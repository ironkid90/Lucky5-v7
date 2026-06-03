param(
    [string]$OutputDir = "tmp"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Area,
        [string]$Name,
        [ValidateSet("PASS", "FAIL", "BLOCKED")][string]$Status,
        [string]$Evidence,
        [string[]]$Blockers = @(),
        [string]$Command = ""
    )

    $script:results.Add([pscustomobject]@{
        area = $Area
        name = $Name
        status = $Status
        command = $Command
        evidence = $Evidence
        blockers = $Blockers
    }) | Out-Null
}

function Invoke-GateCommand {
    param(
        [string]$Area,
        [string]$Name,
        [string]$FileName,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds = 180
    )

    $resolvedCommand = Get-Command $FileName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $resolvedCommand) {
        $FileName = $resolvedCommand.Source
    }

    $commandLine = "$FileName $($Arguments -join ' ')"
    try {
        $stdoutPath = Join-Path $outputPath "$timestamp-$($Name -replace '[^A-Za-z0-9_-]', '-').stdout.log"
        $stderrPath = Join-Path $outputPath "$timestamp-$($Name -replace '[^A-Za-z0-9_-]', '-').stderr.log"
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $FileName
        foreach ($argument in $Arguments) {
            [void]$startInfo.ArgumentList.Add($argument)
        }
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        Set-Content -Path $stdoutPath -Value $stdout -Encoding UTF8
        Set-Content -Path $stderrPath -Value $stderr -Encoding UTF8

        if (-not $completed) {
            try { $process.Kill($true) } catch { }
            Add-Result -Area $Area -Name $Name -Status "BLOCKED" -Command $commandLine -Evidence "Timed out after $TimeoutSeconds seconds. Logs: $stdoutPath, $stderrPath" -Blockers @("Command timeout")
            return
        }

        if ($process.ExitCode -eq 0) {
            $tail = (($stdout -split "`r?`n") | Where-Object { $_ } | Select-Object -Last 5) -join " | "
            Add-Result -Area $Area -Name $Name -Status "PASS" -Command $commandLine -Evidence "Exit 0. $tail Logs: $stdoutPath, $stderrPath"
        } else {
            $tail = ((($stderr + "`n" + $stdout) -split "`r?`n") | Where-Object { $_ } | Select-Object -Last 8) -join " | "
            Add-Result -Area $Area -Name $Name -Status "FAIL" -Command $commandLine -Evidence "Exit $($process.ExitCode). $tail Logs: $stdoutPath, $stderrPath" -Blockers @("Command exited non-zero")
        }
    } catch {
        Add-Result -Area $Area -Name $Name -Status "BLOCKED" -Command $commandLine -Evidence $_.Exception.Message -Blockers @("Command could not start")
    }
}

function Test-JsonFile {
    param([string]$Path)
    try {
        Get-Content -Raw -Path $Path | ConvertFrom-Json -Depth 100 | Out-Null
        return $true
    } catch {
        return $false
    }
}

$contractSchemaPath = Join-Path $RepoRoot "docs/contracts/godot-cabinet/cabinet-contract-v1.schema.json"
$variantSchemaPath = Join-Path $RepoRoot "docs/contracts/godot-cabinet/variant-definition-v1.schema.json"
$variantPath = Join-Path $RepoRoot "docs/contracts/godot-cabinet/lucky5-classic.variant.v1.json"
$fixturePath = Join-Path $RepoRoot "godot/cabinet/data/fixture_snapshot.json"
$godotProjectPath = Join-Path $RepoRoot "godot/cabinet"

$jsonFiles = @($contractSchemaPath, $variantSchemaPath, $variantPath, $fixturePath)
$invalidJson = @($jsonFiles | Where-Object { -not (Test-JsonFile $_) })
if ($invalidJson.Count -eq 0) {
    Add-Result -Area "contract" -Name "JSON syntax" -Status "PASS" -Evidence "Contract schemas, variant record, and Godot fixture parse as JSON."
} else {
    Add-Result -Area "contract" -Name "JSON syntax" -Status "FAIL" -Evidence "Invalid JSON files: $($invalidJson -join ', ')" -Blockers $invalidJson
}

