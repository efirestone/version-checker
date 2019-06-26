require 'fileutils'

class RemoteDockerImagesList

  class TagList

    def initialize(images_list)
      @index = 0
      @images_list = images_list
    end

    def next
      image = @images_list.tag_list_next_at(@index)
      return nil if image == nil

      @index += 1
      image['name']
    end

  end

  def initialize(repository, cache_dir = "~/.cache/version_checker/docker_image_data/")
    @cache_dir = File.join(File.expand_path(cache_dir), 'manifests', repository)
    @repository = repository

    # We'll use the Docker Hub website API rather than the docker.io registry /tags/list version
    # because the registry version returns all the tags alphabetically ordered, and we really
    # want a chronologically ordered version so that we can check newer images first.
    # Check the git history for the older version.
    @next_tag_uri = URI.parse("https://hub.docker.com/v2/repositories/#{@repository}/tags/")
  end

  # If force_download is true then skip checking the cache
  def get_manifest(tag, force_download = false)
    raise "Cannot get manifest for empty reference" if tag.nil? || tag.empty?

    # We want the V2 content type. https://docs.docker.com/registry/spec/manifest-v2-2/
    content_type = 'vnd.docker.distribution.manifest.v2+json'

    unless force_download
      manifest_json = get_cached_manifest(tag, content_type)

      # Check for a "no entry exists" token, and if it does, don't try to download again.
      return nil if manifest_json == 'noentry'

      return DockerImageManifest.new(tag, manifest_json) unless manifest_json.nil?
    end

    manifest_json = download_manifest(tag, "application/#{content_type}")

    return nil if manifest_json.nil?

    # For some images we get back the v1 manifest even when requesting the v2 one.
    if JSON.parse(manifest_json)['schemaVersion'] != 2
      # Mark this as an invalid entry so we don't try to re-download again in the future.
      cache_manifest('noentry', tag, content_type)
      return nil
    end

    cache_manifest(manifest_json, tag, content_type)

    return DockerImageManifest.new(tag, manifest_json)
  end

  def tag_list
    TagList.new(self)
  end

  private def cache_manifest(manifest, reference, variant)
    # Keep an in-memory cache as well so we're not going to disk if we don't need to.
    @cache ||= {}

    @cache["#{reference}/#{variant}"] = manifest

    path = File.join(@cache_dir, reference, "#{variant}.json")
    dir = File.dirname(path)

    FileUtils.mkdir_p(dir) unless File.exist?(dir)

    File.write(path, manifest)
  end

  private def get_cached_manifest(reference, variant)
    # Check the in-memory cache first
    manifest = @cache["#{reference}/#{variant}"]
    return manifest unless manifest == nil

    # Then check the file system cache
    path = File.join(@cache_dir, reference, "#{variant}.json")

    return nil unless File.exist?(path)

    File.read(path)
  end

  private def download_manifest(reference, accept_type)
    @token ||= get_token

    uri = URI.parse("https://registry-1.docker.io/v2/#{@repository}/manifests/#{reference}")
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Accept'] = accept_type

    response = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https') do |https|
      https.request(request)
    end

    if response.code != '200'
      puts "Failed to download manifest from #{uri.request_uri}"
      return nil
    end

    return nil if response.body.nil? || response.body.strip.empty?

    response.body
  end

  private def get_token
    uri = URI.parse('https://auth.docker.io/token')
    uri.query = URI.encode_www_form({
      'service' => 'registry.docker.io',
      'scope' => "repository:#{@repository}:pull"
    })
    request = Net::HTTP::Get.new(uri.request_uri)

    response = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https') do |https|
      https.request(request)
    end

    json = JSON.parse(response.body)

    json['token']
  end

  # Get the next tag in the array. Fetch new ones if necessary.
  # For use by tag lists only
  def tag_list_next_at(index)
    @tags ||= []

    if index < @tags.size
      return @tags[index]
    elsif @next_tag_uri == nil
      # We're at the end of the list and there's nothing left to fetc
      return nil
    else
      tag_list_fetch_next

      # Try again
      return tag_list_next_at(index)
    end
  end

  # Fetch the next page of tags.
  private def tag_list_fetch_next
    uri = @next_tag_uri
    request = Net::HTTP::Get.new(uri.request_uri)
    request['content-type'] = 'application/json'

    response = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https') do |https|
      https.request(request)
    end

    raise "Failed to fetch tags for #{@repository}" unless response.code.to_i == 200

    json = JSON.parse(response.body)

    # Save the URI for the next page to fetch
    next_uri = json['next']
    if next_uri == nil
      # Set a placeholder to indicate we've hit the end
      @next_tag_uri = nil
    else
      @next_tag_uri = URI.parse(next_uri)
    end

    @tags += json['results']
  end

end

class DockerImageManifest

  def initialize(tag, raw_json)
    raise "Cannot create a manifest from empty JSON" if raw_json.nil? || raw_json.strip.empty?

    @json = JSON.parse(raw_json)
    @tag = tag

    raise "Metadata version 2 is required" unless @json['schemaVersion'] == 2
  end

  def digest
    @json['config']['digest']
  end

  def tag
    @tag
  end

end
