# Plex Platform

## Summary

A platform for checking the version of a [Plex Media Server](https://plex.tv).

## Configuration YAML

In addition to the standard `platform`, `host`, and `topic` parameters, the Plex platform requires an auth token:

 - `auth_token` - (Required) A token which gives access to the logged-in Plex information. This token can be found by following [these instructions](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/).

Also, note that unlike many other platforms the `host` parameter requires a scheme ("http" or "https") and can optionally include a port number if the Plex server is available on a port other than 80.

```
version_checks:
  - platform: plex
    host: https://plex.example.com:32400
    topic: software/plex
    auth_token: AbCdEFgH98765
```

## Device Configuration

No special configuration is needed of the Plex Media Server install itself.
