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
  install-packages        Install packages from scripts/pkglist.txt
  install-maplemono-cn    Install Maple Mono NF CN from a temporary Arch Linux CN repo
  install-shell           Install Oh My Zsh, plugins, and powerlevel10k
  link-configs            Symlink tracked configs into place
  dpms-toggle             Toggle display power (GNOME)
  dpms-off                Force display off
  dpms-on                 Force display on and restore apps
  dpms-lock-monitor       Monitor lock state and toggle DPMS
  backup-gnome            Sync GNOME extensions/themes and archive assets
  backup-themes           Archive GNOME themes, icons, and extensions
  restore-themes <files>  Restore themes/icons/extensions from archives
  backup-firefox          Archive ~/.mozilla
  restore-firefox <file>  Restore ~/.mozilla from an archive
  update-pkglist          Refresh scripts/pkglist.txt from pacman
  measure-power           Measure power draw for TLP profiles
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
        "$REPO_DIR/setup.sh"
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
    dpms-lock-monitor)
        "$REPO_DIR/scripts/gnome/dpms-lock-monitor.sh"
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
    measure-power)
        "$REPO_DIR/scripts/power/measure_tlp_power.sh" "$@"
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
