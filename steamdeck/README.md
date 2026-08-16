# FF8 Remastered - Draw 100 Mod (Steam Deck / Linux) v0.1.4

Makes any successful Draw fill the spell's stock to 100 - both the in-battle
Draw command and field Draw Points. Same patch as the Windows version; the Steam
Deck runs the identical game files through Proton, so it patches the same two
bytes in `FFVIII_EFIGS.dll`.

Draw resistance and the chance to fail are unchanged - only the amount you get.

## Install (Steam Deck, Desktop Mode)

1. Press **STEAM > Power > Switch to Desktop**.
2. In Steam (desktop), right-click **FINAL FANTASY VIII Remastered >
   Manage > Browse local files**. A file window opens on the game folder.
3. Copy the whole **Draw100Mod-SteamDeck** folder into that game folder.
4. Make sure the game is closed. Open the **Draw100Mod-SteamDeck** folder,
   then in the file manager choose **... > Open Terminal** (in Dolphin it is
   the F4 key), and run:

   ```
   bash install.sh
   ```

To uninstall, run `bash uninstall.sh` the same way.

You do not have to put the folder in the game directory - the installer also
searches the usual Steam library locations (internal storage and SD card). If
it cannot find the game, point it at the folder yourself:

```
bash install.sh --game-dir "/run/media/mmcblk0p1/steamapps/common/FINAL FANTASY VIII Remastered"
```

## Check status

```
python3 ff8_draw100.py status
```

## How it works

The game adds drawn magic to your stock one unit at a time through a routine
that caps at 100. That routine exists twice in `FFVIII_EFIGS.dll` - one copy for
in-battle Draw, one for field Draw Points - so this patches both. Each site
changes 2 bytes (`mov bl,[esi]` -> `mov bl,100`) and is found by its own unique
signature, so the patcher fails safely (no write) rather than touching the wrong
bytes if a game update moves the code. A backup of the original DLL is saved
next to it as `FFVIII_EFIGS.dll.draw100-backup` on first install.

## Notes

- Needs Python 3, which is preinstalled on Steam Deck (SteamOS). Nothing else.
- Steam's "Verify integrity of game files" (Properties > Installed Files)
  replaces the patched DLL and removes the mod. Just run `bash install.sh` again.
- Works the same on any Linux install of the game, and on the Steam Deck's
  internal drive or an SD card.
- The battle message may still show the normal rolled amount (e.g. "Drew 9
  Firas"), but the stock becomes 100 regardless.
