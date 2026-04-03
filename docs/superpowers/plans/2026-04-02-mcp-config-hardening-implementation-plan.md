# MCP Config Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a generated, launcher-backed MCP configuration workflow that keeps every current server, removes inline secrets from the maintained source configuration, and makes startup failures diagnosable and recoverable.

**Architecture:** Store the normalized server inventory in `scripts/mcp/server-manifest.psd1`, load it through `scripts/mcp/common.ps1`, generate the external `C:\Users\Gabi\.verdent\mcp.json` with `scripts/mcp/write-verdent-config.ps1`, and route stdio servers through `scripts/mcp/launch-server.ps1`. Add `scripts/mcp/check.ps1` and `scripts/mcp/preflight.ps1` so runtime prerequisites, env vars, and local endpoints are validated before the MCP client is opened.

**Tech Stack:** PowerShell 7, JSON, Windows environment variables, Docker CLI, Node/npm/npx, Python virtualenv launchers, `uvx`, Git.

---

## File Structure

**Create:**

- `scripts/mcp/.env.mcp.example` — example env file documenting all required secrets and toggles.
- `scripts/mcp/common.ps1` — shared path, manifest, env-loading, command-resolution, launch-plan, and readiness helpers.
- `scripts/mcp/server-manifest.psd1` — normalized server inventory for all current MCP servers.
- `scripts/mcp/write-verdent-config.ps1` — generates `C:\Users\Gabi\.verdent\mcp.json` from the manifest.
- `scripts/mcp/launch-server.ps1` — stdio wrapper that resolves and launches the real server runtime.
- `scripts/mcp/check.ps1` — readiness and validation script.
- `scripts/mcp/preflight.ps1` — optional startup helper before opening the MCP client.
- `scripts/mcp/tests/EnvTemplate.Tests.ps1` — validates ignored env file and template contents.
- `scripts/mcp/tests/Manifest.Tests.ps1` — validates manifest completeness and secret hygiene.
- `scripts/mcp/tests/ConfigGeneration.Tests.ps1` — validates generated config shape and no inline secret leakage.
- `scripts/mcp/tests/LaunchServer.Tests.ps1` — validates resolved runtime plans and masked previews.
- `scripts/mcp/tests/Readiness.Tests.ps1` — validates readiness-report output.

**Modify:**

- `.gitignore` — ignore `scripts/mcp/.env.mcp`.
- `scripts/mcp/common.ps1` — expanded in later tasks with launch-plan and readiness helpers.

**Generate outside repo:**

- `C:\Users\Gabi\.verdent\mcp.json` — final client-consumed config written by `scripts/mcp/write-verdent-config.ps1`.

---

### Task 1: Secure local secrets input and ignore local env state

**Files:**
- Create: `scripts/mcp/.env.mcp.example`
- Create: `scripts/mcp/tests/EnvTemplate.Tests.ps1`
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing env-template test**

```powershell
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
```

- [ ] **Step 2: Run the env-template test to verify it fails**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/EnvTemplate.Tests.ps1
```

Expected: FAIL with either `Expected scripts/mcp/.env.mcp to be ignored in .gitignore` or `Expected scripts/mcp/.env.mcp.example to exist`.

- [ ] **Step 3: Update `.gitignore` to ignore the local MCP env file**

Add this line under the existing local env section in `.gitignore`:

```gitignore
scripts/mcp/.env.mcp
```

- [ ] **Step 4: Add `scripts/mcp/.env.mcp.example`**

```dotenv
# Copy this file to scripts/mcp/.env.mcp and fill in your local values.
# The launcher loads scripts/mcp/.env.mcp if present and does not overwrite
# variables that are already set in the current process or user environment.

GITHUB_PERSONAL_ACCESS_TOKEN=
GITHUB_TOOLSETS=
GITHUB_READ_ONLY=0

SENTRY_AUTH_TOKEN=
NOTION_API_TOKEN=
E2B_API_KEY=

# Optional overrides
MCP_AGENT_MAESTRO_URL=http://localhost:23334/mcp
MCP_AI_AGENTS_SWISS_KNIFE_BASE_URL=http://127.0.0.1:8000
```

- [ ] **Step 5: Run the env-template test to verify it passes**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/EnvTemplate.Tests.ps1
```

