[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$unit = Get-Content -LiteralPath (Join-Path $root 'artifacts/scratch/c611-source-call-interpolation-semantic-owner-unit-20260929-01.json') -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
$focused = $unit.steps[3]
$many = Get-Content -LiteralPath $focused.manyArgumentEvidence -Raw | ConvertFrom-Json
$retained = Get-Content -LiteralPath $focused.retainedEvidence -Raw | ConvertFrom-Json
$priorFailure = Get-Content -LiteralPath $focused.priorFailureEvidence -Raw | ConvertFrom-Json
$managed = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw
$ir = Get-Content -LiteralPath (Join-Path $root 'selfhost/ir/interpolation.slg') -Raw
$semantic = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/interpolation_inference.slg') -Raw
$preparation = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/context_prepare.slg') -Raw
$context = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/emitter/context.slg') -Raw
$diagnostics = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/emitter/diagnostics.slg') -Raw
$emitter = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Raw

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $many.status -cne 'passed' -or -not $many.inputStable -or $many.completed -ne 2 -or $many.total -ne 2 -or
    $retained.status -cne 'passed' -or -not $retained.inputStable -or $retained.completed -ne 5 -or $retained.total -ne 5 -or
    $priorFailure.status -cne 'failed' -or
    @($many.runs + $retained.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private BoundType InferCallExpression(', [StringComparison]::Ordinal) -or
    -not $ir.Contains('directChildCount! > 3', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public directCallExpectedArityByNode', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('ir[target].nextOperand => parameterIndex!', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('call.argumentCount => provided', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationInference.directCallExpectedArityByNode', [StringComparison]::Ordinal) -or
    -not $context.Contains('public directCallExpectedArityByNode:', [StringComparison]::Ordinal) -or
    -not $diagnostics.Contains('context.directCallExpectedArityByNode[nodeIndex!]', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('interpolationCallArgumentAt nodeIndex:', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('node.kind == 8 -> if { -1 -> return }', [StringComparison]::Ordinal)) {
    throw 'C611 source-call semantic ownership or focused native proof failed'
}

foreach ($path in $focused.negativeEvidence) {
    $negative = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $receiptDirectory = Split-Path -Parent $path
    $managedStderr = [IO.File]::ReadAllText((Join-Path $receiptDirectory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $receiptDirectory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    $expected = [IO.File]::ReadAllText($negative.expected).Replace("`r`n", "`n")
    if (-not $negative.inputsStable -or $negative.failureId -ne $null -or
        $negative.selfhostCompilerSha256 -cne $build.compilerSha256 -or
        $negative.managed.exitCode -ne 1 -or $negative.selfhost.exitCode -ne 1 -or
        -not $negative.managed.noEmittedProducts -or -not $negative.selfhost.noEmittedProducts -or
        $managedStderr -cne $selfhostStderr -or $managedStderr -cne $expected) {
        throw "C611 negative diagnostic mismatch: $path"
    }
}

Write-Host '[C611 source-call semantic owner] PASS many-argument native 2/2, retained native 5/5, exact normalized negative stderr 2/2, source owner present.'
