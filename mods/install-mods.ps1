<#
.SYNOPSIS
  Installs the GaZacktic Seanquest mod set for Star Wars Battlefront II (2005, Steam or GOG).

.DESCRIPTION
  Finds the game, downloads what can be downloaded automatically (GitHub), walks you through the
  ModDB downloads (ModDB blocks scripted downloads, so your browser does those), then installs
  everything in the right order. Every file it replaces is copied to a backup folder first.

  Run it from install-mods.bat, or:  powershell -ExecutionPolicy Bypass -File install-mods.ps1

.PARAMETER GamePath
  The game's GameData folder (the one holding BattlefrontII.exe). Found automatically if omitted.
.PARAMETER Yes
  Accept the default selection without showing the menu.
.PARAMETER Only
  Install only these mod keys, e.g. -Only bf1-maps,shader-patch
.PARAMETER Force
  Reinstall mods this script already installed.
.PARAMETER NoShortcut
  Do not create the desktop shortcut.
.PARAMETER Verify
  Install nothing; only check that the mods this script installed are still in place.
.PARAMETER Undo
  Remove these mods again, e.g. -Undo ai  or  -Undo xbox-dlc. Works for mods this script copied
  in itself; a mod that used its own installer has to be removed with Steam's file verification.
.PARAMETER MakeSetList
  Write setlist.json from this PC's install, replacing any existing one. The set list is what makes
  two players' installs identical: give the file to the other player (next to their install-mods.bat).
.PARAMETER NoSetList
  Ignore any set list and choose mods freely.
.PARAMETER NoLauncher
  Do not install the launcher that lets the game board start the game on a chosen mission.
.PARAMETER TestLaunch
  Install the launcher if needed, then start the game on this mission code, e.g. -TestLaunch cor1c_con
