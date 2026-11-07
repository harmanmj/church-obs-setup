<#
.SYNOPSIS
  Test tools\add-obs-scene-collection.ps1 and update-obs-scene-collections.ps1 in a throwaway folder.
  Your real OBS settings are not touched.

.DESCRIPTION
  Run it from a normal PowerShell, not as administrator, with OBS closed:
    powershell -ExecutionPolicy Bypass -File .\tests\test-obs-scene-collections.ps1
  It needs OBS installed, and exits non-zero if a check fails.
#>
$ErrorActionPreference = 'Stop'

$tool = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\add-obs-scene-collection.ps1'
$updateTool = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\update-obs-scene-collections.ps1'
$failed = 0
function Check($what, $ok) {
    if ($ok) { Write-Host "  ok    $what" -ForegroundColor Green }
    else { Write-Host "  FAIL  $what" -ForegroundColor Red; $script:failed++ }
}
function Add-SceneCollection([string[]]$toolArgs) {
    $ErrorActionPreference = 'Continue'
    $script:out = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $tool -NoPull @toolArgs -ObsDir $obs -MusicDir $music *>&1 | Out-String
    $script:code = $LASTEXITCODE
}

function Add-FromMenu($answer) {
    $ErrorActionPreference = 'Continue'
    $script:out = $answer | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tool -NoPull -ObsDir $obs -MusicDir $music *>&1 | Out-String
    $script:code = $LASTEXITCODE
}
function Invoke-Git {
    $ErrorActionPreference = 'Continue'
    & git @args *>$null
}
function Add-FromCheckout([string[]]$toolArgs) {
    $ErrorActionPreference = 'Continue'
    $script:out = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $checkout 'tools\add-obs-scene-collection.ps1') @toolArgs -ObsDir $obs -MusicDir $music *>&1 | Out-String
    $script:code = $LASTEXITCODE
}
function Update-FromCheckout([string[]]$toolArgs) {
    $ErrorActionPreference = 'Continue'
    $script:out = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $checkout 'tools\update-obs-scene-collections.ps1') @toolArgs -ObsDir $obs -MusicDir $music *>&1 | Out-String
    $script:code = $LASTEXITCODE
}
function Update-SceneCollections {
    $ErrorActionPreference = 'Continue'
    $script:out = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $updateTool -NoPull -ObsDir $obs -MusicDir $music *>&1 | Out-String
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

    Write-Host 'The menu reads what OBS already has'
    $dual = Join-Path $scenes 'dual-camera.json'
    $made = Join-Path $scenes 'made-in-obs.json'
    $renamed = Join-Path $scenes 'Single_Camera.json'
    Remove-Item $dual
    [IO.File]::WriteAllText($made, '{"name":"Made in OBS"}')
    [IO.File]::WriteAllText($renamed, '{"name":"Single Camera"}')
    Add-FromMenu '0'
    Check 'exit code 0' ($code -eq 0)
    Check 'it lists what is in OBS' ($out -match 'Already in OBS:.*Made in OBS')
    Check 'it offers what is missing' ($out -match '\d\) Dual Camera')
    Check 'it does not offer what is there' ($out -notmatch '\d\) Stake Conference')
    Check 'it knows a collection by name, whatever the file' ($out -notmatch '(?m)\d\) Single Camera\s*$')
    Check '0 cancels' (-not (Test-Path $dual))
    Add-FromMenu '1'
    Check 'a number adds that collection' ((Test-Path $dual) -and $out -match "Installed the 'dual-camera'")

    Write-Host 'Updating replaces what OBS has from this repo'
    [IO.File]::WriteAllText($stake, '{"name":"Stake Conference","edited":true}')
    [IO.File]::WriteAllText($dual, '{"name":"Dual Camera","edited":true}')
    Update-SceneCollections
    Check 'exit code 0' ($code -eq 0)
    Check 'the first is replaced' ([IO.File]::ReadAllText($stake, [Text.Encoding]::UTF8) -match 'wasapi_input_capture')
    Check 'the second is replaced' ([IO.File]::ReadAllText($dual, [Text.Encoding]::UTF8) -match 'wasapi_input_capture')
    Check 'each old file is kept' (@(Get-ChildItem $scenes -Filter '*.bak' | Where-Object { [IO.File]::ReadAllText($_.FullName) -match '"edited":true' }).Count -eq 2)
    Check 'collections made in OBS are left alone' ([IO.File]::ReadAllText($made) -eq '{"name":"Made in OBS"}' -and [IO.File]::ReadAllText($renamed) -eq '{"name":"Single Camera"}')
    Check 'and it says so' ($out -match 'Left alone.*Made in OBS')
    Check 'nothing new is added' (-not (Test-Path (Join-Path $scenes 'single-camera.json')))
    Check 'the active collection is unchanged' ((Get-FileHash $ini).Hash -eq $iniBefore)

    Write-Host 'When everything is there'
    Remove-Item $made, $renamed
    foreach ($c in Get-ChildItem (Join-Path (Split-Path -Parent $PSScriptRoot) 'configs') -Directory) { Add-SceneCollection @('-Config', $c.Name) }
    Add-SceneCollection @()
    Check 'the menu says so instead of asking' ($code -eq 0 -and $out -match 'already in OBS')
    Get-ChildItem $scenes -Filter '*.json' | Where-Object { $_.Name -notin 'stake-conference.json', 'dual-camera.json' } | Remove-Item

    Write-Host 'Adding several at once'
    $single = Join-Path $scenes 'single-camera.json'
    Remove-Item $dual, $stake
    Add-FromMenu '1 2'
    Check 'two numbers add both' ($code -eq 0 -and (Test-Path $dual) -and (Test-Path $single) -and -not (Test-Path $stake))
    Check 'it picks the audio input once' (([regex]::Matches($out, 'Audio input for OBS')).Count -eq 1)
    Remove-Item $dual, $single
    Add-FromMenu '1,1, 2'
    Check 'commas and repeats work' ($code -eq 0 -and (Test-Path $dual) -and (Test-Path $single) -and ([regex]::Matches($out, "Installed the 'dual-camera'")).Count -eq 1)
    Remove-Item $dual, $single
    Add-FromMenu @('1 99', '0 1', '0')
    Check 'a bad number in the list adds nothing' ($code -eq 0 -and -not (Test-Path $dual) -and -not (Test-Path $single))
    Add-SceneCollection @('-Config', 'dual-camera,no-such-collection')
    Check 'a mistyped name adds nothing' ($code -ne 0 -and $out -match 'No such configuration: no-such-collection' -and -not (Test-Path $dual))
    Add-SceneCollection @('-Config', 'dual-camera,stake-conference')
    Check '-Config takes several' ($code -eq 0 -and (Test-Path $dual) -and (Test-Path $stake))
    [IO.File]::WriteAllText($dual, '{"name":"Dual Camera","edited":true}')
    Add-SceneCollection @('-Config', 'dual-camera,single-camera')
    Check 'a list adds what is missing and keeps what is there' ($code -eq 0 -and (Test-Path $single) -and [IO.File]::ReadAllText($dual) -match '"edited":true' -and $out -match "'dual-camera' scene collection is already there")
    Remove-Item $single
    Add-SceneCollection @('-Config', 'dual-camera,stake-conference', '-Force')
    Check '-Force replaces every one in the list' ($code -eq 0 -and [IO.File]::ReadAllText($dual, [Text.Encoding]::UTF8) -match 'wasapi_input_capture')

    Write-Host 'Choosing the active collection after adding'
    $iniBytes = [IO.File]::ReadAllBytes($ini)
    Remove-Item $dual
    Add-FromMenu @('1', '0')
    Check 'it lists what is in OBS' ($out -match '\d\) Stake Conference' -and $out -match 'keep the current one')
    Check '0 keeps the active collection' ((Get-FileHash $ini).Hash -eq $iniBefore)
    Remove-Item $dual
    Add-FromMenu @('1', '1')
    Check 'a number makes that one active' ([IO.File]::ReadAllText($ini) -match 'SceneCollection=Dual Camera' -and [IO.File]::ReadAllText($ini) -match 'SceneCollectionFile=dual-camera.json')
    Remove-Item $dual
    Add-FromMenu @('1', '0')
    Check 'it marks the active one' ($out -match 'Dual Camera \(active now\)')
    [IO.File]::WriteAllBytes($ini, $iniBytes)
    Remove-Item $dual
    Add-FromMenu @('1 2', '99', '3')
    Check 'it also asks after adding several, and a bad number asks again' ([IO.File]::ReadAllText($ini) -match 'SceneCollection=Stake Conference')
    [IO.File]::WriteAllBytes($ini, $iniBytes)
    Remove-Item $dual, $single
    Add-SceneCollection @('-Config', 'dual-camera')
    Check '-Config does not ask' ($code -eq 0 -and $out -notmatch 'keep the current one' -and (Get-FileHash $ini).Hash -eq $iniBefore)

    $real = $obs; $obs = Join-Path $root 'no-collections'
    New-Item -ItemType Directory -Force $obs | Out-Null
    Copy-Item $ini $obs
    Update-SceneCollections
    Check 'updating with none from this repo changes nothing' ($code -eq 0 -and $out -match 'nothing changed' -and -not (Test-Path (Join-Path $obs 'basic')))
    $obs = $real

    Write-Host 'Updating gets the latest first, from a stand-in for GitHub'
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $origin = Join-Path $root 'origin.git'
    $work = Join-Path $root 'work'
    $checkout = Join-Path $root 'checkout'
    Invoke-Git init --bare $origin
    Invoke-Git clone $origin $work
    Copy-Item (Join-Path $repoRoot 'tools') $work -Recurse
    New-Item -ItemType Directory (Join-Path $work 'configs') | Out-Null
    Copy-Item (Join-Path $repoRoot 'configs\dual-camera') (Join-Path $work 'configs') -Recurse
    Invoke-Git -C $work add -A
    Invoke-Git -C $work -c user.name=test -c user.email=test@example.com commit -m first
    Invoke-Git -C $work push origin HEAD
    Invoke-Git clone $origin $checkout
    $workDual = Join-Path $work 'configs\dual-camera\dual-camera.json'
    [IO.File]::WriteAllText($workDual, [IO.File]::ReadAllText($workDual).Replace('"name": "Dual Camera"', '"name": "Dual Camera Pulled"'))
    Invoke-Git -C $work -c user.name=test -c user.email=test@example.com commit -am second
    Invoke-Git -C $work push origin HEAD

    Update-FromCheckout @()
    Check 'exit code 0' ($code -eq 0)
    Check 'it says which version it is at' ($out -match 'At [0-9a-f]+ second')
    Check 'OBS gets the newer collection' ([IO.File]::ReadAllText($dual, [Text.Encoding]::UTF8).Contains('Dual Camera Pulled'))

    New-Item -ItemType Directory (Join-Path $work 'configs\brand-new') | Out-Null
    [IO.File]::WriteAllText((Join-Path $work 'configs\brand-new\brand-new.json'), '{"name":"Brand New"}')
    Invoke-Git -C $work add -A
    Invoke-Git -C $work -c user.name=test -c user.email=test@example.com commit -m third
    Invoke-Git -C $work push origin HEAD
    Add-FromCheckout @('-Config', 'brand-new')
    Check 'adding gets a collection that is only on GitHub' ($code -eq 0 -and (Test-Path (Join-Path $scenes 'brand-new.json')))
    Check 'and says which version it is at' ($out -match 'At [0-9a-f]+ third')
    Remove-Item (Join-Path $scenes 'brand-new.json')

    Invoke-Git -C $checkout remote set-url origin (Join-Path $root 'gone.git')
    Add-FromCheckout @('-Config', 'brand-new')
    Check 'adding still works if GitHub cannot be reached' ($code -eq 0 -and (Test-Path (Join-Path $scenes 'brand-new.json')))
    Check 'and warns about it' ($out -match 'Could not get the latest scene collections')
    Remove-Item (Join-Path $scenes 'brand-new.json')

    [IO.File]::WriteAllText($dual, '{"name":"Dual Camera","edited":true}')
    Update-FromCheckout @()
    Check 'it fails if GitHub cannot be reached' ($code -ne 0 -and $out -match 'nothing changed')
    Check 'and leaves the collection alone' ([IO.File]::ReadAllText($dual) -eq '{"name":"Dual Camera","edited":true}')
    Update-FromCheckout @('-NoPull')
    Check '-NoPull works without GitHub' ($code -eq 0 -and [IO.File]::ReadAllText($dual, [Text.Encoding]::UTF8).Contains('Dual Camera Pulled'))

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
    Update-SceneCollections
    Check 'updating fails while OBS is running' ($code -ne 0 -and $out -match 'OBS is running')

    Write-Host 'Your real OBS settings'
    Check 'nothing changed in %APPDATA%\obs-studio' (((Get-RealState) -join "`n") -eq $realBefore)
} finally {
    if ($fake) { Stop-Process -Id $fake.Id -Force -ErrorAction SilentlyContinue; $fake.WaitForExit() }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed) { Write-Host "$failed check(s) failed." -ForegroundColor Red; exit 1 }
Write-Host 'All checks passed.' -ForegroundColor Green
