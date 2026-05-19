[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReadinessGatePath,

    [string]$SigningKeyPemPath = $env:LUCKY5_MANIFEST_SIGNING_KEY_PEM_PATH,

    [string]$ManifestPath,

    [string]$SignaturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RequiredPath {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function ConvertTo-CanonicalJson {
    param([Parameter(Mandatory = $true)] $Value)

    return ($Value | ConvertTo-Json -Depth 16 -Compress)
}

function Get-GitValue {
    param([Parameter(Mandatory = $true)] [string[]]$Arguments)

    try {
        $value = & git @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }

        return ($value -join "`n").Trim()
    }
    catch {
        return $null
    }
}

$packageRootPath = Resolve-RequiredPath -Path $PackageRoot -Description 'Package root'
$readinessGateFullPath = Resolve-RequiredPath -Path $ReadinessGatePath -Description 'Readiness gate evidence'

$readinessGate = Get-Content -LiteralPath $readinessGateFullPath -Raw | ConvertFrom-Json
if ($readinessGate.approved -ne $true) {
    throw "Readiness gate is not approved. Refusing to create a release manifest: $readinessGateFullPath"
}

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $packageRootPath 'asset-manifest.json'
}

if (-not $SignaturePath) {
    $SignaturePath = "$ManifestPath.sig"
}

$manifestFullPath = [System.IO.Path]::GetFullPath($ManifestPath)
$signatureFullPath = [System.IO.Path]::GetFullPath($SignaturePath)

$files = Get-ChildItem -LiteralPath $packageRootPath -Recurse -File |
    Where-Object {
        $fullName = [System.IO.Path]::GetFullPath($_.FullName)
        $fullName -ne $manifestFullPath -and
        $fullName -ne $signatureFullPath -and
        $_.Name -notmatch '\.(log|tmp)$'
    } |
    Sort-Object FullName

if ($files.Count -eq 0) {
    throw "No package files found under $packageRootPath"
}

$packageRootWithSeparator = $packageRootPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$entries = foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($packageRootWithSeparator.Length).Replace('\', '/')
    [ordered]@{
        path = $relativePath
        size_bytes = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$gitCommit = Get-GitValue -Arguments @('rev-parse', 'HEAD')
$gitStatus = Get-GitValue -Arguments @('status', '--porcelain')
$readinessGateHash = (Get-FileHash -LiteralPath $readinessGateFullPath -Algorithm SHA256).Hash.ToLowerInvariant()

$manifest = [ordered]@{
    schema_version = 'lucky5.godot_asset_manifest.v1'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    version = $Version
    package_root_name = (Split-Path -Path $packageRootPath -Leaf)
    git_commit = $gitCommit
    git_dirty = -not [string]::IsNullOrWhiteSpace($gitStatus)
    readiness_gate = [ordered]@{
        path = $ReadinessGatePath.Replace('\', '/')
        sha256 = $readinessGateHash
        approved_by = $readinessGate.approved_by
        approved_at_utc = $readinessGate.approved_at_utc
    }
    files = @($entries)
}

$manifestJson = ConvertTo-CanonicalJson -Value $manifest
Set-Content -LiteralPath $manifestFullPath -Value $manifestJson -Encoding utf8NoBOM

if ($SigningKeyPemPath) {
    $signingKeyFullPath = Resolve-RequiredPath -Path $SigningKeyPemPath -Description 'Manifest signing private key'
    $rsa = [System.Security.Cryptography.RSA]::Create()
    try {
        $pem = Get-Content -LiteralPath $signingKeyFullPath -Raw
        $rsa.ImportFromPem($pem)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($manifestJson)
        $signature = $rsa.SignData(
            $bytes,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        [System.IO.File]::WriteAllText($signatureFullPath, [Convert]::ToBase64String($signature), [System.Text.UTF8Encoding]::new($false))
    }
    finally {
        $rsa.Dispose()
    }
}

[ordered]@{
    manifest_path = $manifestFullPath
    manifest_sha256 = (Get-FileHash -LiteralPath $manifestFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    signature_path = if (Test-Path -LiteralPath $signatureFullPath) { $signatureFullPath } else { $null }
    file_count = $files.Count
} | ConvertTo-Json -Depth 4
