require 'json'
require 'open-uri'
require 'time'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class UniFiDeviceConfig < DeviceConfig

  attr_reader :username

  def initialize(config)
    super(config)

    @username = config['username']

    raise "Version check definition for platform '#{UniFiPlatform.name}' does not include a 'username'" if @username == nil
  end

end

# Platform

class UniFiPlatform < Platform

  def initialize(device_config, global_config)
    @device_config = device_config
    @global_config = global_config
  end

  def self.name
    "unifi"
  end

  def self.new_config(info)
    UniFiDeviceConfig.new(info)
  end

  def payload_factories
    [DeviceMqttPayloadFactory.new(@device_config.topic, get_info)]
  end

  private def get_info
    current_info = fetch_current_device_info

    # The model name retrieved from the device doesn't match the standard model name
    # used by the website and firmware updates, so map them.
    model = current_info['Model']
    product_name = product_name_for(model)

    latest_info = fetch_latest_firmware_info(product_name)

    booted_at = nil
    unless current_info['Uptime'].nil?
      uptime = current_info['Uptime'][0 .. -("seconds".length)].strip.to_i
      booted_at = Time.now - uptime
    end

    # Convert to a standardized set of keys
    {
      :current_version => current_info['Version'],
      :latest_version => latest_info['version'],
      :latest_version_checked_at => Time.now.utc.iso8601,
      :host_name => current_info['Hostname'],
      :ipv4_address => current_info['IP Address'],
      :mac_address => current_info['MAC Address'],
      :manufacturer => 'Ubiquiti',
      :name => marketing_name_for(model),
      :model => product_name,
      :booted_at => booted_at.utc.iso8601,
    }
  end

  # Returns info from the actual device
  private def fetch_current_device_info
    output = `ssh #{@device_config.username}@#{@device_config.host} #{@global_config.ssh.command_line_params} mca-cli-op info`

    raise "Failed to connect to #{@device_config.host}" unless $?.success?

    info = {}
    output.split("\n").each { |line|
      next if line.strip.empty?
      colon_index = line.index(':')

      key = line[0 .. colon_index-1].strip
      value = line[colon_index+1 .. -1].strip
      info[key] = value
    }

    info
  end

  # The model name retrieved from the device itself doesn't match the standard model name
  # used by the website and firmware updates, so map them.
  private def product_name_for(model)
    {
      'UAP-AC-Pro-Gen2' => 'UAP-AC-PRO',
      'USW-24' => 'US-24',
      'USW-24P-250' => 'US-24-250W',
    }[model] || model
  end

  # Provide a more user-friendly display name.
  private def marketing_name_for(model)
    {
      'UAP-AC-LR' => 'UniFi AP AC LR',
      'UAP-AC-Pro-Gen2' => 'UniFi AP AC PRO',
      'USW-24' => 'UniFi Switch 24',
      'USW-24P-250' => 'UniFi Switch PoE 24 250W',
    }[model]
  end

  # Get information about the latest available firmware for a given model
  # The model should be something like "UAP-AC-LR"
  private def fetch_latest_firmware_info(model)
    # First try to download updates for this specific product
    product_url = "https://www.ui.com/download/?product=#{model.downcase}"
    buffer = open(product_url,
      'X-Requested-With' => 'XMLHttpRequest'
    ).read

    json = JSON.parse(buffer)

    # If the direct product didn't work, then try to download updates
    # for a product group
    group_url = nil
    if json['downloads'].empty?
      # The group name is lowercase with dashes, and also
      # uses "unifi-ap" rather than "uap", like "unifi-ap-ac-lr"
      group_name = model.downcase.gsub(' ', '-')
      group_name.gsub!(/^uap-/, 'unifi-ap-')

      group_url = "https://www.ui.com/download/?group=#{group_name}"
      buffer = open(group_url,
        'X-Requested-With' => 'XMLHttpRequest'
      ).read

      json = JSON.parse(buffer)
    end

    candidates = json['downloads'].each.select { |e|
      next false unless e['category__name'] == 'Firmware'
      products = e['products'].split('|')
      next false unless products.include?(model)
      true
    }

    if candidates.empty?
      raise "Failed to find updated firmware for \"Unifi #{model}\" from:\n"
        + "  #{product_url}\n"
        + "  #{group_url}"
    end

    candidates.sort! { |a,b|
      next a['date_published'] <=> b['date_published'] unless a['date_published'] == b['date_published']
      next a['version'] <=> b['version']
    }

    candidates.last
  end

end
