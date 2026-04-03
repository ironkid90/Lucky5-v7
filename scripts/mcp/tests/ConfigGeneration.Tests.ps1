$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$generator = Join-Path $repoRoot 'scripts\mcp\write-verdent-config.ps1'
$tempOutput = Join-Path $env:TEMP 'verdent.mcp.generated.json'

if (Test-Path $tempOutput) {
    Remove-Item $tempOutput -Force
}

& pwsh -NoLogo -NoProfile -File $generator -OutputPath $tempOutput | Out-Null

$config = Get-Content $tempOutput -Raw | ConvertFrom-Json -Depth 20
$actualKeys = [string[]]$config.mcpServers.PSObject.Properties.Name
$expectedKeys = @(
    'filesystem',
    'playwright',
    'memory',
    'sequentialthinking',
    'context7',
    'ai-agents-swiss-knife',
    'Agent Maestro',
    'github',
    'sentry',
    'notion',
    'e2b',
    'firebase',
    'ida-pro',
    'n8n-mcp',
    'puppeteer'
)

$missing = @($expectedKeys | Where-Object { $_ -notin $actualKeys })
if ($missing.Count -gt 0) {
    throw "Generated config missing keys: $($missing -join ', ')"
}

$raw = Get-Content $tempOutput -Raw
foreach ($needle in @('github_pat_', 'sntrys_', 'ntn_', 'e2b_')) {
    if ($raw -like "*$needle*") {
        throw "Generated config leaked secret marker '$needle'"
    }
}

if ($config.mcpServers.filesystem.command -notmatch 'pwsh(\.exe)?$') {
    throw 'filesystem.command should be pwsh or pwsh.exe'
}

if (-not ($config.mcpServers.filesystem.args -contains '-ServerKey')) {
    throw 'filesystem.args should route through launch-server.ps1'
}

if ($config.mcpServers.'Agent Maestro'.url -ne 'http://localhost:23334/mcp') {
    throw 'Agent Maestro URL should come from the default override when env is absent'
}

Write-Host 'Config generation tests passed'
