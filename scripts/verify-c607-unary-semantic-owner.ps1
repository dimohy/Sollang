[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contract = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/interpolation-semantic-parity.json') -Raw | ConvertFrom-Json
$unit = Get-Content -LiteralPath (Join-Path $root $contract.unarySemanticOwnerEvidence) -Raw | ConvertFrom-Json
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
    $pair.completed -ne 2 -or $pair.total -ne 2 -or
    @($pair.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    $exact.status -cne 'passed' -or $exact.completed -ne 2 -or $exact.total -ne 2 -or
    @($exact.cases | Where-Object {
        -not $_.exact -or $_.selfhostCompilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private BoundType InferNegateExpression(', [StringComparison]::Ordinal) -or
    -not $managed.Contains('private BoundType InferNotExpression(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public unaryResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationInference.unaryResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $context.Contains('public interpolationUnaryTypeByNode:', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('context.interpolationUnaryTypeByNode[semanticIndex]', [StringComparison]::Ordinal)) {
    throw 'C607 unary interpolation semantic decision owner proof failed'
}

Write-Host '[C607 unary semantic owner] PASS native pairs 2/2, exact negative stderr 2/2, source owner present.'
