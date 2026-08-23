# Documentation Overview

This folder contains reference notes and quick guidance for maintaining the Arch post-install setup. It is intentionally concise and kept in sync with the automation scripts.

## Where to Look
- `docs/fileLocationList.md` is the source-to-target mapping for symlinked configs.
- `docs/gnome-extensions.md` and `docs/gnome-appearrance.md` are updated by the GNOME sync script.
- `docs/bug-history.md` tracks notable config issues and fixes.
- `docs/thoughts.md` is a freeform notes file for future changes.
- `docs/screensaver.md` explains the Omarchy-inspired GNOME screensaver and its safety boundary.
- `docs/commands.md` lists common commands and the unified CLI.

## Quick Start
- Full setup: `./bootstrap.sh`
- Symlink configs only: `./setup.sh`
- Unified CLI: `./scripts/archpostinstall.sh --help` (or `archpostinstall --help` after linking)

## GNOME Sync and Backups
- GNOME sync writes the current extension list and theme settings into `docs/`.
- Archives are stored under `backups/gnome/` by default.
- Enable auto-sync after linking:
  - `systemctl --user daemon-reload`
  - `systemctl --user enable --now archpostinstall-gnome-sync.path`
- Optional env vars:
  - `GNOME_BACKUP_DIR` to override backup location
  - `GNOME_SYNC_THROTTLE_SECONDS` to adjust archive frequency

## DPMS Toggle
- `dpms-toggle` turns the display off/on and manages app shutdown/restore.
- Configure app behavior in `configs/archpostinstall/dpms.conf` with `dpms_app`.
- Diagnostic output is written to stderr; systemd captures it in the journal when a unit invokes the script.
- `dpms_app` uses `--action restart` by default; use `--action start` for apps left running
  during display-off, or `--action stop` for apps not reopened by DPMS.
- The default config restarts `zen-browser`, `wechat`, and `qq`, leaves Kitty running,
  and stops Steam and Firefox without reopening them.
- `dpms-toggle` does not switch TLP or power-profiles-daemon profiles; power policy stays under GNOME/TLP/user control.
- If an old `/usr/local/bin/dpms-toggle` exists, re-run `./setup.sh` to replace it.

## Animated Screensaver
- `Super+F11` or `archpostinstall screensaver toggle` opens the custom full-screen animation.
- The user service launches it after five idle minutes and closes it on keyboard or pointer activity.
- It is not a lock screen and does not change GNOME lock, suspend, or DPMS settings.
- Customize the art and effect allowlist in `configs/archpostinstall/screensaver.*`; see `docs/screensaver.md`.

## Package List Updates
- Pacman hook triggers `archpostinstall-update-pkglist` after transactions.
- Manual refresh: `./scripts/update_pkglist.sh` (writes `scripts/pkglist.txt`).

## TLP Power Management
- TLP overrides live in `configs/tlp/99-archpostinstall.conf` and are linked to `/etc/tlp.d/99-archpostinstall.conf`.

## BaiduPCS-Go
- Copy your real config to `configs/baidupcs/pcs_config.json` before running `./setup.sh`.
- The example template lives at `configs/baidupcs/pcs_config.json.example` and does not contain secrets.

## Firefox Backup/Restore
- Backups go to `backups/firefox/` by default.
- Use `./scripts/backup/backup_firefox.sh` and `./scripts/backup/restore_firefox.sh` for manual control.