Expected: PASS with `Env template tests passed`.

- [ ] **Step 6: Commit the secure env scaffolding**

```powershell
git add .gitignore scripts/mcp/.env.mcp.example scripts/mcp/tests/EnvTemplate.Tests.ps1
git commit -m "chore: add MCP env template scaffolding"
```

---

### Task 2: Add the normalized MCP manifest and shared helper layer

**Files:**
- Create: `scripts/mcp/common.ps1`
- Create: `scripts/mcp/server-manifest.psd1`
- Create: `scripts/mcp/tests/Manifest.Tests.ps1`

- [ ] **Step 1: Write the failing manifest test**

```powershell
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
$missing = $expectedKeys | Where-Object { $_ -notin $actualKeys }
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
    if ($serialized -like "*$needle*") {
        throw "Manifest contains inline secret marker '$needle'"
    }
}

Write-Host 'Manifest tests passed'
```

- [ ] **Step 2: Run the manifest test to verify it fails**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/Manifest.Tests.ps1
```

Expected: FAIL because `scripts/mcp/common.ps1` and `scripts/mcp/server-manifest.psd1` do not exist yet.

- [ ] **Step 3: Add the initial shared helper file `scripts/mcp/common.ps1`**

```powershell
Set-StrictMode -Version Latest

function Get-McpRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-McpScriptsRoot {
    return (Join-Path (Get-McpRepoRoot) 'scripts\mcp')
}

function Get-McpManifestPath {
    return (Join-Path (Get-McpScriptsRoot) 'server-manifest.psd1')
}

function Get-McpEnvFilePath {
    return (Join-Path (Get-McpScriptsRoot) '.env.mcp')
}

function Get-McpServerManifest {
    if (-not $script:McpServerManifest) {
        $script:McpServerManifest = Import-PowerShellDataFile (Get-McpManifestPath)
    }

    return $script:McpServerManifest
}

function Get-McpServerDefinition {
    param(
        [Parameter(Mandatory)]
        [string]$ServerKey
    )

    $manifest = Get-McpServerManifest
    if (-not $manifest.Servers.Contains($ServerKey)) {
        throw "Unknown MCP server key '$ServerKey'"
    }

    return $manifest.Servers[$ServerKey]
}

