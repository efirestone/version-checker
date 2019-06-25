require_relative 'device_config.rb'

class Platform

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

end
