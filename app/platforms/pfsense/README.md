# pfSense Platform

## Summary

A platform for checking the version of a [pfSense](https://www.pfsense.org) installation.

## Configuration YAML

In addition to the standard `platform`, `host`, and `topic` parameters, the pfSense platform requires authentication parameters:

 - `username` - (Required) The user name used to log into the pfSense dashboard.
 - `password` - (Required) The password for `username` used to log into the pfSense dashboard.

 Also, note that unlike many other platforms the `host` parameter requires a scheme ("http" or "https") and can optionally include a port number if the pfSense dashboard is available on a port other than 80.

```
version_checks:
  - platform: pfsense
    host: https://pfsense.example.com:900
    topic: software/pfsense
    username: pfsense_user
    password: pfsense_users_password
```

## Device Configuration

No special configuration is needed of the pfSense install itself.
