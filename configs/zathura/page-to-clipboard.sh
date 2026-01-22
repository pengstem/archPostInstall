#!/bin/bash
set -euo pipefail

file="$1"
page="$2"
tmp_dir="$(mktemp -d)"

cleanup_tmp() {
    rm -rf "$tmp_dir"
}

trap cleanup_tmp EXIT

if command -v mutool >/dev/null 2>&1; then
    img="$tmp_dir/page.png"
    mutool draw -F png -r 150 -o "$img" "$file" "$page"
elif command -v pdftoppm >/dev/null 2>&1; then
    out="$tmp_dir/page"
    pdftoppm -r 150 -f "$page" -l "$page" -png "$file" "$out"
    img="${out}-${page}.png"
else
    echo "zathura: need mutool or pdftoppm" >&2
    exit 1
fi

if command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$img"
elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -t image/png -i "$img"
elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input --mime-type image/png < "$img"
else
    echo "zathura: need wl-copy/xclip/xsel" >&2
    exit 1
fi
