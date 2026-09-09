[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^C[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+$')]
    [string]$DefectId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('schema', 'type', 'enum', 'manifest', 'index', 'invariant', 'validator', 'fixture', 'pipeline')]
    [string]$AssetKind,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AuthorityPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Reason,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ValidatorEvidence,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ConsumerEvidence,

    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$ledgerPath = Join-Path $RepositoryRoot 'scripts\contracts\compiler-defects.json'
$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
$defect = @($ledger.defects | Where-Object id -ceq $DefectId)
if ($defect.Count -ne 1) {
    throw "expected exactly one compiler defect '$DefectId', found $($defect.Count)"
}
$defect = $defect[0]

$evidenceRoot = Join-Path $RepositoryRoot "scripts\contracts\evidence\$DefectId"
$baselinePath = Join-Path $evidenceRoot 'baseline.json'
$candidatePath = Join-Path $evidenceRoot 'candidate.json'
$tracePath = Join-Path $evidenceRoot 'as-us-001.json'
foreach ($requiredPath in @($baselinePath, $candidatePath, $tracePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "required shaping evidence is missing: $requiredPath"
    }
}

$baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
$candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
$previousTrace = Get-Content -LiteralPath $tracePath -Raw | ConvertFrom-Json
$fingerprint = [string]$defect.shapingEvidence.inputFingerprint
foreach ($receipt in @($baseline, $candidate)) {
    if ($receipt.defectId -cne $DefectId -or $receipt.inputFingerprint -cne $fingerprint) {
        throw "shaping receipt identity does not match '$DefectId'"
    }
}
if ($baseline.exitCode -ne $baseline.expectedExitCode -or $candidate.exitCode -ne 0 -or $candidate.expectedExitCode -ne 0) {
    throw "baseline or candidate receipt does not prove the requested transition"
}
if ($previousTrace.signal.id -cne $DefectId -or
    $previousTrace.signal.durable -ne $true -or
    $previousTrace.signal.machineDecidable -ne $true) {
    throw "the prior AS-US-001 signal is absent or not machine-decidable"
}

$revision = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[a-fA-F0-9]{7,64}$') {
    throw 'unable to resolve the repository revision'
}
$measurementCommand = "pwsh -NoProfile -File scripts/measure-compiler-defect-late-failures.ps1 -DefectId $DefectId"
$executedCommands = @(
    [ordered]@{
        purpose = 'baseline'
        command = $baseline.command
        exitCode = $baseline.exitCode
        expectedExitCode = $baseline.expectedExitCode
        outputSha256 = $baseline.outputSha256
    },
    [ordered]@{
        purpose = 'validator'
        command = $candidate.command
        exitCode = $candidate.exitCode
        expectedExitCode = $candidate.expectedExitCode
        outputSha256 = $candidate.outputSha256
    },
    [ordered]@{
        purpose = 'consumer'
        command = $candidate.command
        exitCode = $candidate.exitCode
        expectedExitCode = $candidate.expectedExitCode
        outputSha256 = $candidate.outputSha256
    },
    [ordered]@{
        purpose = 'candidate'
        command = $candidate.command
        exitCode = $candidate.exitCode
        expectedExitCode = $candidate.expectedExitCode
        outputSha256 = $candidate.outputSha256
    }
)
$trace = [ordered]@{
    ruleId = 'AS-US-001'
    traceAuthority = 'orchestrator'
    orchestratorEvidence = [ordered]@{
        runner = 'agentic-shaping-orchestrator'
        runId = "$DefectId-structured-and-applied"
        targetRepository = ($RepositoryRoot -replace '\\', '/')
        targetRevision = $revision
        inputFingerprint = $fingerprint
        executedCommands = $executedCommands
    }
    signal = $previousTrace.signal
    decision = [ordered]@{
        structured = $true
        claimLevel = 'structured-and-applied'
        reason = $Reason
        asset = [ordered]@{
            kind = $AssetKind
            authorityPath = ($AuthorityPath -replace '\\', '/')
            inputFingerprint = $fingerprint
            validatorEvidence = @($ValidatorEvidence)
        }
        application = [ordered]@{
            productionPathChanged = $true
            consumerEvidence = @($ConsumerEvidence)
        }
        measurementPlan = [ordered]@{
            metric = 'lateFailures'
            measurementCommand = $measurementCommand
            baselineEvidence = @("$DefectId baseline receipt exits $($baseline.exitCode) as expected.")
            candidateEvidence = @("$DefectId candidate receipt exits zero on the frozen focused command.")
            measuredInputFingerprint = $fingerprint
        }
    }
    currentTaskComplete = $true
    forbiddenActions = @()
}

$json = $trace | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($tracePath, "$json`n", [Text.UTF8Encoding]::new($false))
& node (Join-Path $RepositoryRoot '..\AgenticShaping\evals\unstructured-to-structured.mjs') --trace $tracePath
if ($LASTEXITCODE -ne 0) {
    throw "AS-US-001 evaluator rejected the promoted trace: $tracePath"
}
Write-Host "[$DefectId] Agentic Shaping trace promoted: $tracePath"
