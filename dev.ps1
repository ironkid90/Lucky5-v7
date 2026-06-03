<#
.SYNOPSIS
  Lucky5 v7 - 1-Click Launcher.
  Starts the .NET API server and the Godot cabinet client by default.

.PARAMETER Web
  Open the legacy static web cabinet fallback instead of launching Godot.

.PARAMETER Headless
  API only - no browser and no Godot.

.PARAMETER GodotBin
  Godot executable path or command name. Defaults to GODOT_BIN, then godot4, then godot.

.PARAMETER Port
  API port (default: 5051).

.EXAMPLE
  .\dev.ps1                 # Server + Godot cabinet
  .\dev.ps1 -Web            # Server + legacy web cabinet fallback
  .\dev.ps1 -Headless -Port 8080  # API only

Admin login: admin / admin123
Test login:  tester / password
#>
param(
    [switch]$Web,
    [switch]$Headless,
    [string]$GodotBin = $env:GODOT_BIN,
    [int]$Port = 5051
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

function Assert-Command([string]$name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "'$name' not found in PATH. Install it and re-run."
        exit 1
    }
}

function Resolve-GodotBin([string]$preferred) {
    if (-not [string]::IsNullOrWhiteSpace($preferred)) {
        return $preferred
    }

    $command = Get-Command godot4, godot, Godot_v4.6-stable_win64.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        return "godot4"
    }

    return $command.Source
}

function Wait-Port([int]$port, [int]$timeoutSec = 90) {
    Write-Host "  Waiting for localhost:$port ..." -NoNewline
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("localhost", $port)
            $tcp.Close()
            Write-Host " ready." -ForegroundColor Green
            return $true
        } catch { Start-Sleep -Milliseconds 500 }
    }
    Write-Warning " timed out."
    return $false
}

Assert-Command "dotnet"

if ($Headless -and $Web) {
    Write-Error "Use either -Headless or -Web, not both."
    exit 1
}

$launchGodot = -not $Headless -and -not $Web
if ($launchGodot) {
    $GodotBin = Resolve-GodotBin $GodotBin
    Assert-Command $GodotBin
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Lucky5 v7 - Godot Cabinet" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  URL:  http://localhost:$Port"
Write-Host "  Admin: admin / admin123"
Write-Host "  Test:  tester / password"
Write-Host ""

$apiProcess = $null

Write-Host "[1/3] Starting Lucky5.Api on http://localhost:$Port ..." -ForegroundColor Yellow
$env:PORT = "$Port"
$env:ASPNETCORE_ENVIRONMENT = "Development"
$apiProject = "$root\server\src\Lucky5.Api\Lucky5.Api.csproj"

$apiProcess = Start-Process -PassThru -NoNewWindow `
    -FilePath "dotnet" `
    -ArgumentList "run", "--project", $apiProject, "--no-launch-profile" `
    -WorkingDirectory "$root\server\src\Lucky5.Api"

Write-Host "  API PID: $($apiProcess.Id)"
$ready = Wait-Port $Port 90

if (-not $ready) {
    Write-Warning "Server may still be starting. Check http://localhost:$Port/health/live"
}

if ($Web) {
    Write-Host "[2/3] Opening legacy web cabinet fallback..." -ForegroundColor Yellow
    Start-Process "http://localhost:$Port"
    Write-Host "  Legacy web fallback loaded in browser." -ForegroundColor Green
} elseif ($launchGodot) {
    Write-Host "[2/3] Preparing Godot cabinet launch." -ForegroundColor Yellow
} else {
    Write-Host "[2/3] Headless mode - API only." -ForegroundColor DarkGray
}

if ($launchGodot) {
    Write-Host "[3/3] Launching Godot cabinet..." -ForegroundColor Yellow
    $env:LUCKY5_API_BASE_URL = "http://127.0.0.1:$Port"
    if (-not $env:LUCKY5_ACCESS_TOKEN) {
        Write-Warning "LUCKY5_ACCESS_TOKEN not set. Godot will use interactive auth or fixture mode."
    }
    $godotProjectPath = "$root\godot\cabinet"
    $godotProcess = Start-Process -FilePath $GodotBin `
        -ArgumentList @("--path", $godotProjectPath) `
        -WorkingDirectory $godotProjectPath `
        -Wait `
        -PassThru
    if ($godotProcess.ExitCode -ne 0) {
        throw "Godot exited with code $($godotProcess.ExitCode)."
    }
} else {
    Write-Host "[3/3] Server running. Press Ctrl+C to stop." -ForegroundColor Green
    if ($apiProcess) { Wait-Process -Id $apiProcess.Id }
}

if ($apiProcess -and -not $apiProcess.HasExited) {
    Write-Host ""
    Write-Host "Stopping API ($($apiProcess.Id))..." -ForegroundColor DarkGray
    $apiProcess.Kill()
}
Write-Host "Done." -ForegroundColor Green
