<#
.SYNOPSIS
  Add one scene collection to OBS, and nothing else. Run it from a normal PowerShell, not as administrator.
  (Windows twin of add-obs-scene-collection.sh.)

.DESCRIPTION
  Close OBS first. It lists the collections OBS already has and asks which of the others to add. It installs
  nothing, does not update this repo, and leaves the collection OBS opens with as it is: the new one appears in
  OBS's Scene Collection menu. Only collections in this checkout can be added. A collection that is already
  there is left alone, so scenes changed in OBS survive; -Force replaces it.

.PARAMETER Config       The collection in configs\<name> to add, instead of asking.
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

Assert-ObsReady $ObsDir

$scenes = Join-Path $ObsDir 'basic\scenes'
$repo = @(Get-RepoCollections (Join-Path (Split-Path -Parent $PSScriptRoot) 'configs'))
$present = @(Get-ObsCollections $scenes)

if (-not $Config) {
    if ($present) { Write-Host "Already in OBS: $(($present | ForEach-Object Name) -join ', ')" }
    $choices = @($repo | Where-Object { $Force -or -not (Test-InObs $_ $present) })
    if (-not $choices) {
        Write-Host 'Every scene collection in this repo is already in OBS. To replace them, run tools\update-obs-scene-collections.ps1.'
        exit 0
    }
    Write-Host 'Which scene collection should be added?'
    for ($i = 0; $i -lt $choices.Count; $i++) { Write-Host "  $($i + 1)) $($choices[$i].Name)" }
    Write-Host '  0) cancel'
    do {
        $n = Read-Host 'Number'
    } until ($n -match '^\d+$' -and [int]$n -le $choices.Count)
    if ([int]$n -eq 0) { exit 0 }
    $Config = $choices[[int]$n - 1].Config
}

$collection = $repo | Where-Object Config -eq $Config | Select-Object -First 1
if (-not $collection) { Fail "No such configuration: $Config (have: $(($repo | ForEach-Object Config) -join ', '))" }

if ((Test-InObs $collection $present) -and -not $Force) {
    Write-Host "    The '$Config' scene collection is already there; nothing changed. Use -Force to replace it."
    exit 0
}

$deviceId = Select-AudioInput $AudioDevice
Install-Collection $collection.Dir $scenes $MusicDir $deviceId
Write-Host "    Installed the '$Config' scene collection. Pick it from OBS's Scene Collection menu."
Show-MissingPieces @($collection.Dir) $MusicDir
