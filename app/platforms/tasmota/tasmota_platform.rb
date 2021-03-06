require 'net/http'
require 'nokogiri'
require 'time'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

class TasmotaPlatform < Platform

  def initialize(device_config, global_config)
    @device_config = device_config

    @host = "http://#{device_config.host}" unless @device_config.host.start_with?('http')
  end

  def self.name
    "tasmota"
  end

  def payload_factories
    info = get_info
    id = info[:mac_address].gsub(':', '')[-6..-1].upcase unless info[:mac_address].nil?
    [new_mqtt_payload(info, id)]
  end

  private def get_info
    info = get_current_info
    return nil if info == nil

    info[:newest_version] = get_newest_version
    info[:newest_version_checked_at] = Time.now.utc.iso8601

    info.compact
  end

  private def get_current_info
    def format_version(version)
      version.gsub(/\(.*\)/, '').strip
    end

    def to_booted_at(uptime)
      parts = uptime.split('T')
      uptime_seconds = parts[0].to_i * (24 * 3600)

      time_parts = parts[1].split(':')
      uptime_seconds += time_parts[0].to_i * 3600 + time_parts[1].to_i * 60 + time_parts[2].to_i

      Time.now - uptime_seconds
    end

    uri = URI.parse("#{@host}/in")

    request = Net::HTTP::Get.new(uri.request_uri)

    begin
      response = Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |https|
        https.request(request)
      end
    rescue => exception
      # Failed to connect to the device.
      raise_current_version_check_error("Failed to connect to device: #{exception}")
    end

    page = Nokogiri::HTML(response.body)
    model = page.css('h3').text
    model.slice!(' Module')

    # The content is included as a JavaScript string that is delimited by "}1" (separates key/value pairs)
    # and "}2" (separates the key from the value).
    values_content = response.body.match(/\<table.*th\>(.*)\<\/td\>\<\/tr\>\<\/table\>/).captures[0]
    values = values_content.split('}1').map { |row| row.split('}2') }.to_h

    {
      :current_version => format_version(values['Program Version']),
      :mac_address => values['MAC Address'],
      :ipv4_address => values['IP Address'],
      :host_name => values['Hostname'],
      :booted_at => to_booted_at(values['Uptime']).utc.iso8601,
      :manufacturer => 'Tasmota',
      :model => model,
      :name => values['Friendly Name 1'] + ' Tasmota',
    }.compact
  end

  private def get_newest_version
    uri = URI.parse('https://github.com/arendst/Tasmota/releases/latest')

    request = Net::HTTP::Get.new(uri.request_uri)

    begin
      response = Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |https|
        https.request(request)
      end
    rescue SocketError => exception
      raise_current_version_check_error("Failed to connect to #{uri}")
    end

    # We expect a URL redirect
    raise "Unexpected response code #{response.code}" unless response.code.to_i == 302

    # The /latest URL redirects to the latest version, so extract the version number from the URL.
    version = URI(response['Location']).path.split('/').last

    # Remove a leading v if it's v#
    version = version[1..-1] if version.match(/^v\d/)

    version
  end

end
