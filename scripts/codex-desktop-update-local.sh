#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_DIR/codex-app"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/codex-desktop"
APP_PID_FILE="$STATE_DIR/app.pid"
CODEX_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Codex"
REBUILD_ONLY=0
FRESH=0
FORCE=0

usage() {
    cat <<'EOF'
Usage: scripts/codex-desktop-update-local.sh [OPTIONS]

Updates the wrapper checkout and rebuilds codex-app/ locally. It does not
install packages, use sudo, or enable systemd services.

Options:
  --rebuild-only  Skip git pull and just run make build-app.
  --fresh         Remove codex-app/ and cached Codex.dmg before rebuilding.
  --force         Rebuild even if a Codex Desktop Electron process appears to be running.
  -h, --help      Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --rebuild-only)
            REBUILD_ONLY=1
            ;;
        --fresh)
            FRESH=1
            ;;
        --force)
            FORCE=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

pid_matches_app() {
    local pid="$1"
    [ -n "$pid" ] || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [ -d "/proc/$pid" ] || return 1
    [ "$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)" = "$(readlink -f "$APP_DIR/electron" 2>/dev/null || true)" ]
}

app_appears_running() {
    if [ -f "$APP_PID_FILE" ]; then
        local app_pid
        app_pid="$(cat "$APP_PID_FILE" 2>/dev/null || true)"
        if pid_matches_app "$app_pid"; then
            return 0
        fi
    fi

    pgrep -f "$APP_DIR/electron" >/dev/null 2>&1
}

clear_web_caches_after_rebuild() {
    if app_appears_running; then
        echo "[update] Skipping Electron web cache cleanup because Codex Desktop is running" >&2
        return 0
    fi

    [ -d "$CODEX_CONFIG_DIR" ] || return 0

    local backup_dir
    backup_dir="$CODEX_CONFIG_DIR/cache-backup-$(date +%Y%m%d-%H%M%S)"

    local moved=0
    local name
    for name in \
        "Cache" \
        "Code Cache" \
        "GPUCache" \
        "DawnCache" \
        "DawnGraphiteCache" \
        "DawnWebGPUCache" \
        "ShaderCache" \
        "blob_storage" \
        "Service Worker"
    do
        if [ -e "$CODEX_CONFIG_DIR/$name" ]; then
            mkdir -p "$backup_dir"
            mv "$CODEX_CONFIG_DIR/$name" "$backup_dir/$name"
            moved=1
        fi
    done

    if [ "$moved" -eq 1 ]; then
        echo "[update] Moved Electron web caches to: $backup_dir"
    fi
}

if [ "$FORCE" -ne 1 ] && [ -f "$APP_PID_FILE" ]; then
    app_pid="$(cat "$APP_PID_FILE" 2>/dev/null || true)"
    if pid_matches_app "$app_pid"; then
        echo "Codex Desktop appears to be running as pid $app_pid." >&2
        echo "Close it first, or rerun with --force." >&2
        exit 1
    fi
fi

ensure_modern_7zz() {
    if command -v 7zz >/dev/null 2>&1 && 7zz 2>&1 | grep -qm 1 "7-Zip"; then
        return 0
    fi
    if command -v 7z >/dev/null 2>&1 && ! 7z 2>&1 | grep -m 1 "7-Zip" | grep -q "16.02"; then
        return 0
    fi

    local arch sevenzip_arch version url tmpdir
    arch="$(uname -m)"
    case "$arch" in
        x86_64) sevenzip_arch="x64" ;;
        aarch64) sevenzip_arch="arm64" ;;
        armv7l) sevenzip_arch="arm" ;;
        *)
            echo "Unsupported architecture for automatic 7zz bootstrap: $arch" >&2
            exit 1
            ;;
    esac

    version="2600"
    url="https://www.7-zip.org/a/7z${version}-linux-${sevenzip_arch}.tar.xz"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    echo "[update] Installing modern 7zz into ~/.local/bin"
    curl -fL --progress-bar -o "$tmpdir/7z.tar.xz" "$url"
    tar -C "$tmpdir" -xf "$tmpdir/7z.tar.xz" 7zz
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$tmpdir/7zz" "$HOME/.local/bin/7zz"
    export PATH="$HOME/.local/bin:$PATH"
}

cd "$REPO_DIR"

ensure_modern_7zz

if [ "$REBUILD_ONLY" -ne 1 ]; then
    echo "[update] Pulling wrapper repo"
    git pull --ff-only
fi

echo "[update] Rebuilding codex-app"
if [ "$FRESH" -eq 1 ]; then
    ./install.sh --fresh
else
    make build-app
fi

clear_web_caches_after_rebuild

echo "[update] Done: $APP_DIR/start.sh"
