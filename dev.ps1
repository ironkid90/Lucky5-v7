<#
.SYNOPSIS
  Lucky5 v7 dev launcher — Godot + .NET API.
  Starts the in-memory .NET API server, then launches the Godot cabinet client.

.PARAMETER SkipServer
  Skip starting the .NET API (if already running on :5051).

.PARAMETER Headless
  Start API only without launching the Godot client.

.EXAMPLE
  .\dev.ps1                      # Full: API + Godot cabinet
  .\dev.ps1 -SkipServer          # Godot only (API already running)
  .\dev.ps1 -Headless            # API only, no client

Admin login: admin / admin123
Test login:  tester / password
#>
param(
    [switch]$SkipServer,
    [switch]$Headless
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$port = 5051

function Assert-Command([string]$name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "'$name' not found in PATH. Install it and re-run."
        exit 1
    }
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

$godotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }
if (-not $Headless) {
    $foundGodot = Assert-Command $godotBin 2>$null -or (Get-Command $godotBin -ErrorAction SilentlyContinue)
    if (-not $foundGodot) {
        $godotBin = "godot4"
        Assert-Command $godotBin
    }
}

Write-Host ""
Write-Host "=== Lucky5 v7 — Godot Cabinet ===" -ForegroundColor Cyan
Write-Host "  API: http://localhost:$port"
Write-Host "  Credentials: admin / admin123"
Write-Host ""

$apiProcess = $null

if (-not $SkipServer) {
    Write-Host "[1/2] Starting Lucky5.Api on http://localhost:$port ..." -ForegroundColor Yellow
    $env:PORT = "$port"
    $env:ASPNETCORE_ENVIRONMENT = "Development"
    $apiProject = "$root\server\src\Lucky5.Api\Lucky5.Api.csproj"

    $apiProcess = Start-Process -PassThru -NoNewWindow `
        -FilePath "dotnet" `
        -ArgumentList "run", "--project", $apiProject, "--no-launch-profile" `
        -WorkingDirectory "$root\server\src\Lucky5.Api"

    Write-Host "  API PID: $($apiProcess.Id)"
    $ready = Wait-Port $port 90
    if (-not $ready) {
        Write-Warning "Server may still be starting. Check http://localhost:$port/health/live"
    }
} else {
    Write-Host "[1/2] Skipping server (flag set)." -ForegroundColor DarkGray
}

if (-not $Headless) {
    Write-Host "[2/2] Launching Godot cabinet..." -ForegroundColor Yellow
    $env:LUCKY5_API_BASE_URL = "http://127.0.0.1:$port"
    if (-not $env:LUCKY5_ACCESS_TOKEN) {
        Write-Warning "LUCKY5_ACCESS_TOKEN not set. Godot will use fixture/auth mode."
    }
    & $godotBin --path "$root\godot\cabinet"
} else {
    Write-Host "[2/2] Headless mode. API running at http://localhost:$port" -ForegroundColor Green
    Write-Host "  Press Ctrl+C to stop."
    if ($apiProcess) { Wait-Process -Id $apiProcess.Id }
}

if ($apiProcess -and -not $apiProcess.HasExited) {
    Write-Host ""
    Write-Host "Stopping API ($($apiProcess.Id))..." -ForegroundColor DarkGray
    $apiProcess.Kill()
}
Write-Host "Done." -ForegroundColor Green