$contract = Get-Content -Raw -Path $contractSchemaPath | ConvertFrom-Json -Depth 100
$variant = Get-Content -Raw -Path $variantPath | ConvertFrom-Json -Depth 100
$fixture = Get-Content -Raw -Path $fixturePath | ConvertFrom-Json -Depth 100

$contractBlockers = New-Object System.Collections.Generic.List[string]
if ($contract.'$defs'.SchemaVersion.const -ne "cabinet.v1") { $contractBlockers.Add("Cabinet schema version constant is not cabinet.v1.") }
if ($fixture.schema_version -ne "cabinet.v1") { $contractBlockers.Add("Godot fixture schema_version is '$($fixture.schema_version)', expected cabinet.v1.") }
$fixtureVariantId = if ($fixture.PSObject.Properties.Name -contains "variant_id") { $fixture.variant_id } elseif ($fixture.variant -and ($fixture.variant.PSObject.Properties.Name -contains "variant_id")) { $fixture.variant.variant_id } else { "" }
if ($fixtureVariantId -ne $variant.variant_id) { $contractBlockers.Add("Godot fixture variant_id is '$fixtureVariantId', expected '$($variant.variant_id)'.") }
if ($fixture.PSObject.Properties.Name -notcontains "sequence_number") { $contractBlockers.Add("Godot fixture is missing sequence_number for replay/gap recovery.") }
if ($fixture.PSObject.Properties.Name -notcontains "state_version") { $contractBlockers.Add("Godot fixture is missing state_version for optimistic command safety.") }
if ($contractBlockers.Count -eq 0) {
    Add-Result -Area "contract" -Name "Godot fixture compatibility" -Status "PASS" -Evidence "Fixture uses cabinet.v1, variant id matches, and state/sequence fields are present."
} else {
    Add-Result -Area "contract" -Name "Godot fixture compatibility" -Status "FAIL" -Evidence "Fixture is not yet compatible with the governed Godot cabinet contract." -Blockers $contractBlockers.ToArray()
}

$commandBlockers = New-Object System.Collections.Generic.List[string]
$cabinetRoot = Get-Content -Raw -Path (Join-Path $RepoRoot "godot/cabinet/scripts/cabinet_root.gd")
if ($cabinetRoot -notmatch '"schema_version"\s*:\s*"cabinet\.v1"') { $commandBlockers.Add("Godot command emitter does not stamp schema_version cabinet.v1.") }
if ($cabinetRoot -notmatch 'expected_state_version') { $commandBlockers.Add("Godot command emitter must include expected_state_version.") }
if ($cabinetRoot -notmatch 'idempotency_key') { $commandBlockers.Add("Godot command emitter must include idempotency_key.") }
if ($cabinetRoot -notmatch 'client_sequence_number') { $commandBlockers.Add("Godot command emitter must include client_sequence_number.") }
if ($cabinetRoot -notmatch 'pending_command_id') { $commandBlockers.Add("Godot command emitter must suppress duplicate pending commands.") }
if ($commandBlockers.Count -eq 0) {
    Add-Result -Area "contract" -Name "Godot command envelope" -Status "PASS" -Evidence "Command envelope includes cabinet.v1, expected_state_version, idempotency_key, client_sequence_number, and pending action locking."
} else {
    Add-Result -Area "contract" -Name "Godot command envelope" -Status "FAIL" -Evidence "Godot command envelope is not production contract compatible." -Blockers $commandBlockers.ToArray()
}

Invoke-GateCommand -Area "backend" -Name "Regression suite including replay, recovery, ledger, idempotency" -FileName "dotnet" -Arguments @("run", "--project", "server/tests/Lucky5.Tests/Lucky5.Tests.csproj") -WorkingDirectory $RepoRoot -TimeoutSeconds 180

