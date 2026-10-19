[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedBaselineCompilerSha256,
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCandidateCompilerSha256,
    [Parameter(Mandatory)][string]$BaselineBatchResult,
    [Parameter(Mandatory)][string]$CandidateBatchResult,
    [Parameter(Mandatory)][string]$CandidateCompletionRecord,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'verification-process.ps1')

function Resolve-Compiler {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Description
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $actual = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
    if ($actual -cne $ExpectedSha256.ToUpperInvariant()) {
        throw "C453 $Description compiler hash mismatch: expected=$ExpectedSha256 actual=$actual"
    }
    $resolved
}

function Invoke-CompilerText {
    param(
        [Parameter(Mandatory)][string]$Compiler,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Sources,
        [Parameter(Mandatory)][string]$Description
    )

    $result = Invoke-VerificationProcessCapture `
        -FilePath $Compiler `
        -ArgumentList (@($Command) + $Sources) `
        -Description $Description `
        -TimeoutMilliseconds 30000
    if ($result.ExitCode -ne 0) {
        throw "C453 $Description failed with exit code $($result.ExitCode):`n$($result.Stdout)`n$($result.Stderr)"
    }
    [pscustomobject]@{
        Stdout = $result.Stdout
        Stderr = $result.Stderr
        Combined = ($result.Stderr + $result.Stdout).Replace("`r`n", "`n").TrimEnd("`n")
    }
}

function Read-SourceZeroTopology {
    param([Parameter(Mandatory)][string]$Text)

    $records = @{}
    foreach ($line in @($Text -split "`r?`n")) {
        if ($line -match '^node (?<node>\d+) kind (?<kind>\d+) parent (?<parent>-?\d+) source 0 ast (?<ast>\d+) symbol (?<symbol>-?\d+) target (?<target>-?\d+) type (?<type>[^ ]+) payload (?<payload>-?\d+) opcode (?<opcode>-?\d+) operands (?<operand0>-?\d+)/(?<operand1>-?\d+)/(?<next>-?\d+) flags') {
            $records[[int]$Matches.ast] = [pscustomobject]@{
                Node = [int]$Matches.node
                Kind = [int]$Matches.kind
                Parent = [int]$Matches.parent
                Symbol = [int]$Matches.symbol
                Target = [int]$Matches.target
                Type = $Matches.type
                Opcode = [int]$Matches.opcode
                Operand0 = [int]$Matches.operand0
                Operand1 = [int]$Matches.operand1
                NextOperand = [int]$Matches.next
            }
        }
    }
    $records
}

