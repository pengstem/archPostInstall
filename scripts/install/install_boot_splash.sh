#!/bin/bash

set -Eeuo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

THEME_SOURCE="$REPO_DIR/configs/plymouth/themes/connect"
PLYMOUTH_CONFIG_SOURCE="$REPO_DIR/configs/plymouth/plymouthd.conf"
MKINITCPIO_CONFIG_SOURCE="$REPO_DIR/configs/mkinitcpio/90-archpostinstall-nvidia-plymouth.conf"
CMDLINE_CONFIG_SOURCE="$REPO_DIR/configs/kernel/cmdline.d/90-archpostinstall-splash.conf"
ZEN_PRESET_SOURCE="$REPO_DIR/configs/mkinitcpio/linux-zen.preset"

THEME_TARGET="/usr/share/plymouth/themes/connect"
PLYMOUTH_CONFIG_TARGET="/etc/plymouth/plymouthd.conf"
MKINITCPIO_CONFIG_TARGET="/etc/mkinitcpio.conf.d/90-archpostinstall-nvidia-plymouth.conf"
CMDLINE_CONFIG_TARGET="/etc/cmdline.d/90-archpostinstall-splash.conf"
ZEN_PRESET_TARGET="/etc/mkinitcpio.d/linux-zen.preset"
ZEN_UKI="/boot/EFI/Linux/arch-linux-zen.efi"
LTS_UKI="/boot/EFI/Linux/arch-linux-lts.efi"
ZEN_KERNEL="/boot/vmlinuz-linux-zen"
BACKUP_ROOT="/var/lib/archpostinstall/boot-splash-backups"

MANAGED_TARGETS=(
    "$THEME_TARGET"
    "$PLYMOUTH_CONFIG_TARGET"
    "$MKINITCPIO_CONFIG_TARGET"
    "$CMDLINE_CONFIG_TARGET"
    "$ZEN_PRESET_TARGET"
)

ACTIVE_BACKUP=""
ROLLBACK_NEEDED=0

usage() {
    cat <<'EOF'
Usage: install_boot_splash.sh <apply|verify|rollback>

  apply      Back up the current Zen boot state, install tracked configs,
             rebuild only linux-zen, and verify the resulting UKI.
  verify     Verify the live Connect theme, configuration, and Zen UKI.
  rollback   Restore the most recent boot-splash backup without rebuilding.
EOF
}

die() {
    echo "Error: $*" >&2
    return 1
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        die "run this command from a root shell (for example, su -c 'archpostinstall boot-splash apply')"
    fi
}

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null || die "required command not found: $command_name"
}

require_source() {
    local source_path="$1"

    [[ -e "$source_path" ]] || die "tracked source not found: $source_path"
}

