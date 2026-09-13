[CmdletBinding()]
param(
    [switch]$ContractOnly,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-Authority([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "indexed-owned-exchange authority is missing: $RelativePath"
    }
    return [IO.File]::ReadAllText($path)
}

function Require([bool]$Condition, [string]$Description) {
    if (-not $Condition) {
        throw "indexed-owned-exchange contract failure: $Description"
    }
}

$contractPath = Join-Path $RepositoryRoot 'scripts/contracts/indexed-owned-exchange.json'
$schemaPath = Join-Path $RepositoryRoot 'scripts/contracts/indexed-owned-exchange.schema.json'
$contractText = Read-Authority 'scripts/contracts/indexed-owned-exchange.json'
$null = Read-Authority 'scripts/contracts/indexed-owned-exchange.schema.json'

Require ($contractText | Test-Json -SchemaFile $schemaPath -ErrorAction Stop) 'contract does not satisfy its schema'
$contract = $contractText | ConvertFrom-Json
$identity = $contract.canonicalIdentity

Require ($identity.id -ceq 'collection.array.exchange') 'canonical id drifted'
Require ($identity.managedKind -ceq 'ArrayExchange') 'managed kind drifted'
Require ($identity.selfhostOpcode -eq -310) 'selfhost opcode drifted'

if ($ContractOnly) {
    Write-Host '[indexed-owned-exchange] PASS contract-only canonical identity collection.array.exchange / ArrayExchange / -310.'
    return
}

$expectedCaseKinds = [ordered]@{
    'P-DISTINCT' = 'native-success'
    'P-SAME' = 'native-success'
    'N-LEFT-BOUNDS' = 'native-trap'
    'N-RIGHT-BOUNDS' = 'native-trap'
    'P-NESTED-CLEANUP' = 'native-success'
    'N-HEAP' = 'compile-failure'
    'N-DEQUE' = 'compile-failure'
    'N-ARITY' = 'compile-failure'
    'N-INDEX-TYPE' = 'compile-failure'
}
Require ($contract.fixtures.cases.Count -eq $expectedCaseKinds.Count) 'focused matrix must contain exactly nine cases'
$caseIds = @($contract.fixtures.cases | ForEach-Object { $_.id })
Require (($caseIds | Select-Object -Unique).Count -eq $expectedCaseKinds.Count) 'focused matrix case ids must be unique'
foreach ($entry in $expectedCaseKinds.GetEnumerator()) {
    $case = @($contract.fixtures.cases | Where-Object { $_.id -ceq $entry.Key })
    Require ($case.Count -eq 1) "focused matrix must contain $($entry.Key) exactly once"
    Require ($case[0].kind -ceq $entry.Value) "$($entry.Key) must use kind $($entry.Value)"
    $null = Read-Authority $case[0].source
    $expectedText = Read-Authority $case[0].expected
    if ($entry.Value -ceq 'native-trap') {
        Require ($expectedText.Length -eq 0) "$($entry.Key) must require exact empty stdout"
    } else {
        Require (-not [string]::IsNullOrWhiteSpace($expectedText)) "$($entry.Key) expected evidence must not be empty"
    }
}
$null = Read-Authority $contract.fixtures.manualWorkaroundNegative
$null = Read-Authority $contract.fixtures.manualWorkaroundDiagnostic
$focusedVerifier = Read-Authority $contract.fixtures.verifier
$reclassifier = Read-Authority $contract.fixtures.reclassifier
$auditShim = Read-Authority $contract.fixtures.auditShim
$resultSchemaText = Read-Authority $contract.fixtures.resultSchema
$resultSchema = $resultSchemaText | ConvertFrom-Json
Require ($resultSchema.properties.total.const -eq 9) 'result schema total must remain nine'
Require ($resultSchema.properties.cases.minItems -eq 9 -and $resultSchema.properties.cases.maxItems -eq 9) 'result schema must require all nine cases'
Require ($focusedVerifier.Contains('Inspect-ExchangeLlvm')) 'focused verifier must inspect generated exchange LLVM'
Require ($focusedVerifier.Contains('Invoke-AllocationAudit')) 'focused verifier must execute the allocation audit'
Require ($focusedVerifier.Contains('verify-llvm-direct-call-closure.ps1')) 'focused verifier must run V004'
Require ($reclassifier.Contains('reclassified-immutable-artifacts')) 'reclassifier must identify reused immutable evidence'
Require ($auditShim.Contains('allocations != releases || invalid_releases != 0')) 'audit shim must fail on imbalance or invalid cleanup'

$positiveProbe = Read-Authority 'scripts/probes/general-algorithms/indexed-owned-exchange-positive.slg'
Require ($positiveProbe.Contains('payload: box NestedOwner')) 'positive probe must use nested noncopyable elements'
Require ($positiveProbe.Contains('values! -> exchange(0, 2)')) 'positive probe must exchange distinct indices'
Require ($positiveProbe.Contains('values! -> exchange(1, 1)')) 'positive probe must exercise a valid same-index no-op'
Require ($positiveProbe.Contains('finalLength == originalLength')) 'positive probe must reuse the owner and preserve length'
Require ($positiveProbe.Contains('finalCapacity == originalCapacity')) 'positive probe must preserve capacity'
$leftBoundsProbe = Read-Authority 'scripts/probes/general-algorithms/indexed-owned-exchange-left-bounds.slg'
$rightBoundsProbe = Read-Authority 'scripts/probes/general-algorithms/indexed-owned-exchange-right-bounds.slg'
Require ($leftBoundsProbe.Contains('values! -> exchange(-1, 1)')) 'left-bounds probe must fail its left index'
Require ($rightBoundsProbe.Contains('values! -> exchange(1, 3)')) 'right-bounds probe must fail its right index'

$spec = Read-Authority 'docs/SPEC.md'
Require ($spec.Contains('`values! -> exchange(left, right)`')) 'SPEC must define the canonical exchange syntax'
Require ($spec.Contains('Both bounds are validated before either element is loaded or stored')) 'SPEC must require bounds-before-mutation'
Require ([regex]::IsMatch($spec, 'Equal valid\s+indices are a no-op')) 'SPEC must define same-index behavior'

$managedBoundProgram = Read-Authority 'src/Sollang.Compiler/Semantics/BoundProgram.cs'
$managedSemantic = Read-Authority 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'
$managedEmitter = Read-Authority 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Flow.cs'
$managedExchangeEmitter = Read-Authority 'src/Sollang.Compiler/CodeGen/LlvmEmitter.ArrayExchange.cs'
$selfhostTyped = Read-Authority 'selfhost/ir/typed.slg'
$selfhostOrdinary = Read-Authority 'selfhost/ir/typed/ordinary_function_expressions.slg'
$selfhostEntry = Read-Authority 'selfhost/ir/typed/source_lowering.slg'
$selfhostOrdinaryFinalize = Read-Authority 'selfhost/ir/typed/ordinary_function_finalize_phases.slg'
$selfhostEntryFinalize = Read-Authority 'selfhost/ir/typed/source_lowering_finalize.slg'
$selfhostContainers = Read-Authority 'selfhost/llvm/text/containers.slg'
$selfhostFunctionEmitter = Read-Authority 'selfhost/llvm/text/function_expressions.slg'
$selfhostEntryEmitter = Read-Authority 'selfhost/llvm/text/entry_expressions.slg'
$selfhostRegionEmitter = Read-Authority 'selfhost/llvm/text/control_region_expressions.slg'
$selfhostScheduling = Read-Authority 'selfhost/llvm/text/function_scheduling.slg'
$selfhostInvariants = Read-Authority 'selfhost/llvm/text/invariants.slg'

$integrationFailures = [Collections.Generic.List[string]]::new()
function Require-Integration([bool]$Condition, [string]$Description) {
    if (-not $Condition) {
        $integrationFailures.Add($Description)
    }
}

$managedSources = $managedBoundProgram + "`n" + $managedSemantic + "`n" + $managedEmitter
$managedKindDefinitionCount = [regex]::Matches(
    $managedBoundProgram,
    '(?m)^\s*ArrayExchange\s*,?\s*$').Count
Require-Integration ($managedKindDefinitionCount -eq 1) 'managed ArrayExchange enum identity must be defined exactly once in BoundProgram.cs'
Require-Integration ([regex]::Matches($managedBoundProgram, 'IReadOnlyDictionary<object, ContainerIntrinsicKind>\s+ContainerIntrinsics').Count -eq 1) 'BoundProgram must preserve one authoritative typed container-intrinsic map'
Require-Integration ([regex]::Matches($managedSemantic, '_containerIntrinsics\[target\]\s*=\s*ContainerIntrinsicKind\.ArrayExchange;').Count -eq 1) 'SemanticCompiler must bind exchange to the managed identity exactly once'
Require-Integration ([regex]::Matches($managedEmitter, 'ContainerIntrinsicKind\.ArrayExchange\s*=>\s*EmitArrayExchange').Count -eq 1) 'LLVM flow emission must dispatch the managed identity exactly once instead of spelling'
Require-Integration ($managedExchangeEmitter.Contains('EmitCompare(leftInBounds, "ult", "i64", left, length)')) 'managed exchange must check the left bound'
Require-Integration ($managedExchangeEmitter.Contains('EmitCompare(rightInBounds, "ult", "i64", right, length)')) 'managed exchange must check the right bound'
Require-Integration ($managedExchangeEmitter.Contains('EmitBinary(inBounds, "and", "i1", leftInBounds, rightInBounds)')) 'managed exchange must combine both bounds before mutation'
Require-Integration ($managedExchangeEmitter.Contains('EmitConditionalBranch(same, done, swap)')) 'managed exchange must bypass memory operations for equal indices'
foreach ($forbidden in @('EmitHeapAllocate', 'EmitHeapFree', 'memcpy', 'memmove', 'DropOwnedRuntimeValue')) {
    Require-Integration (-not $managedExchangeEmitter.Contains($forbidden)) "managed exchange must not contain $forbidden"
}

$exchangeClassifier = [regex]::Matches(
    $selfhostTyped,
    '(?s)sourceMatches\([^\r\n]*"exchange"\).*?->\s*if\s*\{\s*(?<opcode>-\d+)\s*=>\s*opcode!\s*\}')
Require-Integration ($exchangeClassifier.Count -eq 1) 'selfhost intrinsic classifier must map exchange exactly once'
if ($exchangeClassifier.Count -eq 1) {
    Require-Integration ([int]$exchangeClassifier[0].Groups['opcode'].Value -eq $identity.selfhostOpcode) 'selfhost exchange classifier opcode must equal the contract opcode'
}

Require-Integration ($selfhostTyped.Contains('isArrayExchangeIntrinsicCall')) 'selfhost Typed IR must expose one canonical exchange predicate'
Require-Integration ($selfhostTyped.Contains('opcode == -310')) 'selfhost exchange predicate must consume opcode -310'
Require-Integration ($selfhostOrdinary.Contains('isArrayExchangeIntrinsicCall') -or $selfhostOrdinary.Contains('flowOpcode == -310')) 'ordinary-function Typed IR must retain the exchange identity'
Require-Integration ($selfhostEntry.Contains('isArrayExchangeIntrinsicCall') -or $selfhostEntry.Contains('entryFlowOpcode == -310')) 'entry Typed IR must retain the exchange identity'
Require-Integration ($selfhostOrdinaryFinalize.Contains('isArrayExchangeOpcode')) 'ordinary-function operand finalization must retain exchange receiver and indices'
Require-Integration ($selfhostEntryFinalize.Contains('isArrayExchangeOpcode')) 'entry operand finalization must retain exchange receiver and indices'
Require-Integration ($selfhostContainers.Contains('emitExchange ')) 'container LLVM lowering must define emitExchange'
Require-Integration ($selfhostFunctionEmitter.Contains('emitExchange(context, state)')) 'named-function LLVM must dispatch emitExchange'
Require-Integration ($selfhostEntryEmitter.Contains('emitExchange(context, state)')) 'entry LLVM must dispatch emitExchange'
Require-Integration ($selfhostRegionEmitter.Contains('emitExchange(context, state)')) 'control-region LLVM must dispatch emitExchange'
Require-Integration ($selfhostScheduling.Contains('isArrayExchangeIntrinsicCall') -or $selfhostScheduling.Contains('opcode == -310')) 'scheduler must classify exchange as a mutation barrier'
Require-Integration ($selfhostInvariants.Contains('isArrayExchangeIntrinsicCall') -or $selfhostInvariants.Contains('opcode == -310')) 'LLVM invariants must require one writable exchange owner'

$exchangeBodyMatch = [regex]::Match($selfhostContainers, '(?s)emitExchange .*?(?=\r?\nemitTake )')
Require-Integration $exchangeBodyMatch.Success 'emitExchange body must have a stable isolated lowering boundary'
if ($exchangeBodyMatch.Success) {
    $exchangeBody = $exchangeBodyMatch.Value
    $orderedMarkers = @(
        '_left_in_bounds = icmp ult',
        '_right_in_bounds = icmp ult',
        '_in_bounds = and i1',
        '_validated, label',
        '_same = icmp eq',
        '_left_ptr = getelementptr',
        '_right_ptr = getelementptr',
        '_left_value = load',
        '_right_value = load',
        '  store '
    )
    $previous = -1
    foreach ($marker in $orderedMarkers) {
        $next = $exchangeBody.IndexOf($marker, [StringComparison]::Ordinal)
        Require-Integration ($next -gt $previous) "emitExchange ordering marker is missing or out of order: $marker"
        $previous = $next
    }
    Require-Integration ($exchangeBody.Contains('context.ir[exchangeNode.operand1].nextOperand')) 'emitExchange must consume the canonical right-index sibling'
    Require-Integration ($exchangeBody.Contains('_same, label %exchange$(exchangeIndex)_done, label %exchange$(exchangeIndex)_swap')) 'same-index exchange must bypass every memory operation'
    foreach ($forbidden in @('@malloc', '@free', 'memcpy', 'memmove', 'sollang_drop')) {
        Require-Integration (-not $exchangeBody.Contains($forbidden)) "emitExchange must not contain $forbidden"
    }
}

if ($integrationFailures.Count -ne 0) {
    $hasManagedIdentity = $managedSources.Contains('ArrayExchange')
    $hasSelfhostIdentity = $selfhostTyped.Contains('-310') -or $selfhostTyped.Contains('"exchange"')
    $state = if ($hasManagedIdentity -or $hasSelfhostIdentity) { 'FAIL' } else { 'PENDING' }
    Write-Host "[indexed-owned-exchange] $state integrated canonical identity is incomplete:"
    foreach ($failure in $integrationFailures) {
        Write-Host " - $failure"
    }
    throw "indexed-owned-exchange integrated validation $($state.ToLowerInvariant()) with $($integrationFailures.Count) missing invariant(s)"
}

Write-Host '[indexed-owned-exchange] PASS contract, managed typed identity, and selfhost opcode consumption are integrated 1:1.'
