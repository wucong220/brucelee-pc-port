param(
    [Parameter(Mandatory = $true)]
    [string]$CandidateGlb,
    [Parameter(Mandatory = $true)]
    [string]$TextureRoot,
    [string]$GodotExe = "C:\Tools\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Python = "py -3.12"
)

$ErrorActionPreference = "Stop"
$lexicalRepoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = $lexicalRepoRoot
$godotProject = Join-Path $repoRoot "godot"
$pathResolver = Join-Path $repoRoot "godot\tools\resolve_candidate_path.ps1"

function Resolve-CanonicalPath([string]$Value) {
    $resolved = & $pathResolver -LiteralPath $Value
    if (-not $?) {
        throw "Could not resolve path: $Value"
    }
    return ([string]$resolved).Trim()
}

function Assert-OutsideRepositoryLexically([string]$Value, [string]$Label) {
    $prefix = $lexicalRepoRoot.TrimEnd('\') + '\'
    if ($Value.Equals($lexicalRepoRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $Value.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must remain outside the repository: $Value"
    }
}

function Resolve-ExternalPath([string]$Value, [string]$Label) {
    $resolved = [IO.Path]::GetFullPath($Value)
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "$Label does not exist: $resolved"
    }
    Assert-OutsideRepositoryLexically $resolved $Label
    $resolved = Resolve-CanonicalPath $resolved
    $prefix = $repoRoot.TrimEnd('\') + '\'
    if ($resolved.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must remain outside the repository: $resolved"
    }
    return $resolved
}

function Invoke-Checked([string]$Label, [scriptblock]$Command) {
    Write-Host "== $Label =="
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

function Test-CandidatePathBoundary {
    $token = [Guid]::NewGuid().ToString('N')
    $repositoryFixture = Join-Path $repoRoot ".path-guard-cli-fixture-$token"
    $externalFixture = Join-Path ([IO.Path]::GetTempPath()) "brucelee-path-guard-cli-$token"
    $externalFile = Join-Path $externalFixture "candidate.glb"
    $junction = Join-Path $repositoryFixture "external-junction"
    New-Item -ItemType Directory -Path $repositoryFixture | Out-Null
    New-Item -ItemType Directory -Path $externalFixture | Out-Null
    New-Item -ItemType File -Path $externalFile | Out-Null
    New-Item -ItemType Junction -Path $junction -Target $externalFixture | Out-Null
    try {
        try {
            Resolve-ExternalPath (Join-Path $junction "candidate.glb") `
                "Candidate path guard self-test" | Out-Null
            throw "Candidate path guard accepted a lexically internal junction"
        }
        catch {
            if ($_.Exception.Message -notlike "*must remain outside the repository*") {
                throw
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $junction) {
            Remove-Item -LiteralPath $junction -Force
        }
        if (Test-Path -LiteralPath $externalFile) {
            Remove-Item -LiteralPath $externalFile -Force
        }
        if (Test-Path -LiteralPath $externalFixture) {
            Remove-Item -LiteralPath $externalFixture -Force
        }
        if (Test-Path -LiteralPath $repositoryFixture) {
            Remove-Item -LiteralPath $repositoryFixture -Force
        }
    }
}

$repoRoot = Resolve-CanonicalPath $repoRoot
$godotProject = Join-Path $repoRoot "godot"
$pathResolver = Join-Path $repoRoot "godot\tools\resolve_candidate_path.ps1"
Test-CandidatePathBoundary
$CandidateGlb = Resolve-ExternalPath $CandidateGlb "Candidate GLB"
$TextureRoot = Resolve-ExternalPath $TextureRoot "Texture root"
$GodotExe = (Resolve-Path -LiteralPath $GodotExe).Path

Push-Location $repoRoot
try {
    $pythonParts = $Python -split '\s+', 2
    $pythonExe = Get-Command $pythonParts[0] -ErrorAction Stop
    $pythonArgs = @()
    if ($pythonParts.Count -eq 2) {
        $pythonArgs = $pythonParts[1] -split '\s+'
    }
    Invoke-Checked "Python tests" {
        & $pythonExe.Source @pythonArgs -X utf8 -B -m unittest discover -s tests -p "test*.py" -q
    }

    Invoke-Checked "Godot import" {
        & $GodotExe --headless --editor --path $godotProject --quit
    }
    Invoke-Checked "Prototype smoke" {
        & $GodotExe --headless --path $godotProject --script res://tests/smoke_test.gd
    }
    Invoke-Checked "Candidate animation" {
        & $GodotExe --headless --path $godotProject `
            --script res://tests/validate_candidate_animation.gd -- $CandidateGlb --expect-hair
    }
    Invoke-Checked "Synthetic texture material binding" {
        & $GodotExe --headless --path $godotProject `
            --script res://tests/validate_candidate_textures.gd -- $CandidateGlb
    }
    Invoke-Checked "Real texture and combat candidate" {
        & $GodotExe --headless --path $godotProject `
            --script res://tests/validate_combat_candidate.gd -- $CandidateGlb $TextureRoot
    }
}
finally {
    Pop-Location
}

Write-Host "CANDIDATE_VALIDATION=PASS"
