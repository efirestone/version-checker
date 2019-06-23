require_relative 'platform.rb'

class PlatformManager

  def initialize
    @platforms_by_name = {}
  end

  # Turn a version_check configuration entry into a config object.
  def new_config(info)
    name = info['platform']
    raise "'version_check' entry does not include a 'platform'" if name == nil

    platform_class = @platforms_by_name[name]
    raise "Unsupported platform '#{name}' found in 'version_checks'" if platform_class == nil

    platform_class.new_config(info)
  end

  def platform_for(device_config, global_config)
    platform_class = @platforms_by_name[device_config.platform]
    platform_class.new(device_config, global_config)
  end

  # Register a platform class
  def register(platform_class)
    raise "Cannot register class #{platform_class} which does not subclass from Platform" unless platform_class < Platform
    @platforms_by_name[platform_class.name] = platform_class
  end

end
