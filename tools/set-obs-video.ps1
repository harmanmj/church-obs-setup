<#
.SYNOPSIS
  Set OBS's video in every profile: 1920x1080 canvas and output, 30 fps, recording quality "Same as stream".
  (Windows twin of set-obs-video.py.)

.DESCRIPTION
  Close OBS first: it writes its settings when it exits. The setup script uses -IfFirstSetup, so changes made
  in OBS survive a re-run. Run without it to reset the video. FirstRun=true marks the setup as done, and also
  skips OBS's Auto-Configuration Wizard.

.PARAMETER ObsDir       OBS's config folder. Default: %APPDATA%\obs-studio.
.PARAMETER IfFirstSetup Do nothing if the setup has already been done on this computer.
#>
param(
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio'),
    [switch]$IfFirstSetup
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false

function Set-IniValues($path, $section, [hashtable]$values) {
    $lines = if (Test-Path $path) { [IO.File]::ReadAllLines($path) } else { @() }
    $out = New-Object System.Collections.Generic.List[string]
    $done = @{}; $inSection = $false; $seen = $false
    $flush = { foreach ($k in $values.Keys) { if (-not $done[$k]) { $out.Add("$k=$($values[$k])"); $done[$k] = $true } } }
    foreach ($l in $lines) {
        if ($l -match '^\s*\[(.+)\]\s*$') {
            if ($inSection) { & $flush }
            $inSection = ($Matches[1] -eq $section)
            if ($inSection) { $seen = $true }
        } elseif ($inSection -and $l -match '^([^=;#]+)=') {
            $k = $Matches[1].Trim()
            if ($values.ContainsKey($k)) { $out.Add("$k=$($values[$k])"); $done[$k] = $true; continue }
        }
        $out.Add($l)
    }
    if ($inSection) { & $flush }
    if (-not $seen) { $out.Add("[$section]"); & $flush }
    [IO.File]::WriteAllLines($path, $out.ToArray(), $utf8)
}

$userIni = Join-Path $ObsDir 'user.ini'
if ($IfFirstSetup) {
    if ((Test-Path $userIni) -and (Select-String -Path $userIni -Pattern '^FirstRun=true' -Quiet)) {
        Write-Host '    Keeping the OBS video settings already there.'
        exit 0
    }
} elseif (Get-Process obs64 -ErrorAction SilentlyContinue) {
    Write-Host 'OBS is running. Close it and run this again.' -ForegroundColor Red
    exit 1
}

$profiles = @(Get-ChildItem (Join-Path $ObsDir 'basic\profiles') -Directory -ErrorAction SilentlyContinue)
if ($profiles.Count -eq 0) {
    Write-Host "No OBS profiles in $ObsDir. Run the setup script first." -ForegroundColor Red
    exit 1
}
foreach ($p in $profiles) {
    $ini = Join-Path $p.FullName 'basic.ini'
    Set-IniValues $ini 'Video' @{ BaseCX = 1920; BaseCY = 1080; OutputCX = 1920; OutputCY = 1080; FPSType = 0; FPSCommon = 30 }
    Set-IniValues $ini 'SimpleOutput' @{ RecQuality = 'Stream' }
    Write-Host "    OBS video ($($p.Name)): 1920x1080 canvas and output, 30 fps, recording same as stream"
}
Set-IniValues $userIni 'General' @{ FirstRun = 'true' }
