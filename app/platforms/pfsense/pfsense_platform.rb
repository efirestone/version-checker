require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'openssl'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class PfSenseDeviceConfig < DeviceConfig

  attr_reader :password, :username

  def initialize(config)
    super(config)

    @password = config['password']
    @username = config['username']

    raise "Version check definition for platform '#{PfSensePlatform.name}' 'host' entry does not include the http or https scheme" unless @host.start_with?('http')
    raise "Version check definition for platform '#{PfSensePlatform.name}' does not include a 'password'" if @password == nil
    raise "Version check definition for platform '#{PfSensePlatform.name}' does not include a 'username'" if @username == nil
  end

end

# Platform

class PfSensePlatform < Platform

  def self.name
    "pfsense"
  end

  def self.new_config(info)
    PfSenseDeviceConfig.new(info)
  end

  def payload_factories
    [new_mqtt_payload(get_info)]
  end

  private def get_info
    login_form_response = fetch_login_form_response

    @csrf_token = get_csrf_token(login_form_response)
    @cookie = get_cookie(login_form_response)

    dashboard_response = fetch_dashboard_response

    @csrf_token = get_csrf_token(dashboard_response)
    @cookie = get_cookie(dashboard_response)
    current_version, newest_version = fetch_versions

    mac_address = fetch_mac_address

    uptime = fetch_uptime
    booted_at = (Time.now - uptime)

    # Convert to a standardized set of keys
    {
      :manufacturer => 'Netgate',
      :model => 'pfSense',
      :mac_address => mac_address,
      :current_version => current_version,
      :newest_version => newest_version,
      :booted_at => booted_at.utc.iso8601,
      :newest_version_checked_at => Time.now.utc.iso8601
    }
  end

  private def get_csrf_token(response)
    page = Nokogiri::HTML(response.body)

    csrf_values = page.css('input[name=__csrf_magic]')[0]['value']

    # The value includes two tokens, but we don't care about the second.
    # Ex: sid:022ad9cf6465a7fddfacbf7fb4d7a038f23f1484,1559535858;ip:c537ca59f1d0f8be8b709e26191534512740925a,1559535858
    csrf_values.split(';').find { |i| i.start_with?('sid:') }
  end

  private def get_cookie(response)
    response.response['set-cookie'].split('; ')[0]
  end

  private def fetch_login_form_response
    uri = URI.parse(@device_config.host)
    request = Net::HTTP::Get.new(uri.request_uri)

    return Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(request)
    end
  end

  private def fetch_dashboard_response
    query_params = {
      'usernamefld' => @device_config.username,
      'passwordfld' => @device_config.password,
      'login' => 'Sign In',
      '__csrf_magic' => @csrf_token,
    }
    uri = URI.parse(@device_config.host)

    request = Net::HTTP::Post.new(uri.request_uri)
    request['cookie'] = @cookie
    request.set_form_data(query_params)

    response = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(request)
    end

    # A successful login will give us a redirect to reload the main page
    raise "Incorrect login credentials" if response.code != '302'

    new_host = (uri + response['Location']).to_s
    uri = URI.parse(new_host)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['cookie'] = get_cookie(response)

    return Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(request)
    end
  end

  private def fetch_versions
    referer_uri = URI.parse(@device_config.host) + 'pkg_mgr_install.php'
    referer_uri.query = URI.encode_www_form({ 'id' => 'firmware'})

    response = ajax_fetch(
      'pkg_mgr_install.php',
      { 'getversion' => 'yes' },        # Ajax params
      { 'referer' => referer_uri.to_s } # Headers
    )

    json = JSON.parse(response.body)

    [json['installed_version'], json['version']]
  end

  private def fetch_mac_address

    def fetch_interface_attributes
      uri = URI.parse(@device_config.host) + 'status_interfaces.php'

      request = Net::HTTP::Get.new(uri.request_uri)
      request['cookie'] = @cookie

      response = Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https',
        :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
        https.request(request)
      end

      page = Nokogiri::HTML(response.body)

      attributes_by_interface = {}
      page.css('div.panel.panel-default').each do |panel|
        interface_description = panel.css('.panel-title').text
        interface_name = interface_description.match(/.*\(([A-Za-z0-9.]+), [A-Za-z0-9.]+\)/).captures[0]

        attribute_names = panel.css('.dl-horizontal dt').map { |k| k.text }
        attribute_values = panel.css('.dl-horizontal dd').map { |v| v.text }
        attributes = Hash[attribute_names.zip(attribute_values)]

        attributes_by_interface[interface_name] = attributes
      end

      attributes_by_interface
    end

    attributes_by_interface = fetch_interface_attributes

    # Only look for `lan*` or `wan*` interfaces. Prefer LAN ones.
    relevant_interfaces = attributes_by_interface.keys.select { |k| k.match(/^[lw]an/) }.sort

    relevant_interfaces.map { |i| attributes_by_interface[i]['MAC Address'] }.compact.first
  end

  private def fetch_newest_version
    response = ajax_fetch('widgets/widgets/system_information.widget.php', {
      'getupdatestatus' => '1'
    })

    page = Nokogiri::HTML(response.body)

    # Find the string like "Version information updated at Tue Jun 4 0:55:05 CDT 2019"
    checked_at_string = response.body.match(/Version information updated at (.* 20\d\d)/).captures[0]
    checked_at = Time.parse(checked_at_string)

    version = page.css('span.text-success').text

    return version, checked_at
  end

  private def fetch_uptime
    response = ajax_fetch('getstats.php', {})

    # Extracts uptime as something like "19 Days 09 Hours 03 Minutes 06 Seconds"
    values = response.body.split('|')[3]

    days = 0
    if match = values.match(/(\d+) Days?/)
      days = match.captures[0]&.to_i
    end
    hours = values.match(/(\d+) Hours?/).captures[0].to_i
    minutes = values.match(/(\d+) Minutes?/).captures[0].to_i
    seconds = values.match(/(\d+) Seconds?/).captures[0].to_i

    return (days * 24 * 3600) + (hours * 3600) + (minutes * 60) + seconds
  end

  private def ajax_fetch(uri_path, params, headers = {})
    uri = URI.parse(@device_config.host) + uri_path

    request = Net::HTTP::Post.new(uri.request_uri)
    request['cookie'] = @cookie
    headers.each { |k, v| request[k] = v }

    query_params = {
      '__csrf_magic' => @csrf_token,
      'ajax' => 'ajax',
    }.merge(params)

    request.set_form_data(query_params)

    Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https',
      :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |https|
      https.request(request)
    end
  end

end
