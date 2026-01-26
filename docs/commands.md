# Commands Reference

This page lists common commands and what they do.

## Unified CLI
After linking, you can use `archpostinstall` as a wrapper:

```
archpostinstall --help
archpostinstall bootstrap
archpostinstall install-packages
archpostinstall install-shell
archpostinstall link-configs
archpostinstall dpms-toggle
archpostinstall dpms-off
archpostinstall dpms-on
archpostinstall dpms-restore
archpostinstall backup-gnome
archpostinstall backup-themes
archpostinstall restore-themes <archives...>
archpostinstall backup-firefox
archpostinstall restore-firefox <archive>
archpostinstall update-pkglist
archpostinstall measure-power
archpostinstall obs-autoedit <file.mkv>
archpostinstall obs-autoedit-scan
archpostinstall obs-autoedit-enable
archpostinstall obs-autoedit-disable
```

## Direct Script Calls
Use these when you want explicit control:

```
./bootstrap.sh
./setup.sh
./scripts/install/install_packages.sh
./scripts/install/install_shell_tools.sh
./scripts/backup/backup_themes_extensions.sh [output_dir]
./scripts/backup/restore_themes_extensions.sh <archives...>
./scripts/backup/backup_firefox.sh [output_dir]
./scripts/backup/restore_firefox.sh <archive>
./scripts/gnome/backup_gnome_state.sh
./scripts/gnome/dpms-toggle.sh [--on|--off|--toggle|--idle|--restore]
./scripts/update_pkglist.sh
./scripts/power/measure_tlp_power.sh
./scripts/obs/autoedit_idle.sh [--scan] [--dry-run] [--force] [file.mkv]
```

## Systemd (GNOME Sync)
Enable automatic GNOME sync after linking:

```
systemctl --user daemon-reload
systemctl --user enable --now archpostinstall-gnome-sync.path
systemctl --user enable --now archpostinstall-dpms-idle.timer
systemctl --user enable --now archpostinstall-dpms-restore.timer
systemctl --user enable --now archpostinstall-dpms-log-cleanup.timer
systemctl --user enable --now archpostinstall-obs-autoedit.path
```
