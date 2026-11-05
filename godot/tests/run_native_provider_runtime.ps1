# Headless acceptance for the native progress provider integration.
# Runs save and restart in separate Godot processes (real main.tscn), plus the
# native-store smoke test and the existing progress regression suites.
param(
    [string] $GodotExe = 'D:\BruceLeeWork\result-audio-20261104\work\godot\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path (Split-Path -Parent $project) 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (-not (Test-Path $GodotExe)) { Write-Error "Godot not found: $GodotExe"; exit 1 }

$tests = @(
    @{ name = 'native_store'; script = 'res://tests/validate_native_provider_store.gd'; args = @() },
    @{ name = 'native_main_save'; script = 'res://tests/validate_native_provider_runtime.gd'; args = @('save') },
    @{ name = 'native_main_restart'; script = 'res://tests/validate_native_provider_runtime.gd'; args = @('restart') },
    @{ name = 'native_language_session'; script = 'res://tests/validate_native_settings.gd'; args = @('user://native_lang_reg_test.dat', 'session') },
    @{ name = 'native_language_restart'; script = 'res://tests/validate_native_settings.gd'; args = @('user://native_lang_reg_test.dat', 'restart') },
    @{ name = 'native_language_failclosed'; script = 'res://tests/validate_native_settings.gd'; args = @('user://native_lang_reg_test.dat', 'failclosed') },
    @{ name = 'progress_integration'; script = 'res://tests/validate_progress_integration.gd'; args = @() },
    @{ name = 'progress_main_hooks'; script = 'res://tests/validate_progress_main_hooks.gd'; args = @() },
    @{ name = 'progress_wiring'; script = 'res://tests/validate_progress_wiring.gd'; args = @() }
)

$failures = @()
foreach ($t in $tests) {
    $outFile = Join-Path $logDir ($t.name + '.log')
    $argv = @('--headless', '--path', $project, '--script', $t.script)
    if ($t.args.Count -gt 0) { $argv += '--'; $argv += $t.args }
    $out = & $GodotExe @argv 2>&1
    $code = $LASTEXITCODE
    $out | Out-File -LiteralPath $outFile -Encoding utf8
    $summary = $out | Select-String -Pattern '^(=== .*RESULT|PASS |FAIL |.*_OK )' | Select-Object -Last 1
    Write-Host ("{0}: exit {1} {2}" -f $t.name, $code, ($summary.Line -replace '^\s+', ''))
    if ($code -ne 0) { $failures += $t.name }
}
if ($failures.Count -gt 0) {
    Write-Error ('FAILED: ' + ($failures -join ', '))
    exit 1
}
Write-Host 'ALL NATIVE PROGRESS CHECKS PASSED'
exit 0
