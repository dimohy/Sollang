[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineBatchResult,
    [Parameter(Mandatory)][string]$BaselineLlvm,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedBaselineCompilerSha256,
    [Parameter(Mandatory)][string]$CandidateBatchResult,
    [Parameter(Mandatory)][string]$CandidateCompletionRecord,
    [Parameter(Mandatory)][string]$CandidateLlvm,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCandidateCompilerSha256,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$productionSource = Join-Path $root 'selfhost\llvm\text\core_prepare.slg'
$productProducer = Join-Path $root 'selfhost\semantic\expression_type_ids_resolution_phases.slg'
& (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source @($productionSource, $productProducer)

$production = [IO.File]::ReadAllText($productionSource)
$producer = [IO.File]::ReadAllText($productProducer)
if ([regex]::Matches($production, 'productType\.status == 0 and productType\.kind == 10 and not productType\.containsParameter').Count -ne 1 -or
    [regex]::Matches($production, 'C455 product 310 field').Count -ne 0) {
    throw 'C455 concrete-only product declaration contract is missing or temporary instrumentation remains'
}
if ([regex]::Matches($producer, 'containsParameter: productContainsParameter!').Count -ne 1) {
    throw 'C455 structural product parameter-provenance contract is missing'
}

$baselineBatch = Get-Content -LiteralPath $BaselineBatchResult -Raw | ConvertFrom-Json
$candidateBatch = Get-Content -LiteralPath $CandidateBatchResult -Raw | ConvertFrom-Json
$completion = Get-Content -LiteralPath $CandidateCompletionRecord -Raw | ConvertFrom-Json
$baselineHash = $ExpectedBaselineCompilerSha256.ToUpperInvariant()
$candidateHash = $ExpectedCandidateCompilerSha256.ToUpperInvariant()
foreach ($batch in @($baselineBatch, $candidateBatch)) {
    if ($batch.schemaVersion -ne 1 -or $batch.total -ne 1 -or @($batch.results).Count -ne 1 -or
        $batch.results[0].Fixture -cne '1452-each-call-result-record-type') {
        throw 'C455 batch does not identify the exact 1452 fixture'
    }
}
$baselineError = [string]$baselineBatch.results[0].Error
if ($baselineBatch.compilerSha256 -cne $baselineHash -or $baselineBatch.state -cne 'failed' -or
    $baselineError -notmatch '%sollang\.product\.t310 = type \{ , %sollang\.enum\.t298 \}' -or
    $baselineError -notmatch 'error: expected type') {
    throw 'C455 baseline did not reproduce the exact malformed generic product declaration'
}
if ($candidateBatch.compilerSha256 -cne $candidateHash -or $candidateBatch.state -cne 'passed' -or
    $candidateBatch.completed -ne 1 -or $candidateBatch.passed -ne 1 -or
    $candidateBatch.failed -ne 0 -or $candidateBatch.missing -ne 0 -or
    -not $candidateBatch.results[0].Success -or -not [string]::IsNullOrEmpty([string]$candidateBatch.results[0].Error)) {
    throw 'C455 candidate exact fixture batch did not pass cleanly'
}
if ($completion.schemaVersion -ne 3 -or $completion.runId -cne 'c455-concrete-product-v14' -or
    $completion.executionMode -cne 'detached-supervisor' -or $completion.status -cne 'passed' -or
    $completion.exitCode -ne 0 -or $completion.targetExitCode -ne 0 -or
    @($completion.failureIds).Count -ne 0 -or @($completion.orphanProcessIds).Count -ne 0 -or
    -not $completion.processAudit.completed) {
    throw 'C455 candidate completion is not a clean detached success with zero orphans'
}

$baselineLlvmPath = (Resolve-Path -LiteralPath $BaselineLlvm).Path
$candidateLlvmPath = (Resolve-Path -LiteralPath $CandidateLlvm).Path
$baselineText = [IO.File]::ReadAllText($baselineLlvmPath)
$candidateText = [IO.File]::ReadAllText($candidateLlvmPath)
if ([regex]::Matches($baselineText, '%sollang\.product\.t310 = type \{ , %sollang\.enum\.t298 \}').Count -ne 1 -or
    [regex]::Matches($baselineText, '%sollang\.product\.t310').Count -ne 1) {
    throw 'C455 baseline LLVM product t310 topology changed'
}
if ([regex]::Matches($candidateText, '%sollang\.product\.t\d+ = type \{\s*,').Count -ne 0 -or
    [regex]::Matches($candidateText, '%sollang\.product\.t310').Count -ne 0) {
    throw 'C455 candidate retained an incomplete generic product declaration'
}

$result = [ordered]@{
    schemaVersion = 1
    caseId = 'C2026-09-14-455'
    status = 'passed'
    completed = 7
    total = 7
    baselineCompilerSha256 = $baselineHash
    candidateCompilerSha256 = $candidateHash
    baselineMalformedProductCount = 1
    candidateMalformedProductCount = 0
    candidateNativeFixturePassed = $true
    orphanProcessIds = @()
    productionSourceSha256 = (Get-FileHash -LiteralPath $productionSource -Algorithm SHA256).Hash
    baselineLlvmSha256 = (Get-FileHash -LiteralPath $baselineLlvmPath -Algorithm SHA256).Hash
    candidateLlvmSha256 = (Get-FileHash -LiteralPath $candidateLlvmPath -Algorithm SHA256).Hash
    candidateBatchSha256 = (Get-FileHash -LiteralPath $CandidateBatchResult -Algorithm SHA256).Hash
    candidateCompletionSha256 = (Get-FileHash -LiteralPath $CandidateCompletionRecord -Algorithm SHA256).Hash
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($result | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
Write-Host "[C455 concrete product declarations] PASS 7/7 compiler=$candidateHash result=$resolvedOutput"
