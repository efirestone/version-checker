require 'date'
require 'nokogiri'

require_relative '../platform.rb'

# Device Config

class PlexDeviceConfig < DeviceConfig

  attr_reader :auth_token

  def initialize(config)
    super(config)

    @auth_token = config['auth_token']

    raise "Version check definition for platform '#{PlexPlatform.name}' does not include an 'auth_token'" if @auth_token == nil
  end

end

# Platform

class PlexPlatform < Platform

  def self.name
    "plex"
  end

  def self.new_config(info)
    PlexDeviceConfig.new(info)
  end

  def payload_factories
    info = get_info
    unique_id = info[:machine_id]
    [DeviceMqttPayloadFactory.new(@device_config.topic, info, unique_id)]
  end

  private def get_info
    library_info = fetch_library_info
    newest_version_info = fetch_newest_version(library_info[:current_version])

    {
      :manufacturer => 'Plex Inc',
      :model => 'Plex',
    }.merge(newest_version_info).merge(library_info)
  end


  private def fetch_library_info
    uri = URI.parse(@device_config.host) + '/media/providers'

    begin
      response = fetch(uri)
    rescue SocketError => exception
      raise_current_version_check_error(exception.message)
    end

    json = JSON.parse(response.body)

    info = {}

    provider = json['MediaContainer']

    info[:current_version] = format_version(provider['version'])
    info[:name] = provider['friendlyName']
    info[:machine_id] = provider['machineIdentifier']

    info
  end

  private def fetch_newest_version(current_version)
    uri = URI.parse(@device_config.host) + '/updater/status'
    uri.query = URI.encode_www_form({ 'download' => '0' })

    begin
      response = fetch(uri)
    rescue => exception
      puts "Error fetching latest Plex version: #{exception}"
      return {}
    end

    json = JSON.parse(response.body)
    container = json['MediaContainer']

    # If we don't have an update then the 'Release' array will be empty
    newest_version = nil
    if container['status'].to_i == 0 && container['Release'] == nil
      newest_version = current_version
    else
      newest_version = format_version(container['Release'][0]['version'])
    end

    info = {}

    info[:newest_version] = newest_version

    checked_at = container['checkedAt']
    info[:newest_version_checked_at] = Time.at(checked_at).utc.iso8601 unless checked_at == nil

    info
  end

  private def fetch(uri)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['accept'] = 'application/json'
    request['X-Plex-Token'] = @device_config.auth_token

    begin
      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https',
        :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
        https.request(request)
      end
    rescue Net::OpenTimeout => e
      puts "Failed to connect to #{uri.host}: #{e}"
      return nil
    end
  end

  private def format_version(version)
    return nil if version == nil
    first, second = version.split('-', 2)
    first
  end

end
