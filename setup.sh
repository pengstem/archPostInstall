#!/bin/bash

# =============================================================================
# Arch Post-Install: Dotfiles Setup Script
# =============================================================================
#
# Installs every entry of manifest.tsv. See that file for the format.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
MANIFEST="$REPO_DIR/manifest.tsv"
ALL_GROUPS=(pacman system user)
USER_NAME="$(id -un)"

DRY_RUN=0
CHECK=0
SELECTED_GROUPS=()
ISSUES=0
RENDER_DIR=""

usage() {
    cat <<'EOF'
Usage: setup.sh [--group pacman|system|user]... [--dry-run] [--check]

  --group G   Only install group G (repeatable; default: all, in manifest order)
  --dry-run   Print what would change without touching anything
  --check     Report missing sources, drifted targets, and leftover backups;
              exits 1 when something needs attention (never uses sudo)
EOF
}

while (($#)); do
    case "$1" in
        --group)
            SELECTED_GROUPS+=("${2:?--group needs a value}")
            shift 2
            ;;
        -n | --dry-run)
            DRY_RUN=1
            shift
            ;;
        --check)
            CHECK=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "${EUID}" -eq 0 ]]; then
    echo "Please run this script as a regular user with sudo privileges."
    exit 1
fi

if ((${#SELECTED_GROUPS[@]} == 0)); then
    SELECTED_GROUPS=("${ALL_GROUPS[@]}")
fi
for group in "${SELECTED_GROUPS[@]}"; do
    if [[ " ${ALL_GROUPS[*]} " != *" $group "* ]]; then
        echo "Unknown group: $group (expected one of: ${ALL_GROUPS[*]})" >&2
        exit 1
    fi
done

RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT

# --- Helpers ---

status() {
    printf '  %-24s %s\n' "[$1]" "$2"
}

issue() {
    ISSUES=$((ISSUES + 1))
    status "$1" "⚠️  $2"
}

# Run a mutating command, or only describe it under --dry-run.
run() {
    if ((DRY_RUN)); then
        printf '      would run: %s\n' "$*"
    else
        "$@"
    fi
}

is_repo_link() {
    [ -L "$1" ] && [[ "$(readlink -f "$1" 2>/dev/null)" == "$REPO_DIR"/* ]]
}

# Clear the destination before installing. Links back into this repository
# are simply removed (their content is tracked); anything else is backed up.
make_room() {
    local dest="$1"
    shift

    if ! [ -e "$dest" ] && ! [ -L "$dest" ]; then
        return
    fi
    if is_repo_link "$dest"; then
        run "$@" rm -f -- "$dest"
    else
        run "$@" mv -- "$dest" "$dest.bak_$(date +%s)"
    fi
}

# Comment out pacman Include lines whose literal target does not exist yet
# (for example a vendor repo that its own package sets up), so a fresh
# machine can still run pacman.
drop_missing_includes() {
    local file="$1"
    local line
    local path

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:space:]]*Include[[:space:]]*=[[:space:]]*([^[:space:]]+) ]]; then
            path="${BASH_REMATCH[1]}"
            if ! [[ "$path" =~ [*?[] ]] && ! [ -e "$path" ]; then
                printf '# archpostinstall: skipped, %s does not exist\n#%s\n' "$path" "$line"
                continue
            fi
        fi
        printf '%s\n' "$line"
    done < "$file" > "$file.tmp"
    mv -- "$file.tmp" "$file"
}

# Print the path of the file to install for a copy/template entry.
render_source() {
    local src="$1"
    local mode="$2"
    local dest="$3"
    local out

    if [[ "$mode" != sudo-template && "$dest" != /etc/pacman.conf ]]; then
        printf '%s\n' "$src"
        return
    fi

    out="$RENDER_DIR/$(basename "$dest")"
    if [[ "$mode" == sudo-template ]]; then
        sed -e "s|@REPO_DIR@|$REPO_DIR|g" \
            -e "s|@USER@|$USER_NAME|g" \
            -e "s|@HOME@|$HOME|g" \
            "$src" > "$out"
    else
        cp -- "$src" "$out"
    fi
    if [[ "$dest" == /etc/pacman.conf ]]; then
        drop_missing_includes "$out"
    fi
    printf '%s\n' "$out"
}

install_link() {
    local src="$1"
    local dest="$2"
    local label="$3"
    shift 3

    if [ -L "$dest" ] && [ "$(readlink -f "$dest")" == "$src" ]; then
        status "$label" "✅ Already linked"
        return
    fi
    if ((CHECK)); then
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            issue "$label" "$dest is not linked to $src"
        else
            issue "$label" "$dest is missing"
        fi
        return
    fi

    make_room "$dest" "$@"
    run "$@" mkdir -p -- "$(dirname "$dest")"
    run "$@" ln -s -- "$src" "$dest"
    status "$label" "$( ((DRY_RUN)) && echo "Would link" || echo "✅ Linked")${1:+ ($1)}"
}

install_copy() {
    local src="$1"
    local installed="$2"
    local dest="$3"
    local label="$4"
    local file_mode=0644

    if ! [ -L "$dest" ]; then
        if [ -d "$installed" ] && [ -d "$dest" ] && diff -qr -- "$installed" "$dest" >/dev/null 2>&1; then
            status "$label" "✅ Already copied"
            return
        fi
        if [ -f "$installed" ] && [ -f "$dest" ] && cmp -s -- "$installed" "$dest"; then
            status "$label" "✅ Already copied"
            return
        fi
    fi
    if ((CHECK)); then
        if [ -L "$dest" ]; then
            issue "$label" "$dest is a symlink; run 'archpostinstall sync-system'"
        elif [ -e "$dest" ]; then
            issue "$label" "$dest differs from $src"
        else
            issue "$label" "$dest is missing"
        fi
        return
    fi

    make_room "$dest" sudo
    run sudo mkdir -p -- "$(dirname "$dest")"
    if [ -d "$installed" ]; then
        run sudo cp -a --reflink=auto --no-preserve=ownership -- "$installed" "$dest"
    else
        [ -x "$src" ] && file_mode=0755
        run sudo install -m "$file_mode" -- "$installed" "$dest"
    fi
    status "$label" "$( ((DRY_RUN)) && echo "Would copy" || echo "✅ Copied") (sudo)"
}

report_backups() {
    local dest="$1"
    local label="$2"
    local backups=()

    mapfile -t backups < <(compgen -G "$dest.bak_*" || true)
    if ((${#backups[@]})); then
        issue "$label" "${#backups[@]} leftover backup(s): $dest.bak_*"
    fi
}

process_entry() {
    local mode="$1"
    local src="$REPO_DIR/$2"
    local dest="$3"
    local label="$4"
    local guard=""

    # shellcheck disable=SC2088 # the manifest stores a literal "~/"
    if [[ "$dest" == "~/"* ]]; then
        dest="$HOME/${dest:2}"
    fi
    if [[ "$mode" == link:* ]]; then
        guard="$REPO_DIR/${mode#link:}"
        mode="link"
    fi

    if ! [ -e "$src" ]; then
        issue "$label" "source not found: $src"
        return
    fi
    if [ -n "$guard" ] && ! [ -e "$guard" ]; then
        status "$label" "Skipped (${guard#"$REPO_DIR"/} missing)"
        return
    fi

    case "$mode" in
        link) install_link "$src" "$dest" "$label" ;;
        sudo-link) install_link "$src" "$dest" "$label" sudo ;;
        sudo-copy | sudo-template)
            install_copy "$src" "$(render_source "$src" "$mode" "$dest")" "$dest" "$label"
            ;;
        *)
            issue "$label" "unknown mode '$mode' in manifest.tsv"
            return
            ;;
    esac

    if ((CHECK)); then
        report_backups "$dest" "$label"
    fi
}

process_group() {
    local wanted="$1"
    local group mode src dest label

    echo ""
    echo "==========================================================="
    echo "   🔗 ${wanted^} targets"
    echo "==========================================================="

    while read -r group mode src dest label <&3; do
        [[ -z "$group" || "$group" == \#* ]] && continue
        [[ "$group" == "$wanted" ]] || continue
        process_entry "$mode" "$src" "$dest" "$label"
    done 3< "$MANIFEST"
}

# --- Main ---

for group in "${ALL_GROUPS[@]}"; do
    [[ " ${SELECTED_GROUPS[*]} " == *" $group "* ]] || continue

    # Initialize the recorded Rime upstream revision; upgrades remain manual.
    if [[ "$group" == user ]] && ! [ -f "$REPO_DIR/vendor/rime-frost/default.yaml" ]; then
        if ((CHECK)); then
            issue "Rime Upstream" "vendor/rime-frost submodule is not initialized"
        else
            run git -C "$REPO_DIR" submodule update --init -- vendor/rime-frost
        fi
    fi

    process_group "$group"
done

echo ""
if ((CHECK)); then
    if ((ISSUES)); then
        echo "❗ $ISSUES issue(s) found."
        exit 1
    fi
    echo "✨ Everything matches manifest.tsv."
elif ((DRY_RUN)); then
    echo "✨ Dry run complete; nothing was changed."
else
    echo "✨ Configuration linking complete!"
fi
