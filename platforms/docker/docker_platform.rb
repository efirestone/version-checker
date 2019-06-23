require_relative '../../device_mqtt_payload_factory.rb'
require_relative '../platform.rb'
require_relative 'docker_image_device_check.rb'
require_relative 'local_docker_containers_list.rb'
require_relative 'remote_docker_images_list.rb'

# Device Config

class DockerDeviceConfig < DeviceConfig

  attr_reader :monitored_repositories, :username

  def initialize(config)
    super(config)

    @monitored_repositories = config['monitored_repositories']
    @username = config['username']

    raise "Version check definition for platform '#{DockerPlatform.name}' does not include a 'username'" if @username == nil
  end

end

# Platform

class DockerPlatform < Platform

  def initialize(device_config)
    @device_config = device_config
  end

  def self.name
    "docker"
  end

  def self.new_config(info)
    DockerDeviceConfig.new(info)
  end

  def payload_factories
    images = LocalDockerContainersList.new(@device_config.username, @device_config.host).get_containers_list

    monitored_repositories = @device_config.monitored_repositories

    payload_factories = []
    images.each do |image|
      repository = image[:repository]
      tag = image[:tag]
      next if tag.nil? || tag.empty?

      # Ignore unmonitored repositories
      next unless monitored_repositories.nil? || monitored_repositories.empty? || monitored_repositories.include?(repository)

      info = DockerImageDeviceCheck.new(image).get_info
      image_topic = @device_config.topic.gsub('{{repository}}', repository)

      payload_factories << DeviceMqttPayloadFactory.new(image_topic, info)
    end

    payload_factories
  end

end
