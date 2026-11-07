<#
.SYNOPSIS
  Get the latest scene collections from GitHub and replace every one OBS has. Run it from a normal PowerShell,
  not as administrator. (Windows twin of update-obs-scene-collections.sh.)

.DESCRIPTION
  Close OBS first. Changes made to these collections in OBS are replaced, without asking; each old file is kept
  as *.bak. Collections that did not come from this repo are left alone, none are added, and the collection OBS
  opens with stays the same. It installs nothing. If GitHub cannot be reached, nothing is changed.

.PARAMETER NoPull       Skip GitHub and use the collections already in this checkout.
.PARAMETER AudioDevice  Part of the name of the audio input to use (default: Sound Blaster, else any USB input).
.PARAMETER ObsDir       OBS's config folder. Default: %APPDATA%\obs-studio.
.PARAMETER MusicDir     The sacrament graphic and music folder. Default: Documents\sacrament.
#>
param(
    [switch]$NoPull,
    [string]$AudioDevice,
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio'),
    [string]$MusicDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'sacrament')
)
$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

. (Join-Path $PSScriptRoot 'obs-collection.ps1')

Assert-ObsReady $ObsDir

if (-not $NoPull) {
    if (-not (Update-Checkout (Split-Path -Parent $PSScriptRoot))) {
        Fail 'Could not get the latest scene collections from GitHub, so nothing changed. Check the internet connection, or use -NoPull to use the ones already on this computer.'
    }

    # Carry on with the copy just pulled, as this script may have changed too.
    $again = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-NoPull', '-ObsDir', $ObsDir, '-MusicDir', $MusicDir)
    if ($AudioDevice) { $again += @('-AudioDevice', $AudioDevice) }
    & (Get-Process -Id $PID).Path @again
    exit $LASTEXITCODE
}

$scenes = Join-Path $ObsDir 'basic\scenes'
$repo = @(Get-RepoCollections (Join-Path (Split-Path -Parent $PSScriptRoot) 'configs'))
$present = @(Get-ObsCollections $scenes)
$updates = @($repo | Where-Object { $present.File -contains $_.File })
$others = @($present | Where-Object { $updates.File -notcontains $_.File })

if ($updates) {
    $deviceId = Select-AudioInput $AudioDevice
    foreach ($c in $updates) {
        Install-Collection $c.Dir $scenes $MusicDir $deviceId
        Write-Host "    Updated the '$($c.Name)' scene collection."
    }
} else {
    Write-Host '    OBS has no scene collections from this repo; nothing changed. Use tools\add-obs-scene-collection.ps1 to add one.'
}
if ($others) { Write-Host "    Left alone (not from this repo): $(($others | ForEach-Object Name) -join ', ')" }
if ($updates) { Show-MissingPieces @($updates | ForEach-Object Dir) $MusicDir }
