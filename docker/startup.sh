#!/bin/sh

ED25519_SSH_KEY=/config/.ssh/id_ed25519
RSA_SSH_KEY=/config/.ssh/id_rsa

if [ ! -f $ED25519_SSH_KEY ]; then
  mkdir -p "$(dirname "$ED25519_SSH_KEY")"
  ssh-keygen -o -a 100 -t ed25519 -f $ED25519_SSH_KEY -N "" -q

  echo ""
  echo "New ed25519 SSH key generated. Add this key to your devices to allow Version Checker to authenticate to them. For each device, run this command:"
  echo "    ssh-copy-id -i </volume/mounted/config>/.ssh/id_ed25519 <user>@<device_host>"
  echo ""
fi

if [ ! -f $RSA_SSH_KEY ]; then
  mkdir -p "$(dirname "$RSA_SSH_KEY")"
  ssh-keygen -o -a 100 -t rsa -f $RSA_SSH_KEY -N "" -q

  echo ""
  echo "New RSA SSH key generated. The ed25519 key should be preferred over this one if a device supports it. Add this key to devices to allow Version Checker to authenticate to them. For each device, run this command:"
  echo "    ssh-copy-id -i </volume/mounted/config>/.ssh/id_rsa <user>@<device_host>"
  echo ""
fi

eval "$(ssh-agent -s)"
ssh-add $ED25519_SSH_KEY
ssh-add $RSA_SSH_KEY

CONFIG_FILE=/config/configuration.yaml

ruby /app/version_checker.rb "$CONFIG_FILE"
