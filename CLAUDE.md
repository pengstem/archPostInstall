# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal Arch Linux post-install automation and dotfiles repository. Automates package installation, symlinks configs into place, and captures GNOME theme/extension state for easy rebuilds.

## Key Commands

```bash
# Full post-install setup (packages, shell tools, symlinks, sets zsh as default shell)
./bootstrap.sh

# Symlink configs only (no package installation)
./setup.sh

# Unified CLI (after setup.sh links it to ~/.local/bin/archpostinstall)
archpostinstall --help
archpostinstall bootstrap
archpostinstall install-packages
archpostinstall install-shell
archpostinstall link-configs
archpostinstall backup-gnome
archpostinstall backup-themes
archpostinstall restore-themes <files>
archpostinstall backup-firefox
archpostinstall restore-firefox <file>
archpostinstall update-pkglist
archpostinstall dpms-toggle
archpostinstall dpms-off
archpostinstall dpms-on
archpostinstall dpms-lock-monitor
archpostinstall measure-power

# Syntax-check a script without running it
bash -n scripts/some_script.sh
```

## Repository Architecture

**Entry points:**
- `bootstrap.sh` - Full setup orchestrator (runs install_packages -> install_shell_tools -> setup.sh -> sets zsh)
- `setup.sh` - Symlinks all tracked configs; handles both user (`~/.config`) and system (`/etc`) targets
- `scripts/archpostinstall.sh` - Unified CLI wrapper for all common operations

**Scripts organized by purpose:**
- `scripts/install/` - Package and shell tool installation
- `scripts/backup/` - Firefox and GNOME theme/extension backup/restore
- `scripts/gnome/` - GNOME state sync and DPMS automation
- `scripts/power/` - TLP power measurement tools
- `scripts/zathura/` - Zathura PDF viewer helpers

**Config structure:**
- `configs/<tool>/` - Each tool's config mirrors its target location
- System configs (`pacman/`, `paru/`) require sudo to link
- `configs/systemd/user/` - User systemd units for GNOME sync and DPMS lock monitoring

**Key files:**
- `scripts/pkglist.txt` - Package source of truth; auto-updated by pacman hook
- `configs/archpostinstall/dpms.conf` - DPMS automation settings (apps to kill/restore, power profiles)
- `docs/fileLocationList.md` - Complete source-to-target symlink mapping

## Symlink Behavior

`setup.sh` uses two helper functions:
- `create_link()` - User-space symlinks with backup of existing files
- `create_sudo_link()` - System symlinks (`/etc/*`) requiring sudo

Existing files are backed up with timestamp suffix (`.bak_<epoch>`) before linking.

## Special Cases

- `configs/baidupcs/pcs_config.json` - Ignored; copy from `.example` template locally
- `configs/rime/user.yaml` - Ignored; changes constantly during typing
- `configs/rime/build/`, `configs/rime/*.userdb/` - Build artifacts, may be git-ignored
- `backups/` - Git-ignored archive output directory

## Systemd Integration

After running `setup.sh`, enable user units:
```bash
systemctl --user daemon-reload
systemctl --user enable --now archpostinstall-gnome-sync.path  # Auto-sync GNOME state
systemctl --user enable --now archpostinstall-dpms-lock-monitor.service  # DPMS automation
systemctl --user enable --now archpostinstall-dpms-log-cleanup.timer
```

## Shell Script Conventions

- Use `#!/bin/bash` with `set -euo pipefail` for fail-fast behavior
- 4-space indentation
- `lower_snake_case` for functions, `UPPER_SNAKE_CASE` for constants
- Scripts must not be run as root; check `EUID` and require sudo privileges instead
