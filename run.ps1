<#
.SYNOPSIS
  Lucky5 consolidated run script.
  Starts the .NET API server (with in-memory store) and optionally the web client.

.PARAMETER Client
  Client target: "none" (API only) | "web" (default) | "godot" | "flutter-windows" | "flutter-chrome"

.PARAMETER Port
  API port (default: 5051).

.PARAMETER SkipServer
  Skip starting the .NET API (if already running).

.EXAMPLE
  .\run.ps1
  .\run.ps1 -Client web -Port 8080
  .\run.ps1 -Client none -Port 5000
#>
param(
    [ValidateSet("none", "web", "godot", "flutter-windows", "flutter-chrome", "flutter-edge")]
    [string]$Client = "web",
    [int]$Port = 5051,
    [switch]$SkipServer
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$apiProject = "$root\server\src\Lucky5.Api\Lucky5.Api.csproj"

Write-Host ""
Write-Host "=== Lucky5 v7 Server ===" -ForegroundColor Cyan
Write-Host "  Port    : $Port"
Write-Host "  Client  : $Client"
Write-Host "  URL     : http://localhost:$Port"
Write-Host ""

# ── 1. Start API ───────────────────────────────────────────────────────────
$apiProcess = $null
if (-not $SkipServer) {
    Write-Host "[1/2] Starting Lucky5.Api on http://localhost:$Port ..." -ForegroundColor Yellow
    $env:PORT = "$Port"
    $env:ASPNETCORE_ENVIRONMENT = "Development"

    $apiProcess = Start-Process -PassThru -NoNewWindow `
        -FilePath "dotnet" `
        -ArgumentList "run", "--project", $apiProject,
                       "--no-launch-profile" `
        -WorkingDirectory "$root\server\src\Lucky5.Api"

    Write-Host "  API PID: $($apiProcess.Id)"

    Write-Host "  Waiting for localhost:$Port ..." -NoNewline
    $deadline = (Get-Date).AddSeconds(90)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("localhost", $Port)
            $tcp.Close()
            $ready = $true
            break
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if ($ready) {
        Write-Host " ready." -ForegroundColor Green
    } else {
        Write-Warning " timed out waiting for port $Port."
    }
} else {
    Write-Host "[1/2] Skipping server (flag set)." -ForegroundColor DarkGray
}

# ── 2. Launch client ───────────────────────────────────────────────────────
if ($Client -eq "none") {
    Write-Host "[2/2] API-only mode. Server running at http://localhost:$Port" -ForegroundColor Green
    Write-Host "  Admin login: admin / admin123"
    Write-Host "  Test login:  tester / password"
    Write-Host ""
    Write-Host "  Press Ctrl+C to stop."
    if ($apiProcess) {
        Wait-Process -Id $apiProcess.Id
    }
} elseif ($Client -eq "web") {
    Write-Host "[2/2] Launching web cabinet..." -ForegroundColor Yellow
    Push-Location "$root\src\web"
    try {
        if (-not (Test-Path "node_modules")) {
            Write-Host "  Installing dependencies..." -ForegroundColor DarkGray
            if (Get-Command pnpm -ErrorAction SilentlyContinue) {
                pnpm install --frozen-lockfile
            } else {
                npm install
            }
        }
        $env:LUCKY5_API_ORIGIN = "http://localhost:$Port"
        $env:NEXT_EXPORT = ""  # force dev mode with rewrites
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            pnpm run dev
        } else {
            npm run dev
        }
    } finally {
        Pop-Location
    }
} elseif ($Client -like "godot*") {
    Write-Host "[2/2] Launching Godot cabinet..." -ForegroundColor Yellow
    $godotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot4" }
    $env:LUCKY5_API_BASE_URL = "http://127.0.0.1:$Port"
    & $godotBin --path "$root\godot\cabinet"
} elseif ($Client -like "flutter-*") {
    Write-Host "[2/2] Launching Flutter client..." -ForegroundColor Yellow
    $flutterTarget = ($Client -replace 'flutter-', '')
    Push-Location "$root\client"
    try {
        flutter pub get
        if ($flutterTarget -eq "windows") {
            flutter run -d windows `
                --dart-define=API_BASE_URL=http://localhost:$Port `
                --dart-define=HUB_URL=http://localhost:$Port/CarrePokerGameHub
        } else {
            flutter run -d $flutterTarget `
                --dart-define=API_BASE_URL=http://localhost:$Port `
                --dart-define=HUB_URL=http://localhost:$Port/CarrePokerGameHub `
                --web-port 5173
        }
    } finally {
        Pop-Location
    }
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
if ($apiProcess -and -not $apiProcess.HasExited) {
    Write-Host ""
    Write-Host "Stopping API process ($($apiProcess.Id))..." -ForegroundColor DarkGray
    $apiProcess.Kill()
}
Write-Host "Done." -ForegroundColor Green