require 'yaml'

class Config

  class Mqtt

    attr_reader :host, :password, :username

    def initialize(config)
      raise "'mqtt' config section is an array and not a hash" if config.kind_of?(Array)

      @host = config['host']
      @username = config['username']
      @password = config['password']

      raise "MQTT configuration does not include a 'host'" if @host == nil
      raise "MQTT configuration does not include a 'username'" if @username == nil
    end

  end

  attr_reader :check_interval, :mqtt

  def initialize(file_path)
    raise "No configuration file found at #{file_path}" unless File.exist?(file_path)

    config = YAML.load_file(file_path)

    # By default we'll check every 30 minutes
    @check_interval = 30 * 3600
    if value = config['config']['check_interval']
      value = value.to_i
      raise "Check interval cannot be zero" if value == 0
      raise "Check interval cannot be negative" if value < 0
      @check_interval = value
    end

    mqtt_config = config['mqtt']
    raise "Configuration does not contain an 'mqtt' section" if mqtt_config == nil

    @mqtt = Mqtt.new(mqtt_config)
  end

end
