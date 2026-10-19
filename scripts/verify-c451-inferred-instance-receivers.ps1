[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$compiler = (Resolve-Path -LiteralPath $CandidateCompiler).Path
$expectedHash = $ExpectedCompilerSha256.ToUpperInvariant()
$actualHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
if ($actualHash -cne $expectedHash) {
    throw "C451 compiler hash mismatch: expected=$expectedHash actual=$actualHash"
}

$scalarFixture = Join-Path $root 'scripts\contracts\fixtures\selfhost-scalar-and-move-instance.slg'
$siblingFixtures = @(
    Join-Path $root 'scripts\contracts\fixtures\selfhost-sibling-enum-variant-model.slg'
    Join-Path $root 'scripts\contracts\fixtures\selfhost-sibling-enum-variant-runtime.slg'
    Join-Path $root 'scripts\contracts\fixtures\selfhost-sibling-enum-variant-caller.slg'
)
$sourcePath = Join-Path $root 'selfhost\semantic\call_resolution_sources.slg'
$inputs = @($compiler, $scalarFixture, $sourcePath) + $siblingFixtures
foreach ($input in $inputs) {
    if (-not (Test-Path -LiteralPath $input -PathType Leaf)) {
        throw "C451 input is missing: $input"
    }
}

$source = [IO.File]::ReadAllText($sourcePath)
foreach ($contract in @(
    'moduleQualifiedTargetSymbol.kind == 27',
    'moduleQualifiedTargetSymbol.typeNode >= 0',
    'not (importedTargetSymbol.kind == 27',
    'importedTargetSymbol.typeNode >= 0',
    'siblingVariantSymbol.kind == 27',
    'siblingVariantSymbol.typeNode >= 0',
    'siblingVariantOwner.kind == 4',
    'siblingVariantAmbiguous!'
)) {
    if (-not $source.Contains($contract, [StringComparison]::Ordinal)) {
        throw "C451 source contract is missing: $contract"
    }
}

& (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check `
    -Source (@($scalarFixture) + $siblingFixtures + @($sourcePath))

if ($ValidateOnly) {
    Write-Host "[C451] PASS validated inputs compiler=$actualHash"
    return
}

function Assert-CleanDiagnostics {
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string[]]$Source)

    $capture = Invoke-VerificationProcessCapture `
        -FilePath $compiler `
        -ArgumentList (@('diagnostic-counts') + $Source) `
        -Description "C451 $Id diagnostic counts" `
        -TimeoutMilliseconds 30000
    # diagnostic-counts deliberately writes semantic/IR counts to stderr and
    # the final checked count to stdout. Reassemble that public command output
    # and require the complete three-line contract instead of treating stderr
    # as a compiler failure.
    $diagnostics = ($capture.Stderr + $capture.Stdout).Replace("`r`n", "`n").TrimEnd("`n")
    if ($capture.ExitCode -ne 0 -or $diagnostics -cne @'
semantic diagnostics = 0
ir diagnostics = 0
checked diagnostics = 0
'@) {
        throw "C451 $Id diagnostics were not clean:`n$($capture.Stdout)`n$($capture.Stderr)"
    }
}

Assert-CleanDiagnostics -Id 'scalar-and-move' -Source @($scalarFixture)
Assert-CleanDiagnostics -Id 'sibling-enum-variant' -Source $siblingFixtures

$calls = Invoke-VerificationProcessCapture `
    -FilePath $compiler `
    -ArgumentList (@('typed-ir-calls') + $siblingFixtures) `
    -Description 'C451 sibling enum variant call identity' `
    -TimeoutMilliseconds 30000
if ($calls.ExitCode -ne 0 -or $calls.Stderr.Length -ne 0 -or
    $calls.Stdout -notmatch '(?m)^resolution 1:9 .* target 0:3 source 0 status 0\r?$' -or
    $calls.Stdout -notmatch '(?m)^call \d+ source 1 ast 9 target 0:3 .* type \d+\r?$' -or
    $calls.Stdout -match '(?m)^call \d+ source 1 ast 9 target -1:-1 ') {
    throw "C451 sibling enum variant identity was not exact:`n$($calls.Stdout)`n$($calls.Stderr)"
}

$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$receiptPath = Join-Path $outputRoot 'c451-inferred-instance-receivers.json'
$receipt = [ordered]@{
    schemaVersion = 1
    caseId = 'C2026-09-14-451'
    status = 'passed'
    compilerSha256 = $actualHash
    completed = 3
    total = 3
    checks = @('scalar-and-move-diagnostics', 'sibling-enum-variant-diagnostics', 'sibling-enum-variant-call-identity')
    orphanProcessIds = @()
    inputSha256 = [ordered]@{}
}
foreach ($input in @($scalarFixture, $sourcePath) + $siblingFixtures) {
    $relative = [IO.Path]::GetRelativePath($root, $input).Replace('\', '/')
    $receipt.inputSha256[$relative] = (Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash
}
[IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
Write-Host "[C451] PASS 3/3 compiler=$actualHash receipt=$receiptPath"
