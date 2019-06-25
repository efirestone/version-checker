require 'fileutils'

class RemoteDockerImagesList

  def initialize(repository, cache_dir = "~/.cache/version_checker/docker_image_data/")
    @cache_dir = File.join(File.expand_path(cache_dir), 'manifests', repository)
    @repository = repository
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

  def get_tags
    return @tags unless @tags.nil?

    @token ||= get_token

    uri = URI.parse("https://registry-1.docker.io/v2/#{@repository}/tags/list")
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"

    response = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https') do |https|
      https.request(request)
    end

    json = JSON.parse(response.body)
    @tags = json['tags']

    @tags
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
