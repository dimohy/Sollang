[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$verifier = Join-Path $RepositoryRoot 'scripts/verify-selfhost-compiler-contracts.ps1'
$tokens = $null
$parseErrors = $null
$tree = [Management.Automation.Language.Parser]::ParseFile($verifier, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Static assertion verifier has syntax errors' }
$names = @('Register-StaticAssertionFailure', 'Assert-Contains', 'Assert-NotContains', 'Assert-Matches', 'Assert-NotMatches', 'Assert-MatchCount')
$functions = @($tree.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $names }, $false))
if ($functions.Count -ne $names.Count) { throw 'Static assertion helper inventory differs' }
. ([scriptblock]::Create(($functions.Extent.Text -join "`n")))
$CollectStaticAssertionFailures = $false
$staticAssertionFailures = [Collections.Generic.List[string]]::new()
$positive = @(
    { Assert-Contains 'alpha beta' 'beta' 'contains' },
    { Assert-NotContains 'alpha' 'beta' 'not contains' },
    { Assert-Matches 'value=42' '^value=\d+$' 'matches' },
    { Assert-NotMatches 'alpha' '\d' 'not matches' },
    { Assert-MatchCount 'aa aa' 'aa' 2 'count' }
)
$negative = @(
    { Assert-Contains 'alpha' 'beta' 'contains' },
    { Assert-NotContains 'alpha beta' 'beta' 'not contains' },
    { Assert-Matches 'alpha' '^value=\d+$' 'matches' },
    { Assert-NotMatches 'value=42' '\d' 'not matches' },
    { Assert-MatchCount 'aa aa' 'aa' 1 'count' }
)
$completed = 0
foreach ($probe in $positive) { & $probe; $completed++ }
foreach ($probe in $negative) {
    $rejected = $false
    try { & $probe } catch { $rejected = $true }
    if (-not $rejected) { throw 'Default assertion path accepted a negative control' }
    $completed++
}
if ($staticAssertionFailures.Count -ne 0) { throw 'Fail-fast mode accumulated failures' }
$CollectStaticAssertionFailures = $true
foreach ($probe in $negative) {
    $before = $staticAssertionFailures.Count
    & $probe
    if ($staticAssertionFailures.Count -ne $before + 1) { throw 'Collection mode lost an assertion failure' }
    $completed++
}
foreach ($probe in $positive) { & $probe }
if ($staticAssertionFailures.Count -ne 5) { throw 'Positive controls changed the failure count' }
$rejected = $false
try { & $verifier -CollectStaticAssertionFailures } catch {
    if ($_.Exception.Message -ne 'STATIC_ASSERTION_COLLECTION_REQUIRES_STATIC_ONLY') { throw }
    $rejected = $true
}
if (-not $rejected) { throw 'Collection mode entered full verification' }
$completed++

