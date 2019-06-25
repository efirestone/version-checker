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

  # SSH Config

  class Ssh

    attr_reader :fail_on_host_changes

    def initialize(config)
      # Default to ignoring host changes. We'll usually communicating between internal machines,
      # so any host changes will likely be due to upgrades on those machines.
      @fail_on_host_changes = (config['fail_on_host_changes'] || 'false').to_s.downcase == 'true'
    end

    # The parameters to use when executing an SSH command.
    def command_line_params
      params = ""

      # Disallow password auth. We need to fail if no trusted key is set up.
      params += "-o PasswordAuthentication=no "

      # Disallow other keyoard-interactive auth methods.
      params += "-o ChallengeResponseAuthentication=no "

      # Automatically add unknown hosts to the "known hosts" file, without prompting.
      params += "-o StrictHostKeyChecking=no "

      # Also silence warnings since StrictHostKeyChecking=no always issues a warning
      params += "-o LogLevel=ERROR "

      if !@fail_on_host_changes
        # Ignore when the signature of a host changes. This usually happens when a machine is upgraded,
        # but could also happen due to man-in-the-middle attacks.
        params += "-o UserKnownHostsFile=/dev/null "
      end

      params
    end

  end

  # Top Level Config

  attr_reader :check_interval, :device_configs, :mqtt, :ssh

  def initialize(file_path, platform_manager)
    raise "No configuration file found at #{file_path}" unless File.exist?(file_path)

    config = YAML.load_file(file_path)

    @check_interval = self.class.default_check_interval
    if value = config['config']['check_interval']
      value = value.to_i
      raise "Check interval cannot be zero" if value == 0
      raise "Check interval cannot be negative" if value < 0
      @check_interval = value
    end

    mqtt_config = config['mqtt']
    raise "Configuration does not contain an 'mqtt' section" if mqtt_config == nil

    @mqtt = Mqtt.new(mqtt_config)

    @ssh = Ssh.new(config['ssh'] || {})

    @device_configs = []
    config['version_checks'].each do |device_config|
      begin
        @device_configs << platform_manager.new_config(device_config)
      rescue => exception
        puts "Ignoring config: #{exception}\n   #{exception.backtrace.join("\n   ")}"
      end
    end
  end

  def self.default_check_interval
    # By default we'll check every 30 minutes
    30 * 3600
  end

end
