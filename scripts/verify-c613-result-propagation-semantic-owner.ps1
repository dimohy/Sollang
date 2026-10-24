[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-C613ExpectedDiagnostic([string]$CurrentRoot, $Negative) {
    $sourceName = [IO.Path]::GetFileName([string]$Negative.source)
    $expectedName = [IO.Path]::ChangeExtension($sourceName, '.stderr.contains.txt')
    if ([IO.Path]::GetExtension($sourceName) -cne '.slg' -or
        [IO.Path]::GetFileName([string]$Negative.expected) -cne $expectedName) {
        throw 'C613 historical diagnostic source/expectation identity differs'
    }
    $expectedPath = ''
    foreach ($entry in @(
        @{ recorded = $Negative.source; name = $sourceName; hash = $Negative.sourceSha256 },
        @{ recorded = $Negative.expected; name = $expectedName; hash = $Negative.expectedSha256 }
    )) {
        $relative = [IO.Path]::Combine('examples', 'regression', 'diagnostics', $entry.name)
        $canonical = [IO.Path]::GetFullPath([IO.Path]::Combine($CurrentRoot, $relative))
        $historical = [IO.Path]::Combine('P:\MyWorks\Sollang', $relative)
        $recorded = [IO.Path]::GetFullPath([string]$entry.recorded)
        if (($recorded -ine $canonical -and $recorded -ine $historical) -or
            [string]$entry.hash -notmatch '^[0-9A-Fa-f]{64}$' -or
            (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash -ine $entry.hash) {
            throw 'C613 historical diagnostic canonical path or pinned bytes differ'
        }
        $expectedPath = $canonical
    }
    return $expectedPath
}
$unit = Get-Content -LiteralPath (Join-Path $root 'artifacts/scratch/c613-result-propagation-semantic-owner-unit-20260929-01.json') -Raw | ConvertFrom-Json
$managedFirst = Get-Content -LiteralPath $unit.steps[0].evidence -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
$focused = $unit.steps[3]
$positive = Get-Content -LiteralPath $focused.positiveEvidence -Raw | ConvertFrom-Json
$managed = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'))
$semantic = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
$preparation = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/context_prepare.slg'))
$context = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/emitter/context.slg'))
$diagnostics = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/emitter/diagnostics.slg'))
$emitter = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/foundation.slg'))
$interpolation = [IO.File]::ReadAllText((Join-Path $root 'selfhost/ir/interpolation.slg'))
$goal = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/active-goal-progress.json') -Raw | ConvertFrom-Json
$owner = Get-Content -LiteralPath (Join-Path $root $goal.currentResultPropagationOwnerEvidence) -Raw | ConvertFrom-Json
if ($owner.status -cne 'canonical-single-result-owner-focused-verified') {
    throw 'Current pre-IR Result owner has not completed its focused runtime verification'
}
$currentProof = Get-Content -LiteralPath (Join-Path $root $owner.runtimeProof) -Raw | ConvertFrom-Json
if ($currentProof.status -cne 'passed' -or -not $currentProof.inputsStable -or
    -not $currentProof.processesStopped -or $currentProof.completed -ne $currentProof.total -or
    $currentProof.total -ne 12) {
    throw 'Current Result owner production proof is incomplete'
}
foreach ($inputHash in $currentProof.inputHashes.PSObject.Properties) {
    if (-not (Test-Path -LiteralPath $inputHash.Name -PathType Leaf) -or
        (Get-FileHash -LiteralPath $inputHash.Name -Algorithm SHA256).Hash -cne $inputHash.Value) {
        throw "Current Result owner production input changed: $($inputHash.Name)"
    }
}
foreach ($mapping in $owner.sourceMapping) {
    $canonicalPath = [IO.Path]::GetFullPath((Join-Path $root $mapping.canonical))
    $candidatePath = [IO.Path]::GetFullPath((Join-Path $root $mapping.source))
    $input = $currentProof.inputHashes.PSObject.Properties[$candidatePath]
    if ((Get-FileHash -LiteralPath $canonicalPath -Algorithm SHA256).Hash -cne $mapping.afterSha256 -or
        $null -eq $input -or $input.Value -cne $mapping.afterSha256) {
        throw 'Current Result owner source differs from its production proof'
    }
}

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0 -or
    $managedFirst.status -cne 'passed' -or -not $managedFirst.inputsStable -or
    $managedFirst.completed -ne 5 -or $managedFirst.total -ne 5 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $positive.status -cne 'passed' -or -not $positive.inputStable -or
    $positive.completed -ne 2 -or $positive.total -ne 2 -or
    @($positive.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private BoundType InferTryExpression(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public preIrResultPropagationDecisionByNode', [StringComparison]::Ordinal) -or
    $semantic.Contains('public resultPropagationDecisionByNode', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('interpolationLexicalTypeFromIr', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationResultPropagationByNode: preIrResultPropagationDecisions', [StringComparison]::Ordinal) -or
    $preparation.Contains('interpolationInference.resultPropagationDecisionByNode(', [StringComparison]::Ordinal) -or
    -not $context.Contains('public interpolationResultPropagationByNode:', [StringComparison]::Ordinal) -or
    -not $diagnostics.Contains('context.interpolationResultPropagationByNode[interpolationIndex!].status > 0', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('decision.operandTypeId => resultTypeId', [StringComparison]::Ordinal) -or
    -not $interpolation.Contains('(loweredKind! == 3 or loweredKind! == 11)', [StringComparison]::Ordinal) -or
    $diagnostics.Contains('C613_PROBE', [StringComparison]::Ordinal)) {
    throw 'C613 Result propagation semantic ownership, source structure, or positive proof failed'
}

foreach ($path in $focused.negativeEvidence) {
    $negative = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent $path
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    $expectedPath = Resolve-C613ExpectedDiagnostic $root $negative
    $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $null -ne $negative.failureId -or
        $negative.selfhostCompilerSha256 -cne $build.compilerSha256 -or
        $negative.managed.exitCode -ne 1 -or $negative.selfhost.exitCode -ne 1 -or
        -not $negative.managed.noEmittedProducts -or -not $negative.selfhost.noEmittedProducts -or
        $managedStderr -cne $selfhostStderr -or
        -not $managedStderr.Contains($expected, [StringComparison]::Ordinal)) {
        throw "C613 exact Result propagation diagnostic mismatch: $path"
    }
}

Write-Host '[C613 Result propagation semantic owner] PASS historical C613 controls retained; current single pre-IR owner source matches focused production 12/12. Full native CLI and Stage gates remain separate.'
