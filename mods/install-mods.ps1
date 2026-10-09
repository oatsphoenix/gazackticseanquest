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
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [switch]$Yes,
    [string[]]$Only,
    [switch]$Force,
    [switch]$NoShortcut,
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is many times faster without the bar
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# "-Only a,b" arrives as one string when the script is started with -File, so split it here.
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }

$Root        = Split-Path -Parent $MyInvocation.MyCommand.Path
$DownloadDir = Join-Path $Root 'downloads'
$WorkDir     = Join-Path $Root 'work'
$ArchiveExt  = @('.zip', '.7z', '.rar', '.exe')

# -----------------------------------------------------------------------------------------------
# The mod set, in install order. Order matters:
#   - hd-graphics goes first so the interface mod's files end up on top of it.
#   - remaster-ui already contains the unofficial 1.3 patch; its author says never to install the
#     1.3 patch after it, so patch-1.3 is only used when remaster-ui is not selected.
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
    @{ Key = 'xbox-dlc'; Name = 'Xbox DLC and Title Update content for PC'; Default = $true; Source = 'moddb'; Kind = 'addon'
       What = 'Bespin Cloud City, Rhen Var Citadel and Harbor, Yavin 4 Arena, Kit Fisto, Asajj Ventress.'
       NameLike = 'xbox|dlc'; MinMB = 5; MaxMB = 300; Contains = @('DLC_XBOX', 'UPDATE_XBOX', 'addme.script')
       Url  = 'https://www.moddb.com/mods/xbox-dlc-content-for-pc/downloads/xbox-dlc-and-title-update-content-for-pc' }
    @{ Key = 'bf1-maps'; Name = "Marvel4's Conversion Pack 1.1"; Default = $true; Source = 'moddb'; Kind = 'addon'
       What = '13 Battlefront 1 maps, including every BF1 map on the Seanquest board.'
       NameLike = 'marvel|conversion'; MinMB = 20; MaxMB = 5000; Contains = @('addme.script')
       Url  = 'https://www.moddb.com/downloads/marvel4s-conversion-pack-11' }
    @{ Key = 'ai'; Name = 'AI Difficulty mod 2.0'; Default = $false; Source = 'moddb'; Kind = 'lvl'
       What = 'EXPERIMENTAL. Forces Elite AI on the stock maps by replacing mission.lvl. May clash with other mods.'
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
function Test-GameData([string]$Path) {
    return [bool]($Path -and (Test-Path -LiteralPath (Join-Path $Path 'BattlefrontII.exe')))
}

# Steam keeps a list of every library folder in libraryfolders.vdf; each one may hold the game.
function Get-SteamLibraryPaths([string]$VdfText) {
    $paths = @()
    foreach ($m in [regex]::Matches($VdfText, '"path"\s+"([^"]+)"')) {
        $paths += ($m.Groups[1].Value -replace '\\\\', '\')
    }
    return $paths
}

function Find-GameData {
    $candidates = @()
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam', 'HKCU:\Software\Valve\Steam')) {
        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($name in @('InstallPath', 'SteamPath')) {
                $steam = $props.$name
                if (-not $steam) { continue }
                $libs = @($steam)
                $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
                if (Test-Path -LiteralPath $vdf) { $libs += Get-SteamLibraryPaths (Get-Content -LiteralPath $vdf -Raw) }
                foreach ($lib in $libs) { $candidates += (Join-Path $lib 'steamapps\common\Star Wars Battlefront II\GameData') }
            }
        } catch { }
    }
    try {
        foreach ($game in Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games' -ErrorAction Stop) {
            $props = Get-ItemProperty -Path $game.PSPath
            if ("$($props.gameName)" -match 'Battlefront.*II' -and $props.path) { $candidates += (Join-Path $props.path 'GameData') }
        }
    } catch { }
    foreach ($drive in @('C:', 'D:', 'E:', 'F:')) {
        $candidates += "$drive\Program Files (x86)\Steam\steamapps\common\Star Wars Battlefront II\GameData"
        $candidates += "$drive\SteamLibrary\steamapps\common\Star Wars Battlefront II\GameData"
        $candidates += "$drive\GOG Games\Star Wars Battlefront II\GameData"
        $candidates += "$drive\Program Files (x86)\GOG Galaxy\Games\Star Wars Battlefront II\GameData"
    }
    foreach ($c in ($candidates | Select-Object -Unique)) { if (Test-GameData $c) { return $c } }
    return $null
}

