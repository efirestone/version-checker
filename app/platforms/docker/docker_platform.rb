require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'
require_relative 'docker_image_device_check.rb'
require_relative 'local_docker_containers_list.rb'
require_relative 'remote_docker_images_list.rb'

# Device Config

class DockerDeviceConfig < DeviceConfig

  attr_reader :monitored_containers, :username

  def initialize(config)
    super(config)

    @monitored_containers = config['monitored']
    @username = config['username']

    raise "Version check definition for platform '#{DockerPlatform.name}' does not include a 'username'" if @username == nil
  end

end

# Platform

class DockerPlatform < Platform

  def self.name
    "docker"
  end

  def self.new_config(info)
    DockerDeviceConfig.new(info)
  end

  def payload_factories
    containers = LocalDockerContainersList.new(
      @device_config.username,
      @device_config.host,
      @global_config.ssh.command_line_params
    ).get_containers_list

    monitored_containers = @device_config.monitored_containers.dup

    payload_factories = []
    containers.each do |container|
      name = container.name.dup
      tag = container.tag.dup
      next if tag.nil? || tag.empty?

      # Ignore unmonitored containers
      next unless monitored_containers.nil? || monitored_containers.empty? || monitored_containers.delete(name) != nil

      info = DockerImageDeviceCheck.new(container).get_info
      container_topic = @device_config.topic
        .gsub('{{container}}', name)
        .gsub('{{tag}}', tag)
      unique_id = "docker_#{name}_#{tag}"

      payload_factories << DeviceMqttPayloadFactory.new(container_topic, info, unique_id)
    end

    (monitored_containers || []).each do |container|
      puts "No Docker container exists named #{container}"
    end

    payload_factories
  end

end
