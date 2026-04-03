$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\common.ps1')

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-HashtableFieldValue {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [Parameter(Mandatory)]
        [string]$Field,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ((-not $Table.ContainsKey($Field)) -or [string]::IsNullOrWhiteSpace([string]$Table[$Field])) {
        throw $Message
    }
}

function Assert-HashtableArrayField {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Table,

        [Parameter(Mandatory)]
        [string]$Field,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ((-not $Table.ContainsKey($Field)) -or ($null -eq $Table[$Field]) -or (-not ($Table[$Field] -is [System.Array]))) {
        throw $Message
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()

    try {
        return ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
        $listener.Stop()
    }
}

function Remove-ProcessEnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Remove-Item -LiteralPath ("Env:{0}" -f $Name) -ErrorAction SilentlyContinue
}

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

    switch ($server.Mode) {
        'Launcher' {
            Assert-HashtableFieldValue -Table $server -Field 'Runtime' -Message "Launcher server '$key' is missing Runtime"

            switch ($server.Runtime) {
                'NodeScript' {
                    Assert-HashtableFieldValue -Table $server -Field 'CommandPath' -Message "NodeScript server '$key' is missing CommandPath"
                    Assert-HashtableArrayField -Table $server -Field 'Args' -Message "NodeScript server '$key' is missing Args"
                }
                'Python' {
                    Assert-HashtableFieldValue -Table $server -Field 'CommandPath' -Message "Python server '$key' is missing CommandPath"
                    Assert-HashtableArrayField -Table $server -Field 'Args' -Message "Python server '$key' is missing Args"
                }
                'Docker' {
                    Assert-HashtableArrayField -Table $server -Field 'Args' -Message "Docker server '$key' is missing Args"
                }
                'Npx' {
                    Assert-HashtableArrayField -Table $server -Field 'Args' -Message "Npx server '$key' is missing Args"
                }
                'Uvx' {
                    Assert-HashtableArrayField -Table $server -Field 'Args' -Message "Uvx server '$key' is missing Args"
                }
                default {
                    throw "Launcher server '$key' has unsupported Runtime '$($server.Runtime)'"
                }
            }
        }
        'Endpoint' {
            Assert-HashtableFieldValue -Table $server -Field 'TransportType' -Message "Endpoint server '$key' is missing TransportType"
            Assert-HashtableFieldValue -Table $server -Field 'Url' -Message "Endpoint server '$key' is missing Url"

            if ($server.ContainsKey('HealthUrl')) {
                Assert-HashtableFieldValue -Table $server -Field 'HealthUrl' -Message "Endpoint server '$key' is missing HealthUrl"
            }

            if ($server.ContainsKey('Timeout')) {
                Assert-True -Condition ($server.Timeout -gt 0) -Message "Endpoint server '$key' has invalid Timeout"
            }
        }
        default {
            throw "Server '$key' has unsupported Mode '$($server.Mode)'"
        }
    }
}

$envFilePath = [System.IO.Path]::GetTempFileName()
$preserveEmptyName = 'MCP_TEST_PRESERVE_EMPTY'
$importMissingName = 'MCP_TEST_IMPORT_MISSING'
[System.IO.File]::WriteAllLines($envFilePath, @(
    "$preserveEmptyName=from-file",
    "$importMissingName=imported-value"
))

try {
    [Environment]::SetEnvironmentVariable($preserveEmptyName, '', 'Process')
    Remove-ProcessEnvironmentVariable -Name $importMissingName

    Assert-True -Condition (-not (Test-Path -LiteralPath ("Env:{0}" -f $importMissingName))) -Message 'Test setup failed to clear the missing-variable regression case'

    Import-McpLocalEnvironment -EnvFilePath $envFilePath

    Assert-True -Condition ([Environment]::GetEnvironmentVariable($preserveEmptyName, 'Process') -eq '') -Message 'Import-McpLocalEnvironment overwrote an explicitly empty process variable'
    Assert-True -Condition ([Environment]::GetEnvironmentVariable($importMissingName, 'Process') -eq 'imported-value') -Message 'Import-McpLocalEnvironment did not import a missing process variable'
}
finally {
    Remove-ProcessEnvironmentVariable -Name $preserveEmptyName
    Remove-ProcessEnvironmentVariable -Name $importMissingName
    Remove-Item -LiteralPath $envFilePath -ErrorAction SilentlyContinue
}

$port = Get-FreeTcpPort
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
$listener.Start()
$serverPowerShell = [powershell]::Create()
$serverAsync = $null

try {
    $null = $serverPowerShell.AddScript({
        param($TcpListener)

        $client = $TcpListener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $buffer = New-Object byte[] 4096
            $null = $stream.Read($buffer, 0, $buffer.Length)

            $body = 'teapot body'
            $contentLength = [System.Text.Encoding]::ASCII.GetByteCount($body)
            $responseText = "HTTP/1.1 418 I'm a teapot`r`nContent-Type: text/plain`r`nContent-Length: $contentLength`r`nConnection: close`r`n`r`n$body"
            $responseBytes = [System.Text.Encoding]::ASCII.GetBytes($responseText)
            $stream.Write($responseBytes, 0, $responseBytes.Length)
            $stream.Flush()
        }
        finally {
            $client.Dispose()
            $TcpListener.Stop()
        }
    }).AddArgument($listener)
    $serverAsync = $serverPowerShell.BeginInvoke()

    $httpResult = Test-McpHttpEndpoint -Url "http://127.0.0.1:$port/"

    Assert-True -Condition (-not $httpResult.Reachable) -Message 'Test-McpHttpEndpoint reported a failing endpoint as reachable'
    Assert-True -Condition ($httpResult.StatusCode -eq 418) -Message 'Test-McpHttpEndpoint did not return the HTTP status code for a failing endpoint'
    Assert-True -Condition ($httpResult.Message -like 'HTTP 418*') -Message 'Test-McpHttpEndpoint did not include a clear HTTP failure message'
    Assert-True -Condition ($httpResult.Message -like '*teapot body*') -Message 'Test-McpHttpEndpoint did not preserve response diagnostics'
}
finally {
    if ($null -ne $serverAsync) {
        $serverPowerShell.EndInvoke($serverAsync) | Out-Null
    }

    $serverPowerShell.Dispose()
    if ($listener.Server.IsBound) {
        $listener.Stop()
    }
}

$serialized = $manifest | ConvertTo-Json -Depth 20
foreach ($needle in @('github_pat_', 'sntrys_', 'ntn_', 'e2b_')) {
    if ($serialized -clike "*$needle*") {
        throw "Manifest contains inline secret marker '$needle'"
    }
}

Write-Host 'Manifest tests passed'
