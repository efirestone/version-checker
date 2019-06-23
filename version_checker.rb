#!/usr/bin/env ruby

require 'mqtt'

require_relative 'config.rb'

config_file_path = './configuration.yaml'

# Methods

def run_checks
  MQTT::Client.connect("mqtt://#{@config.mqtt.username}:#{@config.mqtt.password}@#{@config.mqtt.host}") do |client|

    threads = []

    # TODO: Run all the checkers

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
  sleep(30 * 3600)
end
