<#
.SYNOPSIS
  Install the OBS window layout in configs\obs-layout.ini, which has the PTZ Controls dock in place.
  (Windows twin of set-obs-docks.py.)

.DESCRIPTION
  Keeps the layout already there if PTZ Controls is docked in it, so changes made in OBS survive a re-run.
  Also turns off OBS's popup about closing a dock. Close OBS first: it writes its own layout when it exits.

.PARAMETER ObsDir OBS's config folder. Default: %APPDATA%\obs-studio.
#>
param(
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio')
)
$ErrorActionPreference = 'Stop'

$userIni = Join-Path $ObsDir 'user.ini'
$lines = if (Test-Path $userIni) { @([IO.File]::ReadAllLines($userIni)) } else { @() }

# Skip OBS's "You just closed a dockable window" popup.
$warned = 'WarnedAboutClosingDocks=true'
$kept = New-Object System.Collections.Generic.List[string]
$lines | Where-Object { $_ -notlike 'WarnedAboutClosingDocks=*' } | ForEach-Object { $kept.Add($_) }
$general = $kept.IndexOf('[General]')
if ($general -ge 0) { $kept.Insert($general + 1, $warned) } else { $kept.Add('[General]'); $kept.Add($warned) }
$lines = $kept.ToArray()
New-Item -ItemType Directory -Force $ObsDir | Out-Null
[IO.File]::WriteAllLines($userIni, $lines, (New-Object System.Text.UTF8Encoding $false))

$current = $lines | Where-Object { $_ -like 'DockState=?*' } | Select-Object -First 1
if ($current) {
    # Names in Qt's saved window state are UTF-16; the flags byte after one is 1 visible, 2 floating.
    $state = [Convert]::FromBase64String($current.Substring('DockState='.Length))
    $latin1 = [Text.Encoding]::GetEncoding(28591)
    $name = $latin1.GetString([Text.Encoding]::BigEndianUnicode.GetBytes('ptz-dock'))
    $i = $latin1.GetString($state).IndexOf($name, [StringComparison]::Ordinal)
    if ($i -ge 0 -and $state[$i + $name.Length] -eq 1) {
        Write-Host '    PTZ Controls is already docked; leaving the OBS layout alone.'
        exit 0
    }
}

$layout = [string[]]@(Get-Content (Join-Path $PSScriptRoot '..\configs\obs-layout.ini') |
    Where-Object { $_ -match '^(geometry|DockState)=' })
$out = New-Object System.Collections.Generic.List[string]
$inSection = $false; $seen = $false
foreach ($l in $lines) {
    if ($l -match '^\s*\[(.+)\]\s*$') {
        $inSection = ($Matches[1] -eq 'BasicWindow')
        $out.Add($l)
        if ($inSection) { $seen = $true; $out.AddRange($layout) }
    } elseif (-not ($inSection -and $l -match '^(geometry|DockState)=')) {
        $out.Add($l)
    }
}
if (-not $seen) { $out.Add('[BasicWindow]'); $out.AddRange($layout) }
New-Item -ItemType Directory -Force $ObsDir | Out-Null
[IO.File]::WriteAllLines($userIni, $out.ToArray(), (New-Object System.Text.UTF8Encoding $false))
Write-Host "    OBS layout with PTZ Controls docked installed in $userIni"
