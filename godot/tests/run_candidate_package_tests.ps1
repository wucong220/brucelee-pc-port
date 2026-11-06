#Requires -Version 5.1
<#
.SYNOPSIS
    Validate the stable character-candidate package layout end to end.

.DESCRIPTION
    Runs, in order, against the Godot project in this repository:

      1. a headless editor import (catches script/import errors),
      2. validate_candidate_package_manifest.gd  (data + GLB identity + config),
      3. validate_package_models_opt_in.gd       (path-guard opt-in stays narrow),
      4. capture_candidate_package_loads.gd      (real main.tscn load + screenshot
                                                  for every candidate, windowed).

    Every step appends a log under <OutDir>\logs; the load step also writes
    <OutDir>\screenshots\candidate_<id>.png and a JSON report.  The script exits
    non-zero as soon as a step fails, after writing its log.

.PARAMETER GodotExe
    Godot 4.7.2 executable (the console build gives usable stdout/exit codes).

.PARAMETER PackageRoot
    Directory that holds the stable models\ layout (the package root).  It is
    exported as BRUCELEE_PACKAGE_ROOT so the editor run resolves the same files
    the exported package will.

.PARAMETER OutDir
    Evidence directory.  logs\ and screenshots\ are created inside it.

.EXAMPLE
    .\run_candidate_package_tests.ps1 `
        -GodotExe 'C:\Tools\Godot_v4.7.2-stable_win64_console.exe' `
        -PackageRoot 'C:\private\char-candidates-integrated' `
        -OutDir 'C:\private\char-candidates-integrated\evidence'
#>
param(
    [Parameter(Mandatory = $true)][string]$GodotExe,
    [Parameter(Mandatory = $true)][string]$PackageRoot,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path $projectDir -Parent
$logDir = Join-Path $OutDir 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
New-Item -ItemType Directory -Force (Join-Path $OutDir 'screenshots') | Out-Null
$env:BRUCELEE_PACKAGE_ROOT = (Resolve-Path $PackageRoot).Path
$script:failed = $false
$script:steps = @()

function Invoke-GodotStep {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$LogName
    )
    $logPath = Join-Path $logDir $LogName
    Write-Host "== $Name"
    # Godot writes push_error/push_warning to stderr.  Windows PowerShell 5.1
    # turns native stderr into a terminating error while
    # $ErrorActionPreference='Stop', so relax it only around the native call.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $GodotExe @Arguments 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    $text = ($output | Out-String)
    Set-Content -Path $logPath -Value $text -Encoding UTF8
    Write-Host $text.TrimEnd()
    $script:steps += [pscustomobject]@{ step = $Name; exit = $code; log = $logPath }
    if ($code -ne 0) {
        Write-Host "FAILED: $Name (exit $code)"
        return $false
    }
    return $true
}

$common = @('--headless', '--path', $projectDir)
$windowed = @('--path', $projectDir, '--resolution', '1280x720')
$allStepsOk = $true

if (Invoke-GodotStep -Name 'editor import' -Arguments ($common + @('--editor', '--quit')) `
        -LogName '01_editor_import.log') {
    if (Invoke-GodotStep -Name 'package manifest + config' -Arguments (
            $common + @('--script', 'res://tests/validate_candidate_package_manifest.gd')
        ) -LogName '02_candidate_package_manifest.log') {
        if (Invoke-GodotStep -Name 'package models path-guard opt-in' -Arguments (
                $common + @('--script', 'res://tests/validate_package_models_opt_in.gd')
            ) -LogName '03_package_models_opt_in.log') {
            # One Godot process per candidate.  Importing ten 6-9 MB skinned GLBs
            # inside a single window is not reliable on this GPU (the process can
            # abort mid-run), so isolation is the documented mode; each process
            # still writes its own screenshot and case report.  A failed windowed
            # process is retried a bounded number of times and every attempt is
            # logged, so a flaky abort is visible in the logs instead of hidden.
            $manifestPath = Join-Path $projectDir 'data\candidate_package_models.json'
            $manifest = [System.IO.File]::ReadAllText(
                $manifestPath, [System.Text.Encoding]::UTF8
            ) | ConvertFrom-Json
            $caseIds = @($manifest.candidates | ForEach-Object { $_.id })
            $merged = [ordered]@{
                package_root = $env:BRUCELEE_PACKAGE_ROOT
                output_dir = $OutDir
                cases = @()
                fail_closed_checks = @()
                failures = @()
                attempts = [ordered]@{}
            }
            $maxAttempts = 3
            foreach ($caseId in $caseIds) {
                $caseReport = Join-Path $logDir "candidate_load_report_$caseId.json"
                Remove-Item $caseReport -ErrorAction SilentlyContinue
                $attempt = 0
                $ok = $false
                while (-not $ok -and $attempt -lt $maxAttempts) {
                    $attempt++
                    $logName = if ($attempt -eq 1) {
                        "04_load_$caseId.log"
                    } else {
                        "04_load_${caseId}_retry$attempt.log"
                    }
                    $ok = Invoke-GodotStep -Name "load $caseId (attempt $attempt)" -Arguments (
                        $windowed + @(
                            '--script', 'res://tests/capture_candidate_package_loads.gd',
                            '--', $OutDir, $caseId
                        )
                    ) -LogName $logName
                    if (-not $ok) {
                        Start-Sleep -Milliseconds 1500
                    }
                }
                $merged.attempts[$caseId] = $attempt
                if ($ok) {
                    if (Test-Path $caseReport) {
                        $report = [System.IO.File]::ReadAllText(
                            $caseReport, [System.Text.Encoding]::UTF8
                        ) | ConvertFrom-Json
                        $merged.cases += @($report.cases)
                        if ($merged.fail_closed_checks.Count -eq 0) {
                            $merged.fail_closed_checks = @($report.fail_closed_checks)
                        }
                        foreach ($failure in @($report.failures)) {
                            $merged.failures += "$caseId`: $failure"
                        }
                    } else {
                        $merged.failures += "$caseId`: case report was not written"
                        $allStepsOk = $false
                    }
                } else {
                    $merged.failures += "$caseId`: no successful windowed load after $maxAttempts attempts"
                    $allStepsOk = $false
                }
            }
            $mergedPath = Join-Path $logDir 'candidate_load_report.json'
            Set-Content -Path $mergedPath -Value (
                $merged | ConvertTo-Json -Depth 12
            ) -Encoding UTF8
            $loaded = @($merged.cases | Where-Object { $_.candidate_loaded }).Count
            $shots = @($merged.cases | Where-Object { $_.screenshot_ok }).Count
            Write-Host "Merged load report: $mergedPath"
            Write-Host "Candidates loaded: $loaded / $($caseIds.Count); screenshots: $shots"
            Write-Host "Attempts: $($merged.attempts | ConvertTo-Json -Compress)"
            if ($loaded -ne $caseIds.Count -or $shots -ne $caseIds.Count) {
                $allStepsOk = $false
            }
        } else {
            $allStepsOk = $false
        }
    } else {
        $allStepsOk = $false
    }
} else {
    $allStepsOk = $false
}
$script:failed = -not $allStepsOk

Write-Host ''
Write-Host 'Step summary:'
$script:steps | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

$loadReport = Join-Path $logDir 'candidate_load_report.json'
if (Test-Path $loadReport) {
    Write-Host "Load report: $loadReport"
}

if ($script:failed) {
    Write-Host 'CANDIDATE_PACKAGE_TESTS=FAILED'
    exit 1
}
Write-Host 'CANDIDATE_PACKAGE_TESTS=PASS'
exit 0
