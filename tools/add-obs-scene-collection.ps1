<#
.SYNOPSIS
  Add one scene collection to OBS, and nothing else. Run it from a normal PowerShell, not as administrator.
  (Windows twin of add-obs-scene-collection.sh.)

.DESCRIPTION
  Close OBS first. It installs nothing, does not update this repo, and leaves the collection OBS opens with as
  it is: the new one appears in OBS's Scene Collection menu. Only collections in this checkout can be added.
  A collection that is already there is left alone, so scenes changed in OBS survive; -Force replaces it.

.PARAMETER Config       The collection in configs\<name> to add (asks if omitted).
.PARAMETER AudioDevice  Part of the name of the audio input to use (default: Sound Blaster, else any USB input).
.PARAMETER Force        Replace the collection if it is already there, keeping the old one as *.bak.
.PARAMETER ObsDir       OBS's config folder. Default: %APPDATA%\obs-studio.
.PARAMETER MusicDir     The sacrament graphic and music folder. Default: Documents\sacrament.
#>
param(
    [string]$Config,
    [string]$AudioDevice,
    [switch]$Force,
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio'),
    [string]$MusicDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'sacrament')
)
$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

. (Join-Path $PSScriptRoot 'obs-collection.ps1')

if (-not (Test-Path (Join-Path $env:ProgramFiles 'obs-studio\bin\64bit\obs64.exe'))) {
    Fail 'OBS is not installed. Run setup-obs-windows.ps1 first.'
}
if (-not (Test-Path (Join-Path $ObsDir 'user.ini'))) {
    Fail "OBS is not set up for $env:USERNAME. Sign in as the person who uses OBS, or run setup-obs-windows.ps1 first."
}
if (Get-Process obs64 -ErrorAction SilentlyContinue) { Fail 'OBS is running. Close it and run this again.' }

$configRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'configs'
$configs = @(Get-ChildItem $configRoot -Directory | ForEach-Object Name)
$scenes = Join-Path $ObsDir 'basic\scenes'

function Test-Installed($name) {
    return [bool](Get-ChildItem (Join-Path $configRoot $name) -Filter *.json |
        Where-Object { Test-Path (Join-Path $scenes $_.Name) })
}

if (-not $Config) {
    Write-Host 'Which scene collection should be added?'
    for ($i = 0; $i -lt $configs.Count; $i++) {
        $note = if (Test-Installed $configs[$i]) { ' (already added)' } else { '' }
        Write-Host "  $($i + 1)) $($configs[$i])$note"
    }
    do {
        $n = Read-Host 'Number'
    } until ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $configs.Count)
    $Config = $configs[[int]$n - 1]
}
if ($configs -notcontains $Config) { Fail "No such configuration: $Config (have: $($configs -join ', '))" }

if ((Test-Installed $Config) -and -not $Force) {
    Write-Host "    The '$Config' scene collection is already there; nothing changed. Use -Force to replace it."
    exit 0
}

$deviceId = Select-AudioInput $AudioDevice
Install-Collection (Join-Path $configRoot $Config) $scenes $MusicDir $deviceId
Write-Host "    Installed the '$Config' scene collection. Pick it from OBS's Scene Collection menu."

# Every collection uses these; OBS opens without them, but with those sources missing.
$plugins = Join-Path $env:ProgramData 'obs-studio\plugins'
foreach ($p in 'distroav', 'obs-ptz') {
    if (-not (Test-Path (Join-Path $plugins $p))) { Write-Warning "The $p plugin was not found. Run setup-obs-windows.ps1 to install it." }
}
if ((Select-String -Path (Join-Path $configRoot "$Config\*.json") -Pattern 'downstream' -Quiet) -and
    -not (Test-Path (Join-Path $env:ProgramFiles 'obs-studio\obs-plugins\64bit\downstream-keyer.dll'))) {
    Write-Warning 'The Downstream Keyer plugin was not found. Run setup-obs-windows.ps1 to install it.'
}
foreach ($f in 'sacrament-graphic.png', 'sacrament-playlist.mp3') {
    if (-not (Test-Path (Join-Path $MusicDir $f))) { Write-Warning "$f is not in $MusicDir. Run setup-obs-windows.ps1 to make it." }
}
