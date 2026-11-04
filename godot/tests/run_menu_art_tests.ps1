# Opt-in original-art front menu (BRUCELEE_MENU_ART=1) - test + capture runner.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_menu_art_tests.ps1
#   powershell ... -File tests\run_menu_art_tests.ps1 -SkipCapture
#
# Steps:
#   1. text-menu regression (BRUCELEE_MENU_ART unset, including the RECORDS /
#      STYLE EDITOR opt-in rows when their flags are on)
#   2. art-menu navigation validation (main -> Play -> all six recovered rows)
#   3. windowed PNG capture of the two art menus and every mode entry screen
#
# The Godot process cannot write files under the DSH sandbox, so the capture
# goes through tools\run_menu_art_capture.py (TCP receiver). This file is ASCII.

param(
    [string]$Godot = "",
    [string]$PlayerGlb = "D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb",
    [string]$OpponentGlb = "D:\BruceLeeWork\brick-full-20261103\candidate\brick_full_94_20261103.glb",
    [switch]$SkipCapture
)

$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "..\godot"
$outRoot = Split-Path -Parent $root
$logs = Join-Path $outRoot "logs"
$shots = Join-Path $outRoot "screenshots"
New-Item -ItemType Directory -Force $logs | Out-Null
New-Item -ItemType Directory -Force $shots | Out-Null

if ([string]::IsNullOrEmpty($Godot)) {
    $Godot = Join-Path $env:LOCALAPPDATA "BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe"
}
if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }
if (-not (Test-Path $PlayerGlb)) { throw "player GLB missing: $PlayerGlb" }
if (-not (Test-Path $OpponentGlb)) { throw "opponent GLB missing: $OpponentGlb" }

# The sandboxed Godot process prints harmless user:// log failures on stderr;
# Windows PowerShell 5.1 turns native stderr into error records, so native
# steps rely on $LASTEXITCODE instead of terminating on stderr.
$ErrorActionPreference = "Continue"

# Never inherit a half-set menu state from the caller.
Get-ChildItem Env:BRUCELEE_* -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Path ("Env:" + $_.Name) -ErrorAction SilentlyContinue
}

$results = @()

function Invoke-Step {
    param([string]$Name, [string]$LogFile, [scriptblock]$Body)
    Write-Host "== $Name ==" -ForegroundColor Cyan
    $start = Get-Date
    $logPath = Join-Path $logs $LogFile
    $code = 0
    try {
        & $Body 2>&1 | Set-Content -Path $logPath -Encoding utf8
        $code = $LASTEXITCODE
    }
    catch {
        $_ | Out-String | Set-Content -Path $logPath -Encoding utf8
        $code = 1
    }
    Get-Content -Path $logPath -Encoding UTF8 |
        Select-String -Pattern "^(PASS|FAIL|SHOT|MENU_ART_|SMOKE_|PROTOTYPE_)" |
        ForEach-Object { Write-Host ("   " + $_.Line) }
    $seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    Write-Host ("   exit={0} ({1}s)" -f $code, $seconds)
    $script:results += [pscustomobject]@{ Step = $Name; ExitCode = $code; Seconds = $seconds; Log = "logs/$LogFile" }
}

Invoke-Step -Name "menu_art_off_regression" -LogFile "menu_art_off.log" -Body {
    & $Godot --headless --path (Resolve-Path $project) --script res://tests/validate_menu_art_off.gd `
        --quit-after 3000 -- $PlayerGlb $OpponentGlb
}

Invoke-Step -Name "menu_art_navigation" -LogFile "menu_art_navigation.log" -Body {
    & $Godot --headless --path (Resolve-Path $project) --script res://tests/validate_menu_art_menu.gd `
        --quit-after 3000 -- $PlayerGlb $OpponentGlb
}

if (-not $SkipCapture) {
    Invoke-Step -Name "menu_art_capture" -LogFile "menu_art_capture.log" -Body {
        python -X utf8 (Join-Path $outRoot "tools\run_menu_art_capture.py") --out $shots `
            --player $PlayerGlb --opponent $OpponentGlb --godot $Godot
    }
}

Write-Host ""
$results | Format-Table -AutoSize
$failed = @($results | Where-Object { $_.ExitCode -ne 0 }).Count
if ($failed -gt 0) {
    Write-Host "$failed step(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "all menu-art steps passed" -ForegroundColor Green
exit 0
