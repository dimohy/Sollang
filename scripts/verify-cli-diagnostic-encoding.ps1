[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ContractPath = 'scripts/contracts/diagnostic-encoding-parity.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contract = Get-Content -LiteralPath (Join-Path $root $ContractPath) -Raw | ConvertFrom-Json
if ($contract.schemaVersion -eq 2) {
    $python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    & $python (Join-Path $root 'scripts/verify-current-diagnostic-encoding.py') --contract (Join-Path $root $ContractPath)
    if ($LASTEXITCODE -ne 0) { throw 'Current CLI diagnostic encoding evidence is incomplete or changed' }
    return
}
$sourcePath = Join-Path $root $contract.managedSource
$managedCompiler = Join-Path $root $contract.managedCompiler
$selfhostCompiler = Join-Path $root $contract.selfhostCompiler
$baseline = Get-Content -LiteralPath (Join-Path $root $contract.baselineReceipt) -Raw | ConvertFrom-Json
$pair = Get-Content -LiteralPath (Join-Path $root $contract.currentPairReceipt) -Raw | ConvertFrom-Json
$exact = Get-Content -LiteralPath (Join-Path $root $contract.exactStderrEvidence) -Raw | ConvertFrom-Json

foreach ($input in @(
    @{ Path = $sourcePath; Hash = $contract.managedSourceSha256 },
    @{ Path = $managedCompiler; Hash = $contract.managedCompilerSha256 },
    @{ Path = $selfhostCompiler; Hash = $contract.selfhostCompilerSha256 },
    @{ Path = $baseline.logs.managedStderr; Hash = $contract.baselineManagedStderrSha256 },
    @{ Path = $pair.logs.managedStderr; Hash = $contract.currentManagedStderrSha256 },
    @{ Path = $pair.logs.selfhostStderr; Hash = $contract.currentSelfhostStderrSha256 },
    @{ Path = $pair.source; Hash = $pair.sourceSha256 },
    @{ Path = $pair.expected; Hash = $pair.expectedSha256 }
)) {
    if (-not (Test-Path -LiteralPath $input.Path -PathType Leaf) -or
        (Get-FileHash -LiteralPath $input.Path -Algorithm SHA256).Hash -cne $input.Hash) {
        throw "Diagnostic encoding input changed: $($input.Path)"
    }
}
if ($contract.status -cne 'focused-passed-full-gate-open' -or
    $contract.comparison -cne 'strict-utf8-and-whole-stderr-ordinal-after-crlf-normalization' -or
    -not (Get-Content -LiteralPath $sourcePath -Raw).Contains('Console.OutputEncoding = new UTF8Encoding(false);', [StringComparison]::Ordinal) -or
    (Get-Item -LiteralPath (Join-Path $root $contract.managedBuildStderr)).Length -ne 0 -or
    -not (Test-Path -LiteralPath (Join-Path $root $contract.managedBuildStdout) -PathType Leaf) -or
    $baseline.failureId -cne 'NEGATIVE_CHECK_FAILED' -or $baseline.managed.expectedInStderr -or
    $pair.state -cne 'passed' -or -not $pair.inputsStable -or
    $pair.managedCompilerSha256 -cne $contract.managedCompilerSha256 -or
    $pair.selfhostCompilerSha256 -cne $contract.selfhostCompilerSha256 -or
    -not $pair.managed.noEmittedProducts -or -not $pair.selfhost.noEmittedProducts -or
    $exact.comparison -cne 'whole-stderr-ordinal-after-crlf-normalization' -or
    $exact.status -cne 'passed' -or $exact.completed -ne 1 -or $exact.total -ne 1 -or
    $exact.cases[0].receipt -cne $contract.currentPairReceipt -or
    -not $exact.cases[0].exact) {
    throw 'Diagnostic encoding source, build, baseline, or paired receipt is incomplete'
}

$strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
$baselineBytes = [IO.File]::ReadAllBytes($baseline.logs.managedStderr)
try {
    $null = $strictUtf8.GetString($baselineBytes)
    throw 'Baseline managed stderr unexpectedly decodes as UTF-8'
} catch [Text.DecoderFallbackException] {
    # The original Windows-codepage output must remain a failing control.
}
$managedBytes = [IO.File]::ReadAllBytes($pair.logs.managedStderr)
$selfhostBytes = [IO.File]::ReadAllBytes($pair.logs.selfhostStderr)
foreach ($bytes in @($managedBytes, $selfhostBytes)) {
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        throw 'Diagnostic stderr contains a UTF-8 BOM'
    }
}
$managedText = $strictUtf8.GetString($managedBytes).Replace("`r`n", "`n")
$selfhostText = $strictUtf8.GetString($selfhostBytes).Replace("`r`n", "`n")
$expected = [IO.File]::ReadAllText($pair.expected).Trim()
if ($managedText -cne $selfhostText -or
    -not $managedText.Contains($expected, [StringComparison]::Ordinal)) {
    throw 'Korean diagnostic differs after strict UTF-8 decoding and newline normalization'
}
$ascii = Get-Content -LiteralPath (Join-Path $root $contract.retainedAsciiExactEvidence) -Raw | ConvertFrom-Json
if ($ascii.comparison -cne 'whole-stderr-ordinal-after-crlf-normalization' -or
    $ascii.status -cne 'passed' -or $ascii.completed -ne 2 -or $ascii.total -ne 2 -or
    @($ascii.cases).Count -ne 2) {
    throw 'CLI UTF-8 change lacks two retained ASCII diagnostic controls'
}
foreach ($case in $ascii.cases) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $case.receipt) -Raw | ConvertFrom-Json
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.managedCompilerSha256 -cne $contract.managedCompilerSha256 -or
        $receipt.selfhostCompilerSha256 -cne $contract.selfhostCompilerSha256 -or
        (Get-FileHash -LiteralPath $receipt.source -Algorithm SHA256).Hash -cne $receipt.sourceSha256 -or
        (Get-FileHash -LiteralPath $receipt.expected -Algorithm SHA256).Hash -cne $receipt.expectedSha256 -or
        -not $case.exact -or
        $strictUtf8.GetString([IO.File]::ReadAllBytes($receipt.logs.managedStderr)).Replace("`r`n", "`n") -cne
            $strictUtf8.GetString([IO.File]::ReadAllBytes($receipt.logs.selfhostStderr)).Replace("`r`n", "`n")) {
        throw "CLI UTF-8 retained ASCII case changed: $($case.receipt)"
    }
}
$positive = Get-Content -LiteralPath (Join-Path $root $contract.retainedPositivePair) -Raw | ConvertFrom-Json
$managedExe = Join-Path (Split-Path -Parent $managedCompiler) 'Sollang.Compiler.exe'
if ($positive.status -cne 'passed' -or -not $positive.inputStable -or
    $positive.completed -ne 1 -or $positive.total -ne 1 -or
    $positive.inputHashesStart.PSObject.Properties[$managedExe].Value -cne
        (Get-FileHash -LiteralPath $managedExe -Algorithm SHA256).Hash -or
    $positive.inputHashesStart.PSObject.Properties[$selfhostCompiler].Value -cne
        $contract.selfhostCompilerSha256) {
    throw 'CLI UTF-8 change lacks current positive native control'
}
Write-Host '[CLI diagnostic encoding] PASS strict UTF-8 Korean 1/1, retained ASCII 2/2, native positive 1/1; baseline invalid UTF-8'
