
class DockerContainer
    attr_accessor :name, :container_id, :repository, :tag, :image_id, :booted_at, :host_name, :ipv4_address
end

class LocalDockerContainersList

  def initialize(username, host, ssh_params)
    @host = host
    @username = username
    @ssh_params = ssh_params
  end

  def get_containers_list
    output = `ssh #{@username}@#{@host} #{@ssh_params} docker ps --no-trunc --format "{{.ID}}"`

    raise "Failed to connect to #{@host}" unless $?.success?

    return output.split("\n").map { |container_id|
      next if container_id.strip.empty?

      # TODO: May be able to pull the network data from other parts of the config
      output = `ssh #{@username}@#{@host} #{@ssh_params} docker inspect #{container_id} --format "{{.Name}}\\|{{.Image}}\\|{{.Config.Image}}\\|{{.State.StartedAt}}\\|{{.Config.Hostname}}\\|{{.NetworkSettings.IPAddress}}"`

      values = output.strip.split('|')

      image_id = values[1]

      repository_values = values[2].split(':')
      repository = repository_values[0]
      tag = repository_values.size > 1 ? repository_values[1] : 'latest'

      booted_at = Time.iso8601(values[3]) if $?.success?

      container = DockerContainer.new
      container.container_id = container_id
      container.name = values[0].gsub(/^\//, '')
      container.repository = repository
      container.tag = tag
      container.image_id = image_id
      container.booted_at = booted_at
      container.host_name = values[4]
      container.ipv4_address = values[5]

      container
    }
  end

end