function Import-McpLocalEnvironment {
    param(
        [string]$EnvFilePath = (Get-McpEnvFilePath)
    )

    if (-not (Test-Path $EnvFilePath)) {
        return
    }

    foreach ($line in Get-Content $EnvFilePath) {
        if ($line -match '^\s*(#|$)') {
            continue
        }

        $name, $value = $line -split '=', 2
        $name = $name.Trim()
        $value = if ($null -ne $value) { $value.Trim() } else { '' }

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

function Resolve-Executable {
    param(
        [Parameter(Mandatory)]
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return $command.Source
        }
    }

    throw "Unable to find executable. Checked: $($Candidates -join ', ')"
}

function Test-McpHttpEndpoint {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [int]$TimeoutSeconds = 3
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing
        return [pscustomobject]@{
            Reachable  = $true
            StatusCode = [int]$response.StatusCode
            Message    = 'OK'
        }
    }
    catch {
        return [pscustomobject]@{
            Reachable  = $false
            StatusCode = $null
            Message    = $_.Exception.Message
        }
    }
}
```

- [ ] **Step 4: Add the normalized server manifest `scripts/mcp/server-manifest.psd1`**

```powershell
@{
    Servers = [ordered]@{
        filesystem = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@modelcontextprotocol\server-filesystem\dist\index.js'
            Args        = @('C:\Users\Gabi')
            AlwaysAllow = @('search_files', 'edit_file', 'read_multiple_files')
            Disabled    = $false
        }

        playwright = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@playwright\mcp\cli.js'
            Args        = @()
            AlwaysAllow = @(
                'browser_close',
                'browser_resize',
                'browser_console_messages',
                'browser_handle_dialog',
                'browser_evaluate',
                'browser_file_upload',
                'browser_fill_form',
                'browser_install',
                'browser_type',
                'browser_navigate',
                'browser_navigate_back',
                'browser_take_screenshot',
                'browser_network_requests',
                'browser_snapshot',
                'browser_click',
                'browser_drag',
                'browser_hover',
                'browser_select_option',
                'browser_tabs'
            )
            Disabled    = $false
        }

        memory = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@modelcontextprotocol\server-memory\dist\index.js'
            Args        = @()
            Disabled    = $false
        }

        sequentialthinking = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@modelcontextprotocol\server-sequential-thinking\dist\index.js'
            Args        = @()
            AlwaysAllow = @('sequentialthinking')
            Disabled    = $false
        }

        context7 = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@upstash\context7-mcp\dist\index.js'
            Args        = @()
            Disabled    = $false
        }

        'ai-agents-swiss-knife' = @{
            Mode        = 'Launcher'
            Runtime     = 'Python'
            CommandPath = 'C:\Users\Gabi\.codex\ai-agents-swiss-knife\.venv\Scripts\python.exe'
            Args        = @('C:\Users\Gabi\.codex\ai-agents-swiss-knife\server\mcp_bridge.py')
            EnvMap      = @{
                MCP_BASE_URL          = '${MCP_AI_AGENTS_SWISS_KNIFE_BASE_URL}'
                MCP_AUTOSTART_BACKEND = '1'
            }
            OptionalEnv = @{
                MCP_AI_AGENTS_SWISS_KNIFE_BASE_URL = 'http://127.0.0.1:8000'
            }
            Disabled    = $true
            AlwaysAllow = @()
        }

        'Agent Maestro' = @{
            Mode         = 'Endpoint'
            TransportType = 'streamable-http'
            Url          = '${MCP_AGENT_MAESTRO_URL}'
            OptionalEnv  = @{
                MCP_AGENT_MAESTRO_URL = 'http://localhost:23334/mcp'
            }
            AlwaysAllow  = @('Execute Roo Tasks')
            Timeout      = 900
            Disabled     = $false
            HealthUrl    = '${MCP_AGENT_MAESTRO_URL}'
        }

        github = @{
            Mode        = 'Launcher'
            Runtime     = 'Docker'
            Args        = @(
                'run',
                '-i',
                '--rm',
                '-e', 'GITHUB_PERSONAL_ACCESS_TOKEN',
                '-e', 'GITHUB_TOOLSETS',
                '-e', 'GITHUB_READ_ONLY',
                'ghcr.io/github/github-mcp-server'
            )
            RequiredEnv = @('GITHUB_PERSONAL_ACCESS_TOKEN')
            OptionalEnv = @{
                GITHUB_TOOLSETS  = ''
                GITHUB_READ_ONLY = '0'
            }
            Disabled    = $false
            AlwaysAllow = @()
        }

        sentry = @{
            Mode        = 'Launcher'
            Runtime     = 'Uvx'
            Args        = @('mcp-server-sentry', '--auth-token', '${SENTRY_AUTH_TOKEN}')
            RequiredEnv = @('SENTRY_AUTH_TOKEN')
            Disabled    = $false
        }

        notion = @{
            Mode        = 'Launcher'
            Runtime     = 'Npx'
            Args        = @('@notionhq/notion-mcp-server')
            RequiredEnv = @('NOTION_API_TOKEN')
            EnvMap      = @{
                OPENAPI_MCP_HEADERS = '{"Authorization":"Bearer ${NOTION_API_TOKEN}","Notion-Version":"2022-06-28"}'
            }
            Disabled    = $false
        }

        e2b = @{
            Mode        = 'Launcher'
            Runtime     = 'Npx'
            Args        = @('@e2b/mcp-server')
            RequiredEnv = @('E2B_API_KEY')
            EnvMap      = @{
                E2B_API_KEY = '${E2B_API_KEY}'
            }
            Disabled    = $false
        }

        firebase = @{
            Mode     = 'Launcher'
            Runtime  = 'Npx'
            Args     = @('firebase-tools@14.15.2', 'experimental:mcp')
            Disabled = $false
        }

        'ida-pro' = @{
            Mode     = 'Launcher'
            Runtime  = 'Uvx'
            Args     = @('--from', 'git+https://github.com/mrexodia/ida-pro-mcp.git@f0af9fba733fb60fc13365b297b10c82db3771d7', 'ida-pro-mcp')
            Disabled = $false
        }

        'n8n-mcp' = @{
            Mode     = 'Launcher'
            Runtime  = 'Npx'
            Args     = @('n8n-mcp@2.12.2')
            EnvMap   = @{
                MCP_MODE               = 'stdio'
                LOG_LEVEL              = 'error'
                DISABLE_CONSOLE_OUTPUT = 'true'
            }
            Disabled = $false
        }

        puppeteer = @{
            Mode     = 'Launcher'
            Runtime  = 'Npx'
            Args     = @('@modelcontextprotocol/server-puppeteer')
            Disabled = $false
        }
    }
}
```

- [ ] **Step 5: Run the manifest test to verify it passes**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/Manifest.Tests.ps1
```

