[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contract = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/interpolation-semantic-parity.json') -Raw | ConvertFrom-Json
$unit = Get-Content -LiteralPath (Join-Path $root $contract.binarySemanticOwnerEvidence) -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
$pair = Get-Content -LiteralPath $unit.steps[3].evidence -Raw | ConvertFrom-Json
$exact = Get-Content -LiteralPath (Join-Path $root $unit.steps[3].exactNegativeEvidence) -Raw | ConvertFrom-Json
$semantic = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/interpolation_inference.slg') -Raw
$preparation = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/context_prepare.slg') -Raw
$context = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/emitter/context.slg') -Raw
$emitter = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Raw
$managed = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $pair.status -cne 'passed' -or -not $pair.inputStable -or
    $pair.completed -ne 3 -or $pair.total -ne 3 -or
    @($pair.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    $exact.status -cne 'passed' -or $exact.completed -ne 3 -or $exact.total -ne 3 -or
    @($exact.cases | Where-Object {
        -not $_.exact -or $_.selfhostCompilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private BoundType InferIntegerBinaryExpression(', [StringComparison]::Ordinal) -or
    -not $managed.Contains('private BoundType InferCompareExpression(', [StringComparison]::Ordinal) -or
    -not $managed.Contains('private BoundType InferLogicalExpression(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public binaryResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationInference.binaryResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $context.Contains('public interpolationBinaryTypeByNode:', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('context.interpolationBinaryTypeByNode[semanticIndex]', [StringComparison]::Ordinal)) {
    throw 'C608 binary interpolation semantic decision owner proof failed'
}

Write-Host '[C608 binary semantic owner] PASS native pairs 3/3, exact negative stderr 3/3, source owner present.'
