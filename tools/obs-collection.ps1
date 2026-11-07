<#
.SYNOPSIS
  Pick the audio input and install a scene collection. Needs no administrator rights.
  Dot-sourced by setup-obs-windows.ps1 and tools\add-obs-scene-collection.ps1. (Windows twin of obs-collection.sh.)
#>

# Windows lists audio devices ("endpoints") under MMDevices. An endpoint's id, as OBS stores it, is
# {0.0.1.00000000}.{guid} for an input and {0.0.0.00000000}.{guid} for an output.
$MMDev = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio'
function Get-AudioEndpoints($kind) {   # 'Capture' (inputs) or 'Render' (outputs)
    $prefix = if ($kind -eq 'Capture') { '{0.0.1.00000000}.' } else { '{0.0.0.00000000}.' }
    foreach ($k in Get-ChildItem (Join-Path $MMDev $kind) -ErrorAction SilentlyContinue) {
        $state = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DeviceState
        if ($state -ne 1) { continue }   # 1 = active (present and enabled)
        $props = Get-ItemProperty (Join-Path $k.PSPath 'Properties') -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        $desc = $props.'{a45c254e-df1c-4efd-8020-67d146a850e0},2'    # e.g. "Microphone", "CABLE Input"
        $iface = $props.'{b3f8fa53-0004-438e-9003-51a46e139bfc},6'   # e.g. "Sound Blaster Play! 3"
        [pscustomobject]@{ Id = $prefix + $k.PSChildName; Name = "$desc ($iface)"; Description = $desc }
    }
}

# The microphone: the "USB Audio" source is a PulseAudio input in the repo; on Windows it is a WASAPI input.
# Returns the device id to put in the scene collection.
function Select-AudioInput($AudioDevice) {
    $inputs = @(Get-AudioEndpoints 'Capture' | Where-Object { $_.Description -notlike 'CABLE Output*' })
    $pick = $null
    if ($AudioDevice) {
        $pick = $inputs | Where-Object { $_.Id -eq $AudioDevice -or $_.Name -like "*$AudioDevice*" } | Select-Object -First 1
        if (-not $pick) { Write-Warning "No input matches '$AudioDevice'; using the Windows default input." }
    } else {
        # NDI Tools adds virtual "NDI Webcam Audio" inputs; their sound is poor, so never pick one by default.
        $real = @($inputs | Where-Object { $_.Name -notmatch 'NDI' })
        $pick = $real | Where-Object Name -match 'Sound Blaster' | Select-Object -First 1
        if (-not $pick) { $pick = $real | Where-Object Name -match 'USB' | Select-Object -First 1 }
        if (-not $pick) {
            Write-Warning 'No Sound Blaster or USB audio input is plugged in. Plug it in and run this again, or pass -AudioDevice.'
            # Else any real input, by id: "default" could be CABLE Output or NDI audio.
            $pick = $real | Select-Object -First 1
        }
    }
    $deviceId = if ($pick) { $pick.Id } else { 'default' }
    $deviceName = if ($pick) { $pick.Name } else { 'the Windows default input' }
    Write-Host "    Audio input for OBS: $deviceName (change it on the 'USB Audio' source in OBS if this is wrong)"
    return $deviceId
}

# Copy the collection in $src into OBS's scenes folder, made to suit this computer. An existing file is kept as *.bak.
function Install-Collection($src, $scenes, $musicDir, $deviceId) {
    $utf8 = New-Object System.Text.UTF8Encoding $false
    New-Item -ItemType Directory -Force $scenes | Out-Null
    # OBS accepts forward slashes in paths, and they need no JSON escaping
    $sacramentFwd = $musicDir -replace '\\', '/'
    foreach ($f in Get-ChildItem $src -Filter *.json) {
        $dest = Join-Path $scenes $f.Name
        if (Test-Path $dest) { Copy-Item $dest "$dest.$(Get-Date -Format yyyyMMdd-HHmmss).bak" }
        $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
        # Documents may be redirected to OneDrive here; the DejaVu Serif font is Linux-only, so use Georgia
        $text = $text.Replace('@HOME@/Documents/sacrament', $sacramentFwd).Replace('DejaVu Serif', 'Georgia')
        $text = $text.Replace('"id": "pulse_input_capture"', '"id": "wasapi_input_capture"')
        $text = $text.Replace('"versioned_id": "pulse_input_capture"', '"versioned_id": "wasapi_input_capture"')
        $text = $text.Replace('@AUDIO_DEVICE@', $deviceId)
        [IO.File]::WriteAllText($dest, $text, $utf8)
    }
}
