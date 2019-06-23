#!/usr/bin/env ruby

require 'mqtt'

require_relative 'config.rb'

config_file_path = './configuration.yaml'

# Methods

def run_checks
  MQTT::Client.connect("mqtt://#{@config.mqtt.username}:#{@config.mqtt.password}@#{@config.mqtt.host}") do |client|

    threads = []

    @config.checkers.each do |checker|
      threads << Thread.new do
        case checker.platform
        when 'example'
        else
          puts "Unsupported platform '#{checker.platform}'. Skipping."
        end
      end
    end

    # Wait for the threads to finish
    threads.each(&:join)
  end
end

# Main program

@config = Config.new(config_file_path)

while true
  begin
    run_checks
  rescue StandardError => error
    puts "Version check batch failed: #{error}"
  end
  sleep(@config.check_interval)
end
