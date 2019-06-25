require 'json'
require 'mqtt'

require_relative 'config.rb'
require_relative 'platforms/platform_manager.rb'
require_relative 'platforms/tasmota/tasmota_platform.rb'

project_root = File.dirname(File.absolute_path(__FILE__))
Dir.glob(project_root + '/platforms/*/*_platform.rb') { |file| require file }

# Methods

def read_config(path)
  begin
    return Config.new(path, @platform_manager)
  rescue => exception
    puts "Configuration error:\n   #{exception}"
  end

  nil
end

def run_checks(config)

  def publish_discovery_info(client, payload_factory)
    # Current Version Sensor
    client.publish(
      payload_factory.current_version_sensor_discovery_topic,
      payload_factory.current_version_sensor_discovery_payload.to_json,
      true
    )

    # Latest Version Sensor
    client.publish(
      payload_factory.latest_version_sensor_discovery_topic,
      payload_factory.latest_version_sensor_discovery_payload.to_json,
      true
    )
  end

  def publish_version_info(client, payload_factory)
    client.publish(
      payload_factory.version_update_topic,
      payload_factory.version_update_payload.to_json,
      true
    )
  end

  begin
    MQTT::Client.connect("mqtt://#{config.mqtt.username}:#{config.mqtt.password}@#{config.mqtt.host}") do |client|

      threads = []

      config.device_configs.each do |device_config|
        threads << Thread.new do
          platform = @platform_manager.platform_for(device_config, config)
          platform.payload_factories.each do |factory|
            publish_discovery_info(client, factory)
            publish_version_info(client, factory)
          end
        end
      end

      # Wait for the threads to finish
      threads.each(&:join)
    end
  rescue SocketError => exception
    puts "Error connecting to mqtt://#{config.mqtt.host}:\n   #{exception}"
  end
end

# Main program

@platform_manager = PlatformManager.new
[BlueIrisPlatform, DockerPlatform, PfSensePlatform, PlexPlatform, TasmotaPlatform, UniFiPlatform].each do |platform_class|
  @platform_manager.register(platform_class)
end

config_file_path = ARGV[0]
raise "The configuration file path must be specified as an argument." if config_file_path == nil

while true
  # Read the config file each time to potentially pick up new changes
  config = read_config(config_file_path)

  begin
    run_checks(config) unless config == nil
  rescue => exception
    puts "Version check batch failed: #{exception}\n   #{exception.backtrace.join("\n   ")}"
  end
  sleep(config&.check_interval || Config.default_check_interval)
end
