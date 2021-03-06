require 'json'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class HassOSDeviceConfig < DeviceConfig

  attr_reader :username

  def initialize(config)
    super(config)

    @username = 'root'
  end

end

# Platform

class HassOSPlatform < Platform

  def self.name
    "hass_os"
  end

  def self.new_config(info)
    HassOSDeviceConfig.new(info)
  end

  def payload_factories
    hass_info = fetch_info

    info = {
      :current_version => hass_info['version'],
      :newest_version => hass_info['version_latest'],
      :mac_address => fetch_mac_address,
      :name => 'Home Assistant OS',
      :host_name => @device_config.host
    }.compact

    [new_mqtt_payload(info)]
  end

  # Returns info about the installed add-ons.
  private def fetch_info
    output = `ssh #{@device_config.username}@#{@device_config.host} #{@global_config.ssh.command_line_params} 'eval $(grep SUPERVISOR_TOKEN /etc/profile.d/homeassistant.sh); /usr/bin/ha os info --raw-json'`

    raise_current_version_check_error("Failed to connect to #{@device_config.host}") unless $?.success?

    json = JSON.parse(output)

    raise_current_version_check_error("Home Assistant OS info returned result #{json['result']}") unless json['result'] == 'ok'

    json['data']
  end

  # This will fetch the MAC for the docker image of the SSH add-on, but that should be good enough.
  private def fetch_mac_address
    output = `ssh #{@device_config.username}@#{@device_config.host} #{@global_config.ssh.command_line_params} 'ifconfig'`

    raise_current_version_check_error("Failed to connect to #{@device_config.host}") unless $?.success?

    # Parse the MAC address out of a line similar to:
    # eth0      Link encap:Ethernet  HWaddr 00:11:22:33:44:55  
    output.match(/eth.*HWaddr\s+([0-9A-Fa-f\:]{17})/).captures[0].strip
  end

end
