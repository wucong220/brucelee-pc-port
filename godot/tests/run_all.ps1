# Arcade / Survival / Time Attack menu localization (Current161 rebase) -
# full test + screenshot runner.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_all.ps1
#   powershell ... -File tests\run_all.ps1 -SkipShots
#
# Steps:
#   1. pre-existing game-mode rule validation (Current161 code, regression)
#   2. headless text validation for all 10 languages (writes the text dump)
#   3. windowed gallery: mode menu / Arcade settings / Time Attack settings x 10
#   4. windowed full flows: Arcade EN/ZH/JA, Survival EN/ZH, Time Attack EN/ZH
#   5. Current161 prototype smoke test (unmodified upstream suite)
#   6. pixel validation of every screenshot
#   7. python gate: provenance, coverage, patch, dump, screenshot set
# Exit 0 only when every step is OK.
# -SkipShots runs steps 1, 2 and 5 only (no capture, no screenshot gate).
#
# This file is pure ASCII on purpose: the private texture root lives under a
# CJK folder name, so it is resolved by wildcard (or passed in) instead of
# being hardcoded here - a UTF-8/ANSI mismatch can never corrupt the path.
param(
    [switch]$SkipShots,
    [string]$Godot = "",
    [string]$TextureRoot = "",
    [string]$PlayerGlb = "D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb",
    [string]$GameTextRoot = "D:\BruceLeeWork\story-flow-20261104\tools\ui\gametext",
    [string]$HudRoot = "D:\BruceLeeWork\ui_hud_png"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$outRoot = Split-Path -Parent $root
$logs = Join-Path $outRoot "evidence\logs"
$shots = Join-Path $outRoot "screenshots"
New-Item -ItemType Directory -Force $logs | Out-Null
New-Item -ItemType Directory -Force $shots | Out-Null

if ([string]::IsNullOrEmpty($Godot)) {
    $Godot = Join-Path $root "..\..\story-flow-151-20261104\tools\godot.exe"
}
if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }

