@echo off
rem Installs only the GaZacktic Seanquest launcher, which lets the game board's "Launch game"
rem button start Battlefront II on the right mission. It fetches the current installer script
rem from the project site and runs it with -LauncherOnly. Nothing else on the PC is changed.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; $d = Join-Path $env:LOCALAPPDATA 'Seanquest'; New-Item -ItemType Directory -Force -Path $d | Out-Null; $f = Join-Path $d 'install-mods.ps1'; Write-Host 'Fetching the installer...'; Invoke-WebRequest -UseBasicParsing -Uri 'https://oatsphoenix.github.io/gazackticseanquest/mods/install-mods.ps1' -OutFile $f; & $f -LauncherOnly"
echo.
pause
