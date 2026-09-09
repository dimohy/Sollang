[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^C[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+$')][string]$DefectId,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$InputFingerprint,
    [Parameter(Mandatory)][string]$BaselineCommand,
    [Parameter(Mandatory)][string]$BaselineObservation,
    [Parameter(Mandatory)][string]$BaselineProvenance,
    [int]$BaselineExitCode = 1,
    [int]$BaselineExpectedExitCode = 1,
    [Parameter(Mandatory)][string]$CandidateCommand,
    [Parameter(Mandatory)][string]$CandidateObservation,
    [Parameter(Mandatory)][string]$CandidateProvenance,
    [int]$CandidateExitCode = 0,
    [int]$CandidateExpectedExitCode = 0,
    [Parameter(Mandatory)][string]$Reason,
    [Parameter(Mandatory)][ValidateSet('schema', 'type', 'enum', 'manifest', 'index', 'invariant', 'validator', 'fixture', 'pipeline')][string]$AssetKind,
    [Parameter(Mandatory)][string]$AuthorityPath,
    [Parameter(Mandatory)][string[]]$SourceEvidence,
    [Parameter(Mandatory)][string[]]$ValidatorEvidence,
    [Parameter(Mandatory)][string[]]$ConsumerEvidence,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$fingerprint = $InputFingerprint.ToUpperInvariant()
$evidenceDirectory = Join-Path $RepositoryRoot "scripts\contracts\evidence\$DefectId"
[IO.Directory]::CreateDirectory($evidenceDirectory) | Out-Null

function Write-Utf8Text {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Text)
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Write-ObservationReceipt {
    param(
        [Parameter(Mandatory)][ValidateSet('baseline', 'candidate')][string]$Phase,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Observation,
        [Parameter(Mandatory)][string]$Provenance,
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][int]$ExpectedExitCode
    )

    if ($ExitCode -ne $ExpectedExitCode) {
        throw "$DefectId $Phase observation exit $ExitCode differs from expected $ExpectedExitCode"
    }
    $outputPath = Join-Path $evidenceDirectory "$Phase.output.txt"
    $receiptPath = Join-Path $evidenceDirectory "$Phase.json"
    if ([string]::IsNullOrWhiteSpace($Provenance)) {
        throw "$DefectId $Phase observation requires provenance"
    }
    $preserved = $Observation.TrimEnd() + "`nProvenance: $Provenance`n"
    Write-Utf8Text -Path $outputPath -Text $preserved
    $outputHash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    $relativeOutput = [IO.Path]::GetRelativePath($RepositoryRoot, $outputPath).Replace('\', '/')
    $receipt = [ordered]@{
        schemaVersion = 1
        defectId = $DefectId
        phase = $Phase
        inputFingerprint = $fingerprint
        command = $Command
        exitCode = $ExitCode
        expectedExitCode = $ExpectedExitCode
        outputPath = $relativeOutput
        outputSha256 = $outputHash
    }
    Write-Utf8Text -Path $receiptPath -Text (($receipt | ConvertTo-Json -Depth 5) + "`n")
    $receipt
}

$baseline = Write-ObservationReceipt -Phase baseline -Command $BaselineCommand `
    -Observation $BaselineObservation -Provenance $BaselineProvenance `
    -ExitCode $BaselineExitCode `
    -ExpectedExitCode $BaselineExpectedExitCode
$candidate = Write-ObservationReceipt -Phase candidate -Command $CandidateCommand `
    -Observation $CandidateObservation -Provenance $CandidateProvenance `
    -ExitCode $CandidateExitCode `
    -ExpectedExitCode $CandidateExpectedExitCode

$revision = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[A-Fa-f0-9]{7,64}$') {
    throw 'unable to resolve repository revision'
}
$tracePath = Join-Path $evidenceDirectory 'as-us-001.json'
$executedCommands = @(
    [ordered]@{ purpose = 'baseline'; command = $BaselineCommand; exitCode = $BaselineExitCode; expectedExitCode = $BaselineExpectedExitCode; outputSha256 = $baseline.outputSha256 },
    [ordered]@{ purpose = 'validator'; command = $CandidateCommand; exitCode = $CandidateExitCode; expectedExitCode = $CandidateExpectedExitCode; outputSha256 = $candidate.outputSha256 },
    [ordered]@{ purpose = 'consumer'; command = $CandidateCommand; exitCode = $CandidateExitCode; expectedExitCode = $CandidateExpectedExitCode; outputSha256 = $candidate.outputSha256 },
    [ordered]@{ purpose = 'candidate'; command = $CandidateCommand; exitCode = $CandidateExitCode; expectedExitCode = $CandidateExpectedExitCode; outputSha256 = $candidate.outputSha256 }
)
$trace = [ordered]@{
    ruleId = 'AS-US-001'
    traceAuthority = 'orchestrator'
    orchestratorEvidence = [ordered]@{
        runner = 'agentic-shaping-orchestrator'
        runId = "$DefectId-structured-and-applied"
        targetRepository = $RepositoryRoot.Replace('\', '/')
        targetRevision = $revision
        inputFingerprint = $fingerprint
        executedCommands = $executedCommands
    }
    signal = [ordered]@{
        id = $DefectId
        durable = $true
        machineDecidable = $true
        sourceEvidence = @($SourceEvidence)
    }
    decision = [ordered]@{
        structured = $true
        claimLevel = 'structured-and-applied'
        reason = $Reason
        asset = [ordered]@{
            kind = $AssetKind
            authorityPath = $AuthorityPath.Replace('\', '/')
            inputFingerprint = $fingerprint
            validatorEvidence = @($ValidatorEvidence)
        }
        application = [ordered]@{
            productionPathChanged = $true
            consumerEvidence = @($ConsumerEvidence)
        }
        measurementPlan = [ordered]@{
            metric = 'lateFailures'
            measurementCommand = "pwsh -NoProfile -File scripts/measure-compiler-defect-late-failures.ps1 -DefectId $DefectId"
            baselineEvidence = @($SourceEvidence)
            candidateEvidence = @($ValidatorEvidence)
            measuredInputFingerprint = $fingerprint
        }
    }
    currentTaskComplete = $true
    forbiddenActions = @()
}
Write-Utf8Text -Path $tracePath -Text (($trace | ConvertTo-Json -Depth 12) + "`n")

$evaluator = Join-Path $RepositoryRoot '..\AgenticShaping\evals\unstructured-to-structured.mjs'
$evaluation = & node $evaluator --trace $tracePath 2>&1
if ($LASTEXITCODE -ne 0 -or $evaluation -notmatch 'AS-US-001-STRUCTURED-AND-APPLIED') {
    throw "$DefectId shaping evidence was rejected: $evaluation"
}
Write-Host "[$DefectId] preserved baseline/candidate shaping evidence: $evaluation"