$baselineCompilerPath = Resolve-Compiler -Path $BaselineCompiler -ExpectedSha256 $ExpectedBaselineCompilerSha256 -Description 'baseline'
$candidateCompilerPath = Resolve-Compiler -Path $CandidateCompiler -ExpectedSha256 $ExpectedCandidateCompilerSha256 -Description 'candidate'
$baselineHash = $ExpectedBaselineCompilerSha256.ToUpperInvariant()
$candidateHash = $ExpectedCandidateCompilerSha256.ToUpperInvariant()
$sources = @(
    (Join-Path $root 'stdlib\std\archive\zip.slg')
    (Join-Path $root 'stdlib\std\archive\zip\error.slg')
    (Join-Path $root 'stdlib\std\archive\zip\decoder_phase.slg')
    (Join-Path $root 'stdlib\std\archive\zip\encoder_phase.slg')
    (Join-Path $root 'stdlib\std\compress\gzip.slg')
    (Join-Path $root 'stdlib\std\compress\gzip\error.slg')
    (Join-Path $root 'stdlib\std\hash\crc32.slg')
    (Join-Path $root 'stdlib\std\compress\gzip\decoder_phase.slg')
)
$productionSource = Join-Path $root 'selfhost\ir\typed\function_lowering.slg'
& (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $productionSource
$productionText = [IO.File]::ReadAllText($productionSource)
$wrapperContract = '(?s)finalProjectedCandidate\.parent == finalProjectedMatch!\.parent\s+=> finalProjectedCandidateSharesOwner!.*?finalProjectedCandidateWrapper\.kind == 9\s+and finalProjectedCandidateWrapper\.opcode == -1\s+and finalProjectedCandidateWrapper\.parent == finalProjectedMatch!\.parent\s+and finalProjectedCandidateWrapper\.nextOperand == finalProjectedMatchIndex!\s+-> if \{ true => finalProjectedCandidateSharesOwner! \}'
if ([regex]::Matches($productionText, $wrapperContract).Count -ne 1) {
    throw 'C453 exact transparent-wrapper ownership contract is missing or duplicated'
}

$baselineDiagnostics = Invoke-CompilerText -Compiler $baselineCompilerPath -Command 'diagnostic-counts' -Sources $sources -Description 'baseline ZIP-closure diagnostics'
$candidateDiagnostics = Invoke-CompilerText -Compiler $candidateCompilerPath -Command 'diagnostic-counts' -Sources $sources -Description 'candidate ZIP-closure diagnostics'
$expectedBaselineDiagnostics = "semantic diagnostics = 0`nir diagnostics = 1`nchecked diagnostics = 1"
$expectedCandidateDiagnostics = "semantic diagnostics = 0`nir diagnostics = 0`nchecked diagnostics = 0"
if ($baselineDiagnostics.Combined -cne $expectedBaselineDiagnostics) {
    throw "C453 baseline diagnostic contract mismatch:`n$($baselineDiagnostics.Combined)"
}
if ($candidateDiagnostics.Combined -cne $expectedCandidateDiagnostics) {
    throw "C453 candidate diagnostic contract mismatch:`n$($candidateDiagnostics.Combined)"
}

$baselineNodes = Invoke-CompilerText -Compiler $baselineCompilerPath -Command 'typed-ir-nodes' -Sources $sources -Description 'baseline ZIP-closure Typed IR'
$candidateNodes = Invoke-CompilerText -Compiler $candidateCompilerPath -Command 'typed-ir-nodes' -Sources $sources -Description 'candidate ZIP-closure Typed IR'
$baselineTopology = Read-SourceZeroTopology -Text $baselineNodes.Stdout
$candidateTopology = Read-SourceZeroTopology -Text $candidateNodes.Stdout
$baselineCall = $baselineTopology[3019]
$baselineMatch = $baselineTopology[3025]
$baselineWrapper = $baselineTopology[6387]
$candidateCall = $candidateTopology[3019]
$candidateMatch = $candidateTopology[3025]
$candidateWrapper = $candidateTopology[6387]
foreach ($topology in @(
    @($baselineCall, $baselineMatch, $baselineWrapper),
    @($candidateCall, $candidateMatch, $candidateWrapper)
)) {
    if ($null -eq $topology[0] -or $topology[0].Kind -ne 6 -or $topology[0].Target -ne 4 -or
        $topology[0].Symbol -ne 870 -or $topology[0].Type -cne '78/7/4/-1/1/1' -or
        $null -eq $topology[1] -or $topology[1].Kind -ne 27 -or
        $null -eq $topology[2] -or $topology[2].Kind -ne 9 -or $topology[2].Opcode -ne -1 -or
        $topology[0].Parent -ne $topology[2].Node -or $topology[2].Parent -ne $topology[1].Parent -or
        $topology[2].NextOperand -ne $topology[1].Node) {
        throw 'C453 ZIP-closure call/match/wrapper topology changed outside the intended subject edge'
    }
}
if ($baselineMatch.Operand0 -eq $baselineCall.Node -or $baselineMatch.Operand0 -ne 1840) {
    throw "C453 baseline did not preserve the exact stale subject 1840: actual=$($baselineMatch.Operand0)"
}
if ($candidateMatch.Operand0 -ne $candidateCall.Node) {
    throw "C453 candidate match subject is not the exact wrapped Result call: expected=$($candidateCall.Node) actual=$($candidateMatch.Operand0)"
}

$baselineBatch = Get-Content -LiteralPath $BaselineBatchResult -Raw | ConvertFrom-Json
$candidateBatch = Get-Content -LiteralPath $CandidateBatchResult -Raw | ConvertFrom-Json
$completion = Get-Content -LiteralPath $CandidateCompletionRecord -Raw | ConvertFrom-Json
foreach ($batch in @($baselineBatch, $candidateBatch)) {
    if ($batch.schemaVersion -ne 1 -or $batch.total -ne 1 -or @($batch.results).Count -ne 1 -or
        $batch.results[0].Fixture -cne '1452-each-call-result-record-type') {
        throw 'C453 full-stdlib batch does not identify the exact 1452 fixture'
    }
}
if ($baselineBatch.compilerSha256 -cne $baselineHash -or $candidateBatch.compilerSha256 -cne $candidateHash) {
    throw 'C453 full-stdlib batch compiler hashes do not match the preserved compilers'
}
$baselineSource16S018 = [regex]::Matches([string]$baselineBatch.results[0].Error, 'S018:[^\r\n]*source 16,').Count
$candidateSource16Diagnostics = [regex]::Matches([string]$candidateBatch.results[0].Error, 'sollang compiler error [A-Z]\d{3}:[^\r\n]*source 16,').Count
if ($baselineSource16S018 -ne 1 -or $candidateSource16Diagnostics -ne 0) {
    throw "C453 full-stdlib source-16 closure mismatch: baselineS018=$baselineSource16S018 candidateDiagnostics=$candidateSource16Diagnostics"
}
if ($completion.schemaVersion -ne 3 -or $completion.runId -cne 'c453-wrapper-match-v12' -or
    $completion.executionMode -cne 'detached-supervisor' -or $completion.status -cne 'failed' -or
    $completion.exitCode -eq 0 -or -not $completion.processAudit.completed -or
    @($completion.orphanProcessIds).Count -ne 0) {
    throw 'C453 candidate completion is not a terminated fail-closed run with zero orphans'
}

$result = [ordered]@{
    schemaVersion = 1
    caseId = 'C2026-09-14-453'
    status = 'passed'
    completed = 8
    total = 8
    baselineCompilerSha256 = $baselineHash
    candidateCompilerSha256 = $candidateHash
    sourceClosureCount = $sources.Count
    baselineDiagnosticCount = 1
    candidateDiagnosticCount = 0
    callAst = 3019
    matchAst = 3025
    wrapperAst = 6387
    baselineMatchOperand0 = $baselineMatch.Operand0
    candidateMatchOperand0 = $candidateMatch.Operand0
    exactCallNode = $candidateCall.Node
    baselineFullStdlibSource16S018 = $baselineSource16S018
    candidateFullStdlibSource16Diagnostics = $candidateSource16Diagnostics
    remainingFullStdlibSource = 43
    remainingFullStdlibDiagnosticCount = [regex]::Matches([string]$candidateBatch.results[0].Error, 'sollang compiler error [A-Z]\d{3}:').Count
    orphanProcessIds = @()
    productionSourceSha256 = (Get-FileHash -LiteralPath $productionSource -Algorithm SHA256).Hash
    candidateBatchSha256 = (Get-FileHash -LiteralPath $CandidateBatchResult -Algorithm SHA256).Hash
    candidateCompletionSha256 = (Get-FileHash -LiteralPath $CandidateCompletionRecord -Algorithm SHA256).Hash
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($result | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
Write-Host "[C453 wrapped Result match subject] PASS 8/8 compiler=$candidateHash result=$resolvedOutput"
