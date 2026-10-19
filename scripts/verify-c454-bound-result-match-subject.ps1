[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedBaselineCompilerSha256,
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCandidateCompilerSha256,
    [Parameter(Mandatory)][string]$CandidateBatchResult,
    [Parameter(Mandatory)][string]$CandidateCompletionRecord,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'verification-process.ps1')

function Resolve-ExactCompiler {
    param([string]$Path, [string]$ExpectedHash, [string]$Phase)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $actual = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
    if ($actual -cne $ExpectedHash.ToUpperInvariant()) {
        throw "C454 $Phase compiler hash mismatch: expected=$ExpectedHash actual=$actual"
    }
    $resolved
}

function Invoke-ExactText {
    param([string]$Compiler, [string]$Command, [string[]]$Sources, [string]$Phase)
    $process = Invoke-VerificationProcessCapture -FilePath $Compiler `
        -ArgumentList (@($Command) + $Sources) -Description "C454 $Phase $Command" `
        -TimeoutMilliseconds 30000
    if ($process.ExitCode -ne 0) {
        throw "C454 $Phase $Command failed:`n$($process.Stdout)`n$($process.Stderr)"
    }
    [pscustomobject]@{
        Stdout = $process.Stdout
        Combined = ($process.Stderr + $process.Stdout).Replace("`r`n", "`n").TrimEnd("`n")
    }
}

function Read-MatchOperands {
    param([string]$Text)
    $records = @{}
    foreach ($line in @($Text -split "`r?`n")) {
        if ($line -match '^node (?<node>\d+) kind 27 parent (?<parent>-?\d+) source 2 ast (?<ast>647|835) .* operands (?<operand0>-?\d+)/') {
            $records[[int]$Matches.ast] = [pscustomobject]@{
                Node = [int]$Matches.node
                Parent = [int]$Matches.parent
                Operand0 = [int]$Matches.operand0
            }
        }
    }
    $records
}

