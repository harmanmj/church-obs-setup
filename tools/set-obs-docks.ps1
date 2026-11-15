<#
.SYNOPSIS
  Install the OBS window layout in obs-configuration\obs-layout.ini, and open OBS in studio mode.
  (Windows twin of set-obs-docks.py.)

.DESCRIPTION
  The layout (window, docks with PTZ Controls in place, side docks, vertical mixer, multiview) goes in once per
  version of obs-layout.ini: user.ini remembers which one it got (ChurchLayout), so changes made in OBS survive
  a re-run until the repo's layout changes. Also turns off OBS's popup about closing a dock. Close OBS first: it
  writes its own layout when it exits.

.PARAMETER ObsDir OBS's config folder. Default: %APPDATA%\obs-studio.
#>
param(
    [string]$ObsDir = (Join-Path $env:APPDATA 'obs-studio')
)
$ErrorActionPreference = 'Stop'

# The layout's key=value lines, from its [BasicWindow] section, in file order.
$layout = New-Object System.Collections.Specialized.OrderedDictionary
$inSection = $false
foreach ($l in Get-Content (Join-Path $PSScriptRoot '..\obs-configuration\obs-layout.ini')) {
    if ($l -match '^\s*\[(.+)\]\s*$') { $inSection = ($Matches[1] -eq 'BasicWindow') }
    elseif ($inSection -and $l -match '^([^;=\s][^=]*)=(.*)$') { $layout[$Matches[1]] = $Matches[2] }
}
# Which layout this is: the same in set-obs-docks.py (key=value lines in file order, each ending in \n).
$text = (@($layout.Keys | ForEach-Object { "$_=$($layout[$_])`n" }) -join '')
$sha = [Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
$version = (-join ($sha | ForEach-Object { $_.ToString('x2') })).Substring(0, 12)

$userIni = Join-Path $ObsDir 'user.ini'
$lines = if (Test-Path $userIni) { @([IO.File]::ReadAllLines($userIni)) } else { @() }

# What to set in each section. Studio mode: OBS saves it on exit, so it is only the starting state.
$set = @{
    'General'     = [ordered]@{ WarnedAboutClosingDocks = 'true' }
    'BasicWindow' = [ordered]@{ PreviewProgramMode = 'true' }
}
$current = $lines | Where-Object { $_ -like 'ChurchLayout=*' } | Select-Object -First 1
if ($current -eq "ChurchLayout=$version") {
    $message = '    The OBS layout is already this version; leaving it alone (studio mode on).'
} else {
    foreach ($k in $layout.Keys) { $set['BasicWindow'][$k] = $layout[$k] }
    $set['BasicWindow']['ChurchLayout'] = $version
    $message = "    OBS layout (PTZ Controls docked, studio mode on) installed in $userIni"
}

# Rewrite user.ini: drop the keys being set from their sections, then add them at the top of each section.
$out = New-Object System.Collections.Generic.List[string]
$sectionName = $null
$seen = @{}
foreach ($l in $lines) {
    if ($l -match '^\s*\[(.+)\]\s*$') {
        $sectionName = $Matches[1]
        $out.Add($l)
        if ($set.Contains($sectionName)) {
            $seen[$sectionName] = $true
            foreach ($k in $set[$sectionName].Keys) { $out.Add("$k=$($set[$sectionName][$k])") }
        }
    } elseif ($sectionName -and $set.Contains($sectionName) -and $l -match '^([^=]+)=' -and $set[$sectionName].Contains($Matches[1])) {
        # replaced above
    } else {
        $out.Add($l)
    }
}
foreach ($name in $set.Keys) {
    if (-not $seen[$name]) {
        $out.Add("[$name]")
        foreach ($k in $set[$name].Keys) { $out.Add("$k=$($set[$name][$k])") }
    }
}
New-Item -ItemType Directory -Force $ObsDir | Out-Null
[IO.File]::WriteAllLines($userIni, $out.ToArray(), (New-Object System.Text.UTF8Encoding $false))
Write-Host $message
