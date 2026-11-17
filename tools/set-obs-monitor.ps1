<#
.SYNOPSIS
  Point OBS's audio monitoring device at "CABLE Input (VB-Audio Virtual Cable)", which Zoom hears as the
  microphone "CABLE Output", in every OBS profile. (Windows twin of set-obs-monitor.py.)

.DESCRIPTION
  OBS monitors "USB Audio" and "Sacrament Music" (set to Monitor and Output in the collections) into the cable.
  Close OBS first. Does nothing (with a warning) if OBS has no profile yet or the cable is not active.

.PARAMETER ObsDir OBS's config folder. Default: %APPDATA%\obs-studio.
#>
param(
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio')
)
$ErrorActionPreference = 'Stop'

# Windows lists audio outputs under MMDevices; OBS stores an endpoint's id as {0.0.0.00000000}.{guid}.
$render = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render'
$cable = foreach ($k in Get-ChildItem $render -ErrorAction SilentlyContinue) {
    if ((Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DeviceState -ne 1) { continue }   # 1 = active
    $props = Get-ItemProperty (Join-Path $k.PSPath 'Properties') -ErrorAction SilentlyContinue
    if (-not $props) { continue }
    $desc = $props.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
    $iface = $props.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'
    if ($desc -like 'CABLE Input*') { [pscustomobject]@{ Id = '{0.0.0.00000000}.' + $k.PSChildName; Name = "$desc ($iface)" }; break }
}
if (-not $cable) {
    Write-Warning 'The virtual cable is not active, so OBS monitoring was not pointed at it. Restart Windows (or run the setup) and try again.'
    exit 0
}
$profiles = @(Get-ChildItem (Join-Path $ObsDir 'basic\profiles') -Directory -ErrorAction SilentlyContinue)
if ($profiles.Count -eq 0) {
    Write-Warning "OBS has no profile in $ObsDir yet; run the setup (or open OBS once) first."
    exit 0
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$set = [ordered]@{ MonitoringDeviceId = $cable.Id; MonitoringDeviceName = $cable.Name }
foreach ($p in $profiles) {
    # In [Audio], replace the two keys (added at the top of the section).
    $ini = Join-Path $p.FullName 'basic.ini'
    $lines = if (Test-Path $ini) { @([IO.File]::ReadAllLines($ini)) } else { @() }
    $out = New-Object System.Collections.Generic.List[string]
    $inAudio = $false; $seen = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*\[(.+)\]\s*$') {
            $inAudio = ($Matches[1] -eq 'Audio')
            $out.Add($l)
            if ($inAudio) { $seen = $true; foreach ($k in $set.Keys) { $out.Add("$k=$($set[$k])") } }
        } elseif (-not ($inAudio -and $l -match '^([^=]+)=' -and $set.Contains($Matches[1]))) {
            $out.Add($l)
        }
    }
    if (-not $seen) { $out.Add('[Audio]'); foreach ($k in $set.Keys) { $out.Add("$k=$($set[$k])") } }
    [IO.File]::WriteAllLines($ini, $out.ToArray(), $utf8)
    Write-Host "    OBS monitoring device ($($p.Name)): $($cable.Name)"
}
