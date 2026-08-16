#!/usr/bin/env bash
# FF8 Remastered - Draw 100 Mod : graphical installer/uninstaller (Steam Deck / KDE).
#
# Double-click the matching launcher:
#   "Install Draw 100 (Steam Deck).desktop"   -> runs: gui.sh apply
#   "Uninstall Draw 100 (Steam Deck).desktop" -> runs: gui.sh restore
# Or run directly:  bash gui.sh apply
#
# It auto-detects the game folder, opens a folder picker already pointing there
# (so you just confirm), then patches and shows the result - no terminal needed.

set -uo pipefail

action="${1:-apply}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- pick a graphical dialog tool (kdialog ships with the Steam Deck's KDE) ---
DLG=""
if command -v kdialog >/dev/null 2>&1; then DLG=kdialog
elif command -v zenity  >/dev/null 2>&1; then DLG=zenity
fi
info() {
    case "$DLG" in
        kdialog) kdialog --title "FF8 Draw 100" --msgbox "$1" ;;
        zenity)  zenity  --info --title="FF8 Draw 100" --width=460 --text="$1" ;;
        *)       printf '%s\n' "$1" ;;
    esac
}
fail() {
    case "$DLG" in
        kdialog) kdialog --title "FF8 Draw 100" --error "$1" ;;
        zenity)  zenity  --error --title="FF8 Draw 100" --width=460 --text="$1" ;;
        *)       printf 'ERROR: %s\n' "$1" >&2 ;;
    esac
}
ask_dir() {  # ask_dir <start-dir> -> prints chosen folder (empty if cancelled)
    case "$DLG" in
        kdialog) kdialog --title "Select your FINAL FANTASY VIII Remastered folder" --getexistingdirectory "$1" ;;
        zenity)  zenity  --file-selection --directory --title="Select your FINAL FANTASY VIII Remastered folder" --filename="$1/" ;;
        *)       return 1 ;;
    esac
}

# --- need Python 3 (preinstalled on Steam Deck) ---
PY=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
    fail "Python 3 was not found. It is preinstalled on Steam Deck (SteamOS); on other Linux, install Python 3."
    exit 1
fi

patcher="$here/ff8_draw100.py"
if [ ! -f "$patcher" ]; then
    fail "ff8_draw100.py was not found next to this launcher. Keep all the mod files together in one folder."
    exit 1
fi

# --- auto-detect a good starting folder for the picker ---
start="$("$PY" "$patcher" locate 2>/dev/null || true)"
[ -n "$start" ] || start="$HOME"

# --- no GUI available: fall back to the auto-detected folder, else explain ---
if [ -z "$DLG" ]; then
    if [ -f "$start/FFVIII_EFIGS.dll" ]; then
        "$PY" "$patcher" "$action" --game-dir "$start"
        exit $?
    fi
    echo "No graphical dialog (kdialog/zenity) found and could not auto-locate the game." >&2
    echo "Run from a terminal:  $PY \"$patcher\" $action --game-dir \"/path/to/FINAL FANTASY VIII Remastered\"" >&2
    exit 1
fi

# --- ask the user to confirm/choose the folder (pre-aimed at the detected one) ---
game="$(ask_dir "$start")" || exit 0
[ -n "$game" ] || exit 0

if [ ! -f "$game/FFVIII_EFIGS.dll" ]; then
    fail "That folder does not contain FFVIII_EFIGS.dll:

$game

Please pick your 'FINAL FANTASY VIII Remastered' folder (the one with FFVIII_EFIGS.dll)."
    exit 1
fi

out="$("$PY" "$patcher" "$action" --game-dir "$game" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then info "$out"; else fail "$out"; fi
exit "$rc"
