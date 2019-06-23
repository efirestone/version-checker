# Tasmota

A platform to check the version of devices running [Tasmota](https://github.com/arendst/Sonoff-Tasmota) (such as Sonoffs).

# Configuration YAML

This platform uses a standard config, requiring only the basic values. Tasmota devices that have an admin password configured are not currently supported.

```
version_checks:
  - platform: tasmota
    host: myplug.example.com
    topic: laundry_room/washer
```

# Device Configuration

No special configuration is needed on the Tasmota device itself.