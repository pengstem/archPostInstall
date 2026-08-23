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
archpostinstall boot-splash apply
archpostinstall boot-splash verify
archpostinstall boot-splash rollback
archpostinstall dpms-toggle
archpostinstall dpms-off
archpostinstall dpms-on
archpostinstall screensaver <start|stop|toggle|status|install|uninstall>
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
./scripts/install/install_boot_splash.sh <apply|verify|rollback>
./scripts/backup/backup_themes_extensions.sh [output_dir]
./scripts/backup/restore_themes_extensions.sh <archives...>
./scripts/backup/backup_firefox.sh [output_dir]
./scripts/backup/restore_firefox.sh <archive>
./scripts/gnome/backup_gnome_state.sh
./scripts/gnome/dpms-toggle.sh [--on|--off|--toggle]
./scripts/gnome/screensaver.sh [start|stop|toggle|status|install|uninstall]
./scripts/update_pkglist.sh
```

## Systemd (GNOME Sync)
Enable automatic GNOME sync after linking:

```
systemctl --user daemon-reload
systemctl --user enable --now archpostinstall-gnome-sync.path
```

## Systemd (Animated Screensaver)
`bootstrap.sh` enables this automatically on GNOME. For an existing linked checkout:

```
archpostinstall screensaver install
```
