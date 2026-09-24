#!/bin/bash

# Lint tracked shell and Python scripts: bash -n, shellcheck, shfmt, py_compile.
# Usage: lint.sh [--fix]   (--fix rewrites files with shfmt)

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
SHFMT_OPTS=(-i 4 -ci)
FIX=0
FAILED=0

case "${1:-}" in
    --fix) FIX=1 ;;
    "") ;;
    *)
        echo "Usage: lint.sh [--fix]" >&2
        exit 1
        ;;
esac

cd "$REPO_DIR"

# Vendored third-party code is linted upstream, not here.
list_tracked() {
    git ls-files -- . ':!configs/rime' ':!configs/mpv' ':!vendor'
}

mapfile -t SHELL_FILES < <(
    list_tracked | while read -r file; do
        if [[ "$file" == *.sh ]] || head -n1 -- "$file" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b'; then
            printf '%s\n' "$file"
        fi
    done
)
mapfile -t PYTHON_FILES < <(
    list_tracked | while read -r file; do
        if [[ "$file" == *.py ]] || head -n1 -- "$file" 2>/dev/null | grep -qE '^#!.*python'; then
            printf '%s\n' "$file"
        fi
    done
)

step() {
    echo ""
    echo "==> $1"
}

fail() {
    FAILED=1
    echo "❌ $1"
}

step "bash -n (${#SHELL_FILES[@]} files)"
for file in "${SHELL_FILES[@]}"; do
    bash -n -- "$file" || fail "syntax error in $file"
done

step "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK=(shellcheck)
elif command -v uvx >/dev/null 2>&1; then
    SHELLCHECK=(uvx --quiet --from shellcheck-py shellcheck)
else
    SHELLCHECK=()
    echo "⚠️  shellcheck not found (sudo pacman -S shellcheck); skipped."
fi
if ((${#SHELLCHECK[@]})); then
    "${SHELLCHECK[@]}" --external-sources --source-path=SCRIPTDIR -- "${SHELL_FILES[@]}" \
        || fail "shellcheck reported problems"
fi

step "shfmt ${SHFMT_OPTS[*]}"
if command -v shfmt >/dev/null 2>&1; then
    if ((FIX)); then
        shfmt -w "${SHFMT_OPTS[@]}" -- "${SHELL_FILES[@]}"
    else
        shfmt -d "${SHFMT_OPTS[@]}" -- "${SHELL_FILES[@]}" \
            || fail "shfmt: formatting differs (run: archpostinstall lint --fix)"
    fi
else
    echo "⚠️  shfmt not found (sudo pacman -S shfmt); skipped."
fi

step "python compile (${#PYTHON_FILES[@]} files)"
for file in "${PYTHON_FILES[@]}"; do
    python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' "$file" \
        || fail "syntax error in $file"
done

echo ""
if ((FAILED)); then
    echo "❗ Lint failed."
    exit 1
fi
echo "✨ Lint passed."
