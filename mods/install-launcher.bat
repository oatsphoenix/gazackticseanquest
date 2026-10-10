@echo off
rem GaZacktic Seanquest - the one installer for Star Wars Battlefront II (2005) on Windows.
rem Double-click it. It fetches the current installer script from the project site, then:
rem   1. sets up the launcher, so the game board's "Launch game" button can start the game;
rem   2. offers the mod set (press N at the menu to skip the mods);
rem   3. reads the game's mission list and hands it to the board.
rem Options can be added after the name, for example:
rem   install-launcher.bat -Verify            check the installed mods
rem   install-launcher.bat -LauncherOnly      launcher and mission list only, no mods menu
rem   install-launcher.bat -Undo ai           take one mod back out
rem Downloads and setlist.json are kept in the folder this file is in.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; $d = Join-Path $env:LOCALAPPDATA 'Seanquest'; New-Item -ItemType Directory -Force -Path $d | Out-Null; $f = Join-Path $d 'install-mods.ps1'; Write-Host 'Fetching the installer...'; Invoke-WebRequest -UseBasicParsing -Uri 'https://oatsphoenix.github.io/gazackticseanquest/mods/install-mods.ps1' -OutFile $f; & $f -HomeDir '%~dp0.' %*"
echo.
pause
