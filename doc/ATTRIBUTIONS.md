# Attributions - u1-force-ssh

**Plugin author:** justinh-rahb

Starts the Snapmaker U1's own stock SSH server.

| Upstream project | Author | Licence | Needed at runtime | Code ships in this package |
| --- | --- | --- | --- | --- |
| Snapmaker U1 stock firmware, `/etc/init.d/S50dropbear` and dropbear | Snapmaker | per the firmware | yes | no |

Nothing from the firmware ships in this package: the plugin calls the init script and the dropbear binary
already on the printer. The `--force` gate it relies on is documented by the Extended Firmware overlay
`common/02-enable-ssh` (paxx12, GPL-3.0), which patches the same lines out of stock U1_2.0.0.205; no code
from that overlay ships here.
