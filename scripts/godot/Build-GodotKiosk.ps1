[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [string]$GodotProjectPath = 'godot/cabinet',

    [string]$GodotBin = $env:GODOT_BIN,

    [string]$PresetName = 'Windows Desktop',

    [string]$ReadinessGatePath = 'tmp/readiness-gate.json',

    [string]$OutputRoot = 'artifacts/godot-kiosk',

    [string]$SigningKeyPemPath = $env:LUCKY5_MANIFEST_SIGNING_KEY_PEM_PATH,

    [switch]$SkipExport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RequiredPath {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

if (-not $SkipExport -and [string]::IsNullOrWhiteSpace($GodotBin)) {
    throw 'Set GODOT_BIN or pass -GodotBin with the pinned Godot executable path.'
}

$repoRoot = (Resolve-Path -LiteralPath '.').Path
$projectPath = Resolve-RequiredPath -Path $GodotProjectPath -Description 'Godot project path'
$readinessGateFullPath = Resolve-RequiredPath -Path $ReadinessGatePath -Description 'Readiness gate evidence'
$readinessGate = Get-Content -LiteralPath $readinessGateFullPath -Raw | ConvertFrom-Json
if ($readinessGate.approved -ne $true) {
    throw "Readiness gate is not approved. Refusing kiosk build: $readinessGateFullPath"
}

$exportPresetPath = Join-Path $projectPath 'export_presets.cfg'
if (-not $SkipExport -and -not (Test-Path -LiteralPath $exportPresetPath)) {
    throw "Godot export presets are missing: $exportPresetPath. Create/review presets in the Godot editor or provide them through CI."
}

$artifactRoot = Join-Path $repoRoot (Join-Path $OutputRoot $Version)
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

if (-not $SkipExport) {
    $godotPath = Resolve-RequiredPath -Path $GodotBin -Description 'Godot executable'
    $godotVersion = & $godotPath --version
    if ($LASTEXITCODE -ne 0) {
        throw 'Godot --version failed.'
    }

    $exportFile = Join-Path $artifactRoot 'Lucky5Cabinet.exe'
    & $godotPath --headless --path $projectPath --export-release $PresetName $exportFile
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed for preset '$PresetName'."
    }

    Set-Content -LiteralPath (Join-Path $artifactRoot 'godot-version.txt') -Value ($godotVersion -join "`n") -Encoding utf8NoBOM
}

$manifestScript = Join-Path $repoRoot 'scripts/godot/New-GodotAssetManifest.ps1'
$manifestArgs = @{
    PackageRoot = $artifactRoot
    Version = $Version
    ReadinessGatePath = $readinessGateFullPath
}

if ($SigningKeyPemPath) {
    $manifestArgs.SigningKeyPemPath = $SigningKeyPemPath
}

$manifestResult = & $manifestScript @manifestArgs
if ($LASTEXITCODE -ne 0) {
    throw 'Manifest generation failed.'
}

$buildInfo = [ordered]@{
    schema_version = 'lucky5.godot_kiosk_build.v1'
    version = $Version
    built_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    artifact_root = $artifactRoot
    godot_project_path = $GodotProjectPath.Replace('\', '/')
    export_preset = $PresetName
    readiness_gate_path = $ReadinessGatePath.Replace('\', '/')
    manifest_result = ($manifestResult | ConvertFrom-Json)
}

$buildInfoPath = Join-Path $artifactRoot 'build-info.json'
$buildInfo | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $buildInfoPath -Encoding utf8NoBOM

$buildInfo | ConvertTo-Json -Depth 8
