class DeviceMqttPayloadFactory

  attr_accessor :topic

  def initialize(topic, state_info, id)
    raise "State info cannot be nil" if state_info == nil

    @id = id
    @topic = topic
    @state_info = state_info
  end

  # Current Version Sensor Discovery

  def current_version_sensor_discovery_payload
    current_version = @state_info[:current_version]
    newest_version = @state_info[:newest_version]

    icon = case
    when newest_version == nil ; 'mdi:help-circle-outline'
    when current_version == newest_version ; 'mdi:check-circle-outline'
    else 'mdi:alert-circle-outline'
    end

    {
      'uniq_id' => current_version_id,
      'name' => "#{sensor_name_prefix} Version",
      'ic' => icon,
      'dev' => device,

      '~' => "#{@topic}/tele/",

      'stat_t' => '~VERSION',
      'val_tpl' => '{{value_json.current_version}}',

      'json_attr_t' => '~VERSION',
    }
  end

  def current_version_sensor_discovery_topic
    "homeassistant/sensor/#{current_version_id}/config"
  end

  private def current_version_id
    "#{@id}_version"
  end

  # Version Update

  def version_update_payload
    current_version = @state_info[:current_version]
    newest_version = @state_info[:newest_version]
    summary = "Up to date"
    if newest_version == nil
      summary = "Could not check for newer version"
    elsif current_version != newest_version
      summary = "#{newest_version} is available"
    end

    {
      'current_version' => current_version,
      'newest_version' => newest_version,
      'newest_version_checked_time' => @state_info[:newest_version_checked_at],
      'summary' => summary,
    }.compact
  end

  def version_update_topic
    "#{@topic}/tele/VERSION"
  end

  # Private Methods

  private def device
    device = {
      'ids' => [@id],
      'name' => @state_info[:name],
      'mf' => @state_info[:manufacturer],
      'mdl' => @state_info[:model],
      'sw' => @state_info[:current_version],
    }.compact

    if @state_info[:mac_address] != nil
      device['cns'] ||= []
      device['cns'] << ['mac', @state_info[:mac_address]]
    end

    if @state_info[:ipv4_address] != nil
      device['cns'] ||= []
      device['cns'] << ['ipv4', @state_info[:ipv4_address]]
    end

    device
  end

  private def sensor_name_prefix
    prefix = @state_info[:name]

    manufacturer = @state_info[:manufacturer]
    model = @state_info[:model]

    if manufacturer != nil && model != nil
      prefix ||= "#{manufacturer}_#{model}"
    else
      prefix ||= model
    end

    prefix
  end

end