Expected: PASS with `Manifest tests passed`.

- [ ] **Step 6: Commit the manifest layer**

```powershell
git add scripts/mcp/common.ps1 scripts/mcp/server-manifest.psd1 scripts/mcp/tests/Manifest.Tests.ps1
git commit -m "feat: add MCP manifest and shared helpers"
```

---

### Task 3: Generate the external Verdent MCP config from the manifest

**Files:**
- Create: `scripts/mcp/write-verdent-config.ps1`
- Create: `scripts/mcp/tests/ConfigGeneration.Tests.ps1`
- Generate: `C:\Users\Gabi\.verdent\mcp.json`

- [ ] **Step 1: Write the failing config-generation test**

```powershell
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

$missing = $expectedKeys | Where-Object { $_ -notin $actualKeys }
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
```

- [ ] **Step 2: Run the config-generation test to verify it fails**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/ConfigGeneration.Tests.ps1
```

Expected: FAIL because `scripts/mcp/write-verdent-config.ps1` does not exist yet.

- [ ] **Step 3: Add the generator `scripts/mcp/write-verdent-config.ps1`**

```powershell
param(
    [string]$OutputPath = 'C:\Users\Gabi\.verdent\mcp.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'common.ps1')

Import-McpLocalEnvironment
$manifest = Get-McpServerManifest
$pwshPath = Resolve-Executable @('pwsh.exe', 'pwsh')
$launchScript = Join-Path (Get-McpScriptsRoot) 'launch-server.ps1'

function Resolve-ManifestString {
    param([string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    return ([regex]::Replace($Value, '\$\{([^}]+)\}', {
        param($match)
        $name = $match.Groups[1].Value
        $current = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not [string]::IsNullOrWhiteSpace($current)) {
            return $current.Trim()
        }

        foreach ($server in $manifest.Servers.Values) {
            if ($server.OptionalEnv -and $server.OptionalEnv.Contains($name)) {
                return [string]$server.OptionalEnv[$name]
            }
        }

        throw "Missing value for placeholder ${$name} while generating config"
    }))
}

$servers = [ordered]@{}
foreach ($key in $manifest.Servers.Keys) {
    $server = $manifest.Servers[$key]

    if ($server.Mode -eq 'Launcher') {
        $entry = [ordered]@{
            command = $pwshPath
            args    = @('-NoLogo', '-NoProfile', '-File', $launchScript, '-ServerKey', $key)
        }

        if ($server.Contains('Timeout')) {
            $entry.timeout = [int]$server.Timeout
        }

        if ($server.Contains('Disabled')) {
            $entry.disabled = [bool]$server.Disabled
        }

        if ($server.Contains('AlwaysAllow') -and $server.AlwaysAllow.Count -gt 0) {
            $entry.alwaysAllow = @($server.AlwaysAllow)
        }

        $servers[$key] = $entry
        continue
    }

    if ($server.Mode -eq 'Endpoint') {
        $entry = [ordered]@{
            type = $server.TransportType
            url  = Resolve-ManifestString $server.Url
        }

        if ($server.Contains('AlwaysAllow') -and $server.AlwaysAllow.Count -gt 0) {
            $entry.alwaysAllow = @($server.AlwaysAllow)
        }

        if ($server.Contains('Timeout')) {
            $entry.timeout = [int]$server.Timeout
        }

        if ($server.Contains('Disabled')) {
            $entry.disabled = [bool]$server.Disabled
        }

        $servers[$key] = $entry
        continue
    }

    throw "Unsupported manifest Mode '$($server.Mode)' for '$key'"
}

$payload = [ordered]@{
    mcpServers = $servers
}

$outputDirectory = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$json = $payload | ConvertTo-Json -Depth 20
Set-Content -Path $OutputPath -Value $json -Encoding UTF8
Write-Host "Wrote MCP config to $OutputPath"
```

- [ ] **Step 4: Run the config-generation test to verify it passes**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/ConfigGeneration.Tests.ps1
```

Expected: PASS with `Config generation tests passed`.

- [ ] **Step 5: Generate the real Verdent config**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/write-verdent-config.ps1
```

Expected: PASS with `Wrote MCP config to C:\Users\Gabi\.verdent\mcp.json`.

- [ ] **Step 6: Commit the config generator**

```powershell
git add scripts/mcp/write-verdent-config.ps1 scripts/mcp/tests/ConfigGeneration.Tests.ps1
git commit -m "feat: generate external MCP config from manifest"
```

---

### Task 4: Implement the shared launcher and masked dry-run resolution

**Files:**
- Create: `scripts/mcp/launch-server.ps1`
- Create: `scripts/mcp/tests/LaunchServer.Tests.ps1`
- Modify: `scripts/mcp/common.ps1`

- [ ] **Step 1: Write the failing launcher test**

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$launcher = Join-Path $repoRoot 'scripts\mcp\launch-server.ps1'

$env:SENTRY_AUTH_TOKEN = '  sentry-token  '
$env:GITHUB_PERSONAL_ACCESS_TOKEN = 'github-test-token'

$previewJson = & pwsh -NoLogo -NoProfile -File $launcher -ServerKey sentry -ResolveOnly
$preview = $previewJson | ConvertFrom-Json -Depth 20
$joinedPreviewArgs = [string]::Join(' ', [string[]]$preview.ArgsPreview)

if ($preview.Command -notmatch 'uvx(\.exe)?$') {
    throw 'Expected sentry preview to resolve to uvx'
}

if ($joinedPreviewArgs -notmatch '--auth-token \*\*\*set\*\*\*') {
    throw 'Expected masked auth token preview for sentry'
}

if ($joinedPreviewArgs -match 'sentry-token') {
    throw 'Launcher preview leaked the raw Sentry token'
}

$filesystemJson = & pwsh -NoLogo -NoProfile -File $launcher -ServerKey filesystem -ResolveOnly
$filesystem = $filesystemJson | ConvertFrom-Json -Depth 20
if ($filesystem.Command -notmatch 'node(\.exe)?$') {
    throw 'Expected filesystem preview to resolve to node'
}

if (-not ([string[]]$filesystem.ArgsPreview -contains 'C:\Users\Gabi')) {
    throw 'filesystem preview should retain the home-path argument'
}

Write-Host 'Launcher tests passed'
```

- [ ] **Step 2: Run the launcher test to verify it fails**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/LaunchServer.Tests.ps1
```

Expected: FAIL because `scripts/mcp/launch-server.ps1` and launch-plan helpers do not exist yet.

- [ ] **Step 3: Extend `scripts/mcp/common.ps1` with launch-plan helpers**

Append these functions to `scripts/mcp/common.ps1`:

```powershell
function Expand-McpTemplateValue {
    param(
        [Parameter(Mandatory)]
        $Value,

        [hashtable]$FallbackValues = @{}
    )

    if ($Value -is [string]) {
        return ([regex]::Replace($Value, '\$\{([^}]+)\}', {
            param($match)
            $name = $match.Groups[1].Value
            $current = [Environment]::GetEnvironmentVariable($name, 'Process')
            if (-not [string]::IsNullOrWhiteSpace($current)) {
                return $current.Trim()
            }

            if ($FallbackValues.ContainsKey($name)) {
                return [string]$FallbackValues[$name]
            }

            throw "Missing value for placeholder ${$name}"
        }))
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[$key] = Expand-McpTemplateValue -Value $Value[$key] -FallbackValues $FallbackValues
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $result = @()
        foreach ($item in $Value) {
            $result += Expand-McpTemplateValue -Value $item -FallbackValues $FallbackValues
        }
        return $result
    }

    return $Value
}

function Resolve-McpLaunchPlan {
    param(
        [Parameter(Mandatory)]
        [string]$ServerKey
    )

    Import-McpLocalEnvironment
    $server = Get-McpServerDefinition -ServerKey $ServerKey
    if ($server.Mode -ne 'Launcher') {
        throw "Server '$ServerKey' is not launcher-backed"
    }

    $fallbackValues = @{}
    if ($server.OptionalEnv) {
        foreach ($name in $server.OptionalEnv.Keys) {
            $fallbackValues[$name] = [string]$server.OptionalEnv[$name]
        }
    }

    $secretValues = @()
    foreach ($requiredName in @($server.RequiredEnv)) {
        $value = [Environment]::GetEnvironmentVariable($requiredName, 'Process')
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Server '$ServerKey' requires environment variable $requiredName"
        }

        $secretValues += $value.Trim()
    }

    $command = switch ($server.Runtime) {
        'NodeScript' { Resolve-Executable @('node.exe', 'node') }
        'Npx'        { Resolve-Executable @('npx.cmd', 'npx') }
        'Python'     {
            if (-not (Test-Path $server.CommandPath)) {
                throw "Python executable not found at $($server.CommandPath)"
            }
            $server.CommandPath
        }
        'Uvx'        { Resolve-Executable @('uvx.exe', 'uvx') }
        'Docker'     { Resolve-Executable @('docker.exe', 'docker') }
        default      { throw "Unsupported runtime '$($server.Runtime)' for '$ServerKey'" }
    }

    $args = switch ($server.Runtime) {
        'NodeScript' { @($server.CommandPath) + @($server.Args) }
        'Npx'        { @('-y') + @($server.Args) }
        default      { @($server.Args) }
    }

    $resolvedArgs = [string[]](Expand-McpTemplateValue -Value $args -FallbackValues $fallbackValues)
    $resolvedEnv = [ordered]@{}
    foreach ($name in $fallbackValues.Keys) {
        if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
            $resolvedEnv[$name] = [string]$fallbackValues[$name]
        }
    }

    if ($server.EnvMap) {
        $expandedEnv = Expand-McpTemplateValue -Value $server.EnvMap -FallbackValues $fallbackValues
        foreach ($name in $expandedEnv.Keys) {
            $resolvedEnv[$name] = [string]$expandedEnv[$name]
        }
    }

    return [pscustomobject]@{
        ServerKey   = $ServerKey
        Command     = $command
        Args        = $resolvedArgs
        Environment = $resolvedEnv
        SecretValues = $secretValues
    }
}

