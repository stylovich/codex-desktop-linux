# Local Codex Desktop Usage

This checkout has a local-only workflow for running Codex Desktop without
installing a native package, using `sudo`, writing to `/opt`, or enabling a
systemd user service.

## Files

- `scripts/codex-desktop-run.sh`: launches the generated `codex-app/start.sh`
  with a predictable display mode.
- `scripts/codex-desktop-update-local.sh`: pulls this wrapper repo and rebuilds
  `codex-app/` locally.
- `scripts/codex-desktop-install-desktop-files.sh`: installs user-local
  `.desktop` entries into `~/.local/share/applications`.

The generated app lives in:

```bash
codex-app/
```

The cached upstream DMG lives in:

```bash
Codex.dmg
```

## New Machine Setup

Clone the local workflow branch from the fork:

```bash
git clone -b local-workflow https://github.com/stylovich/codex-desktop-linux.git
cd codex-desktop-linux
```

Install host dependencies:

```bash
bash scripts/install-deps.sh
```

Build a fresh local app from the current upstream DMG:

```bash
scripts/codex-desktop-update-local.sh --fresh
```

Install user-local application menu entries:

```bash
scripts/codex-desktop-install-desktop-files.sh
```

The app can then be launched from the application menu or with:

```bash
scripts/codex-desktop-run.sh auto
```

## Launching

From the repo root:

```bash
scripts/codex-desktop-run.sh auto
```

Available modes:

```bash
scripts/codex-desktop-run.sh auto
scripts/codex-desktop-run.sh wayland
scripts/codex-desktop-run.sh x11
scripts/codex-desktop-run.sh safe
```

- `auto`: uses the generated launcher defaults.
- `wayland`: forces Wayland and disables GPU compositing.
- `x11`: forces X11 and disables GPU compositing.
- `safe`: forces X11 and disables GPU acceleration.

Use `x11` if Wayland shows Vulkan/GPU warnings, flickering, blank windows, or
weird focus behavior. Use `safe` only if `x11` still has graphics problems.

Extra Electron flags can be passed after `--`:

```bash
scripts/codex-desktop-run.sh x11 -- --disable-features=UseOzonePlatform
```

## Desktop Entries

Install or refresh the user-local launchers:

```bash
scripts/codex-desktop-install-desktop-files.sh
```

This writes:

```bash
~/.local/share/applications/codex-desktop.desktop
~/.local/share/applications/codex-desktop-x11.desktop
```

After that, the application menu should show:

- `Codex Desktop`
- `Codex Desktop X11`

## Updating

Update the wrapper repo and rebuild the local app:

```bash
scripts/codex-desktop-update-local.sh
```

Rebuild without pulling from git:

```bash
scripts/codex-desktop-update-local.sh --rebuild-only
```

Fresh rebuild, removing `codex-app/` and the cached `Codex.dmg` first:

```bash
scripts/codex-desktop-update-local.sh --fresh
```

If Codex Desktop appears to be running, the update script stops before
rebuilding. Close the app first, or override intentionally:

```bash
scripts/codex-desktop-update-local.sh --force
```

The update script bootstraps a modern `7zz` into `~/.local/bin` if the system
`7z` is too old for the current DMG format.

## Port 5175

The generated launcher serves the Desktop webview on:

```bash
http://127.0.0.1:5175
```

If another dev server is already using that port, the wrapper refuses to start
and prints the process using it. Stop that process first, then launch Codex
Desktop again.

To inspect the port manually:

```bash
ss -ltnp '( sport = :5175 )'
```

## Logs

Launcher logs:

```bash
tail -f ~/.cache/codex-desktop/launcher.log
```

Electron state and cache are under:

```bash
~/.config/Codex/
```

Codex CLI state is under:

```bash
~/.codex/
```

## CLI Relationship

The Desktop app uses Codex infrastructure behind the scenes. The generated
launcher finds the local `codex` binary and exports `CODEX_CLI_PATH`; the app
then talks to the Codex app-server/runtime rather than simply shelling out to
`codex` for every message.

The local launcher in `scripts/codex-desktop-run.sh` prefers
`~/.bun/bin/codex` when it exists, then falls back to `codex` from `PATH`, nvm,
`~/.local/bin`, and system locations.

Desktop and CLI share local Codex auth/config/state under `~/.codex`, but
Desktop also keeps Electron-specific state under `~/.config/Codex`.

To check whether a Desktop conversation is resumable from the CLI:

```bash
codex resume --all
```

If the conversation appears there, continue it with:

```bash
codex resume <session-id>
```

If it does not appear, that Desktop thread was not recorded in the regular CLI
resume index.

## Cleanup

Remove local Desktop menu entries:

```bash
rm -f ~/.local/share/applications/codex-desktop.desktop
rm -f ~/.local/share/applications/codex-desktop-x11.desktop
```

Remove generated app artifacts from this checkout:

```bash
rm -rf codex-app Codex.dmg
```

Remove launcher state and logs:

```bash
rm -rf ~/.local/state/codex-desktop ~/.cache/codex-desktop
```
