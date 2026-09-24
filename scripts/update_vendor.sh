#!/bin/bash

# Check and update pinned third-party code:
#   rime  the rime-frost dictionaries and schemas (vendor/rime-frost submodule)
#   mpv   uosc (release snapshot in vendor/uosc) and thumbfast (vendor/thumbfast
#         submodule), both linked into configs/mpv
#
# Usage: update_vendor.sh [--check] [rime|mpv]...   (default: both)
#
# Updates are staged, not committed, so they can be reviewed with git diff.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

RIME_SUB="$REPO_DIR/vendor/rime-frost"
RIME_BRANCH="master"
RIME_CONF="$REPO_DIR/configs/rime"
RIME_STAMP="$RIME_CONF/build/rime_frost.table.bin"

MPV_DIR="$REPO_DIR/configs/mpv"
UOSC_DIR="$REPO_DIR/vendor/uosc"
UOSC_REPO="tomasklaen/uosc"
THUMBFAST_SUB="$REPO_DIR/vendor/thumbfast"

CHECK=0
TARGETS=()

usage() {
    cat <<'EOF'
Usage: update_vendor.sh [--check] [rime|mpv]...

  rime      Fast-forward vendor/rime-frost to upstream master and redeploy Rime
  mpv       Update uosc to its latest release (merging uosc.conf) and
            fast-forward the thumbfast submodule
  --check   Only report what is outdated; change nothing
EOF
}

while (($#)); do
    case "$1" in
        --check) CHECK=1 ;;
        rime | mpv) TARGETS+=("$1") ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done
