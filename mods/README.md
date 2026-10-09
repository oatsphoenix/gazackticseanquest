# Battlefront II (2005) mod installer

Installs the mod set the GaZacktic Seanquest campaign is played with, on Windows, for the Steam or GOG
version of the 2005 game. It does not work with the Classic Collection re-release.

## Run it

1. Download `install-mods.bat` and `install-mods.ps1` into the same folder.
2. Double-click `install-mods.bat`.
3. Pick the mods (the defaults are the recommended set) and press Enter.

Both players need to run it so their map mods match.

## What it installs

| Key | Mod | Gets you | How it arrives |
|---|---|---|---|
| `hd-graphics` | Battlefront 2 Remaster (Harrisonfog) | HD maps, models, lighting, sound | ModDB, 4.8 GB, its own installer |
| `remaster-ui` | Battlefront II Remastered 1.5 r2 ([GT]Anakin) | Menus and HUD for modern screens, AI heroes, the unofficial 1.3 patch (bug fixes, Fake Console) | ModDB, its own installer |
| `xbox-dlc` | Xbox DLC and Title Update content | Bespin Cloud City, Rhen Var Citadel and Harbor, Yavin 4 Arena, Kit Fisto, Asajj Ventress | ModDB |
| `bf1-maps` | Marvel4's Conversion Pack 1.1 | 13 Battlefront 1 maps | ModDB |
| `shader-patch` | Shader Patch | Modern renderer | GitHub, automatic |
| `patch-1.3` | Unofficial 1.3 patch r130 | Bug fixes and Fake Console alone (off by default: `remaster-ui` already includes it) | GitHub, automatic |
| `ai` | AI Difficulty mod 2.0 | Elite AI on stock maps (off by default: experimental) | ModDB |

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

## Options

```
install-mods.bat -Verify                    check the installed mods, install nothing
install-mods.bat -Only bf1-maps,xbox-dlc    install just these
install-mods.bat -Yes                       take the default set without the menu
install-mods.bat -Force                     reinstall mods already installed
install-mods.bat -GamePath "D:\Games\Star Wars Battlefront II\GameData"
```

## Galactic Conquest bonuses in any match

With `remaster-ui` (or `patch-1.3`) installed: pause the match, open **Fake Console**, and pick
`Bonus 1 ...` or `Bonus 2 ...` for team 1 or 2.

## Known rough edges

- The Xbox DLC's author warns it may clash with BF1 map packs, and Marvel4's pack already contains the
  four DLC maps. If maps are doubled or the game crashes, delete `DLC_XBOX` and `UPDATE_XBOX` from
  `GameData\addon`.
- The install order (HD graphics, then the interface mod, then maps, then Shader Patch) follows
  community guides; it has not been tested end to end by this project.
