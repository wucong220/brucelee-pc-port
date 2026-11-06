<#
Runs the VIDEO/CONTROLS headless validators against the real main.tscn.

Strict user:// isolation: APPDATA / HOME / USERPROFILE are redirected to a
fresh temp directory for the whole run, and the validator itself disables the
native settings.dat / progress mirror.  Nothing is written to the checkout or
to the machine's normal user-data directory.

    powershell -File godot\tests\run_video_controls_tests.ps1
#>
param(
    [string]$Godot = "$env:LOCALAPPDATA\BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Player = 'D:\BruceLeeWork\DragonWarrior-Current238-20261103\models\bruce_skin01.glb',
    [string]$Opponent = 'D:\BruceLeeWork\DragonWarrior-Current238-20261103\models\brick_full_94_20261103.glb'
)

# Continue is deliberate: Godot writes harmless engine diagnostics to stderr
# (sandbox cannot create its user:// log file); those must not abort the run.
# Every failure is detected explicitly via $LASTEXITCODE / the validation JSON.
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $Godot)) { throw "Godot not found: $Godot" }
if (-not (Test-Path $Player)) { throw "player GLB not found: $Player" }
if (-not (Test-Path $Opponent)) { throw "opponent GLB not found: $Opponent" }

$userDir = Join-Path $env:TEMP ('brucelee-video-controls-' + [guid]::NewGuid().ToString('N'))
# Pre-create the Godot user-data tree: the engine child cannot create directories
# in this sandbox, but it can use an already-existing isolated tree.
$projectName = 'Dragon Warrior Story Flow (isolated)'
$projectUserDir = Join-Path $userDir ("Godot\app_userdata\$projectName")
New-Item -ItemType Directory -Force -Path (Join-Path $projectUserDir 'logs') | Out-Null
$old = @{
    APPDATA = $env:APPDATA
    HOME = $env:HOME
    USERPROFILE = $env:USERPROFILE
}
$env:APPDATA = $userDir
$env:HOME = $userDir
$env:USERPROFILE = $userDir

try {
    foreach ($mode in @('normal', 'failclosed')) {
        $log = Join-Path $userDir ($mode + '.log')
        & $Godot --headless --path $project --script res://tests/validate_video_controls.gd `
            --quit-after 12000 -- $Player $Opponent $mode *> $log
        $code = $LASTEXITCODE
        $summary = Select-String -Path $log -Pattern 'VIDEO_CONTROLS_VALIDATION|FAIL ' -ErrorAction SilentlyContinue
        foreach ($line in $summary) { Write-Host $line.Line }
        if ($code -ne 0) {
            Write-Error "mode=$mode exit=$code log=$log"
            Get-Content $log -Tail 40
            exit $code
        }
    }
    Write-Host 'ALL VIDEO-CONTROLS CHECKS PASSED'
    exit 0
}
finally {
    $env:APPDATA = $old.APPDATA
    $env:HOME = $old.HOME
    $env:USERPROFILE = $old.USERPROFILE
}
