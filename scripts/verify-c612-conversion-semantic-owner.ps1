[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$unit = Get-Content -LiteralPath (Join-Path $root 'artifacts/scratch/c612-builtin-conversion-semantic-owner-unit-20260929-01.json') -Raw | ConvertFrom-Json
$managedFirst = Get-Content -LiteralPath $unit.steps[0].evidence -Raw | ConvertFrom-Json
$build = Get-Content -LiteralPath $unit.steps[2].evidence -Raw | ConvertFrom-Json
$focused = $unit.steps[3]
$positive = Get-Content -LiteralPath $focused.positiveEvidence -Raw | ConvertFrom-Json
$managed = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw
$semantic = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/interpolation_inference.slg') -Raw
$preparation = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/context_prepare.slg') -Raw
$context = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/emitter/context.slg') -Raw
$emitter = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Raw

if ($unit.completed -ne 4 -or $unit.total -ne 4 -or
    @($unit.steps | Where-Object status -ne 'complete').Count -ne 0 -or
    $managedFirst.status -cne 'passed' -or -not $managedFirst.inputsStable -or
    $managedFirst.completed -ne 4 -or $managedFirst.total -ne 4 -or
    $build.status -cne 'passed' -or -not $build.inputsStable -or
    $positive.status -cne 'passed' -or -not $positive.inputStable -or
    $positive.completed -ne 3 -or $positive.total -ne 3 -or
    @($positive.runs | Where-Object {
        $_.compiler -ceq 'selfhost' -and $_.compilerSha256 -cne $build.compilerSha256
    }).Count -ne 0 -or
    -not $managed.Contains('private bool TryInferNumericConversion(', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('public numericConversionResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('and not invalidArity[nodeIndex!]', [StringComparison]::Ordinal) -or
    -not $semantic.Contains('and invalidLiteral[nodeIndex!] < 0', [StringComparison]::Ordinal) -or
    -not $preparation.Contains('interpolationInference.numericConversionResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $context.Contains('public numericConversionResultTypeByNode:', [StringComparison]::Ordinal) -or
    -not $emitter.Contains('context.numericConversionResultTypeByNode[semanticIndex]', [StringComparison]::Ordinal)) {
    throw 'C612 numeric conversion semantic owner or positive proof failed'
}

foreach ($path in $focused.negativeEvidence) {
    $negative = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent $path
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    $expected = [IO.File]::ReadAllText($negative.expected).Replace("`r`n", "`n").TrimEnd("`n")
    if (-not $negative.inputsStable -or $null -ne $negative.failureId -or
        $negative.selfhostCompilerSha256 -cne $build.compilerSha256 -or
        $negative.managed.exitCode -ne 1 -or $negative.selfhost.exitCode -ne 1 -or
        -not $negative.managed.noEmittedProducts -or -not $negative.selfhost.noEmittedProducts -or
        $managedStderr -cne $selfhostStderr -or
        -not $managedStderr.Contains($expected, [StringComparison]::Ordinal)) {
        throw "C612 exact conversion diagnostic mismatch: $path"
    }
}

Write-Host '[C612 conversion semantic owner] PASS managed first 4/4, native positive 3/3, normalized exact negative stderr 3/3, source owner present.'