$devScript = Get-Content -Raw -Path (Join-Path $RepoRoot "dev.ps1")
$defaultLaunchBlockers = New-Object System.Collections.Generic.List[string]
if ($devScript -match '\$Client') { $defaultLaunchBlockers.Add("dev.ps1 still references the removed Client selector.") }
if ($devScript -match '\[switch\]\$Godot') { $defaultLaunchBlockers.Add("dev.ps1 still exposes Godot as an opt-in switch instead of the default.") }
if ($devScript -notmatch '\[switch\]\$Web') { $defaultLaunchBlockers.Add("dev.ps1 must keep legacy web fallback behind an explicit -Web switch.") }
if ($devScript -notmatch '\$launchGodot\s*=\s*-not \$Headless -and -not \$Web') { $defaultLaunchBlockers.Add("dev.ps1 does not make Godot the default non-headless launch path.") }
if ($defaultLaunchBlockers.Count -eq 0) {
    Add-Result -Area "launch" -Name "Godot default launcher" -Status "PASS" -Evidence "dev.ps1 launches Godot by default and makes web fallback explicit."
} else {
    Add-Result -Area "launch" -Name "Godot default launcher" -Status "FAIL" -Evidence "dev.ps1 does not satisfy Godot default launch requirements." -Blockers $defaultLaunchBlockers.ToArray()
}

$godotCommand = Get-Command godot, godot4, Godot_v4.6-stable_win64.exe, Godot_v4.4.1-stable_win64.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $godotCommand) {
    Add-Result -Area "godot" -Name "Godot headless project load" -Status "BLOCKED" -Command "scripts/godot/Test-GodotCabinet.ps1" -Evidence "No Godot executable found on PATH under checked command names." -Blockers @("Install Godot 4.x or add it to PATH, then rerun this gate.")
} else {
    $pwshCommand = Get-Command pwsh, pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $pwshCommand) {
        Add-Result -Area "godot" -Name "Godot headless project load" -Status "BLOCKED" -Command "scripts/godot/Test-GodotCabinet.ps1" -Evidence "PowerShell 7 executable not found for the Godot smoke wrapper." -Blockers @("Install PowerShell 7 or run scripts/godot/Test-GodotCabinet.ps1 manually.")
    } else {
        Invoke-GateCommand -Area "godot" -Name "Godot headless project load" -FileName $pwshCommand.Source -Arguments @("-NoProfile", "-File", (Join-Path $RepoRoot "scripts/godot/Test-GodotCabinet.ps1"), "-GodotBin", $godotCommand.Source) -WorkingDirectory $RepoRoot -TimeoutSeconds 120
    }
}

$recoveryBlockers = New-Object System.Collections.Generic.List[string]
$stateStore = Get-Content -Raw -Path (Join-Path $RepoRoot "godot/cabinet/scripts/cabinet_store.gd")
if ($stateStore -notmatch 'sequence_number') { $recoveryBlockers.Add("Godot state store does not track sequence_number or detect gaps.") }
if ($stateStore -notmatch 'state_version') { $recoveryBlockers.Add("Godot state store does not track state_version before applying snapshots/events.") }
if ($stateStore -notmatch 'gap|replay|recovery|reconnect|enter_recovery') { $recoveryBlockers.Add("Godot state store has no explicit gap/replay/recovery path yet.") }
if ($recoveryBlockers.Count -eq 0) {
    Add-Result -Area "replay" -Name "Godot gap recovery readiness" -Status "PASS" -Evidence "State store has explicit sequence/state recovery handling."
} else {
    Add-Result -Area "replay" -Name "Godot gap recovery readiness" -Status "FAIL" -Evidence "Backend replay determinism exists, but the Godot client recovery path is not implemented." -Blockers $recoveryBlockers.ToArray()
}

