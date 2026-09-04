# wifi-watchdog

Small runit service for Void systems using `wpa_supplicant` + `dhcpcd`.

It checks Wi-Fi association plus ping reachability. On failure it first asks
`wpa_supplicant` to reconnect/reassociate and renews DHCP. After repeated failed
checks it restarts `wpa_supplicant` and `dhcpcd`.

Install:

```sh
cd void-app-installer/wifi-watchdog
./install-wifi-watchdog
```

Config:

```sh
/etc/default/wifi-watchdog
```

Defaults:

```sh
IFACE=wlp0s20f3
ROUTER=10.0.0.1
TARGET=1.1.1.1
INTERVAL=60
REASSOCIATE_AFTER=1
RESTART_AFTER=3
```

Logs:

```sh
/var/log/wifi-watchdog.log
sv status wifi-watchdog
```
