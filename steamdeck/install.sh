#!/usr/bin/env bash
# FF8 Remastered - Draw 100 Mod : Steam Deck / Linux installer
# Runs the patcher against your game's FFVIII_EFIGS.dll. Close the game first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PY=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
    echo "ERROR: Python 3 was not found. It is preinstalled on Steam Deck (SteamOS);" >&2
    echo "on other Linux distros, install Python 3 and try again." >&2
    exit 1
fi

exec "$PY" "$here/ff8_draw100.py" apply "$@"
