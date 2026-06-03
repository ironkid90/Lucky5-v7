<#
.SYNOPSIS
  Lucky5 local dev launcher.
  Starts the in-memory .NET API on :5051, then launches the selected client.
  No Docker required — the server uses an in-memory store.

.PARAMETER Client
  Client target: "godot" (default) | "web" | "flutter-windows" | "flutter-chrome" | "flutter-edge"

.PARAMETER SkipServer
  Skip starting the .NET API (if already running on :5051).

.EXAMPLE
  .\dev.ps1
  .\dev.ps1 -Client web
  .\dev.ps1 -SkipServer
#>
param(
    [ValidateSet("godot", "web", "flutter-windows", "flutter-chrome", "flutter-edge")]
    [string]$Client = "godot",
    [switch]$SkipServer
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# ── Helpers ──────────────────────────────────────────────────────────────────
function Assert-Command([string]$name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "'$name' not found in PATH. Please install it and re-run."
        exit 1
    }
}

function Wait-Port([int]$port, [int]$timeoutSec = 60) {
    Write-Host "  Waiting for localhost:$port ..." -NoNewline
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect("localhost", $port)
            $tcp.Close()
            Write-Host " ready." -ForegroundColor Green
            return
        } catch { Start-Sleep -Milliseconds 500 }
    }
    Write-Warning " timed out waiting for port $port."
}

# ── Pre-flight checks ─────────────────────────────────────────────────────────
Assert-Command "dotnet"

$needsGodot = ($Client -eq "godot")
$needsFlutter = ($Client -like "flutter-*")
$needsWeb = ($Client -eq "web")

if ($needsGodot) {
    $godotBin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "godot" }
    Assert-Command $godotBin
}
if ($needsFlutter) {
    Assert-Command "flutter"
}
if ($needsWeb) {
    Assert-Command "pnpm"
}

Write-Host ""
Write-Host "=== Lucky5 Dev Launcher ===" -ForegroundColor Cyan
Write-Host "  Client : $Client"
Write-Host "  Skip Server : $SkipServer"
Write-Host ""

# ── 1. .NET API ────────────────────────────────────────────────────────────
$apiProcess = $null
if (-not $SkipServer) {
    Write-Host "[1/3] Starting Lucky5.Api on http://localhost:5051 ..." -ForegroundColor Yellow
    $apiProject = "$root\server\src\Lucky5.Api\Lucky5.Api.csproj"
    $env:PORT = "5051"
    $apiProcess = Start-Process -PassThru -NoNewWindow `
        -FilePath "dotnet" `
        -ArgumentList "run", "--project", $apiProject,
                       "--no-launch-profile",
                       "--environment", "Development" `
        -WorkingDirectory "$root\server\src\Lucky5.Api"
    Write-Host "  API PID: $($apiProcess.Id)"
    Wait-Port 5051 90
} else {
    Write-Host "[1/3] Skipping server (flag set)." -ForegroundColor DarkGray
}

# ── 2. Client prep ────────────────────────────────────────────────────────
if ($needsGodot) {
    Write-Host "[2/3] Godot cabinet (no package install needed)." -ForegroundColor DarkGray
} elseif ($needsFlutter) {
    Write-Host "[2/3] Running flutter pub get..." -ForegroundColor Yellow
    Push-Location "$root\client"
    try {
        flutter pub get
    } finally {
        Pop-Location
    }
} elseif ($needsWeb) {
    Write-Host "[2/3] Running pnpm install..." -ForegroundColor Yellow
    Push-Location "$root\src\web"
    try {
        pnpm install --frozen-lockfile
    } finally {
        Pop-Location
    }
}

# ── 3. Launch client ──────────────────────────────────────────────────────
Write-Host "[3/3] Launching $Client client..." -ForegroundColor Yellow

if ($needsGodot) {
    $env:LUCKY5_API_BASE_URL = "http://127.0.0.1:5051"
    if (-not $env:LUCKY5_ACCESS_TOKEN) {
        Write-Warning "LUCKY5_ACCESS_TOKEN is not set. Godot will boot in fixture/auth mode."
    }
    & $godotBin --path "$root\godot\cabinet"
} elseif ($needsFlutter) {
    $flutterTarget = ($Client -replace 'flutter-', '')
    Push-Location "$root\client"
    try {
        if ($flutterTarget -eq "windows") {
            flutter run -d windows `
                --dart-define=API_BASE_URL=http://localhost:5051 `
                --dart-define=HUB_URL=http://localhost:5051/CarrePokerGameHub
        } else {
            flutter run -d $flutterTarget `
                --dart-define=API_BASE_URL=http://localhost:5051 `
                --dart-define=HUB_URL=http://localhost:5051/CarrePokerGameHub `
                --web-port 5173
        }
    } finally {
        Pop-Location
    }
} elseif ($needsWeb) {
    Push-Location "$root\src\web"
    try {
        $env:LUCKY5_API_ORIGIN = "http://localhost:5051"
        pnpm run dev
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