.PARAMETER RemoveLauncher
  Remove the launcher (its seanquest:// link type and its script).
.PARAMETER ScanMissions
  Read the game's real mission list (which maps, eras and modes exist, mods included) and open the
  game board with it, so battles only offer missions this install actually has.
.PARAMETER LauncherOnly
  Install just the launcher and touch nothing else. This is what install-launcher.bat runs.
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [switch]$Yes,
    [string[]]$Only,
    [switch]$Force,
    [switch]$NoShortcut,
    [switch]$Verify,
    [string[]]$Undo,
    [switch]$MakeSetList,
    [switch]$NoSetList,
    [switch]$NoLauncher,
    [string]$TestLaunch,
    [switch]$RemoveLauncher,
    [switch]$LauncherOnly,
    [switch]$ScanMissions
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is many times faster without the bar
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# "-Only a,b" arrives as one string when the script is started with -File, so split it here.
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if ($Undo) { $Undo = @($Undo | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$Root        = Split-Path -Parent $MyInvocation.MyCommand.Path
$DownloadDir = Join-Path $Root 'downloads'
$WorkDir     = Join-Path $Root 'work'
$ArchiveExt  = @('.zip', '.7z', '.rar', '.exe')
$SetListPath = Join-Path $Root 'setlist.json'
# A set list published with the project is picked up automatically when there is none beside the script.
$SetListUrl  = 'https://oatsphoenix.github.io/gazackticseanquest/mods/setlist.json'

# -----------------------------------------------------------------------------------------------
# The mod set, in install order. Order matters:
#   - hd-graphics goes first so the interface mod's files end up on top of it.
#   - remaster-ui already contains the unofficial 1.3 patch; its author says never to install the
#     1.3 patch after it, so patch-1.3 is only used when remaster-ui is not selected.
#   - bf1-maps goes before xbox-dlc: the board needs six maps only the BF1 pack has, so if the two
#     ever want the same addon folder, the BF1 pack's copy is the one that is kept.
#   - shader-patch goes last.
# Kind: installer = an .exe you click through; addon = folders copied into GameData\addon;
#       overlay = files copied over GameData; lvl = stock .lvl files replaced.
# Checks that the right thing was downloaded and installed:
#   NameLike / MinMB / MaxMB  what the downloaded file should look like (a mismatch asks first)
#   Sha256                    exact checksum of the pinned download
#   Contains                  things that must be inside the archive
#   Markers                   things that must be in GameData afterwards
# -----------------------------------------------------------------------------------------------
$Mods = @(
    @{ Key = 'hd-graphics'; Name = 'Battlefront 2 Remaster (Harrisonfog)'; Default = $true; Source = 'moddb'; Kind = 'installer'
       What = 'HD maps, models, lighting and sound. 4.8 GB download.'
       NameLike = 'remaster'; MinMB = 3000; MaxMB = 9000; Contains = @('*.exe')
       Url  = 'https://www.moddb.com/mods/hd-graphics-mod/downloads/battlefront-2-remaster-installer-10' }
    @{ Key = 'remaster-ui'; Name = 'Battlefront II Remastered 1.5 r2 ([GT]Anakin)'; Default = $true; Source = 'moddb'; Kind = 'installer'
       What = 'Menus and HUD that fit modern screens, AI heroes, and the unofficial 1.3 patch (bug fixes, Fake Console).'
       NameLike = 'remaster'; MinMB = 5; MaxMB = 3000
       Url  = 'https://www.moddb.com/mods/star-wars-battlefront-ii-full-hd-interface/downloads/swbf2-remaster-1-5' }
    @{ Key = 'patch-1.3'; Name = 'Unofficial 1.3 patch r130'; Default = $false; Source = 'direct'; Kind = 'overlay'
       What = 'Bug fixes and the Fake Console on their own. Only for use WITHOUT remaster-ui, which already includes it.'
       Url  = 'https://github.com/Gametoast/un-official-patch/releases/download/1.3.130/SWBF2-v1.3patch-r130.zip'
       File = 'patch-1.3.zip'
       Sha256 = 'b7f799b1eeac1ac3ec6a0e098a7d161d5aa8fd7ac8fc85371dcc7feb613bfedf'
       Contains = @('GameData/data/_lvl_pc/shell.lvl', 'GameData/addon/AAA-v1.3patch/addme.script')
       Markers  = @('addon/AAA-v1.3patch/addme.script', 'data/_lvl_pc/v1.3patch_strings.lvl') }
    @{ Key = 'bf1-maps'; Name = "Marvel4's Conversion Pack 1.1"; Default = $true; Source = 'moddb'; Kind = 'addon'
       What = '13 Battlefront 1 maps, including every BF1 map on the Seanquest board.'
       NameLike = 'marvel|conversion'; MinMB = 20; MaxMB = 5000; Contains = @('addme.script')
       Url  = 'https://www.moddb.com/downloads/marvel4s-conversion-pack-11' }
    @{ Key = 'xbox-dlc'; Name = 'Xbox DLC and Title Update content for PC'; Default = $true; Source = 'moddb'; Kind = 'addon'
       What = 'Bespin Cloud City, Rhen Var Citadel and Harbor, Yavin 4 Arena, Kit Fisto, Asajj Ventress.'
       NameLike = 'xbox|dlc'; MinMB = 5; MaxMB = 300; Contains = @('DLC_XBOX', 'UPDATE_XBOX', 'addme.script')
       Url  = 'https://www.moddb.com/mods/xbox-dlc-content-for-pc/downloads/xbox-dlc-and-title-update-content-for-pc' }
    @{ Key = 'ai'; Name = 'AI Difficulty mod 2.0'; Default = $true; Source = 'moddb'; Kind = 'lvl'
       What = 'Elite AI on the stock maps (replaces mission.lvl). If stock maps misbehave afterwards: install-mods.bat -Undo ai'
       NameLike = 'ai'; MaxMB = 300; Contains = @('mission.lvl')
       Url  = 'https://www.moddb.com/games/star-wars-battlefront-ii/downloads/ai-difficulty-mod' }
    @{ Key = 'shader-patch'; Name = 'Shader Patch (PrismaticFlower)'; Default = $true; Source = 'github'; Kind = 'overlay-root'
       What = 'Modern renderer: fixed water, better lighting, HUD scaling.'
       Repo = 'PrismaticFlower/shaderpatch'; Asset = 'shaderpatch.zip'
       Url  = 'https://github.com/PrismaticFlower/shaderpatch/releases/download/v1.11.0/shaderpatch.zip'
       File = 'shader-patch.zip'
       Sha256 = '9ac39a216310f91d246cad52e860590a563eab862dc2f43edde13e76a9df3ea3'   # v1.11.0
       Contains = @('d3d9.dll', 'shader patch.yml', 'data/shaderpatch')
       Markers  = @('d3d9.dll', 'shader patch.yml', 'data/shaderpatch') }
)

# -----------------------------------------------------------------------------------------------
# Output helpers
# -----------------------------------------------------------------------------------------------
function Write-Step([string]$Text) { Write-Host ''; Write-Host "== $Text" -ForegroundColor Cyan }
function Write-Info([string]$Text) { Write-Host "   $Text" }
function Write-Ok([string]$Text)   { Write-Host "   OK: $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "   WARNING: $Text" -ForegroundColor Yellow }
function Stop-Script([string]$Text) { Write-Host ''; Write-Host "STOPPED: $Text" -ForegroundColor Red; exit 1 }

function Read-YesNo([string]$Question, [bool]$Default = $true) {
    $suffix = '[y/N]'; if ($Default) { $suffix = '[Y/n]' }
    while ($true) {
        $answer = (Read-Host "   $Question $suffix").Trim().ToLower()
        if ($answer -eq '') { return $Default }
        if ($answer -in @('y', 'yes')) { return $true }
        if ($answer -in @('n', 'no')) { return $false }
    }
}

# -----------------------------------------------------------------------------------------------
# Finding the game
# -----------------------------------------------------------------------------------------------
# Paths here are built with [IO.Path]::Combine, not Join-Path: Join-Path stops the script when the
# drive letter does not exist, and candidate folders are often on drives this PC does not have.
function Test-GameData([string]$Path) {
    if (-not $Path) { return $false }
    try { return [bool](Test-Path -LiteralPath ([IO.Path]::Combine($Path, 'BattlefrontII.exe')) -ErrorAction Stop) } catch { return $false }
}

# Steam keeps a list of every library folder in libraryfolders.vdf; each one may hold the game.
function Get-SteamLibraryPaths([string]$VdfText) {
    $paths = @()
    foreach ($m in [regex]::Matches($VdfText, '"path"\s+"([^"]+)"')) {
        $paths += ($m.Groups[1].Value -replace '\\\\', '\')
    }
    return $paths
}

# Every folder Steam is installed in, according to the registry.
function Get-SteamRoots {
    $roots = @()
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($name in @('SteamPath', 'InstallPath')) {
                if ($props.$name) { $roots += ("$($props.$name)" -replace '/', '\').TrimEnd('\') }
            }
        } catch { }
    }
    return (Select-UniquePaths $roots)
}

# Windows paths ignore case, so "C:\Steam" and "c:\steam" are the same folder.
function Select-UniquePaths($Paths) {
    $seen = @{}; $out = @()
    foreach ($p in @($Paths)) {
        if (-not $p) { continue }
        $k = "$p".TrimEnd('\').ToLowerInvariant()
        if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $out += "$p".TrimEnd('\') }
    }
    return $out
}

# Every Steam library on this PC: Steam's own folder plus the ones listed in its library files.
function Get-SteamLibraries {
    $libs = @()
    foreach ($root in @(Get-SteamRoots)) {
        $libs += $root
        foreach ($vdf in @('steamapps\libraryfolders.vdf', 'config\libraryfolders.vdf')) {
            try {
                $file = [IO.Path]::Combine($root, $vdf)
                if (Test-Path -LiteralPath $file) { $libs += Get-SteamLibraryPaths (Get-Content -LiteralPath $file -Raw) }
            } catch { }
        }
    }
    return (Select-UniquePaths $libs)
}

# Looks for the game, most reliable source first. What it checked is kept in $script:SearchNotes so a
# failed search can say why.
function Find-GameData {
    $script:SearchNotes = @()
    $script:SteamHasGame = $false
    $candidates = @()

    # 1. Windows' own record of where Steam installed the game (Steam app 6060).
    foreach ($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 6060', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 6060')) {
        try {
            $loc = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallLocation
            if ($loc) { $candidates += [IO.Path]::Combine($loc, 'GameData'); $script:SearchNotes += "Windows lists the game at: $loc" }
        } catch { }
    }

    # 2. Each Steam library. The library's manifest for app 6060 names the game's folder.
    $libs = @(Get-SteamLibraries)
    if ($libs.Count) { $script:SearchNotes += "Steam libraries: $($libs -join '; ')" } else { $script:SearchNotes += 'No Steam installation found in the registry.' }
    foreach ($lib in $libs) {
        $folders = @('Star Wars Battlefront II')
        try {
            $manifest = [IO.Path]::Combine($lib, 'steamapps\appmanifest_6060.acf')
            if (Test-Path -LiteralPath $manifest) {
                $script:SteamHasGame = $true
                $script:SearchNotes += "Steam lists the game in library: $lib"
                $m = [regex]::Match((Get-Content -LiteralPath $manifest -Raw), '"installdir"\s+"([^"]+)"')
                if ($m.Success) { $folders = @($m.Groups[1].Value) + $folders }
            }
        } catch { }
        foreach ($folder in $folders) { $candidates += [IO.Path]::Combine($lib, 'steamapps\common', $folder, 'GameData') }
    }

    # 3. GOG's record.
    try {
        foreach ($game in Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games' -ErrorAction Stop) {
            $props = Get-ItemProperty -Path $game.PSPath
            if ("$($props.gameName)" -match 'Battlefront.*II' -and $props.path) { $candidates += [IO.Path]::Combine($props.path, 'GameData') }
        }
    } catch { }

    # 4. The usual places on each drive.
    $drives = @()
    try { $drives = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | ForEach-Object { $_.Name.TrimEnd('\') }) } catch { }
    if (-not $drives.Count) { $drives = @('C:') }
    foreach ($drive in $drives) {
        foreach ($tail in @('Program Files (x86)\Steam', 'Program Files\Steam', 'SteamLibrary', 'Steam', 'Games\Steam', 'Games\SteamLibrary')) {
            $candidates += "$drive\$tail\steamapps\common\Star Wars Battlefront II\GameData"
        }
        $candidates += "$drive\GOG Games\Star Wars Battlefront II\GameData"
        $candidates += "$drive\Program Files (x86)\GOG Galaxy\Games\Star Wars Battlefront II\GameData"
    }
    foreach ($c in @(Select-UniquePaths $candidates)) { if (Test-GameData $c) { return $c } }

    # 5. Last resort: look through the drives for any Steam library holding the game.
    Write-Info 'Not in the usual places. Searching the drives for it (this can take a minute)...'
    foreach ($drive in $drives) {
        $tops = @()
        try { $tops = @(Get-ChildItem -LiteralPath "$drive\" -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('Windows', '$Recycle.Bin', 'System Volume Information', 'ProgramData', 'Recovery', '$WinREAgent') }) } catch { }
        foreach ($top in $tops) {
            $found = $null
            try {
                $steamapps = @($top) + @(Get-ChildItem -LiteralPath $top.FullName -Directory -Recurse -Depth 2 -Force -ErrorAction SilentlyContinue) | Where-Object { $_.Name -eq 'steamapps' }
                foreach ($sa in @($steamapps)) {
                    $common = [IO.Path]::Combine($sa.FullName, 'common')
                    if (-not (Test-Path -LiteralPath $common)) { continue }
                    foreach ($game in @(Get-ChildItem -LiteralPath $common -Directory -ErrorAction SilentlyContinue)) {
                        $gd = [IO.Path]::Combine($game.FullName, 'GameData')
                        if ((Test-GameData $gd) -and $gd -notmatch 'Classic Collection') { $found = $gd; break }
                    }
                    if ($found) { break }
                }
            } catch { }
            if ($found) { return $found }
        }
    }
    $script:SearchNotes += "Drives searched: $($drives -join ', ')"
    return $null
}

# Asked only when the search above finds nothing.
function Select-GameDataFolder {
    Write-Warn 'Could not find Battlefront II (2005) on this PC.'
    foreach ($note in @($script:SearchNotes)) { Write-Info $note }
    if (-not $script:SteamHasGame -and @(Get-SteamRoots).Count) {
        Write-Info 'Steam does not list the game as installed on this PC.'
        if (Read-YesNo 'Open Steam to install it now? (Run this again once it has finished.)') {
            try { Start-Process 'steam://install/6060' } catch { }
            exit 0
        }
    }
    Write-Info 'If it is installed somewhere unusual, pick its GameData folder (the one containing BattlefrontII.exe).'
    try {
        Add-Type -AssemblyName System.Windows.Forms
        # an invisible always-on-top owner keeps the picker from opening behind this window
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the Battlefront II GameData folder (contains BattlefrontII.exe)'
        $dialog.ShowNewFolderButton = $false
        $result = $dialog.ShowDialog($owner)
        $owner.Dispose()
        if ($result -eq 'OK') { return $dialog.SelectedPath }
    } catch { }
    return (Read-Host '   Or paste the full path to the GameData folder').Trim('"', ' ')
}

function Test-WriteAccess([string]$Dir) {
    $probe = Join-Path $Dir ('.seanquest-write-test-' + [guid]::NewGuid().ToString('N'))
    try { Set-Content -LiteralPath $probe -Value 'x'; Remove-Item -LiteralPath $probe -Force; return $true } catch { return $false }
}

# -----------------------------------------------------------------------------------------------
# Archives
# -----------------------------------------------------------------------------------------------
function Find-SevenZip {
    foreach ($p in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    $cmd = Get-Command 7z -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Install-SevenZip {
    Write-Info '7-Zip is needed to open this archive. Trying to install it with winget...'
    try {
        & winget install --id 7zip.7zip -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
    } catch { }
    $found = Find-SevenZip
    if (-not $found) { Stop-Script 'Install 7-Zip from https://www.7-zip.org/ and run this script again.' }
    return $found
}

function Expand-ModArchive([string]$File, [string]$Dest) {
    if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    $sevenZip = Find-SevenZip
    if ([IO.Path]::GetExtension($File).ToLower() -eq '.zip' -and -not $sevenZip) {
        Expand-Archive -LiteralPath $File -DestinationPath $Dest -Force
        return
    }
    if (-not $sevenZip) { $sevenZip = Install-SevenZip }
    & $sevenZip x "-o$Dest" -y $File | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Script "7-Zip could not extract $File (exit code $LASTEXITCODE). The download may be incomplete: delete it and run again." }
}

# -----------------------------------------------------------------------------------------------
# Copying into the game, with a backup of anything replaced
# -----------------------------------------------------------------------------------------------
# Notes a file this run wrote into the game, as a path relative to GameData. A reinstall that
# writes identical files would otherwise look, from size and date alone, like nothing happened.
function Add-Touched([string]$FullPath) {
    $root = $script:GameDataRoot.TrimEnd('\', '/')
    $script:Touched += ($FullPath.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/')
}

# Copies every file under $Source to the same relative place under $Target. A file that already
# exists in the game is copied to $BackupDir first (once: the first backup is the original).
function Copy-Overlay([string]$Source, [string]$Target, [string]$BackupDir) {
    $sourceFull = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\', '/')
    $copied = 0; $backedUp = 0
    foreach ($file in Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force) {
        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\', '/')
        $dest = Join-Path $Target $relative
        if (Test-Path -LiteralPath $dest) {
            $backup = Join-Path $BackupDir $relative
            if (-not (Test-Path -LiteralPath $backup)) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
                Copy-Item -LiteralPath $dest -Destination $backup -Force
                $backedUp++
            }
        } else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        }
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
        Add-Touched $dest
        $copied++
    }
    return @{ Copied = $copied; BackedUp = $backedUp }
}

# Works out what an extracted download is, because the mods are packaged in different ways.
function Get-PackageLayout([string]$Dir) {
    $gameData = Get-ChildItem -LiteralPath $Dir -Recurse -Directory -Force | Where-Object { $_.Name -eq 'GameData' } | Select-Object -First 1
    if ($gameData) { return @{ Type = 'gamedata'; Path = $gameData.FullName } }
    $addons = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -Filter 'addme.script' | ForEach-Object { $_.Directory.FullName } | Select-Object -Unique)
    if ($addons.Count) { return @{ Type = 'addon'; Paths = $addons } }
    $exe = Get-ChildItem -LiteralPath $Dir -Recurse -File -Force -Filter '*.exe' | Sort-Object Length -Descending | Select-Object -First 1
    if ($exe) { return @{ Type = 'installer'; Path = $exe.FullName } }
    return @{ Type = 'unknown'; Path = $Dir }
}

# -----------------------------------------------------------------------------------------------
# Checking that a download is the right mod, and that it really installed
# -----------------------------------------------------------------------------------------------
# Before installing: size and checksum. Returns $false when the file should not be used.
function Test-ModDownload($Mod, [string]$File) {
    $item = Get-Item -LiteralPath $File
    $sizeMb = [math]::Round($item.Length / 1MB, 1)
    $listed = $null
    if ($script:SetList -and $script:SetList.mods) { $listed = $script:SetList.mods.($Mod.Key) }
    if ($listed -and $listed.sha256) {
        $hash = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLower()
        if ($hash -eq $listed.sha256) { Write-Ok "Identical to the file the set list was made with ($sizeMb MB)."; return $true }
        Write-Warn "This is not the same file the set list was made with (a different version or a damaged download)."
        Write-Warn "Expected $($listed.bytes) bytes with checksum $($listed.sha256.Substring(0, 12))..., got $($item.Length) bytes with $($hash.Substring(0, 12))..."
        Remove-Item -LiteralPath $File -Force
        Remove-Item -LiteralPath "$File.sha256" -Force -ErrorAction SilentlyContinue
        return $false
    }
    # The checksum to expect: the one saved beside the file when it was downloaded (GitHub publishes
    # one per release file), or else the pinned one for a download that only ever has one version.
    $expected = $null
    $sidecar = "$File.sha256"
    if (Test-Path -LiteralPath $sidecar) { $expected = (Get-Content -LiteralPath $sidecar -Raw).Trim().ToLower() }
    elseif ($Mod.Sha256 -and $Mod.Source -eq 'direct') { $expected = $Mod.Sha256 }
    if ($expected) {
        $hash = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLower()
        if ($hash -eq $expected) { Write-Ok "Checksum matches the published file ($sizeMb MB)."; return $true }
        Write-Warn 'Checksum does not match: the download is damaged or is not the expected file. Deleting it; run again to fetch a fresh copy.'
        Remove-Item -LiteralPath $File -Force
        Remove-Item -LiteralPath $sidecar -Force -ErrorAction SilentlyContinue
        return $false
    }
    $doubts = @()
    if ($Mod.MinMB -and $sizeMb -lt $Mod.MinMB) { $doubts += "it is only $sizeMb MB (expected at least $($Mod.MinMB) MB)" }
    if ($Mod.MaxMB -and $sizeMb -gt $Mod.MaxMB) { $doubts += "it is $sizeMb MB (expected at most $($Mod.MaxMB) MB)" }
    if ($doubts.Count) {
        Write-Warn "This does not look like $($Mod.Name): $($doubts -join '; ')."
        return (Read-YesNo 'Use it anyway?' $false)
    }
    Write-Ok "File size is plausible ($sizeMb MB)."
    return $true
}

# After extracting: the archive must hold what this mod is known to contain.
# A pattern with * is matched against file names; anything else against the end of the path.
function Get-MissingContents($Mod, [string]$Dir) {
    $root = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd('\', '/')
    $paths = @(Get-ChildItem -LiteralPath $root -Recurse -Force | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/' })
    $missing = @()
    foreach ($pattern in @($Mod.Contains)) {
        if (-not $pattern) { continue }
        if ($pattern -like '*[*]*') { $hit = $paths | Where-Object { ($_ -split '/')[-1] -like $pattern } | Select-Object -First 1 }
        else { $hit = $paths | Where-Object { $_ -eq $pattern -or $_ -like "*/$pattern" } | Select-Object -First 1 }
        if (-not $hit) { $missing += $pattern }
    }
    return $missing
}

function Test-ModContents($Mod, [string]$Dir) {
    $missing = @(Get-MissingContents $Mod $Dir)
    if (-not $missing.Count) {
        if (@($Mod.Contains).Count) { Write-Ok 'Archive contents are what this mod should contain.' }
        return $true
    }
    Write-Warn "This archive is missing things $($Mod.Name) should contain: $($missing -join ', ')"
    if ($Mod.Source -ne 'moddb') { return $false }
    return (Read-YesNo 'It may be the wrong download. Install it anyway?' $false)
}

# A list of every file in the game folder with its size and time, to see what an installer changed.
function Get-GameSnapshot([string]$GameData) {
    $root = $GameData.TrimEnd('\', '/')
    $snap = @{}
    foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/'
        if ($rel -like '_seanquest_backup/*' -or $rel -eq 'seanquest-mods.json') { continue }
        $snap[$rel] = "$($f.Length)|$($f.LastWriteTimeUtc.Ticks)"
    }
    return $snap
}

function Compare-GameSnapshot($Before, $After) {
    $changed = @()
    foreach ($k in $After.Keys) { if (-not $Before.ContainsKey($k) -or $Before[$k] -ne $After[$k]) { $changed += $k } }
    return ($changed | Sort-Object)
}

# What gets remembered about an installed mod, so it can be re-checked later.
# $Files is the full list of files this script copied itself (empty when the mod's own installer
# did the work); it is what -Undo walks back.
function New-InstallRecord($Changed, [string]$GameData, $Files) {
    $changed = @($Changed)
    $addons = @($changed | Where-Object { $_ -like 'addon/*/addme.script' } | ForEach-Object { ($_ -split '/')[1] } | Select-Object -Unique)
    $step = [int][math]::Max(1, [math]::Floor($changed.Count / 25))
    $sample = @(); for ($i = 0; $i -lt $changed.Count; $i += $step) { $sample += $changed[$i] }
    $hashes = @{}
    foreach ($rel in ($changed | Where-Object { $_ -like 'data/_lvl_pc/*.lvl' -and $_ -notlike 'data/_lvl_pc/*/*' })) {
        $hashes[$rel] = (Get-FileHash -LiteralPath (Join-Path $GameData $rel) -Algorithm SHA256).Hash.ToLower()
    }
    return @{ Date = (Get-Date).ToString('s'); Changed = $changed.Count; Addon = $addons; Sample = $sample; Hashes = $hashes; Files = @($Files) }
}

# Which installed mod put this addon folder there, if any.
function Get-AddonOwner([string]$Name) {
    foreach ($key in @($script:Installed.Keys)) {
        if (@($script:Installed[$key].Addon) -contains $Name) { return $key }
    }
    return $null
}

# Takes a mod back out: restores every original it replaced and deletes the files it added.
function Undo-Mod($Mod, $Record, [string]$GameData, [string]$BackupDir) {
    $files = @(@($Record.Files) | Where-Object { $_ })
    if (-not $files.Count) {
        Write-Warn "$($Mod.Name) was put in by its own installer, so this script cannot take it out."
        Write-Warn 'Use Steam > game Properties > Installed Files > Verify integrity of game files.'
        return $false
    }
    $restored = 0; $removed = 0
    foreach ($rel in $files) {
        $file = Join-Path $GameData $rel
        $backup = Join-Path $BackupDir $rel
        if (Test-Path -LiteralPath $backup) {
            Copy-Item -LiteralPath $backup -Destination $file -Force
            Remove-Item -LiteralPath $backup -Force
            $restored++
        } elseif (Test-Path -LiteralPath $file) {
            Remove-Item -LiteralPath $file -Force
            $removed++
        }
    }
    foreach ($name in @($Record.Addon)) {
        $dir = Join-Path $GameData "addon/$name"
        if ($name -and (Test-Path -LiteralPath $dir) -and -not (Get-ChildItem -LiteralPath $dir -Recurse -File -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
    }
    Write-Ok "$($Mod.Name) removed: $removed files deleted, $restored originals restored."
    return $true
}

# Re-checks one installed mod against the game folder. Returns a list of problems (empty = fine).
function Test-InstalledMod($Mod, $Record, [string]$GameData) {
    $problems = @()
    foreach ($marker in @($Mod.Markers)) {
        if ($marker -and -not (Test-Path -LiteralPath (Join-Path $GameData $marker))) { $problems += "missing $marker" }
    }
    foreach ($name in @($Record.Addon)) {
        if ($name -and -not (Test-Path -LiteralPath (Join-Path $GameData "addon/$name/addme.script"))) { $problems += "addon/$name is missing or has no addme.script" }
    }
    $gone = @(@($Record.Sample) | Where-Object { $_ -and -not (Test-Path -LiteralPath (Join-Path $GameData $_)) })
    if ($gone.Count) { $problems += "$($gone.Count) of its files are gone, e.g. $($gone[0])" }
    if ($Mod.Kind -eq 'lvl' -and $Record.Hashes) {
        foreach ($p in $Record.Hashes.PSObject.Properties) {
            $file = Join-Path $GameData $p.Name
            if ((Test-Path -LiteralPath $file) -and (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $p.Value) { $problems += "$($p.Name) was replaced by something else since" }
        }
    }
    if ([int]$Record.Changed -eq 0) { $problems += 'it changed no files when it was installed' }
    return $problems
}

function Invoke-Verification($Installed, [string]$GameData) {
    $bad = 0
    foreach ($mod in $Mods) {
        if (-not $Installed.ContainsKey($mod.Key)) { continue }
        $problems = @(Test-InstalledMod $mod $Installed[$mod.Key] $GameData)
        if ($problems.Count) {
            $bad++
            Write-Host ("   FAIL  {0}" -f $mod.Name) -ForegroundColor Red
            foreach ($p in $problems) { Write-Host "           $p" -ForegroundColor Red }
        } else {
            $extra = ''; $n = @($Installed[$mod.Key].Addon).Count
            if ($n) { $extra = "  ($n addon folders)" }
            Write-Host ("   PASS  {0}{1}" -f $mod.Name, $extra) -ForegroundColor Green
        }
    }
    if (-not $Installed.Count) { Write-Info 'This script has not installed anything in this game folder yet.' }
    return $bad
}

# -----------------------------------------------------------------------------------------------
# The set list: one player's exact install, written down so the other player's can be made identical
# -----------------------------------------------------------------------------------------------
# It records which mods, the checksum of each downloaded file, and a checksum of every file in the two
# folders mods live in (addon and data\_lvl_pc). With a set list present the script installs exactly
# those mods, refuses any download that is not byte-for-byte the same file, and compares the result.

# Checksums every file under addon and data/_lvl_pc. Paths are lower-cased and sorted the same way on
# every PC, so two identical installs always produce the same code.
function Get-GameFingerprint([string]$GameData) {
    $root = $GameData.TrimEnd('\', '/')
    $files = @{}
    foreach ($sub in @('addon', 'data/_lvl_pc')) {
        $dir = Join-Path $root $sub
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -Force) {
            $rel = ($f.FullName.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/').ToLowerInvariant()
            $files[$rel] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
        }
    }
    $keys = [string[]]@($files.Keys)
    [Array]::Sort($keys, [StringComparer]::Ordinal)
    $lines = foreach ($k in $keys) { "$k|$($files[$k])" }
    $temp = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($temp, ($lines -join "`n"), (New-Object Text.UTF8Encoding($false)))
    $hash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLower()
    Remove-Item -LiteralPath $temp -Force
    return @{ Hash = $hash; Code = ($hash.Substring(0, 4) + '-' + $hash.Substring(4, 4)).ToUpper(); Files = $files }
}

function Read-SetList {
    if ($NoSetList -or $MakeSetList) { return $null }
    if (-not (Test-Path -LiteralPath $SetListPath)) {
        # Download to a temporary name so a failed request (there may be no published list) leaves nothing behind.
        $temp = "$SetListPath.download"
        try {
            Invoke-WebRequest -Uri $SetListUrl -OutFile $temp -UseBasicParsing
            [void](Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json)
            Move-Item -LiteralPath $temp -Destination $SetListPath -Force
            Write-Info 'Fetched the published set list.'
        } catch { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
    if (-not (Test-Path -LiteralPath $SetListPath)) { return $null }
    try { return (Get-Content -LiteralPath $SetListPath -Raw | ConvertFrom-Json) } catch { Write-Warn "setlist.json could not be read: $($_.Exception.Message)"; return $null }
}

function Write-SetList($Installed, [string]$GameData) {
    Write-Info 'Checksumming the mod folders (a few minutes with the HD graphics mod installed)...'
    $print = Get-GameFingerprint $GameData
    $entries = [ordered]@{}   # not $mods: PowerShell names ignore case, and $Mods is the mod table
    foreach ($mod in $Mods) {
        if (-not $Installed.ContainsKey($mod.Key)) { continue }
        $entry = @{ name = $mod.Name }
        $file = Get-CachedDownload $mod.Key
        if ($file) { $entry.sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower(); $entry.bytes = (Get-Item -LiteralPath $file).Length }
        else { Write-Warn "The download for $($mod.Name) is no longer in the downloads folder, so the other player's copy of it cannot be checked." }
        $entries[$mod.Key] = $entry
    }
    [ordered]@{ made = (Get-Date).ToString('s'); code = $print.Code; fingerprint = $print.Hash; mods = $entries; files = $print.Files } |
        ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SetListPath
    Write-Ok "Set list written: $SetListPath"
    Write-Host "   SET CODE: $($print.Code)" -ForegroundColor Cyan
    Write-Info 'Give setlist.json to the other player: it goes next to their install-mods.bat before they run it.'
}

# Compares this PC with the set list. Returns $true on an exact match.
function Compare-SetList($SetList, [string]$GameData) {
    Write-Info 'Checksumming the mod folders (a few minutes with the HD graphics mod installed)...'
    $print = Get-GameFingerprint $GameData
    if ($print.Hash -eq $SetList.fingerprint) {
        Write-Host "   MATCH: this install is identical to the set list.  SET CODE: $($print.Code)" -ForegroundColor Green
        return $true
    }
    $want = @{}
    foreach ($p in $SetList.files.PSObject.Properties) { $want[$p.Name] = $p.Value }
    $missing = @($want.Keys | Where-Object { -not $print.Files.ContainsKey($_) } | Sort-Object)
    $extra   = @($print.Files.Keys | Where-Object { -not $want.ContainsKey($_) } | Sort-Object)
    $differ  = @($want.Keys | Where-Object { $print.Files.ContainsKey($_) -and $print.Files[$_] -ne $want[$_] } | Sort-Object)
    Write-Host "   MISMATCH: this install is NOT the same as the set list.  Yours: $($print.Code)  Set list: $($SetList.code)" -ForegroundColor Red
    foreach ($group in @(@('Missing here', $missing), @('Only here', $extra), @('Different contents', $differ))) {
        $list = @($group[1])
        if (-not $list.Count) { continue }
        Write-Host "   $($group[0]): $($list.Count) file(s)" -ForegroundColor Yellow
        foreach ($f in ($list | Select-Object -First 12)) { Write-Host "     $f" }
        if ($list.Count -gt 12) { Write-Host "     ... and $($list.Count - 12) more" }
    }
    return $false
}

# -----------------------------------------------------------------------------------------------
# Downloads
# -----------------------------------------------------------------------------------------------
function Get-CachedDownload([string]$Key) {
    if (-not (Test-Path -LiteralPath $DownloadDir)) { return $null }
    $hit = Get-ChildItem -LiteralPath $DownloadDir -File | Where-Object { $_.BaseName -eq $Key -and $_.Extension.ToLower() -in $ArchiveExt } | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

function Get-DirectDownload($Mod) {
    $target = Join-Path $DownloadDir $Mod.File
    if (Test-Path -LiteralPath $target) { Write-Info "Already downloaded: $($Mod.File)"; return $target }
    $url = $Mod.Url
    $expected = $Mod.Sha256   # right for the pinned URL; replaced below if a newer release is used
    if ($Mod.Source -eq 'github' -and -not $script:SetList) {
        # Prefer the newest release; fall back to the pinned one if GitHub's API cannot be reached.
        try {
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$($Mod.Repo)/releases/latest" -Headers @{ 'User-Agent' = 'seanquest-mod-installer' }
            $asset = $release.assets | Where-Object { $_.name -eq $Mod.Asset } | Select-Object -First 1
            if ($asset) {
                $url = $asset.browser_download_url
                $expected = $null
                if ("$($asset.digest)" -like 'sha256:*') { $expected = "$($asset.digest)".Substring(7) }
                Write-Info "Latest release: $($release.tag_name)"
            }
        } catch { Write-Info 'Could not ask GitHub for the latest release; using the pinned version.' }
    }
    Write-Info "Downloading $url"
    $partial = "$target.part"
    Invoke-WebRequest -Uri $url -OutFile $partial -UseBasicParsing
    Move-Item -LiteralPath $partial -Destination $target -Force
    if ($expected) { Set-Content -LiteralPath "$target.sha256" -Value $expected.ToLower() }
    return $target
}

function Get-BrowserDownloadsFolder {
    try { return (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch { }
    return (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads')
}

# A browser download is finished when its size has stopped changing and no partial-file twin exists.
function Test-DownloadFinished([IO.FileInfo]$File) {
    foreach ($suffix in @('.crdownload', '.part', '.partial', '.tmp')) {
        if (Test-Path -LiteralPath ($File.FullName + $suffix)) { return $false }
    }
    $before = $File.Length
    Start-Sleep -Seconds 2
    $File.Refresh()
    return ($File.Exists -and $File.Length -eq $before -and $File.Length -gt 0)
}

# ModDB sits behind a browser check, so a script cannot fetch from it. This opens the page, waits
# for a new archive to land in the browser's Downloads folder, and takes a copy.
function Get-ManualDownload($Mod, [string]$WatchDir, [int]$TimeoutMinutes = 240) {
    $cached = Get-CachedDownload $Mod.Key
    if ($cached) { Write-Info "Already downloaded: $(Split-Path -Leaf $cached)"; return $cached }

    $started = (Get-Date).AddSeconds(-5)
    Write-Info "Opening the download page in your browser:"
    Write-Info "  $($Mod.Url)"
    Write-Info "Click the red DOWNLOAD button and save the file to: $WatchDir"
    Write-Info '(Waiting for it to arrive. Press S to skip this mod, or P to give a file path yourself.)'
    try { Start-Process $Mod.Url } catch { Write-Warn 'Could not open the browser. Open the link above yourself.' }

    $rejected = @{}
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        $picked = $null
        try {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true).Key
                if ($key -eq 'S') { return $null }
                if ($key -eq 'P') {
                    $typed = (Read-Host '   Full path to the downloaded file').Trim('"', ' ')
                    if (Test-Path -LiteralPath $typed) { $picked = Get-Item -LiteralPath $typed } else { Write-Warn 'No file at that path.' }
                }
            }
        } catch { }
        if (-not $picked) {
            $new = Get-ChildItem -LiteralPath $WatchDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension.ToLower() -in $ArchiveExt -and $_.LastWriteTime -ge $started -and -not $rejected.ContainsKey($_.FullName) } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($new -and (Test-DownloadFinished $new)) {
                $sizeMb = [math]::Round($new.Length / 1MB, 1)
                $looksRight = (-not $Mod.NameLike) -or ($new.Name -match $Mod.NameLike)
                if (-not $looksRight) { Write-Warn "'$($new.Name)' does not look like the file name for this mod." }
                if (Read-YesNo "Found '$($new.Name)' ($sizeMb MB). Is this the file for $($Mod.Name)?" $looksRight) { $picked = $new } else { $rejected[$new.FullName] = $true }
            }
        }
        if ($picked) {
            $target = Join-Path $DownloadDir ($Mod.Key + $picked.Extension.ToLower())
            Copy-Item -LiteralPath $picked.FullName -Destination $target -Force
            return $target
        }
        Start-Sleep -Seconds 2
    }
    Write-Warn "Gave up waiting for $($Mod.Name)."
    return $null
}

# -----------------------------------------------------------------------------------------------
# Installing one mod
# -----------------------------------------------------------------------------------------------
function Start-ModInstaller([string]$Exe, [string]$GameData) {
    try { Set-Clipboard -Value $GameData } catch { }
    Write-Info "Starting the mod's own installer: $(Split-Path -Leaf $Exe)"
    Write-Host "   When it asks for a folder, give it exactly this one (it is on your clipboard, so Ctrl+V works):" -ForegroundColor Yellow
    Write-Host "     $GameData" -ForegroundColor Yellow
    for ($try = 1; $try -le 3; $try++) {
        try { Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -Parent $Exe) -Wait } catch { Write-Warn "Could not start it: $($_.Exception.Message)"; return $false }
        if (-not (Read-YesNo 'Did that installer finish without errors?')) { return $false }
        # Some installers hand off to a second window and return early, so look only after the answer.
        $changed = @(Compare-GameSnapshot $script:Snapshot (Get-GameSnapshot $GameData))
        if ($changed.Count) { Write-Ok "The installer changed $($changed.Count) files in GameData."; return $true }
        Write-Warn 'The installer changed nothing in GameData. It was probably pointed at a different folder.'
        if (-not (Read-YesNo 'Run it again?')) { return $false }
    }
    return $false
}

function Install-Mod($Mod, [string]$File, [string]$GameData, [string]$BackupDir) {
    if ([IO.Path]::GetExtension($File).ToLower() -eq '.exe') { return (Start-ModInstaller $File $GameData) }

    $extracted = Join-Path $WorkDir $Mod.Key
    Write-Info 'Extracting...'
    Expand-ModArchive $File $extracted
    if (-not (Test-ModContents $Mod $extracted)) { return $false }

    if ($Mod.Kind -eq 'overlay-root') {
        $r = Copy-Overlay $extracted $GameData $BackupDir
        Write-Info "Copied $($r.Copied) files into GameData ($($r.BackedUp) originals backed up)."
        return $true
    }
    if ($Mod.Kind -eq 'lvl') {
        # Replace only .lvl files the game already has, e.g. mission.lvl.
        $lvlDir = Join-Path $GameData 'data/_lvl_pc'
        $done = 0
        foreach ($lvl in Get-ChildItem -LiteralPath $extracted -Recurse -File -Filter '*.lvl') {
            $dest = Join-Path $lvlDir $lvl.Name
            if (-not (Test-Path -LiteralPath $dest)) { continue }
            $backup = Join-Path $BackupDir (Join-Path 'data/_lvl_pc' $lvl.Name)
            if (-not (Test-Path -LiteralPath $backup)) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
                Copy-Item -LiteralPath $dest -Destination $backup -Force
            }
            Copy-Item -LiteralPath $lvl.FullName -Destination $dest -Force
            Add-Touched $dest
            Write-Info "Replaced $($lvl.Name) (original backed up)."
            $done++
        }
        if (-not $done) { Write-Warn 'No matching .lvl file found in that download; nothing was changed.' }
        return [bool]$done
    }

    $layout = Get-PackageLayout $extracted
    switch ($layout.Type) {
        'gamedata' {
            $r = Copy-Overlay $layout.Path $GameData $BackupDir
            Write-Info "Copied $($r.Copied) files into GameData ($($r.BackedUp) originals backed up)."
            return $true
        }
        'addon' {
            $addonDir = Join-Path $GameData 'addon'
            New-Item -ItemType Directory -Path $addonDir -Force | Out-Null
            $placed = 0
            foreach ($folder in $layout.Paths) {
                $name = Split-Path -Leaf $folder
                # Two mods using the same addon folder name would overwrite each other's maps, so a
                # folder that is already there from something else is left alone and reported.
                if (Test-Path -LiteralPath (Join-Path $addonDir $name)) {
                    $owner = Get-AddonOwner $name
                    if ($owner -ne $Mod.Key) {
                        $from = 'something this script did not install'; if ($owner) { $from = $owner }
                        Write-Warn "CLASH: addon\$name already exists (from $from). Left as it is; this mod's copy was not installed."
                        $script:Clashes += "addon\$name : $($Mod.Key) vs $from"
                        continue
                    }
                }
                $r = Copy-Overlay $folder (Join-Path $addonDir $name) (Join-Path $BackupDir (Join-Path 'addon' $name))
                Write-Info "addon\$name : $($r.Copied) files"
                $placed++
            }
            return [bool]$placed
        }
        'installer' { return (Start-ModInstaller $layout.Path $GameData) }
        default {
            Write-Warn "Could not tell how to install this one. The extracted files are in: $($layout.Path)"
            Write-Warn 'Follow the readme inside it, then run this script again.'
            return $false
        }
    }
}

# -----------------------------------------------------------------------------------------------
# Choosing what to install
# -----------------------------------------------------------------------------------------------
function Select-Mods($Installed) {
    $chosen = @{}
    foreach ($m in $Mods) { $chosen[$m.Key] = [bool]$m.Default }
    if ($script:SetList) {
        foreach ($m in $Mods) { $chosen[$m.Key] = [bool]($script:SetList.mods.PSObject.Properties.Name -contains $m.Key) }
        Write-Info "Following the set list (code $($script:SetList.code)): $(($Mods | Where-Object { $chosen[$_.Key] } | ForEach-Object { $_.Key }) -join ', ')"
        Write-Info 'To choose mods freely instead, run with -NoSetList.'
        return $chosen
    }
    if ($Only) {
        foreach ($m in $Mods) { $chosen[$m.Key] = ($m.Key -in $Only) }
    } elseif (-not $Yes) {
        while ($true) {
            Write-Host ''
            for ($i = 0; $i -lt $Mods.Count; $i++) {
                $m = $Mods[$i]
                $mark = ' '; if ($chosen[$m.Key]) { $mark = 'x' }
                $done = ''; if ($Installed.ContainsKey($m.Key)) { $done = '  (already installed)' }
                Write-Host ("   [{0}] {1}. {2}{3}" -f $mark, ($i + 1), $m.Name, $done)
                Write-Host ("          {0}" -f $m.What) -ForegroundColor DarkGray
            }
            $answer = (Read-Host '   Type a number to switch it on or off, or press Enter to continue').Trim()
            if ($answer -eq '') { break }
            $n = 0
            if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $Mods.Count) { $k = $Mods[$n - 1].Key; $chosen[$k] = -not $chosen[$k] }
        }
    }
    if ($chosen['remaster-ui'] -and $chosen['patch-1.3']) {
        Write-Warn 'remaster-ui already contains the 1.3 patch, and its author says never to install the patch on top. Skipping patch-1.3.'
        $chosen['patch-1.3'] = $false
    }
    return $chosen
}

# -----------------------------------------------------------------------------------------------
# The mission list: which missions this install really has
# -----------------------------------------------------------------------------------------------
# A mission is named map + era letter + mode, e.g. cor1g_con. Not every map has every mode, and the
# game quietly loads a different map when asked for one that does not exist. The names are stored as
# plain text inside the game's mission.lvl (and each mod's own mission.lvl), so they can be read out.
$BoardUrl = 'https://oatsphoenix.github.io/gazackticseanquest/'

function Get-MissionNames([string]$GameData) {
    $files = @()
    $stock = [IO.Path]::Combine($GameData, 'data', '_lvl_pc', 'mission.lvl')
    if (Test-Path -LiteralPath $stock) { $files += $stock }
    $addon = [IO.Path]::Combine($GameData, 'addon')
    if (Test-Path -LiteralPath $addon) {
        $files += @(Get-ChildItem -LiteralPath $addon -Recurse -File -Filter 'mission.lvl' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    $latin = [Text.Encoding]::GetEncoding(28591)   # one byte per character, so nothing is lost
    $pattern = [regex]'(?i)(?<![a-z0-9_])[a-z][a-z0-9]{1,7}[cg]_(?:con|ctf|1flag|hunt|eli|ass|xl)(?![a-z0-9_])'
    $names = @{}
    foreach ($file in $files) {
        try {
            $text = $latin.GetString([IO.File]::ReadAllBytes($file))
            foreach ($m in $pattern.Matches($text)) { $names[$m.Value.ToLowerInvariant()] = $true }
        } catch { Write-Warn "Could not read $file : $($_.Exception.Message)" }
    }
    $list = [string[]]@($names.Keys)
    [Array]::Sort($list, [StringComparer]::Ordinal)
    return $list
}

# Packs the names for the board as  cor1:c.con.ctf,g.con.ctf;tat2:c.con...
function ConvertTo-MissionList($Names) {
    $maps = [ordered]@{}
    foreach ($name in @($Names)) {
        $m = [regex]::Match($name, '^(.+)([cg])_([a-z0-9]+)$')
        if (-not $m.Success) { continue }
        $code = $m.Groups[1].Value; $era = $m.Groups[2].Value
        if (-not $maps.Contains($code)) { $maps[$code] = [ordered]@{} }
        if (-not $maps[$code].Contains($era)) { $maps[$code][$era] = @() }
        $maps[$code][$era] += $m.Groups[3].Value
    }
    $parts = foreach ($code in $maps.Keys) {
        $eras = foreach ($era in $maps[$code].Keys) { $era + '.' + ($maps[$code][$era] -join '.') }
        $code + ':' + ($eras -join ',')
    }
    return @{ Text = ($parts -join ';'); Maps = $maps.Count }
}

function Send-MissionList([string]$GameData) {
    $names = @(Get-MissionNames $GameData)
    if (-not ($names -contains 'cor1c_con')) {
        Write-Warn "Could not read the mission list from this install (found $($names.Count) names, and not the stock Coruscant one)."
        Write-Warn 'The board will keep offering every mode. Tell the project about this.'
        return $false
    }
    $packed = ConvertTo-MissionList $names
    Set-Content -LiteralPath ([IO.Path]::Combine($GameData, 'seanquest-missions.txt')) -Value $names -Encoding ASCII
    Write-Ok "Found $($names.Count) missions on $($packed.Maps) maps. The full list is in GameData\seanquest-missions.txt"
    Write-Info 'Opening the game board with this list. Battles will then only offer eras and modes that exist.'
    Start-Process ($BoardUrl + '#missions=' + $packed.Text)
    return $true
}

# -----------------------------------------------------------------------------------------------
# The launcher: lets the game board's "Launch game" button start the game on a chosen mission
# -----------------------------------------------------------------------------------------------
# The board opens a link like  seanquest://launch?mission=cor1c_con . Windows hands that link to the
# script below, which lives in GameData. It accepts nothing but a mission code in the game's own
# format, so a web page cannot use it to run anything else or pass other options to the game.
$LauncherSource = @'
param([string]$Url)
# GaZacktic Seanquest launcher. Written by install-mods.ps1; safe to delete.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$log  = Join-Path $here 'seanquest-launch.log'
function Note([string]$Text) { Add-Content -LiteralPath $log -Value ("{0}  {1}" -f (Get-Date).ToString('s'), $Text) }
try {
    if ("$Url" -cnotmatch '^seanquest://launch/?\?mission=([a-z0-9]{3,8}[cg]_[a-z0-9]{2,8})/?$') { Note "refused: $Url"; exit 2 }
    $mission = $Matches[1]
    if (Get-Process -Name 'BattlefrontII' -ErrorAction SilentlyContinue) { Note "the game is already running; not starting $mission"; exit 3 }

    # The game loads a different map when asked for a mission it does not have, so check first. The
    # names are plain text in mission.lvl. If even the stock Coruscant mission cannot be seen there,
    # the check itself is not working on this install and is skipped.
    $known = $null
    try {
        $latin = [Text.Encoding]::GetEncoding(28591)
        $files = @([IO.Path]::Combine($here, 'data', '_lvl_pc', 'mission.lvl'))
        $addon = [IO.Path]::Combine($here, 'addon')
        if (Test-Path -LiteralPath $addon) { $files += @(Get-ChildItem -LiteralPath $addon -Recurse -File -Filter 'mission.lvl' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
        $sawStock = $false
        foreach ($file in $files) {
            if (-not (Test-Path -LiteralPath $file)) { continue }
            $text = $latin.GetString([IO.File]::ReadAllBytes($file))
            if ($text.IndexOf('cor1c_con', [StringComparison]::OrdinalIgnoreCase) -ge 0) { $sawStock = $true }
            if ($text.IndexOf($mission, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $known = $true; break }
        }
        if ($known -ne $true -and $sawStock) { $known = $false }
    } catch { Note "could not check the mission list: $($_.Exception.Message)" }
    if ($known -eq $false) {
        Note "refused: this install has no mission $mission"
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [void][System.Windows.Forms.MessageBox]::Show("This copy of Battlefront II has no mission called $mission.`n`nThat map probably does not have this mode in this era. Nothing was started.`n`nPick another mode on the battle card.", 'GaZacktic Seanquest launcher', 'OK', 'Warning')
        } catch { }
        exit 4
    }

    # The display's real resolution and refresh rate, asked of the graphics adapter: with display
    # scaling on, Windows tells ordinary programs a scaled-down size, which would start the game
    # below the screen's own resolution.
    $w = 0; $h = 0; $hz = 0
    try {
        $mode = Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.CurrentHorizontalResolution } |
            Sort-Object { [int64]$_.CurrentHorizontalResolution * [int64]$_.CurrentVerticalResolution } -Descending | Select-Object -First 1
        if ($mode) { $w = [int]$mode.CurrentHorizontalResolution; $h = [int]$mode.CurrentVerticalResolution; $hz = [int]$mode.CurrentRefreshRate }
    } catch { }
    if (-not $w) { try { Add-Type -AssemblyName System.Windows.Forms; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $w = $b.Width; $h = $b.Height } catch { } }
    if (-not $w) { $w = 1920; $h = 1080 }
    # The game stops at 80 frames a second unless told a rate. Use the screen's, but no higher than
    # 144: players report vehicles and AI misbehaving at very high rates.
    if ($hz -lt 50) { $hz = 60 }
    if ($hz -gt 144) { $hz = 144 }

    # These options can be replaced by a line in seanquest-launch-args.txt (the first line there
    # that is not a comment), without touching this script.
    $template = '/resolution {w} {h} /fixedrate {hz} {mission}'
    $argsFile = Join-Path $here 'seanquest-launch-args.txt'
    if (Test-Path -LiteralPath $argsFile) {
        $line = Get-Content -LiteralPath $argsFile | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } | Select-Object -First 1
        if ($line) { $template = $line.Trim() }
    }
    $gameArgs = $template.Replace('{w}', "$w").Replace('{h}', "$h").Replace('{hz}', "$hz").Replace('{mission}', $mission)

    # The Steam copy has to be started through Steam for its options to reach the game.
    $steamExe = $null
    if ($here -match 'steamapps') {
        try { $steamExe = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamExe } catch { }
    }
    if ($steamExe -and (Test-Path -LiteralPath $steamExe)) {
        Note "starting through Steam: -applaunch 6060 $gameArgs"
        Start-Process -FilePath $steamExe -ArgumentList "-applaunch 6060 $gameArgs"
    } else {
        Note "starting: BattlefrontII.exe $gameArgs"
        Start-Process -FilePath (Join-Path $here 'BattlefrontII.exe') -WorkingDirectory $here -ArgumentList $gameArgs
    }
} catch {
    Note "error: $($_.Exception.Message)"
    exit 1
}
'@

function Register-Launcher([string]$GameData) {
    $launcher = Join-Path $GameData 'seanquest-launch.ps1'
    Set-Content -LiteralPath $launcher -Value $LauncherSource -Encoding ASCII
    $argsFile = Join-Path $GameData 'seanquest-launch-args.txt'
    # The options file only holds an override. One written by an earlier version of this script
    # (its old default as the active line) is replaced, so the new defaults take effect.
    $active = $null
    if (Test-Path -LiteralPath $argsFile) {
        $active = Get-Content -LiteralPath $argsFile | Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } | Select-Object -First 1
    }
    if (-not (Test-Path -LiteralPath $argsFile) -or "$active".Trim() -eq '/resolution {w} {h} {mission}') {
        Set-Content -LiteralPath $argsFile -Encoding ASCII -Value @(
            '# Options the launcher gives the game. Lines starting with # are ignored.'
            '# With no other line here, the launcher uses:'
            '#   /resolution {w} {h} /fixedrate {hz} {mission}'
            '# {w} {h} = your screen''s own resolution, {hz} = its refresh rate (144 at most),'
            '# {mission} = the mission code from the board.'
            '#'
            '# To change them, add a line without # below. Examples:'
            '#   /resolution {w} {h} {mission}                 no frame-rate option: the game''s own 80 fps limit'
            '#   /win /resolution 1920 1080 {mission}          in a window at a fixed size'
        )
    }
    try {
        $key = 'HKCU:\Software\Classes\seanquest'
        New-Item -Path "$key\shell\open\command" -Force | Out-Null
        Set-ItemProperty -Path $key -Name '(default)' -Value 'URL:GaZacktic Seanquest launcher'
        Set-ItemProperty -Path $key -Name 'URL Protocol' -Value ''
        Set-ItemProperty -Path "$key\shell\open\command" -Name '(default)' -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcher`" `"%1`""
        $mode = Get-DisplayMode
        Write-Ok 'Launcher installed: the board''s "Launch game" button can now start the game.'
        Write-Info "It will start the game at $($mode.Width)x$($mode.Height) and $($mode.Hz) frames a second."
        Write-Info 'For the frame rate to apply, turn V-Sync on once in the game: Options > Video.'
        Write-Info 'The first time, your browser asks whether to open the link; allow it.'
        return $true
    } catch {
        Write-Warn "Could not register the seanquest:// link type: $($_.Exception.Message)"
        return $false
    }
}

function Unregister-Launcher([string]$GameData) {
    try { Remove-Item -Path 'HKCU:\Software\Classes\seanquest' -Recurse -Force -ErrorAction Stop } catch { }
    foreach ($f in @('seanquest-launch.ps1', 'seanquest-launch-args.txt', 'seanquest-launch.log')) {
        Remove-Item -LiteralPath (Join-Path $GameData $f) -Force -ErrorAction SilentlyContinue
    }
    Write-Ok 'Launcher removed.'
}

# The display's real resolution and refresh rate (see the same lookup in the launcher).
function Get-DisplayMode {
    $w = 0; $h = 0; $hz = 0
    try {
        $mode = Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.CurrentHorizontalResolution } |
            Sort-Object { [int64]$_.CurrentHorizontalResolution * [int64]$_.CurrentVerticalResolution } -Descending | Select-Object -First 1
        if ($mode) { $w = [int]$mode.CurrentHorizontalResolution; $h = [int]$mode.CurrentVerticalResolution; $hz = [int]$mode.CurrentRefreshRate }
    } catch { }
    if (-not $w) { try { Add-Type -AssemblyName System.Windows.Forms; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $w = $b.Width; $h = $b.Height } catch { } }
    if (-not $w) { $w = 1920; $h = 1080 }
    if ($hz -lt 50) { $hz = 60 }
    if ($hz -gt 144) { $hz = 144 }
    return @{ Width = $w; Height = $h; Hz = $hz }
}

function New-GameShortcut([string]$GameData) {
    try {
        $mode = Get-DisplayMode
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Battlefront II (Seanquest).lnk'))
        $link.TargetPath = Join-Path $GameData 'BattlefrontII.exe'
        $link.WorkingDirectory = $GameData
        $link.Arguments = "/resolution $($mode.Width) $($mode.Height) /fixedrate $($mode.Hz)"
        $link.Save()
        Write-Ok "Desktop shortcut created: Battlefront II (Seanquest), at $($mode.Width)x$($mode.Height), $($mode.Hz) Hz."
    } catch { Write-Warn "Could not create the desktop shortcut: $($_.Exception.Message)" }
}

# -----------------------------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------------------------
function Invoke-Main {
    Write-Host 'GaZacktic Seanquest - Battlefront II (2005) mod installer' -ForegroundColor Cyan

    Write-Step 'Finding the game'
    $gameData = $GamePath
    if (-not $gameData) { $gameData = Find-GameData }
    if (-not $gameData) { $gameData = Select-GameDataFolder }
    if (-not (Test-GameData $gameData)) { Stop-Script "BattlefrontII.exe is not in '$gameData'. Point -GamePath at the GameData folder." }
    $gameData = (Resolve-Path -LiteralPath $gameData).Path.TrimEnd('\')
    $script:GameDataRoot = $gameData
    if ($gameData -match 'Classic Collection') { Stop-Script 'This is the Classic Collection. These mods are for the 2005 game (Steam "Star Wars Battlefront 2 (Classic, 2005)" or GOG).' }
    Write-Ok $gameData

    if (Get-Process -Name 'BattlefrontII' -ErrorAction SilentlyContinue) { Stop-Script 'Battlefront II is running. Close it and run this again.' }
    if (-not (Test-WriteAccess $gameData)) {
        Write-Info 'This folder needs administrator rights. Restarting as administrator...'
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-GamePath', "`"$gameData`"")
        if ($Yes) { $argList += '-Yes' }
        if ($Force) { $argList += '-Force' }
        if ($NoShortcut) { $argList += '-NoShortcut' }
        if ($LauncherOnly) { $argList += '-LauncherOnly' }
        if ($ScanMissions) { $argList += '-ScanMissions' }
        if ($NoLauncher) { $argList += '-NoLauncher' }
        if ($TestLaunch) { $argList += '-TestLaunch'; $argList += $TestLaunch }
        if ($Only) { $argList += '-Only'; $argList += ($Only -join ',') }
        Start-Process powershell -Verb RunAs -ArgumentList $argList
        exit 0
    }

    New-Item -ItemType Directory -Path $DownloadDir, $WorkDir -Force | Out-Null
    $statePath = Join-Path $gameData 'seanquest-mods.json'
    $installed = @{}
    if (Test-Path -LiteralPath $statePath) {
        try { (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $installed[$_.Name] = $_.Value } } catch { }
    }
    $backupDir = Join-Path $gameData '_seanquest_backup'

    $script:Installed = $installed
    $script:Clashes = @()

    if ($LauncherOnly) {
        Write-Step 'Game launcher'
        [void](Register-Launcher $gameData)
        Write-Step 'Mission list'
        [void](Send-MissionList $gameData)
        return
    }
    if ($ScanMissions) {
        Write-Step 'Mission list'
        [void](Send-MissionList $gameData)
        return
    }
    if ($RemoveLauncher) { Write-Step 'Removing the launcher'; Unregister-Launcher $gameData; return }
    if ($TestLaunch) {
        Write-Step "Test launch: $TestLaunch"
        if ($TestLaunch -cnotmatch '^[a-z0-9]{3,8}[cg]_[a-z0-9]{2,8}$') { Stop-Script 'That is not a mission code. Example: cor1c_con (Coruscant, Clone Wars, conquest).' }
        if (-not (Register-Launcher $gameData)) { return }
        Write-Info 'Opening the same link the board uses. The game should start on that mission.'
        Start-Process "seanquest://launch?mission=$TestLaunch"
        Write-Info "If nothing happens, look at: $(Join-Path $gameData 'seanquest-launch.log')"
        return
    }

    $script:SetList = Read-SetList

    if ($MakeSetList) {
        Write-Step 'Writing the set list from this install'
        if (-not $installed.Count) { Stop-Script 'This script has not installed anything here yet, so there is nothing to list.' }
        Write-SetList $installed $gameData
        return
    }

    if ($Undo) {
        foreach ($key in $Undo) {
            $mod = $Mods | Where-Object { $_.Key -eq $key } | Select-Object -First 1
            if (-not $mod) { Write-Warn "No mod is called '$key'. Keys: $(($Mods | ForEach-Object { $_.Key }) -join ', ')"; continue }
            Write-Step "Removing $($mod.Name)"
            if (-not $installed.ContainsKey($key)) { Write-Info 'This script has not installed it here.'; continue }
            if (Undo-Mod $mod $installed[$key] $gameData $backupDir) {
                $installed.Remove($key)
                $installed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath
            }
        }
        Write-Step 'Verifying what is still installed'
        [void](Invoke-Verification $installed $gameData)
        return
    }

    if ($Verify) {
        Write-Step 'Verifying installed mods'
        $bad = Invoke-Verification $installed $gameData
        Write-Step 'Comparing with the set list'
        if ($script:SetList) { if (-not (Compare-SetList $script:SetList $gameData)) { $bad++ } }
        else { Write-Info "No set list here. This install's code: $((Get-GameFingerprint $gameData).Code)" }
        if ($bad) { exit 1 }
        return
    }

    Write-Step 'Choosing mods'
    $chosen = Select-Mods $installed
    $queue = @($Mods | Where-Object { $chosen[$_.Key] -and ($Force -or -not $installed.ContainsKey($_.Key)) })
    foreach ($m in ($Mods | Where-Object { $chosen[$_.Key] -and $installed.ContainsKey($_.Key) -and -not $Force })) { Write-Info "Skipping $($m.Name): already installed (use -Force to redo it)." }
    if (-not $queue.Count) { Write-Info 'Nothing to install.'; return }

    if ($chosen['xbox-dlc'] -and $chosen['bf1-maps']) {
        Write-Info "Note: the Xbox DLC's author says it may clash with BF1 map packs, and Marvel4's pack already has the four DLC maps."
        Write-Info 'Folder-name clashes are caught during install. If maps are doubled or the game crashes: install-mods.bat -Undo xbox-dlc'
    }
    $needGb = 3; if ($queue | Where-Object { $_.Key -eq 'hd-graphics' }) { $needGb = 16 }
    try {
        $freeGb = [math]::Round((Get-PSDrive -Name $gameData.Substring(0, 1)).Free / 1GB, 1)
        if ($freeGb -lt $needGb) { Write-Warn "Only $freeGb GB free on the game's drive; about $needGb GB is recommended." }
    } catch { }

    $watchDir = Get-BrowserDownloadsFolder
    $results = @()
    foreach ($mod in $queue) {
        Write-Step $mod.Name
        Write-Info $mod.What
        $ok = $false
        try {
            $file = $null
            if ($mod.Source -eq 'moddb') { $file = Get-ManualDownload $mod $watchDir } else { $file = Get-DirectDownload $mod }
            if (-not $file) { Write-Warn 'Skipped.'; $results += @{ Mod = $mod; Status = 'skipped' }; continue }
            if (-not (Test-ModDownload $mod $file)) { $results += @{ Mod = $mod; Status = 'REJECTED' }; continue }
            $script:Snapshot = Get-GameSnapshot $gameData
            $script:Touched = @()
            $ok = Install-Mod $mod $file $gameData $backupDir
        } catch {
            Write-Warn "Failed: $($_.Exception.Message)"
        }
        if ($ok) {
            $changed = @(@(Compare-GameSnapshot $script:Snapshot (Get-GameSnapshot $gameData)) + $script:Touched | Sort-Object -Unique)
            # Round-trip through JSON so a record made now looks the same as one loaded from disk.
            $record = New-InstallRecord $changed $gameData $script:Touched | ConvertTo-Json -Depth 5 | ConvertFrom-Json
            $problems = @(Test-InstalledMod $mod $record $gameData)
            if ($problems.Count) {
                Write-Warn "Installed, but it does not check out: $($problems -join '; ')"
                $results += @{ Mod = $mod; Status = 'UNVERIFIED' }
                continue
            }
            Write-Ok "$($mod.Name) installed and verified ($($changed.Count) files)."
            $installed[$mod.Key] = $record
            $installed | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statePath
            $results += @{ Mod = $mod; Status = 'installed' }
        } else {
            $results += @{ Mod = $mod; Status = 'FAILED' }
        }
    }

    if (-not $NoShortcut) { Write-Step 'Shortcut'; New-GameShortcut $gameData }
    if (-not $NoLauncher) { Write-Step 'Game launcher'; [void](Register-Launcher $gameData) }
    # the mods just installed add missions, so hand the board the new list
    Write-Step 'Mission list'
    [void](Send-MissionList $gameData)

    Write-Step 'Summary'
    foreach ($r in $results) { Write-Info ("{0,-10} {1}" -f $r.Status, $r.Mod.Name) }

    Write-Step 'Verifying everything this script has installed'
    $bad = Invoke-Verification $installed $gameData
    if ($bad) { Write-Warn "$bad mod(s) failed the check. Run this script again with -Force to reinstall them." }
    if ($script:Clashes.Count) {
        Write-Warn 'Addon folders that two mods both wanted (the first one installed was kept):'
        foreach ($c in $script:Clashes) { Write-Warn "  $c" }
    }

    Write-Step 'Set list'
    if ($script:SetList) {
        if (-not (Compare-SetList $script:SetList $gameData)) {
            Write-Warn 'Until this says MATCH, the two installs are not guaranteed to be the same.'
        }
    } elseif ($installed.Count) {
        Write-SetList $installed $gameData
    }
    Write-Info ''
    Write-Info "Replaced files were backed up to: $backupDir"
    Write-Info 'Both players need the same map mods (xbox-dlc, bf1-maps) to play together.'
    Write-Info 'Galactic Conquest bonuses in any match: pause, open Fake Console, pick "Bonus 1 ..." or "Bonus 2 ...".'
    Write-Info 'To take one mod back out: install-mods.bat -Undo <key>   (for example -Undo ai, or -Undo xbox-dlc)'
    Write-Info 'To undo everything: Steam > game Properties > Installed Files > Verify integrity, then delete GameData\addon.'
}

# Dot-sourcing the file (. .\install-mods.ps1) loads the functions without running the installer.
if ($MyInvocation.InvocationName -ne '.') { Invoke-Main }
