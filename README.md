# CryptHelper
a cryptsetup helper script

Features:
* Streamline mounting / unmounting of LUKS drives
* Does *not* need to be run as root, uses `sudo` when needed instead
  * It also works with `doas`, if you use that instead
  * It even works if you have both, for some reason (see `-S` in the help)
* Interactive, but parameters can be specified ahead of time with options

Requires `cryptsetup`

`sudo` / `doas` are *technically* not required, but running internet scripts directly as root is bad practice

Usage:
```
crypthelp [options]
Options:
-d     Specify the device name (eg: /dev/sda)
-D     Bypasses the dependancy check (careful!)
-h     Displays this help message
-l     Specify the mount location (eg: '/mnt/cryptdrive')
-m     Specify the mapper name (eg: 'cryptdrive')
-M     Mount Mode
-R     Allows you to run the script as the root user (careful!)
-S     (if both sudo and doas are installed) forces the use of sudo
-U     Unmount Mode
-y     Skip confirmation dialogs / splash text
```

Some example commands:

* `crypthelper -My -d /dev/sde1 -m cryptodrive -l /mnt/crypt`
  * [M]ounts the [d]evice `/dev/sde1` at the [l]ocation `/mnt/crypt`, with a device [m]apper named `cryptodrive`
  * the `-y` option just skips some confirmation messages
* `crypthelper -Uy -m cryptodrive -l /mnt/crypt`
  * [U]nmounts the [m]apper `cryptodrive` from the [l]ocation `/mnt/crypt`
