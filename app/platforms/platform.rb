require_relative 'device_config.rb'

class Platform

  # Error

  # An error to raise when fetching the current version fails.
  # This should not be used when fetching any other information as those failures are non-fatal.
  class CurrentVersionCheckError < StandardError

    attr_reader :host, :platform

    def initialize(platform, host, message)
      @platform = platform
      @host = host
      @message = message
    end

    def message
      "Error fetching current device version:\n      #{@message}"
    end

  end

  # Platform

  attr_reader :device_config, :global_config

  def initialize(device_config, global_config)
    @device_config = device_config
    @global_config = global_config
  end

  def self.new_config(info)
    DeviceConfig.new(info)
  end

  def self.name
    raise "Abstract method called"
  end

  def payload_factories
    raise "Abstract method called"
  end

  def new_mqtt_payload(info, unique_id = nil)
    unique_id ||= get_unique_id(info)
    DeviceMqttPayloadFactory.new(@device_config.topic, info, unique_id)
  end

  def raise_current_version_check_error(message)
    raise CurrentVersionCheckError.new(self.class.name, @device_config.host, message)
  end

  private def get_unique_id(info)
    # Use the MAC address if available
    id = info[:mac_address].gsub(':', '').upcase unless info[:mac_address].nil?

    manufacturer = info[:manufacturer]
    model = info[:model]

    if manufacturer != nil && model != nil
      id ||= "#{manufacturer}_#{model}"
    else
      id ||= model || manufacturer
    end

    raise "Failed to create unique ID for #{info[:manufacturer]}, #{info[:model]}" if id.nil? || id.empty?

    "#{self.class.name}_#{id}"
  end

end
