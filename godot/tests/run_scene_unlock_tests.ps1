# Recovered scenery-unlock gating - full test + screenshot runner.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File godot\tests\run_scene_unlock_tests.ps1
#   powershell ... -File godot\tests\run_scene_unlock_tests.ps1 -SkipShots
#
# Steps:
#   1. build the progress-save / unlock-table fixtures (outside Godot)
#   2. headless gate validation (rows, save states, text menu, dock, fail closed)
#   3. existing scene-select suite (145 checks) as the ungated regression
#   4. windowed captures: no-save locked cards, mixed partial save, full save,
#      text menu locked/full, plus the baseline 01-07 shots
#   5. pixel checks on 01-07 (existing verifier)
#   6. pixel + report checks on 08-14 (unlock verifier)
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
New-Item -ItemType Directory -Force $fixtures | Out-Null

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
    $staged = Join-Path $root "run\staging\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path $staged) {
        $Godot = $staged
    } else {
        $Godot = Join-Path $env:LOCALAPPDATA "BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe"
    }
}
if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }
if (-not $SkipShots) {
    foreach ($pair in @(@("player GLB", $PlayerGlb), @("opponent GLB", $OpponentGlb))) {
        if (-not (Test-Path -LiteralPath $pair[1])) {
            throw ("capture asset missing: " + $pair[0] + " -> " + $pair[1])
        }
    }
}

$failures = @()

# ---------------------------------------------------------------- step 1
Write-Host "=== step 1: scenery-unlock fixtures ==="
$code = Invoke-Native $Python @("-X", "utf8",
    (Join-Path $root "tools\make_scene_unlock_fixtures.py"), "--out", $fixtures) `
    (Join-Path $logs "make_scene_unlock_fixtures.log")
Write-Host "exit=$code"
if ($code -ne 0) { $failures += "unlock fixtures (exit $code)" }

# ---------------------------------------------------------------- step 2
Write-Host "=== step 2: headless gate validation ==="
$unlockLog = Join-Path $logs "validate_scene_unlock.log"
$code = Invoke-Native $Godot @("--headless", "--path", $project,
    "--script", "res://tests/validate_scene_unlock.gd", "--quit-after", "60000",
    "--", $fixtures) $unlockLog
Write-Host "exit=$code"
Get-Content $unlockLog | Select-String -Pattern "SCENE_UNLOCK_VALIDATION_RESULT"
if ($code -ne 0) { $failures += "unlock gate validation (exit $code)" }
if (-not (Get-Content $unlockLog | Select-String -Pattern "SCENE_UNLOCK_VALIDATION_RESULT=PASS")) {
    $failures += "unlock gate validation result line"
}

# ---------------------------------------------------------------- step 3
Write-Host "=== step 3: ungated scene-select regression (145 checks) ==="
$regressionLog = Join-Path $logs "scene_select_regression.log"
$previous = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& powershell -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $root "godot\tests\run_scene_select_tests.ps1") -SkipShots -Godot $Godot `
    -PlayerGlb $PlayerGlb -OpponentGlb $OpponentGlb -Python $Python *> $regressionLog
$code = $LASTEXITCODE
$ErrorActionPreference = $previous
Write-Host "exit=$code"
Get-Content $regressionLog | Select-String -Pattern "SCENE_SELECT_TESTS="
if ($code -ne 0) { $failures += "scene-select regression (exit $code)" }

if (-not $SkipShots) {
    # ------------------------------------------------------------ step 4
    Write-Host "=== step 4: windowed captures (baseline + unlock states) ==="
    $captureLog = Join-Path $logs "capture_scene_select.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\run_scene_select_capture.py"), "--out", $shots,
        "--player", $PlayerGlb, "--opponent", $OpponentGlb, "--godot", $Godot) $captureLog
    Write-Host "exit=$code"
    Get-Content $captureLog | Select-String -Pattern "^RESULT="
    if ($code -ne 0) { $failures += "captures (exit $code)" }

    # ------------------------------------------------------------ step 5
    Write-Host "=== step 5: baseline pixel checks (01-07) ==="
    $pixelLog = Join-Path $logs "verify_scene_select_capture.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\verify_scene_select_capture.py"), "--shots", $shots) $pixelLog
    Write-Host "exit=$code"
    Get-Content $pixelLog | Select-String -Pattern "SCENE_SELECT_PIXELS"
    if ($code -ne 0) { $failures += "baseline pixel checks (exit $code)" }

    # ------------------------------------------------------------ step 6
    Write-Host "=== step 6: unlock pixel + report checks (08-14) ==="
    $unlockPixelLog = Join-Path $logs "verify_scene_unlock_capture.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\verify_scene_unlock_capture.py"), "--shots", $shots) $unlockPixelLog
    Write-Host "exit=$code"
    Get-Content $unlockPixelLog | Select-String -Pattern "SCENE_UNLOCK_PIXELS"
    if ($code -ne 0) { $failures += "unlock pixel checks (exit $code)" }
}

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "SCENE_UNLOCK_TESTS=PASS"
    exit 0
}
Write-Host ("SCENE_UNLOCK_TESTS=FAIL: " + ($failures -join "; "))
exit 1
