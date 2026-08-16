#!/usr/bin/env bash
# FF8 Remastered - Draw 100 Mod : Steam Deck / Linux uninstaller
# Reverts the patch. Close the game first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PY=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
    echo "ERROR: Python 3 was not found." >&2
    exit 1
fi

exec "$PY" "$here/ff8_draw100.py" restore "$@"
