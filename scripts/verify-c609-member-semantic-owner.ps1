[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contract = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/interpolation-semantic-parity.json') -Raw | ConvertFrom-Json
$unit = Get-Content -LiteralPath (Join-Path $root $contract.memberSemanticOwnerEvidence) -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
$pair = Get-Content -LiteralPath $unit.steps[3].evidence -Raw | ConvertFrom-Json
$exact = Get-Content -LiteralPath (Join-Path $root $unit.steps[3].exactNegativeEvidence) -Raw | ConvertFrom-Json
$semantic = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/interpolation_inference.slg') -Raw
$preparation = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/context_prepare.slg') -Raw
$emitter = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Raw
$managed = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $pair.status -cne 'passed' -or -not $pair.inputStable -or
    $pair.completed -ne 4 -or $pair.total -ne 4 -or
    @($pair.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    $exact.status -cne 'passed' -or $exact.completed -ne 3 -or $exact.total -ne 3 -or
    @($exact.cases | Where-Object {
        -not $_.exact -or $_.selfhostCompilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private BoundType InferFieldAccessExpression(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public memberResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public memberFieldByNode', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public privateMemberFieldByNode', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationInference.memberFieldByNode', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('nodeIndex -> interpolationMemberFieldIndex(nodes, sourceModule, ownerIndex, beforeIndex, context, state)', [StringComparison]::Ordinal) -or
    $emitter.Contains('memberCursor! < memberEnd', [StringComparison]::Ordinal)) {
    throw 'C609 member interpolation semantic decision owner proof failed'
}

Write-Host '[C609 member semantic owner] PASS native pairs 4/4, exact negative stderr 3/3, source owner present.'
