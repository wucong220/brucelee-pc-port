param(
    [string]$GodotExe = "godot",
    [switch]$Debug,
    [switch]$SelfTest,
    [string]$BuildRoot = "",
    [string]$OutputDir = "",
    [string]$GodotTempRoot = ""
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
$staging = Join-Path $BuildRoot ('brucelee-build-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $staging 'godot'
$buildDist = Join-Path $staging 'dist'
if ([string]::IsNullOrWhiteSpace($GodotTempRoot)) {
    $GodotTempRoot = Join-Path $BuildRoot 'godot-temp'
}
$targetName = 'DragonWarrior_PC_Prototype.exe'
$delivered = Join-Path $dist $targetName
$profile = if ($Debug) { '--export-debug' } else { '--export-release' }

Write-Host "Godot: $GodotExe"
Write-Host "Source project: $sourceProject"
Write-Host "Build project: $project"

$buildRootFull = [System.IO.Path]::GetFullPath($BuildRoot)
$sourceFull = [System.IO.Path]::GetFullPath($sourceProject)
$rootFull = [System.IO.Path]::GetFullPath($root)
$stagingFull = [System.IO.Path]::GetFullPath($staging)
$projectFull = [System.IO.Path]::GetFullPath($project)
$godotTempFull = [System.IO.Path]::GetFullPath($GodotTempRoot)
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

function Test-SubstPath([string]$path, [string[]]$substLines = $null) {
    if ($null -eq $substLines) {
        $substLines = @(& cmd.exe /c subst 2>$null)
    }
    foreach ($substLine in $substLines) {
        if ($substLine -match '^([A-Za-z]):\\:\s*=>') {
            $substDrive = $Matches[1] + ':\'
            if ($path.StartsWith($substDrive, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
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
    $substFixture = @('Z:\: => C:\repo\godot')
    if (-not (Test-SubstPath 'Z:\out' $substFixture)) {
        throw 'SUBST drive path was not detected.'
    }
    if (Test-SubstPath 'C:\out' $substFixture) {
        throw 'A regular path was misreported as SUBST.'
    }
    $junction = Join-Path $env:TEMP ('brucelee-path-overlap-junction-' + [guid]::NewGuid().ToString('N'))
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
if ((Test-PathOverlap $godotTempFull $rootFull) -or
        (Test-PathOverlap $godotTempFull $sourceFull) -or
        (Test-PathOverlap $godotTempFull $stagingFull)) {
    throw 'GodotTempRoot must not overlap the repository, source project, or staging.'
}
if ((Test-ReparsePointInPath $BuildRoot) -or (Test-ReparsePointInPath $staging) -or
        (Test-ReparsePointInPath $sourceProject) -or (Test-ReparsePointInPath $root) -or
        (Test-ReparsePointInPath $GodotTempRoot)) {
    throw 'BuildRoot/staging/source/temp paths must not traverse a junction or symlink.'
}
if ((Test-SubstPath $buildRootFull) -or (Test-SubstPath $sourceFull) -or
        (Test-SubstPath $rootFull) -or (Test-SubstPath $godotTempFull)) {
    throw 'BuildRoot/source/temp paths must not use a SUBST virtual drive.'
}
if (Test-Path $staging) { throw 'Generated staging directory already exists.' }
New-Item -ItemType Directory -Force -Path $staging | Out-Null
New-Item -ItemType Directory -Force -Path $buildDist | Out-Null
New-Item -ItemType Directory -Force -Path $GodotTempRoot | Out-Null
Copy-Item -LiteralPath $sourceProject -Destination $project -Recurse
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
$env:TEMP = $GodotTempRoot
$env:TMP = $GodotTempRoot
$importCode = 1
$exportCode = 1
try {
    $importCommand = '"{0}" --headless --path "{1}" --editor --quit 2>nul' -f (
        $GodotExe, $project
    )
    & cmd.exe /d /s /c $importCommand
    $importCode = $LASTEXITCODE
    if ($importCode -eq 0) {
        $exportCommand = '"{0}" --headless --path "{1}" {2} "Windows Desktop" "{3}" 2>nul' -f (
            $GodotExe, $project, $profile, (Join-Path $buildDist $targetName)
        )
        & cmd.exe /d /s /c $exportCommand
        $exportCode = $LASTEXITCODE
    }
} finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
if ($importCode -ne 0) { throw 'Godot import/script validation failed.' }
if ($exportCode -ne 0) { throw 'Windows export failed. Install the matching Godot export templates and retry.' }

$targetPath = Join-Path $buildDist $targetName
$pckPath = Join-Path $buildDist 'DragonWarrior_PC_Prototype.pck'
$exported = $null
for ($attempt = 0; $attempt -lt 600 -and $null -eq $exported; $attempt++) {
    if (Test-Path -LiteralPath $targetPath) {
        $exported = Get-Item -LiteralPath $targetPath -ErrorAction SilentlyContinue
    }
    if ($null -eq $exported) { Start-Sleep -Milliseconds 200 }
}
if ($null -eq $exported) { throw 'Godot did not produce the expected EXE.' }
$exportedPck = $null
for ($attempt = 0; $attempt -lt 300 -and $null -eq $exportedPck; $attempt++) {
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
