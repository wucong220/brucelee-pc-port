# Style Editor replay onto Current168 (HEAD 6b2f945) - test + screenshot runner.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File godot\tests\run_style_editor_tests.ps1
#   powershell ... -File godot\tests\run_style_editor_tests.ps1 -SkipShots
#
# Steps (all against THIS tree):
#   1. validate_style_editor ...... the replayed feature (101 assertions)
#   2. validate_fight_stats_main .. Current168 fight_stats counters (must stay green)
#   3. smoke_test ................. the current upstream smoke suite, unmodified
#   4. story_flow_validate ........ story-mode data/rules regression
#   5. validate_game_modes ........ arcade/survival/time-attack rules regression
#   6. capture_style_editor ....... windowed 1280x720 screenshots (10 PNGs)
# Exit 0 only when every step is OK.
# -SkipShots runs steps 1-5 only.
#
# This file is pure ASCII on purpose.

param(
    [switch]$SkipShots,
    [string]$Godot = "D:\BruceLeeWork\story-flow-151-20261104\tools\godot.exe"
)

$ErrorActionPreference = "Stop"
$godotProject = Split-Path -Parent $PSScriptRoot
$outRoot = Split-Path -Parent $godotProject
$logs = Join-Path $outRoot "reports\logs"
$shots = Join-Path $outRoot "screenshots"
New-Item -ItemType Directory -Force $logs | Out-Null
New-Item -ItemType Directory -Force $shots | Out-Null

if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }

# Never inherit flag state from the caller: every step sets its own.
$clearedNames = @(
    "BRUCELEE_EXPORT_SELF_TEST", "BRUCELEE_PLAYER_GLB", "BRUCELEE_PLAYER_TEXTURE_ROOT",
    "BRUCELEE_OPPONENT_GLB", "BRUCELEE_OPPONENT_TEXTURE_ROOT",
    "BRUCELEE_CANDIDATE_VISUAL_BLENDING", "BRUCELEE_MAIN_MENU", "BRUCELEE_MAINMENU_PATH",
    "BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE",
    "BRUCELEE_MODE_LAUNCH", "BRUCELEE_PROGRESS", "BRUCELEE_LANG", "BRUCELEE_SCENE",
    "BRUCELEE_ROUND_TIME", "BRUCELEE_AI_DIFFICULTY", "BRUCELEE_MATCH_ROUNDS",
    "BRUCELEE_PLAYER_START_HEALTH", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_DEMO_CLOSE"
)
foreach ($name in $clearedNames) {
    Remove-Item -Path ("Env:" + $name) -ErrorAction SilentlyContinue
}

$results = @()

function Invoke-Godot {
    param([string]$Name, [string[]]$Arguments, [string]$LogFile, [string]$Match = "^(PASS|FAIL|CHECK |STYLE |SMOKE_|SHOT |PROTOTYPE_)")
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
        Select-String -Pattern $Match |
        ForEach-Object { Write-Host ("   " + $_.Line) }
    if ($code -ne 0) {
        Write-Host "   [tail of $LogFile]" -ForegroundColor Yellow
        Get-Content -Path $logPath -Encoding UTF8 -Tail 15 | ForEach-Object { Write-Host ("   | " + $_) }
    }
    $seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    Write-Host ("   exit={0} ({1}s)" -f $code, $seconds)
    $script:results += [pscustomobject]@{ Step = $Name; ExitCode = $code; Seconds = $seconds; Log = "reports/logs/$LogFile" }
}

# A windowed capture step is retried once; a retry is accepted only when the
# step exits 0 AND wrote every expected PNG (a windowed Godot run on this
# machine can end mid-flow while other Godot instances run).
function Invoke-Capture {
    param([string]$Name, [string[]]$Arguments, [string]$LogFile, [string[]]$Expect)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Invoke-Godot -Name $Name -LogFile $LogFile -Arguments $Arguments -Match "^(CHECK|STYLE|SHOT |SHOT_)"
        $last = $script:results[$script:results.Count - 1]
        $missing = @($Expect | Where-Object { -not (Test-Path -LiteralPath (Join-Path $shots $_)) })
        if ($last.ExitCode -eq 0 -and $missing.Count -eq 0) { return }
        if ($attempt -eq 1) {
            Write-Host ("   retry (attempt 2): exit={0} missing={1}" -f $last.ExitCode, ($missing -join ", ")) -ForegroundColor Yellow
            $firstLog = Join-Path $logs ($LogFile -replace '\.log$', '.attempt1.log')
            Copy-Item -LiteralPath (Join-Path $logs $LogFile) -Destination $firstLog -Force -ErrorAction SilentlyContinue
            $script:results.RemoveAt($script:results.Count - 1)
        }
    }
}

Invoke-Godot -Name "validate_style_editor" -LogFile "validate_style_editor.log" -Arguments @(
    "--headless", "--path", $godotProject, "--script", "res://tests/validate_style_editor.gd", "--quit-after", "600"
)

Invoke-Godot -Name "validate_fight_stats_main" -LogFile "validate_fight_stats_main.log" -Arguments @(
    "--headless", "--path", $godotProject, "--script", "res://tests/validate_fight_stats_main.gd", "--quit-after", "900"
)

# Current168 upstream suite, unmodified.
Invoke-Godot -Name "smoke_test" -LogFile "smoke_test.log" -Arguments @(
    "--headless", "--path", $godotProject, "--script", "res://tests/smoke_test.gd"
)

Invoke-Godot -Name "story_flow_validate" -LogFile "story_flow_validate.log" -Arguments @(
    "--headless", "--path", $godotProject, "--script", "res://tests/story_flow_validate.gd", "--quit-after", "900"
)

Invoke-Godot -Name "validate_game_modes" -LogFile "validate_game_modes.log" -Arguments @(
    "--headless", "--path", $godotProject, "--script", "res://tests/validate_game_modes.gd", "--quit-after", "600"
)

if (-not $SkipShots) {
    $expect = @(
        "00_main_menu_row.png", "01_category.png", "02_personality_dock.png",
        "03_special_menu.png", "04_hpunch_dock.png", "05_hpunch_master_cursor.png",
        "06_hpunch_saved.png", "07_reset_confirm.png", "08_help.png",
        "09_back_to_main_menu.png"
    )
    Invoke-Capture -Name "capture_style_editor" -LogFile "capture_style_editor.log" -Expect $expect -Arguments @(
        "--path", $godotProject, "--script", "res://tests/capture_style_editor.gd",
        "--quit-after", "400000", "--", $shots
    )
}

Write-Host ""
$results | Format-Table -AutoSize
$failed = @($results | Where-Object { $_.ExitCode -ne 0 }).Count
if ($failed -gt 0) {
    Write-Host "$failed step(s) failed" -ForegroundColor Red
    exit 1
}
Write-Host "all steps passed" -ForegroundColor Green
exit 0
