$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\common.ps1')

$manifest = Get-McpServerManifest
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

$actualKeys = [string[]]$manifest.Servers.Keys
$missing = @($expectedKeys | Where-Object { $_ -notin $actualKeys })
if ($missing.Count -gt 0) {
    throw "Missing server definitions: $($missing -join ', ')"
}

foreach ($key in $expectedKeys) {
    $server = $manifest.Servers[$key]
    if (-not $server.Mode) {
        throw "Server '$key' is missing Mode"
    }

    if ($server.Mode -eq 'Launcher' -and -not $server.Runtime) {
        throw "Launcher server '$key' is missing Runtime"
    }
}

$serialized = $manifest | ConvertTo-Json -Depth 20
foreach ($needle in @('github_pat_', 'sntrys_', 'ntn_', 'e2b_')) {
    if ($serialized -clike "*$needle*") {
        throw "Manifest contains inline secret marker '$needle'"
    }
}

Write-Host 'Manifest tests passed'
