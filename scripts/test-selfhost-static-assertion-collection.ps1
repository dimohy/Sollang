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
$ssaCases = @(Get-Content -LiteralPath (Join-Path $RepositoryRoot 'scripts/contracts/selfhost-ssa-contract-guards.json') -Raw | ConvertFrom-Json)
if ($ssaCases.Count -ne 20 -or @($ssaCases.description | Select-Object -Unique).Count -ne 20) { throw 'SSA guard case inventory differs' }
function Read-SsaModules([string[]]$Names) {
    ($Names | ForEach-Object { [IO.File]::ReadAllText((Join-Path $RepositoryRoot ('selfhost/llvm/text/' + $_ + '.slg'))) }) -join "`n"
}
$ssaSources = @{
    platformIo = Read-SsaModules @('platform_io')
    ownership = Read-SsaModules @('ownership')
    foundation = Read-SsaModules @('foundation')
    coreCalls = Read-SsaModules @('core_calls','call_arguments','aggregate_values')
    functions = Read-SsaModules @('functions','function_expressions','function_calls','function_returns')
    control = Read-SsaModules @('control','control_regions','control_region_expressions')
    containers = Read-SsaModules @('containers','container_control')
}
function Invoke-SsaAssertion([scriptblock]$Assertion, [hashtable]$Sources) {
    foreach ($name in $Sources.Keys) { Set-Variable -Name $name -Value $Sources[$name] -Scope Local }
    & $Assertion
}
$ssaCommands = @{}
foreach ($probe in $ssaCases) {
    $matches = @($tree.FindAll({ param($node)
        $node -is [Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -in @('Assert-Contains','Assert-NotContains','Assert-Matches') -and
        $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
        $node.CommandElements[-1].Value -ceq $probe.description
    }, $true))
    if ($matches.Count -ne 1) { throw ('SSA assertion inventory differs: ' + $probe.description) }
    $ssaCommands[$probe.description] = $matches[0]
    Invoke-SsaAssertion ([scriptblock]::Create($matches[0].Extent.Text)) $ssaSources
}
$completed++
foreach ($probe in $ssaCases) {
    $command = $ssaCommands[$probe.description]
    $mutated = $ssaSources.Clone()
    $original = $mutated[$probe.source]
    if ($probe.mutation -ceq 'branch-allocation') {
        $mutated[$probe.source] += "`n" + $command.CommandElements[2].Value
    } elseif ($probe.mutation -ceq 'projection-step') {
        $mutated[$probe.source] = $original.Replace('_step$(indexedBaseProjectionDepth!)', '')
    } else {
        $mutated[$probe.source] = $original.Replace('$(' + $probe.mutation + ' -> valueNameId(state))', '$(' + $probe.mutation + ')')
    }
    if ($mutated[$probe.source] -ceq $original) { throw ('SSA mutation did not change its source: ' + $probe.description) }
    $rejected = $false
    try { Invoke-SsaAssertion ([scriptblock]::Create($command.Extent.Text)) $mutated } catch {
        if (-not $_.Exception.Message.StartsWith($probe.description + ' is missing:') -and
            -not $_.Exception.Message.StartsWith($probe.description + ' retained forbidden text:')) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw ('Broken SSA source contract was not rejected: ' + $probe.description) }
    $completed++
}
$handleDescriptions = @('selfhost Windows child-only stdout handle selection',
    'managed Windows child-only stdin handle selection', 'managed Windows child-only stdout handle selection',
    'managed Windows child-only stderr handle selection', 'process runtime imports canonical handle provider',
    'selfhost process consumes shared handle selection', 'selfhost handle provider exports actual method',
    'managed process consumes shared handle selection', 'managed handle provider exports actual method')
$handleAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Assert-Contains' -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $handleDescriptions
}, $true))
if ($handleAssertions.Count -ne 9) { throw 'Shared handle assertion inventory differs' }
$handleSources = @{
    processRuntime = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/llvm/emitter/process_runtime.slg'))
    sharedLlvmRuntime = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/llvm/runtime.slg'))
    nativeRuntimePolicy = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'src/Sollang.Compiler/Shared/Policies/NativeRuntimePolicy.cs'))
    managedWindowsProcessRuntime = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'))
}
foreach ($assertion in $handleAssertions) {
    Invoke-SsaAssertion ([scriptblock]::Create($assertion.Extent.Text)) $handleSources
}
$completed++
foreach ($assertion in $handleAssertions) {
    $mutated = $handleSources.Clone()
    $name = $assertion.CommandElements[1].VariablePath.UserPath
    $needle = $assertion.CommandElements[2].Value
    $original = $mutated[$name]
    $mutated[$name] = $original.Replace($needle, '__disconnected_handle_contract__')
    if ($mutated[$name] -ceq $original) { throw 'Handle mutation did not change the source' }
    $rejected = $false
    try { Invoke-SsaAssertion ([scriptblock]::Create($assertion.Extent.Text)) $mutated } catch {
        if (-not $_.Exception.Message.StartsWith($assertion.CommandElements[-1].Value + ' is missing:')) { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Disconnected handle body or consumer was not rejected' }
    $completed++
}
$parallelDescriptions = @('shared parallel additional values skip the synthesized item before reference arguments',
    'parallel callback environments use shared additional values and exact body-call ownership',
    'function parallel fallback delegates additional reference and promoted values',
    'sequential tryParallel prepares arguments before its loop',
    'sequential tryParallel prepares additional arguments once',
    'sequential parallel prepares additional arguments once',
    'control parallel fallback prepares shared values before its loop',
    'entry parallel fallback prepares shared values before its loop',
    'direct parallel specialization admits only external named arguments')
$parallelAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -in @('Assert-Matches','Assert-MatchCount') -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $parallelDescriptions
}, $true))
if ($parallelAssertions.Count -ne 9) { throw 'Parallel argument assertion inventory differs' }
$parallelSources = @{ coreCalls=$ssaSources.coreCalls; functions=$ssaSources.functions; platformIo=$ssaSources.platformIo; controlRegions=$ssaSources.control; text=(Read-SsaModules @('entry_expressions')) }
$parallelAssertion = [scriptblock]::Create($parallelAssertions.Extent.Text -join "`n")
Invoke-SsaAssertion $parallelAssertion $parallelSources
$completed++
$functionPreparation='expression.operand1 -> emitParallelAdditionalArgumentValues(functionIndex, context, state)'
$platformPreparation='expression.operand1 -> emitParallelAdditionalArgumentValues(request.ownerIndex, context, state)'
$parallelMutations = @(
    @{Name='coreCalls';Before='argumentIndex! -> emitNamedPlaceRead(ownerIndex, context, state)';After='';Expected=$parallelDescriptions[0]},
    @{Name='coreCalls';Before='argumentStart -> emitCallIntegerArgumentPromotions(bodyCallIndex, ownerIndex, 1';After='argumentStart -> emitCallIntegerArgumentPromotions(bodyCallIndex, ownerIndex, 0';Expected=$parallelDescriptions[0]},
    @{Name='coreCalls';Before='bodyCallIndex -> emitParallelAdditionalArgumentValues(ownerIndex, context, state)';After='';Expected=$parallelDescriptions[1]},
    @{Name='functions';Before=$functionPreparation;After='';Append=$functionPreparation;Expected=$parallelDescriptions[2]},
    @{Name='platformIo';Before=$platformPreparation;After='';Append=$platformPreparation;Expected=$parallelDescriptions[3]},
    @{Name='controlRegions';Before='regionNode.operand1 -> emitParallelAdditionalArgumentValues(ownerIndex, context, state)';After='';Expected=$parallelDescriptions[6]},
    @{Name='text';Before='entryExpression.operand1 -> emitParallelAdditionalArgumentValues(functionIndex, context, state)';After='';Expected=$parallelDescriptions[7]},
    @{Name='coreCalls';Before='argument.kind != 5';After='argument.kind != 6';Expected=$parallelDescriptions[8]}
)
foreach ($probe in $parallelMutations) {
    $mutated = $parallelSources.Clone()
    $original = $mutated[$probe.Name]
    $mutated[$probe.Name] = $original.Replace($probe.Before, $probe.After)
    if ($probe.ContainsKey('Append')) { $mutated[$probe.Name] += "`n" + $probe.Append }
    if ($mutated[$probe.Name] -ceq $original) { throw 'Parallel mutation did not change its source' }
    $rejected = $false
    try { Invoke-SsaAssertion $parallelAssertion $mutated } catch {
        if (-not $_.Exception.Message.StartsWith($probe.Expected + ' is missing:')) { throw }
        $rejected=$true
    }
    if (-not $rejected) { throw ('Broken parallel argument preparation was not rejected: ' + $probe.Expected) }
    $completed++
}
$wasmDescriptions = @('WASM write status preserves length and failure contract',
    'WASM printing uses status adapter for data and newline', 'WASM print failures remain sticky')
$wasmAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Assert-Matches' -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $wasmDescriptions
}, $true))
if ($wasmAssertions.Count -ne 3) { throw 'WASM write assertion inventory differs' }
$wasmAssertion = [scriptblock]::Create($wasmAssertions.Extent.Text -join "`n")
$wasmSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../selfhost/llvm/emitter/text_output_runtime.slg'))
Invoke-SsaAssertion $wasmAssertion @{textOutputRuntime=$wasmSource}
$completed++
$wasmMutations = @(
    @{Before='%too_large = icmp ugt i64 %len64, 2147483647';After='%too_large = icmp ugt i64 %len64, 4294967295';Expected=$wasmDescriptions[0]},
    @{Before='%is_ok = icmp ne i32 %ok, 0';After='%is_ok = icmp eq i32 %ok, %len';Expected=$wasmDescriptions[0]},
    @{Before='store i32 %len, ptr %written, align 4';After='store i32 %ok, ptr %written, align 4';Expected=$wasmDescriptions[0]},
    @{Before='fail:' + "`n" + '      store i32 0, ptr %written, align 4';After='fail:' + "`n" + '      store i32 1, ptr %written, align 4';Expected=$wasmDescriptions[0]},
    @{Before='%data_status = call i32 @sollang_write(ptr %stdout, ptr %data, i64 %len, ptr %written)';After='%data_status = call i32 @sollang_browser_write(ptr %data, i32 1)';Expected=$wasmDescriptions[1]},
    @{Before='%newline_status = call i32 @sollang_write(ptr %stdout, ptr @sollang_runtime_newline, i64 1, ptr %written)';After='%newline_status = call i32 @sollang_browser_write(ptr @sollang_runtime_newline, i32 1)';Expected=$wasmDescriptions[1]},
    @{Before='%next = and i1 %previous, %ok';After='%next = or i1 %previous, %ok';Expected=$wasmDescriptions[2]}
)
foreach ($probe in $wasmMutations) {
    $mutated=$wasmSource.Replace($probe.Before,$probe.After)
    if ($mutated -ceq $wasmSource) { throw 'WASM mutation did not change source' }
    $rejected=$false
    try { Invoke-SsaAssertion $wasmAssertion @{textOutputRuntime=$mutated} } catch {
        if (-not $_.Exception.Message.StartsWith($probe.Expected + ' is missing:')) { throw }
        $rejected=$true
    }
    if (-not $rejected) { throw ('Broken WASM write contract was not rejected: ' + $probe.Expected) }
    $completed++
}
$captureAbiDescriptions = @('parallel callback additional arguments share declared-parameter or exact actual-value ABI type fallback',
    'shared capture ABI preserves borrow pointers and value carriers')
$captureAbiAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Assert-Matches' -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $captureAbiDescriptions
}, $true))
if ($captureAbiAssertions.Count -ne 2) { throw 'Capture ABI assertion inventory differs' }
$captureAbiAssertion = [scriptblock]::Create($captureAbiAssertions.Extent.Text -join "`n")
$captureAbiSources = @{text=(Read-SsaModules @('core_prepare'));coreCalls=(Read-SsaModules @('core_calls'))}
Invoke-SsaAssertion $captureAbiAssertion $captureAbiSources
$completed++
$captureAbiMutations = @(
    @{Name='text';Before='context.ir[parallelCallbackParameterIndex] -> writeMaterializedValueAbiType';After='context.ir[parallelCallbackParameterIndex] -> writeFunctionValueAbiType';Expected=$captureAbiDescriptions[0]},
    @{Name='text';Before='context.ir[parallelCallbackAdditionalIndex!] -> writeMaterializedValueAbiType';After='context.ir[parallelCallbackAdditionalIndex!] -> writeFunctionValueAbiType';Expected=$captureAbiDescriptions[0]},
    @{Name='coreCalls';Before='binding -> writeMaterializedValueAbiType';After='binding -> writeFunctionValueAbiType';Expected=$captureAbiDescriptions[1]},
    @{Name='coreCalls';Before='-> if { "ptr" -> print } else {';After='-> if { "i64" -> print } else {';Expected=$captureAbiDescriptions[1]}
)
foreach ($probe in $captureAbiMutations) {
    $mutated=$captureAbiSources.Clone()
    $mutated[$probe.Name]=$mutated[$probe.Name].Replace($probe.Before,$probe.After)
    if ($mutated[$probe.Name] -ceq $captureAbiSources[$probe.Name]) { throw 'Capture ABI mutation did not change source' }
    $rejected=$false
    try { Invoke-SsaAssertion $captureAbiAssertion $mutated } catch {
        if (-not $_.Exception.Message.StartsWith($probe.Expected + ' is missing:')) { throw }
        $rejected=$true
    }
    if (-not $rejected) { throw ('Broken capture ABI was not rejected: ' + $probe.Expected) }
    $completed++
}
$ownerCallDescriptions = @('whole-binding move-site contract',
    'semantic preparation indexes named moves from canonical declared argument bindings',
    'named move reads include only exact direct receivers', 'intrinsic method body exclusion',
    'projected receiver requires an indexed lexical value root', 'aggregate fields cannot become projected receiver roots',
    'contextual intrinsic collision callables are indexed once per package',
    'contextual intrinsic collision index has one package producer')
