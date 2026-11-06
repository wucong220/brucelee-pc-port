# Scene-select recovery - full test + screenshot runner.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File godot\tests\run_scene_select_tests.ps1
#   powershell ... -File godot\tests\run_scene_select_tests.ps1 -SkipShots
#
# Steps:
#   1. rebuild the fail-closed fixtures (broken layout copy + empty icon dir)
#   2. headless validation: dock rows/order/icons/labels, navigation, clamping,
#      fail-closed cases, and a real scene switch that starts a running match
#   3. windowed captures (dock x3, match start, fail-closed fallback, flag-off
#      text rows, Chinese labels)
#   4. pixel checks on every screenshot
# Exit 0 only when every step is OK.

param(
    [switch]$SkipShots,
    [string]$Godot = "",
    [string]$PlayerGlb = "D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb",
    [string]$OpponentGlb = "D:\BruceLeeWork\brick-full-20261103\candidate\brick_full_94_20261103.glb",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$project = Join-Path $root "godot"
$logs = Join-Path $root "logs"
$shots = Join-Path $root "screenshots"
$fixtures = Join-Path $root "evidence\fixtures"
New-Item -ItemType Directory -Force $logs | Out-Null
New-Item -ItemType Directory -Force $shots | Out-Null

# Native tools write warnings to stderr; with ErrorActionPreference=Stop PowerShell
# would turn the first one into a terminating NativeCommandError, so run them under
# Continue and judge them by their exit code only.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments, [string]$LogPath)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Exe @Arguments *> $LogPath
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    return $code
}

if ([string]::IsNullOrEmpty($Godot)) {
    # The staged engine keeps the package's `scene/` assets beside the binary, so
    # the match screenshot shows the recovered arena.  Fall back to the portable
    # engine (no scene assets) when the staging copy is absent.
    $staged = Join-Path $root "run\staging\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path $staged) {
        $Godot = $staged
    } else {
        $Godot = Join-Path $env:LOCALAPPDATA "BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe"
    }
}
if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }
foreach ($pair in @(@("player GLB", $PlayerGlb), @("opponent GLB", $OpponentGlb))) {
    if (-not (Test-Path -LiteralPath $pair[1])) {
        throw ("capture asset missing: " + $pair[0] + " -> " + $pair[1])
    }
}

$failures = @()

# ---------------------------------------------------------------- step 1
Write-Host "=== step 1: fail-closed fixtures ==="
$code = Invoke-Native $Python @("-X", "utf8",
    (Join-Path $root "tools\make_scene_select_fixtures.py"), "--out", $fixtures) `
    (Join-Path $logs "make_fixtures.log")
Write-Host "exit=$code"
if ($code -ne 0) { $failures += "fixtures (exit $code)" }

# ---------------------------------------------------------------- step 2
Write-Host "=== step 2: headless validation ==="
$validationLog = Join-Path $logs "validate_scene_select.log"
$code = Invoke-Native $Godot @("--headless", "--path", $project,
    "--script", "res://tests/validate_scene_select.gd", "--quit-after", "60000",
    "--", $PlayerGlb, $OpponentGlb, $fixtures) $validationLog
Write-Host "exit=$code"
Get-Content $validationLog | Select-String -Pattern "SCENE_SELECT_VALIDATION_RESULT"
if ($code -ne 0) { $failures += "headless validation (exit $code)" }
if (-not (Get-Content $validationLog | Select-String -Pattern "SCENE_SELECT_VALIDATION_RESULT=PASS")) {
    $failures += "headless validation result line"
}

if (-not $SkipShots) {
    # ------------------------------------------------------------ step 3
    Write-Host "=== step 3: windowed captures ==="
    $captureLog = Join-Path $logs "capture_scene_select.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\run_scene_select_capture.py"), "--out", $shots,
        "--player", $PlayerGlb, "--opponent", $OpponentGlb, "--godot", $Godot) $captureLog
    Write-Host "exit=$code"
    Get-Content $captureLog | Select-String -Pattern "^RESULT="
    if ($code -ne 0) { $failures += "captures (exit $code)" }

    # ------------------------------------------------------------ step 4
    Write-Host "=== step 4: pixel checks ==="
    $pixelLog = Join-Path $logs "verify_scene_select_capture.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\verify_scene_select_capture.py"), "--shots", $shots) $pixelLog
    Write-Host "exit=$code"
    Get-Content $pixelLog | Select-String -Pattern "SCENE_SELECT_PIXELS"
    if ($code -ne 0) { $failures += "pixel checks (exit $code)" }
}

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "SCENE_SELECT_TESTS=PASS"
    exit 0
}
Write-Host ("SCENE_SELECT_TESTS=FAIL: " + ($failures -join "; "))
exit 1
