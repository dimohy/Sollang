[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineBatchResult,
    [Parameter(Mandatory)][string]$CandidateBatchResult,
    [Parameter(Mandatory)][string]$CandidateCompletionRecord,
    [Parameter(Mandatory)][string]$FocusedReceipt,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCandidateCompilerSha256,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Description)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "C451 $Description is missing: $Path"
    }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$baselinePath = (Resolve-Path -LiteralPath $BaselineBatchResult).Path
$candidatePath = (Resolve-Path -LiteralPath $CandidateBatchResult).Path
$completionPath = (Resolve-Path -LiteralPath $CandidateCompletionRecord).Path
$focusedPath = (Resolve-Path -LiteralPath $FocusedReceipt).Path
$baseline = Read-JsonFile -Path $baselinePath -Description 'baseline batch result'
$candidate = Read-JsonFile -Path $candidatePath -Description 'candidate batch result'
$completion = Read-JsonFile -Path $completionPath -Description 'candidate completion record'
$focused = Read-JsonFile -Path $focusedPath -Description 'focused receipt'
$expectedCompiler = $ExpectedCandidateCompilerSha256.ToUpperInvariant()

foreach ($batch in @($baseline, $candidate)) {
    if ($batch.schemaVersion -ne 1 -or $batch.total -ne 1 -or
        @($batch.results).Count -ne 1 -or
        $batch.results[0].Fixture -cne '1452-each-call-result-record-type') {
        throw 'C451 batch result does not identify the exact 1452 fixture'
    }
}
if ($candidate.compilerSha256 -cne $expectedCompiler) {
    throw "C451 candidate compiler hash mismatch: expected=$expectedCompiler actual=$($candidate.compilerSha256)"
}
if ($completion.schemaVersion -ne 3 -or $completion.runId -cne 'c451-bfs-variant-v10' -or
    $completion.executionMode -cne 'detached-supervisor' -or
    $completion.status -cne 'failed' -or $completion.exitCode -eq 0 -or
    @($completion.orphanProcessIds).Count -ne 0 -or -not $completion.processAudit.completed) {
    throw 'C451 candidate completion record is not a terminated fail-closed run with zero orphans'
}
if ($focused.schemaVersion -ne 1 -or $focused.caseId -cne 'C2026-09-14-451' -or
    $focused.status -cne 'passed' -or $focused.completed -ne 3 -or $focused.total -ne 3 -or
    $focused.compilerSha256 -cne $expectedCompiler -or @($focused.orphanProcessIds).Count -ne 0) {
    throw 'C451 focused receipt is not a clean 3/3 result for the candidate compiler'
}

$baselineError = [string]$baseline.results[0].Error
$candidateError = [string]$candidate.results[0].Error
$expectedAstIds = @(94, 116, 190, 219)
$baselineAstIds = @([regex]::Matches(
    $baselineError,
    'V006: unresolved call identity reached LLVM emission[^\r\n]*source 65, ast (\d+),') |
    ForEach-Object { [int]$_.Groups[1].Value })
if (($baselineAstIds -join ',') -cne ($expectedAstIds -join ',')) {
    throw "C451 baseline V006 identities changed: expected=$($expectedAstIds -join ',') actual=$($baselineAstIds -join ',')"
}
if ($candidateError -match 'V006: unresolved call identity reached LLVM emission' -or
    $candidateError -match 'source 65, ast (94|116|190|219),') {
    throw 'C451 candidate retained an original unresolved-call identity'
}

$output = [ordered]@{
    schemaVersion = 1
    caseId = 'C2026-09-14-451'
    status = 'passed'
    compilerSha256 = $expectedCompiler
    completed = 7
    total = 7
    checks = @(
        'baseline-source65-ast94-v006'
        'baseline-source65-ast116-v006'
        'baseline-source65-ast190-v006'
        'baseline-source65-ast219-v006'
        'candidate-original-v006-zero'
        'focused-diagnostics-and-call-identity-3-of-3'
        'candidate-orphan-processes-zero'
    )
    baselineCompilerSha256 = $baseline.compilerSha256
    baselineErrorSha256 = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($baselineError)))
    candidateErrorSha256 = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($candidateError)))
    focusedReceiptSha256 = (Get-FileHash -LiteralPath $focusedPath -Algorithm SHA256).Hash
    orphanProcessIds = @()
    remainingFixtureFailureIds = @('S054', 'S018', 'S021', 'S031', 'S017')
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($output | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Write-Host "[C451 BFS call resolution] PASS 7/7 compiler=$expectedCompiler result=$resolvedOutput"
