# Home Assistant Platform

## Summary

A platform for checking the version of [Home Assistant](https://www.home-assistant.io/hassio/) (previously called Hass.io or Home Assistant OS).

## Configuration YAML

The Home Assistant platform uses the standard `platform`, `host`, and `topic` parameters.

```
version_checks:
  - platform: hass_os
    host: homeassistant.example.com
    topic: hass/os
```

## Device Configuration

This platform connects to Home Assistant using SSH, so Home Assistant must have SSH enabled, and the machine running version checker must have passwordless access. The easiest way to enable SSH is using the [SSH add-on](https://github.com/home-assistant/hassio-addons/tree/master/ssh).