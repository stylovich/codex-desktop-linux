#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APPLICATIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
RUN_SCRIPT="$REPO_DIR/scripts/codex-desktop-run.sh"
ICON_SOURCE="$REPO_DIR/assets/codex.png"

if [ ! -x "$RUN_SCRIPT" ]; then
    echo "Missing executable launcher: $RUN_SCRIPT" >&2
    exit 1
fi

mkdir -p "$APPLICATIONS_DIR" "$ICON_DIR"
install -m 644 "$ICON_SOURCE" "$ICON_DIR/codex-desktop-linux.png"

write_desktop_file() {
    local id="$1"
    local name="$2"
    local mode="$3"
    local file="$APPLICATIONS_DIR/$id.desktop"

    cat > "$file" <<EOF
[Desktop Entry]
Name=$name
Comment=Run Codex Desktop on Linux
Exec=$RUN_SCRIPT $mode
Icon=codex-desktop-linux
Terminal=false
Type=Application
Categories=Development;
StartupNotify=true
StartupWMClass=codex-desktop
X-GNOME-WMClass=codex-desktop
EOF
}

write_desktop_file "codex-desktop" "Codex Desktop" "auto"
write_desktop_file "codex-desktop-x11" "Codex Desktop X11" "x11"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Installed desktop entries:"
echo "  $APPLICATIONS_DIR/codex-desktop.desktop"
echo "  $APPLICATIONS_DIR/codex-desktop-x11.desktop"
