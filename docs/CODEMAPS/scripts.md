# Scripts Codemap

> Generated: 2026-01-23

## Directory Structure

```
scripts/
├── archpostinstall.sh        # CLI router (14 subcommands)
├── pkglist.txt               # Package source of truth
├── update_pkglist.sh         # Regenerates pkglist.txt
├── install/
│   ├── install_packages.sh   # Paru/yay package installation
│   ├── install_maplemono_cn_font.sh # Temporary Arch Linux CN font installer
│   └── install_shell_tools.sh # Oh My Zsh, plugins, p10k
├── backup/
│   ├── backup_themes_extensions.sh   # GNOME themes/icons/extensions
│   ├── restore_themes_extensions.sh  # Restore from tar.gz
│   ├── backup_firefox.sh             # Archive ~/.mozilla
│   └── restore_firefox.sh            # Restore Firefox config
├── gnome/
│   ├── backup_gnome_state.sh   # Sync GNOME state to docs/
│   ├── dpms-common.sh          # DPMS config + logging helpers
│   ├── dpms-toggle.sh          # Display power and app orchestration
│   └── dpms-lock-monitor.sh    # Lock/unlock watcher for dpms-toggle
├── power/
│   └── measure_tlp_power.sh    # TLP power measurement
└── zathura/
    └── page-to-clipboard.sh    # PDF page extraction helper
```

## Script Details

| Script | Lines | Purpose |
|--------|-------|---------|
| `archpostinstall.sh` | ~93 | CLI dispatcher |
| `install_packages.sh` | ~50 | Package installation |
| `install_maplemono_cn_font.sh` | ~102 | Temporary Arch Linux CN Maple Mono installer |
| `install_shell_tools.sh` | ~80 | Shell environment setup |
| `backup_themes_extensions.sh` | ~120 | Hash-based backup with pruning |
| `restore_themes_extensions.sh` | ~60 | Auto-detect and restore |
| `backup_firefox.sh` | ~40 | Firefox profile backup |
| `restore_firefox.sh` | ~50 | Firefox profile restore |
| `backup_gnome_state.sh` | ~100 | GNOME state sync with throttle |
| `dpms-common.sh` | ~317 | DPMS config DSL, validation, logging, locking |
| `dpms-toggle.sh` | ~225 | Display PowerSaveMode and app stop/start flow |
| `dpms-lock-monitor.sh` | ~78 | Logind lock watcher for DPMS |
| `update_pkglist.sh` | ~30 | Pacman hook target |
| `measure_tlp_power.sh` | ~244 | Battery power measurement |
| `page-to-clipboard.sh` | ~30 | Zathura helper |

## Key Functions

### backup_themes_extensions.sh
- `get_dir_hash()` - MD5 hash of directory contents
- `hash_changed()` - Compare current vs stored hash
- `backup_exists()` - Check for existing backup
- `prune_backups_keep_newest()` - Keep N newest backups

### install_shell_tools.sh
- `require_cmd()` - Check command availability
- `install_plugin()` - Clone zsh plugin if missing

### dpms-toggle.sh
- Explicit app action flow (`restart`, `start`, or `stop`) from `dpms.conf`
- Display PowerSaveMode control without TLP or power-profiles-daemon profile switching
- Bounded in-process log rotation
