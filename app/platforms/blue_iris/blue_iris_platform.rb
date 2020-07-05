require 'net/http'
require 'nokogiri'
require 'open3'
require 'time'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class BlueIrisDeviceConfig < DeviceConfig

  attr_reader :include_major_updates, :username

  def initialize(config)
    super(config)

    @username = config['username']

    # Whether or not to look for updates within the same major version, or to check for new major versions as well.
    # For example, if this is `false` and we're currently on version "4.2" then we would look for "4.X" updates but
    # not "5.X" updates.
    include_major_value = config['include_major_updates']
    @include_major_updates = include_major_value == nil ? true : include_major_value.to_s.downcase == 'true'

    raise "Version check definition for platform '#{BlueIrisPlatform.name}' does not include a 'username'" if @username == nil
  end

end

# Platform

class BlueIrisPlatform < Platform

  def initialize(device_config, global_config)
    @device_config = device_config
    @global_config = global_config
  end

  def self.name
    "blue_iris"
  end

  def self.new_config(info)
    BlueIrisDeviceConfig.new(info)
  end

  def payload_factories
    [DeviceMqttPayloadFactory.new(@device_config.topic, get_info)]
  end

  private def get_info
    current_version = fetch_current_version

    return {} if current_version == nil

    available_versions = fetch_available_versions

    latest_version = available_versions.sort.last
    if !@device_config.include_major_updates
      major_version, rest = current_version.split('.', 2)
      latest_version = latest_version_with_major(available_versions, major_version)
    end

    interface_info = fetch_network_interfaces.first

    {
      :manufacturer => 'Blue Iris Software',
      :model => 'Blue Iris',
      :current_version => current_version,
      :latest_version => latest_version,
      :latest_version_checked_at => Time.now.utc.iso8601,
      :ipv4_address => interface_info['IPv4 Address'],
      :mac_address => interface_info['Physical Address'],
    }.compact
  end

  # Returns the currently installed version
  private def fetch_current_version
    stdout, stderr, status = Open3.capture3("ssh #{@device_config.username}@#{@device_config.host} #{@global_config.ssh.command_line_params} wmic datafile where name=\\\"C:\\\\\\\\Program Files\\\\\\\\Blue Iris 5\\\\\\\\BlueIris.exe\\\" get Version")

    if !status.success?
      raise_current_version_check_error("Failed to connect to device: #{stderr.strip}")
    end

    lines = stdout.split("\n").map { |l| l.strip }.select { |l| !l.empty? }
    attributes = Hash[*lines]

    attributes['Version']
  end

  # Fetch the versions which are currently available for download.
  # This will include the latest update to previous major versions.
  private def fetch_available_versions
    uri = URI.parse("https://blueirissoftware.com/updates/")

    request = Net::HTTP::Get.new(uri.request_uri)

    begin
      response = Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |https|
        https.request(request)
      end
    rescue
      # Failed to connect.
      return nil
    end

    page = Nokogiri::HTML(response.body)

    # Figure out the legacy versions
    legacy_versions = page.css('.qbutton').map { |button|
      match = button.text.match(/^Blue Iris ([\d.]+)/)
      next nil if match == nil
      next match.captures[0]
    }.compact

    # Figure out the latest version
    latest_versions = page.css('h2').map { |h2|
      match = h2.text.match(/Version ([\d.]+)/)
      next nil if match == nil
      next match.captures[0]
    }.compact

    versions = legacy_versions + latest_versions
    versions.sort!

    versions
  end

  private def latest_version_with_major(versions, major_version)
    versions_in_major = versions.select { |v|
      major, rest = v.split('.', 2)
      major == major_version
    }
    versions_in_major.sort.last
  end

  private def fetch_network_interfaces
    output = `ssh #{@device_config.username}@#{@device_config.host} #{@global_config.ssh.command_line_params} ipconfig \\/all`

    lines = output.split("\n")

    previous_attribute_key = nil
    interfaces = []
    current_interface = nil

    # May need to add `IPv4 Address` to this list...
    multi_value_attributes = ['DNS Servers']

    lines.each do |line|
      # Any line that doesn't have space in the front is a section header
      if line.match(/^[^\s]/)
        # puts "Match: #{line.strip.match(/^Ethernet adapter (.*):$/)}"
        if match = line.strip.match(/^Ethernet adapter (.*):$/)
          interface_name = match.captures[0]
          current_interface = {}
          current_interface['Name'] = interface_name
          interfaces << current_interface
        else
          current_interface = nil
        end
        next
      end

      # Ignore everything that's not an interface attribute
      next if current_interface == nil

      line = line.strip
      next if line.empty?

      key, value = line.split(': ', 2)

      # We have the second value in an array, so use the previous key again:
      # DNS Servers . . . . . . . . . . . : 10.1.10.23
      #                                     1.1.1.1    <-- this line
      if value == nil
        value = key
        key = previous_attribute_key
      end

      # The key has trailing ". . . ." that we need to strip off
      key = key.match(/^([^.]+)/).captures[0].strip

      previous_attribute_key = key

      if multi_value_attributes.include?(key)
        current_interface[key] ||= []
        current_interface[key] << value
      else
        current_interface[key] = value
      end
    end

    # Fix up certain attributes
    interfaces.each do |interface|
      interface['Physical Address'].gsub!('-', ':')
      interface['IPv4 Address'].gsub!('(Preferred)', '')
      interface['Link-local IPv6 Address'].gsub!('(Preferred)', '')
    end

    interfaces
  end

end
