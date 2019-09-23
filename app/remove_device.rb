require 'json'
require 'mqtt'

require_relative 'platforms/platform_manager.rb'
require_relative 'platforms/tasmota/tasmota_platform.rb'

project_root = File.dirname(File.absolute_path(__FILE__))
Dir.glob(project_root + '/platforms/*/*_platform.rb') { |file| require file }

# Methods

def remove_device(device_topic)

  def publish_discovery_info(client, payload_factory)
    puts "#{payload_factory.current_version_sensor_discovery_topic}: #{payload_factory.current_version_sensor_discovery_payload}"

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
    puts "#{payload_factory.version_update_topic}: #{payload_factory.version_update_payload}"

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
          begin
            platform = @platform_manager.platform_for(device_config, config)
            platform.payload_factories.each do |factory|
              publish_discovery_info(client, factory)
              publish_version_info(client, factory)
            end

          # CurrentVersionCheckErrors are expected sometimes based on runtime conditions
          # (network is down, etc) so log nicely.
          rescue Platform::CurrentVersionCheckError => exception
            puts exception.message
            puts "\nSkipping version check for '#{exception.platform}' device at '#{exception.host}'\n\n"

          rescue => exception
            # Other exceptions are programmer error, such as an exception that needed to be
            # caught earlier and silenced or should have been wrapped as a CurrentVersionCheckError.
            puts "Problem during version check: #{exception}\n   #{exception.backtrace.join("\n   ")}"
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

device_topic = ARGV[0]
raise "The device topic must be specified as an argument." if device_topic == nil

remove_device(device_topic)
