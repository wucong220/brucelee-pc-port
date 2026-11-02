param(
    [string]$GodotExe = "godot",
    [switch]$Debug,
    [switch]$SelfTest,
    [string]$BuildRoot = "",
    [string]$OutputDir = "",
    [string]$GodotTempRoot = "",
    [string]$RuntimeAssetRoot = ""
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceProject = Join-Path $root 'godot'
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $defaultBuildBase = ''
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $defaultBuildBase = Join-Path $env:LOCALAPPDATA 'BruceLee-PC-Port'
        if (Test-Path -LiteralPath $defaultBuildBase) {
            $item = Get-Item -LiteralPath $defaultBuildBase -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                $target = @($item.Target)[0]
                if (-not [string]::IsNullOrWhiteSpace($target)) {
                    $defaultBuildBase = [System.IO.Path]::GetFullPath($target)
                }
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($defaultBuildBase)) {
        $defaultBuildBase = $env:TEMP
    }
    $BuildRoot = Join-Path $defaultBuildBase 'godot-build'
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

function Get-ComparisonPath([string]$path) {
    $value = [System.IO.Path]::GetFullPath($path)
    if ($value.StartsWith('\\.\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Unsupported device path.'
    }
    if ($value.StartsWith('\\?\UNC\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $value = '\\' + $value.Substring(8)
    } elseif ($value.StartsWith('\\?\', [System.StringComparison]::OrdinalIgnoreCase)) {
        if ($value -match '^\\\\\?\\[A-Za-z]:') {
            $value = $value.Substring(4)
        } else {
            throw 'Unsupported extended device path.'
        }
    }
    return $value.TrimEnd([char[]]@('\', '/'))
}

$buildRootFull = [System.IO.Path]::GetFullPath($BuildRoot)
$sourceFull = [System.IO.Path]::GetFullPath($sourceProject)
$rootFull = [System.IO.Path]::GetFullPath($root)
$stagingFull = [System.IO.Path]::GetFullPath($staging)
$projectFull = [System.IO.Path]::GetFullPath($project)
$godotTempFull = Get-ComparisonPath($GodotTempRoot)
function Test-PathOverlap([string]$left, [string]$right) {
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $left = Get-ComparisonPath($left)
    $right = Get-ComparisonPath($right)
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

function Test-PckProjectSettings([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 64 -or
            [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne 'GDPC') {
        return $false
    }
    $fileBase = [BitConverter]::ToUInt64($bytes, 24)
    $directoryOffset = [BitConverter]::ToUInt64($bytes, 32)
    if ($directoryOffset + 4 -gt $bytes.Length) { return $false }
    $count = [BitConverter]::ToUInt32($bytes, [int]$directoryOffset)
    $position = [int]$directoryOffset + 4
    for ($entry = 0; $entry -lt $count; $entry++) {
        if ($position + 4 -gt $bytes.Length) { return $false }
        $pathLength = [BitConverter]::ToUInt32($bytes, $position)
        $position += 4
        if ($position + $pathLength + 36 -gt $bytes.Length) { return $false }
        $entryPath = [System.Text.Encoding]::UTF8.GetString(
            $bytes, $position, [int]$pathLength
        ).TrimEnd([char[]]@([char]0))
        $position += [int]$pathLength
        $entryOffset = [BitConverter]::ToUInt64($bytes, $position)
        $entrySize = [BitConverter]::ToUInt64($bytes, $position + 8)
        $position += 36
        if ($entryPath -ne 'project.binary') { continue }
        $dataOffset = $fileBase + $entryOffset
        if ($entrySize -lt 4 -or $dataOffset + 4 -gt $bytes.Length) { return $false }
        $dataIndex = [int]$dataOffset
        return (
            $bytes[$dataIndex] -eq 0x45 -and $bytes[$dataIndex + 1] -eq 0x43 -and
            $bytes[$dataIndex + 2] -eq 0x46 -and $bytes[$dataIndex + 3] -eq 0x47
        )
    }
    return $false
}

function New-PckFixture([string]$path, [string]$entryPath, [byte[]]$data) {
    $fileBase = 64
    $directoryOffset = $fileBase + $data.Length
    $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($entryPath + [char]0)
    $entrySize = 4 + $pathBytes.Length + 8 + 8 + 16 + 4
    $totalSize = $directoryOffset + 4 + $entrySize
    $bytes = New-Object byte[] $totalSize
    [System.Text.Encoding]::ASCII.GetBytes('GDPC').CopyTo($bytes, 0)
    [BitConverter]::GetBytes([uint32]4).CopyTo($bytes, 4)
    [BitConverter]::GetBytes([uint32]4).CopyTo($bytes, 8)
    [BitConverter]::GetBytes([uint32]7).CopyTo($bytes, 12)
    [BitConverter]::GetBytes([uint32]0).CopyTo($bytes, 16)
    [BitConverter]::GetBytes([uint32]0).CopyTo($bytes, 20)
    [BitConverter]::GetBytes([uint64]$fileBase).CopyTo($bytes, 24)
    [BitConverter]::GetBytes([uint64]$directoryOffset).CopyTo($bytes, 32)
    [BitConverter]::GetBytes([uint32]1).CopyTo($bytes, $directoryOffset)
    $position = $directoryOffset + 4
    [BitConverter]::GetBytes([uint32]$pathBytes.Length).CopyTo($bytes, $position)
    $position += 4
    [Array]::Copy($pathBytes, 0, $bytes, $position, $pathBytes.Length)
    $position += $pathBytes.Length
    [BitConverter]::GetBytes([uint64]0).CopyTo($bytes, $position)
    [BitConverter]::GetBytes([uint64]$data.Length).CopyTo($bytes, $position + 8)
    $position += 36
    if ($data.Length -gt 0) {
        [Array]::Copy($data, 0, $bytes, $fileBase, $data.Length)
    }
    [System.IO.File]::WriteAllBytes($path, $bytes)
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
    if (-not (Test-PathOverlap 'D:\' 'D:\staging')) {
        throw 'Drive-root overlap was not detected.'
    }
    if (Test-PathOverlap 'D:\' 'C:\staging') {
        throw 'Drive-root overlap crossed unrelated drives.'
    }
    if (-not (Test-PathOverlap '\\?\D:\staging' 'D:\staging\project')) {
        throw 'Extended-length drive overlap was not detected.'
    }
    if (-not (Test-PathOverlap '\\?\UNC\server\share' '\\server\share\project')) {
        throw 'Extended-length UNC overlap was not detected.'
    }
    $volumePathRejected = $false
    try {
        Test-PathOverlap '\\?\Volume{00000000-0000-0000-0000-000000000000}\repo' 'C:\repo' | Out-Null
    } catch {
        $volumePathRejected = $true
    }
    if (-not $volumePathRejected) {
        throw 'Volume GUID path was not rejected.'
    }
    $devicePathRejected = $false
    try {
        Test-PathOverlap '\\.\C:\repo' 'C:\repo' | Out-Null
    } catch {
        $devicePathRejected = $true
    }
    if (-not $devicePathRejected) {
        throw 'Device namespace path was not rejected.'
    }
    $pckFixture = Join-Path $env:TEMP ('brucelee-pck-fixture-' + [guid]::NewGuid().ToString('N'))
    New-PckFixture $pckFixture 'other.bin' ([byte[]](0x45, 0x43, 0x46, 0x47))
    if (Test-PckProjectSettings $pckFixture) {
        throw 'PCK without project.binary was accepted.'
    }
    New-PckFixture $pckFixture 'project.binary' ([byte[]]@())
    if (Test-PckProjectSettings $pckFixture) {
        throw 'Empty project.binary fixture was accepted.'
    }
    New-PckFixture $pckFixture 'project.binary' ([byte[]](0x45, 0x43, 0x46, 0x47))
    if (-not (Test-PckProjectSettings $pckFixture)) {
        throw 'ECFG project.binary fixture was rejected.'
    }
    Remove-Item -LiteralPath $pckFixture -Force -ErrorAction SilentlyContinue
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
if (($godotTempFull -match '^[A-Za-z]:[\\/]?$') -or
        ($godotTempFull -match '^\\\\[^\\]+\\[^\\]+[\\/]?$')) {
    throw 'GodotTempRoot must not be a drive or UNC share root.'
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
if (-not (Test-PckProjectSettings $exportedPck.FullName)) {
    throw 'Exported PCK lacks binary project settings; check GodotTempRoot.'
}

Copy-Item -LiteralPath $exported.FullName -Destination $delivered -Force
Copy-Item -LiteralPath $exportedPck.FullName -Destination (Join-Path $dist 'DragonWarrior_PC_Prototype.pck') -Force

if (-not [string]::IsNullOrWhiteSpace($RuntimeAssetRoot)) {
    if (-not (Test-Path -LiteralPath $RuntimeAssetRoot -PathType Container)) {
        throw "RuntimeAssetRoot does not exist: $RuntimeAssetRoot"
    }
    foreach ($name in @('audio', 'menu', 'scene', 'ui')) {
        $source = Join-Path $RuntimeAssetRoot $name
        if (Test-Path -LiteralPath $source -PathType Container) {
            Copy-Item -LiteralPath $source -Destination $dist -Recurse -Force
        }
    }
    foreach ($name in @('launch.ps1', 'DragonWarrior_TempleYardB.cmd')) {
        $source = Join-Path $RuntimeAssetRoot $name
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $dist $name) -Force
        }
    }
}

Write-Host "Built: $delivered"
Write-Host 'Reminder: This is a combat prototype, not the complete original game.'
