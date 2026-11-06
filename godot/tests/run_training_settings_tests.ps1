# Rebuild the recovered Training Settings artifact and validate it headless.
# Read-only against the shared repo/package; all writes stay in this output tree.
# Godot writes harmless headless-only warnings to stderr; keep them as data,
# not terminating PowerShell errors, and judge each step by $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$godotProject = Join-Path $root 'godot'
$godot = Join-Path $env:LOCALAPPDATA 'BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe'
$player  = 'D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb'
$opponent = 'D:\BruceLeeWork\brick-full-20261103\candidate\brick_full_94_20261103.glb'
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

Write-Host "== build training_settings.json =="
& py -3.12 -X utf8 -B (Join-Path $root 'tools\build_training_settings.py')
if ($LASTEXITCODE -ne 0) { throw "build_training_settings.py failed ($LASTEXITCODE)" }

foreach ($mode in @('normal', 'failclosed')) {
    Write-Host "== headless validate ($mode) =="
    $log = Join-Path $logs "validate_training_settings_$mode.log"
    & $godot --headless --path $godotProject `
        --script res://tests/validate_training_settings.gd `
        --quit-after 4000 -- $player $opponent $mode 2>&1 | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) { throw "validate_training_settings ($mode) failed ($LASTEXITCODE)" }
}

Write-Host "== headless validate_training_native (regression) =="
$log = Join-Path $logs 'validate_training_native.log'
& $godot --headless --path (Join-Path $root 'godot') `
    --script res://tests/validate_training_native.gd `
    --quit-after 6000 -- $player $opponent 2>&1 | Tee-Object -FilePath $log
if ($LASTEXITCODE -ne 0) { throw "validate_training_native failed ($LASTEXITCODE)" }

Write-Host "ALL TRAINING SETTINGS CHECKS PASSED"
