# Documentation Overview

This folder contains reference notes and quick guidance for maintaining the Arch post-install setup. It is intentionally concise and kept in sync with the automation scripts.

## Where to Look
- `docs/fileLocationList.md` is the source-to-target mapping for symlinked configs.
- `docs/gnome-extensions.md` and `docs/gnome-appearrance.md` are updated by the GNOME sync script.
- `docs/thoughts.md` is a freeform notes file for future changes.
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

## DPMS Toggle and Auto-Idle
- `dpms-toggle` turns the display off/on and manages app shutdown/restore.
- Configure app lists and power profile in `configs/archpostinstall/dpms.conf`.
- Enable timers after linking:
  - `systemctl --user enable --now archpostinstall-dpms-idle.timer`
  - `systemctl --user enable --now archpostinstall-dpms-restore.timer`
- Set `DPMS_KILL_OTHER_GUI=0` to avoid best-effort closing of non-whitelisted GUI apps.
- If an old `/usr/local/bin/dpms-toggle` exists, re-run `./setup.sh` to replace it.

## Package List Updates
- Pacman hook triggers `archpostinstall-update-pkglist` after transactions.
- Manual refresh: `./scripts/update_pkglist.sh` (writes `scripts/pkglist.txt`).

## BaiduPCS-Go
- Copy your real config to `configs/baidupcs/pcs_config.json` before running `./setup.sh`.
- The example template lives at `configs/baidupcs/pcs_config.json.example` and does not contain secrets.

## Firefox Backup/Restore
- Backups go to `backups/firefox/` by default.
- Use `./scripts/backup/backup_firefox.sh` and `./scripts/backup/restore_firefox.sh` for manual control.
