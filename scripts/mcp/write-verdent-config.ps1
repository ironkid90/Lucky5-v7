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
            if ($server.Contains('OptionalEnv') -and $server.OptionalEnv.Contains($name)) {
                return [string]$server.OptionalEnv[$name]
            }
        }

        throw "Missing value for placeholder `${$name} while generating config"
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
