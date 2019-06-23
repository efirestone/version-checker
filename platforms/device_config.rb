# This is for a basic device version check. Platforms with more parameters can subclass.
class DeviceConfig

  attr_reader :host, :platform, :topic

  def initialize(config)
    @host = config['host']
    @platform = config['platform']
    @topic = config['topic']

    raise "Version check definition does not include a 'platform'" if @platform == nil
    raise "Version check definition for platform '#{@platform}' does not include a 'host'" if @host == nil
    raise "Version check definition for platform '#{@platform}' does not include an MQTT 'topic'" if @topic == nil
  end

end
