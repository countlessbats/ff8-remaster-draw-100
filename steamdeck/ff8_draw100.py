#!/usr/bin/env python3
"""
FF8 Remastered - Draw 100 Mod (cross-platform patcher)

Forces any successful Draw to fill the spell's stock to 100, for BOTH the
in-battle Draw command and field Draw Points. Works on Steam Deck / Linux (and
Windows/macOS): the game is the same Windows build everywhere, so this patches
the same two bytes in FFVIII_EFIGS.dll.

Usage:
    python3 ff8_draw100.py apply    [--game-dir DIR]
    python3 ff8_draw100.py restore  [--game-dir DIR]
    python3 ff8_draw100.py status   [--game-dir DIR]

No third-party modules required (standard library only).
"""

import os
import sys
import shutil
import glob

__version__ = "0.1.5"

DLL_NAME = "FFVIII_EFIGS.dll"
BACKUP_NAME = "FFVIII_EFIGS.dll.draw100-backup"

# The two draw-to-stock writeback sites. Each is a unique 16-byte signature;
# patch_off is where the 2 bytes sit (8A 1E = mov bl,[esi] -> B3 64 = mov bl,100).
SITES = [
    {
        "name": "in-battle Draw",
        "context": bytes([0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0x8A,0x1E,0x8D,0x51,0x04]),
        "patch_off": 11,
    },
    {
        "name": "field Draw Point",
        "context": bytes([0xFE,0x06,0x8D,0x51,0x04,0xA1,0xE0,0xB5,0x6C,0x11,0x8A,0x1E,0x53,0x8B,0x04,0x01]),
        "patch_off": 10,
    },
]
PATCH = bytes([0xB3, 0x64])      # mov bl, 100
ORIG = bytes([0x8A, 0x1E])       # mov bl, [esi]


def patched_sig(site):
    b = bytearray(site["context"])
    b[site["patch_off"]:site["patch_off"] + 2] = PATCH
    return bytes(b)


def script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def candidate_game_dirs():
    """Common Steam library locations for this game, across Steam Deck/Linux setups."""
    home = os.path.expanduser("~")
    game = "steamapps/common/FINAL FANTASY VIII Remastered"
    roots = [
        f"{home}/.local/share/Steam",
        f"{home}/.steam/steam",
        f"{home}/.steam/root",
        f"{home}/.var/app/com.valvesoftware.Steam/data/Steam",  # Flatpak Steam
    ]
    cands = [os.path.join(r, game) for r in roots]
    # SD card / external drives (SteamOS mounts under /run/media)
    for pat in ("/run/media/*/", "/run/media/deck/*/", "/media/*/"):
        cands += [os.path.join(p, game) for p in glob.glob(pat)]
    # Windows drive letters, for good measure
    for drive in "CDEFGH":
        cands.append(f"{drive}:/SteamLibrary/steamapps/common/FINAL FANTASY VIII Remastered")
        cands.append(f"{drive}:/Program Files (x86)/Steam/steamapps/common/FINAL FANTASY VIII Remastered")
    return cands


def find_game_dir_optional(override):
    """Return the game folder if found, else None (never raises)."""
    if override:
        dll = os.path.join(override, DLL_NAME)
        return os.path.abspath(override) if os.path.isfile(dll) else None
    # 1) Walk up from the script's folder (works if placed inside the game folder).
    d = script_dir()
    for _ in range(8):
        if os.path.isfile(os.path.join(d, DLL_NAME)):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    # 2) Search common Steam library locations.
    for c in candidate_game_dirs():
        if os.path.isfile(os.path.join(c, DLL_NAME)):
            return os.path.abspath(c)
    return None


def find_game_dir(override):
    g = find_game_dir_optional(override)
    if g is not None:
        return g
    if override:
        raise SystemExit(f"ERROR: {DLL_NAME} not found in --game-dir: {override}")
    raise SystemExit(
        "ERROR: Could not find FFVIII_EFIGS.dll.\n"
        "Put this folder inside your 'FINAL FANTASY VIII Remastered' game folder and\n"
        "run it again, or pass the folder explicitly:\n"
        "    python3 ff8_draw100.py apply --game-dir \"/path/to/FINAL FANTASY VIII Remastered\""
    )


