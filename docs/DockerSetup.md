## Configuration

An external volume should be mounted to `/config` as part of running the container. Version Checker will look for a configuration file at `/config.configuration.yaml`, which should contain your device check definitions and any other configuration.

## SSH Trusted Key

For many version check platforms the Docker container needs a trusted SSH key set up with those devices. The docker image will generate these keys automatically into the mounted `/config` directory, but they must manually be copied over to each device.

There are two notable keys which are generated at `/config/.ssh/id_ed25519.pub` and `/config/.ssh/id_rsa.pub`. Most devices will support ED25519 these days, and that key should be preferred, but some devices will require using the older RSA key instead. Check the platform-specific instructions for help in getting these keys onto your devices.