if ((${#TARGETS[@]} == 0)); then
    TARGETS=(rime mpv)
fi

if [[ "${EUID}" -eq 0 ]]; then
    echo "Please run this script as a regular user."
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

header() {
    echo ""
    echo "==> $1"
}

note() {
    echo "  $1"
}

warn() {
    echo "  ⚠️  $1"
}

# --- Rime ---

# Upstream files that configs/rime replaces with a tracked regular file
# (symlinks into the submodule have mode 120000 and are skipped; README.md
# documents this repository and is not a copy of upstream's).
rime_overrides() {
    git -C "$REPO_DIR" ls-files -s -- configs/rime |
        awk '$1 != "120000" { sub(/^configs\/rime\//, "", $4); if ($4 != "README.md") print $4 }'
}

report_rime_changes() {
    local old="$1"
    local new="$2"
    local file
    local first
    local lua_changes=()
    local unlinked=()

    git -C "$RIME_SUB" log -n 15 --no-merges --format='    %ad %s' --date=short "$old..$new"
    git -C "$RIME_SUB" diff --shortstat "$old" "$new" | sed 's/^/ /'

    # Lua modules run inside fcitx5 and see every keystroke.
    mapfile -t lua_changes < <(git -C "$RIME_SUB" diff --name-only "$old" "$new" -- '*.lua')
    if ((${#lua_changes[@]})); then
        warn "Lua code changed upstream (it runs inside the input method); review before deploying:"
        printf '      %s\n' "${lua_changes[@]}"
        note "  git -C vendor/rime-frost diff ${old:0:7} ${new:0:7} -- '*.lua'"
    fi

    while read -r file; do
        if ! git -C "$RIME_SUB" diff --quiet "$old" "$new" -- "$file"; then
            if git -C "$RIME_SUB" cat-file -e "$new:$file" 2>/dev/null; then
                warn "upstream changed $file, which configs/rime overrides locally; merge by hand:"
            else
                warn "upstream removed or moved $file, which configs/rime overrides locally; check it:"
            fi
            note "  git -C vendor/rime-frost diff ${old:0:7} ${new:0:7} -- $file"
        fi
    done < <(rime_overrides)

    # Files inside a directory that is linked as a whole appear automatically;
    # anything else new needs its own link in configs/rime.
    while read -r file; do
        first="${file%%/*}"
        if [ -L "$RIME_CONF/$first" ]; then
            continue
        elif [[ "$file" != */* ]]; then
            [ -e "$RIME_CONF/$file" ] || unlinked+=("$file")
        elif [ -d "$RIME_CONF/$first" ]; then
            [ -e "$RIME_CONF/$file" ] || unlinked+=("$file")
        elif [[ " ${unlinked[*]} " != *" $first/ "* ]]; then
            unlinked+=("$first/")
        fi
    done < <(git -C "$RIME_SUB" diff --name-only --diff-filter=A "$old" "$new" -- . ':!.github' ':!*.md')
    if ((${#unlinked[@]})); then
        warn "new upstream files without a link in configs/rime (add one if a schema needs them):"
        printf '      %s\n' "${unlinked[@]}"
    fi
}

# Best effort: ask fcitx5 to reload the Rime addon, then confirm that the
# dictionary was rebuilt. Falls back to asking for a manual redeploy.
redeploy_rime() {
    local before
    local waited=0

    before="$(stat -c %Y "$RIME_STAMP" 2>/dev/null || echo 0)"
    if ! busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 \
        ReloadAddonConfig s rime >/dev/null 2>&1; then
        note "Fcitx5 is not running; choose 「重新部署」 in the Rime menu next time it starts."
        return
    fi

    note "Asked Fcitx5 to reload Rime; waiting for the dictionary rebuild..."
    while ((waited < 90)); do
        if (($(stat -c %Y "$RIME_STAMP" 2>/dev/null || echo 0) > before)); then
            note "✅ Rime redeployed."
            return
        fi
        sleep 3
        waited=$((waited + 3))
    done
    warn "could not confirm a rebuild; choose 「重新部署」 in the Rime menu."
}

update_rime() {
    local old
    local new
    local link

    header "Rime (vendor/rime-frost, upstream $RIME_BRANCH)"
    if ! [ -e "$RIME_SUB/.git" ]; then
        git -C "$REPO_DIR" submodule update --init -- vendor/rime-frost
    fi

    git -C "$RIME_SUB" fetch -q origin "$RIME_BRANCH"
    old="$(git -C "$RIME_SUB" rev-parse HEAD)"
    new="$(git -C "$RIME_SUB" rev-parse FETCH_HEAD)"
    if [[ "$old" == "$new" ]]; then
        note "✅ Up to date (${old:0:7})."
        return
    fi
    if ! git -C "$RIME_SUB" merge-base --is-ancestor "$old" "$new"; then
        warn "upstream history was rewritten (${old:0:7} is not an ancestor of ${new:0:7})."
    fi

    note "$(git -C "$RIME_SUB" rev-list --count "$old..$new") new commit(s): ${old:0:7} -> ${new:0:7}"
    report_rime_changes "$old" "$new"
    if ((CHECK)); then
        return
    fi

    git -C "$RIME_SUB" checkout -q --detach "$new"
    while read -r link; do
        warn "dangling link (removed upstream): ${link#"$REPO_DIR"/}"
    done < <(find "$RIME_CONF" -xtype l)

    git -C "$REPO_DIR" add vendor/rime-frost
    note "✅ Updated; submodule bump staged:"
    note "  git commit -m 'chore(rime): update upstream dictionaries'"
    redeploy_rime
}

# --- mpv ---

uosc_release_dir() {
    local version="$1"
    local dir="$TMP_DIR/uosc-$version"

    if ! [ -d "$dir" ]; then
        mkdir -p "$dir"
        curl -fsSL -o "$dir.zip" "https://github.com/$UOSC_REPO/releases/download/$version/uosc.zip"
        unzip -q "$dir.zip" -d "$dir"
        curl -fsSL -o "$dir/uosc.conf" "https://raw.githubusercontent.com/$UOSC_REPO/$version/src/uosc.conf"
    fi
    printf '%s\n' "$dir"
}

update_uosc() {
    local current
    local latest
    local old_dir
    local new_dir

    current="$(sed -n "s/^local uosc_version = '\(.*\)'/\1/p" "$UOSC_DIR/scripts/uosc/main.lua")"
    latest="$(git ls-remote --tags --refs "https://github.com/$UOSC_REPO.git" |
        awk -F/ '{print $3}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)"
    if [[ "$current" == "$latest" ]]; then
        note "✅ uosc is up to date ($current)."
        return 1
    fi
    note "uosc $current -> $latest: https://github.com/$UOSC_REPO/releases/tag/$latest"
    if ((CHECK)); then
        return 1
    fi

    old_dir="$(uosc_release_dir "$current")"
    new_dir="$(uosc_release_dir "$latest")"

    # Refuse to overwrite local edits to the vendored release.
    if ! diff -rq -x ziggy-darwin -x ziggy-windows.exe \
        "$old_dir/scripts/uosc" "$UOSC_DIR/scripts/uosc" >/dev/null ||
        ! diff -rq "$old_dir/fonts" "$UOSC_DIR/fonts" >/dev/null; then
        warn "vendor/uosc differs from the $current release; update it by hand."
        return 1
    fi

    # Carry local option changes over to the new sample config.
    if ! git merge-file -p "$MPV_DIR/script-opts/uosc.conf" \
        "$old_dir/uosc.conf" "$new_dir/uosc.conf" >"$TMP_DIR/uosc.conf"; then
        warn "uosc.conf changes conflict with the new sample; nothing was changed."
        return 1
    fi

    rsync -a --delete --exclude ziggy-darwin --exclude ziggy-windows.exe \
        "$new_dir/scripts/uosc/" "$UOSC_DIR/scripts/uosc/"
    rsync -a --delete "$new_dir/fonts/" "$UOSC_DIR/fonts/"
    cp -- "$TMP_DIR/uosc.conf" "$MPV_DIR/script-opts/uosc.conf"
    note "✅ uosc updated to $latest (uosc.conf merged)."
}

update_thumbfast() {
    local old
    local new

    if ! [ -e "$THUMBFAST_SUB/.git" ]; then
        git -C "$REPO_DIR" submodule update --init -- vendor/thumbfast
    fi
    git -C "$THUMBFAST_SUB" fetch -q origin HEAD
    old="$(git -C "$THUMBFAST_SUB" rev-parse HEAD)"
    new="$(git -C "$THUMBFAST_SUB" rev-parse FETCH_HEAD)"
    if [[ "$old" == "$new" ]]; then
        note "✅ thumbfast is up to date (${old:0:7})."
        return 1
    fi
    note "thumbfast ${old:0:7} -> ${new:0:7}:"
    git -C "$THUMBFAST_SUB" log -n 10 --format='    %ad %s' --date=short "$old..$new"
    if ((CHECK)); then
        return 1
    fi
    git -C "$THUMBFAST_SUB" checkout -q --detach "$new"
    note "✅ thumbfast updated."
}

# Load the scripts in a headless mpv and ask uosc for its version.
verify_mpv() {
    local probe="$TMP_DIR/probe.lua"
    local output

    command -v mpv >/dev/null 2>&1 || return 0
    cat >"$probe" <<'EOF'
mp.register_script_message('uosc-version', function(v) mp.msg.warn('uosc-version ' .. v) end)
mp.add_timeout(1, function() mp.commandv('script-message-to', 'uosc', 'get-version', mp.get_script_name()) end)
EOF
    output="$(timeout 20 mpv --config-dir="$MPV_DIR" --vo=null --ao=null --script="$probe" \
        --msg-level=all=warn 'av://lavfi:testsrc=duration=3' --length=3 2>&1 || true)"
    if grep -qiE 'error|traceback' <<<"$output"; then
        warn "mpv reported errors while loading the scripts:"
        # shellcheck disable=SC2001 # indenting every line, not a single substitution
        sed 's/^/      /' <<<"$output"
    elif grep -q 'uosc-version' <<<"$output"; then
        note "✅ mpv loads the scripts ($(grep -o 'uosc-version .*' <<<"$output"))."
    else
        warn "uosc did not answer in a headless mpv; check playback manually."
    fi
}

update_mpv() {
    local changed=0

    header "mpv scripts (uosc, thumbfast)"
    update_uosc && changed=1
    update_thumbfast && changed=1
    if ((changed)); then
        verify_mpv
        git -C "$REPO_DIR" add vendor/uosc vendor/thumbfast configs/mpv/script-opts/uosc.conf
        note "Staged; commit with: git commit -m 'chore(mpv): update uosc and thumbfast'"
    fi
}

for target in "${TARGETS[@]}"; do
    "update_$target"
done
