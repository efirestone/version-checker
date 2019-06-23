# UniFi Platform

## Summary

A platform for checking the firmware version of various physical UniFi devices, such as switches, access points, etc.

## Configuration YAML

In addition to the standard `platform`, `host`, and `topic` fields, the UniFi platform requires an additional configuration option:

 - `username` - (Required) The user name used to log into the UniFi device. This user must have passwordless SSH configured as discussed below.

```
version_checks:
  - platform: unifi
    host: den.ap.example.com
    topic: "den/ap"
    username: unifi_user
```

## Device Configuration

The UniFi version checker relies on SSH being configured with a [trusted public key](https://www.debian.org/devel/passwordlessssh) on each device.

UniFi devices do not currently support the newer ED25519 security keys, so we'll use the older RSA keys instead. The key can be added once in the UniFi dashboard and it will be deployed to all managed devices by following [these instructions](https://help.ubnt.com/hc/en-us/articles/235247068-UniFi-Adding-SSH-Keys-to-UniFi-Devices).

Note that if you do manually modify the `/etc/dropbear/authorized_keys` file on the device it will be overwritten on the next restart, so using the dashboard is the only way to change it in a persistent manner.
