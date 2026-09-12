[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$productionPath = Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.BorrowOrigins.cs'
$typeAlgorithmPath = Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'
$fixturePath = Join-Path $root 'scripts/contracts/fixtures/borrowed-source-text-return-carriers.cs'
$output = Join-Path $root ('artifacts/scratch/borrowed-source-text-return-carriers-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    defectId = 'C2026-09-12-397'
    status = 'running'
    completed = 0
    total = 45
    checks = @()
}
try {
    $productionHash = (Get-FileHash -LiteralPath $productionPath -Algorithm SHA256).Hash
    $typeAlgorithmHash = (Get-FileHash -LiteralPath $typeAlgorithmPath -Algorithm SHA256).Hash
    $fixtureHash = (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash
    $scriptHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    $production = [IO.File]::ReadAllText($productionPath)
    $matches = [regex]::Matches($production,
        '(?ms)^    private bool TypeCanCarryBorrowedTextOrigin\(BoundType type\) =>\r?\n        TypeContains\(type, BoundType\.Text\)\r?\n        \|\| TypeContains\(type, BoundType\.SourceText\);')
    if ($matches.Count -ne 1) { throw "expected one production carrier predicate, found $($matches.Count)" }
    $record.completed++
    $record.checks += 'one-production-helper'
    if ([regex]::Matches($production,
            '!TypeCanCarryBorrowedTextOrigin\(function\.ReturnType\)').Count -ne 1) {
        throw 'borrowed-return discovery does not use the production carrier predicate exactly once'
    }
    $record.completed++
    $record.checks += 'discovery-uses-helper'
    $parameterStart = $production.IndexOf(
        '    private bool CanSupplyBorrowedTextOrigin(',
        [StringComparison]::Ordinal)
    $parameterEnd = $production.IndexOf(
        '    private bool IsBorrowedTextByteStorage(',
        $parameterStart,
        [StringComparison]::Ordinal)
    if ($parameterStart -lt 0 -or $parameterEnd -le $parameterStart) {
        throw 'production borrowed-origin parameter helper boundaries drifted'
    }
    $parameterHelper = $production.Substring(
        $parameterStart,
        $parameterEnd - $parameterStart).TrimEnd()
    if ([regex]::Matches($parameterHelper,
            'private bool CanSupplyBorrowedTextOrigin\(').Count -ne 1 -or
        -not $parameterHelper.Contains('type != BoundType.SourceText', [StringComparison]::Ordinal)) {
        throw 'production parameter helper does not preserve direct SourceText ownership while admitting nested carriers'
    }
    $record.completed++
    $record.checks += 'production-parameter-helper-inventory'
    if ([regex]::Matches($production,
            'CanSupplyBorrowedTextOrigin\(').Count -ne 3) {
        throw 'input and additional parameter discovery must share one borrowed-origin seed helper'
    }
    $record.completed++
    $record.checks += 'parameter-discovery-shares-seed-helper'
    $typeAlgorithmSource = [IO.File]::ReadAllText($typeAlgorithmPath)
    $algorithmStart = $typeAlgorithmSource.IndexOf('    private bool TypeContains(BoundType type, BoundType expected)', [StringComparison]::Ordinal)
    $algorithmEnd = $typeAlgorithmSource.IndexOf('    private static bool ContainsSliceFlow(', $algorithmStart, [StringComparison]::Ordinal)
    if ($algorithmStart -lt 0 -or $algorithmEnd -le $algorithmStart) { throw 'production TypeContains algorithm boundaries drifted' }
    $typeAlgorithm = $typeAlgorithmSource.Substring($algorithmStart, $algorithmEnd - $algorithmStart).TrimEnd()
    if ([regex]::Matches($typeAlgorithm, 'private bool TypeContains\(').Count -ne 2) {
        throw 'production TypeContains overload inventory drifted'
    }
    $record.completed++
    $record.checks += 'production-recursive-type-contains'
    $enumStart = $production.IndexOf(
        '    private bool TryGetBorrowedTextEnumPayload(Expression expression, out Expression payload)',
        [StringComparison]::Ordinal)
    $enumEnd = $production.IndexOf(
        '    private IReadOnlyList<string> InstallReadonlyReferenceEnumPatternOrigins(',
        $enumStart,
        [StringComparison]::Ordinal)
    if ($enumStart -lt 0 -or $enumEnd -le $enumStart) {
        throw 'production borrowed enum helper boundaries drifted'
    }
    $enumHelpers = $production.Substring($enumStart, $enumEnd - $enumStart).TrimEnd()
    if ([regex]::Matches($enumHelpers, 'private bool TryGetBorrowedTextEnumPayload\(').Count -ne 1 -or
        [regex]::Matches($enumHelpers, 'private bool TryGetBorrowCarrierEnumConstructor\(').Count -ne 1) {
        throw 'production borrowed enum helper inventory drifted'
    }
    $record.completed++
    $record.checks += 'production-enum-helper-inventory'
    if ([regex]::Matches($production,
            'if \(TryGetBorrowedTextEnumPayload\(expression, out var enumPayload\)\)').Count -ne 2) {
        throw 'discovery and call-site inference must both use the borrowed enum payload helper'
    }
    $record.completed++
    $record.checks += 'enum-helper-shared-by-discovery-and-call-site'
    if ([regex]::Matches($enumHelpers,
            'TypeCanCarryBorrowedTextOrigin\(payloadType\)').Count -ne 1) {
        throw 'borrowed enum payload helper does not use the recursive carrier predicate'
    }
    $record.completed++
    $record.checks += 'enum-helper-uses-carrier-predicate'
    $borrowSourceStart = $production.IndexOf(
        '    private bool TryGetBorrowedSourceCallSiteOrigins(',
        [StringComparison]::Ordinal)
    $borrowSourceEnd = $production.IndexOf(
        '    private void RejectLocalBorrowedTextReturnEscape(',
        $borrowSourceStart,
        [StringComparison]::Ordinal)
    if ($borrowSourceStart -lt 0 -or $borrowSourceEnd -le $borrowSourceStart) {
        throw 'production borrowed-source call-site helper boundaries drifted'
    }
    $borrowSourceHelper = $production.Substring(
        $borrowSourceStart,
        $borrowSourceEnd - $borrowSourceStart).TrimEnd()
    if ([regex]::Matches($borrowSourceHelper,
            'private bool TryGetBorrowedSourceCallSiteOrigins\(').Count -ne 1) {
        throw 'production borrowed-source call-site helper inventory drifted'
    }
    $record.completed++
    $record.checks += 'production-borrow-source-helper-inventory'
    if ([regex]::Matches($production,
            'return TryGetBorrowedSourceCallSiteOrigins\(').Count -ne 2) {
        throw 'direct and flowed runtime borrow paths must share the borrowed-source call-site helper'
    }
    $record.completed++
    $record.checks += 'runtime-borrow-paths-share-source-helper'
    $concreteIndex = $borrowSourceHelper.IndexOf(
        'TryGetConcreteBorrowOrigins(source, bindings, out origins)',
        [StringComparison]::Ordinal)
    $fallbackIndex = $borrowSourceHelper.IndexOf(
        'TryGetBorrowedTextCallOrigins(source, functions, bindings, out origins)',
        [StringComparison]::Ordinal)
    if ($concreteIndex -lt 0 -or $fallbackIndex -le $concreteIndex) {
        throw 'borrowed-source call-site helper must create concrete owner origins before carrier fallback'
    }
    $record.completed++
    $record.checks += 'concrete-owner-origin-before-carrier-fallback'
    if ([regex]::Matches($borrowSourceHelper,
            'private bool TryGetBorrowedCallSiteFunction\(').Count -ne 1 -or
        -not $borrowSourceHelper.Contains(
            '_resolvedGenericCalls.TryGetValue(callSite, out function!)',
            [StringComparison]::Ordinal)) {
        throw 'borrowed call-site resolver does not reuse the semantic resolution authority'
    }
    $record.completed++
    $record.checks += 'semantic-call-resolution-authority'
    if ([regex]::Matches($production,
            'TryGetBorrowedCallSiteFunction\(').Count -ne 3) {
        throw 'direct and flowed borrowed-origin paths must share one resolved call-site authority'
    }
    $record.completed++
    $record.checks += 'resolved-call-authority-shared-by-direct-and-flow'
    $returnEscapeStart = $production.IndexOf(
        '    private void RejectLocalBorrowedTextReturnEscape(',
        [StringComparison]::Ordinal)
    $returnEscapeEnd = $production.IndexOf(
        '    private static List<BoundType> FunctionParameterTypes(',
        $returnEscapeStart,
        [StringComparison]::Ordinal)
    if ($returnEscapeStart -lt 0 -or $returnEscapeEnd -le $returnEscapeStart) {
        throw 'production local borrowed-return escape helper boundaries drifted'
    }
    $returnEscapeHelper = $production.Substring(
        $returnEscapeStart,
        $returnEscapeEnd - $returnEscapeStart)
    if (-not $returnEscapeHelper.Contains('!TypeCanCarryBorrowedTextOrigin(returnType)', [StringComparison]::Ordinal) -or
        -not $returnEscapeHelper.Contains('returnOuterBindings.ContainsKey(root)', [StringComparison]::Ordinal) -or
        -not $returnEscapeHelper.Contains('cannot escape function', [StringComparison]::Ordinal)) {
        throw 'local borrowed-return escape helper does not guard scalar returns, preserve outer origins, and reject local origins'
    }
    $record.completed++
    $record.checks += 'local-return-escape-boundary'
    if ([regex]::Matches($typeAlgorithmSource,
            'RejectLocalBorrowedTextReturnEscape\(').Count -ne 2) {
        throw 'fallthrough and explicit returns must both consume local borrowed origins'
    }
    $record.completed++
    $record.checks += 'fallthrough-and-explicit-return-consumers'
    $nestedReturnStart = $production.IndexOf(
        '    private void CollectNestedBorrowedTextReturnOrigins(',
        [StringComparison]::Ordinal)
    $inferStart = $production.IndexOf(
        '    private bool TryInferBorrowedTextOrigins(',
        $nestedReturnStart,
        [StringComparison]::Ordinal)
    $inferEnd = $production.IndexOf(
        '    private bool TryUnionBorrowedTextOrigins(',
        $inferStart,
        [StringComparison]::Ordinal)
    if ($nestedReturnStart -lt 0 -or $inferStart -le $nestedReturnStart -or $inferEnd -le $inferStart) {
        throw 'production borrowed-return discovery boundaries drifted'
    }
    if (-not $production.Substring($nestedReturnStart, $inferStart - $nestedReturnStart).
            Contains('case EnumMatchExpression match:', [StringComparison]::Ordinal)) {
        throw 'nested borrowed-return discovery omits enum-match arms'
    }
    $record.completed++
    $record.checks += 'nested-return-enum-match-arms'
    if (-not $production.Substring($inferStart, $inferEnd - $inferStart).
            Contains('if (expression is EnumMatchExpression match)', [StringComparison]::Ordinal)) {
        throw 'borrowed-return discovery omits enum-match result arms'
    }
    $record.completed++
    $record.checks += 'return-discovery-enum-match-arms'
    $callSiteStart = $production.IndexOf(
        '    private bool TryGetBorrowedTextCallOrigins(',
        [StringComparison]::Ordinal)
    $callSiteEnd = $production.IndexOf(
        '    private bool TryGetReadonlyReferenceCallOrigins(',
        $callSiteStart,
        [StringComparison]::Ordinal)
    if ($callSiteStart -lt 0 -or $callSiteEnd -le $callSiteStart) {
        throw 'production borrowed call-site boundaries drifted'
    }
    $callSiteAlgorithm = $production.Substring($callSiteStart, $callSiteEnd - $callSiteStart)
    foreach ($controlType in @('IfExpression', 'WhenExpression', 'EnumMatchExpression')) {
        if (-not $callSiteAlgorithm.Contains($controlType, [StringComparison]::Ordinal)) {
            throw "borrowed call-site inference omits $controlType result arms"
        }
    }
    $record.completed++
    $record.checks += 'call-site-control-result-arms'
    if ([regex]::Matches($production,
            'private bool TryUnionBlockCallSiteBorrowedOrigins\(').Count -ne 1 -or
        [regex]::Matches($callSiteAlgorithm,
            'TryUnionBlockCallSiteBorrowedOrigins\(').Count -ne 3) {
        throw 'control expressions do not share one borrowed block-origin union helper'
    }
    $record.completed++
    $record.checks += 'shared-call-site-block-union'
    $fixture = [IO.File]::ReadAllText($fixturePath)
    if ([regex]::Matches($fixture, '/\*PRODUCTION_HELPER\*/').Count -ne 1 -or
        [regex]::Matches($fixture, '/\*PRODUCTION_PARAMETER_HELPER\*/').Count -ne 1 -or
        [regex]::Matches($fixture, '/\*PRODUCTION_TYPE_CONTAINS\*/').Count -ne 1 -or
        [regex]::Matches($fixture, '/\*PRODUCTION_ENUM_HELPERS\*/').Count -ne 1 -or
        [regex]::Matches($fixture, '/\*PRODUCTION_BORROW_SOURCE_HELPER\*/').Count -ne 1) {
        throw 'probe fixture marker drifted'
    }
    $source = $fixture.Replace('/*PRODUCTION_TYPE_CONTAINS*/', $typeAlgorithm.Trim()).
        Replace('/*PRODUCTION_HELPER*/', $matches[0].Value.Trim()).
        Replace('/*PRODUCTION_PARAMETER_HELPER*/', $parameterHelper.Trim()).
        Replace('/*PRODUCTION_ENUM_HELPERS*/', $enumHelpers.Trim()).
        Replace('/*PRODUCTION_BORROW_SOURCE_HELPER*/', $borrowSourceHelper.Trim())
    Add-Type -TypeDefinition $source -Language CSharp
    $observed = [SemanticCompilerProbe]::Run()
    if ($observed -cne 'PASS 26/26') { throw "borrowed carrier probe failed: $observed" }
    foreach ($name in @(
            'text', 'nested-text-struct', 'source-text', 'nested-source-struct',
            'nested-source-option', 'nested-source-result', 'unrelated-int',
            'unrelated-owned-return')) {
        $record.completed++
        $record.checks += $name
    }
    foreach ($name in @(
            'direct-source-default', 'direct-source-move', 'nested-source-default',
            'nested-source-move', 'text-move', 'byte-storage',
            'unrelated-parameter')) {
        $record.completed++
        $record.checks += $name
    }
    foreach ($name in @(
            'resolved-option-some', 'parsed-result-ok', 'result-error-payload',
            'payloadless-variant', 'unknown-variant', 'ordinary-expression')) {
        $record.completed++
        $record.checks += $name
    }
    foreach ($name in @(
            'local-owner-source', 'borrowed-view-source', 'unknown-source',
            'resolved-call-site', 'textual-call-fallback')) {
        $record.completed++
        $record.checks += $name
    }
    if ((Get-FileHash -LiteralPath $productionPath -Algorithm SHA256).Hash -cne $productionHash -or
        (Get-FileHash -LiteralPath $typeAlgorithmPath -Algorithm SHA256).Hash -cne $typeAlgorithmHash -or
        (Get-FileHash -LiteralPath $fixturePath -Algorithm SHA256).Hash -cne $fixtureHash -or
        (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash -cne $scriptHash) {
        throw 'borrowed-return probe inputs changed during execution'
    }
    if ($record.completed -ne $record.total) { throw 'borrowed-return probe count differs from contract' }
    $record.status = 'passed'
    $record.productionSha256 = $productionHash
    $record.typeAlgorithmSha256 = $typeAlgorithmHash
    $record.fixtureSha256 = $fixtureHash
    $record.verifierSha256 = $scriptHash
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"))
}
Write-Host "[borrowed SourceText return carriers] PASS $($record.completed)/$($record.total); $resultPath"
