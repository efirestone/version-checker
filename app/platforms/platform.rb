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

  def raise_current_version_check_error(message)
    raise CurrentVersionCheckError.new(self.class.name, @device_config.host, message)
  end

end
