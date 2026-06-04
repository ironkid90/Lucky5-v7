[CmdletBinding()]
param(
    [string]$GodotProjectPath = 'godot/cabinet',

    [string]$GodotBin = $env:GODOT_BIN,

    [string]$PresetName = 'Web',

    [string]$OutputPath = 'src/web/public/godot-cabinet/index.html',

    [switch]$Clean
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

function Resolve-GodotExecutable {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Resolve-RequiredPath -Path $RequestedPath -Description 'Godot executable'
    }

    foreach ($name in @('godot', 'godot4', 'Godot_v4.6.3-stable_win64.exe', 'Godot_v4.6-stable_win64.exe')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw 'Set GODOT_BIN or put godot on PATH.'
}

$repoRoot = (Resolve-Path -LiteralPath '.').Path
$projectPath = Resolve-RequiredPath -Path $GodotProjectPath -Description 'Godot project path'
$exportPresetPath = Join-Path $projectPath 'export_presets.cfg'
if (-not (Test-Path -LiteralPath $exportPresetPath)) {
    throw "Godot export presets are missing: $exportPresetPath"
}

$godotPath = Resolve-GodotExecutable -RequestedPath $GodotBin
$outputFullPath = $OutputPath
if (-not [System.IO.Path]::IsPathRooted($outputFullPath)) {
    $outputFullPath = Join-Path $repoRoot $outputFullPath
}

$outputDir = Split-Path -Parent $outputFullPath
if ($Clean -and (Test-Path -LiteralPath $outputDir)) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$godotVersion = & $godotPath --version
if ($LASTEXITCODE -ne 0) {
    throw 'Godot --version failed.'
}

& $godotPath --headless --path $projectPath --export-release $PresetName $outputFullPath
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed for preset '$PresetName'."
}

Set-Content -LiteralPath (Join-Path $outputDir 'godot-version.txt') -Value ($godotVersion -join "`n") -Encoding utf8NoBOM

$buildInfo = [ordered]@{
    schema_version = 'lucky5.godot_web_export.v1'
    exported_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    godot_version = ($godotVersion -join "`n")
    godot_project_path = $GodotProjectPath.Replace('\', '/')
    export_preset = $PresetName
    output_path = (Resolve-Path -LiteralPath $outputFullPath).Path.Replace($repoRoot, '').TrimStart('\').Replace('\', '/')
    entry_url = '/godot'
    asset_url = '/godot-cabinet/index.html'
    status = 'passed'
}

$buildInfoPath = Join-Path $outputDir 'build-info.json'
$buildInfo | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $buildInfoPath -Encoding utf8NoBOM

$buildInfo | ConvertTo-Json -Depth 8
