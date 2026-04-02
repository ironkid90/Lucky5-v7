Set-StrictMode -Version Latest

$script:McpServerManifest = $null

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
