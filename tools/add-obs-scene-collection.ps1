<#
.SYNOPSIS
  Add scene collections to OBS, and nothing else. Run it from a normal PowerShell, not as administrator.
  (Windows twin of add-obs-scene-collection.sh.)

.DESCRIPTION
  Close OBS first. It gets the latest collections from GitHub (or, if it cannot, uses the ones in this checkout),
  lists the collections OBS already has and asks which of the others to add. The new ones appear in OBS's Scene
  Collection menu. After adding from the menu it asks which collection OBS should open with; with -Config that
  stays as it is. It installs nothing. A collection that is already there is left alone, so scenes changed in
  OBS survive; -Force replaces it.

.PARAMETER Config       The collections in configs\<name> to add, separated by commas, instead of asking.
.PARAMETER NoPull       Skip GitHub and use the collections already in this checkout.
.PARAMETER AudioDevice  Part of the name of the audio input to use (default: Sound Blaster, else any USB input).
.PARAMETER Force        Replace the collection if it is already there, keeping the old one as *.bak.
.PARAMETER ObsDir       OBS's config folder. Default: %APPDATA%\obs-studio.
.PARAMETER MusicDir     The sacrament graphic and music folder. Default: Documents\sacrament.
#>
param(
    [string]$Config,
    [switch]$NoPull,
    [string]$AudioDevice,
    [switch]$Force,
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio'),
    [string]$MusicDir = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'sacrament')
)
$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

. (Join-Path $PSScriptRoot 'obs-collection.ps1')

Assert-ObsReady $ObsDir

if (-not $NoPull) {
    if (Update-Checkout (Split-Path -Parent $PSScriptRoot)) {
        # Carry on with the copy just pulled, as this script may have changed too.
        $again = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-NoPull', '-ObsDir', $ObsDir, '-MusicDir', $MusicDir)
        foreach ($p in 'Config', 'AudioDevice') {
            $v = Get-Variable $p -ValueOnly
            if ($v) { $again += @("-$p", $v) }
        }
        if ($Force) { $again += '-Force' }
        & (Get-Process -Id $PID).Path @again
        exit $LASTEXITCODE
    }
    Write-Warning 'Could not get the latest scene collections from GitHub; using the ones already on this computer.'
}

$scenes = Join-Path $ObsDir 'basic\scenes'
$repo = @(Get-RepoCollections (Join-Path (Split-Path -Parent $PSScriptRoot) 'configs'))
$present = @(Get-ObsCollections $scenes)

$fromMenu = -not $Config
if ($fromMenu) {
    if ($present) { Write-Host "Already in OBS: $(($present | ForEach-Object Name) -join ', ')" }
    $choices = @($repo | Where-Object { $Force -or -not (Test-InObs $_ $present) })
    if (-not $choices) {
        Write-Host 'Every scene collection in this repo is already in OBS. To replace them, run tools\update-obs-scene-collections.ps1.'
        exit 0
    }
    Write-Host 'Scene collections you can add:'
    for ($i = 0; $i -lt $choices.Count; $i++) { Write-Host "  $($i + 1)) $($choices[$i].Name)" }
    Write-Host '  0) cancel'
    do {
        $n = Read-Host 'Enter the numbers of the scene collections you want to add to OBS, separated by spaces'
        if ($null -eq $n) { exit 0 }   # no more input
        $picks = @($n -split '[\s,]+' | Where-Object { $_ })
        $valid = $picks.Count -gt 0 -and -not ($picks | Where-Object { $_ -notmatch '^\d{1,3}$' -or [int]$_ -gt $choices.Count })
        # 0 cancels, so it only counts on its own.
        if ($valid -and $picks.Count -gt 1 -and ($picks | Where-Object { [int]$_ -eq 0 })) { $valid = $false }
    } until ($valid)
    if ([int]$picks[0] -eq 0) { exit 0 }
    $names = @($picks | ForEach-Object { [int]$_ } | Select-Object -Unique | ForEach-Object { $choices[$_ - 1].Config })
} else {
    $names = @($Config -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
}

# Check them all first, so a mistyped name adds nothing.
$collections = @(foreach ($name in $names) {
    $c = $repo | Where-Object Config -eq $name | Select-Object -First 1
    if (-not $c) { Fail "No such configuration: $name (have: $(($repo | ForEach-Object Config) -join ', '))" }
    $c
})

$adding = @(foreach ($c in $collections) {
    if ((Test-InObs $c $present) -and -not $Force) {
        Write-Host "    The '$($c.Config)' scene collection is already there; nothing changed. Use -Force to replace it."
    } else {
        $c
    }
})
if (-not $adding) { exit 0 }

$deviceId = Select-AudioInput $AudioDevice
foreach ($c in $adding) {
    Install-Collection $c.Dir $scenes $MusicDir $deviceId
    Write-Host "    Installed the '$($c.Config)' scene collection. Pick it from OBS's Scene Collection menu."
}
Show-MissingPieces @($adding | ForEach-Object Dir) $MusicDir

if ($fromMenu) {
    $ini = Join-Path $ObsDir 'user.ini'
    $installed = @(Get-ObsCollections $scenes)
    $active = [IO.File]::ReadAllLines($ini) | Where-Object { $_ -match '^SceneCollectionFile=' } | ForEach-Object { $_ -replace '^[^=]*=', '' } | Select-Object -First 1
    Write-Host 'Scene collections in OBS:'
    for ($i = 0; $i -lt $installed.Count; $i++) {
        $note = if ($installed[$i].File -eq $active) { ' (active now)' } else { '' }
        Write-Host "  $($i + 1)) $($installed[$i].Name)$note"
    }
    Write-Host '  0) keep the current one'
    do {
        $n = Read-Host 'Enter the number of the scene collection you want to make active'
        if (-not $n) { exit 0 }
    } until ($n -match '^\d{1,3}$' -and [int]$n -le $installed.Count)
    if ([int]$n -ne 0) {
        $c = $installed[[int]$n - 1]
        Set-IniValues $ini 'Basic' @{ SceneCollection = $c.Name; SceneCollectionFile = $c.File }
        Write-Host "    OBS will open with the '$($c.Name)' scene collection."
    }
}
