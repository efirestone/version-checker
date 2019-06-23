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

  attr_reader :check_interval, :checkers, :mqtt

  def initialize(file_path)
    raise "No configuration file found at #{file_path}" unless File.exist?(file_path)

    config = YAML.load_file(file_path)

    mqtt_config = config['mqtt']
    raise "Configuration does not contain an 'mqtt' section" if mqtt_config == nil

    @mqtt = Mqtt.new(mqtt_config)
  end

end
