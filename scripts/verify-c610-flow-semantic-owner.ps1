[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contract = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/interpolation-semantic-parity.json') -Raw | ConvertFrom-Json
$unit = Get-Content -LiteralPath (Join-Path $root $contract.flowSemanticOwnerEvidence) -Raw | ConvertFrom-Json
$managedFirst = Get-Content -LiteralPath (Join-Path $root $unit.steps[0].evidence) -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
$repair = Get-Content -LiteralPath $unit.steps[2].reproducedMismatchFixed -Raw | ConvertFrom-Json
$retained = Get-Content -LiteralPath $unit.steps[3].evidence -Raw | ConvertFrom-Json
$exact = Get-Content -LiteralPath (Join-Path $root $unit.steps[3].exactNegativeEvidence) -Raw | ConvertFrom-Json
$semantic = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/interpolation_inference.slg') -Raw
$preparation = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/context_prepare.slg') -Raw
$context = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/emitter/context.slg') -Raw
$emitter = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Raw
$managed = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0 -or
    -not $managedFirst.managedNativeMatchesExpected -or -not $managedFirst.inputsStable -or
    $managedFirst.managedBuildExit -ne 0 -or $managedFirst.managedNativeExit -ne 0 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $repair.status -cne 'passed' -or -not $repair.inputStable -or
    $repair.completed -ne 1 -or $repair.total -ne 1 -or
    $retained.status -cne 'passed' -or -not $retained.inputStable -or
    $retained.completed -ne 3 -or $retained.total -ne 3 -or
    @($repair.runs + $retained.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    $exact.status -cne 'passed' -or $exact.completed -ne 3 -or $exact.total -ne 3 -or
    @($exact.cases | Where-Object {
        -not $_.exact -or $_.selfhostCompilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private FlowResult InferFlowExpression(', [StringComparison]::Ordinal) -or
    -not $managed.Contains('private bool TryInferContainerFlowTarget(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public flowResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationInference.flowResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $context.Contains('public interpolationFlowTypeByNode:', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('context.interpolationFlowTypeByNode[semanticIndex]', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('lengthFromI64! and lengthResultWidth == 32', [StringComparison]::Ordinal)) {
    throw 'C610 intrinsic flow interpolation semantic decision owner proof failed'
}

Write-Host '[C610 flow semantic owner] PASS repaired native 1/1, retained native 3/3, exact negative stderr 3/3, source owner present.'
