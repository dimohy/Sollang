[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][ValidateSet('Baseline', 'Candidate')][string]$Mode,
    [string]$CandidateBatchResult = '',
    [string]$CandidateCompletionRecord = '',
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$compilerHash = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
$expectedHash = $ExpectedCompilerSha256.ToUpperInvariant()
if ($compilerHash -cne $expectedHash) {
    throw "C452 compiler hash mismatch: expected=$expectedHash actual=$compilerHash"
}
$fixture = Join-Path $root 'stdlib\std\algorithm.slg'
$productionSources = @(
    (Join-Path $root 'selfhost\semantic\expression_types.slg')
    (Join-Path $root 'selfhost\semantic\expression_type_ids_resolution_phases.slg')
)
& (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source (@($fixture) + $productionSources)
foreach ($sourcePath in $productionSources) {
    $source = [IO.File]::ReadAllText($sourcePath)
    if ([regex]::Matches($source, 'yieldOwner\.kind == 7\s+or yieldOwner\.kind == 31').Count -ne 1 -or
        [regex]::Matches($source, '\(yieldFunctionCandidate\.kind == 7\s+or yieldFunctionCandidate\.kind == 31\)').Count -ne 1) {
        throw "C452 method-function owner parity contract is missing: $sourcePath"
    }
}

$diagnostics = Invoke-VerificationProcessCapture `
    -FilePath $compilerPath `
    -ArgumentList @('diagnostic-counts', $fixture) `
    -Description "C452 $Mode diagnostics" `
    -TimeoutMilliseconds 30000
$diagnosticText = ($diagnostics.Stderr + $diagnostics.Stdout).Replace("`r`n", "`n").TrimEnd("`n")
$expectedDiagnosticText = if ($Mode -ceq 'Baseline') {
@'
semantic diagnostics = 0
ir diagnostics = 2
checked diagnostics = 2
'@
} else {
@'
semantic diagnostics = 0
ir diagnostics = 0
checked diagnostics = 0
'@
}
if ($diagnostics.ExitCode -ne 0 -or $diagnosticText -cne $expectedDiagnosticText) {
    throw "C452 $Mode diagnostic contract mismatch:`n$diagnosticText"
}

$nodes = Invoke-VerificationProcessCapture `
    -FilePath $compilerPath `
    -ArgumentList @('typed-ir-nodes', $fixture) `
    -Description "C452 $Mode Typed IR" `
    -TimeoutMilliseconds 30000
if ($nodes.ExitCode -ne 0 -or $nodes.Stderr.Length -ne 0) {
    throw "C452 $Mode Typed IR inventory failed:`n$($nodes.Stdout)`n$($nodes.Stderr)"
}
$expectedType = if ($Mode -ceq 'Baseline') { '-1/-1/1/-1/0/0' } else { '23/1/1/-1/23/0' }
$records = @{}
foreach ($line in @($nodes.Stdout -split "`r?`n")) {
    if ($line -match '^node (?<node>\d+) kind (?<kind>\d+) .* ast (?<ast>\d+) .* type (?<type>[^ ]+) .* opcode (?<opcode>-?\d+) operands (?<operand0>-?\d+)/') {
        $records[[int]$Matches.ast] = [pscustomobject]@{
            Node = [int]$Matches.node
            Kind = [int]$Matches.kind
            Type = $Matches.type
            Opcode = [int]$Matches.opcode
            Operand0 = [int]$Matches.operand0
        }
    }
}
foreach ($pair in @(@(83, 84), @(130, 131))) {
    $binding = $records[$pair[0]]
    $yield = $records[$pair[1]]
    if ($null -eq $binding -or $binding.Kind -ne 17 -or $binding.Type -cne $expectedType -or
        $null -eq $yield -or $yield.Kind -ne 9 -or $yield.Type -cne $expectedType -or
        $yield.Opcode -ne -227 -or $binding.Operand0 -ne $yield.Node) {
        throw "C452 $Mode Typed IR AST pair $($pair -join '/') is not an exact typed binding-to-yield edge"
    }
}

$fullStdlibSource0S054 = $null
if ($Mode -ceq 'Candidate') {
    if ([string]::IsNullOrWhiteSpace($CandidateBatchResult) -or
        [string]::IsNullOrWhiteSpace($CandidateCompletionRecord)) {
        throw 'C452 Candidate requires the detached full-stdlib batch and completion records'
    }
    $batch = Get-Content -LiteralPath $CandidateBatchResult -Raw | ConvertFrom-Json
    $completion = Get-Content -LiteralPath $CandidateCompletionRecord -Raw | ConvertFrom-Json
    if ($batch.schemaVersion -ne 1 -or $batch.compilerSha256 -cne $compilerHash -or
        $batch.total -ne 1 -or @($batch.results).Count -ne 1 -or
        $batch.results[0].Fixture -cne '1452-each-call-result-record-type') {
        throw 'C452 Candidate batch does not identify the expected compiler and exact fixture'
    }
    $fullStdlibSource0S054 = [regex]::Matches(
        [string]$batch.results[0].Error,
        'S054:[^\r\n]*source 0,').Count
    if ($fullStdlibSource0S054 -ne 0 -or
        $completion.schemaVersion -ne 3 -or
        $completion.runId -cne 'c452-method-yield-v11' -or
        $completion.executionMode -cne 'detached-supervisor' -or
        @($completion.orphanProcessIds).Count -ne 0 -or
        -not $completion.processAudit.completed) {
        throw 'C452 Candidate full-stdlib source-0 or detached process contract failed'
    }
}

$result = [ordered]@{
    schemaVersion = 1
    caseId = 'C2026-09-14-452'
    phase = $Mode.ToLowerInvariant()
    status = 'passed'
    compilerSha256 = $compilerHash
    completed = if ($Mode -ceq 'Baseline') { 5 } else { 7 }
    total = if ($Mode -ceq 'Baseline') { 5 } else { 7 }
    diagnosticCount = if ($Mode -ceq 'Baseline') { 2 } else { 0 }
    typedBlockFunctionKind = 31
    yieldAstIds = @(84, 131)
    bindingAstIds = @(83, 130)
    expectedType = $expectedType
    fullStdlibSource0S054 = $fullStdlibSource0S054
    orphanProcessIds = @()
    fixtureSha256 = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    productionSourceSha256 = [ordered]@{
        'selfhost/semantic/expression_types.slg' = (Get-FileHash -LiteralPath $productionSources[0] -Algorithm SHA256).Hash
        'selfhost/semantic/expression_type_ids_resolution_phases.slg' = (Get-FileHash -LiteralPath $productionSources[1] -Algorithm SHA256).Hash
    }
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, ($result | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
Write-Host "[C452 method typed-block yield] PASS $Mode $($result.completed)/$($result.total) compiler=$compilerHash result=$resolvedOutput"
