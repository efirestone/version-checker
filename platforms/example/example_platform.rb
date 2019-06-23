require_relative '../platform.rb'

# Device Config

class ExampleDeviceConfig < DeviceConfig

  # For illustration we'll add an additional 'username' property.
  attr_reader :username

  def initialize(config)
    super(config)

    @username = config['username']

    raise "Version check definition for platform '#{ExamplePlatform.name}' does not include a 'username'" if @username == nil
  end

end

# Platform

class ExamplePlatform < Platform

  def initialize(device_config)
  end

  def self.name
    "example"
  end

  def self.new_config(info)
    ExampleDeviceConfig.new(info)
  end

  def payload_factories
    # Example platform doesn't do anything.
    # This avoids publishing fake MQTT values as well.
    []
  end

end
