#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_DIR/codex-app"
START_SCRIPT="$APP_DIR/start.sh"
MODE="${1:-auto}"

usage() {
    cat <<'EOF'
Usage: scripts/codex-desktop-run.sh [auto|wayland|x11|safe] [-- ELECTRON_FLAGS...]

Modes:
  auto     Use the generated launcher defaults.
  wayland  Force Wayland.
  x11      Force X11, useful when Wayland/Vulkan glitches appear.
  safe     Force X11 and disable GPU acceleration.

The generated launcher serves Codex webview assets on 127.0.0.1:5175.
EOF
}

case "$MODE" in
    -h|--help)
        usage
        exit 0
        ;;
    auto|wayland|x11|safe)
        shift || true
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        usage >&2
        exit 2
        ;;
esac

if [ "${1:-}" = "--" ]; then
    shift
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ ! -x "$START_SCRIPT" ]; then
    echo "Codex Desktop is not built yet: $START_SCRIPT" >&2
    echo "Run: scripts/codex-desktop-update-local.sh --rebuild-only" >&2
    exit 1
fi

if command -v curl >/dev/null 2>&1; then
    if body="$(curl -fsS --max-time 1 http://127.0.0.1:5175/index.html 2>/dev/null || true)"; then
        if [ -n "$body" ] && ! printf '%s' "$body" | grep -q '<title>Codex</title>'; then
            echo "Port 5175 is already serving non-Codex content." >&2
            if command -v ss >/dev/null 2>&1; then
                ss -ltnp '( sport = :5175 )' >&2 || true
            fi
            echo "Stop the process using 5175, or Codex Desktop will fail before Electron opens." >&2
            exit 1
        fi
    fi
fi

if [ -z "${CODEX_CLI_PATH:-}" ]; then
    for candidate in \
        "$HOME/.bun/bin/codex" \
        "$(command -v codex 2>/dev/null || true)" \
        "$HOME/.nvm/versions/node/current/bin/codex" \
        "$HOME/.nvm/versions/node"/*/bin/codex \
        "$HOME/.local/bin/codex" \
        "/usr/local/bin/codex" \
        "/usr/bin/codex"
    do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            export CODEX_CLI_PATH="$candidate"
            break
        fi
    done
fi

export CHROME_DESKTOP="${CHROME_DESKTOP:-codex-desktop.desktop}"
export BAMF_DESKTOP_FILE_HINT="${BAMF_DESKTOP_FILE_HINT:-$HOME/.local/share/applications/codex-desktop.desktop}"

case "$MODE" in
    auto)
        exec "$START_SCRIPT" "$@"
        ;;
    wayland)
        exec "$START_SCRIPT" --ozone-platform=wayland --disable-gpu-compositing "$@"
        ;;
    x11)
        exec "$START_SCRIPT" --ozone-platform=x11 --disable-gpu-compositing "$@"
        ;;
    safe)
        exec "$START_SCRIPT" --ozone-platform=x11 --disable-gpu "$@"
        ;;
esac
