class DeviceMqttPayloadFactory

  def initialize(topic, state_info)
    @topic = topic
    @state_info = state_info
  end

  # Version Update

  def version_update_payload
    current_version = @state_info[:current_version]
    latest_version = @state_info[:latest_version]
    summary = "Up to date"
    if latest_version == nil
      summary = "Could not check for newer version"
    elsif current_version != latest_version
      summary = "#{latest_version} is available"
    end

    {
      'current_version' => current_version,
      'latest_version' => latest_version,
      'latest_version_checked_time' => @state_info[:latest_version_checked_at],
      'summary' => summary,
    }.compact
  end

  def version_update_topic
    "#{@topic}/tele/VERSION"
  end

end
