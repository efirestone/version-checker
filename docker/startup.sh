#!/bin/sh

ED25519_SSH_KEY=/data/.ssh/id_ed25519
RSA_SSH_KEY=/data/.ssh/id_rsa

if [ ! -f $ED25519_SSH_KEY ]; then
  mkdir -p "$(dirname "$ED25519_SSH_KEY")"
  ssh-keygen -o -a 100 -t ed25519 -f $ED25519_SSH_KEY -N "" -q

  echo " "
  echo "New ed25519 SSH key generated."
  echo " "
fi

if [ ! -f $RSA_SSH_KEY ]; then
  mkdir -p "$(dirname "$RSA_SSH_KEY")"
  ssh-keygen -o -a 100 -t rsa -f $RSA_SSH_KEY -N "" -q

  echo " "
  echo "New RSA SSH key generated."
  echo " "
fi

eval "$(ssh-agent -s)"
ssh-add $ED25519_SSH_KEY
ssh-add $RSA_SSH_KEY

echo " "
echo "To configure a device to use the ed25519 SSH key (preferred) use the following command:"
echo " "
echo "   echo \"$(cat "${ED25519_SSH_KEY}.pub")\" | ssh <user>@<device-hostname> 'cat >> .ssh/authorized_keys'"

echo " "
echo "In rare cases a device does not support ed25519 keys. For those devices you can configure an RSA SSH key with the following command:"
echo " "
echo "   echo \"$(cat "${RSA_SSH_KEY}.pub")\" | ssh <user>@<device-hostname> 'cat >> .ssh/authorized_keys'"

echo " "
echo "Some devices may require the SSH keys to be configured using their respective configuration dashboards."

echo " "

CONFIG_FILE=/data/configuration.yaml
if [ ! -f $CONFIG_FILE ]; then
  # Try the config file for Home Assistant add-ons.
  CONFIG_FILE=/data/options.json
fi

ruby /app/version_checker.rb "$CONFIG_FILE"
