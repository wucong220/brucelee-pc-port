param(
    [Parameter(Mandatory = $true)]
    [string] $PackageDir
)

$ErrorActionPreference = 'Stop'

$voiceSource = Join-Path $PackageDir 'audio\bruce_lee'
if (-not (Test-Path -LiteralPath $voiceSource)) {
    throw "Package voice source not found: $voiceSource"
}

$voiceRoot = Join-Path $env:LOCALAPPDATA 'BruceLee-PC-Port\bruce-voice-20261103\adreno_200\sounds\voices\bruce_lee'
New-Item -ItemType Directory -Force $voiceRoot | Out-Null
Copy-Item (Join-Path $voiceSource '*') $voiceRoot -Recurse -Force
Write-Host "Voice staged to: $voiceRoot"
