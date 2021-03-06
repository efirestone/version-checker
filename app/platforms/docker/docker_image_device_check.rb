require 'time'

# A class that encapsulates the version check for a single Docker image
class DockerImageDeviceCheck

  def initialize(local_image)
    tag = local_image.tag
    raise "Cannot check for updates of a Docker image that is not from a tag." if tag.nil? || tag.empty?

    @local_image = local_image
    @digest = local_image.image_id
    @repository = local_image.repository
    @tag = tag
  end

  def get_info
    start_time = Time.now

    image_list = RemoteDockerImagesList.new(@repository)

    # To start, check if the image associated with the given tag is still the same.
    # If, for example, the 'latest' tag has been updated then it will have a new associated image.
    newest_manifest_for_tag = image_list.get_manifest(@tag, nil)
    if newest_manifest_for_tag.nil?
      # Failed to find any info about this image. It's likely not hosted in this Docker registry.
      return formatted_info(@tag, nil, start_time)
    end

    if newest_manifest_for_tag.digest == @digest
      # We're still up to date. Try to find a better tag (version) if possible.
      # If there isn't an alternative then this will end up downloading all the tags, so set a limit.
      alternate_manifest = get_display_manifest(image_list, @digest, {
        :fetch_limit => 100,
      })
      return formatted_info(
        alternate_manifest&.tag || @tag,
        alternate_manifest || newest_manifest_for_tag,
        start_time
      )
    end

    # The tag we're using points to a new image. Figure out if there are other tags that are
    # still associated with the image we're using. Any tag that's still associated is likely
    # to be a version number that we can display. For example, an image might get the tag
    # '1.0.1' as well as the tag 'latest'. The 'latest' tag might later move to a new image,
    # but '1.0.1' would remain associated with the image.
    #
    # In addition, we'll check for an alternate tag for the remote image that we want to update
    # to. This means that rather than showing the new version/tag as 'latest', we can show it as
    # something like '1.0.3'.
    alternate_local_image_tag = get_display_manifest(image_list, @digest)&.tag
    alternate_remote_manifest = get_display_manifest(image_list, newest_manifest_for_tag.digest)

    return formatted_info(
      alternate_local_image_tag,
      alternate_remote_manifest || newest_manifest_for_tag,
      start_time
    )
  end

  # Words in tags that don't provide any value as a version number.
  # These are regexes, so they can model all or part of a tag to remove
  def self.superfluous_keywords
    [
      /(?:^|[-_.])amd64(?:$|[-_.])/,
      /(?:^|[-_.])latest(?:$|[-_.])/,
      /(?:^|[-_.])stable(?:$|[-_.])/,
      /^rc$/
    ]
  end

  # Find an tag for a given image for which we already have a tag.
  #
  # This method is best-effort. There may be multiple alternate manifests, but this will return
  # the first one it finds, which should be the most recent. This avoids needing to query the
  # server for the details about ever single tag in most cases.
  private def get_display_manifest(image_list, digest, options = {})
    remaining_checks = options[:fetch_limit] || 10000

    tags = image_list.tag_list
    while tag_info = tags.next do
      return nil if remaining_checks == 0
      remaining_checks -= 1

      tag = tag_info['name']
      updated_at = tag_info['last_updated']

      manifest = image_list.get_manifest(tag, updated_at)

      # Try the next one if we failed to fetch a manifest for this tag
      next if manifest == nil

      # Ignore manifests that don't have a tag since that's what we need for versions
      next if manifest.tag == nil

      # Ignore tags for other images
      next unless manifest.digest == digest

      # Ignore tags that aren't valuable, like 'latest'
      next if trimmed_tag(manifest.tag).strip.empty?

      return manifest
    end

    nil
  end

  private def formatted_info(current_tag, newest_image_manifest, start_time)
    repository_parts = @repository.split('/')
    manufacturer = nil
    model = nil
    if repository_parts.length > 1
      manufacturer = repository_parts[0]
      model = repository_parts[1..-1].join('/')
    end

    name = "#{@local_image.name} Docker Image"

    info = {
      :booted_at => @local_image.booted_at.utc.iso8601,
      :current_version => formatted_version(current_tag, @digest),
      :manufacturer => manufacturer,
      :name => name,
      :model => model,
      :host_name => @local_image.host_name,
      :ipv4_address => @local_image.ipv4_address,
    }.compact

    return info if newest_image_manifest.nil?

    info[:newest_version] = formatted_version(newest_image_manifest.tag, newest_image_manifest.digest)
    info[:newest_version_checked_at] = start_time.utc.iso8601

    info
  end

  private def trimmed_tag(tag)
    self.class.superfluous_keywords.each { |pattern|
      tag.gsub!(pattern, '')
    }

    # Remove a 'v'-prefix, like in 'v1.0.1'
    tag = tag[1..-1] if tag.match(/^v\d/)

    tag.strip
  end

  private def formatted_version(tag, image_id)
    # Ignore common tags that we know aren't a version number
    tag = trimmed_tag(tag) if tag != nil
    tag = nil if tag&.empty?

    # Remove the "sha256:" prefix if present, and truncate to just the first five characters of the SHA
    image_id.slice!('sha256:')
    image_id = image_id[0..5]
    return "(#{image_id})" if tag == nil
    return tag
  end

end
