<#
.SYNOPSIS
  Lucky5 local dev launcher.
  Starts the in-memory .NET API on :5051, then launches the Flutter client.
  No Docker required — the server uses an in-memory store.

.PARAMETER Target
  Flutter run target: "windows" (default) | "chrome" | "edge"

.PARAMETER SkipServer
  Skip starting the .NET API (if already running on :5051).

.EXAMPLE
  .\dev.ps1
  .\dev.ps1 -Target chrome
  .\dev.ps1 -SkipServer
#>
param(
    [ValidateSet("windows", "chrome", "edge")]
    [string]$Target = "windows",
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
Assert-Command "flutter"
Write-Host ""
Write-Host "=== Lucky5 Dev Launcher ===" -ForegroundColor Cyan
Write-Host "  Flutter target : $Target"
Write-Host "  Skip Server    : $SkipServer"
Write-Host ""

# ── 1. .NET API ────────────────────────────────────────────────────────────
$apiProcess = $null
if (-not $SkipServer) {
    Write-Host "[1/3] Starting Lucky5.Api on http://localhost:5051 ..." -ForegroundColor Yellow
    $apiProject = "$root\server\src\Lucky5.Api\Lucky5.Api.csproj"
    # Program.cs reads PORT env var and calls UseUrls — that overrides --urls.
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

# ── 2. Flutter pub get ────────────────────────────────────────────────────────
Write-Host "[2/3] Running flutter pub get..." -ForegroundColor Yellow
Push-Location "$root\client"
try {
    flutter pub get
} finally {
    Pop-Location
}

# ── 3. Flutter run ────────────────────────────────────────────────────────────
Write-Host "[3/3] Launching Flutter client (-d $Target)..." -ForegroundColor Yellow
Push-Location "$root\client"
try {
    if ($Target -eq "windows") {
        flutter run -d windows `
            --dart-define=API_BASE_URL=http://localhost:5051 `
            --dart-define=HUB_URL=http://localhost:5051/CarrePokerGameHub
    } else {
        # Web: allow any localhost port the dev server picks
        flutter run -d $Target `
            --dart-define=API_BASE_URL=http://localhost:5051 `
            --dart-define=HUB_URL=http://localhost:5051/CarrePokerGameHub `
            --web-port 5173
    }
} finally {
    Pop-Location
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
if ($apiProcess -and -not $apiProcess.HasExited) {
    Write-Host ""
    Write-Host "Stopping API process ($($apiProcess.Id))..." -ForegroundColor DarkGray
    $apiProcess.Kill()
}
Write-Host "Done." -ForegroundColor Green