if ([string]::IsNullOrEmpty($TextureRoot)) { $TextureRoot = $env:CAPTURE_TEXTURE_ROOT }
if ([string]::IsNullOrEmpty($TextureRoot)) {
    $hit = Get-ChildItem -Path "D:\BaiduSyncdisk\AI*\*\private_assets\appdata-msix\BruceLee-PC-Port\candidate-textures-verified-20261029" `
        -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit -ne $null) { $TextureRoot = $hit.FullName }
}
foreach ($pair in @(@("player GLB", $PlayerGlb), @("texture root", $TextureRoot),
                    @("gametext root", $GameTextRoot), @("HUD root", $HudRoot))) {
    if ([string]::IsNullOrEmpty($pair[1]) -or -not (Test-Path -LiteralPath $pair[1])) {
        throw ("capture asset missing: " + $pair[0] + " -> " + $pair[1])
    }
}

$env:CAPTURE_PLAYER_GLB = $PlayerGlb
$env:CAPTURE_TEXTURE_ROOT = $TextureRoot
$env:CAPTURE_GAMETEXT_ROOT = $GameTextRoot
$env:CAPTURE_HUD_ROOT = $HudRoot
$env:MENU_LANG_DUMP = Join-Path $outRoot "evidence\menu_lang_texts.json"

# Never inherit a half-set state from the caller (same list validate_candidate.ps1 clears).
$clearedNames = @(
    "BRUCELEE_EXPORT_SELF_TEST", "BRUCELEE_PLAYER_GLB", "BRUCELEE_PLAYER_TEXTURE_ROOT",
    "BRUCELEE_OPPONENT_GLB", "BRUCELEE_OPPONENT_TEXTURE_ROOT",
    "BRUCELEE_CANDIDATE_VISUAL_BLENDING", "BRUCELEE_MAIN_MENU", "BRUCELEE_MAINMENU_PATH",
    "BRUCELEE_STORY_FLOW", "BRUCELEE_GAME_MODE", "BRUCELEE_MODE_LAUNCH",
    "BRUCELEE_PROGRESS", "BRUCELEE_LANG", "BRUCELEE_SCENE", "BRUCELEE_ROUND_TIME",
    "BRUCELEE_AI_DIFFICULTY", "BRUCELEE_MATCH_ROUNDS", "BRUCELEE_PLAYER_START_HEALTH"
)
foreach ($name in $clearedNames) {
    Remove-Item -Path ("Env:" + $name) -ErrorAction SilentlyContinue
}

$results = @()

# The 10 recovered .lang languages, in table order.
$LANGUAGES = @(
    "LangEnglish", "LangChineseSimpl", "LangChineseTrad", "LangFrench",
    "LangGerman", "LangItalian", "LangJapanese", "LangKorean",
    "LangRussian", "LangSpanish"
)

function Invoke-Godot {
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
        Select-String -Pattern "^(PASS|FAIL|SHOT |GALLERY_|CAPTURE_|MENU_LANG_|SCREENSHOT_|SMOKE_)" |
        ForEach-Object { Write-Host ("   " + $_.Line) }
    if ($code -ne 0) {
        Write-Host "   [tail of $LogFile]" -ForegroundColor Yellow
        Get-Content -Path $logPath -Encoding UTF8 -Tail 15 | ForEach-Object { Write-Host ("   | " + $_) }
    }
    $seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    Write-Host ("   exit={0} ({1}s)" -f $code, $seconds)
    $script:results += [pscustomobject]@{ Step = $Name; ExitCode = $code; Seconds = $seconds; Log = "evidence/logs/$LogFile" }
}

# Run a windowed capture step; retry once unless it exits 0 AND wrote every
# expected PNG (see the note at the call site).
function Invoke-Capture {
    param([string]$Name, [string[]]$Arguments, [string]$LogFile, [string[]]$Expect)
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Invoke-Godot -Name $Name -LogFile $LogFile -Arguments $Arguments
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

function Invoke-Python {
    param([string]$Name, [string]$Script, [string]$LogFile)
    Write-Host "== $Name ==" -ForegroundColor Cyan
    $start = Get-Date
    $logPath = Join-Path $logs $LogFile
    $cmdline = 'python "' + $Script + '" > "' + $logPath + '" 2>&1'
    cmd /c $cmdline | Out-Null
    $code = $LASTEXITCODE
    Get-Content -Path $logPath -Encoding UTF8 |
        Select-String -Pattern "^(PASS|FAIL|VALIDATE|  FAILED|  MISSING|  LEAK|BUILD)" |
        ForEach-Object { Write-Host ("   " + $_.Line) }
    $seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    Write-Host ("   exit={0} ({1}s)" -f $code, $seconds)
    $script:results += [pscustomobject]@{ Step = $Name; ExitCode = $code; Seconds = $seconds; Log = "evidence/logs/$LogFile" }
}

Invoke-Godot -Name "validate_game_modes" -LogFile "validate_game_modes.log" -Arguments @(
    "--headless", "--path", $root, "--script", "res://tests/validate_game_modes.gd", "--quit-after", "600"
)

Invoke-Godot -Name "validate_menu_lang" -LogFile "validate_menu_lang.log" -Arguments @(
    "--headless", "--path", $root, "--script", "res://tests/validate_menu_lang.gd", "--quit-after", "900"
)

if (-not $SkipShots) {
    # Capture steps are retried once. A windowed Godot process occasionally
    # exits mid-flow on this machine (observed: exit 0 after ~98 s with the log
    # ending right after the round-intro warning, no further SHOT line) while
    # other Godot instances run; the identical command then succeeds. The retry
    # only accepts a step that both exits 0 AND produced its expected PNGs, so a
    # systematically broken capture can never be papered over.
    $galleryShots = @()
    foreach ($lang in $LANGUAGES) {
        $galleryShots += "10-mode-menu-$lang.png"
        $galleryShots += "11-arcade-settings-$lang.png"
        $galleryShots += "12-timeattack-settings-$lang.png"
    }
    Invoke-Capture -Name "gallery" -LogFile "capture_gallery.log" -Expect $galleryShots -Arguments @(
        "--path", $root, "--script", "res://tests/menu_lang_gallery.gd",
        "--quit-after", "400000", "--", $shots
    )
    # One process per flow: concurrent Godot instances contend for the GPU and
    # stall the capture window (observed in arcade-lang-20261104).
    $flows = @(
        @("arcade", "LangEnglish"),
        @("arcade", "LangChineseSimpl"),
        @("arcade", "LangJapanese"),
        @("survival", "LangEnglish"),
        @("survival", "LangChineseSimpl"),
        @("timeattack", "LangEnglish"),
        @("timeattack", "LangChineseSimpl")
    )
    foreach ($flow in $flows) {
        $mode = $flow[0]
        $lang = $flow[1]
        $expect = @("02-$mode-settings-$lang.png", "03-$mode-battle-$lang.png", "04-$mode-result-$lang.png")
        if ($mode -eq "arcade") { $expect = @("01-main-menu-$lang.png") + $expect }
        Invoke-Capture -Name "capture_${mode}_$lang" -LogFile "capture_${mode}_$lang.log" -Expect $expect -Arguments @(
            "--path", $root, "--script", "res://tests/menu_lang_capture.gd",
            "--quit-after", "400000", "--", $mode, $lang, $shots
        )
    }
}

# Current161 upstream suite, unmodified: proves the rebase did not break the port.
Invoke-Godot -Name "smoke_test" -LogFile "smoke_test.log" -Arguments @(
    "--headless", "--path", $root, "--script", "res://tests/smoke_test.gd"
)

# The last two steps need the PNG set, so -SkipShots stops after the smoke test.
if (-not $SkipShots) {
    Invoke-Godot -Name "validate_screenshots" -LogFile "validate_screenshots.log" -Arguments @(
        "--headless", "--path", $root, "--script", "res://tests/validate_screenshots.gd",
        "--quit-after", "900", "--", $shots
    )
    Invoke-Python -Name "validate_data_and_texts" -Script (Join-Path $outRoot "tools\validate.py") -LogFile "validate_python.log"
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
