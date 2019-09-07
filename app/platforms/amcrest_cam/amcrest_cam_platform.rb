require 'net/http'
require 'time'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class AmcrestCamDeviceConfig < DeviceConfig

  attr_reader :username, :password

  def initialize(config)
    super(config)

    @username = config['username'] || 'admin'
    @password = config['password']

    raise "Version check definition for platform '#{AmcrestCamPlatform.name}' does not include a 'username'" if @username == nil
    raise "Version check definition for platform '#{AmcrestCamPlatform.name}' does not include a 'password'" if @password == nil
  end

end

# Platform

class AmcrestCamPlatform < Platform

  def initialize(device_config, global_config)
    @device_config = device_config
    @global_config = global_config
  end

  def self.name
    "amcrest_cam"
  end

  def self.new_config(info)
    AmcrestCamDeviceConfig.new(info)
  end

  def payload_factories
    [DeviceMqttPayloadFactory.new(@device_config.topic, get_info)]
  end

  private def get_info
    # TODO: Get the current version and the latest available version

    {
      :manufacturer => 'Amcrest',
      # :model => '',
      # :current_version => '',
      # :latest_version => '',
      :latest_version_checked_at => Time.now.utc.iso8601,
      # :ipv4_address => '',
      # :mac_address => '',
    }.compact
  end

end
