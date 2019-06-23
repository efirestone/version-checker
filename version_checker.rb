#!/usr/bin/env ruby

require 'json'
require 'mqtt'

require_relative 'config.rb'
require_relative 'platforms/platform_manager.rb'

project_root = File.dirname(File.absolute_path(__FILE__))
Dir.glob(project_root + '/platforms/*/*_platform.rb') { |file| require file }

config_file_path = './configuration.yaml'

# Methods

def run_checks

  def publish_version_info(client, payload_factory)
    client.publish(
      payload_factory.version_update_topic,
      payload_factory.version_update_payload.to_json,
      true
    )
  end

  MQTT::Client.connect("mqtt://#{@config.mqtt.username}:#{@config.mqtt.password}@#{@config.mqtt.host}") do |client|

    threads = []

    @config.device_configs.each do |device_config|
      threads << Thread.new do
        platform = @platform_manager.platform_for(device_config)
        platform.payload_factories.each do |factory|
          publish_version_info(client, factory)
        end
      end
    end

    # Wait for the threads to finish
    threads.each(&:join)
  end
end

# Main program

@platform_manager = PlatformManager.new

@config = Config.new(config_file_path, @platform_manager)

while true
  begin
    run_checks
  rescue => exception
    puts "Version check batch failed: #{exception}\n   #{exception.backtrace.join("\n   ")}"
  end
  sleep(@config.check_interval)
end