function Get-MaskedPreviewValues {
    param(
        [string[]]$Values,
        [string[]]$SecretValues
    )

    $masked = @()
    foreach ($value in $Values) {
        $next = $value
        foreach ($secret in $SecretValues) {
            if (-not [string]::IsNullOrWhiteSpace($secret) -and $next.Contains($secret)) {
                $next = $next.Replace($secret, '***set***')
            }
        }
        $masked += $next
    }

    return $masked
}

function Get-MaskedPreviewEnvironment {
    param(
        [hashtable]$Environment,
        [string[]]$SecretValues
    )

    $preview = [ordered]@{}
    foreach ($name in $Environment.Keys) {
        $value = [string]$Environment[$name]
        $preview[$name] = if ($SecretValues -contains $value) { '***set***' } else { $value }
    }

    return $preview
}
```

- [ ] **Step 4: Add `scripts/mcp/launch-server.ps1`**

```powershell
param(
    [Parameter(Mandatory)]
    [string]$ServerKey,

    [switch]$ResolveOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'common.ps1')

Import-McpLocalEnvironment
$plan = Resolve-McpLaunchPlan -ServerKey $ServerKey

if ($ResolveOnly) {
    [pscustomobject]@{
        ServerKey  = $plan.ServerKey
        Command    = $plan.Command
        ArgsPreview = Get-MaskedPreviewValues -Values $plan.Args -SecretValues $plan.SecretValues
        EnvPreview = Get-MaskedPreviewEnvironment -Environment $plan.Environment -SecretValues $plan.SecretValues
    } | ConvertTo-Json -Depth 20
    exit 0
}