function Test-StaticExecutionOrder([Management.Automation.Language.ScriptBlockAst]$Ast) {
    $aggregation = @($Ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.IfStatementAst] -and
        $node.Extent.Text.StartsWith('if ($staticAssertionFailures.Count -gt 0)')
    }, $true))
    if ($aggregation.Count -ne 1) { return $false }
    $boundary = $aggregation[0].Extent.StartOffset
    $commands = @($Ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.CommandAst]
    }, $true))
    $lateAssertions = @($commands | Where-Object {
        $_.GetCommandName() -in $names -and $_.Extent.StartOffset -gt $boundary
    })
    $earlyChildren = @($commands | Where-Object {
        $_.GetCommandName() -eq 'Invoke-CheckedContract' -and $_.Extent.StartOffset -lt $boundary
    })
    $sourceNames = @('verify-socket-vectored-contract.ps1', 'verify-socket-try-clone-contract.ps1',
        'verify-socket-reactor-contract.ps1', 'verify-struct-field-migration.ps1')
    $probeNames = @('verify-focused-slg-format.ps1', 'verify-llvm-no-allocation-audit.ps1',
        'verify-portable-memory-io-contract.ps1')
    $literals = @($Ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.StringConstantExpressionAst]
    }, $true))
    $sourceSlots = @($literals | Where-Object Value -cin $sourceNames | ForEach-Object { $_.Extent.StartOffset })
    $probeSlots = @($literals | Where-Object Value -cin $probeNames | ForEach-Object { $_.Extent.StartOffset })
    $costOrderValid = $sourceSlots.Count -eq $sourceNames.Count -and $probeSlots.Count -eq $probeNames.Count -and
        ($sourceSlots | Measure-Object -Maximum).Maximum -lt ($probeSlots | Measure-Object -Minimum).Minimum
    return $lateAssertions.Count -eq 0 -and $earlyChildren.Count -eq 0 -and $costOrderValid
}
if (-not (Test-StaticExecutionOrder $tree)) { throw 'Source assertions must finish before child contracts and success output' }
$completed++
$source = [IO.File]::ReadAllText($verifier)
$earlyChildSource = $source.Insert($tree.ParamBlock.Extent.EndOffset, "`nInvoke-CheckedContract -Name 'must-not-run.ps1'`n")
$earlyChildTree = [Management.Automation.Language.Parser]::ParseInput($earlyChildSource, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0 -or (Test-StaticExecutionOrder $earlyChildTree)) { throw 'Early child execution was not rejected' }
$completed++
$lateAssertionTree = [Management.Automation.Language.Parser]::ParseInput(
    $source + "`nAssert-Contains 'input' 'missing' 'late assertion'`n", [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0 -or (Test-StaticExecutionOrder $lateAssertionTree)) { throw 'Assertion after the final failure gate was not rejected' }
$completed++
$lateSource = $source.Replace('"verify-socket-reactor-contract.ps1"', '"__source_order_swap__"').
    Replace('"verify-portable-memory-io-contract.ps1"', '"verify-socket-reactor-contract.ps1"').
    Replace('"__source_order_swap__"', '"verify-portable-memory-io-contract.ps1"')
$lateSourceTree = [Management.Automation.Language.Parser]::ParseInput($lateSource, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0 -or (Test-StaticExecutionOrder $lateSourceTree)) { throw 'Source contracts after expensive probes were not rejected' }
$completed++
$layoutDescriptions = @(
    'declared layout refinement logical module',
    'by-value layout dependency graph',
    'cycle rejection precedes numeric layout iteration',
    'declared layout preparation consumer',
    'declared layout refinement source closure'
)
$layoutAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -in @('Assert-Contains', 'Assert-Matches') -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $layoutDescriptions
}, $true))
if ($layoutAssertions.Count -ne 5) { throw 'Declared layout assertion inventory differs' }
$layoutAssertionText = $layoutAssertions.Extent.Text -join "`n"
function Invoke-DeclaredLayoutAssertions([string]$Context, [string]$Layout, [string]$Manifest) {
    $textContext = $Context
    $finalTypeLayouts = $Layout
    $selfhostDriverSources = $Manifest
    & ([scriptblock]::Create($layoutAssertionText))
}
$layoutContext = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/llvm/text/context_prepare.slg'))
$layoutImplementation = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/llvm/final_type_layouts.slg'))
$layoutManifest = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'))
$CollectStaticAssertionFailures = $false
Invoke-DeclaredLayoutAssertions $layoutContext $layoutImplementation $layoutManifest
$completed++
$layoutMutations = @(
    @{ Context = $layoutContext; Layout = $layoutContext; Manifest = $layoutManifest; Expected = 'by-value layout dependency graph' },
    @{ Context = $layoutContext.Replace('semanticTypes! -> refineDeclaredTypeLayouts(', 'semanticTypes! -> disconnectedLayouts('); Layout = $layoutImplementation; Manifest = $layoutManifest; Expected = 'declared layout preparation consumer' },
    @{ Context = $layoutContext; Layout = $layoutImplementation.Replace('typeIds.valueLayoutCycles(', 'typeIds.missingLayoutCycles('); Manifest = $layoutManifest; Expected = 'by-value layout dependency graph' },
    @{ Context = $layoutContext; Layout = $layoutImplementation.Replace('not hasCyclicLayout! => aggregateLayoutChanged!', 'true => aggregateLayoutChanged!'); Manifest = $layoutManifest; Expected = 'cycle rejection precedes numeric layout iteration' },
    @{ Context = $layoutContext; Layout = $layoutImplementation; Manifest = [regex]::Replace($layoutManifest, '(?m)^selfhost/llvm/final_type_layouts\.slg\r?\n?', ''); Expected = 'declared layout refinement source closure' },
    @{ Context = $layoutContext; Layout = $layoutImplementation.Replace('namespace sollang.compiler.llvm.text', 'namespace unrelated.layout'); Manifest = $layoutManifest; Expected = 'declared layout refinement logical module' }
)
foreach ($probe in $layoutMutations) {
    $layoutRejected = $false
    try { Invoke-DeclaredLayoutAssertions $probe.Context $probe.Layout $probe.Manifest } catch {
        if (-not $_.Exception.Message.StartsWith($probe.Expected + ' is missing:')) { throw }
        $layoutRejected = $true
    }
    if (-not $layoutRejected) { throw ('Declared layout mutation was not rejected: ' + $probe.Expected) }
    $completed++
}
$continuationAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -eq 'Assert-Matches' -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -ceq 'ownership joins compare continuing alternatives only'
}, $true))
if ($continuationAssertions.Count -ne 1) { throw 'Continuation assertion inventory differs' }
$continuationAssertion = [scriptblock]::Create($continuationAssertions[0].Extent.Text)
$semanticOwnership = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/semantic/ownership_check.slg'))
$originalOwnership = $semanticOwnership
& $continuationAssertion
$completed++
foreach ($mutation in @(
    $originalOwnership.Replace('not terminatingControls[retainingAlternativeRegion]', 'terminatingControls[retainingAlternativeRegion]'),
    $originalOwnership.Replace('not terminatingControls[retainingAlternativeRegion]', 'true'),
    $originalOwnership.Replace('alternativeRegion -> alternativeBody => retainingAlternativeRegion', 'alternativeRegion => retainingAlternativeRegion')
)) {
    $semanticOwnership = $mutation
    $rejected = $false
    try { & $continuationAssertion } catch {
        if (-not $_.Exception.Message.StartsWith('ownership joins compare continuing alternatives only is missing:')) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Broken continuing alternative guard was not rejected' }
    $completed++
}
$arrayAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -eq 'Assert-Matches' -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -ceq 'semantic composite type creation before Typed IR'
}, $true))
if ($arrayAssertions.Count -ne 1) { throw 'Late array assertion inventory differs' }
$arrayAssertion = [scriptblock]::Create($arrayAssertions[0].Extent.Text)
$lateArrayTypes = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/semantic/late_array_types.slg'))
$originalArrayTypes = $lateArrayTypes
& $arrayAssertion
$completed++
foreach ($mutation in @(
    $originalArrayTypes.Replace('types -> typeIds.allocateSemanticTypeSlot => typeId!', '0 => typeId!'),
    $originalArrayTypes.Replace('} => types[typeId!]', '} => types[0]'),
    $originalArrayTypes.Replace('first: elementType', 'first: -1'),
    $originalArrayTypes.Replace('length: length!', 'length: 0'),
    $originalArrayTypes.Replace('typeId: typeId!', 'typeId: 0')
)) {
    $lateArrayTypes = $mutation
    $rejected = $false
    try { & $arrayAssertion } catch {
        if (-not $_.Exception.Message.StartsWith('semantic composite type creation before Typed IR is missing:')) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Broken late array type publication was not rejected' }
    $completed++
}
$budgetDescriptions = @('native exact fixture measured timeout default', 'native exact fixture timeout routing',
    'native exact batch measured timeout default', 'native exact batch timeout routing',
    'native exact batch forwards shared input identity')
$budgetAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -in @('Assert-Contains','Assert-Matches','Assert-MatchCount') -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $budgetDescriptions
}, $true))
if ($budgetAssertions.Count -ne 5) { throw 'Budget assertion inventory differs' }
$budgetAssertion = [scriptblock]::Create($budgetAssertions.Extent.Text -join "`n")
$originalFixture = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts/verify-native-exact-fixture.ps1'))
$originalBatch = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts/verify-native-exact-fixture-batch.ps1'))
function Invoke-BudgetAssertions([string]$Fixture, [string]$Batch) {
    $nativeExactFixtureVerifier = $Fixture
    $nativeExactFixtureBatchVerifier = $Batch
    & $budgetAssertion
}
Invoke-BudgetAssertions $originalFixture $originalBatch
$completed++
$budgetMutations = @(
    @{Fixture=$originalFixture.Replace('180000','3600000');Batch=$originalBatch;Expected='native exact fixture measured timeout default'},
    @{Fixture=$originalFixture.Replace('-TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)', '-TimeoutMilliseconds $TimeoutMilliseconds');Batch=$originalBatch;Expected='native exact fixture timeout routing'},
    @{Fixture=$originalFixture;Batch=$originalBatch.Replace('180000','3600000');Expected='native exact batch measured timeout default'},
    @{Fixture=$originalFixture;Batch=$originalBatch.Replace('TimeoutMilliseconds=$using:TimeoutMilliseconds','TimeoutMilliseconds=180000');Expected='native exact batch timeout routing'},
    @{Fixture=$originalFixture;Batch=$originalBatch.Replace('Invoke-NativeExactBudgetedFixture -VerifierPath $using:verifierPath -Parameters $caseParameters','& $using:verifierPath @caseParameters');Expected='native exact batch timeout routing'},
    @{Fixture=$originalFixture;Batch=$originalBatch.Replace('CommonInputFingerprint=$using:commonInputFingerprint','CommonInputFingerprint=""');Expected='native exact batch forwards shared input identity'}
)
foreach ($probe in $budgetMutations) {
    $rejected = $false
    try { Invoke-BudgetAssertions $probe.Fixture $probe.Batch } catch {
        if (-not $_.Exception.Message.StartsWith($probe.Expected + ' is missing:') -and
            -not $_.Exception.Message.StartsWith($probe.Expected + ' count differs:')) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw ('Broken budget guard was not rejected: ' + $probe.Expected) }
    $completed++
}
$cleanupDescriptions = @('projected interpolation direct-call count fixture',
    'managed enum inconsistent continuing owners drop only retained-path values before scope merge',
    'canonical local cleanup preserves borrowed and moved-field ownership')
$cleanupAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -eq 'Assert-Matches' -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $cleanupDescriptions
}, $true))
if ($cleanupAssertions.Count -ne 3) { throw 'Cleanup assertion inventory differs' }
$cleanupAssertion = [scriptblock]::Create($cleanupAssertions.Extent.Text -join "`n")
$enumSource = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Enums.cs'))
$utilitySource = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs'))
$countSource = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'examples/regression/expected/1185-selfhost-projected-receiver-instance-call.selfhost.llvm.regex-counts.txt'))
function Invoke-CleanupAssertions([string]$Enum, [string]$Utility, [string]$Counts) {
    $managedEnumEmitter = $Enum
    $managedUtilitiesEmitter = $Utility
    $projectedInterpolationCallCounts = $Counts
    & $cleanupAssertion
}
Invoke-CleanupAssertions $enumSource $utilitySource $countSource
$completed++
$cleanupMutations = @(
    @{Enum=$enumSource.Replace('RestoreLocals(path.Scope);','');Utility=$utilitySource;Counts=$countSource;Expected=$cleanupDescriptions[1]},
    @{Enum=$enumSource.Replace('DropOwnedLocal(name, path.Scope.Locals[name])','DropOwnedRuntimeValue(path.Scope.Locals[name])');Utility=$utilitySource;Counts=$countSource;Expected=$cleanupDescriptions[1]},
    @{Enum=$enumSource.Replace('RemoveLocalsFromScope(path.Scope, normalizedNames)','path.Scope');Utility=$utilitySource;Counts=$countSource;Expected=$cleanupDescriptions[1]},
    @{Enum=$enumSource;Utility=$utilitySource.Replace('_borrowedMutableLocals.Contains(name) || _borrowedOwnedLocals.Contains(name)','false');Counts=$countSource;Expected=$cleanupDescriptions[2]},
    @{Enum=$enumSource;Utility=$utilitySource.Replace('DropOwnedStructFieldsExceptMoved(name, structure)','DropOwnedRuntimeValue(structure)');Counts=$countSource;Expected=$cleanupDescriptions[2]},
    @{Enum=$enumSource;Utility=$utilitySource;Counts=$countSource.Replace("1`t","2`t");Expected=$cleanupDescriptions[0]},
    @{Enum=$enumSource;Utility=$utilitySource;Counts=$countSource.Replace('@sollang_x','@sollang_m');Expected=$cleanupDescriptions[0]}
)
foreach ($probe in $cleanupMutations) {
    $rejected = $false
    try { Invoke-CleanupAssertions $probe.Enum $probe.Utility $probe.Counts } catch {
        if (-not $_.Exception.Message.StartsWith($probe.Expected + ' is missing:')) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw ('Broken cleanup guard was not rejected: ' + $probe.Expected) }
    $completed++
}
@{ status = 'passed'; completed = $completed; total = 52; defaultFailuresRejected = 5; collectedFailures = 5; fullModeRejected = $true; executionOrderControls = 4; declaredLayoutControls = 7; continuationControls = 4; lateArrayControls = 6; budgetControls = 7; cleanupControls = 8 } | ConvertTo-Json
