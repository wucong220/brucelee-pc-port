param(
    [Parameter(Mandatory = $true)]
    [string]$CandidateGlb,
    [Parameter(Mandatory = $true)]
    [string]$TextureRoot,
    [string]$GodotExe = "C:\Tools\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Python = "py -3.12"
)

$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$godotProject = Join-Path $repoRoot "godot"

function Resolve-ExternalPath([string]$Value, [string]$Label) {
    $resolved = [IO.Path]::GetFullPath($Value)
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "$Label does not exist: $resolved"
    }
    $prefix = $repoRoot.TrimEnd('\') + '\'
    if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
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
    Invoke-Checked "Candidate textures" {
        & $GodotExe --headless --path $godotProject `
            --script res://tests/validate_candidate_textures.gd -- $CandidateGlb
    }
    Invoke-Checked "End-to-end combat candidate" {
        & $GodotExe --headless --path $godotProject `
            --script res://tests/validate_combat_candidate.gd -- $CandidateGlb $TextureRoot
    }
}
finally {
    Pop-Location
}

Write-Host "CANDIDATE_VALIDATION=PASS"