foreach ($name in $plan.Environment.Keys) {
    [Environment]::SetEnvironmentVariable($name, [string]$plan.Environment[$name], 'Process')
}

& $plan.Command @($plan.Args)
exit $LASTEXITCODE
```

- [ ] **Step 5: Run the launcher test to verify it passes**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/LaunchServer.Tests.ps1
```

Expected: PASS with `Launcher tests passed`.

- [ ] **Step 6: Commit the launcher layer**

```powershell
git add scripts/mcp/common.ps1 scripts/mcp/launch-server.ps1 scripts/mcp/tests/LaunchServer.Tests.ps1
git commit -m "feat: add MCP launcher runtime resolution"
```

---

### Task 5: Add readiness checks, preflight, and the end-to-end operator workflow

**Files:**
- Create: `scripts/mcp/check.ps1`
- Create: `scripts/mcp/preflight.ps1`
- Create: `scripts/mcp/tests/Readiness.Tests.ps1`
- Modify: `scripts/mcp/common.ps1`

- [ ] **Step 1: Write the failing readiness test**

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$checkScript = Join-Path $repoRoot 'scripts\mcp\check.ps1'

$json = & pwsh -NoLogo -NoProfile -File $checkScript -Format Json -NoFail
$results = $json | ConvertFrom-Json -Depth 20

