# Home Assistant Add-Ons Platform

## Summary

A platform for checking the versions of [Add-Ons](https://www.home-assistant.io/addons/) for Home Assistant (previously called Hass.io or Home Assistant OS).

## Configuration YAML

The Home Assistant add-on platform uses the standard `platform`, `host`, and `topic` parameters.

```
version_checks:
  - platform: hass_addons
    host: homeassistant.example.com
    topic: hass/{{addon}}
```

To only check the version number of specific add-ons, add a `monitored` array, using the exact names of add-ons to be checked:

```
version_checks:
  - platform: hass_addons
    host: homeassistant.example.com
    topic: hass/{{addon}}
    monitored:
      - Check Home Assistant configuration
      - Terminal & SSH
```

## Device Configuration

This platform connects to Home Assistant using SSH, so Home Assistant must have SSH enabled, and the machine running version checker must have passwordless access. The easiest way to enable SSH is using the [SSH add-on](https://github.com/home-assistant/hassio-addons/tree/master/ssh).