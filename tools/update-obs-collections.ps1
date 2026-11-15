<#
  Update just the OBS scene collections on this computer from this repo, the same way setup-obs-windows.ps1
  installs them, without running the rest of the setup (no software installs, no other OBS settings).
  The Ubuntu twin is tools/update-obs-collections.py.

    powershell -ExecutionPolicy Bypass -File .\tools\update-obs-collections.ps1 [-Default alkire-and-quail|independence-building]

  - Installs every collection in obs-scene-collections\ (from the branch that is checked out).
  - Each file it replaces is saved next to it as *.bak.
  - Keeps what was already picked in OBS, by source name: the "USB Audio" microphone, capture devices and
    NDI senders. A new "USB Audio" gets the input the setup script would pick (Sound Blaster, else USB, ...).
  - Asks which collection OBS opens on, like the setup script (1 alkire-and-quail, 2 independence-building);
    -Default answers up front. Run without a console to ask in, it leaves OBS's current one.
  Run it as the person who uses OBS (no administrator needed). Close OBS first.
#>
param([string]$Default, [string]$Repo = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
if (Get-Process obs64 -ErrorAction SilentlyContinue) { Write-Host 'Close OBS first, then run this again.' -ForegroundColor Red; exit 1 }
$configRoot = Join-Path $Repo 'obs-scene-collections'
if (-not (Test-Path $configRoot)) { Write-Host "No obs-scene-collections folder in $Repo" -ForegroundColor Red; exit 1 }
Write-Host "Scene collections from $configRoot"

# Which collection OBS opens on: the same menu, in the same order, as setup-obs-windows.ps1.
$found = @(Get-ChildItem $configRoot -Directory | ForEach-Object Name)
$configs = @(@('alkire-and-quail', 'independence-building') | Where-Object { $found -contains $_ }) +
           @($found | Where-Object { @('alkire-and-quail', 'independence-building') -notcontains $_ })
if ($Default) {
    if ($configs -notcontains $Default) { Write-Host "No collection named $Default (have: $($configs -join ', '))" -ForegroundColor Red; exit 1 }
} elseif ([Environment]::UserInteractive -and $configs.Count -gt 0) {
    Write-Host 'Which scene collection should OBS open on by default?'
    for ($i = 0; $i -lt $configs.Count; $i++) { Write-Host "  $($i + 1)) $($configs[$i])" }
    do { $n = Read-Host 'Number' } until ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $configs.Count)
    $Default = $configs[[int]$n - 1]
}

# The microphone, chosen the way setup-obs-windows.ps1 does it.
$MMDev = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture'
$inputs = foreach ($k in Get-ChildItem $MMDev -ErrorAction SilentlyContinue) {
    if ((Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DeviceState -ne 1) { continue }
    $p = Get-ItemProperty (Join-Path $k.PSPath 'Properties') -ErrorAction SilentlyContinue
    if (-not $p) { continue }
    $desc = $p.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
    [pscustomobject]@{ Id = '{0.0.1.00000000}.' + $k.PSChildName; Name = "$desc ($($p.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'))"; Description = $desc }
}
$real = @($inputs | Where-Object { $_.Description -notlike 'CABLE Output*' -and $_.Name -notmatch 'NDI' })
$pick = $real | Where-Object Name -match 'Sound Blaster' | Select-Object -First 1
if (-not $pick) { $pick = $real | Where-Object Name -match 'USB' | Select-Object -First 1 }
if (-not $pick) { $pick = $real | Select-Object -First 1 }
$deviceId = if ($pick) { $pick.Id } else { 'default' }

$ObsDir = Join-Path $env:APPDATA 'obs-studio'
$scenes = Join-Path $ObsDir 'basic\scenes'
New-Item -ItemType Directory -Force $scenes | Out-Null
$sacramentFwd = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'sacrament') -replace '\\', '/'
$utf8 = New-Object System.Text.UTF8Encoding $false

foreach ($f in $configs | ForEach-Object { Get-ChildItem (Join-Path $configRoot $_) -Filter *.json }) {
    $dest = Join-Path $scenes $f.Name
    $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $text = $text.Replace('@HOME@/Documents/sacrament', $sacramentFwd).Replace('DejaVu Serif', 'Georgia')
    $text = $text.Replace('"id": "pulse_input_capture"', '"id": "wasapi_input_capture"').Replace('"versioned_id": "pulse_input_capture"', '"versioned_id": "wasapi_input_capture"')
    $text = $text.Replace('"id": "v4l2_input"', '"id": "dshow_input"').Replace('"versioned_id": "v4l2_input"', '"versioned_id": "dshow_input"')

    # Keep what was picked in OBS: the microphone, capture devices and NDI senders, by source name.
    $mic = $deviceId; $kept = @()
    if (Test-Path $dest) {
        $old = [IO.File]::ReadAllText($dest, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($s in $old.sources) {
            $n = [regex]::Escape($s.name)
            if ($s.id -eq 'wasapi_input_capture' -and $s.name -eq 'USB Audio' -and $s.settings.device_id) { $mic = $s.settings.device_id; $kept += 'USB Audio' }
            if ($s.id -eq 'dshow_input' -and $s.settings.video_device_id) {
                $re = "(`"name`": `"$n`",[^{]*?`"settings`": \{[^}]*?)`"video_device_id`": `"`""
                $v = $s.settings.video_device_id.Replace('\', '\\')
                if ([regex]::IsMatch($text, $re)) { $text = [regex]::Replace($text, $re, { param($m) $m.Groups[1].Value + "`"video_device_id`": `"$v`"" }); $kept += $s.name }
            }
            if ($s.id -eq 'ndi_source' -and $s.settings.ndi_source_name) {
                $re = "(`"name`": `"$n`",[^{]*?`"settings`": \{[^}]*?)`"ndi_source_name`": `"[^`"]*`""
                $v = $s.settings.ndi_source_name
                if ([regex]::IsMatch($text, $re)) { $text = [regex]::Replace($text, $re, { param($m) $m.Groups[1].Value + "`"ndi_source_name`": `"$v`"" }); $kept += $s.name }
            }
        }
        Copy-Item $dest "$dest.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
    }
    $text = $text.Replace('@AUDIO_DEVICE@', $mic)
    $null = $text | ConvertFrom-Json   # stop before writing a broken file
    [IO.File]::WriteAllText($dest, $text, $utf8)
    Write-Host "Updated $($f.Name) ($(($text | ConvertFrom-Json).name))"
    if ($kept) { Write-Host "    kept from OBS: $($kept -join ', ')" }
}

if ($Default) {
    $c = Get-ChildItem (Join-Path $configRoot $Default) -Filter *.json | Select-Object -First 1
    $name = ([IO.File]::ReadAllText($c.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json).name
    $ini = Join-Path $ObsDir 'user.ini'
    $lines = [Collections.Generic.List[string]]@(if (Test-Path $ini) { [IO.File]::ReadAllLines($ini) })
    $lines = [Collections.Generic.List[string]]@($lines | Where-Object { $_ -notmatch '^SceneCollection(File)?=' })
    $basic = $lines.IndexOf('[Basic]')
    if ($basic -lt 0) { $lines.Add('[Basic]'); $basic = $lines.Count - 1 }
    $lines.Insert($basic + 1, "SceneCollectionFile=$($c.Name)")
    $lines.Insert($basic + 1, "SceneCollection=$name")
    [IO.File]::WriteAllLines($ini, $lines, $utf8)
    Write-Host "OBS will open on '$name'."
}
