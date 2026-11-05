# Headless runner: recovered Profile sub-pages + About + VIDEO/CONTROLS proof.
# normal + fail-closed, plus the menu-art and language-dock regressions.
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
$failures = @()

function Run-Test([string] $script, [string[]] $extra, [string] $logName) {
    $log = Join-Path $logs $logName
    $a = @('--headless', '--path', $project, '--script', "res://tests/$script",
           '--quit-after', '12000', '--') + $extra
    $out = & $godot @a 2>&1
    $code = $LASTEXITCODE
    $out | Out-File -FilePath $log -Encoding UTF8
    $line = ($out | Select-String -Pattern 'VALIDATION=' | Select-Object -Last 1)
    Write-Host ("{0,-34} exit={1} {2}" -f $script, $code, $line)
    if ($code -ne 0) { $script:failures += "$script (exit $code)" }
}

$builder = Join-Path (Split-Path -Parent $root) 'tools\build_recovered_pages.py'
$b = & py -3.12 -X utf8 -B $builder 2>&1
$b | Out-File (Join-Path $logs 'build_recovered_pages.log') -Encoding UTF8
Write-Host ("build_recovered_pages.py exit={0}" -f $LASTEXITCODE)
if ($LASTEXITCODE -ne 0) { $failures += 'build_recovered_pages.py' }

Run-Test 'validate_recovered_pages.gd' @($PlayerGlb, $OpponentGlb, 'normal') 'recovered_pages_normal.log'
Run-Test 'validate_recovered_pages.gd' @($PlayerGlb, $OpponentGlb, 'failclosed') 'recovered_pages_failclosed.log'
Run-Test 'validate_menu_art_menu.gd' @($PlayerGlb, $OpponentGlb) 'reg_menu_art_menu.log'
Run-Test 'validate_menu_art_off.gd' @($PlayerGlb, $OpponentGlb) 'reg_menu_art_off.log'
Run-Test 'validate_training_settings.gd' @($PlayerGlb, $OpponentGlb, 'normal') 'reg_training_norm.log'

if ($failures.Count -eq 0) { Write-Host 'ALL RECOVERED PAGES CHECKS PASSED'; exit 0 }
Write-Error ('FAILURES: ' + ($failures -join '; ')); exit 1
