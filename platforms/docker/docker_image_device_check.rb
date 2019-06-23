require 'time'

# A class that encapsulates the version check for a single Docker image
class DockerImageDeviceCheck

  def initialize(local_image)
    tag = local_image[:tag]
    raise "Cannot check for updates of a Docker image that is not from a tag." if tag.nil? || tag.empty?

    @local_image = local_image
    @digest = local_image[:image_id]
    @repository = local_image[:repository]
    @tag = tag
  end

  def get_info
    start_time = Time.now

    image_list = RemoteDockerImagesList.new(@repository)

    # To start, check if the image associated with the given tag is still the same.
    # If, for example, the 'latest' tag has been updated then it will have a new associated image.
    latest_manifest_for_tag = image_list.get_manifest(@tag, true)
    if latest_manifest_for_tag.nil?
      # Failed to find any info about this image. It's likely not hosted in this Docker registry.
      return formatted_info(@tag, nil, start_time)
    end

    if latest_manifest_for_tag.digest == @digest
      # We're still up to date.
      return formatted_info(@tag, latest_manifest_for_tag, start_time)
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
    alternate_local_image_tag = nil
    alternate_remote_manifest = nil

    # Iterate backward so that more recent tags are evaluated first.
    image_list.get_tags.reverse.each { |tag|
      # Stop looking if we already found matches
      next if alternate_local_image_tag != nil && alternate_remote_manifest != nil

      manifest = image_list.get_manifest(tag)
      next if manifest.nil?

      alternate_local_image_tag = manifest.tag if manifest.digest == @digest

      if alternate_remote_manifest.nil? && manifest.digest == latest_manifest_for_tag.digest && manifest.tag != latest_manifest_for_tag.tag
        alternate_remote_manifest = manifest
      end
    }

    return formatted_info(alternate_local_image_tag, alternate_remote_manifest || latest_manifest_for_tag, start_time)
  end

  private def formatted_info(current_tag, latest_image_manifest, start_time)
    repository_parts = @repository.split('/')
    manufacturer = nil
    model = nil
    if repository_parts.length > 1
      manufacturer = repository_parts[0]
      model = repository_parts[1..-1].join('/')
    end

    info = {
      :booted_at => @local_image[:booted_at].utc.iso8601,
      :current_version => formatted_version(current_tag, @digest),
      :manufacturer => manufacturer,
      :name => @repository,
      :model => model,
      :host_name => @local_image[:host_name],
      :ipv4_address => @local_image[:ipv4_address],
    }.compact

    return info if latest_image_manifest.nil?

    info[:latest_version] = formatted_version(latest_image_manifest.tag, latest_image_manifest.digest)
    info[:latest_version_checked_at] = start_time.utc.iso8601

    info
  end

  private def formatted_version(tag, image_id)
    # Remove the "sha256:" prefix if present, and truncate to just the first five characters of the SHA
    image_id.slice!('sha256:')
    image_id = image_id[0..5]
    return "(#{image_id})" if tag.nil? || tag.strip.empty?
    return "#{tag} (#{image_id})"
  end

end
