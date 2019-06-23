require 'yaml'

class Config

  # MQTT Config

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

  # Checker Config

  # This is for a basic checker. Checkers with more parameters can subclass.
  class Checker

    attr_reader :host, :platform, :topic

    def initialize(config)
      @host = config['host']
      @platform = config['platform']
      @topic = config['topic']

      raise "Version check definition does not include a 'host'" if @host == nil
      raise "Version check definition does not include a 'platform'" if @platform == nil
      raise "Version check definition does not include an MQTT 'topic'" if @topic == nil
    end

  end

  # Top Level Config

  attr_reader :check_interval, :checkers, :mqtt

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

    @checkers = []
    config['version_checks'].each do |checker|
      @checkers << Checker.new(checker)
    end
  end

end
