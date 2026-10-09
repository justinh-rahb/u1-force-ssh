# u1-force-ssh

A [Bespok3d](https://github.com/Bespok3d) plugin that forces the stock SSH server on for a Snapmaker U1
running **stock** firmware.

It's for anyone who replaced the stock touchscreen UI (HelixScreen, for example) on stock firmware and
lost SSH after a reboot. On stock firmware, `/etc/init.d/S50dropbear` only starts dropbear when it is
called with `--force`. The stock UI's Root Access setting is what makes that call, so once the stock UI
is gone, SSH stays down. Klipper and Moonraker run as `lava` and can't start a root service. The
Bespok3d daemon runs as root, so this plugin runs the firmware's own
`S50dropbear start --force` at every boot and whenever dropbear is not running.

The user-facing documentation is in [`doc/README.md`](doc/README.md).

## Layout

One plugin at the repository root:

```text
manifest.json            the plugin: one system-bin script, one managed root service
files/bin/force-ssh-run  the watcher the service runs
tests/run.sh             shell tests against a fake S50dropbear and a fake pgrep
doc/                     README, CHANGELOG, ATTRIBUTIONS, LICENSE shipped with the plugin
scripts/check.sh         the gate: tests plus the shared Bespok3d detectors (lib_bespok3d)
```

## Build and sideload

```sh
git submodule update --init --recursive
bash scripts/check.sh
npx github:Bespok3d/b3-builder build --unit plugin --source . --out dist --atom-repo justinh-rahb/u1-force-ssh
# -> dist/u1-force-ssh-<version>.b3
```

Drop the `.b3` onto the Bespok3d app window to sideload it. It shows as coming from an unknown
publisher because it's unsigned, and it installs normally. CI (`pr-build`) also uploads an unsigned
`.b3` as a run artifact on every push.

## Verification of the `--force` gate

The claim that stock `S50dropbear` exits unless it is passed `--force` is checked against stock firmware
`U1_2.0.0.205`. It was not taken on word of mouth. The Extended Firmware build pins that exact stock
image (`vars.mk`, sha256 `e6269eb0...aad7`). At build time it applies
`overlays/common/02-enable-ssh/patches/01-enable-ssh.patch` with `patch -F 0` (zero fuzz). That patch
removes exactly these lines:

```sh
if [ "$2" != "--force" ] ; then
	[ x"$(custom_misc vertype 2>/dev/null)" = x"dbg" ] || exit 0
fi
```

So the gate is present byte for byte in 2.0.0.205. `start` is `$1` and `--force` is `$2`, which makes
the call `S50dropbear start --force`.

## Licence

GPL-3.0, see [LICENSE](LICENSE).