$productionBlockers = New-Object System.Collections.Generic.List[string]
if ($variant.status -ne "approved") { $productionBlockers.Add("Variant status is '$($variant.status)', not approved.") }
if ($variant.rtp_gate.simulation_status -ne "passed") { $productionBlockers.Add("Variant RTP simulation status is '$($variant.rtp_gate.simulation_status)', not passed.") }
if ($variant.rtp_gate.approved_for_production -ne $true) { $productionBlockers.Add("Variant RTP gate is not approved_for_production.") }
if ($variant.production_activation.enabled -ne $true) { $productionBlockers.Add("Variant production_activation.enabled is false.") }
if ([string]::IsNullOrWhiteSpace($variant.governance.approved_by)) { $productionBlockers.Add("Governance approved_by is empty.") }
if ([string]::IsNullOrWhiteSpace($variant.rtp_gate.report_uri)) { $productionBlockers.Add("RTP gate report_uri is empty.") }

if ($productionBlockers.Count -eq 0) {
    Add-Result -Area "rollback-burn-in" -Name "Production activation checklist" -Status "PASS" -Evidence "Governance, RTP, production activation, and Godot-first launch path are ready."
} else {
    Add-Result -Area "rollback-burn-in" -Name "Production activation checklist" -Status "FAIL" -Evidence "Production activation and burn-in are blocked until governance, simulation, and Godot launch gates pass." -Blockers $productionBlockers.ToArray()
}

$failed = @($results | Where-Object { $_.status -eq "FAIL" })
$blocked = @($results | Where-Object { $_.status -eq "BLOCKED" })
$overall = if ($failed.Count -eq 0 -and $blocked.Count -eq 0) { "PASS" } else { "FAIL" }

$jsonArtifact = Join-Path $outputPath "godot-migration-readiness-gate-$timestamp.json"
$mdArtifact = Join-Path $outputPath "godot-migration-readiness-gate-$timestamp.md"

$artifact = [pscustomobject]@{
    schema_version = "godot-migration-readiness-gate/v1"
    timestamp = $timestamp
    objective = "Godot cabinet migration production readiness gate"
    overall_status = $overall
    results = $results
    blockers = @($results | ForEach-Object { $_.blockers } | Where-Object { $_ })
}
$artifact | ConvertTo-Json -Depth 100 | Set-Content -Path $jsonArtifact -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Godot Cabinet Migration Readiness Gate - $timestamp")
$lines.Add("")
$lines.Add("Overall status: **$overall**")
$lines.Add("")
$lines.Add("## Gate Results")
$lines.Add("")
$lines.Add("| Area | Check | Status | Evidence |")
$lines.Add("| --- | --- | --- | --- |")
foreach ($result in $results) {
    $evidence = ($result.evidence -replace '\|', '/')
    $lines.Add("| $($result.area) | $($result.name) | $($result.status) | $evidence |")
}
$lines.Add("")
$lines.Add("## Blockers")
$lines.Add("")
$allBlockers = @($results | ForEach-Object { $_.blockers } | Where-Object { $_ })
if ($allBlockers.Count -eq 0) {
    $lines.Add("- None.")
} else {
    foreach ($blocker in $allBlockers) { $lines.Add("- $blocker") }
}
$lines.Add("")
$lines.Add("## Rollback and Burn-in Checklist")
$lines.Add("")
$lines.Add("- Rollback route: keep API-only operation and the explicit -Web fallback for local diagnosis; Godot remains the default playable client.")
$lines.Add("- Burn-in entry requires: contract compatibility, replay/gap recovery, ledger/idempotency, Godot headless load, RTP report, governance approval, and production_activation enabled.")
$lines.Add("- Burn-in exit requires: no unresolved recovery/ledger/idempotency incidents, operator rollback drill completed, and signed release artifact identified.")
Set-Content -Path $mdArtifact -Value $lines -Encoding UTF8

Write-Host "Gate artifact: $mdArtifact"
Write-Host "Gate JSON: $jsonArtifact"
Write-Host "Overall status: $overall"
if ($overall -ne "PASS") { exit 1 }
