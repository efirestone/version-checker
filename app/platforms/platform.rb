require_relative 'device_config.rb'

class Platform

  def initialize(device_config)
    raise "Abstract initializer called"
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
