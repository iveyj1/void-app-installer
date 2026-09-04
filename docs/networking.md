# Networking Notes

Void base installs occasionally leave Wi-Fi in a state where the interface exists but `wpa_supplicant` does not associate or DHCP never obtains a route. This installer makes the normal service setup explicit and provides a repair command for manual recovery.

## Normal services

This setup uses:

- `wpa_supplicant` for Wi-Fi authentication/association
- `dhcpcd` for DHCP, routes, and resolver generation
- `runit` for service supervision

Enabled services:

```sh
/var/service/wpa_supplicant -> /etc/sv/wpa_supplicant
/var/service/dhcpcd         -> /etc/sv/dhcpcd
```

## Installer behavior

Run with Wi-Fi credentials when bootstrapping a new machine:

```sh
VOID_WIFI_SSID='your ssid' VOID_WIFI_PSK='your passphrase' ./install-void-apps
```

The installer writes `/etc/wpa_supplicant/wpa_supplicant.conf` only if it does not already exist and both variables are provided.

When `VOID_WIFI_SSID` and `VOID_WIFI_PSK` are supplied, the installer rewrites `/etc/wpa_supplicant/wpa_supplicant.conf` from those values. This is intentional: explicit credentials on the installer command line mean “make the installed Wi-Fi config match these values,” even if a stale config already exists.

Before the package transaction, it first checks whether the network is already reachable. If it is, the live connection is left alone. If not, it tries to bring Wi-Fi up immediately using the same sequence as the old manual `setnetwork` approach: unblock Wi-Fi, reset the interface, start `wpa_supplicant` in the background, request DHCP with `dhcpcd`, then wait briefly for reachability. This can only work if `wpa_supplicant` and `dhcpcd` are already present in the base/live environment.

It writes `/etc/sv/wpa_supplicant/conf` when the service directory exists:

```sh
WPA_INTERFACE=wlp0s20f3
CONF_FILE=/etc/wpa_supplicant/wpa_supplicant.conf
# DRIVER is omitted by default so wpa_supplicant chooses automatically.
# Set VOID_WIFI_DRIVER=nl80211 if an explicit driver is desired.
```

`VOID_WIFI_IFACE` can override interface detection. After installing packages, the installer restarts the persistent `wpa_supplicant` and `dhcpcd` runit services only if the network is not already reachable, so it does not tear down a working live connection.

## Manual repair

If networking is wedged:

```sh
./void-network-repair
```

That command:

1. stops `dhcpcd` and `wpa_supplicant`
2. kills stale helper processes
3. removes `/run/wpa_supplicant`
4. unblocks Wi-Fi
5. resets the interface down/up
6. disables client Wi-Fi power save
7. restarts `wpa_supplicant`
8. restarts `dhcpcd`
9. prints service/link/address/route status

This replaces the older hand-written `~/setnetwork` style command with a generic version that uses the normal config files and does not contain secrets.

## Diagnostics

Capture a snapshot quickly when the problem appears:

```sh
./wifi-diag
```

The diagnostic script uses passwordless/non-interactive `sudo -n` for privileged checks when available, so running it from a user shell can still capture service status, `wpa_cli`, watchdog logs, and kernel Wi-Fi messages without hanging for a password.

By default it uses:

```sh
IFACE=wlp0s20f3
ROUTER=10.0.0.1
TARGET=1.1.1.1
```

Override as needed:

```sh
IFACE=wlan0 ROUTER=192.168.1.1 TARGET=1.1.1.1 ./wifi-diag
```

Logs are written to:

```sh
~/.local/share/wifi-diag/
```

## Useful checks

```sh
ip -br link
ip -br addr
ip route
cat /etc/resolv.conf
rfkill list
sv status wpa_supplicant dhcpcd
iw dev wlp0s20f3 link
iw dev wlp0s20f3 get power_save
```

Restart services:

```sh
sudo sv restart wpa_supplicant
sudo sv restart dhcpcd
```

Force reassociation and DHCP renew:

```sh
sudo wpa_cli -i wlp0s20f3 reassociate
sudo dhcpcd -n wlp0s20f3
```

## Wi-Fi reconnect watchdog

Install the optional watchdog service:

```sh
cd void-app-installer/wifi-watchdog
./install-wifi-watchdog
```

It installs `/usr/local/sbin/wifi-watchdog`, creates `/etc/sv/wifi-watchdog`, enables `/var/service/wifi-watchdog`, and reads config from:

```sh
/etc/default/wifi-watchdog
```

The watchdog checks association and ping reachability. It first runs `wpa_cli reconnect`/`reassociate` plus `dhcpcd -n`; after repeated failures it restarts `wpa_supplicant` and `dhcpcd`. Logs go to `/var/log/wifi-watchdog.log`.

## Persistent DNS override

The installer writes:

```text
/etc/resolv.conf.head
```

with:

```text
nameserver 1.1.1.1
```

`dhcpcd` prepends this whenever regenerating `/etc/resolv.conf`, so DNS does not depend only on the router DNS proxy.

## Intel Wi-Fi power options

The installer writes:

```text
/etc/modprobe.d/iwlwifi-no-power-save.conf
```

with:

```conf
options iwlwifi power_save=0 power_level=0 uapsd_disable=3
options iwlmvm power_scheme=1
```

These options are intended to reduce missed-beacon/DHCP stalls on Intel Wi-Fi. They fully take effect after reboot or module reload.
