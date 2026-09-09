[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$astPath = Join-Path $root "selfhost\syntax\ast.slg"
$loweringPath = Join-Path $root "selfhost\ir\typed\function_lowering.slg"
$finalizePath = Join-Path $root "selfhost\ir\typed\resolved_context_finalize.slg"
$ordinaryPath = Join-Path $root "selfhost\ir\typed\ordinary_function.slg"
$sourceLoweringPath = Join-Path $root "selfhost\ir\typed\source_lowering.slg"
$fixturePath = Join-Path $root "examples\regression\1322-selfhost-late-enum-member-chain.slg"
$manifestPath = Join-Path $root "examples\regression\expected\1322-selfhost-late-enum-member-chain.sources.txt"
$nestedResultFixturePath = Join-Path $root "examples\regression\1331-selfhost-imported-result-payload-method.slg"
$nestedResultManifestPath = Join-Path $root "examples\regression\expected\1331-selfhost-imported-result-payload-method.sources.txt"
$runtimeManifestPath = Join-Path $root "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"

foreach ($path in @($astPath, $loweringPath, $finalizePath, $ordinaryPath, $sourceLoweringPath, $fixturePath, $manifestPath, $nestedResultFixturePath, $nestedResultManifestPath, $runtimeManifestPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "late enum member-chain dependency is missing: $path"
    }
}

$ast = [System.IO.File]::ReadAllText($astPath)
if (-not $ast.Contains("(postfixKinds! -> len) > 1", [System.StringComparison]::Ordinal) -or
    $ast.Contains("(postfixKinds! -> len) > 1 and postfixHasIndex!", [System.StringComparison]::Ordinal)) {
    throw "pure member/member postfix prefixes are not materialized"
}

$ordinary = [System.IO.File]::ReadAllText($ordinaryPath)
$sourceLowering = [System.IO.File]::ReadAllText($sourceLoweringPath)
if (-not $ordinary.Contains("qualifiedFunctionPathByAst", [System.StringComparison]::Ordinal) -or
    -not $ordinary.Contains("knownCallResultMemberExpression", [System.StringComparison]::Ordinal) -or
    -not $sourceLowering.Contains("qualifiedEntryFunctionPath", [System.StringComparison]::Ordinal) -or
    -not $sourceLowering.Contains("knownEntryCallResultMemberExpression", [System.StringComparison]::Ordinal)) {
    throw "qualified callee and call-result member exclusions are not retained"
}

$lowering = [System.IO.File]::ReadAllText($loweringPath)
if (([regex]::Matches($lowering, "sealLateNominalMemberTypes results:")).Count -ne 1 -or
    -not $lowering.Contains("results -> sealLateNominalMemberTypes", [System.StringComparison]::Ordinal)) {
    throw "late nominal-member sealing is not a single reusable helper"
}
if (([regex]::Matches($lowering, "localMemberRoots prepared:")).Count -ne 1 -or
    -not $ordinary.Contains("prepared -> localMemberRoots(resolvedNames!, sourceIndex)", [System.StringComparison]::Ordinal) -or
    -not $sourceLowering.Contains("prepared -> localMemberRoots(resolvedNames!, sourceIndex)", [System.StringComparison]::Ordinal)) {
    throw "ordinary and entry member chains do not share one exact local-root index"
}
if (-not [regex]::IsMatch($lowering, '(?s)false => finalProjectedCandidateBelongs!.*?finalProjectedCandidate\.astNode == finalProjectedFlowAstIndex.*?finalProjectedCandidateAst\.parent == finalProjectedFlowAstIndex.*?finalProjectedCandidateOwner\.kind == 10.*?finalProjectedCandidateOwner\.parent == finalProjectedFlowAstIndex.*?finalProjectedCandidateOwner\.start == finalProjectedCandidateAst\.start.*?finalProjectedCandidateOwner\.length == finalProjectedCandidateAst\.length') -or
    -not $lowering.Contains("and finalProjectedCandidateBelongs!", [System.StringComparison]::Ordinal)) {
    throw "nested imported Result subjects no longer require an exact direct or same-span transparent flow owner"
}
if (-not $sourceLowering.Contains("entryResolvedSymbolByAst", [System.StringComparison]::Ordinal) -or
    -not $sourceLowering.Contains("knownEntryLocalBindingReference!", [System.StringComparison]::Ordinal) -or
    -not $sourceLowering.Contains("entryBindingRead.typeId => recursiveEntryExpressionTypeId!", [System.StringComparison]::Ordinal)) {
    throw "entry call arguments do not preserve exact local binding identity and canonical type"
}

$finalize = [System.IO.File]::ReadAllText($finalizePath)
if (([regex]::Matches($finalize, "nodes -> sealLateNominalMemberTypes")).Count -ne 3) {
    throw "late nominal-member closure must stay at three bounded checkpoints"
}
$payloadBeforeMember = '(?s)sealNominalEnumPayloadsByArmTags.*?sealLateNominalMemberTypes.*?resolveFinalProjectedMethods'
$aliasBeforeMember = '(?s)sealLateValueAliasTypes\(prepared\).*?sealLateNominalMemberTypes.*?resolveFinalProjectedMethods'
if (-not [regex]::IsMatch($finalize, $payloadBeforeMember) -or
    -not [regex]::IsMatch($finalize, $aliasBeforeMember)) {
    throw "late payload/binding -> member -> projected-method order regressed"
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    'request.head -> methodText => method',
    'request.head.kind',
    'socketError.kind',
    'argumentCount! == 7',
    'node.operand0 >= 0',
    'ir[node.operand0].kind == 13'
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "late enum member-chain fixture no longer proves: $required"
    }
}

$nestedResultFixture = [System.IO.File]::ReadAllText($nestedResultFixturePath)
foreach ($required in @(
    'reader! -> finish -> when',
    'Err(error)',
    'Ok(streamed)',
    'streamed -> intoOutput',
    '"finish=$(finishResolved!),payload=$(payloadTyped!),method=$(outputResolved!)" -> println'
)) {
    if (-not $nestedResultFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "nested imported Result fixture no longer proves: $required"
    }
}

& (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
    -Manifest $manifestPath, $nestedResultManifestPath, $runtimeManifestPath `
    -RepositoryRoot $root
if (-not $?) { throw "late enum member-chain source manifest closure failed" }

Write-Host "[selfhost late enum member chain] PASS pure member prefixes, qualified exclusion, exact nested Result flow ownership, three bounded member checkpoints, and fixture contracts."