foreach ($requiredKey in @('filesystem', 'github', 'Agent Maestro')) {
    if ($requiredKey -notin [string[]]$results.ServerKey) {
        throw "Readiness output is missing '$requiredKey'"
    }
}

$github = $results | Where-Object ServerKey -eq 'github' | Select-Object -First 1
if (-not ('GITHUB_PERSONAL_ACCESS_TOKEN' -in [string[]]$github.RequiredEnv)) {
    throw 'Expected github readiness to report GITHUB_PERSONAL_ACCESS_TOKEN as required'
}

Write-Host 'Readiness tests passed'
```

- [ ] **Step 2: Run the readiness test to verify it fails**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/Readiness.Tests.ps1
```

Expected: FAIL because `scripts/mcp/check.ps1` and readiness helpers do not exist yet.

- [ ] **Step 3: Extend `scripts/mcp/common.ps1` with readiness helpers**

Append these functions to `scripts/mcp/common.ps1`:

```powershell
function Test-McpServerReadiness {
    param(
        [Parameter(Mandatory)]
        [string]$ServerKey
    )

    Import-McpLocalEnvironment
    $server = Get-McpServerDefinition -ServerKey $ServerKey
    $result = [ordered]@{
        ServerKey    = $ServerKey
        Mode         = $server.Mode
        Disabled     = [bool]($server.Disabled)
        Ready        = $false
        RequiredEnv  = @($server.RequiredEnv)
        Message      = ''
    }

    if ($server.Mode -eq 'Endpoint') {
        $healthUrl = Expand-McpTemplateValue -Value $server.HealthUrl -FallbackValues ($server.OptionalEnv ?? @{})
        $status = Test-McpHttpEndpoint -Url $healthUrl
        $result.Ready = [bool]$status.Reachable
        $result.Message = if ($status.Reachable) { "Endpoint reachable ($($status.StatusCode))" } else { $status.Message }
        return [pscustomobject]$result
    }

    try {
        $null = Resolve-McpLaunchPlan -ServerKey $ServerKey
        $result.Ready = $true
        $result.Message = 'Ready'
    }
    catch {
        $result.Ready = $false
        $result.Message = $_.Exception.Message
    }

    return [pscustomobject]$result
}
```

- [ ] **Step 4: Add `scripts/mcp/check.ps1`**

```powershell
param(
    [ValidateSet('Table', 'Json')]
    [string]$Format = 'Table',

    [switch]$NoFail
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'common.ps1')

Import-McpLocalEnvironment
$manifest = Get-McpServerManifest
$results = foreach ($key in $manifest.Servers.Keys) {
    Test-McpServerReadiness -ServerKey $key
}

if ($Format -eq 'Json') {
    $results | ConvertTo-Json -Depth 20
}
else {
    $results | Sort-Object ServerKey | Format-Table ServerKey, Mode, Disabled, Ready, Message -AutoSize
}

if (-not $NoFail) {
    $blocking = $results | Where-Object { -not $_.Disabled -and -not $_.Ready }
    if ($blocking.Count -gt 0) {
        exit 1
    }
}
```

- [ ] **Step 5: Add `scripts/mcp/preflight.ps1`**

