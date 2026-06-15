#!/bin/bash
set -euo pipefail

APPIMAGE="${NOWLEDGE_MEM_APPIMAGE:-/home/nastem/Applications/nowledge-mem.AppImage}"
THREADS="${NOWLEDGE_MEM_THREADS:-2}"
NICE_LEVEL="${NOWLEDGE_MEM_NICE:-10}"
IONICE_CLASS="${NOWLEDGE_MEM_IONICE_CLASS:-3}"

if [ ! -x "$APPIMAGE" ]; then
    echo "nowledge-mem-desktop: AppImage is not executable: $APPIMAGE" >&2
    exit 1
fi

# Keep the GTK/WebKit window on X11 and prevent model/index startup from
# monopolizing CPU or disk while the desktop is active.
export GDK_BACKEND="${GDK_BACKEND:-x11}"
export GTK_A11Y="${GTK_A11Y:-none}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$THREADS}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-$THREADS}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-$THREADS}"
export NUMEXPR_NUM_THREADS="${NUMEXPR_NUM_THREADS:-$THREADS}"
export BLIS_NUM_THREADS="${BLIS_NUM_THREADS:-$THREADS}"
export VECLIB_MAXIMUM_THREADS="${VECLIB_MAXIMUM_THREADS:-$THREADS}"
export RAYON_NUM_THREADS="${RAYON_NUM_THREADS:-$THREADS}"
export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"

if command -v ionice >/dev/null 2>&1; then
    exec nice -n "$NICE_LEVEL" ionice -c "$IONICE_CLASS" "$APPIMAGE" "$@"
fi

exec nice -n "$NICE_LEVEL" "$APPIMAGE" "$@"
