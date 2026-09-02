#!/bin/sh
# Give Void Linux/Xfce a KDE Plasma (Breeze) look.
# Run this as the desktop user, not as root.
set -eu

MODE=dark
INSTALL_PACKAGES=1
RESTART_PANEL=1

usage() {
    cat <<'EOF'
Usage: ./plasma-look-xfce.sh [--light|--dark] [--no-packages] [--no-restart]
       ./plasma-look-xfce.sh --restore [BACKUP]

BACKUP defaults to the newest ~/.local/state/plasma-look-xfce/*.tar.gz file.
Run from inside an Xfce graphical session so xfconf-query can reach xfconfd.
EOF
}

restore_backup() {
    archive=${1:-}
    if [ -z "$archive" ]; then
        archive=$(find "$HOME/.local/state/plasma-look-xfce" -maxdepth 1 -name '*.tar.gz' -type f 2>/dev/null | sort | tail -n 1 || true)
    fi
    [ -n "$archive" ] && [ -f "$archive" ] || {
        echo "No backup archive found." >&2
        exit 1
    }
    echo "Restoring $archive"
    xfce4-panel -q 2>/dev/null || true
    pkill xfconfd 2>/dev/null || true
    rm -rf "$HOME/.config/xfce4"
    tar -xzf "$archive" -C "$HOME"
    if [ -n "${DISPLAY:-}" ]; then
        (xfce4-panel >/dev/null 2>&1 &)
    fi
    echo "Restored. Log out and back in if any old settings remain cached."
}

if [ "${1:-}" = "--restore" ]; then
    restore_backup "${2:-}"
    exit 0
fi

while [ "$#" -gt 0 ]; do
    case $1 in
        --light) MODE=light ;;
        --dark) MODE=dark ;;
        --no-packages) INSTALL_PACKAGES=0 ;;
        --no-restart) RESTART_PANEL=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[ "$(id -u)" -ne 0 ] || {
    echo "Run this as your normal desktop user; the script invokes sudo only for packages." >&2
    exit 1
}
if [ "$INSTALL_PACKAGES" -eq 1 ]; then
    package_installer=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/install-void-package-groups
    [ -x "$package_installer" ] || {
        echo "Missing package-group installer: $package_installer" >&2
        exit 1
    }
    "$package_installer" xfce
fi

command -v xfconf-query >/dev/null || {
    echo "xfconf-query is missing; install the optional xfce package group first." >&2
    exit 1
}
# xfconf-query requires the user's graphical D-Bus session.
xfconf-query -l >/dev/null 2>&1 || {
    echo "Cannot contact xfconfd. Run this in a terminal inside your Xfce session." >&2
    exit 1
}

state_dir="$HOME/.local/state/plasma-look-xfce"
mkdir -p "$state_dir"
backup="$state_dir/xfce-$(date +%Y%m%d-%H%M%S).tar.gz"
if [ -d "$HOME/.config/xfce4" ]; then
    tar -czf "$backup" -C "$HOME" .config/xfce4
    echo "Backup: $backup"
fi

# Install a small, pinned Xfwm theme. It contains only theme assets.
xfwm_commit=a781844cb11b9c077a0ede5c5d2ec5cbb3ae1d08
xfwm_sha256=4135a60bd1d111cd621c1c9d046a1d5b66e452ea51eac155c412428ce822b0e3
if command -v curl >/dev/null && command -v sha256sum >/dev/null; then
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
    archive="$tmpdir/xfwm-breeze.tar.gz"
    curl -fsSL "https://github.com/mjkim0727/xfwm4-breeze/archive/$xfwm_commit.tar.gz" -o "$archive"
    printf '%s  %s\n' "$xfwm_sha256" "$archive" | sha256sum -c - >/dev/null
    tar -xzf "$archive" -C "$tmpdir"
    mkdir -p "$HOME/.themes"
    rm -rf "$HOME/.themes/Plasma-Breeze" "$HOME/.themes/Plasma-Breeze-Dark"
    cp -R "$tmpdir/xfwm4-breeze-$xfwm_commit/xfwm-breeze-light" "$HOME/.themes/Plasma-Breeze"
    cp -R "$tmpdir/xfwm4-breeze-$xfwm_commit/xfwm-breeze-dark" "$HOME/.themes/Plasma-Breeze-Dark"
    rm -rf "$tmpdir"
    trap - EXIT HUP INT TERM
else
    echo "Warning: curl/sha256sum unavailable; retaining the current Xfwm decoration." >&2
fi

# Set an xfconf scalar, creating it with the requested type when absent.
xset() {
    channel=$1 property=$2 type=$3 value=$4
    if xfconf-query -c "$channel" -p "$property" >/dev/null 2>&1; then
        xfconf-query -c "$channel" -p "$property" -s "$value"
    else
        xfconf-query -c "$channel" -p "$property" -n -t "$type" -s "$value"
    fi
}
if [ "$MODE" = dark ]; then
    gtk_theme=Breeze-Dark
    icon_theme=breeze-dark
    xfwm_theme=Plasma-Breeze-Dark
else
    gtk_theme=Breeze
    icon_theme=breeze
    xfwm_theme=Plasma-Breeze
fi

# Toolkit, typography, and window decoration.
xset xsettings /Net/ThemeName string "$gtk_theme"
xset xsettings /Net/IconThemeName string "$icon_theme"
xset xsettings /Gtk/CursorThemeName string breeze_cursors
xset xsettings /Gtk/CursorThemeSize int 24
xset xsettings /Gtk/FontName string "Noto Sans 10"
xset xsettings /Gtk/MonospaceFontName string "Noto Sans Mono 10"
xset xsettings /Gtk/DecorationLayout string "icon,menu:minimize,maximize,close"
xset xsettings /Gtk/DialogsUseHeader bool false
xset xsettings /Xft/Antialias int 1
xset xsettings /Xft/Hinting int 1
xset xsettings /Xft/HintStyle string hintslight
xset xsettings /Xft/RGBA string rgb

[ -d "$HOME/.themes/$xfwm_theme/xfwm4" ] && xset xfwm4 /general/theme string "$xfwm_theme"
xset xfwm4 /general/button_layout string "O|HMC"
xset xfwm4 /general/title_alignment string left
xset xfwm4 /general/title_font string "Noto Sans Medium 10"
xset xfwm4 /general/use_compositing bool true
xset xfwm4 /general/show_frame_shadow bool true
xset xfwm4 /general/show_dock_shadow bool true
xset xfwm4 /general/shadow_opacity int 45
xset xfwm4 /general/tile_on_move bool true
xset xfwm4 /general/snap_to_border bool true
xset xfwm4 /general/snap_to_windows bool true
xset xfwm4 /general/snap_width int 10
xset xfwm4 /general/cycle_preview bool true
xset xfwm4 /general/cycle_tabwin_mode int 1

# Rebuild one bottom panel. Plugin order:
# launcher, grouped tasks, expanding spacer, tray, volume, clock, show desktop.
xfce4-panel -q 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels -r -R 2>/dev/null || true
xfconf-query -c xfce4-panel -p /plugins -r -R 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels -n -a -t int -s 1
xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -n -a \
    -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 \
    -t int -s 5 -t int -s 6 -t int -s 7
xset xfce4-panel /panels/panel-1/position string 'p=10;x=0;y=0'
xset xfce4-panel /panels/panel-1/position-locked bool true
xset xfce4-panel /panels/panel-1/length int 100
xset xfce4-panel /panels/panel-1/length-adjust bool false
xset xfce4-panel /panels/panel-1/size int 44
xset xfce4-panel /panels/panel-1/nrows int 1
xset xfce4-panel /panels/panel-1/icon-size int 28
xset xfce4-panel /panels/panel-1/autohide-behavior int 0
xset xfce4-panel /panels/panel-1/background-style int 0
xset xfce4-panel /panels/dark-mode bool "$([ "$MODE" = dark ] && echo true || echo false)"

xset xfce4-panel /plugins/plugin-1 string whiskermenu
xset xfce4-panel /plugins/plugin-2 string docklike
xset xfce4-panel /plugins/plugin-3 string separator
xset xfce4-panel /plugins/plugin-3/expand bool true
xset xfce4-panel /plugins/plugin-3/style int 0
xset xfce4-panel /plugins/plugin-4 string systray
xset xfce4-panel /plugins/plugin-4/square-icons bool true
xset xfce4-panel /plugins/plugin-4/icon-size int 22
xset xfce4-panel /plugins/plugin-5 string pulseaudio
xset xfce4-panel /plugins/plugin-6 string clock
xset xfce4-panel /plugins/plugin-6/digital-format string "%a %d %b  %H:%M"
xset xfce4-panel /plugins/plugin-6/tooltip-format string "%A %d %B %Y"
xset xfce4-panel /plugins/plugin-7 string showdesktop

# Whisker defaults, stored separately from xfconf by the plugin.
mkdir -p "$HOME/.config/xfce4/panel"
cat >"$HOME/.config/xfce4/panel/whiskermenu-1.rc" <<'EOF'
button-icon=org.xfce.panel.whiskermenu
button-single-row=true
button-title=
category-icon-size=1
favorites-in-recent=true
launcher-icon-size=2
launcher-show-description=true
launcher-show-name=true
menu-height=640
menu-width=760
position-categories-alternate=false
position-search-alternate=true
position-commands-alternate=false
show-button-title=false
show-category-names=true
stay-on-focus-out=false
view-mode=1
EOF

# KDE-like shortcuts. These properties are command paths in Xfce.
xset xfce4-keyboard-shortcuts '/commands/custom/<Super><Space>' string xfce4-popup-whiskermenu
xset xfce4-keyboard-shortcuts '/commands/custom/<Alt>F2' string 'xfce4-appfinder --collapsed'
xset xfce4-keyboard-shortcuts '/commands/custom/<Super>e' string thunar
xset xfce4-keyboard-shortcuts '/commands/custom/<Super>b' string brave
xset xfce4-keyboard-shortcuts '/commands/custom/<Super>Return' string 'st -g 115x35'
xset xfce4-keyboard-shortcuts '/commands/custom/<Super>l' string xflock4
xset xfce4-keyboard-shortcuts '/xfwm4/custom/<Super>Left' string tile_left_key
xset xfce4-keyboard-shortcuts '/xfwm4/custom/<Super>Right' string tile_right_key
xset xfce4-keyboard-shortcuts '/xfwm4/custom/<Super>Up' string maximize_window_key
xset xfce4-keyboard-shortcuts '/xfwm4/custom/<Super>Down' string hide_window_key

# Keep Qt applications visually consistent with GTK applications.
mkdir -p "$HOME/.config/environment.d"
cat >"$HOME/.config/environment.d/50-plasma-look.conf" <<'EOF'
QT_STYLE_OVERRIDE=Breeze
EOF

# Use Breeze for Xfce notifications when that component is available.
if [ -d "/usr/share/themes/$gtk_theme/xfce-notify-4.0" ]; then
    xset xfce4-notifyd /theme string "$gtk_theme"
fi
xset xfce4-notifyd /notification-position string top-right

if [ "$RESTART_PANEL" -eq 1 ]; then
    (xfce4-panel >/dev/null 2>&1 &)
fi

cat <<EOF
Applied the $MODE Plasma/Breeze look.
Backup: ${backup:-none}

Log out and back in once so Qt applications see QT_STYLE_OVERRIDE.
Right-click a Docklike Tasks icon to pin your preferred applications.
Restore with: $0 --restore ${backup:-}
EOF
