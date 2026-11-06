# Recovered character-unlock gating - test runner.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File godot\tests\run_character_lock_tests.ps1
#   powershell ... -File godot\tests\run_character_lock_tests.ps1 -Shots
#
# Steps:
#   1. build the progress-save / unlock-table / story / menu-art fixtures
#   2. headless gate validation (rows, dock mapping, save states, text menu, dock, fail closed)
#   3. the existing HUD-art wiring regression, headless, with the character gate off
#   4. -Shots only: windowed captures + pixel/report checks
#
# Exit 0 only when every executed step is OK.
#
# `-Scratch` must be a directory the Godot process may write.  The DSH Windows
# sandbox only lets the Godot child write inside the DSH session workspace, so
# the headless progress-chain check (which writes one throw-away save through
# the real SaveManager) gets that path; the user's own progress save is never
# touched.  Default: <output>/work/scratch.

param(
    [switch]$Shots,
    [string]$Godot = "",
    [string]$Python = "python",
    [string]$Scratch = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$project = Join-Path $root "godot"
$logs = Join-Path $root "logs"
$shotsDir = Join-Path $root "screenshots"
$fixtures = Join-Path $root "evidence\fixtures"
if ([string]::IsNullOrEmpty($Scratch)) { $Scratch = Join-Path $root "work\scratch" }
New-Item -ItemType Directory -Force $logs, $shotsDir, $fixtures, $Scratch | Out-Null

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

$failures = @()

# ---------------------------------------------------------------- step 1
Write-Host "=== step 1: character-lock fixtures ==="
$code = Invoke-Native $Python @("-X", "utf8",
    (Join-Path $root "tools\make_character_lock_fixtures.py"), "--out", $fixtures) `
    (Join-Path $logs "make_character_lock_fixtures.log")
Write-Host "exit=$code"
if ($code -ne 0) { $failures += "character-lock fixtures (exit $code)" }

# ---------------------------------------------------------------- step 2
Write-Host "=== step 2: headless character-lock validation ==="
$savedTestPath = $env:CHARACTER_LOCK_TEST_SAVE
$env:CHARACTER_LOCK_TEST_SAVE = Join-Path $Scratch "progress_chain_save.json"
$unlockLog = Join-Path $logs "validate_character_locks.log"
$code = Invoke-Native $Godot @("--headless", "--path", $project,
    "--script", "res://tests/validate_character_locks.gd", "--quit-after", "60000",
    "--", $fixtures) $unlockLog
if ($null -eq $savedTestPath) { Remove-Item Env:\CHARACTER_LOCK_TEST_SAVE -ErrorAction SilentlyContinue }
else { $env:CHARACTER_LOCK_TEST_SAVE = $savedTestPath }
Write-Host "exit=$code"
Get-Content $unlockLog | Select-String -Pattern "CHARACTER_LOCK_VALIDATION_RESULT"
if ($code -ne 0) { $failures += "character-lock validation (exit $code)" }
if (-not (Get-Content $unlockLog | Select-String -Pattern "CHARACTER_LOCK_VALIDATION_RESULT=PASS")) {
    $failures += "character-lock validation result line"
}

# ---------------------------------------------------------------- step 3
Write-Host "=== step 3: HUD-art wiring regression (gate off, headless) ==="
$wiringLog = Join-Path $logs "validate_hud_art_wiring.log"
$playerGlb = "D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb"
$opponentGlb = "D:\BruceLeeWork\brick-full-20261103\candidate\brick_full_94_20261103.glb"
$code = Invoke-Native $Godot @("--headless", "--path", $project,
    "--script", "res://tests/validate_hud_art_wiring.gd", "--quit-after", "4000",
    "--", $playerGlb, $opponentGlb) $wiringLog
Write-Host "exit=$code"
if ($code -ne 0) { $failures += "HUD-art wiring regression (exit $code)" }

if ($Shots) {
    # ------------------------------------------------------------ step 4
    Write-Host "=== step 4: windowed captures (the only windowed step) ==="
    $captureLog = Join-Path $logs "capture_character_locks.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\run_character_lock_capture.py"), "--out", $shotsDir,
        "--godot", $Godot) $captureLog
    Write-Host "exit=$code"
    Get-Content $captureLog | Select-String -Pattern "^RESULT="
    if ($code -ne 0) { $failures += "captures (exit $code)" }

    # ------------------------------------------------------------ step 5
    Write-Host "=== step 5: pixel + report checks ==="
    $pixelLog = Join-Path $logs "verify_character_lock_capture.log"
    $code = Invoke-Native $Python @("-X", "utf8",
        (Join-Path $root "tools\verify_character_lock_capture.py"), "--shots", $shotsDir) $pixelLog
    Write-Host "exit=$code"
    Get-Content $pixelLog | Select-String -Pattern "CHARACTER_LOCK_PIXELS"
    if ($code -ne 0) { $failures += "pixel checks (exit $code)" }
}

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "CHARACTER_LOCK_TESTS=PASS"
    exit 0
}
Write-Host ("CHARACTER_LOCK_TESTS=FAIL: " + ($failures -join "; "))
exit 1
