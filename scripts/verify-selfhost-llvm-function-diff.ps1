[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$tool = Join-Path $PSScriptRoot "compare-selfhost-llvm-functions.ps1"
$fixtureRoot = Join-Path $PSScriptRoot "contracts\llvm-function-diff"
$baseline = Join-Path $fixtureRoot "baseline.ll"
$candidate = Join-Path $fixtureRoot "candidate.ll"
$duplicate = Join-Path $fixtureRoot "duplicate.ll"
$unterminated = Join-Path $fixtureRoot "unterminated.ll"

foreach ($required in @($tool, $baseline, $candidate, $duplicate, $unterminated)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "LLVM function-diff contract input is missing: $required"
    }
}

$record = (& $tool -Baseline $baseline -Candidate $candidate | ConvertFrom-Json)
if ($record.schemaVersion -ne 1 -or
    $record.measurement -cne "llvm-function-body-sha256" -or
    $record.baseline.functionCount -ne 3 -or
    $record.candidate.functionCount -ne 3 -or
    @($record.added).Count -ne 1 -or $record.added[0] -cne "added" -or
    @($record.removed).Count -ne 1 -or $record.removed[0] -cne "removed" -or
    @($record.changed).Count -ne 1 -or $record.changed[0] -cne "changed") {
    throw "LLVM function-diff positive contract drifted"
}

$duplicateRejected = $false
try {
    & $tool -Baseline $baseline -Candidate $duplicate | Out-Null
} catch {
    $duplicateRejected = $_.Exception.Message -match "duplicate LLVM function definition 'repeated'"
}
if (-not $duplicateRejected) {
    throw "LLVM function-diff accepted duplicate definitions"
}

$unterminatedRejected = $false
try {
    & $tool -Baseline $baseline -Candidate $unterminated | Out-Null
} catch {
    $unterminatedRejected = $_.Exception.Message -match "unterminated LLVM function definition 'unfinished'"
}
if (-not $unterminatedRejected) {
    throw "LLVM function-diff accepted an unterminated definition"
}

Write-Host "[LLVM function diff] PASS exact add/remove/change plus duplicate and unterminated negative controls."
