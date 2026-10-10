# Battlefront II (2005) mod installer

Installs the mod set the GaZacktic Seanquest campaign is played with, on Windows, for the Steam or GOG
version of the 2005 game. It does not work with the Classic Collection re-release.

## Run it

1. Download `install-mods.bat` and `install-mods.ps1` into the same folder.
2. Double-click `install-mods.bat`.
3. Pick the mods (the defaults are the recommended set) and press Enter.

Both players run it. The set list (below) is what guarantees the two installs come out the same.

## The set list: same mods on both PCs

1. **Player 1** runs the installer. At the end it writes `setlist.json` next to the script and shows a
   set code such as `D530-2A33`.
2. Player 1 sends `setlist.json` to player 2, who puts it next to their `install-mods.bat` **before**
   running it.
3. **Player 2** runs the installer. With a set list present it:
   - installs exactly the mods on the list (no menu),
   - refuses any download that is not byte-for-byte the file player 1 used,
   - compares the finished install with player 1's and prints `MATCH` or `MISMATCH`.

`MATCH` with the same set code on both PCs means every file in the game's mod folders (`addon` and
`data\_lvl_pc`) is identical. `MISMATCH` lists the files that are missing, extra or different.

`install-mods.bat -Verify` repeats the comparison at any time, for example before a session.

If a `setlist.json` is published in this folder of the project, the script fetches it by itself and
step 2 is not needed.

## What it installs

| Key | Mod | Gets you | How it arrives |
|---|---|---|---|
| `hd-graphics` | Battlefront 2 Remaster (Harrisonfog) | HD maps, models, lighting, sound | ModDB, 4.8 GB, its own installer |
| `remaster-ui` | Battlefront II Remastered 1.5 r2 ([GT]Anakin) | Menus and HUD for modern screens, AI heroes, the unofficial 1.3 patch (bug fixes, Fake Console) | ModDB, its own installer |
| `bf1-maps` | Marvel4's Conversion Pack 1.1 | 13 Battlefront 1 maps | ModDB |
| `xbox-dlc` | Xbox DLC and Title Update content | Bespin Cloud City, Rhen Var Citadel and Harbor, Yavin 4 Arena, Kit Fisto, Asajj Ventress | ModDB |
| `ai` | AI Difficulty mod 2.0 | Elite AI on stock maps (replaces `mission.lvl`) | ModDB |
| `shader-patch` | Shader Patch | Modern renderer | GitHub, automatic |
| `patch-1.3` | Unofficial 1.3 patch r130 | Bug fixes and Fake Console alone (off by default: `remaster-ui` already includes it) | GitHub, automatic |

ModDB blocks scripted downloads, so for those the script opens the page in your browser, waits for the
file to land in your Downloads folder, and asks you to confirm it before using it.

Two of the mods ship their own installer. The script starts it and puts the game's `GameData` path on
your clipboard; paste it when the installer asks for a folder.

## Checks it makes

- **Before installing:** file size, a checksum where one is published, and that the archive holds what
  that mod should contain. A file that fails is not installed.
- **After installing:** that the mod's files are in the game folder. An installer that changed nothing
  is reported as failed.
- **Any time later:** `install-mods.bat -Verify` re-checks everything it installed.

Every file it replaces is copied to `GameData\_seanquest_backup` first. Files replaced by a mod's own
installer are not backed up; Steam's "Verify integrity of game files" restores those.

## Launching battles from the game board

The installer also sets up a small launcher so the board's **Launch game** button (on the battle card)
can start the game on the right mission. It registers a `seanquest://` link type for your Windows user
and puts `seanquest-launch.ps1` in `GameData`. The launcher only accepts a mission code in the game's
own format, such as `cor1c_con`; any other link is refused and noted in `seanquest-launch.log`.

**This is untested against the real game.** Try it first:

```
install-mods.bat -TestLaunch cor1c_con
```

That should start Battlefront II on Coruscant: Jedi Temple, Clone Wars, conquest. If the game opens to
its normal menu instead, or not at all, the game is not taking the mission from the command line the way
the launcher passes it. The options it passes are in `GameData\seanquest-launch-args.txt` and can be
edited there.

Mission codes are map + era letter (`c` Clone Wars, `g` Galactic Civil War) + mode (`_con`, `_ctf`,
`_1flag`, `_hunt`, `_eli`, `_ass`). The board knows the stock maps' codes. Mod maps (the BF1 pack, the
Xbox DLC) have their own, which you type into the board in edit mode once you know them.

## Options

```
install-mods.bat -Verify                    check the installed mods, install nothing
install-mods.bat -Undo ai                   take one mod back out (also: -Undo xbox-dlc)
install-mods.bat -MakeSetList               rewrite setlist.json from this PC's install
install-mods.bat -NoSetList                 ignore the set list and choose mods freely
install-mods.bat -TestLaunch cor1c_con      start the game on a mission through the launcher
install-mods.bat -NoLauncher                install mods without the launcher
install-mods.bat -RemoveLauncher            remove the launcher again
install-mods.bat -Only bf1-maps,xbox-dlc    install just these
install-mods.bat -Yes                       take the default set without the menu
install-mods.bat -Force                     reinstall mods already installed
install-mods.bat -GamePath "D:\Games\Star Wars Battlefront II\GameData"
```

## Galactic Conquest bonuses in any match

With `remaster-ui` (or `patch-1.3`) installed: pause the match, open **Fake Console**, and pick
`Bonus 1 ...` or `Bonus 2 ...` for team 1 or 2.

## Known rough edges

- **Set list and settings files.** The comparison covers every file in the mod folders, so if a mod
  keeps a per-player settings file in there, two otherwise identical installs can report a mismatch on
  that one file. The mismatch list names it.

- **BF1 maps and the Xbox DLC.** Marvel4's pack is the base: it has every BF1 map on the board,
  including the four the DLC also ships. The DLC goes on second for Kit Fisto, Asajj Ventress and the
  official versions of those four maps. If both mods want the same addon folder, the BF1 pack's copy is
  kept and the clash is reported. The DLC's author warns it may clash with BF1 packs in other ways; if
  maps are doubled or the game crashes, run `install-mods.bat -Undo xbox-dlc`.
- **AI mod.** It replaces a core game file. If stock maps misbehave after installing it, run
  `install-mods.bat -Undo ai`, which puts the original file back.
- `-Undo` only works for mods the script copied in itself. The two mods with their own installers
  (`hd-graphics`, `remaster-ui`) are removed with Steam's "Verify integrity of game files".
- The install order (HD graphics, then the interface mod, then maps, then Shader Patch) follows
  community guides; it has not been tested end to end by this project.
