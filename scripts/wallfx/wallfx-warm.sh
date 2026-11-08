#!/usr/bin/env bash
# Mosaic OS: precomputes the outline maps of a wallpaper folder (wallfx-map.py
# --warm), in the background and gently: lowest priority, idle I/O, two threads.
# Does nothing until the cut-out is installed (~/.local/share/mosaic-os/wallfx/venv),
# and never runs twice at once (flock).
#   wallfx-warm.sh <folder>
set -u
DIR="${1:?usage: wallfx-warm.sh <folder>}"
PY="$HOME/.local/share/mosaic-os/wallfx/venv/bin/python"
CACHE="$HOME/.cache/mosaic-os/wallfx"
[ -x "$PY" ] || exit 0
mkdir -p "$CACHE"
exec 9>"$CACHE/.lock"
flock -n 9 || exit 0
OMP_NUM_THREADS=2 ORT_NUM_THREADS=2 nice -n 19 ionice -c 3 \
    "$PY" "$(dirname "$(readlink -f "$0")")/wallfx-map.py" --warm "$DIR" "$CACHE" 2>/dev/null
