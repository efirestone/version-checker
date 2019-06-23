# Version Checker

## Summary

This tool allows you to monitor whether or not various firmware and software components (devices) are up to date. It queries the currently installed version of the software on those devices and compares that version to the latest version available from the manufacturer. This information is then published to an MQTT broker where other systems can read and display the information.

The tool supports varying types of components (platforms), such as smart plugs, Docker images, as well as some specific software packages. It is designed so that additional platforms can be added relatively easily.

The tool also has specific support for [Home Assistant](https://www.home-assistant.io), and will publish special [discovery](https://www.home-assistant.io/docs/mqtt/discovery) messages to the MQTT broker which allow the devices to show up automatically, along with two sensors for the currently installed and latest versions of those devices. To use this functionality, make sure that MQTT discovery is enabled in your Home Assistant configuration.

## Vocabulary

- *device* - A "device" refers to any thing that is having its version checked. For some checks this might be a software package and not an actual physical device.

- *platform* - A platform provides support for a class of device firmware, or software package.

- *sweep* - A pass of all configured device version checks. Checks are always executed as a batch but some may take longer than others. The sweep describes the period from when the checks are started to when the last one finishes.

## Configuration

Version Checker is configured using a single YAML file which must be located at `./configuration.yaml`.

### `config` section

- `check_interval` - The interval, in seconds, between version check sweeps. The interval begins at the end of the sweep, when all version checks in the sweep have completed.

```
config:
  # Check every thirty seconds.
  check_interval: 30
```

## `mqtt` section

- `host` - The host name of the MQTT broker. This should not include the `mqtt://` schema.

- `username` - The user name used to log into the MQTT broker.

- `password` - The password for `username` used to log into the MQTT broker.

```
mqtt:
  host: mosquitto.example.com
  username: version_check_user
  password: password123
```
