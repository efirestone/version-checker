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

# Confirm the Firewall rule is configured (if Windows Firewall is enabled).
# It should be created automatically by setup.
# There should be a firewall rule named "OpenSSH-Server-In-TCP", which should be enabled 
Get-NetFirewallRule -Name *ssh*
```

At this point the SSH server is operational. Next is to [add a public key](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement#deploying-the-public-key) for our client machine so that no password is required. To do so, from the client machine that will be running version_checker, run the commands below.

Where the `authorized_keys` file lives on the Windows machine will depend on whether or not the user you're logging in as is an administrator on that machine. If the user _is_ an administrator then set `BI_KEYS` to `C:\ProgramData\ssh\administrators_authorized_keys`. If the user is not an administrator then use `C:\ProgramData\ssh\authorized_keys`. If you're unsure which to use, you can check the `AuthorizedKeysFile` value at the bottom of the file `C:\ProgramData\ssh\ssh_config` on the Windows machine. For more info about `authorized_keys` and permissions, see [this article](https://github.com/PowerShell/Win32-OpenSSH/wiki/Security-protection-of-various-files-in-Win32-OpenSSH).

```
# Make sure that the .ssh directory exists in your server's home folder
BI_USER=<Windows user>
BI_HOST=<Windows hostname or IP>
BI_KEYS=<See above>

ssh $BI_USER@$BI_HOST mkdir C:\\ProgramData\\ssh

# Use scp to copy the public key file generated previously to authorized_keys on your server
scp ~/.ssh/id_ed25519.pub $BI_USER@$BI_HOST:$BI_KEYS

# Appropriately ACL the authorized_keys file on your server
ssh $BI_USER@$BI_HOST "icacls $BI_KEYS /inheritance:r && icacls $BI_KEYS /grant SYSTEM:(F) && icacls $BI_KEYS /grant BUILTIN\Administrators:(F)"
```