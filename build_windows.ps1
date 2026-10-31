param(
    [string]$GodotExe = "godot",
    [switch]$Debug,
    [switch]$SelfTest,
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
$project = Join-Path $BuildRoot 'staging\godot'
$buildDist = Join-Path $BuildRoot 'staging\dist'
$targetName = 'DragonWarrior_PC_Prototype.exe'
$delivered = Join-Path $dist $targetName
$profile = if ($Debug) { '--export-debug' } else { '--export-release' }

Write-Host "Godot: $GodotExe"
Write-Host "Source project: $sourceProject"
Write-Host "Build project: $project"

$buildRootFull = [System.IO.Path]::GetFullPath($BuildRoot)
$sourceFull = [System.IO.Path]::GetFullPath($sourceProject)
$rootFull = [System.IO.Path]::GetFullPath($root)
$staging = Join-Path $BuildRoot 'staging'
$stagingFull = [System.IO.Path]::GetFullPath($staging)
$projectFull = [System.IO.Path]::GetFullPath($project)
function Test-PathOverlap([string]$left, [string]$right) {
    $separator = [System.IO.Path]::DirectorySeparatorChar
    return [string]::Equals($left, $right, [System.StringComparison]::OrdinalIgnoreCase) -or
        $left.StartsWith($right + $separator, [System.StringComparison]::OrdinalIgnoreCase) -or
        $right.StartsWith($left + $separator, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ReparsePointInPath([string]$path) {
    $current = [System.IO.Path]::GetFullPath($path)
    while (-not [string]::IsNullOrWhiteSpace($current)) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and
                (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            return $true
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) {
            break
        }
        $current = $parent
    }
    return $false
}

if ($SelfTest) {
    if (-not (Test-PathOverlap 'C:\Work\staging' 'c:\work\staging\project')) {
        throw 'Case-insensitive child overlap was not detected.'
    }
    if (Test-PathOverlap 'C:\Work\staging' 'D:\Work\project') {
        throw 'Unrelated paths were reported as overlapping.'
    }
    $junction = Join-Path $env:TEMP 'brucelee-path-overlap-junction'
    if (Test-Path $junction) { cmd.exe /c rmdir /q "$junction" | Out-Null }
    New-Item -ItemType Junction -Path $junction -Target $rootFull | Out-Null
    try {
        if (-not (Test-ReparsePointInPath $junction)) {
            throw 'A junction in the candidate path was not detected.'
        }
    } finally {
        cmd.exe /c rmdir /q "$junction" | Out-Null
    }
    Write-Host 'PATH_OVERLAP_SELFTEST=passed'
    exit 0
}
if ((Test-PathOverlap $stagingFull $rootFull) -or
        (Test-PathOverlap $stagingFull $sourceFull) -or
        (Test-PathOverlap $projectFull $sourceFull)) {
    throw 'BuildRoot/staging must not overlap the repository or source project.'
}
if ((Test-ReparsePointInPath $BuildRoot) -or (Test-ReparsePointInPath $staging)) {
    throw 'BuildRoot/staging must not traverse a junction or symlink.'
}
if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $buildDist | Out-Null
Copy-Item -LiteralPath $sourceProject -Destination $project -Recurse
New-Item -ItemType Directory -Force -Path $dist | Out-Null

& $GodotExe --headless --path $project --editor --quit
if (-not $?) { throw 'Godot import/script validation failed.' }

& $GodotExe --headless --path $project $profile 'Windows Desktop' (Join-Path $buildDist $targetName)
if (-not $?) { throw 'Windows export failed. Install the matching Godot export templates and retry.' }

$targetPath = Join-Path $buildDist $targetName
$pckPath = Join-Path $buildDist 'DragonWarrior_PC_Prototype.pck'
$exported = $null
for ($attempt = 0; $attempt -lt 150 -and $null -eq $exported; $attempt++) {
    if (Test-Path -LiteralPath $targetPath) {
        $exported = Get-Item -LiteralPath $targetPath -ErrorAction SilentlyContinue
    }
    if ($null -eq $exported) { Start-Sleep -Milliseconds 200 }
}
if ($null -eq $exported) { throw 'Godot did not produce the expected EXE.' }
$exportedPck = $null
for ($attempt = 0; $attempt -lt 50 -and $null -eq $exportedPck; $attempt++) {
    if (Test-Path -LiteralPath $pckPath) {
        $exportedPck = Get-Item -LiteralPath $pckPath -ErrorAction SilentlyContinue
    }
    if ($null -eq $exportedPck) { Start-Sleep -Milliseconds 200 }
}
if ($null -eq $exportedPck) { throw 'Godot did not produce the expected PCK.' }

Copy-Item -LiteralPath $exported.FullName -Destination $delivered -Force
Copy-Item -LiteralPath $exportedPck.FullName -Destination (Join-Path $dist 'DragonWarrior_PC_Prototype.pck') -Force

Write-Host "Built: $delivered"
Write-Host 'Reminder: This is a combat prototype, not the complete original game.'
