[CmdletBinding()]
param(
    [string]$GodotProjectPath = 'godot/cabinet',

    [string]$GodotBin = $env:GODOT_BIN,

    [int]$QuitAfterFrames = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $command = Get-Command godot, godot4, Godot_v4.6-stable_win64.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) {
        $GodotBin = $command.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotBin) -or -not (Test-Path -LiteralPath $GodotBin)) {
    throw 'Set GODOT_BIN or pass -GodotBin with the pinned Godot executable path.'
}

if (-not (Test-Path -LiteralPath $GodotProjectPath)) {
    throw "Godot project path not found: $GodotProjectPath"
}

$godotPath = (Resolve-Path -LiteralPath $GodotBin).Path
$projectPath = (Resolve-Path -LiteralPath $GodotProjectPath).Path

$versionOutput = & $godotPath --version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Godot --version failed: $($versionOutput -join [Environment]::NewLine)"
}

$launchOutput = & $godotPath --headless --path $projectPath --quit-after $QuitAfterFrames 2>&1
$exitCode = $LASTEXITCODE
$launchText = $launchOutput -join [Environment]::NewLine
$significantLaunchLines = @(
    foreach ($line in $launchOutput) {
        $text = [string]$line
        if ($text -match '^(ERROR|WARNING): \d+ RID allocations of type .+ were leaked at exit\.$') {
            continue
        }
        if ($text -match '^WARNING: \d+ RIDs of type ".+" were leaked\.$') {
            continue
        }
        if ($text -match '^WARNING: ObjectDB instances leaked at exit') {
            continue
        }
        if ($text -match '^\s*at: (_free_rids|cleanup) \(') {
            continue
        }
        $text
    }
)
$significantLaunchText = $significantLaunchLines -join [Environment]::NewLine

if ($exitCode -ne 0) {
    throw "Godot headless launch failed with exit code $exitCode.$([Environment]::NewLine)$launchText"
}

if ($significantLaunchText -match '(?m)^(SCRIPT ERROR|ERROR):') {
    throw "Godot headless launch emitted errors.$([Environment]::NewLine)$launchText"
}

[ordered]@{
    schema_version = 'lucky5.godot_smoke.v1'
    godot_version = ($versionOutput -join [Environment]::NewLine).Trim()
    project_path = $GodotProjectPath.Replace('\', '/')
    quit_after_frames = $QuitAfterFrames
    ignored_shutdown_diagnostics = ($launchOutput.Count - $significantLaunchLines.Count)
    status = 'passed'
} | ConvertTo-Json -Depth 4
