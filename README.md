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

### `mqtt` section

- `host` - The host name of the MQTT broker. This should not include the `mqtt://` schema.

- `username` - The user name used to log into the MQTT broker.

- `password` - The password for `username` used to log into the MQTT broker.

```
mqtt:
  host: mosquitto.example.com
  username: version_check_user
  password: password123
```

### `ssh` section

The SSH section allows customization of SSH behavior. For most people the default behavior will be fine and this section can be omitted.

- `fail_on_host_changes` - (Optional, default false) If set to true then changes to the SSH signature for a given host will cause the corresponding version check to fail. By default this is disabled as most SSH connections will be to internal hosts and devices where the most likely reason for a signature changes is that the device was updated, and not because of a man-in-the-middle attack.

```
ssh:
  fail_on_host_changes: true
```

### `version_checks` section

The `version_checks` section lists all of the devices that you want to run version checks on. See the `platforms` folder for the list of supported platforms, but generally the config will look something like:

```
version_checks:
  - platform: pfsense
    host: https://pfsense.example.com:900
    topic: software/pfsense
    username: pfsense_user
    password: pfsense_users_password

  - platform: tasmota
    host: washerplug.example.com
    topic: laundry_room/washer

  - platform: tasmota
    host: dryerplug.example.com
    topic: laundry_room/dryer
```

## Debugging

### Removing Old Entities

Occasionally sensor entities will get duplicated in Home Assistant. Usually this is the result of changes to the sensors' unique identifiers, either because of a change in Version Checker (sorry, but sometimes it's required), or because you're testing out changes locally.

To clean things up, you'll need to do a few steps:

1. Stop any instances of Version Checker.
1. Stop your MQTT broker and delete its data store to remove any retained messages. For Mosquitto this is `./data/mosquitto.db`.
1. In Home Assistant, go to Configuration -> Entity Registry. Remove all of the entities that are duplicated. Remove *both* versions of the duplicated sensor (or all if there are more than two).
1. Stop Home Assistant. This is important, as otherwise it will overwrite the changes we're about to make in Step 3.
1. In your Home Assistant config folder, edit `<config>/.storage/core.device_registry` to remove the Version Checker based entries. Save your changes.
1. Restart Home Assistant and Version Checker.

## Q & A

**Q**: Why build Version Checker as a separate system and not a Home Assistant component?

**A**: There are two reasons for this: security and flexibility.

Version Checker needs authentication credentials (often including passwordless SSH) to many different systems and devices in your home, and unlike Home Assistant has no need to be exposed publicly in any way as it only communicates through MQTT. By separating Version Checker and Home Assistant we don't give up Version Checker's secrets if someone does manage to infiltrate Home Assistant's rather large attack surface.

Having the two be separate also provides flexibility. Version Checker publishes Home Assistant-specific discovery MQTT messages, but the messages published containing the actual version checks are not Home Assistant-specific in any way and could be read by any system that finds them valuable, such as another home automation platform or home lab dashboard.

**Q**: Why Ruby and not Python like Home Assistant?

**A**: No particular reason other than I know Ruby better than Python and it doesn't need to interface with Home Assistant Python APIs directly.