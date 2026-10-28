param(
    [string]$GodotExe = "godot",
    [switch]$Debug
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = Join-Path $root 'godot'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$target = Join-Path $dist 'DragonWarrior_PC_Prototype.exe'
$profile = if ($Debug) { '--export-debug' } else { '--export-release' }
Write-Host "Godot: $GodotExe"
Write-Host "Project: $project"
& $GodotExe --headless --path $project --editor --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import/script validation failed.' }
& $GodotExe --headless --path $project $profile 'Windows Desktop' $target
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed. Install the matching Godot export templates and retry.' }
if (-not (Test-Path $target)) { throw 'Godot did not produce the expected EXE.' }
Write-Host "Built: $target"
Write-Host 'Reminder: This is a combat prototype, not the complete original game.'
