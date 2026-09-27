# wifi-watchdog

Void/runit Wi-Fi recovery for `wpa_supplicant` + `dhcpcd` (IPv4).

## Install / upgrade

```sh
sudo ./install-wifi-watchdog
```

The installer backs up changed system files under `/var/backups/wifi-watchdog/`.
It migrates the old 60-second default to 10 seconds, removes obsolete failure-count
settings, and otherwise retains `/etc/default/wifi-watchdog`. Custom intervals
are retained. It restarts the watchdog and **log services only**, not networking.

It replaces the packaged `vlogger` log/run scripts for wpa_supplicant and dhcpcd
with `svlogd -tt`: normal daemon output is saved in root-only directories
`/var/log/wpa_supplicant/` and `/var/log/dhcpcd/`, rotated at 1 MiB, five archives.
Package upgrades may replace those log/run scripts; reapply the installer if so.
No verbose supplicant debugging or key logging is enabled.

To roll back, restore the backed-up files to their original paths and restart
`wifi-watchdog`, `wpa_supplicant/log`, and `dhcpcd/log` with `sv restart`.

## Recovery policy

- Poll every 10 seconds. Newly detected failures get a 10-second grace period.
- If disconnected: request reconnect, check again next interval, explicitly
  request reassociate, then restart only wpa_supplicant if still disconnected.
- An in-progress authentication gets one additional interval before intervention.
- If associated but lacking a global IPv4 address or default route: renew DHCP,
  then restart only dhcpcd if the problem persists.
- An unreachable gateway alone **never** causes reassociation or service restart.
  There is no external internet ping trigger. Gateways may filter ICMP; this
  conservative policy also leaves associated-but-stalled radio links untouched.
- Restarts share a cooldown: 120 seconds initially, doubling to at most 900.
  Five minutes of verified health resets it. Recovery remains monitored during
  cooldown. Restarting the watchdog itself resets its in-memory backoff.

Normally a persistent disconnection gets a service restart about 30–40 seconds
from onset, plus command execution time. No resume hook is installed: polling
handles wake-ups without another integration point. Association state, not a
successful command exit, determines escalation.

## Logs / configuration

`/var/log/wifi-watchdog.log` contains state transitions, command responses and
exit status, pre-action state, cooldown decisions, and verified recovery with
time since first observed failure. It rotates at 1 MiB with two archives and
uses root-only permissions. `FAIL` from wpa_cli counts as failure even with exit
status zero. Commands have an 8-second timeout.

Defaults are in `wifi-watchdog.conf`; override in `/etc/default/wifi-watchdog`.
`IFACE` selects the Wi-Fi interface. The gateway is derived from its route rather
than a hard-coded LAN address. `GRACE`, `INTERVAL`, `RESTART_COOLDOWN`,
`MAX_BACKOFF`, `STABLE_RESET`, `COMMAND_TIMEOUT`, `PING_TIMEOUT`, `LOG`, and
`LOG_MAX_BYTES` are configurable. Numeric durations must be positive seconds
(`GRACE` may be zero). Do not run multiple watchdog instances for one interface.

The companion `../wifi-diag` includes service logs, supplicant state and kernel
suspend/resume events. Run as root for complete evidence; failed reads are shown.
Logs contain SSIDs/MACs/IPs: redact before sharing.

## Tests

```sh
python3 test_watchdog.py
sh -n wifi-watchdog install-wifi-watchdog ../wifi-diag
```

Tests mock network actions; they do not restart services or change connectivity.
