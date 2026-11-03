# Arcade / Survival / Time Attack modes - test runner
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all.ps1
#   powershell ... -File tests\run_all.ps1 -SkipShots
#
# Validation is headless. Capture runs one process per mode (windowed) and
# writes PNGs into screenshots/. Exit 0 only when every suite is OK.
param(
    [switch]$SkipShots,
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrEmpty($Godot)) { $Godot = Join-Path $root "..\..\story-flow-151-20261104\tools\godot.exe" }
if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }

$logs = Join-Path $root "evidence\logs"
New-Item -ItemType Directory -Force $logs | Out-Null
$shots = Join-Path $root "..\screenshots"
New-Item -ItemType Directory -Force $shots | Out-Null
$results = @()

function Invoke-Suite {
    param([string]$Name, [string[]]$Arguments, [string]$LogFile)
    Write-Host "== $Name ==" -ForegroundColor Cyan
    $start = Get-Date
    $logPath = Join-Path $logs $LogFile
    $parts = @('"' + $Godot + '"')
    foreach ($a in $Arguments) { $parts += ('"' + $a + '"') }
    $cmdline = ($parts -join ' ') + ' > "' + $logPath + '" 2>&1'
    cmd /c $cmdline | Out-Null
    $code = $LASTEXITCODE
    $errors = (Select-String -Path $logPath -Pattern "SCRIPT ERROR|Parse Error" -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($errors -gt 0 -and $code -eq 0) { $code = 1 }
    Get-Content -Path $logPath -Encoding UTF8 |
        Select-String -Pattern "^(PASS|FAIL|GAME_MODES_|CAPTURE_FAILURES|SHOT )" |
        ForEach-Object { Write-Host ("   " + $_.Line) }
    $seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    Write-Host ("   exit={0} ({1}s)" -f $code, $seconds)
    $script:results += [pscustomobject]@{ Suite = $Name; ExitCode = $code; Seconds = $seconds; Log = "evidence/logs/$LogFile" }
}

Invoke-Suite -Name "validate_game_modes" -LogFile "validate.log" -Arguments @(
    "--headless", "--path", $root, "--script", "res://tests/validate_game_modes.gd", "--quit-after", "600"
)

if (-not $SkipShots) {
    foreach ($mode in @("arcade", "survival", "timeattack")) {
        Invoke-Suite -Name "capture_$mode" -LogFile "capture_$mode.log" -Arguments @(
            "--path", $root, "--script", "res://tests/game_modes_capture.gd",
            "--quit-after", "400000", "--", $mode, $shots
        )
    }
}

Write-Host ""
$results | Format-Table -AutoSize
$failed = ($results | Where-Object { $_.ExitCode -ne 0 }).Count
if ($failed -gt 0) {
    Write-Host "$failed suite(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "all suites passed" -ForegroundColor Green
exit 0
