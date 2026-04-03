$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$gitignorePath = Join-Path $repoRoot '.gitignore'
$templatePath = Join-Path $repoRoot 'scripts\mcp\.env.mcp.example'

$gitignore = if (Test-Path $gitignorePath) {
    Get-Content $gitignorePath -Raw
} else {
    ''
}

if ($gitignore -notmatch '(?m)^scripts/mcp/\.env\.mcp$') {
    throw 'Expected scripts/mcp/.env.mcp to be ignored in .gitignore'
}

if (-not (Test-Path $templatePath)) {
    throw 'Expected scripts/mcp/.env.mcp.example to exist'
}

$template = Get-Content $templatePath -Raw
$requiredKeys = @(
    'GITHUB_PERSONAL_ACCESS_TOKEN',
    'SENTRY_AUTH_TOKEN',
    'NOTION_API_TOKEN',
    'E2B_API_KEY',
    'GITHUB_TOOLSETS',
    'GITHUB_READ_ONLY'
)

foreach ($key in $requiredKeys) {
    if ($template -notmatch "(?m)^$([regex]::Escape($key))=") {
        throw "Expected $key= in scripts/mcp/.env.mcp.example"
    }
}

Write-Host 'Env template tests passed'
