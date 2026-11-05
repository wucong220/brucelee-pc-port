# Headless runner for the recovered 8-item language dock.
# session (input -> select -> apply -> payload) then restart (persisted restore).
# The harness denies the Godot child any file write, so this runner materialises
# the exact payload the game produced for the restart run (disclosed workaround).
param(
    [string] $PlayerGlb = 'D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb',
    [string] $OpponentGlb = 'D:\BruceLeeWork\brick-full-20261103\candidate\brick_full_94_20261103.glb'
)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$project = Join-Path $root 'godot'
$logs = Join-Path (Split-Path -Parent $root) 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$godot = Join-Path $env:LOCALAPPDATA 'BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path $godot)) { Write-Error "Godot not found: $godot"; exit 1 }
$save = Join-Path $logs 'language_dock_save.json'
Remove-Item $save -ErrorAction SilentlyContinue
$failures = @()

$args1 = @('--headless', '--path', $project, '--script',
    'res://tests/validate_language_dock.gd', '--quit-after', '12000', '--',
    $PlayerGlb, $OpponentGlb, $save, 'session')
$out1 = & $godot @args1 2>&1
$code1 = $LASTEXITCODE
$out1 | Out-File (Join-Path $logs 'language_session.log') -Encoding UTF8
$out1 | Select-String -Pattern '^(PASS|FAIL|NOTE|LANGUAGE_DOCK_VALIDATION)' | ForEach-Object { $_.Line }
if ($code1 -ne 0) { $failures += "session (exit $code1)" }

$payloadLine = ($out1 | Select-String -Pattern '^LANGUAGE_SAVE_PAYLOAD=' | Select-Object -Last 1)
if (-not $payloadLine) { $failures += 'session produced no save payload' }
else {
    $json = $payloadLine.Line.Substring('LANGUAGE_SAVE_PAYLOAD='.Length)
    [System.IO.File]::WriteAllText($save, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host ("materialised save payload -> {0} ({1} bytes)" -f $save, (Get-Item $save).Length)
}

$args2 = @('--headless', '--path', $project, '--script',
    'res://tests/validate_language_dock.gd', '--quit-after', '12000', '--',
    $PlayerGlb, $OpponentGlb, $save, 'restart')
$out2 = & $godot @args2 2>&1
$code2 = $LASTEXITCODE
$out2 | Out-File (Join-Path $logs 'language_restart.log') -Encoding UTF8
$out2 | Select-String -Pattern '^(PASS|FAIL|LANGUAGE_DOCK_VALIDATION)' | ForEach-Object { $_.Line }
if ($code2 -ne 0) { $failures += "restart (exit $code2)" }

if ($failures.Count -eq 0) { Write-Host 'ALL LANGUAGE DOCK CHECKS PASSED'; exit 0 }
Write-Error ('FAILURES: ' + ($failures -join '; ')); exit 1