$baseline = Resolve-ExactCompiler $BaselineCompiler $ExpectedBaselineCompilerSha256 'baseline'
$candidate = Resolve-ExactCompiler $CandidateCompiler $ExpectedCandidateCompilerSha256 'candidate'
$baselineHash = $ExpectedBaselineCompilerSha256.ToUpperInvariant()
$candidateHash = $ExpectedCandidateCompilerSha256.ToUpperInvariant()
$sources = @(
    (Join-Path $root 'stdlib\std\io.slg')
    (Join-Path $root 'stdlib\std\io\async.slg')
    (Join-Path $root 'stdlib\std\io\socket.slg')
    (Join-Path $root 'stdlib\std\net.slg')
    (Join-Path $root 'stdlib\std\net\parse_error.slg')
    (Join-Path $root 'stdlib\std\net\socket.slg')
    (Join-Path $root 'stdlib\std\time.slg')
    (Join-Path $root 'stdlib\sys\runtime\clock.slg')
    (Join-Path $root 'stdlib\sys\runtime\console.slg')
    (Join-Path $root 'stdlib\sys\runtime\integer_file.slg')
    (Join-Path $root 'stdlib\sys\runtime\parallel.slg')
    (Join-Path $root 'stdlib\sys\runtime\random.slg')
    (Join-Path $root 'stdlib\sys\runtime\socket.slg')
    (Join-Path $root 'stdlib\sys\runtime\time.slg')
)
$productionSource = Join-Path $root 'selfhost\ir\typed\function_lowering.slg'
& (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $productionSource
$production = [IO.File]::ReadAllText($productionSource)
$contract = '(?s)finalProjectedCandidateBinding\.kind == 17.*?finalProjectedCandidateBinding\.operand0 == finalProjectedCandidateIndex!.*?finalProjectedCandidateRead\.kind == 5.*?finalProjectedCandidateRead\.operand0 == finalProjectedCandidate\.parent.*?finalProjectedCandidateRead\.nextOperand == finalProjectedMatchIndex!.*?true => finalProjectedCandidateUsesBoundSubject!.*?\(finalProjectedCandidateAst\.start >= finalProjectedFlowAst\.start\s+or finalProjectedCandidateUsesBoundSubject!\)'
if ([regex]::Matches($production, $contract).Count -ne 1) {
    throw 'C454 exact call-binding-read-match contract is missing or duplicated'
}

$baselineDiagnostics = Invoke-ExactText $baseline 'diagnostic-counts' $sources 'baseline'
$candidateDiagnostics = Invoke-ExactText $candidate 'diagnostic-counts' $sources 'candidate'
if ($baselineDiagnostics.Combined -cne "semantic diagnostics = 0`nir diagnostics = 22`nchecked diagnostics = 22") {
    throw "C454 baseline diagnostic contract changed:`n$($baselineDiagnostics.Combined)"
}
if ($candidateDiagnostics.Combined -cne "semantic diagnostics = 0`nir diagnostics = 0`nchecked diagnostics = 0") {
    throw "C454 candidate diagnostic contract changed:`n$($candidateDiagnostics.Combined)"
}
$baselineNodeText = Invoke-ExactText $baseline 'typed-ir-nodes' $sources 'baseline'
$candidateNodeText = Invoke-ExactText $candidate 'typed-ir-nodes' $sources 'candidate'
$baselineNodes = Read-MatchOperands -Text $baselineNodeText.Stdout
$candidateNodes = Read-MatchOperands -Text $candidateNodeText.Stdout
if ($null -eq $baselineNodes[647] -or $null -eq $baselineNodes[835] -or
    $baselineNodes[647].Operand0 -ne 2134 -or $baselineNodes[835].Operand0 -ne 2266) {
    throw 'C454 baseline no longer reproduces both stale outer match subjects'
}
if ($null -eq $candidateNodes[647] -or $null -eq $candidateNodes[835] -or
    $candidateNodes[647].Operand0 -ne 2159 -or $candidateNodes[835].Operand0 -ne 2268) {
    throw 'C454 candidate did not bind both outer matches to their exact Result calls'
}

$batch = Get-Content -LiteralPath $CandidateBatchResult -Raw | ConvertFrom-Json
$completion = Get-Content -LiteralPath $CandidateCompletionRecord -Raw | ConvertFrom-Json
if ($batch.schemaVersion -ne 1 -or $batch.compilerSha256 -cne $candidateHash -or
    $batch.total -ne 1 -or @($batch.results).Count -ne 1 -or
    $batch.results[0].Fixture -cne '1452-each-call-result-record-type') {
    throw 'C454 candidate batch does not identify the expected compiler and exact fixture'
}
$batchError = [string]$batch.results[0].Error
if ($batchError -match 'sollang compiler error [A-Z]\d{3}:' -or
    $batchError -notmatch '%sollang\.product\.t310 = type \{ , %sollang\.enum\.t298 \}') {
    throw 'C454 candidate batch did not separate zero Typed IR diagnostics from the exact downstream C455 malformed product'
}
if ($completion.schemaVersion -ne 3 -or $completion.runId -cne 'c454-bound-subject-v13' -or
    $completion.executionMode -cne 'detached-supervisor' -or $completion.status -cne 'failed' -or
    $completion.exitCode -eq 0 -or -not $completion.processAudit.completed -or
    @($completion.orphanProcessIds).Count -ne 0) {
    throw 'C454 candidate completion is not a terminated fail-closed run with zero orphans'
}

$result = [ordered]@{
    schemaVersion = 1
    caseId = 'C2026-09-14-454'
    status = 'passed'
    completed = 8
    total = 8
    baselineCompilerSha256 = $baselineHash
    candidateCompilerSha256 = $candidateHash
    sourceClosureCount = $sources.Count
    baselineDiagnosticCount = 22
    candidateDiagnosticCount = 0
    baselineMatchOperands = [ordered]@{ '647' = 2134; '835' = 2266 }
    candidateMatchOperands = [ordered]@{ '647' = 2159; '835' = 2268 }
    fullStdlibTypedDiagnosticCount = 0
    downstreamFailureId = 'C2026-09-14-455'
    orphanProcessIds = @()
    productionSourceSha256 = (Get-FileHash -LiteralPath $productionSource -Algorithm SHA256).Hash
    candidateBatchSha256 = (Get-FileHash -LiteralPath $CandidateBatchResult -Algorithm SHA256).Hash
    candidateCompletionSha256 = (Get-FileHash -LiteralPath $CandidateCompletionRecord -Algorithm SHA256).Hash
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($result | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
Write-Host "[C454 bound Result match subject] PASS 8/8 compiler=$candidateHash result=$resolvedOutput"
