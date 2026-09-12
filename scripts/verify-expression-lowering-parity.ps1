[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\expression-lowering-parity.json"
$schemaPath = Join-Path $root "scripts\contracts\expression-lowering-parity.schema.json"
$nodesPath = Join-Path $root "src\Sollang.Compiler\Syntax\Nodes.cs"
$managedSemanticPath = Join-Path $root "src\Sollang.Compiler\Semantics\SemanticCompiler.cs"
$managedEmitterPath = Join-Path $root "src\Sollang.Compiler\CodeGen\LlvmEmitter.Expressions.Core.cs"
$astPath = Join-Path $root "selfhost\syntax\ast.slg"
$typedPath = Join-Path $root "selfhost\ir\typed.slg"
$constantLoweringPath = Join-Path $root "selfhost\semantic\constant_collection_lowering.slg"
$ordinaryPath = Join-Path $root "selfhost\ir\typed\ordinary_function_expressions.slg"
$entryPath = Join-Path $root "selfhost\ir\typed\source_lowering.slg"
$invariantsPath = Join-Path $root "selfhost\llvm\text\invariants.slg"
$diagnosticsPath = Join-Path $root "selfhost\llvm\text\invariant_diagnostics.slg"
$semanticCallsPath = Join-Path $root "selfhost\semantic\calls.slg"
$semanticEffectsPath = Join-Path $root "selfhost\semantic\effects.slg"
$branchEmitterPath = Join-Path $root "selfhost\llvm\text\control_region_expressions.slg"
$controlRegionsPath = Join-Path $root "selfhost\llvm\text\control_regions.slg"
$coreCallsPath = Join-Path $root "selfhost\llvm\text\core_calls.slg"
$entryExpressionsPath = Join-Path $root "selfhost\llvm\text\entry_expressions.slg"

foreach ($path in @($contractPath, $schemaPath, $nodesPath, $managedSemanticPath, $managedEmitterPath, $astPath, $typedPath, $constantLoweringPath, $ordinaryPath, $entryPath, $invariantsPath, $diagnosticsPath, $semanticCallsPath, $semanticEffectsPath, $branchEmitterPath, $controlRegionsPath, $coreCallsPath, $entryExpressionsPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Expression lowering parity input is missing: $path"
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "Expression lowering parity contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
$nodes = [IO.File]::ReadAllText($nodesPath)
$managedSemantic = [IO.File]::ReadAllText($managedSemanticPath)
$managedEmitter = [IO.File]::ReadAllText($managedEmitterPath)
$ast = [IO.File]::ReadAllText($astPath)
$typed = [IO.File]::ReadAllText($typedPath)
$constantLowering = [IO.File]::ReadAllText($constantLoweringPath)
$ordinary = [IO.File]::ReadAllText($ordinaryPath)
$entry = [IO.File]::ReadAllText($entryPath)
$invariants = [IO.File]::ReadAllText($invariantsPath)
$diagnostics = [IO.File]::ReadAllText($diagnosticsPath)
$semanticCalls = [IO.File]::ReadAllText($semanticCallsPath)
$semanticEffects = [IO.File]::ReadAllText($semanticEffectsPath)
$branchEmitter = [IO.File]::ReadAllText($branchEmitterPath)
$controlRegions = [IO.File]::ReadAllText($controlRegionsPath)
$coreCalls = [IO.File]::ReadAllText($coreCallsPath)
$entryExpressions = [IO.File]::ReadAllText($entryExpressionsPath)
if ($ast -notmatch 'typeSyntaxAngleToken!' -or
    $ast -notmatch 'typeAnnotationNode\.ruleId == grammar\.ruleIdTypeAnnotation\(\)' -or
    $ast -notmatch 'typeApplicationNode\.ruleId == grammar\.ruleIdTypeApplicationExpression\(\)' -or
    $ast -notmatch 'typeAngleDepth!' -or
    $ast -notmatch 'foundTypeAngles!' -or
    $ast -notmatch 'typeAngleDepth! == 0 -> if \{ typeTokenEnd => typeTokenIndex! \}' -or
    $ast -notmatch 'typeSyntaxAngleToken!\[operatorTokenIndex!\] == 0' -or
    $ast -notmatch '(?s)operatorPayloadToken! < 0 -> if \{.*?astKind! >= 18.*?astKind! <= 22.*?-1 => astKind!') {
    throw 'Self-host comparison lowering must exclude only the balanced type-argument angles and preserve comparison operators in call arguments'
}
if ($contract.operatorTokenOwnership.typeSyntaxAngles -cne 'type-annotation-plus-balanced-application-clause' -or
    -not $contract.operatorTokenOwnership.callArgumentsExcluded -or
    $contract.operatorTokenOwnership.operatorlessEnvelope -cne 'omit' -or
    $contract.operatorTokenOwnership.nestedComparisonControl -cne 'Result<Bool, Text>.Ok(3 > 2)') {
    throw 'Expression parity contract no longer fixes the managed/self-host operator-token ownership boundary'
}
$aggregateEmitter = [string]$contract.branchMaterialization.sharedAggregateEmitter
$armEmitter = [string]$contract.branchMaterialization.sharedArmEmitter
$parallelEmitter = [string]$contract.branchMaterialization.sharedParallelEmitter
if ([regex]::Matches($branchEmitter, "(?m)^$([regex]::Escape($aggregateEmitter))\s").Count -ne 1 -or
    [regex]::Matches($branchEmitter, "(?m)^$([regex]::Escape($armEmitter))\s").Count -ne 1 -or
    [regex]::Matches($branchEmitter, "(?m)^$([regex]::Escape($parallelEmitter))\s").Count -ne 1) {
    throw 'Branch materialization must have exactly one shared sequential aggregate, arm, and parallel emitter authority'
}
foreach ($relativeConsumer in $contract.branchMaterialization.consumers) {
    $consumerPath = Join-Path $root ([string]$relativeConsumer)
    if (-not (Test-Path -LiteralPath $consumerPath -PathType Leaf)) {
        throw "Sequential branch materialization consumer is missing: $relativeConsumer"
    }
    $consumer = [IO.File]::ReadAllText($consumerPath)
    if ($consumer -notmatch "(?s)kind == $($contract.branchMaterialization.sequentialBranchTypedIrKind).*?$([regex]::Escape($aggregateEmitter))" -or
        $consumer -notmatch "(?s)kind == $($contract.branchMaterialization.armTypedIrKind).*?$([regex]::Escape($armEmitter))" -or
        $consumer -notmatch "(?s)kind == $($contract.branchMaterialization.parallelBranchTypedIrKind).*?$([regex]::Escape($parallelEmitter))") {
        throw "Branch materialization consumer bypasses a shared emitter: $relativeConsumer"
    }
}
if ([string]$contract.branchMaterialization.controlRegionFixture -notin @($contract.focusedFixtures) -or
    [string]$contract.branchMaterialization.controlRegionFixture -notin @($contract.representativeFixtures)) {
    throw 'The nested control-region sequential branch fixture must remain in both focused and representative verification sets'
}
if ([string]$contract.branchMaterialization.nestedParallelControlFixture -notin @($contract.focusedFixtures) -or
    [string]$contract.branchMaterialization.nestedParallelControlFixture -notin @($contract.representativeFixtures)) {
    throw 'The nested control-region parallel branch fixture must remain in both focused and representative verification sets'
}
$rangeEmitter = [string]$contract.contextMaterialization.sharedRangeEmitter
if ([regex]::Matches($branchEmitter, "(?m)^$([regex]::Escape($rangeEmitter))\s").Count -ne 1) {
    throw 'Range materialization must have exactly one shared emitter authority'
}
foreach ($relativeConsumer in $contract.contextMaterialization.rangeConsumers) {
    $consumerPath = Join-Path $root ([string]$relativeConsumer)
    if (-not (Test-Path -LiteralPath $consumerPath -PathType Leaf)) {
        throw "Range materialization consumer is missing: $relativeConsumer"
    }
    $consumer = [IO.File]::ReadAllText($consumerPath)
    if ($consumer -notmatch "(?s)kind == $($contract.contextMaterialization.rangeTypedIrKind).*?$([regex]::Escape($rangeEmitter))") {
        throw "Range materialization consumer bypasses the shared emitter: $relativeConsumer"
    }
}
if ([string]$contract.contextMaterialization.nestedControlFixture -notin @($contract.focusedFixtures) -or
    [string]$contract.contextMaterialization.nestedControlFixture -notin @($contract.representativeFixtures)) {
    throw 'The nested control-region range fixture must remain in both focused and representative verification sets'
}
$streamBodyEmitter = [string]$contract.nestedStreamScheduling.sharedBodyEmitter
$regionStreamDelegator = [string]$contract.nestedStreamScheduling.regionDelegator
$streamOwnershipClassifier = [string]$contract.nestedStreamScheduling.ownershipClassifier
$mutableSlotPolicyField = [string]$contract.nestedStreamScheduling.mutableSlotPolicyField
if ([regex]::Matches($entryExpressions, "(?m)^$([regex]::Escape($streamBodyEmitter))\s").Count -ne 1 -or
    $entryExpressions -notmatch "plan\.$([regex]::Escape($mutableSlotPolicyField))\s*-> if") {
    throw 'Stream scheduling must have one shared body emitter with explicit mutable-slot policy'
}
if ([regex]::Matches($controlRegions, "(?m)^$([regex]::Escape($regionStreamDelegator))\s").Count -ne 1 -or
    $controlRegions -notmatch "(?s)$([regex]::Escape($regionStreamDelegator)).*?$([regex]::Escape($streamBodyEmitter))" -or
    $controlRegions -notmatch "$([regex]::Escape($mutableSlotPolicyField)):\s*false") {
    throw 'Nested control-region streams must delegate to the shared body emitter without reallocating function slots'
}
if ([regex]::Matches($coreCalls, "(?m)^$([regex]::Escape($streamOwnershipClassifier))\s").Count -ne 1 -or
    $coreCalls -notmatch '(?s)regionOwnedStreamPipeline.*?\.callIr == nodeIndex') {
    throw 'Nested stream ownership must suppress already-fused stage calls from outer region emission'
}
if ([string]$contract.nestedStreamScheduling.controlRegionFixture -notin @($contract.focusedFixtures) -or
    [string]$contract.nestedStreamScheduling.controlRegionFixture -notin @($contract.representativeFixtures)) {
    throw 'The nested control-region stream fixture must remain in both focused and representative verification sets'
}
$managedExpressionDeclarationPattern = '(?ms)^internal sealed record\s+(?<name>\w+Expression)\b(?:(?!^internal ).)*?:\s*Expression\([^;]*;'
$inventoryBoundaryControl = @'
internal sealed record FirstExpression(int Line, int Column) : Expression(Line, Column);
internal sealed record HelperExpression(int Value);
internal sealed record ProductExpression(
    int Line,
    int Column)
    : Expression(Line, Column);
'@
$inventoryBoundaryNames = @([regex]::Matches($inventoryBoundaryControl, $managedExpressionDeclarationPattern) |
    ForEach-Object { $_.Groups['name'].Value })
if ($inventoryBoundaryNames.Count -ne 2 -or
    $inventoryBoundaryNames[0] -cne 'FirstExpression' -or
    $inventoryBoundaryNames[1] -cne 'ProductExpression') {
    throw 'Managed expression inventory extraction crossed a declaration boundary'
}
$managedExpressionTypes = @([regex]::Matches(
    $nodes,
    $managedExpressionDeclarationPattern) |
    ForEach-Object { $_.Groups['name'].Value } |
    Sort-Object -Unique)
if ($managedExpressionTypes.Count -ne $contract.managedExpressionInventoryTotal) {
    throw "Managed expression inventory drifted: expected $($contract.managedExpressionInventoryTotal), actual $($managedExpressionTypes.Count)"
}
if ([int]$contract.endToEndImplementedTotal + @($contract.endToEndPending).Count -ne $managedExpressionTypes.Count) {
    throw 'Implemented and pending end-to-end expression totals must exactly partition the managed inventory'
}
$mappedManagedExpressions = @($contract.mappings.managedExpression | Sort-Object -Unique)
if ($mappedManagedExpressions.Count -ne $contract.mappings.Count) {
    throw 'Expression lowering parity mappings contain duplicate managed expression types'
}
$mappingDifference = @(Compare-Object -ReferenceObject $managedExpressionTypes -DifferenceObject $mappedManagedExpressions)
if ($mappingDifference.Count -ne 0) {
    throw "Expression lowering parity mappings differ from the managed declaration inventory: $($mappingDifference | ConvertTo-Json -Compress)"
}
$pendingEndToEnd = @($contract.endToEndPending | Sort-Object -Unique)
if ([int]$contract.endToEndImplementedTotal + $pendingEndToEnd.Count -ne $contract.managedExpressionInventoryTotal) {
    throw 'Expression lowering end-to-end totals do not cover the managed declaration inventory'
}
foreach ($expression in $pendingEndToEnd) {
    $pendingMapping = @($contract.mappings | Where-Object managedExpression -eq $expression)
    if ($pendingMapping.Count -ne 1 -or [string]$pendingMapping[0].policyStatus -ne 'shape-only') {
        throw "Pending end-to-end expression must be marked shape-only: $expression"
    }
}
foreach ($mapping in $contract.mappings) {
    $expression = [string]$mapping.managedExpression
    if ($managedSemantic -notmatch "\b$([regex]::Escape($expression))\b") {
        throw "Managed semantic implementation is missing: $expression"
    }
    foreach ($kind in $mapping.selfhostAstKinds) {
        if ($ast -notmatch "\b$kind\s*=>\s*(?:astKind|kind)!") {
            throw "Self-host AST kind $kind for $expression is absent from the AST authority"
        }
    }
    $policy = [string]$mapping.policy
    if ([string]$mapping.policyStatus -eq 'shared') {
        if ($policy -eq 'constant_collection_lowering') {
            if ($constantLowering -notmatch 'node\.kind == 83') {
                throw 'Compile-time each is not consumed by constant collection lowering'
            }
        } elseif ($typed -notmatch "public $([regex]::Escape($policy))\b") {
            throw "Shared self-host expression policy is missing: $policy"
        }
    }
}
$sharedTypedPolicies = @($contract.mappings |
    Where-Object { $_.policyStatus -eq 'shared' -and $_.policy -ne 'constant_collection_lowering' } |
    ForEach-Object { [string]$_.policy } |
    Sort-Object -Unique)
foreach ($policy in $sharedTypedPolicies) {
    $definitionPattern = "(?m)^public\s+$([regex]::Escape($policy))\b"
    $definitionCount = [regex]::Matches($typed, $definitionPattern).Count
    if ($definitionCount -ne 1) {
        throw "Shared self-host expression policy must have exactly one authority: $policy (actual $definitionCount)"
    }
}
$policyFamilyExpressions = @($contract.families.managedExpressions | ForEach-Object { $_ } | Sort-Object -Unique)
foreach ($expression in $policyFamilyExpressions) {
    if ($expression -notin $managedExpressionTypes) {
        throw "Parity policy family names an unknown managed expression: $expression"
    }
}

$fixtureCoveredExpressions = @($contract.fixtureCoverage.managedExpression | Sort-Object -Unique)
if ($fixtureCoveredExpressions.Count -ne $contract.fixtureCoverage.Count) {
    throw 'Expression fixture coverage contains duplicate managed expression rows'
}
$fixtureCoverageDifference = @(Compare-Object -ReferenceObject $managedExpressionTypes -DifferenceObject $fixtureCoveredExpressions)
if ($fixtureCoverageDifference.Count -ne 0) {
    throw "Expression fixture coverage differs from the managed declaration inventory: $($fixtureCoverageDifference | ConvertTo-Json -Compress)"
}
foreach ($coverage in $contract.fixtureCoverage) {
    $expression = [string]$coverage.managedExpression
    $fixture = [string]$coverage.fixture
    if ($fixture -notin @($contract.representativeFixtures)) {
        throw "Expression fixture coverage is outside the representative batch: $expression -> $fixture"
    }
    $fixturePath = Join-Path $root "examples/regression/$fixture.slg"
    $expectedPath = Join-Path $root "examples/regression/expected/$fixture.stdout.txt"
    foreach ($path in @($fixturePath, $expectedPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Expression fixture coverage input is missing: $path"
        }
    }
    $fixtureSource = [IO.File]::ReadAllText($fixturePath)
    foreach ($fragment in $coverage.sourceFragments) {
        if (-not $fixtureSource.Contains([string]$fragment, [StringComparison]::Ordinal)) {
            throw "Expression fixture source evidence is absent: $expression -> $fixture -> $fragment"
        }
    }
    $expectedLines = @([IO.File]::ReadAllLines($expectedPath))
    foreach ($fragment in $coverage.expectedOutputFragments) {
        if ([string]$fragment -cnotin $expectedLines) {
            throw "Expression fixture expected-output evidence is absent: $expression -> $fixture -> $fragment"
        }
    }
}
if ($contract.status -eq 'complete' -and $fixtureCoveredExpressions.Count -ne $managedExpressionTypes.Count) {
    throw "A complete expression lowering parity contract must cover every managed expression type"
}

foreach ($family in $contract.families) {
    foreach ($expression in $family.managedExpressions) {
        if ($nodes -notmatch "sealed record $([regex]::Escape($expression))\b") {
            throw "Managed syntax type is not declared: $expression"
        }
        if ($managedSemantic -notmatch "\b$([regex]::Escape($expression))\b") {
            throw "Managed semantic dispatch is missing: $expression"
        }
        if ($managedEmitter -notmatch "\b$([regex]::Escape($expression))\b") {
            throw "Managed LLVM dispatch is missing: $expression"
        }
    }
    $policy = [string]$family.selfhostPolicy
    if ($typed -notmatch "public $([regex]::Escape($policy)) kind: Int -> Bool") {
        if ($typed -notmatch "public $([regex]::Escape($policy))\b") {
            throw "Self-host shared materialization policy is missing: $policy"
        }
    }
    $familyKinds = @($family.managedExpressions |
        ForEach-Object {
            $name = $_
            $contract.mappings |
                Where-Object managedExpression -eq $name |
                ForEach-Object { $_.selfhostAstKinds }
        } |
        ForEach-Object { $_ } |
        Sort-Object -Unique)
    foreach ($kind in $family.selfhostAstKinds) {
        if ($kind -notin $familyKinds) {
            throw "Self-host AST kind $kind is not mapped by family $($family.id)"
        }
    }
}

foreach ($source in @($ordinary, $entry)) {
    if ($source -notmatch 'kind -> isNumericBinaryAstKind') {
        throw "Entry and ordinary lowering must consume the shared numeric binary policy"
    }
    if ($source -notmatch 'resolvedExpressionIrKindForAstKind\(' -or
        $source -notmatch 'kind -> controlIrKindForAstKind') {
        throw 'Entry and ordinary lowering must consume the shared contextual and control shape policies'
    }
    if ($source -match 'kind == 13 -> if \{ 2 => \w*ExpressionKind!') {
        throw 'Entry and ordinary lowering still duplicate the static AST-to-Typed-IR mapping'
    }
    if ($source -notmatch 'mapExpressionOpcode! -> mapExpressionTypeSymbolForOpcode' -and
        $source -notmatch 'entryMapExpressionOpcode! -> mapExpressionTypeSymbolForOpcode') {
        throw 'Entry and ordinary lowering must consume the shared mapped-byte result type policy'
    }
    if ($source -match 'MapExpressionOpcode! == -306 -> if') {
        throw 'Entry and ordinary lowering still duplicate mapped-byte result type selection'
    }
}
if ($typed -notmatch 'kind -> defaultExpressionIrKindForAstKind => irKind!') {
    throw 'The shared contextual expression policy must refine the shared base shape policy'
}
if ($typed -notmatch '(?s)public mapExpressionTypeSymbolForOpcode opcode: Int -> Int => opcode -> when \{\s*== -306 \{ 17 \}\s*== -307 \{ 18 \}\s*else \{ -1 \}\s*\}') {
    throw 'The shared mapped-byte result type policy is missing or has drifted'
}
if ($invariants -notmatch 'typedIr\.isBinaryValueAstKind' -or $diagnostics -notmatch 'compiler error S059') {
    throw "The pre-LLVM AST-to-Typed-IR coverage invariant is not connected"
}
if ($invariants -notmatch '(?m)^invalidMapBindingIr\b' -or
    $invariants -notmatch '\.kind == 49' -or
    $invariants -notmatch 'producer\.kind == 9' -or
    $invariants -notmatch 'producer\.opcode == expectedOpcode' -or
    $invariants -notmatch 'irNodeHasBuiltinType\(expectedSymbol' -or
    $invariants -notmatch 'producer\.flags >= 0 and producer\.flags <= 7' -or
    $invariants -notmatch 'pathOperand -> irNodeHasBuiltinType\(1, context\)' -or
    $invariants -notmatch 'optionOperand -> irNodeHasBuiltinType\(expectedOptionSymbol!, context\)' -or
    $invariants -notmatch 'expectedOpcode == -306 and hasFileSize' -or
    $invariants -notmatch 'binding\.operand0 != producerIndex' -or
    $invariants -notmatch '(?s)missingBinaryBindingIr.*invalidMapBindingIr' -or
    $diagnostics -notmatch 'compiler error S060') {
    throw 'The pre-LLVM map AST-to-Typed-IR producer and exact binding invariant is not connected'
}
$mapMapping = @($contract.mappings | Where-Object managedExpression -eq $contract.mapLowering.managedExpression)
if ($mapMapping.Count -ne 1 -or
    [int]$contract.mapLowering.astKind -notin @($mapMapping[0].selfhostAstKinds) -or
    [int]$contract.mapLowering.typedIrKind -notin @($mapMapping[0].typedIrKinds) -or
    [string]$mapMapping[0].policyStatus -ne 'shared' -or
    [string]$contract.mapLowering.managedExpression -in $pendingEndToEnd) {
    throw 'MapExpression semantic, Typed IR, and LLVM lowering must remain end-to-end under shared policies'
}
foreach ($fixture in $contract.mapLowering.focusedFixtures) {
    if ([string]$fixture -notin @($contract.focusedFixtures)) {
        throw "Map lowering focused control is not in the focused fixture set: $fixture"
    }
}
foreach ($control in $contract.mapBindingControls) {
    $expectedOpcode = if ([string]$control.mode -ceq 'read') {
        [int]$contract.mapLowering.readOpcode
    } else {
        [int]$contract.mapLowering.writeOpcode
    }
    $expectedSymbol = if ([string]$control.mode -ceq 'read') {
        [int]$contract.mapLowering.readBuiltinSymbol
    } else {
        [int]$contract.mapLowering.writeBuiltinSymbol
    }
    $flags = [int]$control.flags
    $hasOffset = ($flags -band [int]$contract.mapLowering.offsetFlag) -ne 0
    $hasLength = ($flags -band [int]$contract.mapLowering.lengthFlag) -ne 0
    $hasFileSize = ($flags -band [int]$contract.mapLowering.fileSizeFlag) -ne 0
    $expectedOptions = @()
    if ($hasOffset) { $expectedOptions += 11 }
    if ($hasLength) { $expectedOptions += 13 }
    if ($hasFileSize) { $expectedOptions += 11 }
    $actualOptions = @($control.optionBuiltinSymbols | ForEach-Object { [int]$_ })
    $optionDifference = @(Compare-Object -ReferenceObject $expectedOptions -DifferenceObject $actualOptions -SyncWindow 0)
    $actualInvalid = [int]$control.producerCount -ne 1 -or
        [int]$control.producerKind -ne [int]$contract.mapLowering.typedIrKind -or
        [int]$control.producerOpcode -ne $expectedOpcode -or
        [int]$control.producerBuiltinSymbol -ne $expectedSymbol -or
        [int]$control.pathBuiltinSymbol -ne [int]$contract.mapLowering.pathBuiltinSymbol -or
        $hasOffset -ne $hasLength -or
        ([string]$control.mode -ceq 'read' -and $hasFileSize) -or
        $optionDifference.Count -ne 0 -or
        -not [bool]$control.bindingMatchesProducer
    if ($actualInvalid -ne [bool]$control.expectedInvalid) {
        throw "Map binding invariant control failed: $($control.id)"
    }
}
if ($invariants -notmatch '(?m)^invalidMappedFlushIr\b' -or
    $invariants -notmatch 'candidate\.symbol == -114' -or
    $invariants -notmatch 'receiver -> irNodeHasBuiltinType\(18, context\)' -or
    $diagnostics -notmatch 'compiler error S061') {
    throw 'Mapped flush must retain runtime alias -114 and an exact MutableMappedBytes receiver before LLVM emission'
}
if ($semanticCalls -notmatch '(?s)localSymbolIndex!.*?localFunctionSymbol!.*?runtimeFunctionSymbol' -or
    $semanticCalls -notmatch '(?s)expected: "flush".*?-114' -or
    $semanticEffects -notmatch 'call\.functionSymbol == -114') {
    throw 'Mapped flush authority drifted: lexical functions must win before runtime alias -114, which retains File effect semantics'
}
if ($invariants -notmatch 'binaryOwnerByAst!' -or
    $invariants -notmatch 'binaryChildByParentAst!\[sourceRange\.astStart \+ binaryOwnerAst!\]') {
    throw "The pre-LLVM binary coverage invariant must select the canonical descendant through transparent binary wrappers"
}
$binaryKinds = @(18, 19, 20, 21, 24, 25, 70)
foreach ($control in $contract.binaryWrapperControls) {
    $canonicalByOwner = @{}
    $ownerByAst = @(-1) * $control.nodes.Count
    for ($astIndex = 0; $astIndex -lt $control.nodes.Count; $astIndex++) {
        $node = $control.nodes[$astIndex]
        if ([int]$node.kind -notin $binaryKinds -or [int]$node.parent -lt 0) {
            continue
        }
        $ownerAst = [int]$node.parent
        if ($ownerAst -ge 0 -and $ownerAst -lt $control.nodes.Count -and
            [int]$control.nodes[$ownerAst].kind -in $binaryKinds -and
            [int]$control.nodes[$ownerAst].start -eq [int]$node.start -and
            [int]$control.nodes[$ownerAst].length -eq [int]$node.length -and
            $ownerByAst[$ownerAst] -ge 0) {
            $ownerAst = $ownerByAst[$ownerAst]
        }
        if ($ownerAst -ge 0 -and $ownerAst -lt $control.nodes.Count) {
            $ownerByAst[$astIndex] = $ownerAst
            $canonicalByOwner[$ownerAst] = $astIndex
        }
    }
    $canonicalAst = if ($canonicalByOwner.ContainsKey([int]$control.ownerAst)) {
        [int]$canonicalByOwner[[int]$control.ownerAst]
    } else { -1 }
    $actualMissing = $canonicalAst -ge 0 -and $canonicalAst -notin @($control.irAsts)
    if ($actualMissing -ne [bool]$control.expectedMissing) {
        throw "Binary wrapper control failed: $($control.id)"
    }
}
foreach ($fixture in @($contract.focusedFixtures) + @($contract.representativeFixtures)) {
    foreach ($relative in @("examples/regression/$fixture.slg", "examples/regression/expected/$fixture.stdout.txt")) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
            throw "Expression lowering parity fixture is missing: $relative"
        }
    }
}

$coveragePercent = [math]::Round(100 * $fixtureCoveredExpressions.Count / $managedExpressionTypes.Count, 1)
$sharedPolicyCount = @($contract.mappings | Where-Object policyStatus -eq 'shared').Count
$sharedPolicyPercent = [math]::Round(100 * $sharedPolicyCount / $managedExpressionTypes.Count, 1)
$endToEndPercent = [math]::Round(100 * [int]$contract.endToEndImplementedTotal / $managedExpressionTypes.Count, 1)
Write-Host "[expression lowering parity] PASS declaration mapping inventory $($mappedManagedExpressions.Count)/$($managedExpressionTypes.Count) (100%), end-to-end $($contract.endToEndImplementedTotal)/$($managedExpressionTypes.Count) ($endToEndPercent%), shared policy $sharedPolicyCount/$($managedExpressionTypes.Count) ($sharedPolicyPercent%), and source-linked representative fixture coverage $($fixtureCoveredExpressions.Count)/$($managedExpressionTypes.Count) ($coveragePercent%); S059/S060/S061 pre-LLVM coverage connected."
