# Blue Iris Platform

## Configuration YAML

In addition to the standard `platform`, `host`, and `topic` fields, the Blue Iris platform supports these additional configuration options:

 - `username` - (Required) The user name used to log into the Windows machine. This user must have passwordless SSH configured as discussed below.

 - `include_major_updates` = (Optional, default `true`) If set to `false` then updates to new major versions are ignored. For example, if the currently installed version is 4.0.8.6 then new 4.X versions will be considered, but 5.X versions will be ignored.

```
version_checks:
  - platform: blue_iris
    host: blueiris.example.com
    topic: "software/blue_iris"
    username: MyWindowsUser
    include_major_updates: false
```

## Device Configuration

The Blue Iris version checker relies on SSH being configured with a [trusted public key](https://www.debian.org/devel/passwordlessssh). Therefore, the Windows machine that is running Blue Iris needs an SSH server installed and running.

To [install the OpenSSH server on Windows 10](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse):

- From the Start menu search bar, search for "PowerShell"
- Right-click Windows PowerShell and select "Run as administrator"
- In PowerShell run the following command:

```
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```
then configure the service:
```
Start-Service sshd
# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'
# Confirm the Firewall rule is configured. It should be created automatically by setup. 
Get-NetFirewallRule -Name *ssh*
# There should be a firewall rule named "OpenSSH-Server-In-TCP", which should be enabled 
```

At this point the SSH server is operational. Next is to [add a public key](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement#deploying-the-public-key) for our client machine so that no password is required. To do so, from the client machine that will be running version_checker, run this command:

```
# Make sure that the .ssh directory exists in your server's home folder
ssh <user>@<host> mkdir C:\\Users\\<user>\\.ssh

# Use scp to opy the public key file generated previously to authorized_keys on your server
scp ~/.ssh/id_ed25519.pub <user>@<host>:C:\\Users\\<user>\\.ssh\\authorized_keys

# Appropriately ACL the authorized_keys file on your server
# This failed, but wasn't required for me on Windows 10.
ssh --% <user>@<host> powershell -c $ConfirmPreference = 'None'; Repair-AuthorizedKeyPermission C:\Users\<user>\.ssh\authorized_keys
```