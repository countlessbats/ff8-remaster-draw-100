# FF8 Remastered — Draw 100 Mod v0.1.1

Any successful Draw (in battle or at a draw point) fills that spell's stock to
the maximum of 100 immediately. Draw resistance and the chance to fail are
unchanged — only the amount you receive.

## Install

1. Copy the `Draw100Mod` folder into your game directory (the folder that
   contains `FFVIII_EFIGS.dll`), e.g.
   `...\SteamLibrary\steamapps\common\FINAL FANTASY VIII Remastered\`
2. With the game closed, run `apply.ps1` (right-click → Run with PowerShell, or
   from a PowerShell window):

```powershell
& "C:\...\FINAL FANTASY VIII Remastered\Draw100Mod\apply.ps1"
```

On first run it saves a backup of the original DLL as
`Draw100Mod\FFVIII_EFIGS.dll.bak` before patching. `apply.ps1` is safe to
re-run at any time.

## Uninstall

Run `restore.ps1` with the game closed. It reverts the patch and verifies the
result (using the backup only as a fallback).

## How it works

The game logic in `FFVIII_EFIGS.dll` adds drawn magic to your stock one unit at
a time through a routine that caps stock at 100. This mod changes 2 bytes of
that routine (`mov bl,[esi]` → `mov bl,100`) so the quantity written back to
your inventory is always the full 100 — the permanent, file-patch equivalent of
the community Cheat Engine script "Full Stock (100) on Draw". The patch site is
located by signature scan, so it fails safely (no write) rather than patching
the wrong bytes if a game update moves the code.

## Notes

- Applies to all non-Japanese languages. The Japanese build uses a separate
  `FFVIII_JP.dll`, which is not patched.
- Steam's "Verify integrity of game files" replaces the patched DLL and removes
  the mod. Run `apply.ps1` again afterwards if you want it back.
- The battle message may still report the normally-rolled draw amount
  (e.g. "Drew 9 Firas"), but the stock becomes 100 regardless.
- No game files are redistributed by this mod; it patches your local copy.
