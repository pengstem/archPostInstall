#!/bin/bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: archpostinstall <command> [args]

Commands:
  bootstrap               Run full post-install flow
  install-packages        Install packages from scripts/pkglist/
  install-maplemono-cn    Install Maple Mono NF CN from a temporary Arch Linux CN repo
  install-shell           Install Oh My Zsh, plugins, and powerlevel10k
  link-configs [opts]     Install every manifest.tsv entry (see setup.sh --help)
  sync-system             Re-copy root-owned targets after editing them in the repo
  doctor                  Report missing sources, drifted targets, and old backups
  boot-splash <action>    Apply, verify, or roll back the Zen Connect splash
  dpms-toggle             Toggle display power (GNOME)
  dpms-off                Force display off
  dpms-on                 Force display on and restore apps
  screensaver [action]    Control the Omarchy-inspired GNOME screensaver
  backup-gnome            Sync GNOME extensions/themes and archive assets
  backup-themes           Archive GNOME themes, icons, and extensions
  restore-themes <files>  Restore themes/icons/extensions from archives
  backup-firefox          Archive ~/.mozilla
  restore-firefox <file>  Restore ~/.mozilla from an archive
  update-pkglist          Refresh scripts/pkglist/ from pacman
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
    bootstrap)
        "$REPO_DIR/bootstrap.sh"
        ;;
    install-packages)
        "$REPO_DIR/scripts/install/install_packages.sh"
        ;;
    install-maplemono-cn)
        "$REPO_DIR/scripts/install/install_maplemono_cn_font.sh"
        ;;
    install-shell)
        "$REPO_DIR/scripts/install/install_shell_tools.sh"
        ;;
    link-configs)
        "$REPO_DIR/setup.sh" "$@"
        ;;
    sync-system)
        "$REPO_DIR/setup.sh" --group pacman --group system "$@"
        ;;
    doctor)
        "$REPO_DIR/setup.sh" --check "$@"
        ;;
    boot-splash)
        "$REPO_DIR/scripts/install/install_boot_splash.sh" "$@"
        ;;
    dpms-toggle)
        "$REPO_DIR/scripts/gnome/dpms-toggle.sh"
        ;;
    dpms-off)
        "$REPO_DIR/scripts/gnome/dpms-toggle.sh" --off
        ;;
    dpms-on)
        "$REPO_DIR/scripts/gnome/dpms-toggle.sh" --on
        ;;
    screensaver)
        "$REPO_DIR/scripts/gnome/screensaver.sh" "$@"
        ;;
    backup-gnome)
        "$REPO_DIR/scripts/gnome/backup_gnome_state.sh" "$@"
        ;;
    backup-themes)
        "$REPO_DIR/scripts/backup/backup_themes_extensions.sh" "$@"
        ;;
    restore-themes)
        "$REPO_DIR/scripts/backup/restore_themes_extensions.sh" "$@"
        ;;
    backup-firefox)
        "$REPO_DIR/scripts/backup/backup_firefox.sh" "$@"
        ;;
    restore-firefox)
        "$REPO_DIR/scripts/backup/restore_firefox.sh" "$@"
        ;;
    update-pkglist)
        "$REPO_DIR/scripts/update_pkglist.sh"
        ;;
    ""|-h|--help|help)
        usage
        ;;
    *)
        echo "Unknown command: $cmd"
        usage
        exit 1
        ;;
esac