$ownerCallAssertions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -in @('Assert-Matches','Assert-MatchCount') -and
    $node.CommandElements[-1] -is [Management.Automation.Language.StringConstantExpressionAst] -and
    $node.CommandElements[-1].Value -cin $ownerCallDescriptions
}, $true))
if ($ownerCallAssertions.Count -ne 8) { throw 'Owner/call assertion inventory differs' }
$ownerCallAssertion=[scriptblock]::Create($ownerCallAssertions.Extent.Text -join "`n")
function Read-OwnerCallSource([string]$Name) { [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('../selfhost/'+$Name+'.slg'))) }
$ownerCallSources=@{semanticOwnership=(Read-OwnerCallSource 'semantic/ownership_check');semanticContext=(Read-OwnerCallSource 'semantic/context');calls=(Read-OwnerCallSource 'semantic/calls')+"`n"+(Read-OwnerCallSource 'semantic/call_resolution_sources');text=(Read-OwnerCallSource 'llvm/text')}
Invoke-SsaAssertion $ownerCallAssertion $ownerCallSources
$completed++
$ownerCallMutations=@(
    @{Name='semanticOwnership';Before='moveEvent.awaited -> if { true => consumes! }';After='';Expected=$ownerCallDescriptions[0]},
    @{Name='semanticOwnership';Before='moveEvent.memberIr < 0';After='moveEvent.memberIr >= 0';Expected=$ownerCallDescriptions[0]},
    @{Name='semanticOwnership';Before='and moveEvent.siteIr < (typed -> len)';After='';Expected=$ownerCallDescriptions[0]},
    @{Name='semanticOwnership';Before='or moveSite.kind == 43';After='';Expected=$ownerCallDescriptions[0]},
    @{Name='semanticContext';Before='and (package -> callArgumentIsNamedRead(binding.sourceModule, binding.callAst, binding.argumentAst))';After='and true';Expected=$ownerCallDescriptions[1]},
    @{Name='semanticContext';Before='(package -> directCallReceiverAst(sourceModule, callAst)) == argumentAst';After='true';Expected=$ownerCallDescriptions[2]},
    @{Name='text';Before='and not (context.ir[index!] -> isIntrinsicDeclaration)';After='';Expected=$ownerCallDescriptions[3]},
    @{Name='calls';Before='package -> receiverSymbolIsRuntimeValue(sourceIndex, indexedName.symbol)';After='true';Expected=$ownerCallDescriptions[4]},
    @{Name='calls';Before='owner.kind == 3 or owner.kind == 4';After='owner.kind == 3';Expected=$ownerCallDescriptions[5]},
    @{Name='calls';Before='ModuleCallFacts { declarations: declarations, references: referenceIndex, intrinsicNames: intrinsicNames }';After='ModuleCallFacts { declarations: declarations, references: referenceIndex, intrinsicNames: [] }';Expected=$ownerCallDescriptions[6]}
)
foreach($probe in $ownerCallMutations){
    $mutated=$ownerCallSources.Clone();$mutated[$probe.Name]=$mutated[$probe.Name].Replace($probe.Before,$probe.After)
    if($mutated[$probe.Name] -ceq $ownerCallSources[$probe.Name]){throw 'Owner/call mutation did not change source'}
    $rejected=$false
    try{Invoke-SsaAssertion $ownerCallAssertion $mutated}catch{
        if(-not $_.Exception.Message.StartsWith($probe.Expected+' is missing:')){throw}
        $rejected=$true
    }
    if(-not $rejected){throw ('Broken owner/call contract was not rejected: '+$probe.Expected)}
    $completed++
}
@{ status = 'passed'; completed = $completed; total = 116; defaultFailuresRejected = 5; collectedFailures = 5; fullModeRejected = $true; executionOrderControls = 4; declaredLayoutControls = 7; continuationControls = 4; lateArrayControls = 6; budgetControls = 7; cleanupControls = 8; ssaControls = 21; sharedHandleControls = 10; parallelArgumentControls = 9; wasmWriteControls = 8; captureAbiControls = 5; ownerCallControls = 11 } | ConvertTo-Json
