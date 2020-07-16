require 'json'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class HassAddonsDeviceConfig < DeviceConfig

  attr_reader :monitored_addons, :username

  def initialize(config)
    super(config)

    @monitored_addons = config['monitored']
    @username = 'root'
  end

end

# Platform

class HassAddonsPlatform < Platform

  def self.name
    "hass_addons"
  end

  def self.new_config(info)
    HassAddonsDeviceConfig.new(info)
  end

  def payload_factories
    addons = fetch_addons

    monitored_addons = @device_config.monitored_addons.dup

    payload_factories = []
    addons.each do |addon|
      name = addon['name'].dup
      slug = addon['slug'].dup

      # Ignore unmonitored add-ons
      next unless monitored_addons.nil? || monitored_addons.empty? || monitored_addons.delete(name) != nil

      name = "#{name} Home Assistant Add-On"

      info = {
        :current_version => addon['installed'],
        :newest_version => addon['version'],
        :name => name,
        :host_name => @device_config.host
      }.compact

      addon_topic = @device_config.topic
        .gsub('{{addon}}', slug)
      unique_id = "hass_addon_#{slug}"

      payload_factories << DeviceMqttPayloadFactory.new(addon_topic, info, unique_id)
    end

    (monitored_addons || []).each do |addon|
      puts "No Home Assistant addon exists named #{addon}"
    end

    payload_factories
  end

  # Returns info about the installed add-ons.
  private def fetch_addons
    output = `ssh #{@device_config.username}@#{@device_config.host} #{@global_config.ssh.command_line_params} 'eval $(grep SUPERVISOR_TOKEN /etc/profile.d/homeassistant.sh); /usr/bin/ha addons --raw-json'`

    raise_current_version_check_error("Failed to connect to #{@device_config.host}") unless $?.success?

    json = JSON.parse(output)

    raise_current_version_check_error("Add-on info returned result #{json['result']}") unless json['result'] == 'ok'

    installed_addons = json['data']['addons'].select { |a| a['installed'] != nil }

    installed_addons
  end

end
