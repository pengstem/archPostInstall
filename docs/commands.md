# Commands Reference

This page lists common commands and what they do.

## Unified CLI
After linking, you can use `archpostinstall` as a wrapper:

```
archpostinstall --help
archpostinstall bootstrap
archpostinstall install-packages
archpostinstall install-maplemono-cn
archpostinstall install-shell
archpostinstall link-configs
archpostinstall dpms-toggle
archpostinstall dpms-off
archpostinstall dpms-on
archpostinstall backup-gnome
archpostinstall backup-themes
archpostinstall restore-themes <archives...>
archpostinstall backup-firefox
archpostinstall restore-firefox <archive>
archpostinstall update-pkglist
```

## Direct Script Calls
Use these when you want explicit control:

```
./bootstrap.sh
./setup.sh
./scripts/install/install_packages.sh
./scripts/install/install_maplemono_cn_font.sh
./scripts/install/install_shell_tools.sh
./scripts/backup/backup_themes_extensions.sh [output_dir]
./scripts/backup/restore_themes_extensions.sh <archives...>
./scripts/backup/backup_firefox.sh [output_dir]
./scripts/backup/restore_firefox.sh <archive>
./scripts/gnome/backup_gnome_state.sh
./scripts/gnome/dpms-toggle.sh [--on|--off|--toggle]
./scripts/update_pkglist.sh
```

## Systemd (GNOME Sync)
Enable automatic GNOME sync after linking:

```
systemctl --user daemon-reload
systemctl --user enable --now archpostinstall-gnome-sync.path
```
