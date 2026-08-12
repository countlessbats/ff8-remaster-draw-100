# FF8 Remastered - Draw 100 Mod v0.1.3

Any successful Draw fills that spell's stock to the maximum of 100 immediately -
both the in-battle Draw command and field Draw Points. Draw resistance and the
chance to fail are unchanged - only the amount you receive.

## Install (easy way)

1. Copy the whole `Draw100Mod` folder into your game folder - the one that
   contains `FFVIII_EFIGS.dll`. On Steam that is usually:
   `...\steamapps\common\FINAL FANTASY VIII Remastered\`
2. Close the game.
3. Double-click **Install Draw 100 Mod.bat**.

That's it. To undo it later, double-click **Uninstall Draw 100 Mod.bat**.

The installer finds the game folder automatically by looking for
`FFVIII_EFIGS.dll` next to itself and in the folders above it, so it works
whether you keep the `Draw100Mod` folder inside the game folder or drop the
files straight into the game folder. If it still can't find the game, you can
point it at the folder yourself:

```
powershell -NoProfile -ExecutionPolicy Bypass -File ".\apply.ps1" -GameDir "D:\Games\FINAL FANTASY VIII Remastered"
```

## Files

- `Install Draw 100 Mod.bat` / `Uninstall Draw 100 Mod.bat` - double-click launchers
- `apply.ps1` / `restore.ps1` - the actual scripts (safe to re-run)
- `FFVIII_EFIGS.dll.draw100-backup` - created next to the game DLL on first
  install; used as a safety net for uninstall. Do not delete it.

## How it works

The game adds drawn magic to your stock one unit at a time through a routine
that caps stock at 100. There are two copies of that routine - one for the
in-battle Draw command and one for field Draw Points - so this mod patches
both. Each site changes 2 bytes (`mov bl,[esi]` -> `mov bl,100`) so the quantity
written back to your inventory is always the full 100 - the permanent, file-patch
equivalent of the community Cheat Engine script "Full Stock (100) on Draw". Each
site is located by its own signature scan, so the installer fails safely (no
write) rather than patching the wrong bytes if a game update moves the code.

## Changelog

- v0.1.3 - also patch field Draw Points (v0.1.2 only affected the in-battle Draw command).
- v0.1.2 - ASCII-only scripts, auto-locate the game folder, double-click .bat launchers.
- v0.1.1 - initial release (in-battle Draw only).

## Notes

- Applies to all non-Japanese languages. The Japanese build uses a separate
  `FFVIII_JP.dll`, which is not patched.
- Steam's "Verify integrity of game files" replaces the patched DLL and removes
  the mod. Just run the installer again afterwards.
- The battle message may still report the normally-rolled draw amount
  (e.g. "Drew 9 Firas"), but the stock becomes 100 regardless.
- No game files are redistributed by this mod; it patches your local copy.
