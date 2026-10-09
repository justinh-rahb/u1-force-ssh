# Force SSH

Brings SSH back on a Snapmaker U1 running **stock** firmware, and keeps it on, even when the stock
touchscreen UI has been replaced and its Root Access setting is gone.

## The problem it solves

On stock U1 firmware, the SSH server (dropbear) does not start on its own. Its boot script,
`/etc/init.d/S50dropbear`, opens with:

```sh
if [ "$2" != "--force" ] ; then
	[ x"$(custom_misc vertype 2>/dev/null)" = x"dbg" ] || exit 0
fi
```

A retail printer is a release build, not `dbg`, so the plain `start` that runs at boot exits without
starting anything. The stock touchscreen's **Settings > Maintenance > Root Access** is what runs
`S50dropbear start --force` and brings SSH up.

Install something that replaces the stock touchscreen UI (HelixScreen, for example) and nothing calls
`--force` any more. The next reboot leaves SSH down, PuTTY says `Connection refused`, and there is no
setting left to turn it back on. Fluidd and Bespok3d still work, because they do not need SSH, but
Klipper and Moonraker run as the unprivileged user `lava` and cannot start a root service from a macro.

The Bespok3d daemon runs as root, so a Bespok3d plugin can.

## What it does

Runs one small root service, `u1-force-ssh`, started at every boot by the Bespok3d boot runner and
immediately on install. Every 30 seconds it checks whether a `dropbear` process exists, and if not runs
the firmware's own:

```sh
/etc/init.d/S50dropbear start --force
```

That is the same command the stock Root Access setting runs. Nothing else changes:

- no new binary: it starts the dropbear already in your firmware;
- no new port: SSH is on port 22 as before;
- no password or key change: log in with the same account and password you used before SSH went away
  (`root`, with the password you used when Root Access was on; the stock default is `snapmaker`).

## Rescue: SSH is gone and the stock screen is gone too

1. In the Bespok3d app, install **Force SSH** (or drop the `u1-force-ssh-<version>.b3` file onto the
   app window and install it).
2. Wait a few seconds; no reboot needed. The service starts on install.
3. `ssh root@<printer-ip>`.

From there you can uninstall whatever replaced the stock UI, install a firmware, or keep going as you
were. SSH will also come back by itself after every reboot while this plugin is installed.

## Uninstalling

Uninstalling stops the watcher, and only the watcher: dropbear is left running so an SSH session you
are using is not cut off. From the next reboot, SSH is back under the stock Root Access setting's
control, which means it stays off unless the stock UI turns it on.

## Things to know

- **SSH is forced on.** While installed, turning Root Access off in the stock UI does not keep SSH
  off: the watcher starts it again within 30 seconds. Uninstall the plugin if you want SSH off.
- **Stock firmware only.** Extended Firmware (paxx12) already removes the `--force` gate and manages
  SSH from its own `firmware-config` page; you do not need this plugin there.
- **Logs** are in `/userdata/bespok3d/var/log/u1-force-ssh.log`. Each forced start is logged.
- **Verified against:** stock `U1_2.0.0.205`. The `--force` gate above matches that firmware exactly:
  the Extended Firmware build applies a patch removing these lines to `U1_2.0.0.205` with zero fuzz
  (`overlays/common/02-enable-ssh`), so any change to them would fail its build.
