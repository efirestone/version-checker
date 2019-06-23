
class LocalDockerContainersList

  def initialize(user, host)
    @host = host
    @user = user
  end

  def get_containers_list
    output = `ssh #{@user}@#{@host} -oPasswordAuthentication=no docker ps --no-trunc --format "{{.ID}}"`

    raise "Failed to connect to #{@host}" unless $?.success?

    return output.split("\n").map { |container_id|
      next if container_id.strip.empty?

      # TODO: May be able to pull the network data from other parts of the config
      output = `ssh #{@user}@#{@host} -oPasswordAuthentication=no docker inspect #{container_id} --format "{{.Image}}\\|{{.Config.Image}}\\|{{.State.StartedAt}}\\|{{.Config.Hostname}}\\|{{.NetworkSettings.IPAddress}}"`

      values = output.strip.split('|')

      image_id = values[0]

      repository_values = values[1].split(':')
      repository = repository_values[0]
      tag = repository_values.size > 1 ? repository_values[1] : 'latest'

      booted_at = Time.iso8601(values[2]) if $?.success?

      {
        :container_id => container_id,
        :repository => repository,
        :tag => tag,
        :image_id => image_id,
        :booted_at => booted_at,
        :host_name => values[3],
        :ipv4_address => values[4]
      }
    }
  end

end