```powershell
param(
    [switch]$NoFail,
    [switch]$RegenerateConfig,
    [string]$OutputPath = 'C:\Users\Gabi\.verdent\mcp.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($RegenerateConfig) {
    & pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'write-verdent-config.ps1') -OutputPath $OutputPath
}

$json = & pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'check.ps1') -Format Json -NoFail
$results = $json | ConvertFrom-Json -Depth 20

$results | Sort-Object ServerKey | Format-Table ServerKey, Mode, Disabled, Ready, Message -AutoSize

if (-not $NoFail) {
    $blocking = $results | Where-Object { -not $_.Disabled -and -not $_.Ready }
    if ($blocking.Count -gt 0) {
        throw "Preflight failed for: $($blocking.ServerKey -join ', ')"
    }
}
```

- [ ] **Step 6: Run the readiness test to verify it passes**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/Readiness.Tests.ps1
```

Expected: PASS with `Readiness tests passed`.

- [ ] **Step 7: Run the full operator workflow against the real external config**

Run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/preflight.ps1 -RegenerateConfig -NoFail
```

Expected:
- `C:\Users\Gabi\.verdent\mcp.json` is regenerated.
- Each server is listed with `Ready` plus a clear `Message`.
- Any missing runtime, env var, or endpoint is reported per server instead of failing silently.

- [ ] **Step 8: Commit the readiness tooling**

```powershell
git add scripts/mcp/common.ps1 scripts/mcp/check.ps1 scripts/mcp/preflight.ps1 scripts/mcp/tests/Readiness.Tests.ps1
git commit -m "feat: add MCP readiness checks and preflight"
```

---

## Final Verification Checklist

- [ ] Run all MCP PowerShell tests:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/EnvTemplate.Tests.ps1
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/Manifest.Tests.ps1
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/ConfigGeneration.Tests.ps1
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/LaunchServer.Tests.ps1
pwsh -NoLogo -NoProfile -File scripts/mcp/tests/Readiness.Tests.ps1
```

Expected: every script prints a `... tests passed` message and exits `0`.

- [ ] Regenerate the real external config:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/write-verdent-config.ps1
```

Expected: `Wrote MCP config to C:\Users\Gabi\.verdent\mcp.json`.

- [ ] Run the readiness table before opening the MCP client:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/check.ps1 -NoFail
```

Expected: a per-server readiness table with no silent failures.

- [ ] If you want regeneration plus readiness in one command, run:

```powershell
pwsh -NoLogo -NoProfile -File scripts/mcp/preflight.ps1 -RegenerateConfig -NoFail
```

Expected: regenerated config plus the same readiness report.

---

## Spec Coverage Self-Check

- **Keep every existing server entry:** covered by `scripts/mcp/server-manifest.psd1` and `scripts/mcp/tests/Manifest.Tests.ps1` in [Task 2](#task-2-add-the-normalized-mcp-manifest-and-shared-helper-layer).
- **Remove inline credentials and source them from environment variables:** covered by `scripts/mcp/.env.mcp.example`, placeholder-based manifest values, and launcher expansion in [Task 1](#task-1-secure-local-secrets-input-and-ignore-local-env-state) and [Task 4](#task-4-implement-the-shared-launcher-and-masked-dry-run-resolution).
- **Make startup safer across Node, Python, Docker, `uvx`, and endpoints:** covered by `Resolve-McpLaunchPlan`, `check.ps1`, and `preflight.ps1` in [Task 4](#task-4-implement-the-shared-launcher-and-masked-dry-run-resolution) and [Task 5](#task-5-add-readiness-checks-preflight-and-the-end-to-end-operator-workflow).
- **Fix malformed arguments and pinned executable paths:** covered by runtime resolution and trimmed env expansion in [Task 4](#task-4-implement-the-shared-launcher-and-masked-dry-run-resolution).
- **Add verification tooling:** covered by `scripts/mcp/tests/*.ps1`, `check.ps1`, and `preflight.ps1` in [Tasks 1-5](#task-1-secure-local-secrets-input-and-ignore-local-env-state).
- **Generated config layer:** covered by `scripts/mcp/write-verdent-config.ps1` and `scripts/mcp/tests/ConfigGeneration.Tests.ps1` in [Task 3](#task-3-generate-the-external-verdent-mcp-config-from-the-manifest).