find_zen_kernel_release() {
    local pkgbase_file
    local pkgbase
    local -a releases=()

    for pkgbase_file in /usr/lib/modules/*/pkgbase; do
        [[ -f "$pkgbase_file" ]] || continue
        read -r pkgbase < "$pkgbase_file"
        if [[ "$pkgbase" == "linux-zen" ]]; then
            releases+=("$(basename "$(dirname "$pkgbase_file")")")
        fi
    done

    [[ "${#releases[@]}" -eq 1 ]] || die "expected exactly one installed linux-zen module tree, found ${#releases[@]}"
    printf '%s\n' "${releases[0]}"
}

check_prerequisites() {
    local command_name
    local kernel_release
    local module_name
    local source_path

    for command_name in cmp diff identify install lsinitcpio mkinitcpio objcopy objdump plymouth-set-default-theme sha256sum; do
        require_command "$command_name"
    done

    for source_path in \
        "$THEME_SOURCE" \
        "$THEME_SOURCE/connect.plymouth" \
        "$THEME_SOURCE/connect.script" \
        "$THEME_SOURCE/connect.bmp" \
        "$PLYMOUTH_CONFIG_SOURCE" \
        "$MKINITCPIO_CONFIG_SOURCE" \
        "$CMDLINE_CONFIG_SOURCE" \
        "$ZEN_PRESET_SOURCE"; do
        require_source "$source_path"
    done

    [[ -f "$ZEN_KERNEL" ]] || die "Zen kernel not found: $ZEN_KERNEL"
    [[ -f "$ZEN_UKI" ]] || die "Zen UKI not found: $ZEN_UKI"
    pacman -Q plymouth nvidia-open-dkms nvidia-utils linux-zen mkinitcpio >/dev/null

    kernel_release="$(find_zen_kernel_release)"
    for module_name in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        modinfo -k "$kernel_release" -F filename "$module_name" >/dev/null \
            || die "NVIDIA module missing for $kernel_release: $module_name"
    done

    [[ "$(find -L "$THEME_SOURCE" -maxdepth 1 -type f -name 'progress-*.png' | wc -l)" -eq 120 ]] \
        || die "the Connect theme must contain 120 animation frames"
}

create_backup() {
    local timestamp
    local backup_dir
    local target
    local backup_path

    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="$BACKUP_ROOT/$timestamp"
    mkdir -p "$backup_dir/files"
    : > "$backup_dir/manifest.tsv"

    for target in "${MANAGED_TARGETS[@]}"; do
        backup_path="$backup_dir/files$target"
        mkdir -p "$(dirname "$backup_path")"
        if [[ -e "$target" || -L "$target" ]]; then
            cp -a --no-dereference -- "$target" "$backup_path"
            printf 'present\t%s\n' "$target" >> "$backup_dir/manifest.tsv"
        else
            printf 'absent\t%s\n' "$target" >> "$backup_dir/manifest.tsv"
        fi
    done

    cp -a -- "$ZEN_UKI" "$backup_dir/arch-linux-zen.efi"
    sha256sum "$ZEN_UKI" > "$backup_dir/zen-uki.sha256"
    if [[ -f "$LTS_UKI" ]]; then
        sha256sum "$LTS_UKI" > "$backup_dir/lts-uki.sha256"
        stat -c '%n %s %Y' "$LTS_UKI" > "$backup_dir/lts-uki.stat"
    fi

    if [[ -e "$BACKUP_ROOT/latest" && ! -L "$BACKUP_ROOT/latest" ]]; then
        die "$BACKUP_ROOT/latest exists and is not a symbolic link"
    fi
    ln -sfn "$timestamp" "$BACKUP_ROOT/latest"
    ACTIVE_BACKUP="$backup_dir"
}

remove_managed_target() {
    local target="$1"
    local displaced_dir="$2"

    if [[ -L "$target" || -f "$target" ]]; then
        rm -f -- "$target"
    elif [[ -d "$target" ]]; then
        mkdir -p "$displaced_dir$(dirname "$target")"
        mv -- "$target" "$displaced_dir$target"
    fi
}

restore_backup() {
    local backup_dir="$1"
    local state
    local target
    local backup_path
    local displaced_dir

    displaced_dir="$backup_dir/displaced-$(date +%Y%m%d-%H%M%S)"

    [[ -d "$backup_dir" ]] || die "backup directory not found: $backup_dir"
    [[ -f "$backup_dir/manifest.tsv" ]] || die "backup manifest not found: $backup_dir/manifest.tsv"

    while IFS=$'\t' read -r state target; do
        remove_managed_target "$target" "$displaced_dir"
        if [[ "$state" == "present" ]]; then
            backup_path="$backup_dir/files$target"
            [[ -e "$backup_path" || -L "$backup_path" ]] \
                || die "backup entry missing: $backup_path"
            mkdir -p "$(dirname "$target")"
            cp -a --no-dereference -- "$backup_path" "$target"
        fi
    done < "$backup_dir/manifest.tsv"

    [[ -f "$backup_dir/arch-linux-zen.efi" ]] \
        || die "Zen UKI backup missing: $backup_dir/arch-linux-zen.efi"
    cp -a -- "$backup_dir/arch-linux-zen.efi" "$ZEN_UKI"
}

install_copy() {
    local source="$1"
    local target="$2"

    mkdir -p "$(dirname "$target")"
    if [[ -d "$source" ]]; then
        cp -a --reflink=auto --no-preserve=ownership -- "$source" "$target"
    else
        install -m 0644 -- "$source" "$target"
    fi
}

install_tracked_configs() {
    local displaced_dir="$ACTIVE_BACKUP/replaced-during-apply"

    remove_managed_target "$THEME_TARGET" "$displaced_dir"
    install_copy "$THEME_SOURCE" "$THEME_TARGET"
    remove_managed_target "$PLYMOUTH_CONFIG_TARGET" "$displaced_dir"
    install_copy "$PLYMOUTH_CONFIG_SOURCE" "$PLYMOUTH_CONFIG_TARGET"
    remove_managed_target "$MKINITCPIO_CONFIG_TARGET" "$displaced_dir"
    install_copy "$MKINITCPIO_CONFIG_SOURCE" "$MKINITCPIO_CONFIG_TARGET"
    remove_managed_target "$CMDLINE_CONFIG_TARGET" "$displaced_dir"
    install_copy "$CMDLINE_CONFIG_SOURCE" "$CMDLINE_CONFIG_TARGET"
    remove_managed_target "$ZEN_PRESET_TARGET" "$displaced_dir"
    install_copy "$ZEN_PRESET_SOURCE" "$ZEN_PRESET_TARGET"
}

verify_copy_file() {
    local source="$1"
    local target="$2"

    [[ -f "$target" && ! -L "$target" ]] || die "expected regular file: $target"
    cmp -s -- "$source" "$target" || die "installed file differs from tracked source: $target"
}

verify_copy_dir() {
    local source="$1"
    local target="$2"

    [[ -d "$target" && ! -L "$target" ]] || die "expected regular directory: $target"
    diff -qr -- "$source" "$target" >/dev/null \
        || die "installed directory differs from tracked source: $target"
}

verify_cmdline() {
    local cmdline_file="$1"
    local cmdline
    local token
    local token_count

    cmdline="$(tr -d '\0' < "$cmdline_file")"
    grep -qE '(^|[[:space:]])root=' <<< "$cmdline" \
        || die "Zen UKI cmdline lost its root= parameter"

    for token in quiet loglevel=3 splash; do
        token_count="$(tr ' ' '\n' <<< "$cmdline" | grep -Fxc "$token" || true)"
        [[ "$token_count" -eq 1 ]] \
            || die "expected exactly one '$token' token in Zen UKI cmdline, found $token_count"
    done
}

verify_initrd() {
    local initrd_file="$1"
    local listing_file="$2"

    lsinitcpio "$initrd_file" > "$listing_file"

    grep -Eq '/nvidia\.ko(\.zst)?$' "$listing_file" \
        || die "nvidia.ko is missing from the Zen initramfs"
    grep -Eq '/nvidia-modeset\.ko(\.zst)?$' "$listing_file" \
        || die "nvidia-modeset.ko is missing from the Zen initramfs"
    grep -Eq '/nvidia-uvm\.ko(\.zst)?$' "$listing_file" \
        || die "nvidia-uvm.ko is missing from the Zen initramfs"
    grep -Eq '/nvidia-drm\.ko(\.zst)?$' "$listing_file" \
        || die "nvidia-drm.ko is missing from the Zen initramfs"
    if grep -Eq '/nouveau\.ko(\.zst)?$' "$listing_file"; then
        die "nouveau.ko is still present in the Zen initramfs"
    fi

    grep -Fq 'usr/bin/plymouthd' "$listing_file" \
        || die "plymouthd is missing from the Zen initramfs"
    grep -Fq 'usr/lib/plymouth/script.so' "$listing_file" \
        || die "Plymouth script plugin is missing from the Zen initramfs"
    grep -Fq 'usr/share/plymouth/themes/connect/connect.plymouth' "$listing_file" \
        || die "Connect theme is missing from the Zen initramfs"
    [[ "$(grep -Ec 'usr/share/plymouth/themes/connect/progress-[0-9]+\.png$' "$listing_file")" -eq 120 ]] \
        || die "the Zen initramfs does not contain all 120 Connect frames"
}

verify_lts_unchanged() {
    local backup_dir="$1"
    local expected_hash
    local current_hash

    [[ -n "$backup_dir" ]] || return 0
    [[ -f "$backup_dir/lts-uki.sha256" ]] || return 0
    [[ -f "$LTS_UKI" ]] || die "LTS UKI disappeared during Zen rebuild"

    expected_hash="$(awk '{print $1}' "$backup_dir/lts-uki.sha256")"
    current_hash="$(sha256sum "$LTS_UKI" | awk '{print $1}')"
    [[ "$current_hash" == "$expected_hash" ]] \
        || die "LTS UKI changed during the Zen-only rebuild"
}

verify_installation() {
    local backup_dir="${1:-}"
    local temporary_dir
    local splash_geometry

    check_prerequisites
    verify_copy_dir "$THEME_SOURCE" "$THEME_TARGET"
    verify_copy_file "$PLYMOUTH_CONFIG_SOURCE" "$PLYMOUTH_CONFIG_TARGET"
    verify_copy_file "$MKINITCPIO_CONFIG_SOURCE" "$MKINITCPIO_CONFIG_TARGET"
    verify_copy_file "$CMDLINE_CONFIG_SOURCE" "$CMDLINE_CONFIG_TARGET"
    verify_copy_file "$ZEN_PRESET_SOURCE" "$ZEN_PRESET_TARGET"

    [[ "$(plymouth-set-default-theme)" == "connect" ]] \
        || die "Plymouth default theme is not connect"

    splash_geometry="$(identify -format '%wx%h %[channels]' "$THEME_TARGET/connect.bmp")"
    [[ "$splash_geometry" == "800x600 srgba 4.0" ]] \
        || die "unexpected UKI splash format: $splash_geometry"

    temporary_dir="$(mktemp -d)"
    objcopy --dump-section ".splash=$temporary_dir/splash.bmp" "$ZEN_UKI"
    objcopy --dump-section ".cmdline=$temporary_dir/cmdline" "$ZEN_UKI"
    objcopy --dump-section ".initrd=$temporary_dir/initrd" "$ZEN_UKI"

    cmp -s "$temporary_dir/splash.bmp" "$THEME_TARGET/connect.bmp" \
        || die "Zen UKI .splash does not match connect.bmp"
    verify_cmdline "$temporary_dir/cmdline"
    verify_initrd "$temporary_dir/initrd" "$temporary_dir/initrd.list"
    verify_lts_unchanged "$backup_dir"

    rm -rf -- "$temporary_dir"
    echo "Connect Zen UKI verification passed."
}

on_error() {
    local exit_code=$?
    local line_number="$1"

    trap - ERR
    set +e
    echo "Boot splash apply failed at line $line_number (exit $exit_code)." >&2
    if [[ "$ROLLBACK_NEEDED" -eq 1 && -n "$ACTIVE_BACKUP" ]]; then
        echo "Restoring $ACTIVE_BACKUP ..." >&2
        restore_backup "$ACTIVE_BACKUP"
        echo "Original configuration and Zen UKI restored." >&2
    fi
    exit "$exit_code"
}

apply_boot_splash() {
    check_prerequisites
    create_backup
    ROLLBACK_NEEDED=1
    trap 'on_error "$LINENO"' ERR

    install_tracked_configs
    mkinitcpio -p linux-zen
    verify_installation "$ACTIVE_BACKUP"

    ROLLBACK_NEEDED=0
    trap - ERR
    echo "Applied Connect to linux-zen. Backup: $ACTIVE_BACKUP"
}

rollback_boot_splash() {
    local backup_dir

    [[ -L "$BACKUP_ROOT/latest" ]] || die "no boot-splash backup is available"
    backup_dir="$(readlink -e "$BACKUP_ROOT/latest")"
    restore_backup "$backup_dir"
    echo "Restored boot configuration and Zen UKI from $backup_dir"
}

main() {
    local action="${1:-}"

    case "$action" in
        -h|--help|help|"")
            usage
            return 0
            ;;
    esac

    require_root
    case "$action" in
        apply)
            apply_boot_splash
            ;;
        verify)
            verify_installation
            ;;
        rollback)
            rollback_boot_splash
            ;;
        *)
            usage >&2
            die "unknown action: $action"
            ;;
    esac
}

main "$@"
