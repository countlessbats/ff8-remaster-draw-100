# FF8 Remastered - Draw 100 Mod (Steam Deck / Linux) v0.1.5

Makes any successful Draw fill the spell's stock to 100 - both the in-battle
Draw command and field Draw Points. Same patch as the Windows version; the Steam
Deck runs the identical game files through Proton, so it patches the same two
bytes in `FFVIII_EFIGS.dll`.

Draw resistance and the chance to fail are unchanged - only the amount you get.

## Easiest install (Steam Deck, Desktop Mode) - no terminal

1. Press **STEAM > Power > Switch to Desktop**.
2. Copy the whole **Draw100Mod-SteamDeck** folder somewhere on the Deck (your
   Downloads folder is fine - it does not have to be in the game folder).
3. Open the folder. **First time only:** right-click
   **Install Draw 100 (Steam Deck).desktop > Properties > Permissions**, tick
   **Is executable**, click **OK**. (KDE requires this before it will run a
   launcher.)
4. Make sure the game is closed. Double-click
   **Install Draw 100 (Steam Deck).desktop**. If KDE asks, choose
   **Continue / Execute**.
5. A window pops up already pointing at your game folder - just click **OK** to
   confirm. You will get a message when it is done.

To uninstall, double-click **Uninstall Draw 100 (Steam Deck).desktop** the same
way.

The picker starts at the auto-detected game folder (internal storage or SD
card). If detection misses, browse to your **FINAL FANTASY VIII Remastered**
folder (the one containing `FFVIII_EFIGS.dll`) and select it.

## If double-clicking will not run (fallback)

Open the folder in the file manager, use **... > Open Terminal**, and run:

```
bash gui.sh apply
```

That opens the same folder picker. Uninstall with `bash gui.sh restore`. If you
prefer no dialog at all, `bash install.sh` / `bash uninstall.sh` patch the
auto-detected game folder directly.

## Check status

```
python3 ff8_draw100.py status
```

## What's in this folder

- `Install Draw 100 (Steam Deck).desktop` / `Uninstall ... .desktop` -
  double-click launchers with a graphical folder picker.
- `gui.sh` - the graphical installer the launchers call (also runnable directly).
- `install.sh` / `uninstall.sh` - no-dialog terminal versions.
- `ff8_draw100.py` - the actual patcher (Python 3, standard library only).

## How it works

The game adds drawn magic to your stock one unit at a time through a routine
that caps at 100. That routine exists twice in `FFVIII_EFIGS.dll` - one copy for
in-battle Draw, one for field Draw Points - so this patches both. Each site
changes 2 bytes (`mov bl,[esi]` -> `mov bl,100`) and is found by its own unique
signature, so it fails safely (no write) rather than touching the wrong bytes if
a game update moves the code. A backup of the original DLL is saved next to it
as `FFVIII_EFIGS.dll.draw100-backup` on first install.

## Notes

- Needs Python 3 and (for the popup) `kdialog` - both preinstalled on Steam Deck.
  On other Linux, `zenity` also works; with neither, it patches the
  auto-detected folder and prints to the terminal.
- Steam's "Verify integrity of game files" (Properties > Installed Files)
  replaces the patched DLL and removes the mod. Just run the installer again.
- The battle message may still show the normal rolled amount (e.g. "Drew 9
  Firas"), but the stock becomes 100 regardless.
