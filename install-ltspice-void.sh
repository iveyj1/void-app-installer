#!/usr/bin/env bash
set -euo pipefail

# Install LTspice on Void Linux via a dedicated Wine prefix.
# Re-runnable. Override with env vars if desired:
#   LTSPICE_URL=... WINEPREFIX=... ./install-ltspice-void.sh

LTSPICE_URL="${LTSPICE_URL:-https://ltspice.analog.com/software/LTspice64.msi}"
PREFIX="${WINEPREFIX:-$HOME/.local/share/wineprefixes/ltspice}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ltspice-install"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
MSI="$CACHE_DIR/LTspice64.msi"
WRAPPER="$BIN_DIR/ltspice"
DESKTOP="$APP_DIR/ltspice.desktop"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

install_deps_void() {
  local missing=()
  need_cmd wine || missing+=(wine)
  need_cmd msiexec || missing+=(wine)
  need_cmd curl || missing+=(curl)

  if ((${#missing[@]})); then
    if ! need_cmd xbps-install; then
      echo "Missing required commands: ${missing[*]}" >&2
      echo "This script can auto-install dependencies only on Void Linux." >&2
      exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
      echo "Installing Void packages requires sudo. Re-run this script in a terminal and enter your password when prompted:" >&2
      echo "  $PWD/$0" >&2
    fi
    sudo xbps-install -Sy wine wine-mono wine-gecko curl desktop-file-utils xdg-utils
  fi
}

install_deps_void
mkdir -p "$CACHE_DIR" "$BIN_DIR" "$APP_DIR" "$PREFIX"

if [[ ! -s "$MSI" ]]; then
  curl -L --fail --retry 3 -o "$MSI" "$LTSPICE_URL"
fi

export WINEPREFIX="$PREFIX"
export WINEARCH=win64

wineboot --init >/dev/null 2>&1 || wineboot -u
msiexec /i "$MSI" /qn /norestart

EXE="$(find "$PREFIX/drive_c" -type f \
  \( -iname 'LTspice.exe' -o -iname 'LTspice*.exe' \) \
  ! -iname '*unins*' ! -ipath '*/windows/*' \
  | sort | head -n 1)"

if [[ -z "$EXE" ]]; then
  echo "LTspice installed, but LTspice.exe was not found under $PREFIX/drive_c" >&2
  exit 1
fi

cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
export WINEPREFIX="$PREFIX"
export WINEARCH=win64
exec wine "$EXE" "\$@"
EOF
chmod +x "$WRAPPER"

cat >"$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=LTspice
Comment=Analog Devices LTspice circuit simulator
Exec=$WRAPPER %f
Terminal=false
Categories=Science;Electronics;Engineering;
MimeType=application/x-ltspice-asc;application/x-ltspice-schematic;
Icon=applications-engineering
StartupNotify=true
EOF

if need_cmd update-desktop-database; then
  update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
fi

printf 'Installed LTspice\n  Wine prefix: %s\n  Executable:  %s\n  Launcher:    %s\n  Desktop:     %s\n' \
  "$PREFIX" "$EXE" "$WRAPPER" "$DESKTOP"
