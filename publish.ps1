<#
.SYNOPSIS
  Lucky5 consolidated publish script.
  Builds the web client (Next.js static export) and the .NET API,
  then bundles everything into a single deployable folder.

.PARAMETER OutputDir
  Target directory for the published output (default: ./publish).

.PARAMETER Configuration
  Build configuration (default: Release).

.PARAMETER SelfContained
  Publish the .NET runtime self-contained (default: $false, framework-dependent).

.PARAMETER Runtime
  Target runtime identifier for self-contained publish (default: win-x64).

.PARAMETER SkipWeb
  Skip building the web client.

.PARAMETER SkipApi
  Skip publishing the .NET API.

.EXAMPLE
  .\publish.ps1
  .\publish.ps1 -SelfContained -Runtime linux-x64
  .\publish.ps1 -OutputDir ./deploy -SkipWeb
#>
param(
    [string]$OutputDir = "publish",
    [string]$Configuration = "Release",
    [switch]$SelfContained,
    [string]$Runtime = "win-x64",
    [switch]$SkipWeb,
    [switch]$SkipApi
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$apiProject = "$root\server\src\Lucky5.Api\Lucky5.Api.csproj"
$webDir = "$root\src\web"
$wwwroot = "$OutputDir\wwwroot"

Write-Host ""
Write-Host "=== Lucky5 Consolidated Publish ===" -ForegroundColor Cyan
Write-Host "  Output     : $OutputDir"
Write-Host "  Config     : $Configuration"
Write-Host "  SelfContained : $SelfContained"
if ($SelfContained) { Write-Host "  Runtime    : $Runtime" }
Write-Host ""

# ── 1. Build web client ────────────────────────────────────────────────────
if (-not $SkipWeb) {
    Write-Host "[1/3] Building web client (Next.js static export)..." -ForegroundColor Yellow

    if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
        Write-Warning "pnpm not found, trying npm..."
        $pkgManager = "npm"
        $installCmd = "npm install"
        $buildCmd = "npm run build"
    } else {
        $pkgManager = "pnpm"
        $installCmd = "pnpm install --frozen-lockfile"
        $buildCmd = "pnpm run build"
    }

    Push-Location $webDir
    try {
        Write-Host "  Installing dependencies..." -ForegroundColor DarkGray
        Invoke-Expression $installCmd
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Retrying without frozen lockfile..." -ForegroundColor DarkYellow
            if ($pkgManager -eq "pnpm") {
                pnpm install --no-frozen-lockfile
            } else {
                npm install
            }
        }

        Write-Host "  Building static export..." -ForegroundColor DarkGray
        $env:NEXT_EXPORT = "1"
        # Use npx to avoid pnpm internal install trigger
        npx next build

        if (-not (Test-Path "out")) {
            Write-Error "Web client build failed: 'out' directory not found."
            exit 1
        }

        Write-Host "  Web client built successfully." -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[1/3] Skipping web client (flag set)." -ForegroundColor DarkGray
}

# ── 2. Publish .NET API ────────────────────────────────────────────────────
if (-not $SkipApi) {
    Write-Host "[2/3] Publishing .NET API..." -ForegroundColor Yellow

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Error ".NET SDK not found. Install from https://dotnet.microsoft.com"
        exit 1
    }

    $publishArgs = @(
        "publish", $apiProject,
        "-c", $Configuration,
        "-o", $OutputDir,
        "--no-restore:$false"
    )

    if ($SelfContained) {
        $publishArgs += "--self-contained"
        $publishArgs += "-r"
        $publishArgs += $Runtime
    }

    & dotnet @publishArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error ".NET publish failed with exit code $LASTEXITCODE"
        exit 1
    }

    Write-Host "  .NET API published successfully." -ForegroundColor Green
} else {
    Write-Host "[2/3] Skipping .NET API (flag set)." -ForegroundColor DarkGray
}

# ── 3. Bundle web client into wwwroot ──────────────────────────────────────
if (-not $SkipWeb) {
    Write-Host "[3/3] Bundling web client into wwwroot..." -ForegroundColor Yellow

    if (Test-Path $wwwroot) {
        Remove-Item -Recurse -Force $wwwroot
    }
    New-Item -ItemType Directory -Path $wwwroot -Force | Out-Null

    Copy-Item -Recurse "$webDir\out\*" $wwwroot

    Write-Host "  Web client copied to wwwroot." -ForegroundColor Green
} else {
    Write-Host "[3/3] Skipping web bundle (web build skipped)." -ForegroundColor DarkGray
}

# ── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Publish Complete ===" -ForegroundColor Green
Write-Host "  Output: $((Resolve-Path $OutputDir).Path)"
Write-Host ""
Write-Host "  To run locally:"
Write-Host "    cd $OutputDir"
Write-Host "    dotnet Lucky5.Api.dll"
Write-Host ""

if ($SelfContained) {
    $exeName = if ($Runtime -like "win*") { "Lucky5.Api.exe" } else { "Lucky5.Api" }
    Write-Host "  Or run directly:"
    Write-Host "    $OutputDir\$exeName"
    Write-Host ""
}