param(
    [string]$Godot = "C:\Users\Lenovo\AppData\Local\BruceLee-PC-Port\godot-portable-773280yg\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Player = "D:\BruceLeeWork\bruce-full-20261103\out\bruce_full_121_20261103.glb",
    [string]$Opponent = "D:\BruceLeeWork\brick-full-20261103\candidate\brick_full_94_20261103.glb",
    [string]$Scratch = "D:\BaiduSyncdisk\AI项目\李小龙\work\hud-art-wired-scratch",
    [switch]$SkipCapture
)
$ErrorActionPreference = "Continue"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$project = Join-Path $root "godot"
$shots = Join-Path $root "shots"
$logs = Join-Path $root "logs"
$tools = Join-Path $root "tools"
New-Item -ItemType Directory -Force $scratch, $shots, $logs | Out-Null

# The Godot child process can only write inside the session workspace, so the
# capture script writes to $Scratch and this runner copies into shots/.
Get-ChildItem env: | Where-Object { $_.Name -like "BRUCELEE_*" } | ForEach-Object {
    Remove-Item ("env:" + $_.Name) -ErrorAction SilentlyContinue
}
# The portable console wrapper can leave the renderer process behind after
# quit(); a live renderer blocks the next window, so reap between captures.
function Clear-Godot {
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match "Godot|godot" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
Clear-Godot
Start-Sleep -Milliseconds 800

Write-Host "== headless wiring validation =="
& $Godot --headless --path $project --script res://tests/validate_hud_art_wiring.gd `
    --quit-after 4000 -- $Player $Opponent 2>&1 |
    Out-File -FilePath (Join-Path $logs "validate_hud_art_wiring.log") -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw "wiring validation failed ($LASTEXITCODE)" }

if (-not $SkipCapture) {
    foreach ($res in @("1280x720", "868x517")) {
        $tag = ($res -split "x")[0]
        $dir = Join-Path $Scratch $tag
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $dir | Out-Null
        foreach ($mode in @("off", "on", "hud")) {
            Write-Host "== capture $res $mode =="
            & $Godot --path $project --resolution $res --rendering-driver opengl3 `
                --position 80,80 --quit-after 6000 `
                --script res://tests/capture_hud_art_wired.gd -- $dir $mode $Player $Opponent 2>&1 |
                Out-File -FilePath (Join-Path $logs "capture_${tag}_$mode.log") -Encoding utf8
            $code = $LASTEXITCODE
            Start-Sleep -Milliseconds 900
            Clear-Godot
            Start-Sleep -Milliseconds 300
            if ($code -ne 0) { throw "capture $res $mode failed ($code)" }
            $expected = switch ($mode) {
                "off" { @("off_01_main.png", "off_02_opponents_brick.png", "off_05_fight.png") }
                "on" { @("on_01_main.png", "on_02_opponents_brick.png", "on_03_dock_sinfu.png",
                         "on_04_vs_sinfu.png", "on_05_fight.png") }
                "hud" { @("hud_off.png", "hud_on_hidden.png") }
            }
            foreach ($name in $expected) {
                $path = Join-Path $dir $name
                if (-not (Test-Path $path) -or (Get-Item $path).Length -lt 2048) {
                    throw "capture $res $mode did not write $name"
                }
            }
        }
        New-Item -ItemType Directory -Force (Join-Path $shots $res) | Out-Null
        Copy-Item (Join-Path $dir "*.png") (Join-Path $shots $res) -Force
    }
    Write-Host "== measurement =="
    python -X utf8 (Join-Path $tools "measure_hud_art_wired.py") 2>&1 |
        Out-File -FilePath (Join-Path $logs "measure_hud_art_wired.log") -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "measurement failed ($LASTEXITCODE)" }
}
Write-Host "OK"