def find_unique(data, needle, label):
    hits = []
    start = 0
    while True:
        i = data.find(needle, start)
        if i < 0:
            break
        hits.append(i)
        start = i + 1
    if len(hits) > 1:
        raise SystemExit(f"ERROR: {label} matched {len(hits)} times (ambiguous); nothing was changed.")
    return hits[0] if hits else None


def resolve(data, site, want):
    """want='apply' or 'restore'. Returns (action, offset) where action is
    'do' (write), 'skip' (already in target state), or raises on missing."""
    ctx = site["context"]
    pat = patched_sig(site)
    ci = find_unique(data, ctx, f"{site['name']} (original)")
    pi = find_unique(data, pat, f"{site['name']} (patched)")
    if want == "apply":
        if ci is not None:
            return ("do", ci + site["patch_off"])
        if pi is not None:
            return ("skip", None)
    else:  # restore
        if pi is not None:
            return ("do", pi + site["patch_off"])
        if ci is not None:
            return ("skip", None)
    raise SystemExit(f"ERROR: could not find the {site['name']} draw code (different game version?); nothing was changed.")


def cmd_status(game_dir):
    dll = os.path.join(game_dir, DLL_NAME)
    data = open(dll, "rb").read()
    print(f"Game folder: {game_dir}")
    for s in SITES:
        ci = find_unique(data, s["context"], s["name"])
        pi = find_unique(data, patched_sig(s), s["name"])
        state = "PATCHED (100)" if pi is not None else ("original" if ci is not None else "NOT FOUND")
        print(f"  {s['name']:18}: {state}")


def cmd_apply(game_dir):
    dll = os.path.join(game_dir, DLL_NAME)
    bak = os.path.join(game_dir, BACKUP_NAME)
    data = open(dll, "rb").read()
    print(f"Game folder: {game_dir}")

    plan = [(s, *resolve(data, s, "apply")) for s in SITES]
    if all(action == "skip" for _, action, _ in plan):
        print("Draw 100 Mod is already fully applied (both draw types). Nothing to do.")
        return

    if not os.path.exists(bak):
        shutil.copy2(dll, bak)
        print(f"Backed up original DLL to: {bak}")

    buf = bytearray(data)
    for site, action, off in plan:
        if action == "skip":
            print(f"  {site['name']}: already patched.")
            continue
        buf[off:off + 2] = PATCH
        print(f"  {site['name']}: patched.")
    with open(dll, "r+b") as f:
        f.write(buf)

    # verify
    check = open(dll, "rb").read()
    for site in SITES:
        if find_unique(check, patched_sig(site), site["name"]) is None:
            raise SystemExit(f"ERROR: verification failed for {site['name']}. Run the uninstaller.")
    print("Draw 100 Mod applied. Both in-battle Draw and field Draw Points now fill stock to 100.")


def cmd_restore(game_dir):
    dll = os.path.join(game_dir, DLL_NAME)
    bak = os.path.join(game_dir, BACKUP_NAME)
    data = open(dll, "rb").read()
    print(f"Game folder: {game_dir}")

    try:
        plan = [(s, *resolve(data, s, "restore")) for s in SITES]
    except SystemExit:
        # Targeted revert not possible; fall back to a full backup restore.
        if os.path.exists(bak):
            shutil.copy2(bak, dll)
            print(f"A patch site was not found; restored full DLL from backup: {bak}")
            return
        raise
    if all(action == "skip" for _, action, _ in plan):
        print("DLL is already original (both draw types). Nothing to restore.")
        return

    buf = bytearray(data)
    for site, action, off in plan:
        if action == "skip":
            print(f"  {site['name']}: already original.")
            continue
        buf[off:off + 2] = ORIG
        print(f"  {site['name']}: reverted.")
    with open(dll, "r+b") as f:
        f.write(buf)
    print("Original draw code restored for both draw types.")


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else ""
    override = None
    if "--game-dir" in args:
        i = args.index("--game-dir")
        override = args[i + 1] if i + 1 < len(args) else None
    if cmd not in ("apply", "restore", "status", "locate"):
        print(__doc__)
        raise SystemExit(2)
    if cmd == "locate":
        # Print the game folder if found (for GUI wrappers); exit 3 if not found.
        g = find_game_dir_optional(override)
        if g:
            print(g)
            return
        raise SystemExit(3)
    game_dir = find_game_dir(override)
    {"apply": cmd_apply, "restore": cmd_restore, "status": cmd_status}[cmd](game_dir)


if __name__ == "__main__":
    main()
