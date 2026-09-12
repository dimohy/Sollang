[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CandidateCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$candidate = [IO.Path]::GetFullPath($CandidateCompiler)
$contractPath = Join-Path $root 'scripts/contracts/selfhost-async-runtime.json'
$fixturePath = Join-Path $root 'examples/regression/1066-time-duration-instance-sleep.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1066-time-duration-instance-sleep.stdout.txt'
$runtimeApiPath = Join-Path $root 'stdlib/sys/runtime/time.slg'
$managedAsyncPath = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Async.cs'
$managedIntrinsicPath = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.RuntimeIntrinsics.cs'
$managedRuntimePath = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmRuntimePlatform.cs'
$selfhostRuntimePath = Join-Path $root 'selfhost/llvm/emitter/async_runtime.slg'
$selfhostRootPath = Join-Path $root 'selfhost/llvm/text.slg'
$selfhostPreparePath = Join-Path $root 'selfhost/llvm/text/context_prepare.slg'
$selfhostContextPath = Join-Path $root 'selfhost/llvm/emitter/context.slg'
$selfhostTypedPath = Join-Path $root 'selfhost/ir/typed.slg'
$selfhostEntryLoweringPath = Join-Path $root 'selfhost/ir/typed/source_lowering.slg'
$selfhostFunctionLoweringPath = Join-Path $root 'selfhost/ir/typed/ordinary_function_expressions.slg'
$selfhostNormalizePath = Join-Path $root 'selfhost/ir/typed/resolved_context_normalize.slg'
$selfhostNormalizePhasesPath = Join-Path $root 'selfhost/ir/typed/resolved_context_normalize_phases.slg'
$selfhostInvariantsPath = Join-Path $root 'selfhost/llvm/text/invariants.slg'
$selfhostFunctionExpressionsPath = Join-Path $root 'selfhost/llvm/text/function_expressions.slg'
$selfhostEntryExpressionsPath = Join-Path $root 'selfhost/llvm/text/entry_expressions.slg'
$selfhostControlRegionExpressionsPath = Join-Path $root 'selfhost/llvm/text/control_region_expressions.slg'
$selfhostCorePreparePath = Join-Path $root 'selfhost/llvm/text/core_prepare.slg'
$selfhostFunctionsPath = Join-Path $root 'selfhost/llvm/text/functions.slg'
$selfhostCallsPath = Join-Path $root 'selfhost/llvm/text/core_calls.slg'
$stdlibPath = Join-Path $root 'stdlib'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$output = Join-Path $root ('artifacts/scratch/selfhost-async-runtime-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'selfhost-affine-task-structured-async-runtime'
    completed = 0
    total = 11
    candidateSha256 = if (Test-Path -LiteralPath $candidate -PathType Leaf) { (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash } else { $null }
    checks = @()
    resultPath = $resultPath
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 7) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}
function Read-Source([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "missing C414 authority: $Path" }
    [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
}
function Require-Text([string]$Source, [string]$Expected, [string]$Label) {
    if (-not $Source.Contains($Expected, [StringComparison]::Ordinal)) { throw "$Label is missing: $Expected" }
}

Save-Result
try {
    foreach ($path in @($candidate, $contractPath, $fixturePath, $expectedPath, $runtimeApiPath,
            $managedAsyncPath, $managedIntrinsicPath, $managedRuntimePath, $selfhostRuntimePath,
            $selfhostRootPath, $selfhostPreparePath, $selfhostCorePreparePath, $selfhostFunctionsPath,
            $selfhostCallsPath, $selfhostContextPath, $selfhostTypedPath, $selfhostEntryLoweringPath,
            $selfhostFunctionLoweringPath, $selfhostNormalizePath, $selfhostNormalizePhasesPath,
            $selfhostInvariantsPath, $selfhostFunctionExpressionsPath,
            $selfhostEntryExpressionsPath, $selfhostControlRegionExpressionsPath, $stdlibPath, $llvmAs)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "missing C414 input: $path" }
    }

    $contract = Read-Source $contractPath | ConvertFrom-Json
    if ($contract.schemaVersion -ne 1 -or
        $contract.scope -cne 'selfhost affine Task structured async runtime' -or
        $contract.fixture -cne '1066-time-duration-instance-sleep' -or
        $contract.requiredRuntimeSymbols.Count -ne 10 -or
        $contract.requiredGeneratedLlvm.Count -ne 7 -or
        $contract.forbiddenGeneratedLlvm.Count -ne 3 -or
        $contract.invariants.Count -ne 5) {
        throw 'C414 focused contract dimensions drifted'
    }
    Complete-Check 'contract-dimensions'

    $fixture = Read-Source $fixturePath
    $runtimeApi = Read-Source $runtimeApiPath
    Require-Text $fixture 'constructInAsync: -> async Int {' 'async user-function fixture'
    Require-Text $fixture 'construction -> await => constructedMillis' 'async user-function await fixture'
    Require-Text $fixture 'delay -> sleep => timer' 'Duration.sleep fixture'
    Require-Text $fixture 'timer -> await' 'sleep Task await fixture'
    Require-Text $runtimeApi 'public sleep: move self -> async Unit uses Clock = intrinsic' 'Duration.sleep API'
    Complete-Check 'natural-slg-affine-task-fixture'

    $managedAsync = Read-Source $managedAsyncPath
    $managedIntrinsic = Read-Source $managedIntrinsicPath
    $managedRuntime = Read-Source $managedRuntimePath
    foreach ($required in @('EmitAsyncFunction', 'sollang_task_start', 'EmitAwaitTask', 'sollang_task_join', 'sollang_task_release')) {
        if (-not ($managedAsync.Contains($required, [StringComparison]::Ordinal))) { throw "managed async authority is missing: $required" }
    }
    foreach ($required in @('EmitRuntimeSleepIntrinsic', 'sollang_sleep_worker', 'sollang_sleep_cancel')) {
        if (-not ($managedIntrinsic.Contains($required, [StringComparison]::Ordinal))) { throw "managed sleep authority is missing: $required" }
    }
    foreach ($required in $contract.requiredRuntimeSymbols) {
        if (-not ($managedRuntime.Contains($required, [StringComparison]::Ordinal))) { throw "managed Task runtime is missing: $required" }
    }
    Complete-Check 'managed-reference-authority'

    $selfhostRuntime = Read-Source $selfhostRuntimePath
    foreach ($required in $contract.requiredRuntimeSymbols) {
        if (-not ($selfhostRuntime.Contains($required, [StringComparison]::Ordinal))) { throw "selfhost Task runtime is missing: $required" }
    }
    foreach ($forbidden in @('define internal void @sollang_sleep_blocking', 'define internal void @sollang_sleep_compatibility')) {
        if ($selfhostRuntime.Contains($forbidden, [StringComparison]::Ordinal)) { throw "selfhost blocking sleep shim is forbidden: $forbidden" }
    }
    Complete-Check 'selfhost-runtime-implementation'

    $selfhostRoot = Read-Source $selfhostRootPath
    $selfhostPrepare = Read-Source $selfhostPreparePath
    $selfhostCorePrepare = Read-Source $selfhostCorePreparePath
    Require-Text $selfhostRoot 'import sollang.compiler.llvm.emitter.async_runtime as asyncRuntime' 'async runtime import'
    Require-Text $selfhostPrepare 'diagnostics.usesAsyncRuntime' 'async runtime capability detection'
    Require-Text $selfhostPrepare 'asyncRuntime.emitWindowsRuntime' 'Windows async runtime integration'
    Require-Text $selfhostPrepare 'asyncRuntime.emitLinuxRuntime' 'Linux async runtime integration'
    Require-Text $selfhostCorePrepare '%sollang.task_control = type' 'Task control type emission'
    Require-Text $selfhostCorePrepare 'usesTaskType! or usesAsyncRuntime -> if { "%sollang.task = type { ptr, ptr }" -> println }' 'Task aggregate type follows async runtime capability'
    Require-Text $selfhostCorePrepare '@sollang_task_ready_head = internal global ptr null' 'ready queue global emission'
    Require-Text $selfhostCorePrepare '@sollang_task_timer_head = internal global ptr null' 'timer queue global emission'
    Complete-Check 'selfhost-runtime-integration'

    $selfhostFunctions = Read-Source $selfhostFunctionsPath
    $selfhostCalls = Read-Source $selfhostCallsPath
    $selfhostContext = Read-Source $selfhostContextPath
    $selfhostTyped = Read-Source $selfhostTypedPath
    $selfhostEntryLowering = Read-Source $selfhostEntryLoweringPath
    $selfhostFunctionLowering = Read-Source $selfhostFunctionLoweringPath
    $selfhostNormalize = Read-Source $selfhostNormalizePath
    $selfhostNormalizePhases = Read-Source $selfhostNormalizePhasesPath
    $selfhostInvariants = Read-Source $selfhostInvariantsPath
    $selfhostFunctionExpressions = Read-Source $selfhostFunctionExpressionsPath
    $selfhostEntryExpressions = Read-Source $selfhostEntryExpressionsPath
    $selfhostControlRegionExpressions = Read-Source $selfhostControlRegionExpressionsPath
    Require-Text $selfhostFunctions 'function.flags / 8 % 2 == 1' 'async function dispatch'
    Require-Text $selfhostFunctions 'emitAsyncFunction' 'async function Task boundary emission'
    Require-Text $selfhostCalls 'node.opcode == -113' 'Duration.sleep opcode lowering'
    Require-Text $selfhostCalls 'sollang_task_start' 'sleep Task creation'
    Require-Text $selfhostCalls 'sollang_task_join' 'await join lowering'
    Require-Text $selfhostCalls 'sollang_task_release' 'await release lowering'
    Require-Text $selfhostContext 'public awaitSourceByAst: [Bool; ~]' 'await source index authority'
    Require-Text $selfhostPrepare 'awaitSourceByAst! -> push(false)' 'await source index construction'
    Require-Text $selfhostCalls 'context.awaitSourceByAst[range.astStart + node.astNode]' 'constant-time await lookup'
    $awaitLookup = [regex]::Match($selfhostCalls, '(?s)isAwaitSourceNode nodeIndex:.*?\n}\n\nawaitTaskProducer')
    if (-not $awaitLookup.Success -or $awaitLookup.Value.Contains('-> while', [StringComparison]::Ordinal)) {
        throw 'await source lookup must not rescan AST nodes'
    }
    Require-Text $selfhostTyped 'public builtinRuntimeCallResultTypeSymbol functionSymbol: Int -> Int' 'shared built-in runtime result type authority'
    Require-Text $selfhostTyped 'functionSymbol == -113 -> if { 0 => result! }' 'Duration.sleep underlying Unit result'
    Require-Text $selfhostTyped 'public builtinRuntimeCallIsAsync functionSymbol: Int -> Bool => functionSymbol == -113' 'Duration.sleep async identity'
    foreach ($lowering in @($selfhostEntryLowering, $selfhostFunctionLowering)) {
        Require-Text $lowering '-> builtinRuntimeCallResultTypeSymbol' 'shared runtime result type consumer'
        Require-Text $lowering '-> builtinRuntimeCallIsAsync' 'shared runtime async consumer'
    }
    Require-Text $selfhostEntryLowering 'entryResolvedCall.functionSymbol => entryExpressionOpcode!' 'entry canonical async runtime opcode'
    Require-Text $selfhostFunctionLowering 'resolvedCall.functionSymbol => expressionOpcode!' 'function canonical async runtime opcode'
    Require-Text $selfhostNormalize 'nodes -> normalizeResolvedTimeRuntime(prepared)' 'stdlib-aware time runtime normalization consumer'
    Require-Text $selfhostNormalizePhases 'targetSymbol.flags / 128 % 2 == 1' 'canonical time intrinsic declaration identity'
    Require-Text $selfhostNormalizePhases 'sourceMatches(targetIdentity.pathStart, targetIdentity.pathLength, "std.time")' 'canonical std.time module identity'
    Require-Text $selfhostNormalizePhases 'timeOpcode == -113' 'stdlib-aware Duration.sleep opcode sealing'
    Require-Text $selfhostInvariants 'and (context.ir[node.operand0].flags / 8) % 2 == 0' 'S054 excludes async Unit Task producers'
    Require-Text $selfhostFunctionExpressions 'expression.kind == 5 and not (expressionIndex -> isAwaitSourceNode(context))' 'function await read bypasses ordinary freeze'
    Require-Text $selfhostEntryExpressions 'and not (entryExpressionIndex -> isAwaitSourceNode(context))' 'entry await read bypasses ordinary freeze'
    Require-Text $selfhostControlRegionExpressions 'and not (regionNodeIndex -> isAwaitSourceNode(context))' 'control-region await read bypasses ordinary freeze'
    Complete-Check 'selfhost-async-call-and-await-lowering'

    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $selfhostRuntimePath,$selfhostRootPath,$selfhostPreparePath,$selfhostCorePreparePath,$selfhostFunctionsPath,$selfhostCallsPath,$selfhostContextPath,$selfhostTypedPath,$selfhostEntryLoweringPath,$selfhostFunctionLoweringPath,$selfhostNormalizePath,$selfhostNormalizePhasesPath,$selfhostInvariantsPath,$selfhostFunctionExpressionsPath,$selfhostEntryExpressionsPath,$selfhostControlRegionExpressionsPath
    if ($LASTEXITCODE -ne 0) { throw 'C414 authoritative focused format failed' }
    Complete-Check 'authoritative-focused-format'

    $expected = (Read-Source $expectedPath).TrimEnd("`n")
    $candidateExe = Join-Path $output 'candidate.exe'
    $candidateLog = (& $candidate run $fixturePath --stdlib $stdlibPath --llvm $llvmRoot -o $candidateExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $candidateLog -match '(?m)^warning ' -or
        $candidateLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) {
        throw "selfhost C414 exact execution failed: $candidateLog"
    }
    Complete-Check 'current-selfhost-native-exact-warning-zero'

    $candidateLlvm = $candidateExe + '.ll'
    $llvmText = Read-Source $candidateLlvm
    foreach ($required in $contract.requiredGeneratedLlvm) {
        Require-Text $llvmText $required 'generated structured-async LLVM'
    }
    foreach ($forbidden in $contract.forbiddenGeneratedLlvm) {
        if ($llvmText.Contains($forbidden, [StringComparison]::Ordinal)) { throw "generated LLVM contains forbidden C414 path: $forbidden" }
    }
    Complete-Check 'generated-llvm-structured-async-contract'

    & $llvmAs $candidateLlvm -o (Join-Path $output 'candidate.bc')
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C414 LLVM assembly failed' }
    Complete-Check 'llvm-assembly'

    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $candidateLlvm
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C414 direct-call closure failed' }
    Complete-Check 'direct-call-closure'

    $record.status = 'passed'
    Save-Result
    Write-Host "[selfhost async runtime] PASS 11/11; $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
