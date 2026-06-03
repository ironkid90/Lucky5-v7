<#
.SYNOPSIS
  Lucky5 v7 — 1-Click Launcher.
  Starts the .NET API server with the full graphics web cabinet and Godot client.

.PARAMETER Godot
  Also launch the Godot cabinet client (requires Godot 4.6+).

.PARAMETER Headless
  API only — no browser, no Godot.

.PARAMETER Port
  API port (default: 5051).

.EXAMPLE
  .\dev.ps1                 # Server + open web cabinet in browser
  .\dev.ps1 -Godot          # Server + web + Godot cabinet
  .\dev.ps1 -Headless -Port 8080  # API only

Admin login: admin / admin123
Test login:  tester / password
#>
param(
    [switch]$Godot,
    [switch]$Headless,
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Lucky5 v7 — Full Graphics Cabinet" -ForegroundColor Cyan
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

if (-not $Headless) {
    Write-Host "[2/3] Opening web cabinet in browser..." -ForegroundColor Yellow
    Start-Process "http://localhost:$Port"
    Write-Host "  Full graphics cabinet loaded in browser." -ForegroundColor Green
} else {
    Write-Host "[2/3] Headless mode — API only." -ForegroundColor DarkGray
}

if ($Godot) {
    Write-Host "[3/3] Launching Godot cabinet..." -ForegroundColor Yellow
    $godotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } elseif (Get-Command godot -ErrorAction SilentlyContinue) { "godot" } else { "godot4" }
    Assert-Command $godotBin
    $env:LUCKY5_API_BASE_URL = "http://127.0.0.1:$Port"
    if (-not $env:LUCKY5_ACCESS_TOKEN) {
        Write-Warning "LUCKY5_ACCESS_TOKEN not set. Godot will use fixture/auth mode."
    }
    & $godotBin --path "$root\godot\cabinet"
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