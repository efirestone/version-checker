# Docker Platform

## Summary

A platform for checking the versions of images in a given Docker instance. Unlike many platforms, this platform will publish messages for multiple devices, with each monitored image being treated as its own device.

## Configuration YAML

In addition to the standard `platform`, `host`, and `topic` parameters, the Docker platform supports some additional parameters:

 - `username` - (Required) The user name used to log into the OS running Docker. This user must have passwordless SSH configured as discussed below and have permission to run `docker images`

 - `monitored_repositories` - (Optional, default is all repositories) By default this platform will monitor and publish version check messages for all images currently known to `docker images`. To restrict the monitoring to a specific subset of those images the `monitored_repositories` array can be defined.

The Docker platform publishes information for each image as a separate device, and as such needs a unique topic for each image. To achieve this the `topic` parameter should be specified as a template using the token `{{repository}}` representing the image repository's name, such as "gitlab/gitlab-ce".

```
version_checks:
  - platform: docker
    host: docker.example.com
    topic: "docker/{{repository}}"
    username: user_with_docker_permissions
    monitored_repositories:
      - gitlab/gitlab-ce
      - homeassistant/home-assistant
```

## Device Configuration

The Docker version checker relies on SSH and the user specified needs to have [passwordless SSH access]((https://www.debian.org/devel/passwordlessssh) to the operating system that is running Docker. Additionally the user must have permission to run `docker images`.
