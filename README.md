# Void Installer

Personal Void Linux bootstrap scripts for turning a fresh Void base install into the usual workstation/laptop environment.

The repository is intentionally standalone so it can be fetched over HTTPS on a new machine before SSH keys are configured.

## What this installs/configures

Default install:

- XBPS refresh/upgrade
- core CLI/build tools
- Wi-Fi/networking basics: `wpa_supplicant`, `dhcpcd`, `iw`, `rfkill`
- XLibre/dwm desktop base
- PipeWire/WirePlumber audio integration
- fonts, including global Nerd Fonts
- suckless tools from GitHub: `dmenu`, `dwm`, `st-reflow`, `dwmblocks`
- tmux plugin manager
- Python venv at `~/.local/bin/venv`
- an ed25519 SSH key if one does not already exist
- Brave browser via Flatpak
- global git user defaults

Optional groups:

- `--xfce`: Xfce plus Breeze/Plasma-style appearance packages
- `--cad`: FreeCAD, KiCad, OpenSCAD, and PrusaSlicer Flatpak
- `--network`: CIFS and Samba tools
- `--extras`: cloc, expect, and Pi coding agent
- `--dell-hardware-tuning`: installs/enables a Dell laptop runit service for NVMe latency and keyboard backlight timeout tuning
- `--all`: all non-hardware-specific optional groups

## Quick start on a fresh Void install

```sh
sudo xbps-install -Syu git
cd ~
git clone https://github.com/YOURUSER/void-installer.git
cd void-installer
VOID_WIFI_SSID='your ssid' VOID_WIFI_PSK='your passphrase' \
VOID_GIT_USER_NAME='Your Name' VOID_GIT_USER_EMAIL='you@example.com' \
./install-void-apps --all
```

If `git` is not available yet but `curl` or `wget` is, download the repo archive from GitHub after creating it and run the same installer from the extracted directory.

Do **not** commit Wi-Fi passphrases. Pass them only through environment variables or configure `/etc/wpa_supplicant/wpa_supplicant.conf` manually.

## Networking bootstrap

The installer configures the normal Void/runit network path instead of relying on an ad-hoc startup script:

- creates `/etc/wpa_supplicant/wpa_supplicant.conf` when `VOID_WIFI_SSID` and `VOID_WIFI_PSK` are set
- detects the Wi-Fi interface, or uses `VOID_WIFI_IFACE`
- leaves an already-working live network alone; if the network is down, starts Wi-Fi immediately with `wpa_supplicant`/`dhcpcd` before package installation when those tools are already available
- writes `/etc/sv/wpa_supplicant/conf` with `WPA_INTERFACE` and `CONF_FILE`; `DRIVER` is written only when `VOID_WIFI_DRIVER` is set
- enables and restarts `/var/service/wpa_supplicant` and `/var/service/dhcpcd` for the installed system
- unblocks Wi-Fi, brings the interface up, and disables client Wi-Fi power save
- writes `/etc/resolv.conf.head` so `dhcpcd` prepends a reliable DNS resolver
- writes Intel Wi-Fi module options under `/etc/modprobe.d/iwlwifi-no-power-save.conf`

Useful environment variables:

| Variable | Default | Purpose |
|---|---:|---|
| `VOID_WIFI_SSID` | unset | SSID used to create `/etc/wpa_supplicant/wpa_supplicant.conf` |
| `VOID_WIFI_PSK` | unset | Wi-Fi passphrase; never stored in this repo |
| `VOID_WIFI_IFACE` | auto-detected | Override Wi-Fi interface, e.g. `wlp0s20f3` |
| `VOID_WIFI_CONF` | `/etc/wpa_supplicant/wpa_supplicant.conf` | wpa_supplicant config path |
| `VOID_WIFI_DNS` | `1.1.1.1` | DNS server prepended by `dhcpcd` and ping target for bootstrap checks |
| `VOID_WIFI_WAIT_SECONDS` | `30` | How long to wait for Wi-Fi reachability during bootstrap |
| `VOID_WIFI_DRIVER` | unset | Optional `wpa_supplicant` driver override, e.g. `nl80211`; unset matches `~/setnetwork` default driver selection |
| `VOID_GIT_USER_NAME` | unset | Optional global git `user.name` |
| `VOID_GIT_USER_EMAIL` | unset | Optional global git `user.email` |

Manual repair tool if Void's installer or services wedge Wi-Fi:

```sh
./void-network-repair
```

Diagnostics:

```sh
./wifi-diag
```

Optional reconnect watchdog:

```sh
cd wifi-watchdog
./install-wifi-watchdog
```

## Package groups

Package groups live in `packages.d/` and are installed by `install-void-package-groups`.

```sh
./install-void-package-groups core
./install-void-package-groups core xfce cad
./install-void-package-groups all
```

Group files are plain newline-separated package names. Blank lines and comments beginning with `#` are ignored.

## Scripts

| Path | Purpose |
|---|---|
| `install-void-apps` | Main end-to-end workstation installer |
| `install-void-package-groups` | Installs named package groups from `packages.d/` |
| `dell-hardware-tuning/` | Optional Dell laptop boot-time hardware tuning service installed by `--dell-hardware-tuning` |
| `wifi-watchdog/` | Optional runit Wi-Fi reconnect watchdog service |
| `add-package-void` | Helper to append a package to `packages.d/core` and optionally install it |
| `void-network-repair` | Manual Wi-Fi/runit repair sequence |
| `wifi-diag` | Captures Wi-Fi/network diagnostic snapshots |

## Customization knobs

- `SUCKLESS_DIR`: destination for suckless source clones; default `~/suckless`
- `VOID_WIFI_*`: networking bootstrap controls described above
- `VOID_GIT_USER_NAME` / `VOID_GIT_USER_EMAIL`: optional global git identity
- edit package group files under `packages.d/`

## After installation

Start a graphical session with:

```sh
startx ~/.xinitrc dwm
# or
startx ~/.xinitrc xfce
```

`install-void-apps` only refreshes a managed `.xinitrc` that it created previously. It should not overwrite a custom `.xinitrc`.

## Notes and caveats

- This is a personal installer, not a general Void distribution installer.
- It assumes `sudo`, runit, and XBPS.
- Several steps require internet access after networking is up.
- `install-void-apps` installs Flatpak applications and pulls external code/fonts from GitHub.
- Pi is installed only when `--extras` or `--all` is selected.
- The Intel Wi-Fi modprobe options are harmless on non-Intel systems but only affect Intel Wi-Fi after module reload/reboot.
