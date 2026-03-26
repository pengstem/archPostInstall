# Architecture Codemap

> Generated: 2026-01-23

## Overview

Arch Linux post-install automation: packages, dotfiles symlinks, GNOME state tracking, DPMS power management.

## Entry Points

```
bootstrap.sh          # Full setup orchestrator
├── install_packages.sh
├── install_shell_tools.sh
└── setup.sh          # Symlink orchestrator

scripts/archpostinstall.sh  # Unified CLI (13 subcommands)
```

## Script Call Graph

```
bootstrap.sh
├── scripts/install/install_packages.sh
│   └── reads: scripts/pkglist.txt
├── scripts/install/install_shell_tools.sh
└── setup.sh

archpostinstall.sh (CLI router)
├── bootstrap         → bootstrap.sh
├── install-packages  → install_packages.sh
├── install-shell     → install_shell_tools.sh
├── link-configs      → setup.sh
├── dpms-*            → gnome/dpms-toggle.sh
├── backup-gnome      → gnome/backup_gnome_state.sh
│                       └── backup/backup_themes_extensions.sh
├── backup-themes     → backup/backup_themes_extensions.sh
├── restore-themes    → backup/restore_themes_extensions.sh
├── backup-firefox    → backup/backup_firefox.sh
├── restore-firefox   → backup/restore_firefox.sh
├── update-pkglist    → update_pkglist.sh
└── measure-power     → power/measure_tlp_power.sh
```

## Systemd Automation

```
archpostinstall-gnome-sync.path     # Watches dconf/extensions/themes
└── archpostinstall-gnome-sync.service → backup_gnome_state.sh

archpostinstall-dpms-lock-monitor.service
└── dpms-lock-monitor.sh → dpms-toggle.sh --off/--on
```

## Pacman Hook

```
/etc/pacman.d/hooks/99-update-pkglist.hook
└── update_pkglist.sh → scripts/pkglist.txt
```

## Design Patterns

- `set -euo pipefail` fail-fast in all scripts
- Non-root execution with sudo privileges
- Symlink with `.bak_<epoch>` backup
- Hash-based change detection for backups
- Throttled GNOME sync (1800s default)
- Configuration-driven DPMS via helper DSL in `dpms.conf`
