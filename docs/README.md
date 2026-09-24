# Documentation Overview

This folder contains reference notes and quick guidance for maintaining the Arch post-install setup. It is intentionally concise and kept in sync with the automation scripts.

## Where to Look
- `manifest.tsv` (repo root) is the source-to-target mapping that `setup.sh` installs; `archpostinstall doctor` checks it.
- `docs/gnome-extensions.md` and `docs/gnome-appearrance.md` are updated by the GNOME sync script.
- `docs/bug-history.md` tracks notable config issues and fixes.
- `docs/thoughts.md` is a freeform notes file for future changes.
- `docs/screensaver.md` explains the Omarchy-inspired GNOME screensaver and its safety boundary.
- `docs/commands.md` lists common commands and the unified CLI.

## Quick Start
- Full setup: `./bootstrap.sh`
- Install configs only: `./setup.sh` (`--dry-run`, `--group pacman|system|user`, `--check`)
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
- `/usr/local/bin/dpms-toggle` stays a symlink because GNOME shortcuts do not see `~/.local/bin`; it only ever runs as the user.

## Animated Screensaver
- `Super+F11` or `archpostinstall screensaver toggle` opens the custom full-screen animation.
- `archpostinstall screensaver upgrade` builds the latest stable Rust renderer release.
- The user service launches it after five idle minutes and closes it on keyboard or pointer activity.
- DPMS-off suppresses and stops the animation; DPMS-on only rearms the idle countdown.
- It is not a lock screen and does not change GNOME lock, suspend, or DPMS settings.
- Customize the art and effect allowlist in `configs/archpostinstall/screensaver.*`; see `docs/screensaver.md`.

## Package Lists
- `scripts/pkglist/native.txt` and `aur.txt` are regenerated after every pacman transaction by the hook,
  which runs the root-owned wrapper `/usr/local/bin/archpostinstall-update-pkglist`; it drops to the repo
  owner with `runuser` before running `scripts/update_pkglist.sh`.
- `hw-<hostname>.txt` is hand-maintained and only installed on that host; its packages never appear in
  `native.txt`/`aur.txt`. `ignore.txt` lists packages that are never recorded (AUR helpers, script-installed fonts).
- Manual refresh: `archpostinstall update-pkglist`.

## System Targets
- Everything root reads or executes (pacman/paru config, pacman hook, TLP, mkinitcpio, kernel cmdline,
  Plymouth) is copied, not symlinked, so editing the user-owned repo cannot change root behavior.
- After editing one of those files in the repo, run `archpostinstall sync-system`.
- `/etc/pacman.conf` is installed with any `Include` of a missing file commented out, so a fresh
  machine can run pacman before vendor repos are set up.

## TLP Power Management
- TLP overrides live in `configs/tlp/99-archpostinstall.conf` and are copied to `/etc/tlp.d/99-archpostinstall.conf`.

## BaiduPCS-Go
- Copy your real config to `configs/baidupcs/pcs_config.json` before running `./setup.sh`.
- The example template lives at `configs/baidupcs/pcs_config.json.example` and does not contain secrets.

## Firefox Backup/Restore
- Backups go to `backups/firefox/` by default.
- Use `./scripts/backup/backup_firefox.sh` and `./scripts/backup/restore_firefox.sh` for manual control.
