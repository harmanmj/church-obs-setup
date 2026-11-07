<#
.SYNOPSIS
  Test tools\add-obs-scene-collection.ps1 in a throwaway folder. Your real OBS settings are not touched.

.DESCRIPTION
  Run it from a normal PowerShell, not as administrator, with OBS closed:
    powershell -ExecutionPolicy Bypass -File .\tests\test-add-obs-scene-collection.ps1
  It needs OBS installed, and exits non-zero if a check fails.
#>
$ErrorActionPreference = 'Stop'

$tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\add-obs-scene-collection.ps1'
$failed = 0
function Check($what, $ok) {
    if ($ok) { Write-Host "  ok    $what" -ForegroundColor Green }
    else { Write-Host "  FAIL  $what" -ForegroundColor Red; $script:failed++ }
}
function Add-SceneCollection([string[]]$toolArgs) {
    $ErrorActionPreference = 'Continue'
    $script:out = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $tool @toolArgs -ObsDir $obs -MusicDir $music *>&1 | Out-String
    $script:code = $LASTEXITCODE
}

if (Get-Process obs64 -ErrorAction SilentlyContinue) { Write-Host 'Close OBS and run this again.' -ForegroundColor Red; exit 1 }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Check 'running without administrator' (-not $isAdmin)

$root = Join-Path $env:TEMP "add-obs-scene-collection-test-$PID"
$obs = Join-Path $root 'obs-studio'
$music = Join-Path $root 'sacrament'
$scenes = Join-Path $obs 'basic\scenes'
$ini = Join-Path $obs 'user.ini'
$stake = Join-Path $scenes 'stake-conference.json'
New-Item -ItemType Directory -Force $obs, $music | Out-Null
Set-Content $ini "[Basic]`r`nSceneCollection=Untouched`r`nSceneCollectionFile=untouched.json"
$iniBefore = (Get-FileHash $ini).Hash

$realDir = Join-Path $env:APPDATA 'obs-studio'
function Get-RealState { Get-ChildItem $realDir -Recurse -File -Include 'user.ini', '*.json*' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike '*\plugin_*' } | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" } }
$realBefore = (Get-RealState) -join "`n"

$fake = $null
try {
    Write-Host 'Adding a collection'
    Add-SceneCollection @('-Config', 'stake-conference')
    Check 'exit code 0' ($code -eq 0)
    Check 'the collection file is there' (Test-Path $stake)
    $text = [IO.File]::ReadAllText($stake, [Text.Encoding]::UTF8)
    Check 'it is valid JSON named Stake Conference' (($text | ConvertFrom-Json).name -eq 'Stake Conference')
    Check 'no placeholders are left' ($text -notmatch '@HOME@|@AUDIO_DEVICE@')
    Check 'the audio source is a Windows one' ($text -match 'wasapi_input_capture' -and $text -notmatch 'pulse_input_capture')
    Check 'it points at the music folder' ($text.Contains(($music -replace '\\', '/') + '/sacrament-playlist.mp3'))
    Check 'the Linux font is replaced' (-not $text.Contains('DejaVu Serif'))
    Check 'it warns about the missing graphic' ($out -match 'sacrament-graphic\.png is not in')
    Check 'it warns about the missing playlist' ($out -match 'sacrament-playlist\.mp3 is not in')
    Check 'the active collection is unchanged' ((Get-FileHash $ini).Hash -eq $iniBefore)

    Write-Host 'Adding a second collection'
    New-Item -ItemType File (Join-Path $music 'sacrament-graphic.png'), (Join-Path $music 'sacrament-playlist.mp3') | Out-Null
    Add-SceneCollection @('-Config', 'dual-camera')
    Check 'exit code 0' ($code -eq 0)
    Check 'both collections are there' ((Test-Path $stake) -and (Test-Path (Join-Path $scenes 'dual-camera.json')))
    Check 'no sacrament warning once the files exist' ($out -notmatch 'is not in')

    Write-Host 'Adding it again keeps changes made in OBS'
    [IO.File]::WriteAllText($stake, '{"name":"Changed in OBS"}')
    Add-SceneCollection @('-Config', 'stake-conference')
    Check 'exit code 0' ($code -eq 0)
    Check 'it says nothing changed' ($out -match 'nothing changed')
    Check 'the file is left alone' ([IO.File]::ReadAllText($stake) -eq '{"name":"Changed in OBS"}')
    Check 'no backup was made' (-not (Get-ChildItem $scenes -Filter 'stake-conference.json.*.bak'))

    Write-Host '-Force replaces it and keeps a backup'
    Add-SceneCollection @('-Config', 'stake-conference', '-Force')
    Check 'exit code 0' ($code -eq 0)
    Check 'the file is replaced' ([IO.File]::ReadAllText($stake, [Text.Encoding]::UTF8) -match 'wasapi_input_capture')
    $bak = @(Get-ChildItem $scenes -Filter 'stake-conference.json.*.bak')
    Check 'the old one is the backup' ($bak.Count -eq 1 -and [IO.File]::ReadAllText($bak[0].FullName) -eq '{"name":"Changed in OBS"}')

    Write-Host 'Things it should refuse'
    Add-SceneCollection @('-Config', 'no-such-collection')
    Check 'an unknown name fails' ($code -ne 0 -and $out -match 'No such configuration')

    $real = $obs; $obs = Join-Path $root 'never-set-up'
    Add-SceneCollection @('-Config', 'single-camera')
    Check 'an account without OBS settings fails' ($code -ne 0 -and $out -match 'not set up' -and -not (Test-Path $obs))
    $obs = $real

    # A copy of ping named obs64.exe looks like OBS to the script
    $fakeExe = Join-Path $root 'obs64.exe'
    Copy-Item (Join-Path $env:SystemRoot 'System32\PING.EXE') $fakeExe
    $fake = Start-Process $fakeExe -ArgumentList '-n', '60', '127.0.0.1' -WindowStyle Hidden -PassThru
    Add-SceneCollection @('-Config', 'single-camera')
    Check 'it fails while OBS is running' ($code -ne 0 -and $out -match 'OBS is running')
    Check 'and writes nothing' (-not (Test-Path (Join-Path $scenes 'single-camera.json')))

    Write-Host 'Your real OBS settings'
    Check 'nothing changed in %APPDATA%\obs-studio' (((Get-RealState) -join "`n") -eq $realBefore)
} finally {
    if ($fake) { Stop-Process -Id $fake.Id -Force -ErrorAction SilentlyContinue; $fake.WaitForExit() }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed) { Write-Host "$failed check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host 'All checks passed.' -ForegroundColor Green
