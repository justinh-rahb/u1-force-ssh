# Changelog

## 0.1.0 (2026-10-09)

Initial release. A root managed service that runs the stock firmware's own
`/etc/init.d/S50dropbear start --force` at boot and whenever no dropbear process is running, so SSH
comes back on a stock-firmware U1 whose stock touchscreen UI (and with it the Root Access setting)
has been replaced. Ships one shell script; adds no binary and changes no credentials.

The `--force` gate is confirmed against stock `U1_2.0.0.205` (see `doc/README.md`). Tested against a
fake `S50dropbear` under dash and BusyBox ash (`tests/run.sh`); not yet device-verified on a printer.