function Select-GameDataFolder {
    Write-Info 'Could not find the game automatically. Pick the GameData folder (it contains BattlefrontII.exe).'
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Select the Battlefront II GameData folder (contains BattlefrontII.exe)'
        if ($dialog.ShowDialog() -eq 'OK') { return $dialog.SelectedPath }
    } catch { }
    return (Read-Host '   Paste the full path to the GameData folder').Trim('"', ' ')
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
function New-InstallRecord($Changed, [string]$GameData) {
    $changed = @($Changed)
    $addons = @($changed | Where-Object { $_ -like 'addon/*/addme.script' } | ForEach-Object { ($_ -split '/')[1] } | Select-Object -Unique)
    $step = [int][math]::Max(1, [math]::Floor($changed.Count / 25))
    $sample = @(); for ($i = 0; $i -lt $changed.Count; $i += $step) { $sample += $changed[$i] }
    $hashes = @{}
    foreach ($rel in ($changed | Where-Object { $_ -like 'data/_lvl_pc/*.lvl' -and $_ -notlike 'data/_lvl_pc/*/*' })) {
        $hashes[$rel] = (Get-FileHash -LiteralPath (Join-Path $GameData $rel) -Algorithm SHA256).Hash.ToLower()
    }
    return @{ Date = (Get-Date).ToString('s'); Changed = $changed.Count; Addon = $addons; Sample = $sample; Hashes = $hashes }
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
    if ($Mod.Source -eq 'github') {
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
            foreach ($folder in $layout.Paths) {
                $name = Split-Path -Leaf $folder
                $r = Copy-Overlay $folder (Join-Path $addonDir $name) (Join-Path $BackupDir (Join-Path 'addon' $name))
                Write-Info "addon\$name : $($r.Copied) files"
            }
            return $true
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

function New-GameShortcut([string]$GameData) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Battlefront II (Seanquest).lnk'))
        $link.TargetPath = Join-Path $GameData 'BattlefrontII.exe'
        $link.WorkingDirectory = $GameData
        $link.Arguments = "/resolution $($screen.Width) $($screen.Height)"
        $link.Save()
        Write-Ok "Desktop shortcut created: Battlefront II (Seanquest), at $($screen.Width)x$($screen.Height)."
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

    if ($Verify) {
        Write-Step 'Verifying installed mods'
        $bad = Invoke-Verification $installed $gameData
        if ($bad) { exit 1 }
        return
    }

    Write-Step 'Choosing mods'
    $chosen = Select-Mods $installed
    $queue = @($Mods | Where-Object { $chosen[$_.Key] -and ($Force -or -not $installed.ContainsKey($_.Key)) })
    foreach ($m in ($Mods | Where-Object { $chosen[$_.Key] -and $installed.ContainsKey($_.Key) -and -not $Force })) { Write-Info "Skipping $($m.Name): already installed (use -Force to redo it)." }
    if (-not $queue.Count) { Write-Info 'Nothing to install.'; return }

    if ($chosen['xbox-dlc'] -and $chosen['bf1-maps']) {
        Write-Warn "The Xbox DLC's author says it may clash with BF1 map packs, and Marvel4's pack already has the four DLC maps."
        Write-Warn 'If the game crashes or maps are doubled up, delete the DLC_XBOX and UPDATE_XBOX folders from GameData\addon.'
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
            $record = New-InstallRecord $changed $gameData | ConvertTo-Json -Depth 5 | ConvertFrom-Json
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

    Write-Step 'Summary'
    foreach ($r in $results) { Write-Info ("{0,-10} {1}" -f $r.Status, $r.Mod.Name) }

    Write-Step 'Verifying everything this script has installed'
    $bad = Invoke-Verification $installed $gameData
    if ($bad) { Write-Warn "$bad mod(s) failed the check. Run this script again with -Force to reinstall them." }
    Write-Info ''
    Write-Info "Replaced files were backed up to: $backupDir"
    Write-Info 'Both players need the same map mods (xbox-dlc, bf1-maps) to play together.'
    Write-Info 'Galactic Conquest bonuses in any match: pause, open Fake Console, pick "Bonus 1 ..." or "Bonus 2 ...".'
    Write-Info 'To undo everything: Steam > game Properties > Installed Files > Verify integrity, then delete GameData\addon.'
}

# Dot-sourcing the file (. .\install-mods.ps1) loads the functions without running the installer.
if ($MyInvocation.InvocationName -ne '.') { Invoke-Main }
