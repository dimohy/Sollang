[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PriorResultDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'c476-dictionary-negative-classification.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$prior = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($PriorResultDirectory)) {
    $PriorResultDirectory
} else { Join-Path $root $PriorResultDirectory }))
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else { Join-Path $root $OutputDirectory }))
$classifier = Join-Path $PSScriptRoot 'c476-dictionary-negative-classification.ps1'
$aggregateSchema = Join-Path $PSScriptRoot 'contracts/c476-dictionary-negatives-result.schema.json'
$caseSchema = Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'
$resultSchema = Join-Path $PSScriptRoot 'contracts/c476-dictionary-reclassification-result.schema.json'

function Assert-NoReparseAncestors([string]$Path) {
    $cursor = [IO.Path]::GetPathRoot($Path)
    foreach ($segment in $Path.Substring($cursor.Length) -split '[\\/]') {
        if ($segment) { $cursor = Join-Path $cursor $segment }
        try { $attributes = [IO.File]::GetAttributes($cursor) }
        catch [IO.FileNotFoundException] { return }
        catch [IO.DirectoryNotFoundException] { return }
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "C476 reclassification path traverses a junction or symbolic link: $cursor"
        }
    }
}
foreach ($path in @($root, $scratch, $prior, $output, $classifier, $aggregateSchema, $caseSchema,
        $resultSchema)) { Assert-NoReparseAncestors $path }
