param(
    [Parameter(Mandatory = $true)]
    [string]$CandidateGlb,
    [Parameter(Mandatory = $true)]
    [string]$TextureRoot,
    [string]$GodotExe = "C:\Tools\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$SkipBuild,
    [switch]$ExpectReactionClips
)

$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$buildScript = Join-Path $repoRoot "build_windows.ps1"
$dist = Join-Path $repoRoot "dist"
$exe = Join-Path $dist "DragonWarrior_PC_Prototype.exe"
$pck = Join-Path $dist "DragonWarrior_PC_Prototype.pck"

if (-not $SkipBuild) {
    & $buildScript -GodotExe $GodotExe
    if ($LASTEXITCODE -ne 0) {
        throw "Windows export failed with exit code $LASTEXITCODE"
    }
}
if (-not (Test-Path -LiteralPath $exe) -or
        -not (Test-Path -LiteralPath $pck)) {
    throw "Expected Windows export files are missing from: $dist"
}

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$validationRoot = [IO.Path]::GetFullPath(
    (Join-Path $tempRoot (
        "BruceLee-EXE-Validation-$PID-$([Guid]::NewGuid().ToString('N'))"
    ))
)
if (-not $validationRoot.StartsWith(
        $tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create validation directory outside the temporary root"
}
New-Item -ItemType Directory -Path $validationRoot | Out-Null
Copy-Item -LiteralPath $exe -Destination $validationRoot
Copy-Item -LiteralPath $pck -Destination $validationRoot
$isolatedExe = Join-Path $validationRoot (Split-Path -Leaf $exe)
$stdout = Join-Path $validationRoot "self-test.stdout.txt"
$stderr = Join-Path $validationRoot "self-test.stderr.txt"

$oldSelfTest = $env:BRUCELEE_EXPORT_SELF_TEST
$oldGlb = $env:BRUCELEE_PLAYER_GLB
$oldTextureRoot = $env:BRUCELEE_PLAYER_TEXTURE_ROOT
try {
    $env:BRUCELEE_EXPORT_SELF_TEST = "1"
    $env:BRUCELEE_PLAYER_GLB = [IO.Path]::GetFullPath($CandidateGlb)
    $env:BRUCELEE_PLAYER_TEXTURE_ROOT = [IO.Path]::GetFullPath($TextureRoot)
    $process = Start-Process -FilePath $isolatedExe `
        -ArgumentList "--headless" `
        -WorkingDirectory $validationRoot `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    $output = Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue
    $errors = Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue
    Write-Host $output
    if (-not [string]::IsNullOrWhiteSpace($errors)) {
        Write-Host $errors
    }
    if ($process.ExitCode -ne 0) {
        throw "Exported EXE self-test failed with exit code $($process.ExitCode)"
    }
    $match = [regex]::Match($output, 'EXPORT_SELF_TEST=(\{.*\})')
    if (-not $match.Success) {
        throw "Exported EXE did not produce EXPORT_SELF_TEST output"
    }
    $report = $match.Groups[1].Value | ConvertFrom-Json
    if (-not $report.candidate_textures_loaded -or
            -not $report.internal_path_rejected -or
            [math]::Abs([double]$report.punch_target_health - 95.0) -gt 0.001) {
        throw "Exported EXE self-test reported an invalid candidate/combat result"
    }
    if ($ExpectReactionClips -and $report.reaction_clip -ne "all_impct_light_frnt_mid") {
        throw "Exported EXE self-test did not select the candidate reaction clip"
    }
    if ([double]$report.candidate_world_height -lt 1.5 -or
            [double]$report.candidate_world_height -gt 1.9 -or
            [math]::Abs([double]$report.candidate_world_min_y) -gt 0.02) {
        throw "Exported EXE self-test reported invalid visual bounds"
    }
}
finally {
    if ($null -eq $oldSelfTest) {
        Remove-Item Env:BRUCELEE_EXPORT_SELF_TEST -ErrorAction SilentlyContinue
    } else {
        $env:BRUCELEE_EXPORT_SELF_TEST = $oldSelfTest
    }
    if ($null -eq $oldGlb) {
        Remove-Item Env:BRUCELEE_PLAYER_GLB -ErrorAction SilentlyContinue
    } else {
        $env:BRUCELEE_PLAYER_GLB = $oldGlb
    }
    if ($null -eq $oldTextureRoot) {
        Remove-Item Env:BRUCELEE_PLAYER_TEXTURE_ROOT -ErrorAction SilentlyContinue
    } else {
        $env:BRUCELEE_PLAYER_TEXTURE_ROOT = $oldTextureRoot
    }
    if (Test-Path -LiteralPath $validationRoot) {
        Remove-Item -LiteralPath $validationRoot -Recurse -Force
    }
}

Write-Host "WINDOWS_EXE_VALIDATION=PASS"
