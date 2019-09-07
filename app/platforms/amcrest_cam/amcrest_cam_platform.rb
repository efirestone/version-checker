require 'net/http'
require 'nokogiri'
require 'time'

require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'

# Device Config

class AmcrestCamDeviceConfig < DeviceConfig

  attr_reader :username, :password

  def initialize(config)
    super(config)

    @username = config['username'] || 'admin'
    @password = config['password']

    raise "Version check definition for platform '#{AmcrestCamPlatform.name}' does not include a 'username'" if @username == nil
    raise "Version check definition for platform '#{AmcrestCamPlatform.name}' does not include a 'password'" if @password == nil
  end

end

# Platform

class AmcrestCamPlatform < Platform

  def initialize(device_config, global_config)
    @device_config = device_config
    @global_config = global_config
  end

  def self.name
    "amcrest_cam"
  end

  def self.new_config(info)
    AmcrestCamDeviceConfig.new(info)
  end

  def payload_factories
    [DeviceMqttPayloadFactory.new(@device_config.topic, get_info)]
  end

  private def get_info
    # TODO: Get the current version, model name, and network info

    available_versions = fetch_available_versions

    {
      :manufacturer => 'Amcrest',
      # :model => '',
      # :current_version => '',
      # :latest_version => '',
      :latest_version_checked_at => Time.now.utc.iso8601,
      # :ipv4_address => '',
      # :mac_address => '',
    }.compact
  end

  # Fetch the versions which are currently available for download.
  private def fetch_available_versions

    uri = URI.parse("https://amcrest.com/firmwaredownloads")

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

    body_text = response.body
    
    # The page contains some incorrect break tags.
    body_text.gsub!('</br>', '<br/>')
    
    page = Nokogiri::HTML(body_text)

    ignored_model_words = ['and', 'channel', 'discontinued', 'for', 'only', 'pal', 'supports', 'version', 'versions', 'versions:']
    ignored_version_words = ['-', /\d{1,2}\/\d{1,2}\/\d{2,4}/] # Remove dates
    ignored_versions = ['no update available']

    # Figure out the legacy versions
    firmware_versions = []
    page.css('tr').each { |row|
      # puts "Span: #{row.css('span.frmwr-badge')}"
      next unless span = row.css('span.frmwr-badge')[0]

      columns = row.css('td')

      # Most sections have 7 columns, including a "Previous Firmware Version" column.
      # The deprecated sections don't include this column and require an offset to get the version.
      column_offset = columns.count - 7

      summary = columns[3].inner_html.strip

      version_text = columns[6 + column_offset].inner_html.split('<br>')[0].strip
      next if ignored_versions.include?(version_text.downcase)

      ignored_version_words.each { |w| version_text.gsub!(w, '') }
      version = version_text.strip #split(/\s[\s-]*/)[0].strip

      models = summary.split(/\s|\<br\/?\>/).filter { |w|
        next false if ignored_model_words.include?(w.downcase)
        next false if w.length < 3
        next true
      }
      
      if model = span.text
        # If this is an international model then don't overwrite the regular model.
        # Only store it as "<model> International"
        if model.downcase.include?(' international')
          models = [model]
        else
          models << model
        end
      end

      models.sort!

      models.each { |m|
        firmware_versions << [m, version]
      }

      # Debug: Verify the data is correct
      # has_incorrect_data = expected_latest_model_versions[models] != version
      # if has_incorrect_data
      #   puts "\n\n#{models} => '#{version}'"
      #   puts "Columns: #{columns.inner_html}"
      # end
    }

    firmware_versions.compact.to_h
  end

  # Debugging Methods

  # The expected models as parsed on 2019-09-07. These will likely need to be updated periodically.
  private def expected_latest_model_versions
    @expected_latest_models ||= {
      ["AMDV4M8", "AMDV4M8"] => 'V3.218.00AC000.1.T',
      ["AMDV10804-S3", "AMDV10804-S3"] => 'V3.210.AC01.4',
      ["AMDV10808-S3", "AMDV10808-S3"] => 'V3.210.AC01.4',
      ["AMDV108016-S3", "AMDV108016-S3"] => 'V3.210.AC01.4',
      ["AMDV10814", "AMDV10814"] => 'V3.200.AC04.5',
      ["AMDV10814-S3", "AMDV10814-S3"] => 'V3.210.AC01.4',
      ["AMDV10818", "AMDV10818"] => 'V3.200.AC04.5',
      ["AMDV10818-S3", "AMDV10818-S3"] => 'V3.210.AC01.4',
      ["AMDV108116", "AMDV108116"] => 'V3.200.AC04.5',
      ["AMDV108116-S3", "AMDV108116-S3"] => 'V3.210.AC01.4',
      ["IPM-723", "IPM-723B", "IPM-723W"] => 'V2.400.AC02.15.R',
      ["IP2M-841E", "IP2M-841EB,", "IP2M-841ES", "IP2M-841EW"] => 'V2.620.00AC003.3.R',
      ["IP2M-853E", "IP2M-853EW"] => 'V2.422.AC02.0.R',
      ["IP2M-841", "IP2M-841B,", "IP2M-841S", "IP2M-841W"] => 'V2.420.AC00.18.R',
      ["IP2M-841 International"] => 'V2.420.AC00.17.R',
      ["IP2M-851", "IP2M-851B", "IP2M-851W"] => 'V2.420.AC01.3.R',
      ["IP2M-851E", "IP2M-851EB", "IP2M-851EW"] => 'V2.420.AC01.3.R',
      ["IP2M-852", "IP2M-852B", "IP2M-852W"] => 'V2.420.AC01.3.R',
      ["IP2M-852E", "IP2M-852EB", "IP2M-852EW"] => 'V2.420.AC01.3.R',
      ["IP2M-854E", "IP2M-854EW"] => 'V2.460.AC01.0.R',
      ["IP2M-856E", "IP2M-856EW"] => 'V2.460.AC01.0.R',
      ["IP2M-858", "IP2M-858W"] => 'V2.422.AC02.0.R',
      ["IP2M-PH822B", "IP2M-PH822B"] => 'V2.622.00AC000.0.R',
      ["IP3M-941", "IP3M-941B,", "IP3M-941S", "IP3M-941W"] => 'V2.620.00AC003.3.R',
      ["IP3M-943", "IP3M-943B", "IP3M-943W"] => 'V2.400.AC02.15.R',
      ["IP3M-943 International"] => 'V2.400.AC00.26.R',
      ["IP3M-954E", "IP3M-954EB", "IP3M-954EW"] => 'V2.400.0002.15.R',
      ["IP3M-956E", "IP3M-956EB", "IP3M-956EW"] => 'V2.400.0002.15.R',
      ["IP3M-HX2", "IP3M-HX2B", "IP3M-HX2W"] => 'V2.620.00AC003.3.R',
      ["IP4M-1026", "IP4M-1026B", "IP4M-1026W"] => 'V2.420.AC01.3.R',
      ["IP4M-1026E", "IP4M-1026EB", "IP4M-1026EW"] => 'V2.420.AC01.3.R',
      ["IP4M-1028", "IP4M-1028B", "IP4M-1028W"] => 'V2.420.AC01.3.R',
      ["IP4M-1028E", "IP4M-1028EB", "IP4M-1028EW"] => 'V2.420.AC01.3.R',
      ["IP4M-1051", "IP4M-1051B", "IP4M-1051W"] => 'V2.620.00AC000.3.R',
      ["IP4M-1053E", "IP4M-1053EW"] => 'V2.422.AC02.0.R',
      ["IP4M-1054E", "IP4M-1054EW"] => 'V2.460.AC01.0.R',
      ["IP4M-1055E", "IP4M-1055EB", "IP4M-1055EW"] => 'V2.460.AC01.0.R',
      ["IP4M-1056E", "IP4M-1056EW"] => 'V2.460.AC01.0.R',
      ["IP5M-1173E", "IP5M-1173EW"] => 'V2.460.AC01.0.R',
      ["IP5M-F1180E", "IP5M-F1180E"] => 'V2.622.00AC000.0.R',
      ["IP8M-2493E", "IP8M-2493EB", "IP8M-2493EW"] => 'V2.460.AC01.0.R',
      ["IP8M-2496E", "IP8M-2496EB", "IP8M-2496EW"] => 'V2.460.AC01.0.R',
      ["IP8M-T2499EW", "IP8M-T2499EW"] => 'V2.622.00AC000.0.R',
      ["NV4432E-HS", "NV4432E-HS"] => '10002',
      ["NV4108-HS", "NV4108-HS"] => '10002',
      ["NV4108E-HS", "NV4108E-HS"] => '10002',
      ["NV4116-HS", "NV4116-HS"] => '10002',
      ["NV4116E-HS", "NV4116E-HS"] => '10002',
      ["NV4432-HS", "NV4432-HS"] => '10002',

      # DISCONTINUED MODELS
      ["960H4+", "AMDV960H4+"] => '1611300 GA 3.1',
      ["960H8+", "AMDV960H8+"] => '1611300 GA 3.1',
      ["960H16+", "AMDV960H16+"] => '1611300 GA 3.1',
      ["960H", "AMDV960H4"] => '1701040 GA 3.1',
      ["960H", "AMDV960H8"] => '1701040 GA 3.1',
      ["960H", "AMDV960H16"] => '1611300 GA 3.1',
      ["ACD-830B", "ACD-830B"] => 'V9.2017.0216.v06',
      ["AMDV7204", "SV10003"] => '3.200.AC04.5',
      ["AMDV7208", "SV10003"] => '3.200.AC04.5',
      ["AMDV72016", "SV10003"] => '3.200.AC04.5',
      ["AMDV7214", "AMDV7214"] => 'V3.200.AC04.5',
      ["AMDV7218", "AMDV7218"] => 'V3.200.AC04.5',
      ["AMDV72116", "AMDV72116"] => 'V3.200.AC04.5',
      ["AMDV7204-S3", "AMDV7204-S3"] => 'V3.210.AC01.4',
      ["AMDV7208-S3", "AMDV7208-S3"] => 'V3.210.AC01.4',
      ["AMDV72016-S3", "AMDV72016-S3"] => 'V3.210.AC01.4',
      ["AMDV7214-S3", "AMDV7214-S3"] => 'V3.210.AC01.4',
      ["AMDV7218-S3", "AMDV7218-S3"] => 'V3.210.AC01.4',
      ["AMDV72116-S3", "AMDV72116-S3"] => 'V3.210.AC01.4',
      ["AMDV10804", "AMDV10804"] => '3.200.AC04.5',
      ["AMDV10808", "AMDV10808"] => '3.200.AC04.5',
      ["ATC-1201", "ATC-1201"] => '1.0',
      ["ATC-801", "ATC-801"] => 'DV 3.3.016',
      ["ATC-1202W", "ATC-1202W"] => 'UN 3.6.05',
      ["IPM-721", "IPM-721B,", "IPM-721S", "IPM-721W"] => 'V2.420.AC00.18.R',
      ["IPM-721E", "IPM-721EB", "IPM-721ES"] => 'V2.420.AC00.17.R',
      ["IPM-721 International"] => 'V2.420.AC00.17.R',
      ["IPM-722", "IPM-722B", "IPM-722S"] => 'V2.210.0000.6.R',
      ["IPM-743E", "IPM-743ES"] => 'V2.520.0000.0.R',
      ["IPM-751", "IPM-751B", "IPM-751W"] => 'V2.400.AC02.15.R',
      ["IPM-HX1", "IPM-HX1B", "IPM-HX1W"] => 'V2.420.AC00.18.R',
      ["IP2M-842", "IP2M-842B", "IP2M-842W"] => 'V2.212.0000.2.R.20160811',
      ["IP2M-842E", "IP2M-842EB"] => 'V2.520.0000.0.R',
      ["IP2M-844E", "IP2M-844EB", "IP2M-844EW"] => 'V2.520.0000.0.R',
      ["IP2M-846", "IP2M-846B", "IP2M-846W"] => 'V2.400.AC03.0.R',
      ["IP2M-846E", "IP2M-846EB"] => 'V2.400.AC03.0.R',
      ["IP2M-848E", "IP2M-848EB"] => 'V2.400.AC07.0.T',
      ["IP2M-850E", "IP2M-850EW"] => 'V2.400.AC03.0.R',
      ["IP3M-952E", "IP3M-952E"] => 'build 16080801',
      ["IP3M-956", "IP3M-956B", "IP3M-956W"] => 'V2.400.AC02.15.R',
      ["IP4M-1024E", "IP4M-1024EB", "IP4M-1024EW"] => '00005',
      ["IP4M-1025E", "IP4M-1025EB", "IP4M-1025W"] => 'V2.500.0002.15.R',
      ["NV1104", "NV1104"] => 'V3.200.AC00.0.R',
      ["NV1108", "NV1108"] => '3.200.AC00.0',
      ["NV4108", "NV4108"] => '3.200.AC00.0.T',
      ["NV4108E", "NV4108E"] => '3.200.AC00.0.T',
      ["NV4432E", "NV4432E"] => 'V3.200.AC00.0.T',
      ["NV2104E", "NV2104E"] => 'V3.200.AC00.0.R',
      ["NV2108", "NV2108"] => 'V3.200.AC00.0.R.',
      ["NV2108E", "NV2108E"] => 'V3.200.AC00.0.R.',
      ["NV2116", "NV2116"] => 'V3.200.AC00.0.R.',
      ["NV2104", "NV2104"] => 'V3.200.AC00.0.R.',
      ["NV1104E", "NV1104E"] => '3.200.AC00.0',
    }
    @expected_latest_models
  end

end