foreach ($entry in @(@{ Path = $prior; Name = 'PriorResultDirectory' },
        @{ Path = $output; Name = 'OutputDirectory' })) {
    if (-not $entry.Path.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "$($entry.Name) must be below $scratch`: $($entry.Path)"
    }
}
if ($output.StartsWith($prior + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'C476 reclassification output must not be inside the original result directory'
}
if (Test-Path -LiteralPath $output) { throw "C476 reclassification output must be unused: $output" }
$priorResultPath = Join-Path $prior 'result.json'
if (-not (Test-Path -LiteralPath $priorResultPath -PathType Leaf)) {
    throw "C476 original aggregate result missing: $priorResultPath"
}
$priorJson = [IO.File]::ReadAllText($priorResultPath)
if (-not (Test-Json -Json $priorJson -SchemaFile $aggregateSchema)) {
    throw 'C476 original aggregate result violates its schema'
}
$priorResult = $priorJson | ConvertFrom-Json
if ($priorResult.state -ceq 'running' -or $priorResult.completed -ne 10 -or
    -not $priorResult.inputsStable -or
    $priorResult.inputFingerprintStart -cne $priorResult.inputFingerprintEnd) {
    throw 'C476 original aggregate result is not a stable completed ten-case execution'
}
$caseNames = @(
    'generic-dictionary-put-wrong-key', 'generic-dictionary-put-wrong-value',
    'generic-dictionary-put-no-arguments', 'generic-dictionary-put-one-argument',
    'generic-dictionary-put-three-arguments',
    'generic-dictionary-put-if-absent-wrong-key', 'generic-dictionary-put-if-absent-wrong-value',
    'generic-dictionary-put-if-absent-no-arguments', 'generic-dictionary-put-if-absent-one-argument',
    'generic-dictionary-put-if-absent-three-arguments'
)
if (@($priorResult.cases).Count -ne $caseNames.Count) {
    throw 'C476 original aggregate does not contain exactly ten cases'
}
$newCases = @()
$semanticPairs = 0
$strictPairs = 0
foreach ($name in $caseNames) {
    $aggregateCases = @($priorResult.cases | Where-Object { $_.id -ceq $name })
    if ($aggregateCases.Count -ne 1) { throw "C476 original aggregate case missing or repeated: $name" }
    $casePath = Join-Path (Join-Path $prior $name) 'result.json'
    Assert-NoReparseAncestors $casePath
    if (-not [IO.File]::Exists($casePath) -or
        -not $aggregateCases[0].resultPath.Equals($casePath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "C476 original case result path differs: $name"
    }
    $caseJson = [IO.File]::ReadAllText($casePath)
    if (-not (Test-Json -Json $caseJson -SchemaFile $caseSchema)) {
        throw "C476 original case result violates its schema: $name"
    }
    $caseResult = $caseJson | ConvertFrom-Json
    if ($caseResult.state -ceq 'running' -or -not $caseResult.inputsStable -or
        $caseResult.inputFingerprintStart -cne $caseResult.inputFingerprintEnd -or
        $caseResult.managedCompilerSha256 -cne $priorResult.managedCompilerSha256 -or
        $caseResult.selfhostCompilerSha256 -cne $priorResult.selfhostCompilerSha256) {
        throw "C476 original case is incomplete or has inconsistent compiler identity: $name"
    }
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $root "examples/regression/diagnostics/$name.slg"))
    $expectedPath = $sourcePath.Substring(0, $sourcePath.Length - 4) + '.stderr.contains.txt'
    foreach ($path in @($sourcePath, $expectedPath)) { Assert-NoReparseAncestors $path }
    if (-not $caseResult.source.Equals($sourcePath, [StringComparison]::OrdinalIgnoreCase) -or
        -not $caseResult.expected.Equals($expectedPath, [StringComparison]::OrdinalIgnoreCase) -or
        (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -cne $caseResult.sourceSha256 -or
        (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash -cne $caseResult.expectedSha256) {
        throw "C476 original fixture identity changed: $name"
    }
    foreach ($compiler in @('managed', 'selfhost')) {
        $compilerOutput = Join-Path (Split-Path -Parent $casePath) $compiler
        if (-not $caseResult.$compiler.outputDirectory.Equals($compilerOutput,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "C476 original compiler output path differs: $name/$compiler"
        }
        Assert-NoReparseAncestors $compilerOutput
        $recorded = @($caseResult.$compiler.generatedProducts | Sort-Object)
        $observed = @(Get-ChildItem -LiteralPath $compilerOutput -Recurse -Force | ForEach-Object FullName |
            Sort-Object)
        if (($recorded -join "`n") -cne ($observed -join "`n")) {
            throw "C476 original generated products changed: $name/$compiler"
        }
        foreach ($product in $observed) { Assert-NoReparseAncestors $product }
    }
    $expectedDiagnostic = [IO.File]::ReadAllText($expectedPath).Trim()
    $managed = Get-C476Evidence $caseResult.managed $expectedDiagnostic
    $selfhost = Get-C476Evidence $caseResult.selfhost $expectedDiagnostic
    $semanticPair = (Test-C476SemanticEligibility $caseResult) -and
        $managed.state -ceq 'passed' -and $selfhost.state -ceq 'passed'
    $strictPair = $caseResult.state -ceq 'passed' -and $semanticPair -and
        $managed.noEmittedProducts -and $selfhost.noEmittedProducts
    if ($semanticPair) { $semanticPairs++ }
    if ($strictPair) { $strictPairs++ }
    $diagnosticLl = Join-Path $caseResult.selfhost.outputDirectory 'negative.exe.ll'
    $diagnosticLlSha = if (Test-C476DiagnosticOnlyLlProduct $diagnosticLl `
            $caseResult.selfhost.outputDirectory $expectedDiagnostic) {
        (Get-FileHash -LiteralPath $diagnosticLl -Algorithm SHA256).Hash
    } else { $null }
    $newCases += [ordered]@{
        id = $name
        sourceResultPath = $casePath
        sourceResultSha256 = (Get-FileHash -LiteralPath $casePath -Algorithm SHA256).Hash
        selfhostDiagnosticOnlyLlSha256 = $diagnosticLlSha
        managed = $managed
        selfhost = $selfhost
        semanticPairPassed = $semanticPair
        strictParityPassed = $strictPair
    }
}
$result = [ordered]@{
    schemaVersion = 1
    gate = 'c476-dictionary-negatives-reclassification'
    state = 'classified'
    classificationOnly = $true
    compilersExecuted = $false
    classifierSha256 = (Get-FileHash -LiteralPath $classifier -Algorithm SHA256).Hash
    sourceResultPath = $priorResultPath
    sourceResultSha256 = (Get-FileHash -LiteralPath $priorResultPath -Algorithm SHA256).Hash
    sourceInputFingerprint = $priorResult.inputFingerprintStart
    total = 10
    completed = 10
    semanticPairPassed = $semanticPairs
    strictParityPassed = $strictPairs
    cases = $newCases
}
$json = $result | ConvertTo-Json -Depth 10
if (-not (Test-Json -Json $json -SchemaFile $resultSchema)) {
    throw 'C476 reclassification result violates its schema'
}
[void][IO.Directory]::CreateDirectory($output)
Assert-NoReparseAncestors $output
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
Write-Host "[C476 reclassification] semantic $semanticPairs/10; strict $strictPairs/10; no compilers executed; $resultPath"
