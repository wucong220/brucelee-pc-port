param(
    [string]$GodotExe = "godot",
    [switch]$Debug,
    [string]$BuildRoot = "",
    [string]$OutputDir = ""
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceProject = Join-Path $root 'godot'
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path $env:TEMP 'brucelee-godot-build'
}
$dist = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    Join-Path $root 'dist'
} else {
    $OutputDir
}
$project = Join-Path $BuildRoot 'godot'
$buildDist = Join-Path $BuildRoot 'dist'
$targetName = 'DragonWarrior_PC_Prototype.exe'
$delivered = Join-Path $dist $targetName
$profile = if ($Debug) { '--export-debug' } else { '--export-release' }

Write-Host "Godot: $GodotExe"
Write-Host "Source project: $sourceProject"
Write-Host "Build project: $project"

if (Test-Path $BuildRoot) { Remove-Item -LiteralPath $BuildRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
Copy-Item -LiteralPath $sourceProject -Destination $project -Recurse
New-Item -ItemType Directory -Force -Path $buildDist | Out-Null
New-Item -ItemType Directory -Force -Path $dist | Out-Null

& $GodotExe --headless --path $project --editor --quit
if (-not $?) { throw 'Godot import/script validation failed.' }

& $GodotExe --headless --path $project $profile 'Windows Desktop' (Join-Path $buildDist $targetName)
if (-not $?) { throw 'Windows export failed. Install the matching Godot export templates and retry.' }

$exported = $null
for ($attempt = 0; $attempt -lt 150 -and $null -eq $exported; $attempt++) {
    $exported = Get-ChildItem -LiteralPath $buildDist -Filter '*.exe' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $exported) { Start-Sleep -Milliseconds 200 }
}
if ($null -eq $exported) { throw 'Godot did not produce the expected EXE.' }

Copy-Item -LiteralPath $exported.FullName -Destination $delivered -Force
$exportedPck = Get-ChildItem -LiteralPath $buildDist -Filter '*.pck' -File -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -ne $exportedPck) {
    Copy-Item -LiteralPath $exportedPck.FullName -Destination (Join-Path $dist 'DragonWarrior_PC_Prototype.pck') -Force
}

Write-Host "Built: $delivered"
Write-Host 'Reminder: This is a combat prototype, not the complete original game.'
