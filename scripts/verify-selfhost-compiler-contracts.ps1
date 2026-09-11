[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot "verify-ai-slg-best-practices.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-portable-memory-io-contract.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-project-progress.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-native-exact-source-closure-contract.ps1")
& (Join-Path $PSScriptRoot "verify-http-server-contract.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-socket-datagram-contract.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-socket-vectored-contract.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-socket-try-clone-contract.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-socket-reactor-contract.ps1") -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-struct-field-migration.ps1") -RepositoryRoot $RepositoryRoot

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
& (Join-Path $PSScriptRoot "verify-selfhost-fragment-manifests.ps1")
& (Join-Path $PSScriptRoot "verify-selfhost-source-structure.ps1")
& (Join-Path $PSScriptRoot "verify-llvm-emitter-modules.ps1")
& (Join-Path $PSScriptRoot "verify-llvm-emitter-split-abi.ps1")
& (Join-Path $PSScriptRoot "verify-selfhost-llvm-function-diff.ps1") `
    -RepositoryRoot $RepositoryRoot

& (Join-Path $PSScriptRoot "verify-input-fingerprint-stability-contract.ps1")
& (Join-Path $PSScriptRoot "verify-selfhost-stage3-seed-provenance.ps1") `
    -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-verified-stage3-install-contract.ps1")
& (Join-Path $PSScriptRoot "verify-quic-stream-api-contract.ps1") `
    -RepositoryRoot $RepositoryRoot
& (Join-Path $PSScriptRoot "verify-browser-stage2-input-fingerprint-contract.ps1")
& (Join-Path $PSScriptRoot "verify-cpu-target-contract.ps1") `
    -RepositoryRoot $RepositoryRoot

function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Description)
    if (-not $Text.Contains($Expected)) {
        throw "$Description is missing: $Expected"
    }
}

function Assert-NotContains {
    param([string]$Text, [string]$Forbidden, [string]$Description)
    if ($Text.Contains($Forbidden)) {
        throw "$Description retained forbidden text: $Forbidden"
    }
}

function Assert-Matches {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if (-not [regex]::IsMatch($Text, $Pattern)) {
        throw "$Description is missing: $Pattern"
    }
}

function Assert-NotMatches {
    param([string]$Text, [string]$Pattern, [string]$Description)
    if ([regex]::IsMatch($Text, $Pattern)) {
        throw "$Description retained forbidden pattern: $Pattern"
    }
}

function Assert-MatchCount {
    param([string]$Text, [string]$Pattern, [int]$ExpectedCount, [string]$Description)
    $actualCount = [regex]::Matches($Text, $Pattern).Count
    if ($actualCount -ne $ExpectedCount) {
        throw "$Description count differs: expected $ExpectedCount, actual $actualCount"
    }
}

function Get-LlvmFunctionDefinitions {
    param([string]$Text, [string]$Name)
    $escapedName = [regex]::Escape($Name)
    return @([regex]::Matches(
        $Text,
        "(?ms)^        define internal %sollang\.socket_result @$escapedName\(.*?^        \}"))
}

$analysisPath = Join-Path $RepositoryRoot "selfhost/semantic/analysis.slg"
$callsPath = Join-Path $RepositoryRoot "selfhost/semantic/calls.slg"
$callResolutionSourcesPath = Join-Path $RepositoryRoot "selfhost/semantic/call_resolution_sources.slg"
$astPath = Join-Path $RepositoryRoot "selfhost/syntax/ast.slg"
$semanticContextPath = Join-Path $RepositoryRoot "selfhost/semantic/context.slg"
$semanticResolvePath = Join-Path $RepositoryRoot "selfhost/semantic/resolve.slg"
$typeIdsPath = Join-Path $RepositoryRoot "selfhost/semantic/type_ids.slg"
$expressionTypesPath = Join-Path $RepositoryRoot "selfhost/semantic/expression_types.slg"
$expressionTypeIdsPath = Join-Path $RepositoryRoot "selfhost/semantic/expression_type_ids.slg"
$expressionTypeIdsResolutionPhasesPath = Join-Path $RepositoryRoot "selfhost/semantic/expression_type_ids_resolution_phases.slg"
$expressionTypeIdsPathsPath = Join-Path $RepositoryRoot "selfhost/semantic/expression_type_ids_paths.slg"
$lateArrayTypesPath = Join-Path $RepositoryRoot "selfhost/semantic/late_array_types.slg"
$lateArrayFixturePath = Join-Path $RepositoryRoot "examples/regression/1217-selfhost-late-indexed-array-type-contract.slg"
$logicalIrFixturePath = Join-Path $RepositoryRoot "examples/regression/1131-selfhost-four-term-logical-ir.slg"
$directoryBinaryFixturePath = Join-Path $RepositoryRoot "examples/regression/986-selfhost-real-directory-binary-contract.slg"
$terminalFlowControlReturnFixturePath = Join-Path $RepositoryRoot "examples/regression/1382-selfhost-terminal-flow-control-return.slg"
$nestedResultLogicalConditionFixturePath = Join-Path $RepositoryRoot "examples/regression/1384-nested-result-logical-condition.slg"
$typeCheckPath = Join-Path $RepositoryRoot "selfhost/semantic/type_check.slg"
$typedPath = Join-Path $RepositoryRoot "selfhost/ir/typed.slg"
$typedTypeQueriesPath = Join-Path $RepositoryRoot "selfhost/ir/typed/type_queries.slg"
$typedFunctionLoweringPath = Join-Path $RepositoryRoot "selfhost/ir/typed/function_lowering.slg"
$typedOrdinaryFunctionPath = Join-Path $RepositoryRoot "selfhost/ir/typed/ordinary_function.slg"
$typedOrdinaryFunctionExpressionsPath = Join-Path $RepositoryRoot "selfhost/ir/typed/ordinary_function_expressions.slg"
$typedOrdinaryFunctionFinalizePath = Join-Path $RepositoryRoot "selfhost/ir/typed/ordinary_function_finalize.slg"
$typedOrdinaryFunctionFinalizePhasesPath = Join-Path $RepositoryRoot "selfhost/ir/typed/ordinary_function_finalize_phases.slg"
$typedSourceLoweringPath = Join-Path $RepositoryRoot "selfhost/ir/typed/source_lowering.slg"
$typedSourceLoweringFinalizePath = Join-Path $RepositoryRoot "selfhost/ir/typed/source_lowering_finalize.slg"
$typedResolvedContextNormalizePath = Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_normalize.slg"
$typedResolvedContextNormalizePhasesPath = Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_normalize_phases.slg"
$typedResolvedContextSealPath = Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_seal.slg"
$typedResolvedContextFinalizePath = Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_finalize.slg"
$typedValueAliasesPath = Join-Path $RepositoryRoot "selfhost/ir/typed/value_aliases.slg"
$lateTypeSealingVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-late-type-sealing.ps1"
$interpolationIrPath = Join-Path $RepositoryRoot "selfhost/ir/interpolation.slg"
$streamIrPath = Join-Path $RepositoryRoot "selfhost/ir/stream.slg"
$textPath = Join-Path $RepositoryRoot "selfhost/llvm/text.slg"
$entryExpressionsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/entry_expressions.slg"
$corePreparePath = Join-Path $RepositoryRoot "selfhost/llvm/text/core_prepare.slg"
$functionSchedulingPath = Join-Path $RepositoryRoot "selfhost/llvm/text/function_scheduling.slg"
$foundationPath = Join-Path $RepositoryRoot "selfhost/llvm/text/foundation.slg"
$coreCallsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/core_calls.slg"
$callArgumentsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/call_arguments.slg"
$aggregateValuesPath = Join-Path $RepositoryRoot "selfhost/llvm/text/aggregate_values.slg"
$functionsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/functions.slg"
$functionExpressionsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/function_expressions.slg"
$functionCallsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/function_calls.slg"
$functionReturnsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/function_returns.slg"
$controlPath = Join-Path $RepositoryRoot "selfhost/llvm/text/control.slg"
$controlRegionsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/control_regions.slg"
$controlRegionExpressionsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/control_region_expressions.slg"
$containersPath = Join-Path $RepositoryRoot "selfhost/llvm/text/containers.slg"
$containerControlPath = Join-Path $RepositoryRoot "selfhost/llvm/text/container_control.slg"
$invariantsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/invariants.slg"
$invariantRulesPath = Join-Path $RepositoryRoot "selfhost/llvm/invariant_rules.slg"
$invariantDiagnosticsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/invariant_diagnostics.slg"
$emitterContextPath = Join-Path $RepositoryRoot "selfhost/llvm/emitter/context.slg"
$emitterDiagnosticsPath = Join-Path $RepositoryRoot "selfhost/llvm/emitter/diagnostics.slg"
$processRuntimePath = Join-Path $RepositoryRoot "selfhost/llvm/emitter/process_runtime.slg"
$managedWindowsProcessRuntimePath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs"
$managedLinuxProcessRuntimePath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs"
$managedProcessEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Process.cs"
$managedEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.cs"
$managedParallelEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Parallel.cs"
$managedControlEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Expressions.Control.cs"
$managedUtilitiesEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs"
$managedEnumEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Enums.cs"
$managedStructEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs"
$managedStatementsEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Statements.cs"
$managedSocketEmitterPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs"
$grammarPath = Join-Path $RepositoryRoot "syntax/sollang.grammar"
$managedParserGeneratorPath = Join-Path $RepositoryRoot "src/Sollang.Compiler.Generators/ParserSourceGenerator.cs"
$managedSemanticCompilerPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
$standardProcessPath = Join-Path $RepositoryRoot "stdlib/sys/process.slg"
$standardProcessRuntimePath = Join-Path $RepositoryRoot "stdlib/sys/runtime/process.slg"
$ownershipPath = Join-Path $RepositoryRoot "selfhost/llvm/text/ownership.slg"
$semanticOwnershipPath = Join-Path $RepositoryRoot "selfhost/semantic/ownership_check.slg"
$storedArrayReferenceDiagnosticPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-stored-array-reference-diagnostic.ps1"
$semanticParityDiagnosticPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-semantic-parity-diagnostics.ps1"
$textOutputRuntimePath = Join-Path $RepositoryRoot "selfhost/llvm/emitter/text_output_runtime.slg"
$socketRuntimePath = Join-Path $RepositoryRoot "selfhost/llvm/emitter/socket_runtime.slg"
$platformIoPath = Join-Path $RepositoryRoot "selfhost/llvm/text/platform_io.slg"
$windowsSocketRuntimePath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs"
$linuxSocketRuntimePath = Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs"
$textContextPath = Join-Path $RepositoryRoot "selfhost/llvm/text/context_prepare.slg"
$entrypointsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/entrypoints.slg"
$incrementalVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-incremental.ps1"
$stage2VerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage2.ps1"
$stage3VerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage3.ps1"
$releasePublisherPath = Join-Path $RepositoryRoot "scripts/publish-release.ps1"
$nativeReleasePackagePath = Join-Path $RepositoryRoot "scripts/native-release-package.ps1"
$nativeReleasePackageContractPath = Join-Path $RepositoryRoot "scripts/verify-native-release-package-contract.ps1"
$browserStage2Path = Join-Path $RepositoryRoot "scripts/build-stage2-browser.ps1"
$browserStage2FingerprintPath = Join-Path $RepositoryRoot "scripts/browser-stage2-input-fingerprint.ps1"
$browserStage2ArtifactVerifierPath = Join-Path $RepositoryRoot "scripts/verify-browser-stage2-artifacts.ps1"
$browserStage2RunnerPath = Join-Path $RepositoryRoot "scripts/verify-browser-stage2.mjs"
$browserProgramRunnerPath = Join-Path $RepositoryRoot "scripts/verify-browser-program.mjs"
$linuxStage2Path = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage2-linux.ps1"
$linuxStage3Path = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage3-linux.ps1"
$directCallClosurePath = Join-Path $RepositoryRoot "scripts/verify-llvm-direct-call-closure.ps1"
$nativeBinaryVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-binary-codecs.ps1"
$nativeSetVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-set-intrinsics.ps1"
$nativeSourceStyleVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-source-style.ps1"
$nativeFormatVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-cli-format.ps1"
$ownedBlockVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-owned-block-result-diagnostics.ps1"
$unresolvedCallDiagnosticVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-unresolved-call-diagnostic.ps1"
$resultPropagationDiagnosticVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-result-propagation-diagnostics.ps1"
$traitOwnershipDiagnosticVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-trait-ownership-diagnostics.ps1"
$traitOwnershipDiagnosticContractPath = Join-Path $RepositoryRoot "scripts/contracts/trait-ownership-diagnostics.json"
$privateFieldDiagnosticVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-private-field-diagnostics.ps1"
$nativeProcessVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-process-child-lifecycle.ps1"
$nativeQuicEndpointOwnershipVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-quic-endpoint-ownership.ps1"
$nativeQuicEndpointOwnershipLinuxVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-quic-endpoint-ownership-linux.ps1"
$nativeSocketTimeoutVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-socket-timeouts.ps1"
$nativeMutableParameterVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-mutable-parameter-indexing.ps1"
$nativeMutableParameterBatchVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-mutable-parameter-indexing-batch.ps1"
$nativeExactFixtureVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-exact-fixture.ps1"
$nativeExactFixtureBatchVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-exact-fixture-batch.ps1"
$nativeExactBatchProfilerPath = Join-Path $RepositoryRoot "scripts/measure-native-exact-batch-profile.ps1"
$nativeExactBatchProfileSummaryPath = Join-Path $RepositoryRoot "scripts/show-native-exact-batch-profile.ps1"
$nativeExactBatchProfileSchemaPath = Join-Path $RepositoryRoot "scripts/contracts/native-exact-batch-profile.schema.json"
$nativeExactBatchProfileContractPath = Join-Path $RepositoryRoot "scripts/verify-native-exact-batch-profile-contract.ps1"
$parallelCallbackLlvmVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-parallel-callback-llvm.ps1"
$parallelCallbackLlvmValidFixturePath = Join-Path $RepositoryRoot "scripts/contracts/fixtures/selfhost-parallel-callback-valid.ll"
$parallelCallbackLlvmSerialFixturePath = Join-Path $RepositoryRoot "scripts/contracts/fixtures/selfhost-parallel-callback-serial-fallback.ll"
$parallelCallbackCacheVerifierPath = Join-Path $RepositoryRoot "scripts/verify-parallel-callback-cache-stability.ps1"
$nativeInterpolationReferenceVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-interpolation-reference-arguments.ps1"
$nativeProjectedReferenceVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-projected-reference-places.ps1"
$nativeLanguageServerVerifierPath = Join-Path $RepositoryRoot "scripts/verify-native-language-server.ps1"
$linuxProcessVerifierPath = Join-Path $RepositoryRoot "scripts/verify-linux-process-child-lifecycle.ps1"
$processDropVerifierPath = Join-Path $RepositoryRoot "scripts/verify-process-child-drop-once.ps1"
$processDropContractPath = Join-Path $RepositoryRoot "scripts/verify-process-child-drop-contract.ps1"
$verificationProcessPath = Join-Path $RepositoryRoot "scripts/verification-process.ps1"
$verificationProcessContractPath = Join-Path $RepositoryRoot "scripts/verify-verification-process-contract.ps1"
$verificationProcessExitRacePath = Join-Path $RepositoryRoot "scripts/verify-verification-process-exit-race.ps1"
$emitContextClosureVerifierPath = Join-Path $RepositoryRoot "scripts/verify-emit-context-constructor-closure.ps1"
$emitContextClosureContractPath = Join-Path $RepositoryRoot "scripts/verify-emit-context-constructor-closure-contract.ps1"
$detachedVerificationPath = Join-Path $RepositoryRoot "scripts/invoke-detached-selfhost-verification.ps1"
$detachedCancellationPath = Join-Path $RepositoryRoot "scripts/request-detached-selfhost-cancellation.ps1"
$detachedVerificationContractPath = Join-Path $RepositoryRoot "scripts/verify-detached-selfhost-verification.ps1"
$detachedProgressPath = Join-Path $RepositoryRoot "scripts/read-detached-selfhost-progress.ps1"
$detachedResultSchemaPath = Join-Path $RepositoryRoot "scripts/contracts/detached-selfhost-verification-result.schema.json"
$profileSchemaContractPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-profile-schema.ps1"
$compilerEmissionProfileContractPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-compiler-emission-profile-schema.ps1"
$compilerEmissionBenchmarkPath = Join-Path $RepositoryRoot "scripts/run-selfhost-compiler-emission-benchmark.ps1"
$c85PerformanceControlPath = Join-Path $RepositoryRoot "scripts/build-c85-per-source-performance-control.ps1"
$c85ImplementationPairPath = Join-Path $RepositoryRoot "scripts/new-c85-implementation-performance-pair.ps1"
$c85ImplementationPairContractPath = Join-Path $RepositoryRoot "scripts/verify-c85-implementation-performance-pair.ps1"
$compilerEmissionFingerprintPath = Join-Path $RepositoryRoot "scripts/compiler-emission-fingerprint.ps1"
$compilerEmissionBenchmarkContractPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-compiler-emission-benchmark.ps1"
$bootstrapPerformancePairSchemaPath = Join-Path $RepositoryRoot "scripts/contracts/selfhost-bootstrap-performance-pair.schema.json"
$stage1GenerationSchemaPath = Join-Path $RepositoryRoot "scripts/contracts/selfhost-stage1-generation.schema.json"
$stage3SeedSchemaPath = Join-Path $RepositoryRoot "scripts/contracts/selfhost-stage3-seed.schema.json"
$stage3SeedProvenancePath = Join-Path $RepositoryRoot "scripts/stage3-seed-provenance.ps1"
$stage3SeedProvenanceContractPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage3-seed-provenance.ps1"
$artifactReceiptContractPath = Join-Path $RepositoryRoot "scripts/verify-stage2-artifact-receipt.ps1"
$artifactReceiptConcurrencyPath = Join-Path $RepositoryRoot "scripts/verify-stage2-artifact-receipt-concurrency.ps1"
$nativeExactReceiptContractPath = Join-Path $RepositoryRoot "scripts/verify-native-exact-fixture-receipt.ps1"
$timeApiContractPath = Join-Path $RepositoryRoot "scripts/verify-time-api-contract.ps1"
$browserTimeDomainContractPath = Join-Path $RepositoryRoot "scripts/verify-browser-time-domain-contract.ps1"
$stage3ArtifactVerifierPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage3-artifacts.ps1"
$stage3ArtifactContractPath = Join-Path $RepositoryRoot "scripts/verify-selfhost-stage3-artifact-contract.ps1"
$releaseOutputScopeContractPath = Join-Path $RepositoryRoot "scripts/verify-release-output-scope-contract.ps1"
$emitterManifestUpdaterPath = Join-Path $RepositoryRoot "scripts/update-llvm-emitter-fragment-manifests.ps1"
$unresolvedCallFixturePath = Join-Path $RepositoryRoot "examples/regression/1126-selfhost-console-emission-invariant.slg"
$lateSetFixturePath = Join-Path $RepositoryRoot "examples/regression/1128-selfhost-late-set-intrinsic-classification.slg"
$borrowedProjectedTextFixturePath = Join-Path $RepositoryRoot "examples/regression/1244-borrowed-projected-text-owner-move.slg"
$lateSetExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1128-selfhost-late-set-intrinsic-classification.stdout.txt"
$controlProducerFixturePath = Join-Path $RepositoryRoot "examples/regression/1129-selfhost-control-producer-call-shape.slg"
$controlProducerExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1129-selfhost-control-producer-call-shape.stdout.txt"
$logicalBindingFixturePath = Join-Path $RepositoryRoot "examples/regression/1130-four-term-logical-binding.slg"
$pathIntrinsicFixturePath = Join-Path $RepositoryRoot "examples/regression/677-selfhost-path-text-intrinsic-ir.slg"
$pathOrdinaryFixturePath = Join-Path $RepositoryRoot "examples/regression/1139-selfhost-path-name-not-intrinsic.slg"
$directoryIntrinsicFixturePath = Join-Path $RepositoryRoot "examples/regression/1140-selfhost-directory-intrinsic-ir.slg"
$enumNegativeFixturePath = Join-Path $RepositoryRoot "examples/regression/1143-enum-match-negative-unary-result.slg"
$enumNegativeSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1143-enum-match-negative-unary-result.selfhost.llvm.regex-counts.txt"
$mutableParameterFixturePath = Join-Path $RepositoryRoot "examples/regression/1147-mut-parameter-refresh-after-call.slg"
$mutableParameterSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1147-mut-parameter-refresh-after-call.selfhost.llvm.regex-counts.txt"
$mutableParameterSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1147-mut-parameter-refresh-after-call.selfhost.llvm.ordered-regex.txt"
$secondMutableParameterFixturePath = Join-Path $RepositoryRoot "examples/regression/1148-second-mut-parameter-refresh-after-call.slg"
$secondMutableParameterSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1148-second-mut-parameter-refresh-after-call.selfhost.llvm.regex-counts.txt"
$secondMutableParameterSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1148-second-mut-parameter-refresh-after-call.selfhost.llvm.ordered-regex.txt"
$controlRegionMutableParameterFixturePath = Join-Path $RepositoryRoot "examples/regression/1149-control-region-mut-parameter-refresh.slg"
$controlRegionMutableParameterSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1149-control-region-mut-parameter-refresh.selfhost.llvm.regex-counts.txt"
$controlRegionMutableParameterSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1149-control-region-mut-parameter-refresh.selfhost.llvm.ordered-regex.txt"
$whileRegionMutableParameterFixturePath = Join-Path $RepositoryRoot "examples/regression/1150-while-region-mut-parameter-refresh.slg"
$whileRegionMutableParameterSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1150-while-region-mut-parameter-refresh.selfhost.llvm.regex-counts.txt"
$whileRegionMutableParameterSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1150-while-region-mut-parameter-refresh.selfhost.llvm.ordered-regex.txt"
$mutableParameterMatrixFixturePath = Join-Path $RepositoryRoot "examples/regression/1151-mutable-parameter-indexing-matrix.slg"
$mutableParameterMatrixSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1151-mutable-parameter-indexing-matrix.selfhost.llvm.regex-counts.txt"
$mutableParameterMatrixSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1151-mutable-parameter-indexing-matrix.selfhost.llvm.ordered-regex.txt"
$earlyReturnCheckedIndexFixturePath = Join-Path $RepositoryRoot "examples/regression/1152-early-return-before-checked-index.slg"
$checkedIndexControlLogicalFixturePath = Join-Path $RepositoryRoot "examples/regression/1153-checked-index-control-before-logical-result.slg"
$callWrappedCheckedIndexFixturePath = Join-Path $RepositoryRoot "examples/regression/1157-call-wrapped-checked-index-after-early-return.slg"
$interpolationReferenceFixturePath = Join-Path $RepositoryRoot "examples/regression/1156-interpolation-readonly-struct-reference.slg"
$interpolationReferenceSelfhostCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1156-interpolation-readonly-struct-reference.selfhost.llvm.regex-counts.txt"
$interpolationReferenceSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1156-interpolation-readonly-struct-reference.selfhost.llvm.ordered-regex.txt"
$projectedReferenceFixturePath = Join-Path $RepositoryRoot "examples/regression/1158-member-array-indexed-member-reference.slg"
$projectedReferenceSelfhostOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1158-member-array-indexed-member-reference.selfhost.llvm.ordered-regex.txt"
$projectedReferenceSelfhostForbiddenPath = Join-Path $RepositoryRoot "examples/regression/expected/1158-member-array-indexed-member-reference.selfhost.llvm.not-contains.txt"
$receiverMetadataFixturePath = Join-Path $RepositoryRoot "examples/regression/1163-selfhost-method-receiver-metadata.slg"
$receiverInvariantFixturePath = Join-Path $RepositoryRoot "examples/regression/1165-selfhost-method-receiver-invariant.slg"
$aggregateChildIndexRulesFixturePath = Join-Path $RepositoryRoot "examples/regression/1395-selfhost-aggregate-child-index-rules.slg"
$controlAllocasMeasurementPath = Join-Path $RepositoryRoot "scripts/measure-selfhost-control-allocas.ps1"
$borrowedOwnedFixturePath = Join-Path $RepositoryRoot "examples/regression/1095-selfhost-checked-borrowed-owned-return.slg"
$ownedCallOriginFixturePath = Join-Path $RepositoryRoot "examples/regression/1281-selfhost-borrowed-receiver-fresh-owned-result.slg"
$borrowedFixedCopyFixturePath = Join-Path $RepositoryRoot "examples/regression/1554-borrowed-fixed-field-copy-independence.slg"
$moveMethodDropFixturePath = Join-Path $RepositoryRoot "examples/regression/1166-move-method-owned-field-drop.slg"
$projectedSocketCloseFixturePath = Join-Path $RepositoryRoot "examples/regression/1174-selfhost-projected-socket-close-intrinsic.slg"
$projectedSocketCloseExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1174-selfhost-projected-socket-close-intrinsic.stdout.txt"
$referenceStructReceiverFixturePath = Join-Path $RepositoryRoot "examples/regression/1175-ref-struct-receiver-inside-while.slg"
$referenceStructReceiverExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1175-ref-struct-receiver-inside-while.stdout.txt"
$referenceStructForwardingFixturePath = Join-Path $RepositoryRoot "examples/regression/1176-ref-struct-direct-call-forwarding.slg"
$referenceStructForwardingExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1176-ref-struct-direct-call-forwarding.stdout.txt"
$referenceStructAssignmentFixturePath = Join-Path $RepositoryRoot "examples/regression/1177-ref-struct-array-element-assignment.slg"
$referenceStructAssignmentExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1177-ref-struct-array-element-assignment.stdout.txt"
$callResultReceiverFixturePath = Join-Path $RepositoryRoot "examples/regression/1178-call-result-receiver-before-literal-fallback.slg"
$callResultReceiverExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1178-call-result-receiver-before-literal-fallback.stdout.txt"
$processStdioLinuxExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1179-process-stdio-file-instance.stdout.linux-x64.txt"
$nonProcessCollectFixturePath = Join-Path $RepositoryRoot "examples/regression/1184-non-process-collect-has-no-process-runtime.slg"
$projectedInterpolationCallFixturePath = Join-Path $RepositoryRoot "examples/regression/1185-selfhost-projected-receiver-instance-call.slg"
$projectedInterpolationCallCountsPath = Join-Path $RepositoryRoot "examples/regression/expected/1185-selfhost-projected-receiver-instance-call.selfhost.llvm.regex-counts.txt"
$projectedInterpolationCallOrderPath = Join-Path $RepositoryRoot "examples/regression/expected/1185-selfhost-projected-receiver-instance-call.selfhost.llvm.ordered-regex.txt"
$projectedInterpolationTopologyFixturePath = Join-Path $RepositoryRoot "examples/regression/1186-selfhost-interpolation-projected-call-topology.slg"
$projectedInterpolationTopologySourcesPath = Join-Path $RepositoryRoot "examples/regression/expected/1186-selfhost-interpolation-projected-call-topology.sources.txt"
$rawStringNoInterpolationFixturePath = Join-Path $RepositoryRoot "examples/regression/1187-selfhost-raw-string-no-interpolation.slg"
$postWhileMemberAssignmentFixturePath = Join-Path $RepositoryRoot "examples/regression/1189-selfhost-member-assignment-after-while.slg"
$controlStructArrayResultFixturePath = Join-Path $RepositoryRoot "examples/regression/1197-control-struct-array-result.slg"
$controlStructArrayResultExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1197-control-struct-array-result.stdout.txt"
$parallelTransferableStructFixturePath = Join-Path $RepositoryRoot "examples/regression/1198-parallel-transferable-struct-worker.slg"
$parallelTransferableStructExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1198-parallel-transferable-struct-worker.stdout.txt"
$localParallelCallbackFixturePath = Join-Path $RepositoryRoot "examples/regression/1199-local-function-parallel-callback.slg"
$localParallelCallbackExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1199-local-function-parallel-callback.stdout.txt"
$parallelNominalReadonlyCapturesFixturePath = Join-Path $RepositoryRoot "examples/regression/1200-parallel-nominal-readonly-captures.slg"
$parallelNominalReadonlyCapturesExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1200-parallel-nominal-readonly-captures.stdout.txt"
$ownershipCaptureFixturePath = Join-Path $RepositoryRoot "examples/regression/499-selfhost-transitive-nonsendable-parallel-capture.slg"
$ownershipCaptureExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/499-selfhost-transitive-nonsendable-parallel-capture.stdout.txt"
$parallelMoveParameterFixturePath = Join-Path $RepositoryRoot "examples/regression/1201-parallel-move-parameter.slg"
$parallelMoveParameterExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1201-parallel-move-parameter.stdout.txt"
$arrayElementOwnerReplacementFixturePath = Join-Path $RepositoryRoot "examples/regression/1202-array-element-owner-replacement-after-read.slg"
$arrayElementOwnerReplacementExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1202-array-element-owner-replacement-after-read.stdout.txt"
$enumPayloadBinaryBindingFixturePath = Join-Path $RepositoryRoot "examples/regression/1203-selfhost-enum-payload-binary-binding.slg"
$enumPayloadBinaryBindingPermutedFixturePath = Join-Path $RepositoryRoot "examples/regression/1204-selfhost-enum-payload-binary-binding-permuted.slg"
$mutableOwnedProjectionEnumFixturePath = Join-Path $RepositoryRoot "examples/regression/1280-mutable-owned-projection-enum-transfer.slg"
$flowAggregateOwnedProjectionDiagnosticPath = Join-Path $RepositoryRoot "examples/regression/diagnostics/flow-aggregate-owned-projection-borrow.stderr.contains.txt"
$runtimeSupportManifestPath = Join-Path $RepositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt"
$selfhostDriverPath = Join-Path $RepositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg"
$exampleRunnerPath = Join-Path $RepositoryRoot "tests/Sollang.ExampleTests/Program.cs"
$textEqualityFixturePath = Join-Path $RepositoryRoot "examples/regression/1327-selfhost-text-equality.slg"
$textOrderingDiagnosticPath = Join-Path $RepositoryRoot "examples/regression/diagnostics/1328-text-ordering-requires-explicit-api.stderr.contains.txt"
$valueFlowPrecedenceFixturePath = Join-Path $RepositoryRoot "examples/regression/1329-value-flow-logical-precedence.slg"
$singleValueFlowOwnerFixturePath = Join-Path $RepositoryRoot "examples/regression/1330-selfhost-single-value-flow-owner.slg"
$singleValueFlowOwnerExpectedPath = Join-Path $RepositoryRoot "examples/regression/expected/1330-selfhost-single-value-flow-owner.stdout.txt"
$generatedGrammarPath = Join-Path $RepositoryRoot "syntax/generated/sollang_grammar.slg"
$runtimePreamblePath = Join-Path $RepositoryRoot "selfhost/llvm/text/runtime_preamble.slg"

$analysis = [IO.File]::ReadAllText($analysisPath)
$calls = [IO.File]::ReadAllText($callsPath) + "`n" + [IO.File]::ReadAllText($callResolutionSourcesPath)
$ast = [IO.File]::ReadAllText($astPath)
$semanticContext = [IO.File]::ReadAllText($semanticContextPath)
$semanticResolve = [IO.File]::ReadAllText($semanticResolvePath)
$typeIds = [IO.File]::ReadAllText($typeIdsPath)
$ownershipCaptureFixture = [IO.File]::ReadAllText($ownershipCaptureFixturePath)
$ownershipCaptureExpected = [IO.File]::ReadAllText($ownershipCaptureExpectedPath)
$expressionTypes = [IO.File]::ReadAllText($expressionTypesPath)
$expressionTypeIds = [IO.File]::ReadAllText($expressionTypeIdsPath) + "`n" + [IO.File]::ReadAllText($expressionTypeIdsResolutionPhasesPath)
$expressionTypeIdsPaths = [IO.File]::ReadAllText($expressionTypeIdsPathsPath)
$lateArrayTypes = [IO.File]::ReadAllText($lateArrayTypesPath)
$lateArrayFixture = [IO.File]::ReadAllText($lateArrayFixturePath)
$logicalIrFixture = [IO.File]::ReadAllText($logicalIrFixturePath)
$directoryBinaryFixture = [IO.File]::ReadAllText($directoryBinaryFixturePath)
$terminalFlowControlReturnFixture = [IO.File]::ReadAllText($terminalFlowControlReturnFixturePath)
$typeCheck = [IO.File]::ReadAllText($typeCheckPath)
$typeClassificationStart = $typeIds.IndexOf("public classify ", [StringComparison]::Ordinal)
$typeClassificationEnd = $typeIds.IndexOf("# Resolves and globally interns", $typeClassificationStart, [StringComparison]::Ordinal)
if ($typeClassificationStart -lt 0 -or $typeClassificationEnd -le $typeClassificationStart) {
    throw "semantic type classification source boundary is missing"
}
$typeClassification = $typeIds.Substring($typeClassificationStart, $typeClassificationEnd - $typeClassificationStart)
$typed = [IO.File]::ReadAllText($typedPath)
$typedTypeQueries = [IO.File]::ReadAllText($typedTypeQueriesPath)
$typedFunctionLowering = [IO.File]::ReadAllText($typedFunctionLoweringPath)
$typedOrdinaryFunction = [IO.File]::ReadAllText($typedOrdinaryFunctionPath) + "`n" + [IO.File]::ReadAllText($typedOrdinaryFunctionExpressionsPath)
$typedOrdinaryFunctionFinalize = [IO.File]::ReadAllText($typedOrdinaryFunctionFinalizePath) + "`n" + [IO.File]::ReadAllText($typedOrdinaryFunctionFinalizePhasesPath)
$typedSourceLowering = [IO.File]::ReadAllText($typedSourceLoweringPath)
$typedSourceLoweringFinalize = [IO.File]::ReadAllText($typedSourceLoweringFinalizePath)
$typedResolvedContextNormalize = [IO.File]::ReadAllText($typedResolvedContextNormalizePath) + "`n" + [IO.File]::ReadAllText($typedResolvedContextNormalizePhasesPath)
$typedResolvedContextSeal = [IO.File]::ReadAllText($typedResolvedContextSealPath)
$nestedResultLogicalConditionFixture = [IO.File]::ReadAllText($nestedResultLogicalConditionFixturePath)
$typedResolvedContextFinalize = [IO.File]::ReadAllText($typedResolvedContextFinalizePath)
$selfhostDriver = [IO.File]::ReadAllText($selfhostDriverPath)
$typedCore = $typed + "`n" + $typedOrdinaryFunction + "`n" + $typedOrdinaryFunctionFinalize + "`n" + $typedSourceLowering + "`n" + $typedSourceLoweringFinalize + "`n" + $typedResolvedContextNormalize + "`n" + $typedResolvedContextSeal + "`n" + $typedResolvedContextFinalize
$typedValueAliases = [IO.File]::ReadAllText($typedValueAliasesPath)
$lateTypeSealingVerifier = [IO.File]::ReadAllText($lateTypeSealingVerifierPath)
$interpolationIr = [IO.File]::ReadAllText($interpolationIrPath)
$streamIr = [IO.File]::ReadAllText($streamIrPath)
$corePrepare = [IO.File]::ReadAllText($corePreparePath)
$text = [IO.File]::ReadAllText($textPath) + "`n" + [IO.File]::ReadAllText($entryExpressionsPath) + "`n" + $corePrepare
$entryExpressions = [IO.File]::ReadAllText($entryExpressionsPath)
$functionScheduling = [IO.File]::ReadAllText($functionSchedulingPath)
$foundation = [IO.File]::ReadAllText($foundationPath)
$coreCalls = [IO.File]::ReadAllText($coreCallsPath) + "`n" + [IO.File]::ReadAllText($callArgumentsPath) + "`n" + [IO.File]::ReadAllText($aggregateValuesPath)
$functionCalls = [IO.File]::ReadAllText($functionCallsPath)
$functionReturns = [IO.File]::ReadAllText($functionReturnsPath)
$controlRegions = [IO.File]::ReadAllText($controlRegionsPath) + "`n" + [IO.File]::ReadAllText($controlRegionExpressionsPath)
$functions = [IO.File]::ReadAllText($functionsPath) + "`n" + [IO.File]::ReadAllText($functionExpressionsPath) + "`n" + $functionCalls + "`n" + $functionReturns
$functionExpressions = [IO.File]::ReadAllText($functionExpressionsPath)
$control = [IO.File]::ReadAllText($controlPath) + "`n" + $controlRegions
$containers = [IO.File]::ReadAllText($containersPath) + "`n" + [IO.File]::ReadAllText($containerControlPath)
$memberSymbolCollisionFixture = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "examples/regression/1319-selfhost-member-symbol-collision-index.slg"))
$invariants = [IO.File]::ReadAllText($invariantsPath)
$invariantRules = [IO.File]::ReadAllText($invariantRulesPath)
$invariantDiagnostics = [IO.File]::ReadAllText($invariantDiagnosticsPath)
$emitterContext = [IO.File]::ReadAllText($emitterContextPath)
$emitterDiagnostics = [IO.File]::ReadAllText($emitterDiagnosticsPath)
$processRuntime = [IO.File]::ReadAllText($processRuntimePath)
$managedWindowsProcessRuntime = [IO.File]::ReadAllText($managedWindowsProcessRuntimePath)
$managedLinuxProcessRuntime = [IO.File]::ReadAllText($managedLinuxProcessRuntimePath)
$managedProcessEmitter = [IO.File]::ReadAllText($managedProcessEmitterPath)
$managedEmitter = [IO.File]::ReadAllText($managedEmitterPath)
$managedParallelEmitter = [IO.File]::ReadAllText($managedParallelEmitterPath)
$managedControlEmitter = [IO.File]::ReadAllText($managedControlEmitterPath)
$managedUtilitiesEmitter = [IO.File]::ReadAllText($managedUtilitiesEmitterPath)
$managedEnumEmitter = [IO.File]::ReadAllText($managedEnumEmitterPath)
$managedStructEmitter = [IO.File]::ReadAllText($managedStructEmitterPath)
$managedStatementsEmitter = [IO.File]::ReadAllText($managedStatementsEmitterPath)
$managedSocketEmitter = [IO.File]::ReadAllText($managedSocketEmitterPath)
$grammar = [IO.File]::ReadAllText($grammarPath)
$managedParserGenerator = [IO.File]::ReadAllText($managedParserGeneratorPath)
$managedSemanticCompiler = [IO.File]::ReadAllText($managedSemanticCompilerPath)
$textEqualityFixture = [IO.File]::ReadAllText($textEqualityFixturePath)
$textOrderingDiagnostic = [IO.File]::ReadAllText($textOrderingDiagnosticPath)
$valueFlowPrecedenceFixture = [IO.File]::ReadAllText($valueFlowPrecedenceFixturePath)
$singleValueFlowOwnerFixture = [IO.File]::ReadAllText($singleValueFlowOwnerFixturePath)
$singleValueFlowOwnerExpected = [IO.File]::ReadAllText($singleValueFlowOwnerExpectedPath)
$generatedGrammar = [IO.File]::ReadAllText($generatedGrammarPath)
$runtimePreamble = [IO.File]::ReadAllText($runtimePreamblePath)
$standardProcess = [IO.File]::ReadAllText($standardProcessPath)
$standardProcessRuntime = [IO.File]::ReadAllText($standardProcessRuntimePath)
$ownership = [IO.File]::ReadAllText($ownershipPath)
$semanticOwnership = [IO.File]::ReadAllText($semanticOwnershipPath)
$storedArrayReferenceDiagnostic = [IO.File]::ReadAllText($storedArrayReferenceDiagnosticPath)
$semanticParityDiagnostic = [IO.File]::ReadAllText($semanticParityDiagnosticPath)
$borrowedProjectedTextFixture = [IO.File]::ReadAllText($borrowedProjectedTextFixturePath)
$textOutputRuntime = [IO.File]::ReadAllText($textOutputRuntimePath)
$socketRuntime = [IO.File]::ReadAllText($socketRuntimePath)
$platformIo = [IO.File]::ReadAllText($platformIoPath)
$windowsSocketRuntime = [IO.File]::ReadAllText($windowsSocketRuntimePath)
$linuxSocketRuntime = [IO.File]::ReadAllText($linuxSocketRuntimePath)
$textContext = [IO.File]::ReadAllText($textContextPath)
$entrypoints = [IO.File]::ReadAllText($entrypointsPath)

Assert-Contains $coreCalls `
    "controlValueUsed nodeIndex: Int, ownerIndex: Int" `
    "self-host control-result fast gate"
Assert-Contains $coreCalls `
    "not (candidate.typeOrigin == 1 and candidate.typeSymbol == 0)" `
    "self-host Unit control-result fast gate"
Assert-Contains $coreCalls `
    "controlResultDiscardedByWhile nodeIndex: Int" `
    "self-host structural while-result fast gate"
Assert-Contains $coreCalls `
    "parent.kind == 20 and parent.operand1 == structuralValue!" `
    "self-host structural while-body result contract"
Assert-Contains $coreCalls `
    "nodeIndex -> irValueUsed(ownerIndex, context, state) => used!" `
    "self-host control-result precise fallback"
Assert-Matches $typedResolvedContextSeal `
    '(?s)chainedControlProducer\.nextOperand => chainedControlNext!.*?chainedControlProducer\.parent => chainedControlWrapper!.*?nodes\[chainedControlWrapper!\]\.kind == 9.*?nodes\[chainedControlWrapper!\]\.opcode == -1.*?chainedControlNext! => chainedControlConsumerIndex.*?chainedControlSubjectAncestor! == chainedControlSubjectRepairIndex!.*?chainedControlSubjectRepairIndex! => chainedControlConsumer!\.operand0' `
    "self-host chained control subject preserves the exact producer edge through transparent parent shells"
Assert-NotMatches ($foundation + "`n" + $control + "`n" + $functions) `
    '(?m)^\s*[A-Za-z0-9_!]+\s*->\s*irValueUsed\(' `
    "self-host LLVM control emission must route result-use checks through the Unit fast gate"
Assert-MatchCount ($text + "`n" + $functions) `
    'emitHoistedControlAllocas\([^\r\n]*, true, false, context, state\)' `
    2 `
    "self-host product control-allocation profiling disabled"
Assert-MatchCount $entrypoints `
    'emitHoistedControlAllocas\([^\r\n]*, true, true, context, emitterState\)' `
    1 `
    "self-host diagnostic control-allocation profiling enabled"

$enumNegativeFixture = [IO.File]::ReadAllText($enumNegativeFixturePath)
$enumNegativeSelfhostCounts = [IO.File]::ReadAllText($enumNegativeSelfhostCountsPath)
$mutableParameterFixture = [IO.File]::ReadAllText($mutableParameterFixturePath)
$mutableParameterSelfhostCounts = [IO.File]::ReadAllText($mutableParameterSelfhostCountsPath)
$mutableParameterSelfhostOrder = [IO.File]::ReadAllText($mutableParameterSelfhostOrderPath)
$secondMutableParameterFixture = [IO.File]::ReadAllText($secondMutableParameterFixturePath)
$secondMutableParameterSelfhostCounts = [IO.File]::ReadAllText($secondMutableParameterSelfhostCountsPath)
$secondMutableParameterSelfhostOrder = [IO.File]::ReadAllText($secondMutableParameterSelfhostOrderPath)
$controlRegionMutableParameterFixture = [IO.File]::ReadAllText($controlRegionMutableParameterFixturePath)
$controlRegionMutableParameterSelfhostCounts = [IO.File]::ReadAllText($controlRegionMutableParameterSelfhostCountsPath)
$controlRegionMutableParameterSelfhostOrder = [IO.File]::ReadAllText($controlRegionMutableParameterSelfhostOrderPath)
$whileRegionMutableParameterFixture = [IO.File]::ReadAllText($whileRegionMutableParameterFixturePath)
$whileRegionMutableParameterSelfhostCounts = [IO.File]::ReadAllText($whileRegionMutableParameterSelfhostCountsPath)
$whileRegionMutableParameterSelfhostOrder = [IO.File]::ReadAllText($whileRegionMutableParameterSelfhostOrderPath)
$mutableParameterMatrixFixture = [IO.File]::ReadAllText($mutableParameterMatrixFixturePath)
$mutableParameterMatrixSelfhostCounts = [IO.File]::ReadAllText($mutableParameterMatrixSelfhostCountsPath)
$mutableParameterMatrixSelfhostOrder = [IO.File]::ReadAllText($mutableParameterMatrixSelfhostOrderPath)
$earlyReturnCheckedIndexFixture = [IO.File]::ReadAllText($earlyReturnCheckedIndexFixturePath)
$checkedIndexControlLogicalFixture = [IO.File]::ReadAllText($checkedIndexControlLogicalFixturePath)
$callWrappedCheckedIndexFixture = [IO.File]::ReadAllText($callWrappedCheckedIndexFixturePath)
$interpolationReferenceFixture = [IO.File]::ReadAllText($interpolationReferenceFixturePath)
$projectedReferenceFixture = [IO.File]::ReadAllText($projectedReferenceFixturePath)
$projectedReferenceSelfhostOrder = [IO.File]::ReadAllText($projectedReferenceSelfhostOrderPath)
$projectedReferenceSelfhostForbidden = [IO.File]::ReadAllText($projectedReferenceSelfhostForbiddenPath)
$projectedSocketCloseFixture = [IO.File]::ReadAllText($projectedSocketCloseFixturePath)
$projectedSocketCloseExpected = [IO.File]::ReadAllText($projectedSocketCloseExpectedPath)
$referenceStructReceiverFixture = [IO.File]::ReadAllText($referenceStructReceiverFixturePath)
$referenceStructReceiverExpected = [IO.File]::ReadAllText($referenceStructReceiverExpectedPath)
$referenceStructForwardingFixture = [IO.File]::ReadAllText($referenceStructForwardingFixturePath)
$referenceStructForwardingExpected = [IO.File]::ReadAllText($referenceStructForwardingExpectedPath)
$referenceStructAssignmentFixture = [IO.File]::ReadAllText($referenceStructAssignmentFixturePath)
$referenceStructAssignmentExpected = [IO.File]::ReadAllText($referenceStructAssignmentExpectedPath)
$callResultReceiverFixture = [IO.File]::ReadAllText($callResultReceiverFixturePath)
$callResultReceiverExpected = [IO.File]::ReadAllText($callResultReceiverExpectedPath)
$processStdioLinuxExpected = [IO.File]::ReadAllText($processStdioLinuxExpectedPath)
$projectedInterpolationCallFixture = [IO.File]::ReadAllText($projectedInterpolationCallFixturePath)
$nonProcessCollectFixture = [IO.File]::ReadAllText($nonProcessCollectFixturePath)
$projectedInterpolationCallCounts = [IO.File]::ReadAllText($projectedInterpolationCallCountsPath)
$projectedInterpolationCallOrder = [IO.File]::ReadAllText($projectedInterpolationCallOrderPath)
$projectedInterpolationTopologyFixture = [IO.File]::ReadAllText($projectedInterpolationTopologyFixturePath)
$projectedInterpolationTopologySources = @([IO.File]::ReadAllLines($projectedInterpolationTopologySourcesPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$postWhileMemberAssignmentFixture = [IO.File]::ReadAllText($postWhileMemberAssignmentFixturePath)
$controlStructArrayResultFixture = [IO.File]::ReadAllText($controlStructArrayResultFixturePath)
$controlStructArrayResultExpected = [IO.File]::ReadAllText($controlStructArrayResultExpectedPath)
$parallelTransferableStructFixture = [IO.File]::ReadAllText($parallelTransferableStructFixturePath)
$parallelTransferableStructExpected = [IO.File]::ReadAllText($parallelTransferableStructExpectedPath)
$localParallelCallbackFixture = [IO.File]::ReadAllText($localParallelCallbackFixturePath)
$localParallelCallbackExpected = [IO.File]::ReadAllText($localParallelCallbackExpectedPath)
$parallelNominalReadonlyCapturesFixture = [IO.File]::ReadAllText($parallelNominalReadonlyCapturesFixturePath)
$parallelNominalReadonlyCapturesExpected = [IO.File]::ReadAllText($parallelNominalReadonlyCapturesExpectedPath)
$parallelMoveParameterFixture = [IO.File]::ReadAllText($parallelMoveParameterFixturePath)
$parallelMoveParameterExpected = [IO.File]::ReadAllText($parallelMoveParameterExpectedPath)
$arrayElementOwnerReplacementFixture = [IO.File]::ReadAllText($arrayElementOwnerReplacementFixturePath)
$arrayElementOwnerReplacementExpected = [IO.File]::ReadAllText($arrayElementOwnerReplacementExpectedPath)
$enumPayloadBinaryBindingFixture = [IO.File]::ReadAllText($enumPayloadBinaryBindingFixturePath)
$enumPayloadBinaryBindingPermutedFixture = [IO.File]::ReadAllText($enumPayloadBinaryBindingPermutedFixturePath)
$mutableOwnedProjectionEnumFixture = [IO.File]::ReadAllText($mutableOwnedProjectionEnumFixturePath)
$flowAggregateOwnedProjectionDiagnostic = [IO.File]::ReadAllText($flowAggregateOwnedProjectionDiagnosticPath)
$receiverMetadataFixture = [IO.File]::ReadAllText($receiverMetadataFixturePath)
$receiverInvariantFixture = [IO.File]::ReadAllText($receiverInvariantFixturePath)
$aggregateChildIndexRulesFixture = [IO.File]::ReadAllText($aggregateChildIndexRulesFixturePath)
$controlAllocasMeasurement = [IO.File]::ReadAllText($controlAllocasMeasurementPath)
$interpolationReferenceSelfhostCounts = [IO.File]::ReadAllText($interpolationReferenceSelfhostCountsPath)
$interpolationReferenceSelfhostOrder = [IO.File]::ReadAllText($interpolationReferenceSelfhostOrderPath)
$incrementalVerifier = [IO.File]::ReadAllText($incrementalVerifierPath)
$stage2Verifier = [IO.File]::ReadAllText($stage2VerifierPath)
$stage3Verifier = [IO.File]::ReadAllText($stage3VerifierPath)
$privateFieldDiagnosticVerifier = [IO.File]::ReadAllText($privateFieldDiagnosticVerifierPath)
$releasePublisher = [IO.File]::ReadAllText($releasePublisherPath)
$nativeReleasePackage = [IO.File]::ReadAllText($nativeReleasePackagePath)
$nativeReleasePackageContract = [IO.File]::ReadAllText($nativeReleasePackageContractPath)
$browserStage2 = [IO.File]::ReadAllText($browserStage2Path)
$browserStage2Fingerprint = [IO.File]::ReadAllText($browserStage2FingerprintPath)
$browserStage2ArtifactVerifier = [IO.File]::ReadAllText($browserStage2ArtifactVerifierPath)
$browserStage2Runner = [IO.File]::ReadAllText($browserStage2RunnerPath)
$browserProgramRunner = [IO.File]::ReadAllText($browserProgramRunnerPath)
$linuxStage2 = [IO.File]::ReadAllText($linuxStage2Path)
$linuxStage3 = [IO.File]::ReadAllText($linuxStage3Path)
$directCallClosure = [IO.File]::ReadAllText($directCallClosurePath)
$nativeBinaryVerifier = [IO.File]::ReadAllText($nativeBinaryVerifierPath)
$nativeSetVerifier = [IO.File]::ReadAllText($nativeSetVerifierPath)
$nativeSourceStyleVerifier = [IO.File]::ReadAllText($nativeSourceStyleVerifierPath)
$nativeFormatVerifier = [IO.File]::ReadAllText($nativeFormatVerifierPath)
$ownedBlockVerifier = [IO.File]::ReadAllText($ownedBlockVerifierPath)
$unresolvedCallDiagnosticVerifier = [IO.File]::ReadAllText($unresolvedCallDiagnosticVerifierPath)
$resultPropagationDiagnosticVerifier = [IO.File]::ReadAllText($resultPropagationDiagnosticVerifierPath)
$traitOwnershipDiagnosticVerifier = [IO.File]::ReadAllText($traitOwnershipDiagnosticVerifierPath)
$traitOwnershipDiagnosticContract = [IO.File]::ReadAllText($traitOwnershipDiagnosticContractPath)
$nativeProcessVerifier = [IO.File]::ReadAllText($nativeProcessVerifierPath)
$nativeQuicEndpointOwnershipVerifier = [IO.File]::ReadAllText($nativeQuicEndpointOwnershipVerifierPath)
$nativeQuicEndpointOwnershipLinuxVerifier = [IO.File]::ReadAllText($nativeQuicEndpointOwnershipLinuxVerifierPath)
$nativeSocketTimeoutVerifier = [IO.File]::ReadAllText($nativeSocketTimeoutVerifierPath)
$nativeMutableParameterVerifier = [IO.File]::ReadAllText($nativeMutableParameterVerifierPath)
$nativeMutableParameterBatchVerifier = [IO.File]::ReadAllText($nativeMutableParameterBatchVerifierPath)
$nativeExactFixtureVerifier = [IO.File]::ReadAllText($nativeExactFixtureVerifierPath)
$nativeExactFixtureBatchVerifier = [IO.File]::ReadAllText($nativeExactFixtureBatchVerifierPath)
$nativeExactBatchProfiler = [IO.File]::ReadAllText($nativeExactBatchProfilerPath)
$nativeExactBatchProfileSummary = [IO.File]::ReadAllText($nativeExactBatchProfileSummaryPath)
$nativeExactBatchProfileSchema = [IO.File]::ReadAllText($nativeExactBatchProfileSchemaPath)
$nativeExactBatchProfileContract = [IO.File]::ReadAllText($nativeExactBatchProfileContractPath)
$parallelCallbackLlvmVerifier = [IO.File]::ReadAllText($parallelCallbackLlvmVerifierPath)
$parallelCallbackCacheVerifier = [IO.File]::ReadAllText($parallelCallbackCacheVerifierPath)
$nativeInterpolationReferenceVerifier = [IO.File]::ReadAllText($nativeInterpolationReferenceVerifierPath)
$nativeProjectedReferenceVerifier = [IO.File]::ReadAllText($nativeProjectedReferenceVerifierPath)
$nativeLanguageServerVerifier = [IO.File]::ReadAllText($nativeLanguageServerVerifierPath)
$linuxProcessVerifier = [IO.File]::ReadAllText($linuxProcessVerifierPath)
$processDropVerifier = [IO.File]::ReadAllText($processDropVerifierPath)
$processDropContract = [IO.File]::ReadAllText($processDropContractPath)
$verificationProcess = [IO.File]::ReadAllText($verificationProcessPath)
$verificationProcessExitRace = [IO.File]::ReadAllText($verificationProcessExitRacePath)
$emitContextClosureVerifier = [IO.File]::ReadAllText($emitContextClosureVerifierPath)
$emitContextClosureContract = [IO.File]::ReadAllText($emitContextClosureContractPath)
$detachedVerification = [IO.File]::ReadAllText($detachedVerificationPath)
$detachedCancellation = [IO.File]::ReadAllText($detachedCancellationPath)
$detachedVerificationContract = [IO.File]::ReadAllText($detachedVerificationContractPath)
$detachedProgress = [IO.File]::ReadAllText($detachedProgressPath)
$detachedResultSchema = [IO.File]::ReadAllText($detachedResultSchemaPath)
$verificationProcessContract = [IO.File]::ReadAllText($verificationProcessContractPath)
$compilerEmissionBenchmark = [IO.File]::ReadAllText($compilerEmissionBenchmarkPath)
$c85PerformanceControl = [IO.File]::ReadAllText($c85PerformanceControlPath)
$c85ImplementationPair = [IO.File]::ReadAllText($c85ImplementationPairPath)
$compilerEmissionFingerprint = [IO.File]::ReadAllText($compilerEmissionFingerprintPath)
$bootstrapPerformancePairSchema = [IO.File]::ReadAllText($bootstrapPerformancePairSchemaPath)
$stage1GenerationSchema = [IO.File]::ReadAllText($stage1GenerationSchemaPath)
$stage3SeedSchema = [IO.File]::ReadAllText($stage3SeedSchemaPath)
$stage3SeedProvenance = [IO.File]::ReadAllText($stage3SeedProvenancePath)
$stage3SeedProvenanceContract = [IO.File]::ReadAllText($stage3SeedProvenanceContractPath)
$emitterManifestUpdater = [IO.File]::ReadAllText($emitterManifestUpdaterPath)
$stage3ArtifactVerifier = [IO.File]::ReadAllText($stage3ArtifactVerifierPath)
$unresolvedCallFixture = [IO.File]::ReadAllText($unresolvedCallFixturePath)
$lateSetFixture = [IO.File]::ReadAllText($lateSetFixturePath)
$lateSetExpected = [IO.File]::ReadAllText($lateSetExpectedPath)
$controlProducerFixture = [IO.File]::ReadAllText($controlProducerFixturePath)
$controlProducerExpected = [IO.File]::ReadAllText($controlProducerExpectedPath)
$logicalBindingFixture = [IO.File]::ReadAllText($logicalBindingFixturePath)
$pathIntrinsicFixture = [IO.File]::ReadAllText($pathIntrinsicFixturePath)
$pathOrdinaryFixture = [IO.File]::ReadAllText($pathOrdinaryFixturePath)
$directoryIntrinsicFixture = [IO.File]::ReadAllText($directoryIntrinsicFixturePath)
$borrowedOwnedFixture = [IO.File]::ReadAllText($borrowedOwnedFixturePath)
$ownedCallOriginFixture = [IO.File]::ReadAllText($ownedCallOriginFixturePath)
$borrowedFixedCopyFixture = [IO.File]::ReadAllText($borrowedFixedCopyFixturePath)
$moveMethodDropFixture = [IO.File]::ReadAllText($moveMethodDropFixturePath)
$rawStringNoInterpolationFixture = [IO.File]::ReadAllText($rawStringNoInterpolationFixturePath)
$exampleRunner = [IO.File]::ReadAllText($exampleRunnerPath)

Assert-Contains $analysis "public analyzeSourcesParallel" "native source-analysis entrypoint"
Assert-Contains $functions "returnValueIndex -> returnedValueTransferredBindingRoots" "returned owned aggregate root resolution"
Assert-Contains $functions "returnedOwnedSource.symbol == ownedParameter.symbol" "returned move-parameter alias cleanup suppression"
Assert-Contains $emitterManifestUpdater '[ValidateSet("Inventory", "Check", "Write", "RefreshCounts")]' "selfhost fragment manifest updater modes"
Assert-Contains $emitterManifestUpdater 'contracts/selfhost-fragments.json' "selfhost fragment manifest inventory authority"
Assert-Contains $emitterManifestUpdater 'ExpectedManifests = [int]$_.expectedManifests' "per-fragment manifest count authority"
Assert-Contains $emitterManifestUpdater 'if ($actual -ne $insertion.ExpectedManifests -and $Mode -ne "RefreshCounts")' "per-fragment manifest count gate"
Assert-NotContains $emitterManifestUpdater 'selfhost/llvm/text/call_arguments.slg' "hardcoded call-lowering fragment insertion"
Assert-NotContains $emitterManifestUpdater 'selfhost/llvm/text/container_control.slg' "hardcoded container-control fragment insertion"
Assert-Contains $emitterManifestUpdater 'manifest updater idempotence control' "manifest updater idempotence control"
Assert-Contains $emitterManifestUpdater 'duplicate owner control' "manifest duplicate-owner negative control"
Assert-Contains $emitterManifestUpdater 'duplicate fragment control' "manifest duplicate-fragment negative control"
Assert-Contains $emitterManifestUpdater 'orphan fragment control' "manifest orphan-fragment negative control"
Assert-Contains $analysis "sources -> parallel sourceText" "owned source-analysis worker boundary"
Assert-Contains $analysis "sources -> assembleSelectedSources(sourceAnalyses" "deterministic package assembly"
Assert-Contains $semanticContext "public prepareParallel" "native semantic preparation"
Assert-Contains $semanticContext "analysis.analyzeSourcesParallel" "native semantic worker routing"
Assert-Contains $textContext "semanticContext.prepareParallel" "native LLVM preparation"
Assert-Contains $typedCore "public lowerResolvedContext prepared:" "resolved recursive-type Typed IR boundary"
Assert-Contains $typedCore "public lowerResolvedContextParallel prepared:" "native parallel Typed IR boundary"
Assert-Contains $typedCore "recursiveTypes: ref expressionTypeIds.ExpressionTypeIdSet" "borrowed recursive-type Typed IR boundary"
Assert-Contains $typedCore 'useParallel -> if {' "explicit native/browser function-lowering mode"
Assert-Contains $typedCore 'lowerFunctionRequests functionRequests: [FunctionLowerRequest; ~], useParallel: Bool' "borrowed source-local function request input"
Assert-NotContains $typedCore 'lowerFunctionRequests functionRequests: move [FunctionLowerRequest; ~]' "unnecessary source-local function request ownership transfer"
Assert-MatchCount $typedCore 'functionRequests -> parallel functionRequest' 1 "single native Typed IR function-lowering worker boundary"
Assert-MatchCount $typedCore 'requestIndex! < \(functionRequests -> len\)' 1 "browser Typed IR sequential fallback"
Assert-MatchCount $typedCore 'functionRequest -> lowerFunctionRequest' 1 "native direct function-lowering callback"
Assert-Contains $typed 'profileStopAfter == 0 -> if { results! -> return }' "Typed IR source-lowering profile boundary"
Assert-Contains $typed 'profileStopAfter == -1 -> if { results! -> return }' "Typed IR shared-index profile boundary"
Assert-Contains $typed 'profileStopAfter == 1 -> if { results! -> return }' "Typed IR normalization profile boundary"
Assert-Contains $typed 'profileStopAfter == 2 -> if { results! -> return }' "Typed IR sealing profile boundary"
Assert-Contains $typed 'public profileResolvedContext prepared:' "diagnostic-only Typed IR phase profiler"
Assert-Contains $typed 'public profileResolvedContextPrefix prepared:' "diagnostic-only Typed IR source-prefix profiler"
Assert-Contains $typed 'public profileResolvedContextFunctionPrefix prepared:' "diagnostic-only Typed IR function-prefix profiler"
Assert-Contains $typedOrdinaryFunction 'frozenFunctionNodeIndices[patternNodePosition!] => patternSearch' "function-local enum pattern child index"
Assert-Contains $typedOrdinaryFunction 'frozenFunctionNodeIndices[indexedMemberBasePosition!] => indexedMemberBaseSearch' "function-local member child index"
Assert-Contains $typedOrdinaryFunction 'frozenFunctionNodeIndices[patternSubjectPosition!] => patternSubjectSearch' "function-local enum pattern subject index"
Assert-Contains $typedOrdinaryFunction 'frozenFunctionNodeIndices[intrinsicChildPosition!] => intrinsicChildSearch' "function-local intrinsic child index"
Assert-Contains $typedOrdinaryFunction 'resolvedSymbolByAst[expressionAstIndex] => expressionSymbol!' "direct resolved-name symbol index"
Assert-Contains $semanticContext 'qualifiedFunctionByParentAst: [Int; ~]' "semantic snapshot qualified-function parent index"
Assert-Contains $semanticContext 'public indexQualifiedFunctionsByParentAst package: ref analysis.PackageAnalysis' "single qualified-function parent index builder"
Assert-MatchCount ($semanticContext + "`n" + $typed + "`n" + $expressionTypeIds + "`n" + $expressionTypes) 'qualifiedFunctionByParentAst: qualifiedFunctionByParentAst' 4 "all semantic snapshot constructors initialize qualified-function parent index"
Assert-MatchCount $typedCore 'prepared\.qualifiedFunctionByParentAst\[' 6 "ordinary, entry, and finalization lowering share qualified-function parent index"
Assert-NotContains $typedOrdinaryFunction 'qualifiedFunctionIndexByParentAst!' "duplicate function-local qualified-function parent index"
Assert-NotContains $typedSourceLowering 'directQualifiedEntryCallSearch!' "entry per-expression qualified-function rescan"
Assert-NotContains $typedOrdinaryFunctionFinalize 'operatorQualifiedSearch!' "function finalization per-expression qualified-function rescan"
Assert-NotContains $typedSourceLoweringFinalize 'entryOperatorQualifiedSearch!' "entry finalization per-expression qualified-function rescan"
Assert-NotContains $typedOrdinaryFunction 'patternSearch! < sourceRange.astCount' "per-match complete-source pattern rescan"
Assert-NotContains $typedOrdinaryFunction 'indexedMemberBaseSearch! < sourceRange.astCount' "per-member complete-source child rescan"
Assert-NotContains $typedOrdinaryFunction 'patternSubjectSearch! < sourceRange.astCount' "per-pattern complete-source subject rescan"
Assert-NotContains $typedOrdinaryFunction 'intrinsicChildSearch! < sourceRange.astCount' "per-call complete-source intrinsic child rescan"
Assert-NotContains $typedOrdinaryFunction 'nameResolutionSearch! < (resolvedNames! -> len)' "per-name complete resolved-name rescan"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-index")' "Typed IR shared-index profile command"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-lower")' "Typed IR source-lowering profile command"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-prefix")' "Typed IR source-prefix profile command"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-function-prefix")' "Typed IR function-prefix profile command"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-normalize")' "Typed IR normalization profile command"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-normalize-candidates")' "Typed IR normalization candidate-count command"
Assert-Contains $selfhostDriver 'command -> textEquals("typed-ir-seal")' "Typed IR sealing profile command"
Assert-Contains $selfhostDriver 'command -> textEquals("diagnostic-counts")' "checked diagnostic count profile command"
Assert-Contains $selfhostDriver 'ownership diagnostic code $(diagnostic.code)' "ownership diagnostic type identity telemetry"
Assert-Contains $selfhostDriver 'command -> textEquals("qualified-resolutions")' "qualified resolution structural diagnostic command"
Assert-Contains $selfhostDriver 'command -> textEquals("symbols")' "source-local symbol structural diagnostic command"
Assert-Contains $incrementalVerifier '-Arguments (@("typed-ir-lower") + $fixturePaths)' "expanded-source Typed IR source-lowering profile"
Assert-Contains $incrementalVerifier '-Arguments (@("typed-ir-index") + $fixturePaths)' "expanded-source Typed IR shared-index profile"
Assert-Contains $incrementalVerifier '-Arguments (@("typed-ir-prefix", [string]$ProfileSourcePrefix) + $fixturePaths)' "expanded-source Typed IR source-prefix profile"
Assert-Contains $incrementalVerifier '-Arguments (@("typed-ir-function-prefix", [string]$ProfileSourcePrefix, [string]$ProfileFunctionPrefix) + $fixturePaths)' "expanded-source Typed IR function-prefix profile"
Assert-Contains $incrementalVerifier '-Arguments (@("typed-ir-normalize") + $fixturePaths)' "expanded-source Typed IR normalization profile"
Assert-Contains $incrementalVerifier '-Arguments (@("typed-ir-seal") + $fixturePaths)' "expanded-source Typed IR sealing profile"
Assert-MatchCount $typedCore 'functionRequests\[requestIndex!\] -> lowerFunctionRequest' 1 "browser direct sequential function lowering"
Assert-MatchCount $typedCore 'sourceFunctionRequests! -> lowerFunctionRequests\(parallelFunctions, profileFunctionLimit, prepared' 1 "one source-local function-lowering dispatch site"
Assert-MatchCount $typedCore 'results! -> appendAndReleaseFunctionResults\(sourceFunctionResults!\)' 1 "prompt source-local function-result merge"
Assert-NotContains $typedCore 'globalFunctionRequests!' "rejected compiler-wide function request lifetime"
Assert-NotContains $typedCore 'appendAndReleaseFunctionResultRange' "rejected long-lived compiler-wide result ranges"
$sourceLoweringDeclarationOffset = $typedSourceLowering.IndexOf('lowerSource requestedSourceIndex: Int, parallelFunctions: Bool', [StringComparison]::Ordinal)
$sourceRequestCollectionOffset = $typedSourceLowering.IndexOf('[FunctionLowerRequest; ~] => sourceFunctionRequests!', $sourceLoweringDeclarationOffset, [StringComparison]::Ordinal)
$sourceFunctionDispatchOffset = $typedSourceLowering.IndexOf('sourceFunctionRequests! -> lowerFunctionRequests(parallelFunctions, profileFunctionLimit, prepared', $sourceRequestCollectionOffset, [StringComparison]::Ordinal)
$sourceFunctionMergeOffset = $typedSourceLowering.IndexOf('results! -> appendAndReleaseFunctionResults(sourceFunctionResults!)', $sourceFunctionDispatchOffset, [StringComparison]::Ordinal)
$orderedSourceAssemblyOffset = $typed.IndexOf('0 => sourceLowerIndex!', [StringComparison]::Ordinal)
if ($sourceLoweringDeclarationOffset -lt 0 -or
    $sourceRequestCollectionOffset -le $sourceLoweringDeclarationOffset -or
    $sourceFunctionDispatchOffset -le $sourceRequestCollectionOffset -or
    $sourceFunctionMergeOffset -le $sourceFunctionDispatchOffset -or
    $orderedSourceAssemblyOffset -lt 0) {
    throw 'function lowering must collect, dispatch, merge, and release each source-local request batch before assembling the next source'
}
Assert-Contains $typedFunctionLowering 'appendFunctionResult results: mut [TypedIrNode; ~], functionResult: ref SourceTypedIr -> Unit' "readonly deterministic function-result merge helper"
Assert-Contains $typedFunctionLowering 'appendAndReleaseFunctionResults results: mut [TypedIrNode; ~], functionResults: mut [SourceTypedIr; ~] -> Unit' "prompt-release ordered source-local function-result merge"
Assert-MatchCount $typedFunctionLowering 'SourceTypedIr \{ nodes: \[TypedIrNode; ~\] \} => functionResults\[[^\]]+\]' 1 "prompt function-result owner replacement after readonly merge"
Assert-NotContains $typedFunctionLowering 'functionResults -> take(' "quadratic affine function-result extraction"
Assert-Contains $typedOrdinaryFunction 'frozenRecursiveTypeByAst[parameterReferenceGlobalAst] => parameterTypeId!' "O(1) ordinary parameter canonical type lookup"
Assert-NotContains $typedOrdinaryFunction 'parameterExactSearch!' "quadratic per-parameter recursive expression scan"
Assert-Contains $semanticContext 'callIndexByAst: [Int; ~]' "semantic snapshot exact-call index"
Assert-Contains $semanticContext 'public indexCallsByAst package: ref analysis.PackageAnalysis, resolvedCalls: ref [calls.ModuleCallResolution; ~] -> [Int; ~]' "single exact-call index builder"
Assert-MatchCount ($typedOrdinaryFunction + "`n" + $typedSourceLowering) 'prepared\.callIndexByAst\[' 11 "O(1) Typed IR exact-call lookups"
Assert-Contains $semanticContext 'callResultMemberByAst: [Bool; ~]' "semantic snapshot resolved-call-result member ancestry index"
Assert-Contains $semanticContext 'public indexCallResultMembersByAst package: ref analysis.PackageAnalysis, resolvedCalls: ref [calls.ModuleCallResolution; ~] -> [Bool; ~]' "single resolved-call-result member index builder"
Assert-Contains $semanticContext 'pathNode.kind == 36 and pathNode.start == callNode.start' "same-start qualified path ancestry proof"
Assert-Contains $semanticContext 'package.tokens[sourceRange.tokenStart + pathNode.payloadToken].span.start >= callNode.start + callNode.length' "resolved call member token must trail the complete callee"
Assert-Contains $semanticContext 'callNode.start + callNode.length < pathNode.start + pathNode.length' "resolved call requires real trailing field suffix"
Assert-MatchCount ($typedOrdinaryFunction + "`n" + $typedSourceLowering) 'prepared\.callResultMemberByAst\[' 2 "entry and ordinary lowering share call-result member index"
Assert-Contains $typedOrdinaryFunction 'knownCallResultMemberExpression!' "ordinary resolved-call-result field projection preservation"
Assert-Contains $typedSourceLowering 'knownEntryCallResultMemberExpression!' "entry resolved-call-result field projection preservation"
Assert-Contains $typedOrdinaryFunction 'prepared.callResultMemberByAst[sourceRange.astStart + expressionAstIndex]' "ordinary indexed call-result member lookup"
Assert-Contains $typedSourceLowering 'prepared.callResultMemberByAst[sourceRange.astStart + entryExpressionAst!]' "entry indexed call-result member lookup"
Assert-Contains $typedOrdinaryFunction 'and not memberPathIsResolvedCallee!' "ordinary method callee excluded from indexed field projection"
Assert-Contains $typedOrdinaryFunction 'or prepared.qualifiedFunctionByParentAst[sourceRange.astStart + expressionAstIndex] >= 0' "ordinary qualified callee wrapper uses its exact indexed path owner"
Assert-Contains $typedSourceLowering 'prepared.qualifiedFunctionByParentAst[sourceRange.astStart + entryExpressionAst!] >= 0' "entry qualified callee wrapper uses its exact indexed path owner"
Assert-MatchCount ($typedOrdinaryFunction + "`n" + $typedSourceLowering) 'qualified(?:Entry)?FunctionCallChild\.start == (?:entryExpression|expression)\.start' 2 "qualified callee transparency requires same-span call descendant"
Assert-Contains $typedSourceLowering 'and not entryMemberPathIsResolvedCallee!' "entry method callee excluded from indexed field projection"
Assert-Contains $typedOrdinaryFunctionFinalize 'nodes[lastRegionChild!].kind == 26' "ordinary contextual enum region wrapper detection"
Assert-Contains $typedOrdinaryFunctionFinalize 'contextualEnumChild.parent == lastRegionChild!' "ordinary contextual enum direct-child proof"
Assert-Contains $typedOrdinaryFunctionFinalize 'contextualEnumChild.typeOrigin == contextualEnumWrapper.typeOrigin' "ordinary contextual enum exact origin proof"
Assert-Contains $typedOrdinaryFunctionFinalize 'contextualEnumChild.typeModule == contextualEnumWrapper.typeModule' "ordinary contextual enum exact module proof"
Assert-Contains $typedOrdinaryFunctionFinalize 'contextualEnumChild.typeSymbol == contextualEnumWrapper.typeSymbol' "ordinary contextual enum exact symbol proof"
Assert-Contains $typedSourceLoweringFinalize 'nodes[entryLastRegionChild!].kind == 26' "entry contextual enum region wrapper detection"
Assert-Contains $typedSourceLoweringFinalize 'entryContextualEnumChild.parent == entryLastRegionChild!' "entry contextual enum direct-child proof"
Assert-Contains $typedSourceLoweringFinalize 'entryContextualEnumChild.typeOrigin == entryContextualEnumWrapper.typeOrigin' "entry contextual enum exact origin proof"
Assert-Contains $typedSourceLoweringFinalize 'entryContextualEnumChild.typeModule == entryContextualEnumWrapper.typeModule' "entry contextual enum exact module proof"
Assert-Contains $typedSourceLoweringFinalize 'entryContextualEnumChild.typeSymbol == entryContextualEnumWrapper.typeSymbol' "entry contextual enum exact symbol proof"
Assert-NotContains $typedOrdinaryFunction 'indexedMemberBase.kind == 11' "ordinary per-expression call-result rescan"
Assert-NotContains $typedSourceLowering 'entryIndexedMemberBase.kind == 11' "entry per-expression call-result rescan"
Assert-Contains $typedOrdinaryFunction '(not resolvedQualifiedLeaf! or knownCallResultMemberExpression!' "ordinary exact call-result member overrides qualified-leaf suppression"
Assert-Contains $typedSourceLowering '(not resolvedEntryQualifiedLeaf! or knownEntryCallResultMemberExpression!' "entry exact call-result member overrides qualified-leaf suppression"
Assert-Matches $typedOrdinaryFunction 'qualifiedFunctionPath and not knownCallResultMemberExpression!\s*-> if' "ordinary call-result field excluded from qualified-function transparency"
Assert-Matches $typedSourceLowering 'qualifiedEntryFunctionPath! and not knownEntryCallResultMemberExpression!\s*-> if' "entry call-result field excluded from qualified-function transparency"
Assert-NotContains $typedOrdinaryFunction 'knownCallSearch!' "quadratic ordinary exact-call scan"
Assert-NotContains $typedOrdinaryFunction 'propertyCallSearch!' "quadratic ordinary property-call scan"
Assert-NotContains $typedOrdinaryFunction 'qualifiedFunctionParentCallSearch!' "quadratic ordinary parent-call scan"
Assert-NotContains $typedOrdinaryFunction 'callSearch!' "quadratic ordinary final-call scan"
Assert-NotContains $typedSourceLowering 'knownEntryCallSearch!' "quadratic entry exact-call scan"
Assert-NotContains $typedSourceLowering 'entryPropertyCallSearch!' "quadratic entry property-call scan"
Assert-NotContains $typedSourceLowering 'qualifiedEntryFunctionParentCallSearch!' "quadratic entry parent-call scan"
Assert-NotContains $typedSourceLowering 'entryCallSearch!' "quadratic entry final-call scan"
Assert-Contains $semanticContext 'controlProducerWrapperByAst: [Bool; ~]' "semantic snapshot exact control-producer wrapper index"
Assert-Contains $semanticContext 'public indexControlProducerWrappersByAst package: ref analysis.PackageAnalysis -> [Bool; ~]' "single control-producer wrapper index builder"
Assert-Contains $semanticContext 'node.cstRuleId == grammar.ruleIdControlFlowExpression()' "control wrapper exact grammar identity"
Assert-Contains $semanticContext 'and node.cstRuleId == grammar.ruleIdFlowExpression()' "flow wrapper exact grammar identity"
Assert-Contains $typedCore 'node.cstRuleId == grammar.ruleIdControlFlowExpression()' "control wrapper excluded from intrinsic spelling ownership"
Assert-Contains $typedCore 'or node.cstRuleId == grammar.ruleIdFlowExpression()' "flow wrapper excluded from intrinsic spelling ownership"
Assert-MatchCount ($typedOrdinaryFunction + "`n" + $typedSourceLowering) 'prepared\.controlProducerWrapperByAst\[' 2 "entry and ordinary lowering share control-producer wrapper index"
Assert-Contains $typedFunctionLowering 'repairIndexedControlProducerWrappers nodes: mut [TypedIrNode; ~], prepared: ref semanticContext.SemanticSnapshot -> Unit' "linear indexed control-producer wrapper edge repair"
Assert-Contains $typedFunctionLowering 'firstChild![parent] => nextSibling![childIndex!]' "control-producer parent adjacency index"
Assert-Contains $typedFunctionLowering 'nodes[controlIndex!].operand0 => wrapper!.operand0' "control-producer exact subject edge"
Assert-Contains $typedCore 'results! -> repairIndexedControlProducerWrappers(prepared)' "control-producer repair before resolved-context normalization"
Assert-Contains $typedOrdinaryFunction 'declaredSignatureCandidate.kind == 17' "expression-body exact signature boundary"
Assert-Contains $typedOrdinaryFunction 'declaredBodyCandidate.kind != 16' "expression-body excludes name path"
Assert-Contains $typedOrdinaryFunction 'declaredBodyCandidate.kind != 17' "expression-body excludes signature"
Assert-Contains $typedOrdinaryFunction 'declaredBodyCandidate.start >= declaredBodyBoundary!' "expression-body begins after signature"
Assert-NotContains $typedOrdinaryFunction 'declaredBodyCandidate.kind == 10' "expression-body no flow-wrapper-only fallback"
Assert-Contains $typedFunctionLowering 'normalizeMatchResultTypeFromCompleteArms match: mut TypedIrNode, matchIndex: Int, unitTypeId: Int' "complete-arm authoritative late match result normalization"
Assert-Contains $typedFunctionLowering 'arm.parent != matchIndex -> if {' "late match result exact arm ownership"
Assert-Contains $typedFunctionLowering 'and allContinuingArmsAgree!' "late match result full-arm agreement gate"
Assert-Matches $typedFunctionLowering 'terminal\.kind != 23\s+and not \(terminalIndex -> terminalValueReturnsFromArm\(armIndex!, nodes\)\)' "late match result skips direct returns and values consumed by returning arms"
Assert-NotContains $typedFunctionLowering 'sealMatchResultTypeFromCanonicalArm' "rejected first-arm match result promotion"
Assert-Contains $typedFunctionLowering 'match -> sealNodeTypeIdentity(unitTypeId, types, flags)' "incomplete late match result demotion to canonical Unit"
Assert-Contains $typedFunctionLowering '0 -> builtinTypeId(types) => unitTypeId' "global match closure resolves canonical Unit once"
Assert-Contains $typedFunctionLowering 'match! -> normalizeMatchResultTypeFromCompleteArms(matchIndex!, unitTypeId, results, types, flags)' "global match closure uses the complete-arm normalizer"
Assert-Contains $typedFunctionLowering 'sealCompletedIfAndRegionTypes nodes: mut [TypedIrNode; ~] -> Unit' "late enclosing if and region type closure"
Assert-Matches $typedFunctionLowering '(?s)sealCompletedIfAndRegionTypes nodes: mut \[TypedIrNode; ~\].*?nodes -> len => controlIndex!.*?control!\.kind == 19.*?control!\.kind == 18.*?thenRegion\.typeId >= 0 and thenRegion\.typeId == elseRegion\.typeId.*?branchTypesMatch!.*?control! => nodes\[controlIndex!\]' "late control closure is reverse ordered and requires exact continuing branch agreement"
Assert-Contains $typedFunctionLowering 'public terminatingControlFlags nodes: ref [TypedIrNode; ~] -> [Bool; ~]' "shared single-pass terminating control index"
Assert-Contains $typedFunctionLowering 'thenTerminates and not elseTerminates' "terminating then branch does not erase the continuing else value"
Assert-Contains $typedFunctionLowering 'elseTerminates and not thenTerminates' "terminating else branch does not erase the continuing then value"
Assert-Contains $semanticOwnership 'typed -> typedIr.terminatingControlFlags => terminatingControls' "ownership joins share Typed IR termination facts"
Assert-Contains $semanticOwnership 'bindingDeclaredBeforeControl moveEvent: typedIr.MoveEvent, controlIndex: Int -> Bool' "ownership joins exclude alternative-local bindings"
Assert-Contains $semanticOwnership 'typed[alternativeControlIndex].kind == 18' "ownership joins inspect conditional alternatives"
Assert-Contains $semanticOwnership 'not terminatingControls[retainingAlternativeRegion!]' "ownership joins compare continuing alternatives only"
Assert-Contains $semanticOwnership 'existingAlternativeDiagnostic.code == 33' "ownership joins deduplicate mixed-alternative diagnostics"
Assert-Contains $emitterDiagnostics 'diagnostic.code == 33 -> if {' "mixed-alternative ownership diagnostic emission"
Assert-Contains $emitterDiagnostics "must be consumed on every control-flow branch or on none of them" "mixed-alternative ownership diagnostic contract"
Assert-Contains $emitterDiagnostics 'diagnosticCode == 33 -> if { count! + 1 => count! }' "mixed-alternative ownership diagnostic blocks code generation"
Assert-Contains $semanticOwnership 'directOwnedCopy.kind == 17' "direct owned-copy binding classification"
Assert-Contains $semanticOwnership 'typed[directOwnedCopy.operand0].kind == 5' "direct owned-copy source identity"
Assert-Contains $semanticOwnership 'moves[directOwnedCopyMoveIndex!].siteIr == directOwnedCopy.operand0' "explicit direct ownership transfer exclusion"
Assert-Contains $semanticOwnership 'directOwnedCopySourceCandidate.kind == 10' "moved parameter alias exclusion"
Assert-Contains $emitterDiagnostics 'owned container values must be created directly at their binding site' "direct owned-copy diagnostic contract"
Assert-Contains $emitterDiagnostics 'diagnosticCode == 34 -> if { count! + 1 => count! }' "direct owned-copy diagnostic blocks code generation"
Assert-Contains $invariants 'typedControlTerminates controlIndex: Int, context: ref emitterContext.EmitContext -> Bool' "LLVM invariant has a state-free structural termination resolver"
Assert-Contains $invariants 'typedIfThenValueIndex -> typedControlTerminates(context) => typedIfThenTerminates' "typed if invariant excludes a terminating then path"
Assert-Contains $invariants 'typedIfElseValueIndex -> typedControlTerminates(context) => typedIfElseTerminates' "typed if invariant excludes a terminating else path"
Assert-MatchCount $typedResolvedContextFinalize 'nodes -> sealCompletedIfAndRegionTypes' 4 "initial and both late projected-match seals immediately propagate through enclosing regions and ifs"
Assert-NotContains $typedOrdinaryFunctionFinalize 'normalizeMatchResultTypeFromCompleteArms' "rejected duplicate per-function complete-arm normalization"
Assert-NotContains $typedSourceLoweringFinalize 'normalizeMatchResultTypeFromCompleteArms' "rejected duplicate entry complete-arm normalization"
Assert-NotContains $typedSourceLoweringFinalize 'entryMatchResultArm.typeOrigin => entryControlTypeNode!.typeOrigin' "rejected entry first-arm match result promotion"
Assert-NotContains $typedResolvedContextSeal 'finalMatchArm.typeOrigin => finalControlType!.typeOrigin' "rejected final first-arm match result promotion"
Assert-NotContains $typedResolvedContextSeal 'lateCallMatchArm.typeOrigin => lateCallControlType!.typeOrigin' "rejected late-call first-arm match result promotion"
Assert-Contains $typedResolvedContextSeal '[Int; ~] => finalControlByParent!' "final control shell direct-child index"
Assert-Contains $typedResolvedContextSeal 'finalControlByParent![finalControlChild.parent] == -1' "final control shell ambiguity-preserving index"
Assert-Contains $typedResolvedContextSeal 'finalControlWrapperRule == grammar.ruleIdControlFlowExpression()' "control-flow expression shell provenance gate"
Assert-Contains $typedResolvedContextSeal 'or finalControlWrapperRule == grammar.ruleIdFlowExpression()' "flow expression shell provenance gate"
Assert-Contains $typedResolvedContextSeal 'and finalControlValue.operand0 == finalControlWrapper!.operand0' "control shell exact condition identity gate"
Assert-Contains $typedResolvedContextSeal 'and finalControlValue.typeId == finalControlWrapper!.typeId' "control shell canonical result identity gate"
Assert-Matches $typedResolvedContextSeal '(?s)9 => finalControlWrapper!\.kind\s+-1 => finalControlWrapper!\.opcode\s+finalControlValueIndex => finalControlWrapper!\.operand1' "misclassified control shell becomes one canonical transparent control-producer wrapper"
Assert-Matches $typedResolvedContextSeal '(?s)finalWrappedValueByNode!\[wrapperIndex\] == controlIndex\s+and nodes\[wrapperIndex\]\.nextOperand == finalControlMatchIndex!\s+-> if \{\s+controlIndex => finalControlMatch!\.operand0' "late control normalization reseals only the exact linked following match to its validated producer"
Assert-Contains $nestedResultLogicalConditionFixture 'earlier < 0 and later > 9_223_372_036_854_775_807 + earlier' "nested Result regression retains logical condition"
Assert-NotContains $typedCore '# per-function parallel region.' "stale C82 parallel-region claim"
Assert-NotContains $typedCore '# Function lowering owns the active parallel region.' "stale C82 function-pool claim"
Assert-Contains $expressionTypeIds 'referenceIndexByTypeAst: [Int; ~]' "retained global-AST type-reference index"
Assert-Contains $expressionTypeIds 'referenceIndexByTypeAst: referenceIndexByTypeAst!' "reference index ownership transfer"
Assert-MatchCount $expressionTypeIds '\[Int; ~\] => referenceIndexByTypeAst!' 1 "single reference-index allocation"
Assert-MatchCount $typedCore 'recursiveTypes\.referenceIndexByTypeAst\[' 8 "Typed IR direct indexed recursive-reference exact lookups"
Assert-MatchCount $typeCheck 'recursiveTypes\.referenceIndexByTypeAst\[' 3 "type-check direct indexed exact reference lookups"
Assert-NotContains $expressionTypeIds 'referenceIndexForTypeAst' "unused O0 recursive-reference lookup helper"
Assert-Contains $expressionTypeIdsPaths 'resolveLateArrayTypes(prepared, types, expressions, expressionIndexByAst)' "late array semantic path phase integration"
Assert-MatchCount ($expressionTypeIds + "`n" + $expressionTypeIdsPaths) 'resolveLateArrayTypes\(prepared, types!?, expressions!?, expressionIndexByAst!?\)' 1 "single late array semantic phase integration"
Assert-Contains $lateArrayTypes '[Int; ~] => nearestDistanceByChild!' "late indexed-element direct-child distance table"
Assert-Contains $lateArrayTypes 'ancestorNode.kind == 37' "late indexed-element array ancestor selection"
Assert-Contains $lateArrayTypes 'typedChildCount![globalAst] == directChildCount![globalAst]' "late array complete direct-child gate"
Assert-Contains $lateArrayTypes 'and homogeneous![globalAst]' "late array homogeneous element gate"
Assert-Contains $lateArrayTypes 'types -> push(typeIds.SemanticType {' "semantic composite type creation before Typed IR"
Assert-Contains $expressionTypeIds 'item.typeId => existing!.typeId' "late array stale expression repair"
Assert-Contains $expressionTypeIds 'expressionIndex! => expressionIndexByAst[item.globalAst]' "late array new expression type publication"
Assert-Contains $expressionTypeIdsPaths 'lateArrayChanged -> if { true => pathChanged! }' "late nested-array fixed-point continuation"
Assert-NotContains $lateArrayFixture 'expression.astNode ==' "late array fixture unstable AST ordinal dependency"
Assert-Contains $lateArrayFixture 'arrayType.kind == 4' "late array fixture semantic array-kind selector"
Assert-Contains $lateArrayFixture 'arrayType.length == 1' "late array fixture semantic fixed-length selector"
Assert-Contains $lateArrayFixture 'elementType.symbol == 8' "late array fixture UInt8 element selector"
Assert-NotMatches $logicalIrFixture 'astNode\s*==\s*\d+' "logical IR fixture unstable AST ordinal dependency"
Assert-Contains $logicalIrFixture 'node.parent == 0' "logical IR fixture semantic root-binding selector"
Assert-Contains $logicalIrFixture 'ir[node.operand0].kind == 8' "logical IR fixture semantic operand-kind selector"
Assert-NotMatches $directoryBinaryFixture 'sourceNode\.start\s*==\s*\d+' "directory binary fixture unstable source-offset dependency"
Assert-Contains $directoryBinaryFixture 'expressionSource == "nameIndex! + 1"' "directory binary stable first source selector"
Assert-Contains $directoryBinaryFixture 'expressionSource == "cursor! + nameLength"' "directory binary stable second source selector"
Assert-NotContains $typedCore 'referenceIndexForTypeAst' "Typed IR O0 recursive-reference lookup helper call"
Assert-NotContains $typeCheck 'referenceIndexForTypeAst' "type-check O0 recursive-reference lookup helper call"
Assert-MatchCount ($typedCore + "`n" + $typedTypeQueries + "`n" + $typedValueAliases) 'recursiveTypes\.references -> len' 5 "Typed IR retained shape, parent, ancestor, and copy reference scans"
Assert-NotContains $typedCore 'prepared.semantic.references -> len' "Typed IR duplicate prepared-reference scans"
Assert-Contains $typedCore 'contextualStructBindingDeclaredTypeId! == contextualStructFieldTypeId!' "declared struct-field binding canonical type gate"
Assert-Contains $typedResolvedContextNormalize 'contextualStructBindingInitializer! => nodes[contextualStructBinding!.operand0]' "struct-field binding initializer canonical type propagation"
Assert-Contains $typedResolvedContextNormalize '[Int; ~] => nullaryFunctionBySymbol!' "nullary flow declaration identity index"
Assert-Contains $typedResolvedContextNormalize 'nullaryFunctionBySymbol![nullaryFlowSourceRange.symbolStart + nullaryFlowSource!.symbol] => nullaryFlowFunctionIr!' "nullary flow indexed declaration lookup"
Assert-Contains $typedResolvedContextNormalize 'nullaryFlowSource!.sourceModule >= 0' "nullary flow source-module lower bound"
Assert-NotContains $typedResolvedContextNormalize 'nullaryFlowFunctionSearch! < (nodes -> len)' "no per-nullary-flow whole-IR declaration scan"
Assert-Contains $typedResolvedContextNormalize '[Int; ~] => recoveredControlByFlowAst!' "unresolved control exact flow-AST index"
Assert-Contains $typedResolvedContextNormalize 'recoveredFlowAstSeed! < (prepared.package.nodes -> len)' "flow-AST index uses authoritative AST cardinality"
Assert-Contains $typedResolvedContextNormalize 'recoveredControlSeed! < (nodes -> len)' "per-control result indexes use Typed IR cardinality"
Assert-Contains $typedResolvedContextNormalize 'recoveredControlByFlowAst![recoveredConditionAncestorGlobalAst] => recoveredCandidateControl!' "Bool candidate indexed control lookup"
Assert-NotContains $typedResolvedContextNormalize 'recoveredConditionSearch! < (nodes -> len)' "no per-control whole-IR Bool candidate scan"
Assert-Contains $typedResolvedContextNormalize '[Int; ~] => lateMutableRootBySymbol!' "late mutable binding canonical-root index"
Assert-Contains $typedResolvedContextNormalize 'lateMutableRootBySymbol![lateMutableGlobalSymbol] => lateMutableRootIndex' "late mutable binding indexed root lookup"
Assert-NotContains $typedResolvedContextNormalize 'lateMutableRootSearch! < lateMutableBindingIndex!' "no per-binding prior-IR canonical-root scan"
Assert-Contains $typedResolvedContextNormalize 'canonicalReference!.kind == 5' "canonical pattern scan reference-kind precondition"
Assert-Contains $typedResolvedContextNormalize '[Int; ~] => canonicalPatternHeadBySymbol!' "canonical pattern global-symbol head index"
Assert-Contains $typedResolvedContextNormalize '[Int; ~] => canonicalPatternNextByIr!' "canonical pattern same-symbol linked index"
Assert-Contains $typedResolvedContextNormalize 'canonicalPatternHeadBySymbol![canonicalPatternRange.symbolStart + canonicalReference!.symbol] => canonicalPatternSearch!' "canonical reference indexed pattern lookup"
Assert-Contains $typedResolvedContextNormalize 'canonicalPatternNextByIr![canonicalPatternSearch!] => canonicalPatternSearch!' "canonical reference same-symbol pattern traversal"
Assert-Contains $typedResolvedContextNormalize 'canonicalReference!.kind == 5 and not canonicalPatternIndexed!' "unresolved pattern identity compatibility fallback"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalSlotRootBySymbol!' "final mutable slot canonical-root index"
Assert-Contains $typedResolvedContextFinalize 'finalSlotRootBySymbol![finalSlotGlobalSymbol] => finalSlotRootIndex' "final mutable slot indexed root lookup"
Assert-NotContains $typedResolvedContextFinalize 'finalSlotRootSearch! < finalSlotBindingIndex!' "no per-final-slot prior-IR root scan"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalFunctionBySymbol!' "final call declaration global-symbol index"
Assert-Contains $typedResolvedContextFinalize 'finalFunctionBySymbol![finalCallArrayGlobalSymbol] => finalCallArrayFunction!' "final call indexed declaration lookup"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalCanonicalTakeByParent!' "duplicate take parent index"
Assert-NotContains $typedResolvedContextFinalize 'finalCanonicalTakeSearch! < (nodes -> len)' "no per-duplicate-take whole-IR scan"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalPatternBindingByArm!' "pattern subject arm-binding index"
Assert-NotContains $typedResolvedContextFinalize 'finalPatternSubjectBindingSearch! < (nodes -> len)' "no per-pattern-subject whole-IR scan"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalReturnCandidateHeadByModule!' "explicit return module candidate index"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalReturnCandidateNextByIr!' "explicit return module linked index"
Assert-Contains $typedResolvedContextFinalize 'finalReturnCandidateHeadByModule![finalExplicitReturn!.sourceModule] => finalExplicitReturnSearch!' "explicit return module-local traversal"
Assert-NotContains $typedResolvedContextFinalize 'finalExplicitReturnSearch! < (nodes -> len)' "no per-explicit-return whole-IR scan"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalNestedControlHeadByModule!' "nested control module head index"
Assert-Contains $typedResolvedContextFinalize '[Int; ~] => finalNestedControlNextByIr!' "nested control module linked index"
Assert-Contains $typedResolvedContextFinalize 'finalNestedControlHeadByModule![finalNestedControlBinary!.sourceModule] => finalNestedControlCandidateIndex!' "nested control module-local traversal"
Assert-NotContains $typedResolvedContextFinalize '0 => finalNestedControlCandidateIndex!' "no per-binary whole-IR nested-control scan"
Assert-NotContains $typeCheck 'recursiveTypes.references -> len' "type-check full reference scans"
Assert-Contains $entrypoints 'profilePhase == 7 -> if {' "checked diagnostic count phase"
Assert-Contains $entrypoints '"semantic diagnostics = $semanticDiagnosticCount" -> runtime.eprintln' "semantic diagnostic count telemetry"
Assert-Contains $entrypoints '"ir diagnostics = $irDiagnosticCount" -> runtime.eprintln' "IR invariant diagnostic count telemetry"
Assert-Contains $textContext "supportsComputePool -> if {" "target-capability Typed IR routing"
Assert-Contains $textContext "prepared -> typedIr.lowerResolvedContextParallel(recursiveTypes)" "native recursive-type production lowering"
Assert-Contains $textContext "prepared -> typedIr.lowerResolvedContext(recursiveTypes)" "browser recursive-type production lowering"
Assert-Contains $interpolationIr "qualifiedFlowTargetName.span.start + qualifiedFlowTargetName.span.length <= qualifiedFlowPath.start + qualifiedFlowPath.length" "interpolation qualified target exact span containment"
Assert-Contains $interpolationIr "complete projected value must become operand0" "interpolation projected receiver operand contract"
Assert-Contains $interpolationIr "and not (source -> isRawStringToken(stringToken))" "raw strings bypass interpolation lowering"
Assert-NotMatches $interpolationIr '(?s)flowTarget\.parent == fragmentAstIndex! and flowTarget\.kind == 36\s*-> if \{ true => flowQualifiedTarget! \}' "broad interpolation member-path target classification"
Assert-Contains $projectedInterpolationCallFixture '"$(outer.inner -> read)" -> println' "projected interpolation executable fixture"
Assert-Contains $projectedInterpolationCallCounts '= call i32 @sollang_m' "projected interpolation direct-call count fixture"
Assert-Contains $projectedInterpolationCallOrder '= extractvalue %sollang\.struct' "projected interpolation receiver-before-call ordering fixture"
Assert-Contains $projectedInterpolationCallOrder 'call void @sollang_runtime_print_i64' "projected interpolation call-before-format ordering fixture"
Assert-Contains $projectedInterpolationTopologyFixture "and interpolations[node.operand0].kind == 5" "projected interpolation call-to-member topology fixture"
Assert-Contains $projectedInterpolationTopologyFixture '"$(42 -> formatter.render)" -> println' "qualified interpolation target negative control"
Assert-Contains $projectedInterpolationTopologyFixture '"projected-call-payload=$(projectedCallPayload!)" -> println' "projected interpolation complete call-span fixture"
if ($projectedInterpolationTopologySources.Count -gt 10) {
    throw "projected interpolation topology fixture exceeds its 10-source closure budget: $($projectedInterpolationTopologySources.Count)"
}
Assert-NotContains ($projectedInterpolationTopologySources -join "`n") 'selfhost/ir/typed.slg' "projected interpolation topology-only closure"
Assert-Contains $rawStringNoInterpolationFixture '$(missing.receiver -> call)' "raw-string interpolation-shaped bytes fixture"
Assert-Contains $functionScheduling "scheduleNode.operand0 -> aggregateValueIndex(context, state) => scheduleAssignmentValue" "canonical assignment-value scheduling"
Assert-Contains $text "entryScheduleNode.operand0 -> aggregateValueIndex(context, state) => entryScheduleAssignmentValue" "production canonical assignment-value scheduling"
Assert-Contains $functionScheduling "context.ir[scheduleAssignmentChildSearch!].parent == scheduleNode.operand0" "canonical assignment direct-child scheduling"
Assert-Contains $text "context.ir[entryScheduleAssignmentChildSearch!].parent == entryScheduleNode.operand0" "production canonical assignment direct-child scheduling"
Assert-Contains $control "localCandidate.operand0 -> aggregateValueIndex(context, state) => localAssignmentValue" "control-region canonical assignment-value scheduling"
Assert-Contains $control "context.ir[localAssignmentChildSearch!].parent == localCandidate.operand0" "control-region canonical assignment direct-child scheduling"
Assert-Contains $containers "assignment.operand0 -> aggregateValueIndex(context, state) => assignmentValueIndex" "canonical assignment-value emission"
Assert-MatchCount $containers 'assignment\.operand0 -> aggregateValueIndex\(context, state\) => assignmentValueIndex' 2 "indexed/member canonical assignment-value paths"
Assert-Contains $containers "ownedMove.regionIr == request.regionIndex or (ownedMove.regionIr -> ownershipRegionContainsEdge(ownedDropEdgeNode, context, state))" "early-return ownership-path move containment"
Assert-Contains $containers "partialMoveActiveBefore(ownedMove.regionIr, request.beforeAst, context, state)" "nested early-return partial-move cleanup region"
Assert-NotContains $containers "partialMoveActiveBefore(request.regionIndex, request.beforeAst, context, state)" "outer-region partial-move cleanup regression"
Assert-Contains $ownership "emitDropGlue request: DropGlueRequest, edgeNodeIndex: Int" "drop glue explicit cleanup-edge identity"
Assert-Matches $functionExpressions '(?s)emittedFieldIndex -> promotedFixedArrayCall\(context, state\) => fieldBackingCall\s+fieldBackingCall >= 0 -> if \{\s+fieldBackingCall -> emitPromotedFixedBackingDrop\(expressionIndex\)' "function field materialization drops only fresh promoted fixed backing"
Assert-Matches $controlRegions '(?s)regionEmittedFieldIndex -> promotedFixedArrayCall\(context, state\) => regionFieldBackingCall\s+regionFieldBackingCall >= 0 -> if \{\s+regionFieldBackingCall -> emitPromotedFixedBackingDrop\(regionNodeIndex\)' "control-region field materialization drops only fresh promoted fixed backing"
Assert-Matches $entryExpressions '(?s)entryEmittedFieldIndex -> promotedFixedArrayCall\(context, state\) => entryFieldBackingCall\s+entryFieldBackingCall >= 0 -> if \{\s+entryFieldBackingCall -> emitPromotedFixedBackingDrop\(entryExpressionIndex\)' "entry field materialization drops only fresh promoted fixed backing"
Assert-MatchCount $functionReturns '(?m)^\s+context\.types\[dropCandidate\.typeId\]\.kind == 4\s*$' 2 "function-return cleanup fixed-array inline ABI guards"
Assert-MatchCount $containers '(?m)^\s+and context\.types\[context\.ir\[ownedDropEdgeNode\]\.typeId\]\.kind == 4\s*$' 1 "control-edge cleanup fixed-array inline ABI guard"
Assert-MatchCount $containers '(?m)^\s+context\.types\[ownedDropCandidate\.typeId\]\.kind == 4\s*$' 1 "control-binding cleanup fixed-array inline ABI guard"
Assert-Contains $ownership "dropGlueMove.regionIr -> ownershipRegionContainsEdge(edgeNodeIndex, context, state)" "drop glue cleanup-edge containment"
Assert-Contains $ownership "partialMoveActiveBefore(dropGlueMove.regionIr, dropTask.beforeAst, context, state)" "drop glue nested partial-move region"
Assert-NotContains $ownership "partialMoveActiveBefore(dropTask.regionIndex, dropTask.beforeAst, context, state)" "drop glue outer-region partial-move regression"
Assert-Contains $ownership "edgeAst.start + edgeAst.length => edgeEnd!" "partial-move cleanup after complete edge expression"
Assert-Contains $ownership "dropGlueEdgeAst.start + dropGlueEdgeAst.length => dropGlueBeforeEnd!" "field drop glue after complete edge expression"
Assert-Contains $ownership "emitAggregatePartialMoveCleanup aggregateIndex: Int, functionIndex: Int" "nested aggregate partial-move cleanup authority"
Assert-Contains $ownership "(context -> parameterIndexForFunction(functionIndex, candidateMove.symbol)) == parameterIndex" "nested aggregate move-parameter declaration identity"
Assert-Contains $ownership "aggregateIndex == moveAggregateOwner" "nested aggregate complete and partial move path cleanup"
Assert-Contains $ownership "nearestAggregateTransferOwner" "innermost aggregate owns partial move cleanup exactly once"
Assert-Contains $ownership 'nearestCompletedTransferOwner siteIndex:' "one authoritative transfer completion boundary"
Assert-Contains $coreCalls 'moveEvent.siteIr -> nearestCompletedTransferOwner(context, state)' "generic transfer markers use the nearest completion boundary"
Assert-Contains $coreCalls 'moveEvent.siteIr -> nearestAggregateTransferOwner(context, state)' "generic markers defer aggregate parameters to aggregate cleanup"
Assert-Contains $typedOrdinaryFunctionFinalize "retain the outermost merged value" "implicit return promotes branch-local leaf to merged control"
Assert-Contains $ownership "context.types[dropFieldTypeId!].kind == 1" "canonical nested struct drop recursion"
Assert-Contains $functions "expressionIndex -> emitAggregatePartialMoveCleanup(functionIndex, context, state)" "function aggregate transfer consumes path cleanup"
Assert-Contains $controlRegions "regionNodeIndex -> emitAggregatePartialMoveCleanup(ownerIndex, context, state)" "control-region aggregate transfer consumes path cleanup"
Assert-Contains $functions 'drop_partial_arg$(ownedParameterOrdinal!)_still_owned' "function cleanup observes aggregate path ownership"
Assert-Contains $containers "emitDropGlue(ownedDropEdgeNode, context, state)" "early-return edge propagated to field drop glue"
Assert-Contains $containers "dropEdgeAst.start + dropEdgeAst.length => dropBeforeEnd!" "owned cleanup after complete edge expression"
Assert-Contains $postWhileMemberAssignmentFixture 'self.offset + (output -> len) => self.offset' "post-while wrapped member-assignment fixture"
foreach ($formalVerifier in @($stage2Verifier, $stage3Verifier)) {
    Assert-Contains $formalVerifier '--exact 1183-process-zero-limit-concurrent-capture' "formal zero-limit process capture fixture"
    Assert-Contains $formalVerifier '--exact 1184-non-process-collect-has-no-process-runtime' "formal process capability false-positive fixture"
    Assert-Contains $formalVerifier '--exact 1185-selfhost-projected-receiver-instance-call' "formal projected interpolation executable fixture"
    Assert-Contains $formalVerifier '--exact 1186-selfhost-interpolation-projected-call-topology' "formal projected interpolation topology fixture"
    Assert-Contains $formalVerifier '--exact 1187-selfhost-raw-string-no-interpolation' "formal raw-string no-interpolation fixture"
    Assert-Contains $formalVerifier '--exact 1189-selfhost-member-assignment-after-while' "formal post-while member-assignment fixture"
    Assert-Contains $formalVerifier '--exact 1212-selfhost-member-assignment-after-take' "formal post-take member-assignment fixture"
    Assert-Contains $formalVerifier '--exact 1213-selfhost-result-field-transfer-after-take' "formal post-take owned field transfer fixture"
    Assert-Contains $formalVerifier '--exact 1340-selfhost-result-arm-owned-field-transfer' "formal Result-arm owned field transfer fixture"
    Assert-Contains $formalVerifier '--exact 1192-readonly-captured-nested-parameter-projection' "formal captured readonly projection fixture"
    Assert-Contains $formalVerifier '--exact 1193-struct-field-collection-binding-baseline' "formal collection-binding baseline fixture"
    Assert-Contains $formalVerifier '--exact 1194-struct-field-collection-binding-perturbed' "formal collection-binding permutation fixture"
}
$productionRecursiveTypeResolutions = ([regex]::Matches($textContext, 'expressionTypeIds\.resolveContext')).Count
if ($productionRecursiveTypeResolutions -ne 1) {
    throw "native LLVM preparation must resolve recursive expression types exactly once; actual=$productionRecursiveTypeResolutions"
}
$recursiveTypeResolutionOffset = $textContext.IndexOf("prepared -> expressionTypeIds.resolveContext => recursiveTypes!", [StringComparison]::Ordinal)
$capabilityHelperOffset = $textContext.IndexOf("lowerPreparedIr prepared:", [StringComparison]::Ordinal)
$parallelLoweringOffset = $textContext.IndexOf("prepared -> typedIr.lowerResolvedContextParallel(recursiveTypes)", [StringComparison]::Ordinal)
$serialLoweringOffset = $textContext.IndexOf("prepared -> typedIr.lowerResolvedContext(recursiveTypes)", [StringComparison]::Ordinal)
$prepareSnapshotOffset = $textContext.IndexOf("prepareSnapshot request:", [StringComparison]::Ordinal)
$capabilityRoutingOffset = $textContext.IndexOf("prepared -> lowerPreparedIr(recursiveTypes!, supportsComputePool) => ir!", [StringComparison]::Ordinal)
$genericClosureOffset = $textContext.IndexOf("ir! -> typedIr.materializeGenericClosure(prepared, recursiveTypes!) => genericInstances", [StringComparison]::Ordinal)
$streamPlanOffset = $textContext.IndexOf("prepared -> streamIr.build(ir!, recursiveTypes!) => streamPlan", [StringComparison]::Ordinal)
if ($capabilityHelperOffset -lt 0 -or
    $parallelLoweringOffset -le $capabilityHelperOffset -or
    $serialLoweringOffset -le $parallelLoweringOffset -or
    $prepareSnapshotOffset -le $serialLoweringOffset -or
    $recursiveTypeResolutionOffset -le $prepareSnapshotOffset -or
    $capabilityRoutingOffset -le $recursiveTypeResolutionOffset -or
    $genericClosureOffset -le $capabilityRoutingOffset -or
    $streamPlanOffset -le $genericClosureOffset) {
    throw "native LLVM recursive-type reuse order drifted"
}

$nativePrepareCalls = ([regex]::Matches($entrypoints, 'prepareRequest -> prepareNative => context')).Count
$serialPrepareCalls = ([regex]::Matches($entrypoints, 'prepareRequest -> prepare => context')).Count
if ($nativePrepareCalls -ne 4 -or $serialPrepareCalls -ne 2) {
    throw "target preparation routing drifted: native=$nativePrepareCalls, browser=$serialPrepareCalls"
}

Assert-Contains $typedCore "public isSocketRuntimeOpcode" "socket runtime opcode predicate"
Assert-Contains $ast "methodIntrinsicToken!" "inherent intrinsic declaration scan"
Assert-Matches $ast '(?s)declaration!\.kind == 7 or declaration!\.kind == 31.*?methodHeaderToken\.kind == grammar\.tokenIdEqual\(\).*?methodIntrinsicEqual!.*?methodHeaderToken\.span\.length == 9.*?declaration!\.flags \+ 128' "exact global and inherent equals-intrinsic AST identity"
Assert-Contains $typedFunctionLowering "pathSymbol.kind == 7 or pathSymbol.kind == 31" "global and inherent path intrinsic symbol kinds"
Assert-Contains $typedFunctionLowering "pathSymbol.flags / 128 % 2 == 1" "path intrinsic declaration identity"
Assert-Contains $typedFunctionLowering "not canonicalPathIntrinsic!" "same-name path intrinsic rejection"
Assert-Contains $typedFunctionLowering "repairPostfixMatchArmResults results: mut [TypedIrNode; ~] -> Unit" "postfix match-arm contextual result repair"
Assert-Contains $typedFunctionLowering 'regionRootIndex + 1 => candidateIndex!' "postfix match-arm candidate scan starts at the proven continuation boundary"
Assert-Matches $typedFunctionLowering '(?s)not regionRootMatchesResultType!.*?candidate\.kind == 18.*?candidate\.kind == 27.*?candidate\.kind == 33.*?candidate\.kind == 34.*?and candidateMatchesResultType!.*?ancestorIndex! == regionRootIndex.*?contextualControlIndex! => region!\.operand1' "postfix match-arm result follows the nearest contextual control descendant"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> repairControlBindingWrappers\(finalWrappedValueByNode\).*?nodes -> repairPostfixMatchArmResults' "postfix match-arm repair runs after final wrapper sealing"
Assert-Matches $typedFunctionLowering '(?s)sealBooleanOperatorTypes results: mut \[TypedIrNode; ~\].*?operator!\.kind == 8.*?grammar\.tokenIdEqualEqual\(\).*?operator!\.opcode == -24.*?operator!\.opcode == -25.*?sealNodeTypeIdentity\(boolTypeId' "late logical and comparison operators seal canonical Bool identity"
Assert-Contains $managedSemanticCompiler "Text supports content equality with '==' and '!='" "managed Text equality semantic contract"
Assert-Contains $managedControlEmitter 'left is RuntimeText leftText && right is RuntimeText rightText' "managed Text equality lowering"
Assert-Contains $managedControlEmitter 'EmitValuesEqual(leftText, rightText)' "managed allocation-free Text equality implementation"
Assert-Contains $functions 'and (leftOperand -> isTextType)' "self-host named-function Text equality type gate"
Assert-Contains $functions '@sollang_text_equal' "self-host named-function Text equality runtime call"
Assert-Contains $text 'entryTextEquality' "self-host entry Text equality path"
Assert-Contains $control 'regionTextEquality' "self-host nested-control Text equality path"
Assert-Contains $containers 'whileTextEquality' "self-host loop Text equality path"
Assert-Contains $runtimePreamble 'usesDirectTextEqualityRuntime' "self-host Text equality helper direct-consumer reachability"
Assert-Contains $runtimePreamble 'usesTextEqualityRuntime!' "self-host Text equality helper consolidated reachability"
Assert-NotContains $runtimePreamble 'usesText -> if { llvmRuntime.emitTextEqualityHelper() }' "self-host Text equality helper broad Text over-emission"
Assert-Contains $textEqualityFixture 'source == expected' "Text equality positive fixture"
Assert-Contains $textEqualityFixture 'source != expected' "Text inequality positive fixture"
Assert-Contains $textEqualityFixture 'index! < 1 -> while {' "Text equality loop-context fixture"
Assert-Contains $textOrderingDiagnostic "Text supports content equality with '==' and '!='" "Text ordering actionable diagnostic fixture"
Assert-Contains $grammar 'rule LogicalAndExpression = ValueFlowComparisonExpression' "value flow comparison is one logical operand"
Assert-Contains $grammar 'rule ValueFlowComparisonExpression = ValueFlowExpression' "flow result comparison stays explicit"
Assert-Contains $grammar 'rule ValueFlowExpression = EqualityExpression' "value flow preserves compare-then-flow"
Assert-Contains $valueFlowPrecedenceFixture 'true and "abc" -> sameText("abc")' "logical right-hand value-flow fixture"
Assert-Contains $valueFlowPrecedenceFixture '"abc" -> len == 3 and rightFlow' "flow-result comparison fixture"
Assert-Contains $generatedGrammar 'public ruleIdTopLevelDeclaration: -> Int => 117' "existing grammar rule ids stay stable"
Assert-Contains $generatedGrammar 'public ruleIdValueFlowComparisonExpression: -> Int => 118' "value-flow comparison rule is appended"
Assert-Contains $generatedGrammar 'public ruleIdValueFlowExpression: -> Int => 119' "value-flow rule is appended"
Assert-Matches $ast '(?s)node\.ruleId == grammar\.ruleIdFlowExpression\(\).*?node\.ruleId == grammar\.ruleIdValueFlowExpression\(\).*?candidateOperator == grammar\.tokenIdArrow\(\).*?arrowOwnedByDirectChild.*?not arrowOwnedByDirectChild! -> if \{.*?10 => astKind!' "only the CST node that directly owns an arrow becomes its semantic flow owner"
Assert-NotContains $ast 'arrowChildSearch' "flow-owner selection stays constant-time instead of rescanning the CST"
Assert-NotContains $ast 'rule == grammar.ruleIdFlowExpression() -> if { 10 => kind! }' "outer flow CST envelope stays transparent when a nested value flow owns the arrow"
Assert-NotContains $ast 'rule == grammar.ruleIdValueFlowExpression() -> if { 10 => kind! }' "arrowless value-flow CST wrapper stays transparent"
Assert-Contains $singleValueFlowOwnerFixture 'projected! -> push(1)' "mutable value-flow owner regression fixture"
Assert-Contains $singleValueFlowOwnerExpected 'flow-owners=1,mutable-owner-parent=10' "single semantic flow owner regression result"
Assert-Matches $typedFunctionLowering '(?s)sealLateNumericSubjectControls results: mut \[TypedIrNode; ~\].*?control!\.kind == 34 and control!\.operand0 < 0.*?candidate\.nextOperand == controlIndex!.*?not ambiguous!.*?subjectIndex! => control!\.operand0' "late numeric subject controls use one exact unambiguous flow edge"
Assert-Matches $typedFunctionLowering '(?s)isComparisonOperandValue node: TypedIrNode -> Bool.*?node\.kind == 2.*?node\.kind == 34' "late numeric comparison rights use the explicit value-node family"
Assert-Matches $typedFunctionLowering '(?s)sealLateNumericSubjectConditionOperands results: mut \[TypedIrNode; ~\].*?results\[candidateIndex!\]\.parent == conditionIndex!.*?not ambiguousChild!.*?condition!\.nextOperand >= 0.*?results\[condition!\.nextOperand\] -> isComparisonOperandValue.*?results\[candidateIndex!\]\.nextOperand == conditionIndex!.*?results\[candidateIndex!\] -> isComparisonOperandValue.*?not ambiguous!.*?rightIndex! => condition!\.operand1' "late numeric subject comparisons recover only exact direct-child or arm-local value edges"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealLateNumericSubjectControls\(frozenRecursiveSemanticTypes\).*?nodes -> sealLateNumericSubjectConditionOperands.*?0 => finalSubjectOperandIndex!' "late numeric subject and comparison sealing precede final arm refresh"
Assert-Matches $typedFunctionLowering '(?s)repairAssignmentsToCompletedSubjectControls results: mut \[TypedIrNode; ~\].*?candidate\.kind == 27 or candidate\.kind == 34.*?candidate\.operand0 == assignment!\.operand0.*?controlIndex! => assignment!\.operand0' "member and index assignments consume completed enum or numeric subject controls"
Assert-Matches $typedFunctionLowering '(?s)public matchArmTerminalValueIndex armIndex: Int.*?nodes\[candidate!\]\.kind == 19.*?nodes\[candidate!\]\.operand1 => candidate!.*?nodes\[candidate!\]\.kind != 19' "direct and structurally nested match arms share one bounded terminal resolver"
Assert-Matches $typedFunctionLowering '(?s)normalizeMatchResultTypeFromCompleteArms match: mut TypedIrNode.*?true => allContinuingArmsAgree!.*?terminal\.kind != 23.*?terminal\.typeId != resultTypeId!.*?false => allContinuingArmsAgree!.*?allContinuingArmsAgree! and hasContinuingValue! and selectedTerminal! >= 0' "late enum and numeric-subject controls require complete canonical agreement across continuing arms"
Assert-Matches $typedFunctionLowering '(?s)sealEnumMatchTypesFromTerminalArms results: mut \[TypedIrNode; ~\].*?match! -> normalizeMatchResultTypeFromCompleteArms\(matchIndex!, unitTypeId, results, types, flags\).*?match!\.typeOrigin == 1 and match!\.typeSymbol == 0' "every match re-enters authoritative complete-arm normalization and propagates canonical Unit to its parent region"
Assert-Matches $typedFunctionLowering '(?s)sealControlBindingAliasTypes results: mut \[TypedIrNode; ~\].*?binding!\.kind == 17.*?read!\.kind == 5' "control result bindings and direct reads share one linear alias seal"
Assert-Matches $typedFunctionLowering '(?s)repairEnumMatchSubjectsFromControlBindings results: mut \[TypedIrNode; ~\], types: ref \[typeIds\.SemanticType; ~\].*?read\.kind == 5.*?results\[read\.operand0\]\.kind == 17.*?results\[read\.operand0\]\.flags != 1.*?results\[results\[read\.operand0\]\.operand0\]\.kind == 18.*?kind == 27.*?kind == 33.*?kind == 34.*?read\.typeId >= 0.*?types\[read\.typeId\] => readType.*?readType\.kind == 1.*?readType\.kind == 7.*?readType\.origin == 4.*?readType\.symbol == 0 or readType\.symbol == 1.*?read\.parent.*?results\[read\.parent\]\.kind == 27.*?read\.nextOperand.*?results\[read\.nextOperand\]\.kind == 27.*?results\[subjectMatchIndex!\]\.operand0 != readIndex!.*?readIndex! => subjectMatch!\.operand0' "enum rematch subjects require an exact live binding/control chain, a copyable scalar or Option/Result enum, and a direct match edge"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealControlBindingAliasTypes\s+nodes -> repairEnumMatchSubjectsFromControlBindings\(frozenRecursiveSemanticTypes\)\s+# The final projected-method pass' "the final projected producer closure repairs control-bound enum rematch subjects before arm sealing"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> repairPostfixMatchArmResults.*?nodes -> sealBooleanOperatorTypes\(frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealEnumMatchTypesFromTerminalArms\(frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealControlBindingAliasTypes.*?nodes -> sealLateTypes\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?# A nominal terminal can become typed only in sealLateTypes\..*?nodes -> sealEnumMatchTypesFromTerminalArms\(frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealControlBindingAliasTypes.*?nodes -> sealLateTypes\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags\)' "late Bool, match, alias, and nominal-member sealing close the bounded dependency chain"
Assert-Matches $typedResolvedContextFinalize '(?s)# Repeat the same bounded closure after the second and final projected.*?nodes -> sealFinalProjectedMatchSubjectsAndPayloads\(prepared, frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealFinalEnumArmTagsAndPayloads\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealNominalEnumPayloadsByArmTags\(frozenRecursiveSemanticTypes, recursiveTypeFlags, prepared, recursiveTypes\).*?nodes -> sealEnumMatchTypesFromTerminalArms\(frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealCompletedIfAndRegionTypes.*?nodes -> sealControlBindingAliasTypes.*?nodes -> sealLateValueAliasTypes\(prepared\)' "final mutable projected Result call restores canonical match subjects, arm tags, payloads, and binding types"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealLateNumericSubjectControls\(frozenRecursiveSemanticTypes\).*?nodes -> sealEnumMatchTypesFromTerminalArms\(frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> repairAssignmentsToCompletedSubjectControls' "late numeric subject type sealing precedes its exact assignment consumer repair"
Assert-Matches $coreCalls '(?s)parallelAdditionalArgumentStart callIndex: Int.*?structuredParallelRoleOwner\(context\).*?context\.ir\[argumentIndex!\]\.nextOperand => argumentIndex!.*?parallelAdditionalArgumentCount.*?parallelAdditionalArgumentStart' "parallel callback additional arguments start after the canonical structured role"
Assert-Matches $text '(?s)parallelExpression\.operand1 -> parallelAdditionalArgumentStart\(context\) => parallelCallbackAdditionalIndex!.*?parallelCallbackAdditionalOrdinal! < parallelCallbackAdditionalCount.*?parallelCallbackParameterIndex >= 0 -> if \{.*?context\.ir\[parallelCallbackParameterIndex\] -> writeIrType.*?else \{.*?context\.ir\[parallelCallbackAdditionalIndex!\] -> writeIrType.*?context\.ir\[parallelCallbackAdditionalIndex!\]\.nextOperand => parallelCallbackAdditionalIndex!' "parallel callback additional arguments share declared-parameter or exact actual-value type fallback"
Assert-Contains $functions 'context.ir[parallelBodyCall.operand0].nextOperand -> emitReferenceArgumentValues' "function parallel fallback skips the synthesized item before reference arguments"
Assert-Contains $functions 'context.ir[parallelBodyCall.operand0].nextOperand -> emitCallArgumentChain' "function parallel fallback skips the synthesized item before call arguments"
Assert-Contains $controlRegions 'context.ir[regionParallelBodyCall.operand0].nextOperand -> emitReferenceArgumentValues' "control parallel fallback skips the synthesized item before reference arguments"
Assert-Contains $controlRegions 'context.ir[regionParallelBodyCall.operand0].nextOperand -> emitCallArgumentChain' "control parallel fallback skips the synthesized item before call arguments"
Assert-Contains $text 'context.ir[entryParallelBodyCall.operand0].nextOperand -> emitReferenceArgumentValues' "entry parallel fallback skips the synthesized item before reference arguments"
Assert-Contains $text 'context.ir[entryParallelBodyCall.operand0].nextOperand -> emitCallArgumentChain' "entry parallel fallback skips the synthesized item before call arguments"
Assert-Matches $coreCalls '(?s)call\.kind == 6.*?call\.opcode == -207 or call\.opcode == -209.*?call\.operand1 < startIndex or call\.operand1 >= endIndex.*?emitHoistedReferenceArgumentAllocas\(call\.operand1, call\.operand1 \+ 1' "parallel fallback hoists additional reference slots from its out-of-range body call"
Assert-Matches $coreCalls '(?s)emitParallelCaptureEnvironment.*?bodyCallIndex -> parallelAdditionalArgumentStart\(context\) -> emitReferenceArgumentValues.*?bodyCallIndex -> parallelAdditionalArgumentStart\(context\) => argumentIndex!' "parallel callback environments never capture the worker role as an outer value"
Assert-Matches $control '(?s)localSchedulePending nodeIndex: Int, localStart: Int, localEnd: Int, scheduled: ref \[Bool; ~\] -> Bool.*?nodeIndex >= localStart.*?nodeIndex < localEnd.*?not scheduled\[nodeIndex - localStart\]' "region-local readiness indexes only its exact function interval"
Assert-Matches $control '(?s)localCandidate\.operand0 -> localSchedulePending.*?localCandidate\.operand1 -> localSchedulePending.*?localPreviousBranchArm! -> localSchedulePending.*?localSliceLength -> localSchedulePending.*?localPushValue -> localSchedulePending.*?localAggregateValue -> localSchedulePending' "region dependency consumers share the bounded local readiness query"
Assert-Contains $typedCore '(matchCandidate.kind == 5 or matchCandidate.kind == 6)' "enum-match subject accepts the exact leading lexical value or resolved call"
Assert-Contains $typedCore '(enumSubjectTerminalCandidate.kind == 5 or enumSubjectTerminalCandidate.kind == 6)' "final enum-subject repair preserves the leading lexical value rule"
Assert-Matches $typedFunctionLowering '(?s)# Replace missing or non-materialized provisional subjects.*?finalProjectedSubject! >= 0 and finalProjectedMatch!\.operand0 != finalProjectedSubject!' "post-synthesis enum-call fallback replaces provisional non-values"
Assert-Matches $typedFunctionLowering '(?s)false => finalProjectedCandidateBelongs!.*?finalProjectedCandidate\.nextOperand == finalProjectedMatchIndex!.*?finalProjectedCandidate\.astNode == finalProjectedFlowAstIndex.*?finalProjectedCandidateAst\.parent == finalProjectedFlowAstIndex.*?finalProjectedCandidateOwner\.kind == 10.*?finalProjectedCandidateOwner\.parent == finalProjectedFlowAstIndex.*?finalProjectedCandidateOwner\.start == finalProjectedCandidateAst\.start.*?finalProjectedCandidateOwner\.length == finalProjectedCandidateAst\.length' "projected enum-call subject accepts an exact linked producer, direct flow child, or one exact transparent flow owner"
Assert-Contains $typedFunctionLowering 'and finalProjectedCandidateBelongs!' "projected enum-call subject selection enforces exact structural ownership"
Assert-Matches $typedFunctionLowering '(?s)prepared\.controlProducerWrapperByAst\[finalProjectedEligibilityRange\.astStart \+ finalProjectedMethod!\.astNode\].*?finalProjectedCall and finalProjectedNeedsResolution\s+and not finalProjectedControlProducerWrapper!' "projected receiver resolution excludes the indexed outer control-producing flow wrapper"
Assert-Matches $typedResolvedContextSeal '(?s)nodes -> resolveFinalProjectedMethods\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags\)\s+# A control-producing flow wrapper.*?nodes -> sealFinalProjectedMatchSubjectsAndPayloads\(prepared, frozenRecursiveSemanticTypes, recursiveTypeFlags\)' "initial projected receiver resolution immediately rebinds enum matches to the concrete inner call"
Assert-MatchCount $typedCore 'nodes -> resolveFinalProjectedMethods' 5 "projected receiver resolution runs only after its five distinct bounded producer checkpoints"
Assert-Contains $typedFunctionLowering 'targetKind == 7 -> if { true -> return }' "same-name global flow targets remain eligible for exact receiver precedence"
Assert-Matches $typedFunctionLowering '(?s)resolvedCallNeedsExactReceiver.*?targetKind == 7.*?targetKind == 31.*?expected.*?linked' "exact receiver retry separates provisional globals from arity-mismatched methods"
Assert-Matches $typedFunctionLowering '(?s)finalProjectedMethodFound! and not finalProjectedMethodAmbiguous!.*?finalProjectedTargetSource! => finalProjectedMethod!\.targetModule.*?finalProjectedTargetSymbol! => finalProjectedMethod!\.symbol' "provisional globals change only after one exact unambiguous receiver method is found"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealLateNominalMemberTypes\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags, lateNominalMemberChanges!\)\s+# Deep control nesting can make.*?nodes -> resolveFinalProjectedMethods\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealLateResolvedCallResultTypes.*?nodes -> sealControlBindingAliasTypes' "final nominal receiver producer is consumed before Typed IR invariants"
Assert-Matches $typedResolvedContextFinalize '(?s)# The final projected-method pass above can be the first producer.*?nodes -> sealFinalProjectedMatchSubjectsAndPayloads.*?nodes -> sealLateNominalMemberTypes.*?nodes -> sealFinalEnumArmTagsAndPayloads.*?nodes -> sealNominalEnumPayloadsByArmTags' "final projected Result identity is consumed by one bounded subject, payload, member, and arm-tag closure"
Assert-Contains $typedFunctionLowering 'finalProjectedCallToken.span.start >= finalProjectedReceiverEnd!' "projected method target token follows the exact receiver span"
Assert-Contains $typedFunctionLowering 'finalProjectedCallToken.span.start < finalProjectedTargetTokenStart!' "projected method target selects the earliest post-receiver identifier token"
Assert-Matches $typedFunctionLowering '(?s)member!\.kind == 13\s+and member!\.operand0 >= 0' "late nominal member sealing revalidates stale canonical field types"
Assert-Matches $typedFunctionLowering '(?s)sealLateNominalMemberTypes results:.*?member!\.kind == 13\s+and member!\.operand0 >= 0\s+and member!\.operand0 < \(results -> len\)\s+and results\[member!\.operand0\]\.typeId >= 0\s+-> if' "late nominal member sealing revalidates every exactly typed owner without a stale-member guard"
Assert-Matches $typedResolvedContextFinalize '(?s)sealFinalBinaryOperandTopology nodes: mut \[TypedIrNode; ~\].*?candidate\.parent >= 0.*?nodes\[candidate\.parent\]\.kind == 8.*?candidateEnd <= operatorStart.*?candidateAst\.start >= operatorEnd.*?leftByBinary!\[binaryIndex!\] => binary!\.operand0.*?rightByBinary!\[binaryIndex!\] => binary!\.operand1' "final binary operands use one linear exact-parent index after control ownership converges"
Assert-Matches $typedResolvedContextFinalize 'nodes\[candidate\.parent\]\.opcode >= grammar\.tokenIdPlus\(\)\s+and nodes\[candidate\.parent\]\.opcode <= grammar\.tokenIdPercent\(\)' "final binary topology repair is restricted to arithmetic operators"
Assert-Contains $typedResolvedContextFinalize 'and not (candidate.kind == 9 and candidate.opcode == -1)' "final binary topology excludes transparent wrapper operands"
Assert-Matches $typedResolvedContextFinalize '(?s)currentLeftAst\.start >= binaryAst\.start.*?currentLeftAst\.start \+ currentLeftAst\.length <= binaryOperatorStart.*?currentRightAst\.start >= binaryOperatorEnd.*?currentRightAst\.start \+ currentRightAst\.length <= binaryAstEnd' "final binary topology preserves already valid in-span operands"
Assert-Contains $typedResolvedContextFinalize 'nodes -> sealFinalBinaryOperandTopology(prepared)' "final binary topology seals before contextual numeric literals"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealFinalFunctionReturnAncestors\(prepared\).*?nodes -> sealEachRoleTypes\(prepared, frozenRecursiveSemanticTypes, recursiveTypeFlags\)\s+# Final return convergence.*?nodes -> sealLateNominalMemberTypes\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags, lateNominalMemberChanges!\)\s+nodes -> sealFinalBinaryOperandTopology' "final return convergence seals each-role types before nominal fields and arithmetic topology"
Assert-Contains $typedCore 'call result -> binding/read -> member -> method' "late mutable receiver dependency closure"
Assert-Matches $typedFunctionLowering '(?s)returnedEnumExistingResult\.parent == returnedEnumRegionIndex!.*?returnedEnumExistingResult\.typeId == returnedEnumReturn!\.typeId.*?3 => returnedEnumArmResultRank!.*?returnedEnumCandidateRank! > returnedEnumArmResultRank!' "returned enum arms preserve an exact direct terminal ahead of nested same-typed candidates"
Assert-Matches $typedFunctionLowering '(?s)repairReturnedEnumMatchResults results:.*?results\[returnedEnumMatch!\.parent\]\.kind == 1.*?results\[returnedEnumMatch!\.parent\]\.operand0 == returnedEnumMatchRepairIndex!.*?results\[returnedEnumMatch!\.parent\]\.typeId >= 0' "returned enum repair mutates only the match already selected by its exact return owner"
Assert-MatchCount $typedResolvedContextFinalize 'nodes -> sealFinalProjectedMatchSubjectsAndPayloads' 5 "projected enum subject and payload sealing runs at every bounded projected-method producer boundary"
Assert-Contains $typedCore '(finalPatternSubject!.kind == 27 or finalPatternSubject!.kind == 34)' "nested enum and subject when share canonical arm-payload repair"
Assert-Contains $typedCore 'finalPatternSubject!.operand0 < 0 => finalPatternSubjectNeedsRepair!' "missing nested enum subjects enter canonical payload repair"
Assert-Contains $typedFunctionLowering 'repairNestedEnumPayloadSubjects results: mut [TypedIrNode; ~] -> Unit' "nested enum payload subject repair has one shared lowering helper"
Assert-Matches $typedFunctionLowering '(?s)\[Int; ~\] => payloadByArm!.*?payloadCandidate\.kind == 29.*?payloadIndex! => payloadByArm!\[payloadCandidate\.parent\].*?-2 => payloadByArm!\[payloadCandidate\.parent\]' "nested enum payload subjects use one ambiguity-preserving arm index"
Assert-Matches $typedFunctionLowering '(?s)match!\.kind == 27 and match!\.operand0 < 0.*?owner\.kind == 19.*?results\[owner\.parent\]\.kind == 27.*?payloadByArm!\[ownerArm!\] => payload.*?payload => match!\.operand0' "nested enum payload repair requires an exact enclosing enum arm and unique payload"
Assert-Matches $typedResolvedContextSeal '(?s)nodes -> repairNestedEnumPayloadSubjects\s+# Enum payload bindings use.*?0 => enumPayloadTypeRepairIndex!' "nested enum subjects are repaired before enum payload typing"
Assert-Matches $typedFunctionLowering '(?s)\[Int; ~\] => resolvedRoleNameByAst!.*?receiverName\.symbol >= 0.*?prepared\.package\.symbols\[receiverSourceRange\.symbolStart \+ receiverName\.symbol\]\.kind == 35.*?receiverNameIndex => resolvedRoleNameByAst!' "structured callback receiver fallback indexes only exact semantic role names"
Assert-Matches $typedFunctionLowering '(?s)\[Int; ~\] => resolvedTypeByAst!.*?recursiveTypes\.expressions\[expressionTypeIndex!\] => expressionType.*?expressionType\.status == 0 and expressionType\.typeId >= 0.*?resolvedTypeByAst!\[expressionGlobalAst\] < 0.*?expressionType\.typeId => resolvedTypeByAst!\[expressionGlobalAst\]' "structured callback receiver types use one exact semantic AST index"
Assert-Matches $typedFunctionLowering '(?s)resolvedTypeByAst!\[sourceRange\.astStart \+ resolvedReceiver\.astNode\]\s+=> receiverTypeId!.*?roleTypeBySymbol!\[sourceRange\.symbolStart \+ resolvedReceiver\.symbol\]\s+=> exactRoleTypeId.*?receiverSymbol\.kind == 35 and exactRoleTypeId >= 0.*?exactRoleTypeId => receiverTypeId!' "structured callback receiver exact role-source type overrides stale use-site inference"
Assert-Matches $typedFunctionLowering '(?s)\[Int; ~\] => callTargetTokenByAst!.*?callTarget\.kind == 16 and callTarget\.parent >= 0.*?nodes\[receiverSourceRange\.astStart \+ callTarget\.parent\]\.kind == 10.*?callTarget\.payloadToken\s+=> callTargetTokenByAst!.*?callTargetTokenByAst!\[sourceRange\.astStart \+ call!\.astNode\] => callTargetToken.*?tokens\[sourceRange\.tokenStart \+ callTargetToken\]\.span\.start\s+=> receiverBoundary!.*?canonicalReceiverAst\.start \+ canonicalReceiverAst\.length <= receiverBoundary!.*?receiverAst\.start \+ receiverAst\.length <= receiverBoundary!' "structured callback receiver validation indexes the exact direct call-target token"
Assert-Matches $typedFunctionLowering '(?s)canonicalReceiverIndex! >= 0 -> if \{.*?canonicalReceiverAst\.start \+ canonicalReceiverAst\.length <= receiverBoundary!.*?-1 => canonicalReceiverIndex!.*?receiverByAst!.*?canonicalReceiverIndex! >= 0 -> if \{ canonicalReceiverIndex! => receiverIndex! \}.*?receiverIndex! < 0 -> if \{.*?resolvedRoleNameByAst!' "explicit post-target arguments cannot suppress structured role receiver recovery"
Assert-Matches $typedFunctionLowering '(?s)repairDirectFlowCallBindings results: mut \[TypedIrNode; ~\].*?binding!\.kind == 17.*?binding!\.flags != 1.*?call\.kind == 6.*?call\.parent == bindingIndex!.*?call\.operand0 == binding!\.operand0.*?call\.typeId >= 0.*?exactCallIndex! < 0.*?-2 => exactCallIndex!.*?results\[exactCallIndex!\]\.typeId => binding!\.typeId.*?exactCallIndex! => binding!\.operand0' "flow-call bindings adopt one exact direct call result and its canonical semantic type"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> repairNamedFlowReceiverCallPlans\(prepared, recursiveTypes, recursiveTypeFlags\)\s+nodes -> repairDirectFlowCallBindings' "direct flow-call binding repair follows canonical receiver-plan repair"
Assert-Contains $typedFunctionLowering 'sealNodeTypeIdentity node: mut TypedIrNode' "late payload typing shares one canonical type identity writer"
Assert-Matches $typedFunctionLowering '(?s)astBelongsTo sourceModule: Int, childAst: Int, ownerAst: Int.*?ancestor! == ownerAst.*?\.parent => ancestor!' "nested type wrappers use exact AST ancestry"
Assert-Contains $typedTypeQueries '(ownerSourceModule! -> astBelongsTo(payloadReference.typeAst, variantAst!, prepared))' "nominal enum payload references accept transparent type wrappers"
Assert-Matches $typedFunctionLowering '(?s)nominalVariantPayloadTypeIdByTag subjectType: typeIds\.SemanticType, tag: Int.*?candidate\.kind == 27 and candidate\.parent == subjectType\.symbol.*?ordinal! == tag.*?referenceIndexByTypeAst\[ownerRange\.astStart \+ candidate\.typeNode\].*?references\[referenceIndex\]\.typeId => payloadTypeId!' "canonical enum tag resolves its exact declared payload type"
Assert-Matches $typedFunctionLowering '(?s)sealFinalEnumArmTagsAndPayloads nodes: mut \[TypedIrNode; ~\].*?finalEnumVariantTag => finalEnumArm!\.opcode.*?nominalVariantPayloadTypeIdByTag\(finalEnumVariantTag, prepared, recursiveTypes\).*?nodes\[finalEnumArm!\.operand0\]\.kind == 29.*?sealNodeTypeIdentity\(finalEnumPayloadTypeId' "final enum tags seal nominal payload bindings before LLVM"
Assert-MatchCount $typedResolvedContextFinalize 'nodes -> sealFinalEnumArmTagsAndPayloads' 5 "enum arm tag and payload sealing runs at the initial and late bounded convergence boundaries plus the final projected-result consumer closure"
Assert-Matches $typedCore '(?s)UIntSize\(0\) => secondStart!.*?firstStart! => secondStart!.*?secondOperand! < 0 or childStart < secondStart!.*?childStart => secondStart!' "function lowering keeps the two earliest direct operands by source position"
Assert-Matches $typedCore '(?s)UIntSize\(0\) => entrySecondStart!.*?entryFirstStart! => entrySecondStart!.*?entrySecondOperand! < 0 or entryChildStart < entrySecondStart!.*?entryChildStart => entrySecondStart!' "entry lowering keeps the two earliest direct operands by source position"
Assert-Matches $typedFunctionLowering '(?s)Recover only one exact.*?explicitArgumentNameToken! != explicitArgumentName\.nameToken.*?explicitArgumentBindingCandidate\.kind == 17.*?explicitArgumentBindingCandidate\.symbol == explicitArgumentSymbol!.*?explicitArgumentBindingCandidate\.nextOperand == callIndex!.*?results\[explicitArgumentBindingCandidate\.operand0\]\.kind == 5.*?explicitArgumentBindingSearch! => explicitArgumentBinding!.*?-1 => explicitArgument!\.nextOperand.*?explicitArgumentBinding! => call!\.operand1' "late two-parameter flow call links only its exact mutable binding storage edge and consumes the old call continuation"
Assert-Matches $semanticResolve '(?s)nameAst\.payloadToken \+ 1 => referenceSuffixToken!.*?nameAst\.firstToken \+ nameAst\.tokenCount => referenceEndToken.*?referenceSuffix\.span\.length == 1.*?source -> byte\(referenceSuffix\.span\.start\)\) == 33.*?true => referenceMutableSuffix!.*?candidate\.kind == 9 or candidate\.kind == 61.*?candidate\.flags % 2 == 1.*?referenceMutableSuffix! and not candidateMutableSuffix.*?candidateMutableSuffix and not referenceMutableSuffix!.*?mutableSuffixMismatch -> if \{ false => namesEqual! \}' "name resolution preserves the mutable bang suffix as part of local semantic identity"
Assert-Matches $typedCore '(?s)canonicalReference!\.symbol >= 0.*?canonicalReferenceSymbol\.kind == 9 or canonicalReferenceSymbol\.kind == 61.*?canonicalReferenceSymbol\.flags % 2 == 1 => canonicalReferenceSymbolMutable!.*?canonicalReferenceMutableMismatch.*?canonicalReferenceCandidate\.symbol == canonicalReference!\.symbol or \(canonicalReferenceSymbolIsBinding! and not canonicalReferenceMutableMismatch\)' "late local reference recovery preserves exact symbols and limits storage aliases to the same mutable-name capability"
Assert-Matches $functions '(?s)\[Bool; ~\] => lateMoveConsumedSymbols!.*?lateMoveCall\.kind == 6.*?callTargetParameter\(lateMoveArgumentOrdinal!, context, state\).*?flags % 2 == 1.*?lateMoveArgumentIndex! -> ownedValueSourceIndex.*?lateMoveSource\.kind == 5.*?lateMoveSource\.sourceModule == function\.sourceModule.*?true => lateMoveConsumedSymbols!\[lateMoveSource\.symbol\].*?lateMoveConsumedSymbols!\[ownedParameter\.symbol\].*?true => ownedParameterMoved!' "final resolved move calls feed one function-local consumed-symbol index before parameter cleanup"
Assert-Matches $ownership '(?s)owningBindingSourceParameterSymbol bindingIndex: Int.*?binding\.kind == 17 and binding\.operand0 >= 0.*?context\.ir\[binding\.operand0\] => directBindingSource.*?parameterIndexForFunction\(functionIndex, directBindingSource\.symbol\).*?context\.ir\[directParameterIndex\]\.flags % 2 == 1.*?directBindingSource\.symbol => resolved!.*?resolved! < 0.*?binding\.operand0 -> ownedValueSourceIndex.*?parameterIndexForFunction\(functionIndex, bindingSource\.symbol\).*?context\.ir\[sourceParameterIndex\]\.flags % 2 == 1.*?bindingSource\.symbol => resolved!' "owning lexical bindings preserve exact direct and canonical fallback move-parameter identity without a nominal ownership guess"
Assert-Matches $ownership '(?s)writeCleanupValueName valueIndex: Int, parameterIndex: Int, functionIndex: Int.*?parameterIndex >= 0.*?writeParameterReference\(functionIndex, context\.ir\[parameterIndex\]\.symbol\).*?%v\$\(valueIndex\)' "all cleanup consumers share one exact parameter-or-SSA value writer"
Assert-Matches $functions '(?s)lateMoveCallIndex! -> owningBindingSourceParameterSymbol\(functionIndex, context, state\).*?lateMoveCall\.parent == function\.operand0.*?lateMoveConsumedSymbols!\[lateMoveBindingParameterSymbol\].*?not ownedParameterMoved!' "normal-return cleanup transfers a root move parameter to its owning local"
Assert-Matches $functions '(?s)dropCandidate\.operand0 => dropCandidateDropValueIndex.*?dropIndex! -> owningBindingSourceParameterSymbol\(functionIndex, context, state\).*?parameterIndexForFunction\(functionIndex, dropCandidateParameterSymbol\).*?dropCandidateValueIndex! -> writeCleanupValueName\(dropCandidateParameterIndex!, functionIndex, context, state\).*?dropCandidateParameterIndex! >= 0 -> if \{ 3 => dropEnumValueKind! \}.*?dropCandidateParameterIndex! >= 0 -> if \{ 3 => dropCandidateValueKind! \}.*?valueIndex: dropCandidateParameterIndex! >= 0.*?bindingIndex: dropCandidateBindingIndex' "normal-return scalar, enum, and nominal cleanup share exact transferred parameter identity"
Assert-Matches $containers '(?s)ownedDropIndex! -> owningBindingSourceParameterSymbol\(ownedDropOwner!, context, state\).*?parameterIndexForFunction\(ownedDropOwner!, ownedDropParameterSymbol\).*?ownedDropParameterIndex!.*?3 => ownedDropValueKind!.*?valueIndex: ownedDropParameterIndex! >= 0.*?bindingIndex: ownedDropIndex!' "early-return projected cleanup preserves the lexical binding while naming its transferred parameter ABI source"
Assert-NotContains $containers 'writeOwnedDropValueName' "early-return cleanup does not retain a private duplicate value-name resolver"
Assert-Matches $ownership '(?s)owningBindingTransfersParameterBeforeEdge bindingIndex: Int.*?edgeAncestor! == bindingRegion.*?binding -> sourceStart.*?context\.ir\[edgeIndex\] -> sourceStart.*?true => transferred!' "early-return ownership transfer requires lexical dominance and source precedence"
Assert-Matches $controlRegions '(?s)returnBindingTransferIndex! < regionNodeIndex.*?owningBindingTransfersParameterBeforeEdge.*?not returnParameterTransferred!.*?emitWholeParameterDrop' "early-return cleanup shares the owning-binding transfer predicate before dropping a move parameter"
Assert-Matches $ownership '(?s)partialMoveActiveAtAssignment moveIndex: Int, assignmentIndex: Int.*?candidateMove\.regionIr == \(assignmentIndex -> moveRegionFor.*?search! != assignmentIndex.*?earlierAssignment -> sourceStart.*?< assignmentStart.*?false => active!' "field reinitialization observes the partial move immediately before its own assignment"
Assert-Contains $containers 'partialMoveActiveAtAssignment(request.nodeIndex, context, state)' "member assignment uses the assignment-boundary partial-move predicate"
Assert-Matches $typedFunctionLowering '(?s)sealNominalEnumPayloadsByArmTags results: mut \[TypedIrNode; ~\].*?arm\.kind == 19 and arm\.opcode >= 0.*?nominalVariantPayloadTypeIdByTag\(arm\.opcode, prepared, recursiveTypes\).*?sealNodeTypeIdentity\(payloadTypeId.*?reference!\.kind == 5.*?results\[reference!\.operand0\]\.kind == 29.*?binding\.typeId => reference!\.typeId' "final nominal enum tag pass seals payload bindings and their direct reads"
Assert-Contains $typedFunctionLowering 'subjectIndex! >= 0 and results[subjectIndex!].operand0 != propagatedReadIndex!' "exact Result payload edge outranks a provisional enum subject"
Assert-Contains $typedValueAliases 'sealLateResultPropagations nodes: mut [TypedIrNode; ~]' "linear late Result propagation closure"
Assert-Contains $typedValueAliases 'resultValueByPropagation![propagationParent!]' "exact propagation-parent canonical Result value index"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealLateResultPropagations\(frozenRecursiveSemanticTypes, recursiveTypeFlags\).*?nodes -> sealNominalEnumPayloadsByArmTags\(frozenRecursiveSemanticTypes, recursiveTypeFlags, prepared, recursiveTypes\).*?0 => finalControlCallIndex!' "final nominal enum payload sealing runs after indexed propagation repair and before call-plan cleanup"
Assert-MatchCount $typedCore 'nodes -> sealPathRuntimeOpcodes\(prepared\)' 3 "path intrinsic opcode sealing follows all runtime-identity producer checkpoints"
Assert-Contains $coreCalls "isIntrinsicDeclaration node:" "bodyless intrinsic declaration predicate"
Assert-Matches $coreCalls '(?s)isNativeDeclarationSymbol sourceModule:.*?ruleIdNativeFunctionDeclaration' "foreign ABI exact native-library declaration identity"
Assert-Matches $coreCalls '(?s)isNativeFunction node:.*?isIntrinsicDeclaration.*?isNativeDeclarationSymbol' "foreign ABI function declaration restriction"
Assert-Matches $coreCalls '(?s)targetsNativeFunction node:.*?targetsImportedLibraryFunction.*?isNativeDeclarationSymbol' "foreign ABI call-target declaration restriction"
Assert-Matches $coreCalls '(?s)targetsNativeTry node:.*?isNativeDeclarationSymbol.*?32768' "foreign ABI fallible call-target declaration restriction"
Assert-Contains $text "not (context.ir[functionIndexCollect!] -> isIntrinsicDeclaration)" "intrinsic method body exclusion"
Assert-Contains $pathIntrinsicFixture "public pathText: self -> Text = intrinsic" "path intrinsic positive fixture"
Assert-Contains $pathOrdinaryFixture "ordinary pathText = misclassified" "path intrinsic same-name negative fixture"
Assert-Contains $directoryIntrinsicFixture 'directory-runtime=$(lowered!),ordinary=$(ordinary!),intrinsic=$(declarationIntrinsic)' "directory intrinsic late-resolution fixture"
Assert-Contains $typedCore "finalDirectoryIntrinsicIndex!" "final directory intrinsic identity pass"
Assert-Contains $typedCore "public isSocketResultOpcode" "socket Result opcode predicate"
Assert-Contains $typedCore "opcode <= -258 and opcode >= -270" "first socket opcode interval"
Assert-Contains $typedCore "opcode <= -272 and opcode >= -274" "second socket opcode interval"
Assert-Contains $typedCore "or opcode == -279" "socket setNoDelay opcode"
Assert-Contains $typedCore "or opcode == -280" "socket noDelay opcode"
Assert-Contains $typedCore "opcode <= -281 and opcode >= -284" "socket timeout opcode interval"
Assert-Contains $typedCore "or opcode == -287" "socket receiveFromInto opcode"
Assert-Contains $typedCore "opcode <= -289 and opcode >= -296" "socket send-range, receive-append, peek, keep-alive, and linger opcode interval"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "setNoDelay")' "socket setNoDelay intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "noDelay")' "socket noDelay intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "setReadTimeout")' "socket setReadTimeout intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "readTimeout")' "socket readTimeout intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "setWriteTimeout")' "socket setWriteTimeout intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "writeTimeout")' "socket writeTimeout intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "receiveFromInto")' "socket receiveFromInto intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "peekFromInto")' "socket peekFromInto intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "peekInto")' "socket peekInto intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "setKeepAlive")' "socket setKeepAlive intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "keepAlive")' "socket keepAlive intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "setLinger")' "socket setLinger intrinsic identity"
Assert-Contains $typedCore 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "linger")' "socket linger intrinsic identity"
Assert-Contains $coreCalls "context.ir[callIndex].opcode == -287" "socket receiveFromInto mutable-buffer ABI"
Assert-Contains $coreCalls "context.ir[callIndex].opcode == -291" "socket peekFromInto mutable-buffer ABI"
Assert-Contains $coreCalls "context.ir[callIndex].opcode == -292" "socket peekInto mutable-buffer ABI"
Assert-Contains $platformIo '@sollang_platform_socket_receive_from(i64 %v$(request.callIndex)_socket_handle, ptr %v$(request.callIndex)_socket_receive_buffer, i64 %v$(request.callIndex)_socket_receive_capacity' "socket receiveFromInto direct platform call"
Assert-Contains $platformIo 'writeSocketReceiverType valueIndex: Int' "reference-backed socket receiver canonical type writer"
Assert-Contains $platformIo 'writeSocketReceiverValue valueIndex: Int' "reference-backed socket receiver materialized SSA writer"
Assert-Contains $platformIo 'firstValueIndex -> writeSocketReceiverType(context, state)' "socket intrinsic receiver type normalization"
Assert-Contains $platformIo 'firstValueIndex -> writeSocketReceiverValue(request.ownerIndex, context, state)' "socket intrinsic receiver value normalization"
Assert-Contains $platformIo 'call.opcode == -291 -> if { "2" -> print } else { "0" -> print }' "socket peekFromInto typed flag selection"
Assert-Contains $platformIo 'call.opcode == -292 -> if { "2" -> print } else { "0" -> print }' "socket peekInto typed flag selection"
Assert-Contains $platformIo 'call.opcode == -272 or call.opcode == -292 -> if {' "socket receiveInto and peekInto success length publication"
Assert-Contains $platformIo 'call.opcode == -293 or call.opcode == -294 -> if {' "socket keep-alive typed lowering"
Assert-Contains $platformIo '@sollang_platform_socket_set_linger(i64 %v$(request.callIndex)_socket_handle' "socket linger setter direct lowering"
Assert-Contains $platformIo '@sollang_platform_socket_linger(i64 %v$(request.callIndex)_socket_handle)' "socket linger getter direct lowering"
Assert-Matches $platformIo 'call\.opcode == -282 or call\.opcode == -284 or call\.opcode == -296\s*-> if \{' "socket duration option result materialization"
Assert-Contains $managedSemanticCompiler 'BoundFunctionKind.RuntimeSocketPeek' "managed socket peekInto typed intrinsic identity"
Assert-Contains $managedSemanticCompiler 'BoundFunctionKind.RuntimeSocketSetKeepAlive' "managed socket setKeepAlive typed intrinsic identity"
Assert-Contains $managedSemanticCompiler 'BoundFunctionKind.RuntimeSocketKeepAlive' "managed socket keepAlive typed intrinsic identity"
Assert-Contains $managedSemanticCompiler 'BoundFunctionKind.RuntimeSocketSetLinger' "managed socket setLinger typed intrinsic identity"
Assert-Contains $managedSemanticCompiler 'BoundFunctionKind.RuntimeSocketLinger' "managed socket linger typed intrinsic identity"
Assert-Contains $managedSocketEmitter 'BoundFunctionKind.RuntimeSocketPeek => EmitSocketReceiveInto' "managed socket peekInto typed lowering"
Assert-Contains $managedSocketEmitter 'BoundFunctionKind.RuntimeSocketSetKeepAlive => EmitSocketSetKeepAlive' "managed socket setKeepAlive typed lowering"
Assert-Contains $managedSocketEmitter 'BoundFunctionKind.RuntimeSocketKeepAlive => EmitSocketKeepAlive' "managed socket keepAlive typed lowering"
Assert-Contains $managedSocketEmitter 'BoundFunctionKind.RuntimeSocketSetLinger => EmitSocketSetLinger' "managed socket setLinger typed lowering"
Assert-Contains $managedSocketEmitter 'BoundFunctionKind.RuntimeSocketLinger => EmitSocketLinger' "managed socket linger typed lowering"
Assert-NotContains $managedSocketEmitter 'function.Name == "receiveAppend"' "managed socket lowering does not branch on receiveAppend name"
Assert-NotContains $managedSocketEmitter 'function.Name == "peekInto"' "managed socket lowering does not branch on peekInto name"
Assert-Contains $platformIo '_socket_datagram_receipt = insertvalue' "socket receiveFromInto receipt materialization"
Assert-Contains $platformIo '_socket_receive_length_address, align 8' "socket receiveFromInto success length publication"
Assert-Contains $platformIo '@sollang_platform_socket_set_' "socket timeout setter direct lowering prefix"
Assert-Contains $platformIo 'call.opcode == -281 -> if { "read" -> print } else { "write" -> print }' "socket timeout setter direction selection"
Assert-Contains $platformIo '@sollang_platform_socket_' "socket timeout getter direct lowering prefix"
Assert-Contains $platformIo 'call.opcode == -282 -> if { "read" -> print } else { "write" -> print }' "socket timeout getter direction selection"
Assert-Contains $platformIo '_timeout(i64 %v$(request.callIndex)_socket_handle' "socket timeout direct handle call"
Assert-MatchCount $socketRuntime 'define internal %sollang\.socket_result @sollang_platform_socket_(?:set_)?read_timeout' 4 "Windows/Linux socket read-timeout runtime definitions"
Assert-MatchCount $socketRuntime 'define internal %sollang\.socket_result @sollang_platform_socket_(?:set_)?write_timeout' 4 "Windows/Linux socket write-timeout runtime definitions"
Assert-MatchCount $socketRuntime 'define internal %sollang\.socket_result @sollang_platform_socket_(?:set_)?keep_alive' 4 "Windows/Linux socket keep-alive runtime definitions"
Assert-MatchCount $socketRuntime 'define internal %sollang\.socket_result @sollang_platform_socket_(?:set_)?linger' 4 "Windows/Linux socket linger runtime definitions"
Assert-MatchCount $socketRuntime '%checked_millis = select i1 %enabled, i64 %millis, i64 1' 2 "disabled linger never observes inactive Option payload"
foreach ($timeoutFunction in @(
    "sollang_platform_socket_set_read_timeout",
    "sollang_platform_socket_read_timeout",
    "sollang_platform_socket_set_write_timeout",
    "sollang_platform_socket_write_timeout"
)) {
    $selfhostDefinitions = @(Get-LlvmFunctionDefinitions $socketRuntime $timeoutFunction)
    $windowsDefinitions = @(Get-LlvmFunctionDefinitions $windowsSocketRuntime $timeoutFunction)
    $linuxDefinitions = @(Get-LlvmFunctionDefinitions $linuxSocketRuntime $timeoutFunction)
    if ($selfhostDefinitions.Count -ne 2 -or $windowsDefinitions.Count -ne 1 -or $linuxDefinitions.Count -ne 1) {
        throw "socket-timeout runtime parity definition count differs for $timeoutFunction"
    }
    if ($selfhostDefinitions[0].Value -cne $windowsDefinitions[0].Value -or
        $selfhostDefinitions[1].Value -cne $linuxDefinitions[0].Value) {
        throw "managed/self-host socket-timeout runtime differs for $timeoutFunction"
    }
}
foreach ($socketPolicyFunction in @(
    "sollang_platform_socket_set_keep_alive",
    "sollang_platform_socket_keep_alive",
    "sollang_platform_socket_set_linger",
    "sollang_platform_socket_linger"
)) {
    $selfhostDefinitions = @(Get-LlvmFunctionDefinitions $socketRuntime $socketPolicyFunction)
    $windowsDefinitions = @(Get-LlvmFunctionDefinitions $windowsSocketRuntime $socketPolicyFunction)
    $linuxDefinitions = @(Get-LlvmFunctionDefinitions $linuxSocketRuntime $socketPolicyFunction)
    if ($selfhostDefinitions.Count -ne 2 -or $windowsDefinitions.Count -ne 1 -or $linuxDefinitions.Count -ne 1) {
        throw "socket-policy runtime parity definition count differs for $socketPolicyFunction"
    }
    if ($selfhostDefinitions[0].Value -cne $windowsDefinitions[0].Value -or
        $selfhostDefinitions[1].Value -cne $linuxDefinitions[0].Value) {
        throw "managed/self-host socket-policy runtime differs for $socketPolicyFunction"
    }
}
Assert-Contains $typedCore "knownReserveExpression! -> if { -271 => expressionOpcode! }" "collection reserve opcode"
Assert-Contains $typedCore 'if { -275 => opcode! }' "compiler stream take opcode"
Assert-Contains $typedCore 'if { -276 => opcode! }' "compiler stream skip opcode"
Assert-Contains $typedCore 'expressionStreamSliceOpcode => expressionOpcode!' "function stream-slice identity"
Assert-Contains $typedCore 'entryStreamSliceOpcode => entryExpressionOpcode!' "entry stream-slice identity"
Assert-Contains $typedCore 'entryOperator!.kind == 17' "entry binding operand selection"
Assert-Contains $typedCore 'and entryChild.kind == 6' "entry collection-only widest-child selection"
Assert-Contains $typedCore 'entryChild.typeSymbol >= 5' "entry collection type lower bound"
Assert-Contains $typedCore 'entryChild.typeSymbol <= 7' "entry collection type upper bound"
Assert-Contains $typedCore '-1 => entryBindingWrapperResult!' "entry transparent-wrapper result selection"
Assert-Contains $typedCore 'true => entryBindingWrapperIsControl!' "entry transparent-wrapper control preference"
Assert-Contains $typedCore 'not entryBindingWrapperIsControl! and nodes[entryBindingControlSearch!].parent == entryBindingControlWrapper' "entry transparent-wrapper value fallback"
Assert-Contains $typedCore 'entryBindingWrapperResult! >= 0 -> if { entryBindingWrapperResult! => entryBindingControlResult!.operand0 }' "entry binding wrapper operand repair"
Assert-Contains $logicalBindingFixture '(first -> len) == (fifth -> len)' "four-term logical binding regression"
Assert-Contains $streamIr 'node.opcode == -275 -> if { 1 => kind! }' "stream take planner identity"
Assert-Contains $streamIr 'node.opcode == -276 -> if { 2 => kind! }' "stream skip planner identity"
Assert-Contains $typedCore "public isConsoleRuntimeCall" "canonical console runtime-call predicate"
Assert-Contains $typedCore "node.kind == 6 or node.kind == 9" "ordinary and materialized console forms"
Assert-Contains $typedCore "public isTransparentControlProducerWrapper" "canonical transparent control-producer wrapper predicate"
Assert-Matches $typedCore '(?s)public isTransparentControlProducerWrapper.*?node\.kind == 9.*?node\.symbol == -1.*?node\.targetModule == -1.*?node\.opcode == -1.*?node\.operand0 >= 0.*?node\.operand1 >= 0' "transparent control-producer wrapper exact identity"
Assert-Contains $typedCore "public isSetIntrinsicCall" "canonical ordinary-or-materialized Set intrinsic predicate"
Assert-Contains $typedCore "public isSetMutationCall" "canonical Set mutation predicate"
Assert-Contains $typedCore "site.kind == 9" "owned collection transfer representation guard"
Assert-Contains $typedCore "site.opcode == -204 or site.opcode == -252 or site.opcode == -255" "owned collection transfer opcode contract"
Assert-Contains $text "entryScheduleNode -> typedIr.isConsoleRuntimeCall" "materialized console scheduling"
Assert-Contains $text "entryExpression.kind == 6 or (entryExpression -> typedIr.isConsoleRuntimeCall)" "materialized console emission"
Assert-Contains $text "parallelCallbackIndex! -> irNodeReachable(context, state)" "reachable parallel callback emission"
Assert-Contains $text "parallelBranchCallbackIndex! -> irNodeReachable(context, state)" "reachable parallel-branch callback emission"
$reachableParallelCallbacks = ([regex]::Matches($text, 'parallelCallbackIndex! -> irNodeReachable\(context, state\)')).Count
$reachableParallelBranchCallbacks = ([regex]::Matches($text, 'parallelBranchCallbackIndex! -> irNodeReachable\(context, state\)')).Count
if ($reachableParallelCallbacks -ne 1 -or $reachableParallelBranchCallbacks -ne 1) {
    throw "parallel callback reachability consumers drifted: parallel=$reachableParallelCallbacks, branch=$reachableParallelBranchCallbacks"
}
$unfilteredParallelCallbacks = ([regex]::Matches($text, '(?m)^\s*parallelCallbackIndex! -> parallelUsesComputePool\(context, state\)')).Count
if ($unfilteredParallelCallbacks -ne 0) {
    throw "parallel callback emission regained an unfiltered all-IR consumer"
}
Assert-Contains $coreCalls 'parallelExpression.operand0 -> hasWorkerTransferArrayElement(context, state) => transferableInput' "recursively transferable parallel input classification"
Assert-Contains $coreCalls 'transferableInput and transferableOutput! -> if { true => supported! }' "nominal worker-transfer input and output eligibility"
Assert-NotContains $coreCalls '(parallelTargetCaptures -> len) > 0 -> if { true => supported! }' "capture presence cannot bypass worker input/output ABI validation"
Assert-NotContains $coreCalls 'not (context.ir[parallelTargetCaptures[parallelTargetCaptureIndex!]] -> ownsType)' "LLVM emitter does not duplicate semantic capture shareability"
Assert-Contains $coreCalls 'E18 rejects mutable bindings and E19 rejects' "semantic capture diagnostics remain the LLVM precondition"
Assert-Contains $coreCalls 'capture -> ownsType -> if { "ptr" -> print } else { capture -> writeIrType(context, state) }' "parallel capture environment preserves value versus borrow ABI"
Assert-Contains $coreCalls 'CaptureValueRequest { callerIndex: ownerIndex, callIndex: parallelIndex, bindingIndex: captureBindingIndex, captureIndex: captureIndex! } -> emitCaptureValue(context, state)' "parallel scalar and readonly-reference capture value materialization"
Assert-Matches $text '(?s)usesAes128Specialization and \(functionIndexCollect! -> isAes128EncryptBlockFunction\(context, state\)\).*?aesFunctionIndicesAfterEntry!.*?aesFunctionIndicesBeforeEntry!.*?regularFunctionIndicesAfterEntry!.*?regularFunctionIndicesBeforeEntry!' "function emission classifies AES specialization before parallel dispatch"
Assert-MatchCount $text 'functionEmitIndex -> emitFunction\(context, state\)' 2 "before-entry and after-entry regular emission use the proven exact worker target"
Assert-MatchCount $text 'aesFunctionIndices(?:Before|After)Entry!\[aesFunctionIndex!\] -> emitAes128FunctionSet\(context, state\)' 2 "before-entry and after-entry AES function sets remain ordered serial units"
Assert-NotMatches $text '(?s)aesFunctionIndices(?:Before|After)Entry! -> parallel.*?emitAes128FunctionSet' "interdependent AES function sets are not dispatched as ordinary parallel workers"
Assert-NotContains $text 'emitSelectedFunction' "function-emission callbacks do not add the crashing scalar-selection capture"
Assert-Contains $text 'parallelCallbackCapture -> ownsType -> if { "ptr" -> print } else { parallelCallbackCapture -> writeIrType(context, state) }' "parallel callback typed capture load"
Assert-Contains $text 'parallelCallbackArgument -> ownsType -> if { "ptr" -> print } else { parallelCallbackArgument -> writeIrType(context, state) }' "parallel callback typed capture argument"
Assert-NotContains $text '"  %capture_value_$(parallelCallbackCaptureIndex!) = load ptr, ptr %capture_address_$(parallelCallbackCaptureIndex!), align 8"' "parallel callback no longer coerces every capture to pointer"
Assert-Contains $parallelCallbackLlvmVerifier '$callbacks.Count -lt $MinimumCallbackCount' "generated compiler callback-count fail-fast gate"
Assert-Contains $parallelCallbackLlvmVerifier '$hasNominalInputAddress -and $hasNominalInputLoad' "generated compiler nominal input callback contract"
Assert-Contains $parallelCallbackLlvmVerifier '$hasNominalResultCall -and $hasNominalResultStore' "generated compiler nominal result callback contract"
Assert-Contains $parallelCallbackLlvmVerifier 'Do not benchmark or promote this compiler' "generated compiler actionable serial-fallback guidance"
Assert-Matches $managedParallelEmitter '(?s)StableCallSiteIdentities\.TryGetValue\(block, out var callSiteIdentity\).*?LlvmCodegenUnit\.StableIdentity\(callSiteIdentity\).*?parallel callback identity collision' "managed parallel callbacks use collision-checked stable call-site symbols"
Assert-NotContains $managedParallelEmitter '_parallelCallbacks.Count.ToString' "managed parallel callback symbols do not depend on discovery ordinals"
Assert-Contains $parallelCallbackCacheVerifier 'Insert a callback before the unchanged module' "callback cache regression mutates a preceding callback schedule"
Assert-Contains $parallelCallbackCacheVerifier 'byte-identical incremental and cold LLVM' "callback cache regression compares partial reuse to a cold build"
Assert-Contains $parallelCallbackCacheVerifier 'Assert-Product $incrementalOutput "14"' "callback cache regression executes the partially reused binary"
Assert-Contains $incrementalVerifier 'verify-selfhost-parallel-callback-llvm.ps1' "incremental Stage2 generated callback gate"
Assert-Contains $incrementalVerifier 'compiler-emission-fingerprint.ps1' "incremental bootstrap pair shared input fingerprint"
Assert-Contains ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts/measure-selfhost-compiler-emission.ps1'))) 'compiler-emission-fingerprint.ps1' "profile producer shared input fingerprint"
Assert-Contains $compilerEmissionFingerprint '$hash.AppendData([byte[]]@(0))' "compiler-emission fingerprint field delimiters"
Assert-Contains $stage2Verifier 'verify-selfhost-parallel-callback-llvm.ps1' "formal Stage2 generated callback gate"
Assert-Contains $stage3Verifier 'verify-selfhost-parallel-callback-llvm.ps1' "formal Stage3 generated callback gate"
& $parallelCallbackLlvmVerifierPath `
    -LlvmPath $parallelCallbackLlvmValidFixturePath `
    -MinimumCallbackCount 4 `
    -RequireNominalTransfer
$serialFallbackAccepted = $false
try {
    & $parallelCallbackLlvmVerifierPath `
        -LlvmPath $parallelCallbackLlvmSerialFixturePath `
        -MinimumCallbackCount 4 `
        -RequireNominalTransfer
    $serialFallbackAccepted = $true
} catch {
    # Expected: a compiler with only the three historical callbacks is not a
    # C82 performance candidate.
}
if ($serialFallbackAccepted) {
    throw "generated compiler callback verifier accepted the serial-fallback negative control"
}
Assert-NotContains $text "(parallelBranchExpression.kind == 38 and context.supportsComputePool)" "parallel-branch callback emission"
Assert-Contains $functionScheduling "scheduleNode -> typedIr.isConsoleRuntimeCall" "function materialized console scheduling"
Assert-Contains $functionScheduling "scheduleNode -> typedIr.isSetIntrinsicCall" "function ordinary-or-materialized Set scheduling"
Assert-Matches $functionScheduling '(?s)Block intrinsics own their operand1 callback region.*?scheduleNode\.opcode != -207.*?scheduleNode\.opcode != -208.*?scheduleNode\.opcode != -209.*?scheduleNode\.operand0 >= expressionStart' "block callback regions excluded from ordinary call-argument scheduling"
Assert-Matches $text 'entryExpression\.opcode - 1_000_000 => entryArrayCapacity!\s+\}' "entry reservation changes capacity only"
Assert-Matches $functions 'expression\.opcode - 1_000_000 => arrayCapacity!\s+\}' "function reservation changes capacity only"
Assert-Matches $control 'regionNode\.opcode - 1_000_000 => regionArrayCapacity!\s+\}' "control-region reservation changes capacity only"
Assert-Matches $containers 'valueNode\.opcode - 1_000_000 => whileArrayCapacity!\s+\}' "loop reservation changes capacity only"
Assert-Contains $text 'context.types[entryExpression.typeId].length => entryArrayLength!' "entry fixed repeat length uses canonical type"
Assert-Contains $functions 'context.types[expression.typeId].length => arrayLength!' "function fixed repeat length uses canonical type"
Assert-Contains $control 'context.types[regionNode.typeId].length => regionArrayLength!' "control-region fixed repeat length uses canonical type"
Assert-Contains $containers 'context.types[valueNode.typeId].length => whileArrayLength!' "loop fixed repeat length uses canonical type"
Assert-Contains $functionScheduling "mutableReadBarrier -> typedIr.isSetMutationCall" "function Set mutation barrier"
Assert-Contains $functionScheduling "mutableReadBarrier.kind == 6 and (mutableReadBarrier -> typedIr.isSetMutationCall)" "function ordinary Set mutation barrier"
Assert-Contains $functionScheduling "mutableReadBarrier.opcode == -253 or mutableReadBarrier.opcode == -256" "function materialized Set scheduling compatibility"
Assert-Contains $functionScheduling 'isSchedulingMutationIntrinsic node:' "shared mutation barrier catalog"
Assert-Contains $functionScheduling 'node.opcode == -271' "reserve participates in mutation ordering"
Assert-Contains $text 'isEntrySchedulingControl node:' "entry control barrier catalog"
foreach ($entryControlRole in @('entryMutableReadBarrier', 'entryScheduleNode', 'context.ir[entryEffectAncestor!]', 'entryEarlierEffect', 'context.ir[entryEarlierEffectAncestor!]')) {
    Assert-Contains $text "$entryControlRole -> isEntrySchedulingControl" "entry control ordering for $entryControlRole"
}
foreach ($barrierRole in @('schedulingBarrier', 'mutableReadBarrier', 'scheduleNode', 'context.ir[effectAncestor!]', 'earlierEffect')) {
    Assert-Contains $functionScheduling "$barrierRole -> isSchedulingMutationIntrinsic" "shared mutation ordering for $barrierRole"
}
Assert-Contains $functions "expression.kind == 6 or (expression -> typedIr.isConsoleRuntimeCall)" "function materialized console emission"
Assert-Contains $functions "expression -> typedIr.isSetIntrinsicCall" "function ordinary-or-materialized Set emission"
Assert-Contains $functions "not (expression -> typedIr.isSetIntrinsicCall)" "function generic-call Set exclusion"
Assert-NotContains $functions "expression.kind == 9 and expression.opcode <= -255" "function kind-9-only Set dispatch"
Assert-Contains $control "regionNode.kind == 6 or (regionNode -> typedIr.isConsoleRuntimeCall)" "control-region materialized console emission"
Assert-Contains $control "regionNode -> typedIr.isSetIntrinsicCall" "control-region ordinary-or-materialized Set emission"
Assert-Contains $control "not (regionNode -> typedIr.isSetIntrinsicCall)" "control-region generic-call Set exclusion"
Assert-NotContains $control "regionNode.kind == 9 and regionNode.opcode <= -255" "control-region kind-9-only Set dispatch"
Assert-Contains $text "entryExpression -> typedIr.isSetIntrinsicCall" "entry ordinary-or-materialized Set emission"
Assert-Contains $text "not (entryExpression -> typedIr.isSetIntrinsicCall)" "entry generic-call Set exclusion"
Assert-Contains $text "entryMutableReadBarrier.kind == 6 and (entryMutableReadBarrier -> typedIr.isSetMutationCall)" "entry ordinary Set mutation barrier"
Assert-NotContains $text "entryExpression.kind == 9 and entryExpression.opcode <= -255" "entry kind-9-only Set dispatch"
Assert-Contains $invariants "not (node -> typedIr.isConsoleRuntimeCall)" "unsupported console-effect invariant"
$transparentControlProducerExclusions = ([regex]::Matches($invariants, 'not \(node -> typedIr\.isTransparentControlProducerWrapper\)')).Count
if ($transparentControlProducerExclusions -ne 2) {
    throw "S047 and V006 must share exactly two transparent control-producer exclusions; found $transparentControlProducerExclusions"
}
Assert-Contains $invariantDiagnostics "compiler verification failure V003" "unsupported console-effect compiler diagnostic"
Assert-Matches $invariants '(?s)# No unresolved call sentinel.*?and \(node\.kind == 6.*?node\.kind == 9.*?irNodeHasSetType.*?node\.operand1 >= 0.*?nextOperand >= 0.*?and node\.symbol == -1.*?if \{ 50 => code! \}' "unresolved ordinary or materialized call sentinel invariant"
Assert-Contains $invariantDiagnostics "compiler verification failure V006" "unresolved call sentinel compiler diagnostic"
Assert-Contains $invariantDiagnostics 'alias $(unresolvedCallBinding!)/$(unresolvedCallBindingType!)/$(unresolvedCallBindingOrigin!)/$(unresolvedCallBindingSymbol!)/$(unresolvedCallProducer!)/$(unresolvedCallProducerKind!)/$(unresolvedCallProducerType!)/$(unresolvedCallProducerOrigin!)/$(unresolvedCallProducerSymbol!)' "V006 value-alias producer diagnostic"
Assert-MatchCount $typedCore "knownCall.sourceModule == sourceIndex and knownCall.callAst == expressionAstIndex and knownCall.status == 2" 1 "function unresolved call classification"
Assert-MatchCount $typedCore "knownEntryCall.sourceModule == sourceIndex and knownEntryCall.callAst == entryExpressionAst! and knownEntryCall.status == 2" 1 "entry unresolved call classification"
Assert-MatchCount $typedCore "and unresolvedCallExpression!" 1 "function unresolved flow projection guard"
Assert-MatchCount $typedCore "and unresolvedEntryCallExpression!" 1 "entry unresolved flow projection guard"
Assert-Matches $typedCore '(?s)not resolvedQualifiedLeaf!.*?unresolvedLibraryInvocation! or unresolvedCallExpression!.*?expression\.kind == 10 and \(unresolvedLibraryInvocation! or unresolvedCallExpression! or insertIntrinsicSpelling!\).*?6 => expressionKind!' "function provisional unresolved flow call survives for late receiver resolution without replacing a resolved qualified leaf"
Assert-Matches $typedCore '(?s)not resolvedEntryQualifiedLeaf!.*?unresolvedEntryLibraryInvocation! or unresolvedEntryCallExpression!.*?entryExpression\.kind == 10 and \(unresolvedEntryLibraryInvocation! or unresolvedEntryCallExpression! or entryInsertIntrinsicSpelling!\).*?6 => entryExpressionKind!' "entry provisional unresolved flow call survives for late receiver resolution without replacing a resolved qualified leaf"
Assert-Matches $typedCore '(?s)finalFileMatchCandidate\.nextOperand == finalWrappedMatchIndex!.*?finalWrappedValueByNode!\[finalFileMatchCandidate\.parent\] == finalFileMatchSearch!.*?finalFileMatchCandidate\.kind == 6 or finalFileMatchCandidate\.kind == 9.*?and finalFileMatchCandidateOwnsMatch!.*?not finalFileMatchAmbiguous!.*?finalWrappedMatchIndex! => finalFileMatchSubjectNode!\.nextOperand.*?finalFileMatchSubject! => finalWrappedMatch!\.operand0' "late file Result producer uniquely owns its direct or exact transparent-wrapper match subject"
Assert-NotContains $typedCore "unresolvedFlowPathSearch!" "per-flow whole-AST library target scan"
Assert-NotContains $typedCore "unresolvedEntryFlowPathSearch!" "entry per-flow whole-AST library target scan"
Assert-Contains $invariantRules "public methodReceiverInvariantCode" "isolated method receiver invariant rule"
Assert-Contains $invariantRules "and not (parameterKind == 10" "method receiver parameter contract"
Assert-Contains $invariantRules "and receiverNameToken == selfToken" "method receiver symbol identity contract"
Assert-Contains $invariants "invariantRules.methodReceiverInvariantCode(" "V008 production rule integration"
Assert-Contains $receiverInvariantFixture 'import sollang.compiler.llvm.invariant_rules as invariantRules' "focused V008 pure rule import"
Assert-NotContains $receiverInvariantFixture 'import sollang.compiler.llvm.text as llvm' "focused V008 compiler-wide import"
Assert-Contains $invariantRules "public irParentOwnerAccepted" "isolated Typed IR parent-owner index rule"
Assert-Contains $invariantRules "public aggregateChildReplacesSelection" "isolated aggregate child selection rule"
Assert-Contains $invariants "irFunctionOwners context:" "linear Typed IR function-owner index"
Assert-Contains $corePrepare "context -> irFunctionOwners => functionOwnerByIrNode" "direct-child index shares the invariant owner map"
Assert-Contains $corePrepare "invariantRules.irParentOwnerAccepted(" "direct-child index excludes cross-function parent edges"
Assert-Contains $coreCalls "invariantRules.aggregateChildReplacesSelection(" "aggregate wrapper uses executable selection-order rule"
Assert-Contains $aggregateChildIndexRulesFixture 'irParentOwnerAccepted(2, 6, 4, 0)' "cross-owner index exclusion case"
Assert-Contains $aggregateChildIndexRulesFixture 'aggregateChildReplacesSelection(true, false, exactSelected!)' "aggregate fallback ordering case"
Assert-Contains $aggregateChildIndexRulesFixture 'aggregateChildReplacesSelection(true, true, exactSelected!)' "aggregate last-exact ordering case"
Assert-Contains $stage2Verifier '--exact 1395-selfhost-aggregate-child-index-rules' "Stage2 aggregate child index rule fixture"
Assert-Contains $stage3Verifier '--exact 1395-selfhost-aggregate-child-index-rules' "Stage3 aggregate child index rule fixture"
Assert-Contains $controlAllocasMeasurement 'phase = "control-allocas"' "Windows control-allocas evidence phase"
Assert-Contains $controlAllocasMeasurement 'selfhost-compiler-runtime.sources.txt' "Windows control-allocas runtime source closure"
Assert-Contains $controlAllocasMeasurement 'compilerSha256 = $compilerFingerprint' "Windows control-allocas compiler identity"
Assert-Contains $controlAllocasMeasurement 'sourceFingerprint = $sourceFingerprint' "Windows control-allocas source identity"
Assert-Contains $controlAllocasMeasurement 'inputStable = $sourceFingerprint -eq $endingSourceFingerprint' "Windows control-allocas input-stability gate"
Assert-Contains $controlAllocasMeasurement 'checkedDiagnosticsZero = $stdout.Contains(' "Windows control-allocas completion criterion"
Assert-Contains $controlAllocasMeasurement 'Invoke-VerificationProcessToFile' "Windows control-allocas bounded process execution"
Assert-Contains $typedCore "public isBuiltinTargetlessCall" "canonical targetless builtin-call predicate"
Assert-Contains $invariants "not (node -> typedIr.isBuiltinTargetlessCall)" "V006 targetless builtin exclusion"
Assert-Contains $expressionTypes "public builtinTypeApplicationSymbol" "single semantic builtin type-application spelling authority"
Assert-MatchCount $typedOrdinaryFunction "expressionTypes.builtinTypeApplicationSymbol" 1 "function builtin type-application identity consumer"
Assert-MatchCount $typedSourceLowering "expressionTypes.builtinTypeApplicationSymbol" 1 "entry builtin type-application identity consumer"
Assert-MatchCount $typedCore "and not targetlessBuiltinTypeApplication!" 1 "function resolved-call exclusion for targetless builtin type application"
Assert-MatchCount $typedCore "and not targetlessEntryBuiltinTypeApplication!" 1 "entry resolved-call exclusion for targetless builtin type application"
Assert-Contains $typedOrdinaryFunction 'directQualifiedCallIndex >= 0' "function qualified-flow proof"
Assert-Matches $typedOrdinaryFunction 'directQualifiedCallIndex >= 0\s+and expression\.kind == 10\s+-> if \{ false => targetlessBuiltinTypeApplication! \}' "function targetless override is limited to the outer flow AST"
Assert-Matches $typedOrdinaryFunction '(?s)resolvedCallIndex >= 0 and expression\.kind == 10.*?directResolvedFlowCall\.sourceModule == sourceIndex.*?directResolvedFlowCall\.callAst == expressionAstIndex.*?directResolvedFlowCall\.status == 0.*?false => targetlessBuiltinTypeApplication!' "function exact resolved local flow overrides outer builtin spelling"
Assert-Contains $typedOrdinaryFunction '-> if { false => targetlessBuiltinTypeApplication! }' "function qualified flow overrides outer builtin spelling"
Assert-Contains $typedSourceLowering 'directQualifiedEntryCallIndex >= 0' "entry qualified-flow proof"
Assert-Matches $typedSourceLowering 'directQualifiedEntryCallIndex >= 0\s+and entryExpression\.kind == 10\s+-> if \{ false => targetlessEntryBuiltinTypeApplication! \}' "entry targetless override is limited to the outer flow AST"
Assert-Matches $typedSourceLowering '(?s)entryResolvedCallIndex >= 0 and entryExpression\.kind == 10.*?directResolvedEntryFlowCall\.sourceModule == sourceIndex.*?directResolvedEntryFlowCall\.callAst == entryExpressionAst!.*?directResolvedEntryFlowCall\.status == 0.*?false => targetlessEntryBuiltinTypeApplication!' "entry exact resolved local flow overrides outer builtin spelling"
Assert-Contains $typedSourceLowering '-> if { false => targetlessEntryBuiltinTypeApplication! }' "entry qualified flow overrides outer builtin spelling"
Assert-MatchCount $calls "indexQualifiedPathCallOwners" 3 "single qualified-path call-owner index and both semantic consumers"
Assert-Matches $calls '(?s)indexQualifiedPathCallOwners.*?candidate\.kind == 11 and candidate\.cstRuleId == grammar\.ruleIdCallExpression\(\).*?candidate\.parent => ancestor!.*?ancestorNode\.kind == 36 and ancestorNode\.start == candidate\.start.*?candidate\.length < nodes\[nodeOffset \+ existingOwner\]\.length.*?callOwnerSearch! => owners!\[ancestor!\]' "qualified paths index the smallest exact nested call owner through AST ancestry"
Assert-MatchCount $calls "or qualifiedPathCallOwners\[moduleQualifiedCall.pathAst\] == callAstIndex!" 2 "standalone and prepared qualified-call discovery route nested paths to their exact call owner"
Assert-Contains $text "entryExpression -> typedIr.isBuiltinIntegerConversionCall" "entry builtin integer conversion classification"
Assert-Contains $functions "expression -> typedIr.isBuiltinIntegerConversionCall" "function builtin integer conversion classification"
Assert-Contains $control "regionNode -> typedIr.isBuiltinIntegerConversionCall" "control builtin integer conversion classification"
Assert-Contains $typed 'and node.operand1 < 0' "builtin integer conversion accepts exactly one linked argument"
Assert-Contains $control 'ast-span $(propagationCandidateAstFound!)/$(propagationCandidateAstStart!)/$(propagationCandidateAstLength!)' "result propagation diagnostics include candidate AST spans"
Assert-Contains $invariantDiagnostics 'V006 ast candidate' "unresolved-call diagnostics include local AST topology"
Assert-Contains $text "entryExpression -> typedIr.isArenaConstructorCall" "entry Arena constructor classification"
Assert-Contains $functions "expression -> typedIr.isArenaConstructorCall" "function Arena constructor classification"
Assert-Contains $control "regionNode -> typedIr.isArenaConstructorCall" "control Arena constructor classification"
Assert-Contains $ownership "referenceValueTypeId node:" "canonical general reference-value type resolver"
Assert-Contains $functions "expression -> referenceValueTypeId(context, state)" "function readonly reference parameter materialization"
Assert-Contains $control "regionNode -> referenceValueTypeId(context, state)" "control-region readonly reference parameter materialization"
Assert-Contains $coreCalls "forwardedReferenceArgument!" "readonly reference argument pointer forwarding"
Assert-Contains $coreCalls 'referencedTypeId -> sameNominalTypeIdentity(context.ir[parameterIndex].typeId, context)' "imported nominal readonly-reference value materialization"
Assert-Contains $coreCalls 'aggregateWrapperValueTypeId!' "transparent reference wrapper payload type authority"
Assert-Contains $coreCalls 'aggregateCandidateTypeId -> sameNominalTypeIdentity(aggregateWrapperValueTypeId!, context)' "transparent reference wrapper nominal candidate selection"
Assert-Contains $coreCalls 'directAggregateValueTypeId -> sameNominalTypeIdentity(aggregateWrapperValueTypeId!, context)' "transparent reference wrapper direct-edge selection"
Assert-Contains $containers 'callArgumentNeedsReferenceValueLoad(callIndex, ordinal, context, state)' "while-region readonly-reference value materialization"
Assert-Contains $coreCalls "writeForwardedReferenceValue ownerIndex:" "canonical forwarded readonly-reference resolver"
Assert-Contains $coreCalls "valueIndex -> referencePlaceRootBindingForEmission(ownerIndex, context, state)" "forwarded readonly-reference exact binding-edge resolution"
Assert-Contains $coreCalls "rootBinding -> writeReferenceRootAddress(ownerIndex, context, state)" "forwarded readonly-reference initializer pointer emission"
Assert-Contains $coreCalls "callOwnerIndex -> writeForwardedReferenceValue(argumentValueIndex, context, state)" "canonical readonly reference argument address writer"
Assert-Contains $emitterDiagnostics 'requires an addressable owner or reference; literals and temporary values cannot be borrowed; bind the value to an immutable name before passing it by ref' "actionable E22 temporary-borrow diagnostic"
Assert-NotContains $coreCalls "argumentValueIndex -> writeReferencePlaceValue(callOwnerIndex, context, state)" "reversed readonly reference address-writer arguments"
Assert-NotContains $invariants "invariantCode != 50" "V006 whole-IR applicability"
Assert-NotContains $invariantDiagnostics "irInvariantApplies" "V006 diagnostic reachability bypass"
Assert-Contains $typeIds "public classify sourceTypes: ref [SemanticType; ~], sourceFields: ref [NominalField; ~]" "readonly semantic trait-classification inputs"
Assert-Contains $typeIds 'intrinsicQualifiedTypeSymbol package: ref analysis.PackageAnalysis' "qualified intrinsic type identity helper"
Assert-Contains $typeIds 'expected: "sys.file"' "qualified SourceText requires the exact intrinsic module path"
Assert-Contains $typeIds 'expected: "SourceText"' "qualified SourceText requires the exact intrinsic type name"
Assert-Contains $ownershipCaptureExpected 'qualifiedSourceText=0, unrelatedSourceText=1' "qualified SourceText positive and unrelated-module negative controls"
Assert-NotContains $typeClassification "[SemanticType; ~] => types!" "semantic trait-classification full type-table copy"
Assert-NotContains $typeClassification "[NominalField; ~] => fields!" "semantic trait-classification full field-table copy"
Assert-Contains $typeClassification "[Int; ~] => firstFieldByOwner!" "semantic trait-classification owner field index"
Assert-Contains $typeClassification "nextFieldByIndex![fieldIndex!] => fieldIndex!" "semantic trait-classification owner field traversal"
Assert-NotContains $typeClassification "fieldIndex! < (sourceFields -> len)" "semantic trait-classification type-by-all-fields scan"
Assert-NotContains $typedCore "[typeIds.SemanticType; ~] => classificationTypes!" "Typed IR trait-classification type-table adapter copy"
Assert-NotContains $typedCore "[typeIds.NominalField; ~] => classificationFields!" "Typed IR trait-classification field-table adapter copy"
Assert-NotContains $textContext "[typeIds.SemanticType; ~] => classificationTypes!" "LLVM context trait-classification type-table adapter copy"
Assert-NotContains $textContext "[typeIds.NominalField; ~] => classificationFields!" "LLVM context trait-classification field-table adapter copy"
Assert-Contains $typedCore "finalizedSetCallIndex" "late Set intrinsic classification after binding recovery"
Assert-Contains $typedCore "finalizedSetCall!.kind == 6 or finalizedSetCall!.kind == 9" "ordinary and materialized late Set intrinsic forms"
Assert-Contains $typedCore "finalizedSetReceiverTypeId" "late Set canonical receiver type recovery"
Assert-Contains $typedCore "finalizedSetReceiverAstTypeId" "late Set receiver-AST type recovery"
Assert-Contains $typedCore "finalizedSetAstReceiverTypeId" "late Set call-AST receiver type recovery"
$projectedMethodPosition = $typedResolvedContextFinalize.IndexOf("nodes -> resolveFinalProjectedMethods(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags)", [StringComparison]::Ordinal)
$socketIntrinsicPosition = $typedResolvedContextFinalize.IndexOf("0 => finalSocketIntrinsicIndex!", [StringComparison]::Ordinal)
if ($projectedMethodPosition -lt 0 -or $socketIntrinsicPosition -le $projectedMethodPosition) {
    throw "canonical socket intrinsic classification must follow final projected method resolution"
}
Assert-Contains $invariants "irNodeHasSetType" "materialized Set V006 receiver classification"
Assert-Contains $emitterDiagnostics "reachableCandidate.kind == 11 => reachableCandidateIsRoot" "executable entry reachability root"
Assert-Contains $emitterContext "finalCallResolvedByAst: [Bool; ~]" "final call-convergence AST index"
Assert-Contains $textContext "finalCall.kind == 6" "final Typed IR call-convergence classification"
Assert-Contains $textContext "finalCall.symbol >= 0 and finalCall.targetModule >= 0" "final Typed IR direct-call convergence"
Assert-Contains $textContext "finalCallResolvedByAst![finalCallRange.astStart + finalCall.astNode]" "single-pass final call-convergence indexing"
Assert-Contains $emitterDiagnostics "context.finalCallResolvedByAst[finalCallAst]" "constant-time resolved-call diagnostic lookup"
Assert-NotContains $emitterDiagnostics "finalCallSearch! < (context.ir -> len)" "per-call full Typed IR diagnostic scan"
Assert-Contains $emitterDiagnostics "and not finalCallResolved!" "resolved inherent call diagnostic suppression"
Assert-Contains $emitterDiagnostics "emitOpenImportAmbiguity" "open-import candidate diagnostic reconstruction"
Assert-Contains $emitterDiagnostics "not emittedAmbiguity" "open-import diagnostic after ordinary resolution failure"
Assert-Contains $text 'functionHasDeclaredEffects! => functionHasDeclaredEffectsBySymbol![captureGlobalSymbolIndex]' "single-pass function effect classification"
Assert-Contains $functionScheduling 'state.frozenFunctionsHaveDeclaredEffectsBySymbol[targetGlobalSymbol] => hasEffects!' "constant-time scheduler effect lookup"
Assert-NotContains $functionScheduling 'targetFunctionIndex! < (context.ir -> len)' "per-effect-query full Typed IR function scan"
$effectBindingScanStart = $functionScheduling.IndexOf('expressionStart => scheduleCallBindingSearch!', [StringComparison]::Ordinal)
$effectBindingScanEnd = $functionScheduling.IndexOf('scheduleNode.opcode == -203', $effectBindingScanStart, [StringComparison]::Ordinal)
if ($effectBindingScanStart -lt 0 -or $effectBindingScanEnd -le $effectBindingScanStart) {
    throw "effectful-call binding scan contract markers are missing or reversed"
}
$effectBindingScan = $functionScheduling.Substring($effectBindingScanStart, $effectBindingScanEnd - $effectBindingScanStart)
$effectBindingOrder = @(
    'scheduleCallBindingSearch! < functionEnd',
    'and scheduleReady!',
    'scheduleCallBinding.kind == 17',
    'scheduleCallBinding.operand0 >= expressionStart',
    'scheduleCallBinding.operand0 < functionEnd',
    'not expressionScheduled![scheduleCallBindingSearch! - expressionStart]',
    'NodeAncestorRequest { nodeIndex: scheduleCandidate!, ownerIndex: scheduleCallBindingSearch! }',
    'scheduleCallBindingOwnerRequest -> irDescendsFrom(context, state)',
    'not scheduleCallInsideBinding',
    'scheduleCallBinding -> sourceStart(context, state)',
    'false => scheduleReady!',
    'scheduleCallBindingSearch! + 1 => scheduleCallBindingSearch!'
)
$effectBindingOffset = 0
foreach ($needle in $effectBindingOrder) {
    $nextEffectBindingOffset = $effectBindingScan.IndexOf($needle, $effectBindingOffset, [StringComparison]::Ordinal)
    if ($nextEffectBindingOffset -lt 0) {
        throw "effectful-call binding scan lost ordered contract '$needle'"
    }
    $effectBindingOffset = $nextEffectBindingOffset + $needle.Length
}
Assert-MatchCount $effectBindingScan 'false => scheduleReady!' 1 "effectful-call first blocker transition"
Assert-MatchCount $effectBindingScan 'true => scheduleReady!' 0 "effectful-call readiness cannot recover inside scan"
Assert-Matches $functionScheduling '(?s)not insideControlRegion\s+and \(pendingEach! < 0 or scheduleInsidePendingEach!\)\s+and scheduleNode.kind == 5.*?true => scheduleReady!' "immutable aggregate aliases preserve the active each scheduling boundary"
Assert-Matches $functionScheduling '(?s)controlDependencySearch! < functionEnd and scheduleReady!\s+-> while \{' "control dependency scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)priorControlValueSearch! < functionEnd and scheduleReady!\s+-> while \{' "prior control-value scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)mutableReadBarrierCursor! < \(schedulingBarrierIndices! -> len\)\s+and scheduleReady!\s+-> while \{' "mutable-read barrier scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)earlierEffectCursor! < \(schedulingBarrierIndices! -> len\)\s+and scheduleReady!\s+-> while \{' "earlier-effect barrier scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)scheduleCallArgument! >= expressionStart\s+and scheduleCallArgument! < functionEnd\s+and scheduleReady!\s+and \(\(scheduleCandidate! -> callTargetParameter' "call-argument scan stops at its first blocker"
Assert-Contains $functionScheduling 'scheduleSibling! >= 0 and scheduleReady! -> while {' "aggregate sibling scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)scheduleBranchArmDependency! >= 0 and scheduleReady!\s+-> while \{' "branch dependency scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)scheduleParallelBranchArgumentIndex! < \(scheduleParallelBranchArguments -> len\)\s+and scheduleReady!\s+-> while \{' "parallel argument scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)scheduleWhenArm! >= expressionStart and scheduleWhenArm! < functionEnd\s+and scheduleReady!\s+-> while \{' "when-arm scan stops at its first blocker"
Assert-Matches $functionScheduling '(?s)controlDirectOperandIndex! < 2 and scheduleReady!\s+-> while \{' "control direct-operand scan stops at its first blocker"
Assert-Contains $functionScheduling 'expressionInsideControlRegion![scheduleCandidate! - expressionStart] => insideControlRegion' "scheduler frozen control-containment lookup"
Assert-Contains $functionScheduling 'expressionInsideLogicalValue![scheduleCandidate! - expressionStart] => insideLogicalValue' "scheduler frozen logical-containment lookup"
Assert-MatchCount $functionScheduling 'ifConditionIndex! < functionEnd' 1 "single function-local if-condition root indexing pass"
Assert-NotContains $functionScheduling 'containmentIfSearch! < functionEnd' "per-expression full-function if-condition scan"
Assert-Contains $ownership 'sameNominalTypeIdentity leftTypeId: Int, rightTypeId: Int' "nominal enum payload identity guard"
# Recursive layout admission uses the complete dependency graph. Omitting a
# constructor/self payload was never a semantic rejection and misses mutual cycles.
Assert-Contains $textContext 'valueLayoutCycles' "by-value layout dependency graph"
Assert-Matches $textContext '(?s)valueLayoutCycles\(semanticFields!.*?not hasCyclicLayout! => aggregateLayoutChanged!' "cycle rejection precedes numeric layout iteration"
Assert-Contains $textContext 'recursiveTypes!.referenceIndexByTypeAst' "canonical annotation index reuse"
Assert-Contains $textContext '((current.kind == 4 and current.length > 0) or current.kind == 12)' "fixed and bounded array dependency edges"
Assert-Contains $textContext 'current.kind == 13' "bounded dictionary dependency edges"
Assert-Contains $invariants 'context.typeLayoutStatuses[index!] == 3' "invalid value-layout admission"
Assert-Contains $invariants '(context -> invalidValueLayoutType) >= 0 -> if { 1 -> return }' "single pre-LLVM recursive layout diagnostic"
Assert-Contains $invariantDiagnostics 'compiler error S058: type has a recursive by-value layout' "source-located recursive value diagnostic"
Assert-Contains $calls 'receiverField.ownerType == receiverTypeId! => receiverFieldOwnerMatches!' "projected receiver exact field owner"
Assert-Contains $calls 'receiverFieldOwnerType.module == receiverFieldReceiverType.module' "projected receiver canonical nominal field owner module"
Assert-Contains $calls 'receiverFieldOwnerType.symbol == receiverFieldReceiverType.symbol' "projected receiver canonical nominal field owner symbol"
Assert-Contains $calls 'and receiverRootBinding!' "projected receiver requires a lexical value root"
Assert-Contains $calls 'receiverRootParent.kind == 3 or receiverRootParent.kind == 4' "aggregate fields cannot become projected receiver roots"
Assert-Contains $calls 'receiverToken.span.start < receiverStart!' "projected receiver selects its earliest lexical root"
Assert-Contains $calls 'and not receiverInsideCallArgument!' "direct call arguments cannot become lexical receiver roots"
Assert-Contains $calls 'and directReceiverResult.callAst != local.callAst' "direct receiver producer scan excludes the current outer call"
Assert-Contains $calls 'and not (directReceiverCall.firstToken <= receiverCallNameToken!' "direct receiver producer scan excludes same-start wrappers that contain the method token"
Assert-MatchCount $calls 'semantic\.types\[receiverTypeId!\]\.kind == 8' 2 "projected receiver root and field reference unwrapping"
Assert-MatchCount $foundation 'eachContainerTypeId! -> writeArrayViewType' 2 "shared each canonical collection view type for data and length"
Assert-Contains $text 'entryExpressionIndex -> emitDirectEachStart(' "entry each uses shared loop and role emission"
Assert-Contains $functions 'expressionIndex -> emitDirectEachStart(' "ordinary each uses shared loop and role emission"
Assert-Contains $controlRegions 'regionNodeIndex -> emitDirectEachStart(' "control-arm each uses shared loop and role emission"
Assert-Contains $platformIo 'writeArrayViewType typeId: Int' "shared fixed, slice, and growable collection view ABI writer"
Assert-NotContains $text '%each$(entryExpressionIndex)_data = extractvalue %sollang.array.i32' "entry each growable-array aggregate hardcode"
Assert-NotContains $functions '%each$(expressionIndex)_data = extractvalue %sollang.array.i32' "ordinary each growable-array aggregate hardcode"
Assert-Contains $typedFunctionLowering '(receiverCandidate.opcode == -207 or receiverCandidate.opcode == -208 or receiverCandidate.opcode == -209)' "sequential each and parallel roles share element-type recovery"
Assert-Contains $typedSourceLoweringFinalize '(nodes[entryRoleCallSearch!].opcode == -207 or nodes[entryRoleCallSearch!].opcode == -208 or nodes[entryRoleCallSearch!].opcode == -209)' "entry sequential each role-result binding repair"
Assert-Contains $typedOrdinaryFunctionFinalize '(nodes[roleCallSearch!].opcode == -207 or nodes[roleCallSearch!].opcode == -208 or nodes[roleCallSearch!].opcode == -209)' "ordinary sequential each role-result binding repair"
Assert-Contains $expressionTypeIdsPaths 'expressionIndexByAst[branchRange.astStart + partitionSourceAst!] => partitionSourceExpression' "partition source uses the final AST-indexed fixed-point type"
Assert-NotContains $expressionTypeIdsPaths 'partitionSourceSearch! < (expressions -> len)' "partition source avoids stale append-only expression records"
Assert-Contains $grammar 'rule RangeExpression = EqualityExpression (Range | RangeUntil) EqualityExpression' "range endpoints exclude unparenthesized value flow"
Assert-Contains $managedParserGenerator 'return TryParseRangeExpression(out var range)' "managed range-or-logical parsing backtracks before logical fallback"
Assert-Contains $selfhostDriver 'command -> textEquals("expression-type-records")' "indexed expression-type diagnostic command"
Assert-Contains $selfhostDriver 'command -> textEquals("semantic-type-records")' "semantic-type graph diagnostic command"
Assert-Contains $selfhostDriver 'semantic type $(typeIndex!) kind $(semanticType.kind)' "semantic-type graph diagnostic fields"
Assert-Contains $selfhostDriver 'semantic field $(fieldIndex!) owner $(field.ownerType) type $(field.fieldType)' "semantic-type field graph diagnostic fields"
Assert-Contains $ast 'roleNameFound! and roleParenDepth! == 0 and tokens[roleToken!].kind == grammar.tokenIdLeftBrace()' "role body begins only after the role name, not in receiver literals"
Assert-Contains $ast 'roleBodySeen! and tokens[roleToken!].kind == grammar.tokenIdRightBrace()' "role body brace depth excludes receiver literal braces"
Assert-Contains $stage2Verifier '-Fixture $stage1SeedHeavyFixtures' "Stage2 seed exact batch consumes the measured heavy partition"
Assert-Contains $stage2Verifier '-Fixture $stage1SeedLightFixtures' "Stage2 seed exact batch consumes the cache-compatible light partition"
Assert-Matches $stage2Verifier '(?s)\$stage1SeedCanaryFixtures = @\(\s*"1201-parallel-move-parameter"\s*"1398-selfhost-borrowed-enum-payload-lifetime"\s*"1403-selfhost-fresh-directory-payload-cleanup"\s*"1451-dictionary-absent-instance-result"\s*"1452-each-call-result-record-type"\s*"1453-each-push-return-alias"\s*"1480-direct-repeat-readonly-slice"\s*"1481-resolved-call-early-return-cleanup"\s*"1482-signed-unary-contexts"\s*"1497-narrow-integer-parameter-print"\s*"1496-wide-integer-array-flow-context"\s*\)' "Stage2 seed fails early for incompatible enum payload cleanup or dictionary insertion capability"
Assert-Matches $stage2Verifier '(?s)-Label "stage1-seed-canary".*?-Fixture \$stage1SeedCanaryFixtures.*?-Jobs \$Stage2BuildJobs.*?if \(\$LASTEXITCODE -ne 0\) \{ exit \$LASTEXITCODE \}.*?-Label "stage1-seed-heavy".*?-MinimumCompilerJobs \$Stage2BuildJobs.*?-Label "stage1-seed"' "Stage2 seed canary gates the full-budget heavy partition and cache-compatible light partition"
Assert-Contains $stage2Verifier 'verify-native-exact-fixture-batch.ps1' "Stage2 seed exact uses bounded parallel verification"
Assert-Matches $stage2Verifier '(?s)-Compiler \$stage2Path `\s+-Label "stage2" `\s+-LlvmRoot' "Windows Stage2 consumes the complete authoritative native-exact fixture plan"
Assert-Matches $stage3Verifier '(?s)-Compiler \$exactGeneration\.Compiler `\s+-Label \$exactGeneration\.Name `\s+-LlvmRoot' "Windows Stage2/Stage3 consume the complete authoritative native-exact fixture plan"
Assert-Contains $grammar 'ControlFlowExpressionStatement | BlockFunctionCallStatement | ExpressionStatement' "block-function statements precede committing general expressions"
Assert-Contains $grammar ') NewLine* lookahead(Arrow))* (NewLine* Arrow notKeyword("if") notKeyword("unless") notKeyword("while")' "self-host block callback preserves value-flow prefixes and rejects while control"
Assert-Contains $grammar ') ((NewLine* Arrow StreamSliceStage NewLine* lookahead(Arrow))* (NewLine* Arrow notKeyword("if")' "self-host block callbacks retain take and skip slice stages between role bodies"
Assert-Contains $managedParserGenerator 'if (IsBlockFunctionTargetAhead())' "managed value flow stops before structural block callbacks"
Assert-Contains $managedParserGenerator 'return Check(TokenKind.LeftBrace);' "managed block callback lookahead requires a real body"
Assert-Contains $foundation 'ownedArmBindingHasMove! -> if {' "moved enum payload ownership flag hoist gate"
Assert-Contains $foundation '"  %v$(ownedArmBindingIndex)_owned = alloca i1, align 1" -> println' "moved enum payload ownership flag entry allocation"
Assert-Contains $foundation '"  store i1 false, ptr %v$(ownedArmBindingIndex)_owned, align 1" -> println' "moved enum payload ownership flag entry initialization"
Assert-NotContains $control '"  %v$(armBindingIndex)_owned = alloca i1, align 1" -> println' "no branch-local moved enum payload ownership flag allocation"
Assert-Contains $control '"  store i1 true, ptr %v$(armBindingIndex)_owned, align 1" -> println' "selected enum arm claims its hoisted payload ownership"
Assert-Matches $control '(?s)controlIsLastRegionChild.*?context\.ir\[regionIndex!\]\.kind == 9.*?context\.ir\[regionIndex!\]\.opcode == -1.*?context\.ir\[regionIndex!\]\.operand1 == regionChild!.*?context\.ir\[laterChildSearch!\]\.parent == regionIndex!.*?false -> return' "terminal control climbs canonical wrappers and rejects a later sibling in the owning region"
Assert-Matches $control '(?s)terminatingControlReturns.*?candidate\.kind == 9.*?candidate\.opcode == -1.*?candidate\.operand1.*?context\.ir\[candidate\.operand1\]\.parent == candidateIndex!.*?candidate\.operand1 => candidateIndex!' "region termination follows only canonical value-flow wrapper ownership edges"
Assert-Matches $control '(?s)terminatingControlReturns.*?controlReturns.*?controlIsLastRegionChild' "region termination requires the control to be the final owning-region child"
Assert-Matches $control '(?s)returnRegion\.kind == 1.*?returnRegion\.operand0 => canonicalTerminal!.*?returnRegion\.kind == 19 or returnRegion\.kind == 20.*?returnRegion\.operand1 => canonicalTerminal!.*?canonicalTerminal! -> terminatingControlReturns' "region termination resolves the canonical function or arm result through terminating flow wrappers"
Assert-Matches $functionScheduling '(?s)reachableExpressionOrder!.*?reachableCandidate -> terminatingControlReturns\(context, state\).*?false => reachableExpressionOpen!' "scheduler removes only a wrapper-aware terminal control with no later owning-region sibling"
Assert-Matches $control '(?s)whenAllArmsReturn!.*?not \(whenIndex -> controlIsLastRegionChild\(context, state\)\).*?false => whenAllArmsReturn!.*?not whenAllArmsReturn!.*?when\$\(whenIndex\)_end' "all-return subject when retains an end block when later region siblings exist"
Assert-Matches $control '(?s)enumMatchReturns\(context, state\) => matchAllArmsReturn!.*?not \(matchIndex -> controlIsLastRegionChild\(context, state\)\).*?false => matchAllArmsReturn!.*?not matchAllArmsReturn!.*?match\$\(matchIndex\)_merge' "all-return enum match retains a merge block when later region siblings exist"
Assert-Matches $functions '(?s)thenReturns and elseReturns! => ifAllBranchesReturn!.*?not \(expressionIndex -> controlIsLastRegionChild\(context, state\)\).*?false => ifAllBranchesReturn!.*?not ifAllBranchesReturn!.*?if\$\(expressionIndex\)_merge' "all-return if retains a merge block when later region siblings exist"
Assert-Contains $terminalFlowControlReturnFixture 'struct Parsed {' "terminal flow-control fixture owned outer payload"
Assert-Contains $terminalFlowControlReturnFixture 'bytes: [UInt8; ~]' "terminal flow-control fixture retained cleanup owner"
Assert-Matches $terminalFlowControlReturnFixture '(?s)Ok\(parsed\).*?self\.listener -> listen -> when.*?Ok\(value\).*?Result<Int, Int>\.Ok\(value\) -> return' "terminal flow-control fixture nested instance-call control topology"
Assert-Contains $functionScheduling 'functionMutableRoots![scheduleCandidate! - functionIndex - 1] => cachedMutableReadRoot' "scheduler cached mutable-read root lookup"
Assert-NotContains $functionScheduling 'mutableReadBindingSearch! < functionEnd' "per-read full function mutable-binding scan"
$directEmitContextLiteralCount = 0
foreach ($contextSource in Get-ChildItem @(
    (Join-Path $RepositoryRoot "selfhost"),
    (Join-Path $RepositoryRoot "examples"),
    (Join-Path $RepositoryRoot "tests"),
    (Join-Path $RepositoryRoot "stdlib")
) -Recurse -File -Filter "*.slg") {
    $contextSourceText = [IO.File]::ReadAllText($contextSource.FullName)
    $contextLiteralCount = [regex]::Matches(
        $contextSourceText,
        '(?m)^\s*emitterContext\.EmitContext\s*\{\s*$').Count
    if ($contextLiteralCount -eq 0) {
        continue
    }
    $contextFieldCount = [regex]::Matches(
        $contextSourceText,
        '(?m)^\s*finalCallResolvedByAst\s*:').Count
    if ($contextFieldCount -ne $contextLiteralCount) {
        throw "direct EmitContext literal field inventory differs in $($contextSource.FullName): literals $contextLiteralCount, final-call indexes $contextFieldCount"
    }
    $directEmitContextLiteralCount += $contextLiteralCount
}
if ($directEmitContextLiteralCount -lt 4) {
    throw "direct EmitContext literal inventory lost a production or invariant fixture constructor"
}
Assert-Contains $nonProcessCollectFixture "Collector { value: 42 } -> collect => value" "ordinary collect instance-call convergence fixture"
Assert-NotContains $emitterDiagnostics "context.symbols[reachableCandidateGlobalSymbol].kind == 31" "unconditional instance-method reachability root"
Assert-Contains $emitterDiagnostics "use.kind == 6 or use.kind == 9" "ordinary and materialized call-graph edges"
Assert-Contains $emitterDiagnostics "public traitMethodSymbol" "canonical implicit trait-method resolver"
Assert-Contains $emitterDiagnostics "use -> typedIr.isSetIntrinsicCall" "reachable Set implicit trait-call edge"
Assert-Contains $emitterDiagnostics 'traitMethodSymbol("Hash", "hash", context)' "reachable Set Hash edge"
Assert-Contains $emitterDiagnostics 'traitMethodSymbol("Eq", "eq", context)' "reachable Set Eq edge"
Assert-Contains $coreCalls "diagnostics.traitMethodSymbol" "LLVM implicit trait resolver consumer"
Assert-Contains $emitterDiagnostics "instanceInterpolation.kind == 8 or instanceInterpolation.kind == 10" "resolved and deferred interpolation call-graph edges"
Assert-Contains $emitterDiagnostics "interpolationFormatterTypeDeferred" "deferred interpolation scalar formatter capability"
Assert-Contains $emitterDiagnostics "kind == 5 or kind == 7 or kind == 8 or kind == 10" "member, index, and source-call interpolation formatter coverage"
Assert-Contains $foundation "diagnostics.interpolationCallNameMatches" "canonical interpolation call-name resolver consumer"
Assert-Contains $foundation 'writeInterpolationIntegerLiteral node: interpolation.InterpolationNode' "interpolation integer literal canonical LLVM writer"
Assert-Matches $foundation '(?s)writeInterpolationIntegerLiteral node: interpolation\.InterpolationNode.*?byte\(byteIndex!\)\) == 95.*?slice\(segmentStart!, byteIndex! - segmentStart!\).*?literalEnd - segmentStart!' "interpolation integer writer removes every visual separator"
Assert-NotContains $foundation 'slice(callArgument.payloadStart, callArgument.payloadLength)' "interpolation call arguments must not copy numeric source spelling into LLVM"
Assert-NotContains $functionCalls 'slice(functionExpressionLeft.payloadStart, functionExpressionLeft.payloadLength)' "function interpolation left operand canonical numeric writer"
Assert-NotContains $functionCalls 'slice(functionExpressionUnary.payloadStart, functionExpressionUnary.payloadLength)' "function interpolation unary operand canonical numeric writer"
Assert-NotContains $functionCalls 'slice(functionExpressionRight.payloadStart, functionExpressionRight.payloadLength)' "function interpolation right operand canonical numeric writer"
Assert-NotContains $functionCalls 'slice(functionExpressionRoot.payloadStart, functionExpressionRoot.payloadLength)' "function interpolation root canonical numeric writer"
Assert-NotContains $controlRegions 'slice(regionExpressionLeft.payloadStart, regionExpressionLeft.payloadLength)' "control interpolation left operand canonical numeric writer"
Assert-NotContains $controlRegions 'slice(regionExpressionUnary.payloadStart, regionExpressionUnary.payloadLength)' "control interpolation unary operand canonical numeric writer"
Assert-NotContains $controlRegions 'slice(regionExpressionRight.payloadStart, regionExpressionRight.payloadLength)' "control interpolation right operand canonical numeric writer"
Assert-NotContains $controlRegions 'slice(regionExpressionRoot.payloadStart, regionExpressionRoot.payloadLength)' "control interpolation root canonical numeric writer"
Assert-Matches $controlRegions '(?s)regionExpressionNode\.kind == 2 and regionExpressionNode\.opcode != -26.*?writeInterpolationValue\(regionExpressionNode\.operand0.*?regionExpressionNode\.kind == 2.*?writeInterpolationValue\(regionExpressionNode\.operand0.*?else \{.*?writeInterpolationValue\(regionExpressionNode\.operand1' "control-region arithmetic delegates literal, parameter, lexical, mutable, and pattern operands to the canonical interpolation value writer"
Assert-NotContains $controlRegions 'context.ir[context.ir[regionExpressionLeftBinding].operand0]' "control-region interpolation never assumes every resolved binding has an initializer operand"
Assert-NotContains $text 'slice(entryExpressionLeft.payloadStart, entryExpressionLeft.payloadLength)' "entry interpolation left operand canonical numeric writer"
Assert-NotContains $text 'slice(entryExpressionUnary.payloadStart, entryExpressionUnary.payloadLength)' "entry interpolation unary operand canonical numeric writer"
Assert-NotContains $text 'slice(entryExpressionRight.payloadStart, entryExpressionRight.payloadLength)' "entry interpolation right operand canonical numeric writer"
Assert-NotContains $text 'slice(entryExpressionRoot.payloadStart, entryExpressionRoot.payloadLength)' "entry interpolation root canonical numeric writer"
Assert-Contains $text "entryExpressionIndex -> emitInterpolationIntrinsic(entryExpressionNodeIndex" "entry interpolation shared intrinsic emitter"
Assert-NotMatches $text '(?s)and not entryInterpolationInsideLogical\s+and \(entryInterpolationNode\.kind == [0-9].*?emitInterpolationIntrinsic\(entryExpressionNodeIndex' "entry interpolation kind whitelist"
Assert-Contains $foundation "directEachRoleTypeId" "direct each-role interpolation type resolver"
Assert-Contains $foundation "frozenValuesHaveFunctionLocalDirectBindings: [Bool; ~]" "immutable function-local direct value-binding index"
Assert-Contains $foundation "frozenFirstIrChildByParent: [Int; ~]" "immutable direct-child head index"
Assert-Contains $foundation "frozenNextIrSiblingByNode: [Int; ~]" "immutable direct-child sibling index"
Assert-Contains $corePrepare "lastIrChildByParent![childParentIndex]" "direct-child index preserves Typed IR order"
Assert-Contains $corePrepare "functionOwnerByIrNode[childNodeIndex!]" "direct-child index preserves function ownership"
Assert-Contains $corePrepare "snapshotIntArray => frozenFirstIrChildByParent" "direct-child head immutable snapshot"
Assert-Contains $corePrepare "snapshotIntArray => frozenNextIrSiblingByNode" "direct-child sibling immutable snapshot"
Assert-Contains $coreCalls "state.frozenFirstIrChildByParent[wrapperIndex] => controlSearch!" "aggregate wrapper begins at indexed direct child"
Assert-Contains $coreCalls "state.frozenNextIrSiblingByNode[controlSearch!] => controlSearch!" "aggregate wrapper advances through indexed direct siblings"
Assert-NotContains $coreCalls "controlOwner! -> functionEnd(context, state) => controlEnd!" "aggregate wrapper whole-function child scan removed"
Assert-Contains $corePrepare "bindingIndexNode.kind == 17" "direct value-binding index kind contract"
Assert-Contains $corePrepare "bindingIndexNode.operand0 > bindingOwnerIndex!" "direct value-binding index lower owner bound"
Assert-Contains $corePrepare "bindingIndexNode.operand0 < bindingOwnerEnd" "direct value-binding index upper owner bound"
Assert-Contains $corePrepare "true => valuesHaveFunctionLocalDirectBindings![bindingIndexNode.operand0]" "direct value-binding initializer index"
Assert-Contains $foundation "valueHasDirectBinding nodeIndex: Int, state: ref CoreEmitterState -> Bool" "constant-time direct value-binding classifier"
Assert-Contains $foundation "nodeIndex < (state.frozenValuesHaveFunctionLocalDirectBindings -> len)" "direct value-binding cache bounds"
Assert-NotContains $foundation "bindingIndex! < bindingEnd! and not used!" "direct value-binding function rescan removed"
Assert-Contains $coreCalls "nodeIndex -> valueHasDirectBinding(state)" "cached control value-binding use integration"
Assert-Matches $selfhostDriver '(?s)runCheckedValidation profilePhase: Int.*?UIntSize\(2\) -> sourceStart => validationPathStart.*?validationPathStart -> collectPaths => paths' "profile commands skip the optional jobs pair before collecting source paths"
Assert-Contains $foundation "controlResultShapeComplete controlIndex:" "nested if result-shape validator"
Assert-Contains $foundation "depth >= 32" "nested result-shape cycle bound"
Assert-Contains $foundation "context.ir[rawThenResult].kind == 17" "binding statement cannot become an if branch value"
Assert-Contains $foundation "context.ir[rawElseResult].kind == 17" "else binding statement cannot become an if branch value"
Assert-Contains $foundation "directBlockResultControlIndex blockIndex:" "block-bodied direct value-control result authority"
Assert-Contains $foundation "child.parent == blockIndex" "block result control requires direct structural ownership"
Assert-Contains $foundation "childTypeMatches!" "block result control requires exact semantic type identity"
Assert-Contains $coreCalls "directBlockResultControl == nodeIndex" "block-contained control value-use integration"
Assert-Contains $coreCalls "resolved! -> directBlockResultControlIndex(regionIndex" "region result consumes the direct block control merge"
Assert-Contains $coreCalls "nodeIndex -> controlResultShapeComplete(0, context, state)" "control result materialization requires a complete nested shape"
Assert-Contains $foundation "eachCandidate.opcode == -208" "direct each-role interpolation owner identity"
Assert-Contains $foundation "node -> directEachRoleTypeId(sourceModule, context, state)" "direct each-role interpolation type integration"
Assert-Contains $foundation "plannedStreamPipeline(context, state)) < 0" "direct each-role exclusion of planned stream terminals"
Assert-Contains $foundation '"%each_role_m$(sourceModule)_s$(node.symbol)" -> print' "direct collection each-role alias value"
Assert-Contains $processRuntime "not hasCloseDeclaration" "Linux process close declaration ownership"
Assert-Contains $textContext "or needsSocketRuntime" "Linux shared close declaration detection"
Assert-Matches $textContext 'needsOwnedFileRuntime or needsSourceTextRuntime or needsProcessRuntime or runtimeModule! >= 0\s*-> if \{\s*"declare dllimport ptr @CreateFileA' "Windows process CreateFile declaration closure"
Assert-Contains $receiverMetadataFixture '"""' "raw multiline embedded Sollang source fixture"
Assert-Contains $receiverMetadataFixture "struct EnvironmentChange {" "natural embedded Sollang source body"
Assert-NotContains $receiverMetadataFixture '"struct EnvironmentChange {\n' "escaped-newline embedded Sollang source"
$escapedMultilineSourcePattern = '(?m)"(?:struct|enum|import|namespace|main|public|impl)\b[^"\r\n]*\\n'
$escapedMultilineSourceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot "examples\regression"), (Join-Path $RepositoryRoot "tests\Sollang.ExampleTests\Fixtures") -Recurse -File -Filter "*.slg" |
        Where-Object { [regex]::IsMatch([IO.File]::ReadAllText($_.FullName), $escapedMultilineSourcePattern) } |
        ForEach-Object { [IO.Path]::GetRelativePath($RepositoryRoot, $_.FullName) }
)
if ($escapedMultilineSourceFiles.Count -ne 0) {
    throw "embedded multiline Sollang fixture source must use raw triple-quoted text: $($escapedMultilineSourceFiles -join ', ')"
}
Assert-Contains $typeIds "[UInt64; ~] => lengthParameterHashes!" "value-generic fixed-array length-parameter identity"
Assert-Contains $typeIds "lengthReplacements![lengthParameterIndex!] != actual.length" "value-generic fixed-array repeated-length unification"
Assert-Contains $typeIds "known.length == specializedLength! and known.lengthHash == specializedLengthHash!" "specialized fixed-array canonical interning"
Assert-Contains $typedOrdinaryFunctionFinalize "typeIds.materializedReadTypeId(foldSourceCandidate.typeId)" "ordinary fold fixed-array reference materialization"
Assert-Contains $typedOrdinaryFunctionFinalize "frozenRecursiveSemanticTypes[foldSourceCandidateValueType].kind == 4" "ordinary fold fixed-array source acceptance"
Assert-Contains $typedSourceLoweringFinalize "typeIds.materializedReadTypeId(entryFoldSourceCandidate.typeId)" "entry fold fixed-array reference materialization"
Assert-Contains $typedSourceLoweringFinalize "frozenRecursiveSemanticTypes[entryFoldSourceCandidateValueType].kind == 4" "entry fold fixed-array source acceptance"
Assert-Contains $functions 'and context.types[foldSource -> effectiveTypeId(context, state)].kind == 4' "ordinary fold fixed-array LLVM carrier selection"
Assert-Contains $entryExpressions 'and context.types[entryFoldSource -> effectiveTypeId(context, state)].kind == 4' "entry fold fixed-array LLVM carrier selection"
Assert-Contains $emitterDiagnostics "value-generic function '`$valueGenericName' requires a fixed array input" "selfhost value-generic fixed-array-required diagnostic"
Assert-Contains $emitterDiagnostics '"; $(valueGenericLength!)] but received [" -> print' "selfhost value-generic fixed-array-size diagnostic"
Assert-Contains $semanticOwnership "current.kind == 4 or current.kind == 7 -> if {" "fixed-array ownership follows recursive element classification"
Assert-Contains $semanticOwnership "current.first >= 0 -> if { pending! -> push(current.first) }" "fixed-array element ownership is traversed"
Assert-Contains $semanticOwnership 'not referenceBorrowUsedAfterMutation! -> if {' "E23 index/call mutation falls back to field-sensitive carrier liveness"
Assert-Contains $semanticOwnership 'prepared -> borrowedBindingUsedAfterSite(typed, referenceBindingIndex!, referenceMutationIndex!, referenceBindingCarrierType!) => referenceBorrowUsedAfterMutation!' "E23 follows live when-payload aliases after carrier direct use"
Assert-Contains $storedArrayReferenceDiagnostic "`$result.ExitCode -ne 1" "stored-array E23 validator rejects abnormal compiler termination"
Assert-Contains $storedArrayReferenceDiagnostic "`$matches.Count -ne 1" "stored-array E23 validator requires exactly one source diagnostic"
Assert-Contains $storedArrayReferenceDiagnostic 'S052|compiler-integrity defect|^target (datalayout|triple)' "stored-array E23 validator rejects late backend failure"
Assert-Contains $emitterDiagnostics "logicalOperandDiagnosticCount" "logical Bool operand blocking diagnostic"
Assert-Contains $emitterDiagnostics "enumExhaustivenessDiagnosticCount" "enum exhaustiveness blocking diagnostic"
Assert-Contains $emitterDiagnostics "error[E29]: right operand of" "actionable logical operand diagnostic"
Assert-Contains $emitterDiagnostics "error[E30]: non-exhaustive enum when" "actionable enum exhaustiveness diagnostic"
Assert-Contains $semanticParityDiagnostic 'logical-and-flow-result' "logical operand parity fixture"
Assert-Contains $semanticParityDiagnostic '1546-logical-flow-bool' "logical Bool flow positive fixture"
Assert-Contains $semanticParityDiagnostic 'enum-non-exhaustive' "enum exhaustiveness parity fixture"
Assert-Contains $stage2Verifier 'verify-selfhost-semantic-parity-diagnostics.ps1' "Stage2 semantic parity gate"
Assert-Contains $stage3Verifier 'verify-selfhost-semantic-parity-diagnostics.ps1' "Stage3 semantic parity gate"
Assert-Contains $semanticOwnership "and ownedEscapeParent.operand1 == ownedEscapeChild!" "container value operand ownership boundary"
Assert-Matches $semanticOwnership 'ownedEscapeParent\.kind == 6\s*-> if \{\s*false => ownershipPreserved!' "ordinary call result ownership-origin boundary"
Assert-Contains $semanticOwnership "and (prepared -> semanticTypeContainsOwnedStorage(types, ownedEscapeParent.typeId))" "owned-only aggregate escape path boundary"
Assert-Contains $semanticOwnership "and (prepared -> semanticTypeContainsOwnedStorage(types, typed[partialMove.memberIr].typeId))" "owned-only partial-move candidate boundary"
Assert-Contains $borrowedOwnedFixture "borrowed-push-blocked=" "selfhost borrowed container-store regression"
Assert-Contains $borrowedOwnedFixture '"""' "natural multiline borrowed container-store source"
Assert-Contains $ownedCallOriginFixture "self.child -> fresh" "fresh owned call-result origin regression"
Assert-Contains $ownedCallOriginFixture "self.phase -> when" "copyable enum subject owned-origin regression"
Assert-Contains $ownedCallOriginFixture "self.resumePhase => self.phase" "copyable-field branch assignment regression"
Assert-Contains $borrowedFixedCopyFixture "holders -> push(Holder { bytes: bytes })" "borrowed fixed scalar array independent-copy regression"
Assert-Contains $moveMethodDropFixture "public close: move self" "partial move-method sibling-drop regression"
Assert-Contains $standardProcess "public setEnvironment: mut self" "instance-owned child environment setter"
Assert-Contains $standardProcess "public removeEnvironment: mut self" "instance-owned child environment removal"
Assert-Contains $standardProcess "public clearEnvironment: mut self" "instance-owned child environment clearing"
Assert-Contains $standardProcess "public enum Input" "directional process stdin policy"
Assert-Contains $standardProcess "public enum Output" "directional process output policy"
Assert-Contains $standardProcess "public stdin: mut self" "instance-owned child stdin setter"
Assert-Contains $standardProcess "public stdout: mut self" "instance-owned child stdout setter"
Assert-Contains $standardProcess "public stderr: mut self" "instance-owned child stderr setter"
Assert-Contains $standardProcess "    Null" "process null-device stdio policy"
Assert-Contains $standardProcess "public struct CaptureLimits" "bounded process capture limits"
Assert-Contains $standardProcess "public struct CapturedOutput" "bounded process capture result"
Assert-Contains $standardProcessRuntime "public collect: move self, limits: CaptureLimits" "instance-owned bounded process capture"
Assert-NotMatches $standardProcess '(?m)^public (setEnvironment|removeEnvironment|clearEnvironment):' "global child environment mutator"
Assert-NotMatches $standardProcess '(?m)^public (stdin|stdout|stderr):' "global child stdio mutator"
Assert-Contains $typedCore "-277 => processCall!.opcode" "explicit process spawn opcode"
Assert-Contains $typedCore "-278 => processCall!.opcode" "explicit process wait opcode"
Assert-Contains $typedCore "-285 => processCall!.opcode" "explicit Child.id projection opcode"
Assert-Contains $typedCore "-286 => processCall!.opcode" "explicit ProcessId.asUInt64 projection opcode"
Assert-Contains $typedCore "processCollectSymbol! -> if { -288 => processCall!.opcode }" "explicit process collect opcode"
Assert-Contains $typedResolvedContextSeal "nodes -> len => lateCallControlTypeIndex!" "late call-result control convergence"
Assert-Contains $typedResolvedContextSeal "nodes[lateCallControlType!.operand1] => lateCallRegionValue" "late call-result region type propagation"
Assert-Contains $typedCore "false => lateNonValueContinuingArm!" "non-value continuing enum-arm classification"
Assert-Contains $typedResolvedContextSeal "nodes -> len => lateNonValueMatchIndex!" "nested non-value match reverse convergence"
Assert-Contains $typedResolvedContextSeal "and nodes[lateNonValueTerminalIndex].kind != 23" "explicit return exclusion from enum value joins"
Assert-Contains $typedCore 'sourceMatches(finalSocketIntrinsicNameToken.span.start, finalSocketIntrinsicNameToken.span.length, "receiveFromInto")' "socket receiveFromInto intrinsic identity"
Assert-Contains $typedCore "-> if { -287 => finalSocketIntrinsic!.opcode }" "socket receiveFromInto opcode"
Assert-NotContains $typedCore "processCollectSymbol! -> if { -287 => processCall!.opcode }" "process and socket opcode collision"
Assert-Contains $typedCore "public isProcessProjectionOpcode" "canonical process domain projection predicate"
Assert-Contains $typedCore "public isProcessExecutionOpcode" "canonical process execution predicate"
Assert-Contains $typedCore "opcode == -288" "process collect execution classification"
Assert-Contains $typedCore "site.kind == 6 or site.kind == 9" "resolved and materialized process receiver move classification"
Assert-Contains $typedCore "site.opcode == -277 or site.opcode == -278" "spawn and wait materialized receiver ownership transfer"
Assert-Contains $processRuntime "%sollang.process_spawn_result = type { i64, i64, i32 }" "process spawn token, identifier, and error ABI"
Assert-Contains $textContext 'declare dllimport ptr @GetEnvironmentStringsW()' "Windows parent environment declaration"
Assert-Contains $textContext 'declare dllimport i32 @FreeEnvironmentStringsW(ptr)' "Windows parent environment release declaration"
Assert-Contains $textContext 'declare dllimport i32 @CompareStringOrdinal(ptr, i32, ptr, i32, i32)' "Windows ordinal environment comparison declaration"
Assert-Contains $processRuntime 'define internal %sollang.process_environment_result @sollang_windows_build_environment' "selfhost Windows child environment builder"
Assert-Contains $processRuntime '%fast0 = insertvalue %sollang.process_environment_result poison, ptr null, 0' "selfhost Windows unchanged environment zero-copy path"
Assert-Contains $processRuntime '%sort_order = call i32 @CompareStringOrdinal' "selfhost Windows case-insensitive sorted environment block"
Assert-Contains $processRuntime '%creation_flags = select i1 %has_environment, i32 1024, i32 0' "selfhost Windows Unicode environment flag"
Assert-Contains $processRuntime 'ptr %environment, ptr %working_directory' "selfhost Windows CreateProcess environment argument"
Assert-Contains $processRuntime '%parent_environment = load ptr, ptr @environ, align 8' "selfhost Linux inherited environment vector"
Assert-Contains $processRuntime '%fast0 = insertvalue %sollang.process_environment_result poison, ptr %parent_environment, 0' "selfhost Linux unchanged environment zero-copy path"
Assert-Contains $processRuntime '@posix_spawnp(ptr %pid_slot, ptr %program, ptr %file_actions, ptr null, ptr %argv, ptr %environment)' "selfhost Linux child environment argument"
Assert-Contains $managedWindowsProcessRuntime 'define internal %sollang.process_environment_result @sollang_windows_build_environment' "managed Windows child environment builder"
Assert-Contains $managedWindowsProcessRuntime '%fast0 = insertvalue %sollang.process_environment_result poison, ptr null, 0' "managed Windows unchanged environment zero-copy path"
Assert-Contains $managedWindowsProcessRuntime '%sort_order = call i32 @CompareStringOrdinal' "managed Windows case-insensitive sorted environment block"
Assert-Contains $managedWindowsProcessRuntime '%creation_flags = select i1 %has_environment, i32 1024, i32 0' "managed Windows Unicode environment flag"
Assert-Contains $managedLinuxProcessRuntime '%parent_environment = load ptr, ptr @environ, align 8' "managed Linux inherited environment vector"
Assert-Contains $managedLinuxProcessRuntime '%fast0 = insertvalue %sollang.process_environment_result poison, ptr %parent_environment, 0' "managed Linux unchanged environment zero-copy path"
Assert-Contains $processRuntime '@sollang_spawn_process_with_stdout' "selfhost child-only stdout spawn helper"
Assert-Contains $processRuntime '@sollang_spawn_process_with_stdio' "selfhost three-direction stdio spawn helper"
Assert-Contains $processRuntime '@sollang_spawn_process_configured' "selfhost instance-configured stdio spawn"
Assert-Contains $processRuntime '@sollang_run_process_configured' "selfhost instance-configured stdio status"
Assert-Contains $processRuntime '%sollang.process_capture_result = type { i32, ptr, i64, i64, i1, ptr, i64, i64, i1, i32 }' "selfhost bounded capture ABI"
Assert-Contains $processRuntime '@sollang_process_capture_append' "selfhost bounded capture growth helper"
Assert-Contains $processRuntime 'public emitWindowsProcessCaptureRuntime' "selfhost Windows concurrent capture runtime"
Assert-Contains $processRuntime 'public emitLinuxProcessCaptureRuntime' "selfhost Linux concurrent capture runtime"
Assert-Contains $processRuntime '@CreateThread' "selfhost Windows concurrent stream readers"
Assert-Matches $textContext 'capturesParallelOutput or needsProcessCapture or needsMouseEventsRuntime or needsConcurrentStreamJoins\s+-> if \{\s+"declare dllimport ptr @CreateThread' "Windows thread creation is a capture capability"
Assert-Matches $textContext 'capturesParallelOutput or needsProcessRuntime or needsMouseEventsRuntime or needsConcurrentStreamJoins\s+-> if \{\s+"declare dllimport i32 @WaitForSingleObject' "ordinary process wait retains its independent declaration"
Assert-Contains $processRuntime '@pthread_create' "selfhost Linux concurrent stream readers"
Assert-Contains $processRuntime '@pipe2(ptr %stdout_pipe, i32 524288)' "selfhost Linux close-on-exec capture pipes"
Assert-Contains $processRuntime '@sollang_process_null_windows' "selfhost Windows null-device path"
Assert-Contains $processRuntime '@sollang_process_null_linux' "selfhost Linux null-device path"
Assert-Contains $processRuntime '@posix_spawn_file_actions_adddup2(ptr %file_actions, i32 %source_fd, i32 %target_fd)' "selfhost Linux child-only stdio duplication action"
Assert-Contains $processRuntime '@posix_spawn_file_actions_addclose(ptr %file_actions, i32 %source_fd)' "selfhost Linux child stdio source descriptor close action"
Assert-Contains $processRuntime '%source_is_target = icmp eq i32 %source_fd, %target_fd' "selfhost Linux stdio target close guard"
Assert-Contains $processRuntime '@sollang_posix_add_redirect(ptr %file_actions, i32 %stdin_fd, i32 0)' "selfhost Linux stdin redirect action"
Assert-Contains $processRuntime '@sollang_posix_add_redirect(ptr %file_actions, i32 %stdout_fd, i32 1)' "selfhost Linux stdout redirect action"
Assert-Contains $processRuntime '@sollang_posix_add_redirect(ptr %file_actions, i32 %stderr_fd, i32 2)' "selfhost Linux stderr redirect action"
Assert-Contains $processRuntime '%stdout_source = select i1 %has_stdout_override, ptr %stdout_override, ptr %stdout_default' "selfhost Windows child-only stdout handle selection"
Assert-NotContains $processRuntime '@_dup2' "selfhost Windows parent stdout replacement"
Assert-NotContains $processRuntime '@dup2(i32' "selfhost Linux parent stdout replacement"
Assert-Contains $managedWindowsProcessRuntime '@sollang_spawn_process_with_stdout' "managed Windows child-only stdout spawn helper"
Assert-Contains $managedWindowsProcessRuntime '@sollang_spawn_process_with_stdio' "managed Windows three-direction stdio spawn helper"
Assert-Contains $managedWindowsProcessRuntime '@sollang_spawn_process_configured' "managed Windows instance-configured stdio spawn"
Assert-Contains $managedWindowsProcessRuntime '@sollang_run_process_configured' "managed Windows instance-configured stdio status"
Assert-Contains $managedWindowsProcessRuntime '@sollang_collect_process_configured' "managed Windows bounded process capture"
Assert-Contains $managedWindowsProcessRuntime '@CreateThread' "managed Windows concurrent stream readers"
Assert-Contains $managedWindowsProcessRuntime '@sollang_process_null_windows' "managed Windows null-device path"
Assert-Contains $managedWindowsProcessRuntime '%stdin_source = select i1 %has_stdin_override, ptr %stdin_override, ptr %stdin_default' "managed Windows child-only stdin handle selection"
Assert-Contains $managedWindowsProcessRuntime '%stdout_source = select i1 %has_stdout_override, ptr %stdout_override, ptr %stdout_default' "managed Windows child-only stdout handle selection"
Assert-Contains $managedWindowsProcessRuntime '%stderr_source = select i1 %has_stderr_override, ptr %stderr_override, ptr %stderr_default' "managed Windows child-only stderr handle selection"
Assert-NotContains $managedWindowsProcessRuntime 'sollang_process_output_override' "managed Windows process-global stdout override"
Assert-Contains $managedLinuxProcessRuntime '@sollang_spawn_process_with_stdio' "managed Linux three-direction stdio spawn helper"
Assert-Contains $managedLinuxProcessRuntime '@sollang_spawn_process_configured' "managed Linux instance-configured stdio spawn"
Assert-Contains $managedLinuxProcessRuntime '@sollang_run_process_configured' "managed Linux instance-configured stdio status"
Assert-Contains $managedLinuxProcessRuntime '@sollang_collect_process_configured' "managed Linux bounded process capture"
Assert-Contains $managedLinuxProcessRuntime '@pthread_create' "managed Linux concurrent stream readers"
Assert-Contains $managedLinuxProcessRuntime '@pipe2(ptr %stdout_pipe, i32 524288)' "managed Linux close-on-exec capture pipes"
Assert-Contains $managedLinuxProcessRuntime '@sollang_process_null_linux' "managed Linux null-device path"
Assert-Contains $managedLinuxProcessRuntime '@posix_spawn_file_actions_adddup2(ptr %file_actions, i32 %source_fd, i32 %target_fd)' "managed Linux child-only stdio duplication action"
Assert-Contains $managedLinuxProcessRuntime '@posix_spawn_file_actions_addclose(ptr %file_actions, i32 %source_fd)' "managed Linux child stdio source descriptor close action"
Assert-Contains $managedLinuxProcessRuntime '%source_is_target = icmp eq i32 %source_fd, %target_fd' "managed Linux stdio target close guard"
Assert-Contains $managedLinuxProcessRuntime '@sollang_posix_add_redirect(ptr %file_actions, i32 %stdin_fd, i32 0)' "managed Linux stdin redirect action"
Assert-Contains $managedLinuxProcessRuntime '@sollang_posix_add_redirect(ptr %file_actions, i32 %stdout_fd, i32 1)' "managed Linux stdout redirect action"
Assert-Contains $managedLinuxProcessRuntime '@sollang_posix_add_redirect(ptr %file_actions, i32 %stderr_fd, i32 2)' "managed Linux stderr redirect action"
Assert-NotContains $managedLinuxProcessRuntime '@dup2(i32' "managed Linux parent stdout replacement"
Assert-Contains $platformIo '@sollang_run_process_configured' "selfhost configured Command.status call"
Assert-Contains $platformIo '@sollang_spawn_process_configured' "selfhost configured Command.spawn call"
Assert-Contains $platformIo 'call.opcode == -288 -> if {' "selfhost process collect lowering"
Assert-Contains $platformIo '@sollang_collect_process_configured' "selfhost configured Command.collect call"
Assert-Contains $platformIo 'capturedStdoutType -> writeSemanticTypeId(context, state)' "selfhost canonical captured stdout array ABI"
Assert-Contains $platformIo 'capturedStderrType -> writeSemanticTypeId(context, state)' "selfhost canonical captured stderr array ABI"
Assert-NotContains $platformIo '%sollang.dynamic_int_array' "invented process capture array ABI"
Assert-NotContains $platformIo '@sollang_run_process_to_file' "selfhost legacy statusToFile runtime path"
Assert-Contains $managedProcessEmitter 'ProcessConfiguredInvocationArguments(invocation, output)' "managed configured statusToFile call"
Assert-NotContains $managedProcessEmitter '"sollang_run_process_to_file"' "managed legacy statusToFile runtime call"
Assert-Contains $managedEmitter '_usesProcessCapture = _reachableFunctions.Any' "reachable process capture capability selection"
Assert-Contains $managedEmitter 'function.Kind == BoundFunctionKind.RuntimeCollectProcess' "typed process capture capability selection"
Assert-NotContains $managedEmitter 'call.Path[^1] == "collect"' "name-only process capture capability selection"
Assert-NotContains $managedEmitter 'target.Path[^1] == "collect"' "name-only flowed process capture capability selection"
Assert-Matches $managedSemanticCompiler '(?s)case BoundFunctionKind\.RuntimeCollectProcess:.*?_resolvedGenericCalls\[target\] = function;' "flowed process intrinsic call-site recording"
Assert-Matches $managedSemanticCompiler '(?s)case BoundFunctionKind\.RuntimeCollectProcess:.*?_resolvedGenericCalls\[expression\] = function;' "direct process intrinsic call-site recording"
Assert-Contains $textContext 'declare dllimport i32 @GetProcessId(ptr)' "Windows process identifier declaration"
Assert-Contains $processRuntime '%process_id32 = call i32 @GetProcessId(ptr %handle)' "Windows process identifier capture at spawn"
Assert-Contains $processRuntime '%terminated_id_error = call i32 @TerminateProcess(ptr %handle, i32 1)' "Windows identifier failure termination"
Assert-Contains $processRuntime '%reaped_id_error = call i32 @WaitForSingleObject(ptr %handle, i32 -1)' "Windows identifier failure reap"
Assert-Contains $processRuntime '%ok1 = insertvalue %sollang.process_spawn_result %ok0, i64 %process_id, 1' "Windows process identifier ABI field"
Assert-Contains $processRuntime '%ok1 = insertvalue %sollang.process_spawn_result %ok0, i64 %token, 1' "Linux process identifier ABI field"
Assert-Contains $platformIo '_process_id = extractvalue %sollang.process_spawn_result' "selfhost process identifier extraction"
Assert-Contains $platformIo '_process_id_payload = getelementptr i8' "selfhost nested ProcessId payload projection"
Assert-Contains $platformIo 'store i64 %v$(request.callIndex)_process_id' "selfhost ProcessId field materialization"
Assert-Contains $platformIo "emitProcessProjectionCall" "selfhost zero-wrapper process domain projection"
Assert-Contains $platformIo 'call.opcode == -285 -> if { ", 1" -> println } else { ", 0" -> println }' "selfhost typed process projection ordinals"
Assert-Contains $text "emitProcessProjectionCall(context, state)" "entry process projection emission"
Assert-Contains $functions "emitProcessProjectionCall(context, state)" "function process projection emission"
Assert-Contains $control "emitProcessProjectionCall(context, state)" "control process projection emission"
Assert-Contains $text "not (externalCall.opcode -> typedIr.isProcessProjectionOpcode)" "process projection external-call exclusion"
Assert-Contains $text "not (entryExpression.opcode -> typedIr.isProcessProjectionOpcode)" "entry process projection wrapper-call exclusion"
Assert-Contains $functions "not (expression.opcode -> typedIr.isProcessProjectionOpcode)" "function process projection wrapper-call exclusion"
Assert-Contains $control "not (regionNode.opcode -> typedIr.isProcessProjectionOpcode)" "control process projection wrapper-call exclusion"
Assert-Contains $processRuntime "@sollang_spawn_process" "single process spawn primitive"
Assert-Contains $processRuntime "@sollang_wait_process" "single process wait primitive"
Assert-Contains $processRuntime "@posix_spawnp" "Linux spawn failure boundary"
Assert-Contains $processRuntime "%interrupted = icmp eq i32 %errno, 4" "Linux EINTR wait retry"
Assert-Contains $processRuntime "@sollang_drop_process_child" "attached child drop primitive"
Assert-Contains $ownership "isOwnedProcessChildType" "selfhost Child owned-storage classification"
Assert-Contains $ownership "call void @sollang_drop_process_child(i64 %handle)" "selfhost Child drop glue"
Assert-Contains $processDropVerifier "externalNestedCalls.Count -ne 0" "process Child consumed-payload direct-drop rejection"
Assert-Contains $processDropVerifier "externalRootCalls -gt 1" "process Child outer-owner second-drop rejection"
Assert-Contains $processDropContract "managed/selfhost safe shapes" "process Child drop verifier positive and negative controls"
& $processDropContractPath
Assert-Contains $verificationProcess '$Process.Kill($true)' "timed-out verification process-tree termination"
Assert-Contains $verificationProcess '$Process.WaitForExit($waitSlice)' "bounded verification process wait"
Assert-Contains $verificationProcess 'Invoke-VerificationProcessCapture' "bounded stdout/stderr capture helper"
Assert-Contains $verificationProcess '$startInfo.ArgumentList.Add($argument)' "exact subprocess argument preservation"
Assert-Contains $verificationProcess '$process.StandardOutput.ReadToEndAsync()' "asynchronous stdout pipe drain"
Assert-Contains $verificationProcess '$process.StandardError.ReadToEndAsync()' "asynchronous stderr pipe drain"
Assert-Contains $verificationProcess '$stdoutTask.GetAwaiter().GetResult()' "complete stdout pipe join after bounded wait"
Assert-Contains $compilerEmissionBenchmark 'if ($index % 2 -eq 1) { @("baseline", "candidate") } else { @("candidate", "baseline") }' "balanced alternating compiler-emission order"
Assert-Contains $compilerEmissionBenchmark 'Test-ResumableProfile $profilePath $step.Variant' "receipt-like benchmark resume gate"
Assert-Contains $compilerEmissionBenchmark '$profile.compilerFingerprint -cne $compilerFingerprints[$Variant]' "resumed benchmark compiler identity"
Assert-Contains $compilerEmissionBenchmark '$profile.target -cne $Target' "resumed benchmark target identity"
Assert-Contains $compilerEmissionBenchmark '$profile.workerLimit -ne $Jobs' "resumed benchmark worker identity"
Assert-Contains $compilerEmissionBenchmark 'selfhost-bootstrap-performance-pair.schema.json' "bootstrap performance pair schema gate"
Assert-Contains $compilerEmissionBenchmark 'selfhost-implementation-performance-pair.schema.json' "controlled implementation performance pair schema gate"
Assert-Contains $compilerEmissionBenchmark '[string[]]$Manifest = @(' "focused performance manifest parameter"
Assert-Contains $compilerEmissionBenchmark 'Manifest = $Manifest' "focused performance manifest reaches each measurement"
Assert-Contains $compilerEmissionBenchmark '$MinimumWallImprovementPercent -ne 1' "authenticated pair frozen wall threshold"
Assert-Contains $compilerEmissionBenchmark '$MaximumCpuRegressionPercent -ne 0' "authenticated pair frozen CPU threshold"
Assert-Contains $compilerEmissionBenchmark '$MaximumPeakMemoryRegressionPercent -ne 2' "authenticated pair frozen peak-memory threshold"
Assert-Contains $compilerEmissionBenchmark '$performancePair.baseline.generatedByCompilerFingerprint -cne $performancePair.candidate.generatedByCompilerFingerprint' "controlled implementation same-seed gate"
Assert-Contains $compilerEmissionBenchmark '$performancePair.baseline.dispatch -cne "per-source"' "controlled per-source baseline identity"
Assert-Contains $compilerEmissionBenchmark '$performancePair.candidate.dispatch -cne "compiler-wide"' "controlled compiler-wide candidate identity"
Assert-Contains $compilerEmissionBenchmark '$performancePair.candidate.generatedByCompilerFingerprint -cne $performancePair.baseline.compilerFingerprint' "adjacent bootstrap generation chain"
Assert-Contains $compilerEmissionBenchmark '$performancePair.target -cne $Target' "bootstrap performance pair target identity"
Assert-Contains $compilerEmissionBenchmark '$performancePair.baseline.parallelCallbackCount -eq 3' "managed adjacent Stage1 callback control"
Assert-Contains $compilerEmissionBenchmark '$performancePair.baseline.optimization -cne "O1"' "optimized Stage1 performance control"
Assert-Contains $incrementalVerifier 'if ($BootstrapStage2 -and $Stage1Optimization -eq "O1") {' "O1-only bootstrap performance pair production"
Assert-Contains $incrementalVerifier '} elseif ($BootstrapStage2) {' "O0 bootstrap performance pair deferral"
Assert-Contains $compilerEmissionBenchmark '$performancePair.candidate.nominalTransferCallbackCount -lt 1' "nominal-worker Stage2 callback control"
Assert-Contains $compilerEmissionBenchmark 'Assert-ProfileMatchesPerformancePair $profilePath' "benchmark input bound to selected performance pair"
Assert-Contains $bootstrapPerformancePairSchema '"mode": { "const": "adjacent-bootstrap-performance-pair" }' "bootstrap performance pair schema mode"
Assert-Contains $bootstrapPerformancePairSchema '"generatedByCompilerFingerprint"' "bootstrap performance pair generator identity"
Assert-Contains $compilerEmissionBenchmark 'benchmark profile already exists; pass -Resume' "no implicit benchmark overwrite"
Assert-Contains $compilerEmissionBenchmark '& $measurePath @measureArguments' "serial compiler-emission producer invocation"
Assert-Contains $compilerEmissionBenchmark '& $comparePath `' "compiler-emission comparison invocation"
Assert-NotContains $compilerEmissionBenchmark 'ForEach-Object -Parallel' "concurrent benchmark pollution"
Assert-Contains $c85PerformanceControl '$typedText.Replace($rangeMerge, $perSourceMerge)' "deterministic C85 per-source overlay"
Assert-Contains $c85PerformanceControl 'globalFunctionRequests! -> lowerFunctionRequests' "C85 global-dispatch removal guard"
Assert-Contains $c85PerformanceControl 'sourceFunctionRequests! -> lowerFunctionRequests(parallelFunctions)' "C85 per-source dispatch control"
Assert-Contains $c85PerformanceControl 'c85-per-source-performance-control.schema.json' "C85 control receipt schema"
Assert-Contains $c85PerformanceControl '$verifiedCurrentSourceFingerprint -cne $currentSourceFingerprint' "C85 control mid-generation source drift gate"
Assert-Contains $c85ImplementationPair '$baseline.seedCompilerFingerprint -cne $seedHash' "C85 pair same-seed provenance"
Assert-Contains $c85ImplementationPair '$candidate.generatedByCompilerFingerprint -cne $seedHash' "C85 candidate generation receipt same-seed provenance"
Assert-Contains $c85ImplementationPair '$currentSourceFingerprint -cne $baseline.currentSourceFingerprint' "C85 pair current workload provenance"
Assert-Contains $c85ImplementationPair '$currentSourceFingerprint -cne $candidate.sourceFingerprint' "C85 candidate current workload provenance"
Assert-Contains $c85ImplementationPair '-not $candidate.managedDifferential' "C85 candidate managed differential provenance"
Assert-Contains $c85ImplementationPair 'selfhost-stage1-generation.schema.json' "C85 verified candidate generation receipt schema"
Assert-Contains $c85ImplementationPair 'selfhost-implementation-performance-pair.schema.json' "C85 implementation pair schema"
Assert-Contains $stage1GenerationSchema '"mode": { "const": "verified-selfhost-stage1-generation" }' "Stage1 generation receipt schema mode"
Assert-Contains $stage1GenerationSchema '"focusedExecutionVerified": { "const": true }' "Stage1 generation receipt execution gate"
Assert-Contains ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts/measure-selfhost-compiler-emission.ps1'))) '[void]$stdoutTask.GetAwaiter().GetResult()' "quiet compiler-emission stdout task join"
Assert-Contains $verificationProcess '$stderrTask.GetAwaiter().GetResult()' "complete stderr pipe join after bounded wait"
Assert-NotContains $verificationProcess 'RedirectStandardOutput = $stdoutPath' "no Start-Process capture-file lifetime race"
Assert-Contains $verificationProcessContract '[switch]$IncludeWsl' "optional WSL pipe-capture contract"
Assert-Contains $verificationProcessContract 'concurrent WSL pipe capture' "concurrent WSL relay regression"
Assert-NotContains $verificationProcess '$process.TotalProcessorTime.TotalSeconds' "process-tree telemetry avoids chained TotalSeconds access"
Assert-NotContains $verificationProcess '($observedAt - $previousTelemetryAt).TotalSeconds' "telemetry interval avoids chained TotalSeconds access"
Assert-Contains $verificationProcessExitRace 'live-to-exited snapshots and no chained TotalSeconds access' "process exit-race focused contract"
Assert-Contains $emitContextClosureVerifier 'missing=[' "EmitContext constructor closure failure identity"
Assert-Contains $emitContextClosureContract 'missing=\[second\]' "EmitContext constructor missing-field negative control"
Assert-Matches $stage3Verifier '(?s)verify-emit-context-constructor-closure\.ps1.*?verify-selfhost-compiler-contracts\.ps1' "Stage3 checks EmitContext constructor closure before compiler contracts"
& $verificationProcessContractPath
& $verificationProcessExitRacePath -Iterations 3
& $emitContextClosureContractPath -RepositoryRoot $RepositoryRoot
& $profileSchemaContractPath
& $compilerEmissionProfileContractPath
& $compilerEmissionBenchmarkContractPath
& $c85ImplementationPairContractPath
& $artifactReceiptContractPath
& $artifactReceiptConcurrencyPath
& $nativeExactReceiptContractPath
& $timeApiContractPath -RepositoryRoot $RepositoryRoot
& $browserTimeDomainContractPath -RepositoryRoot $RepositoryRoot
& $stage3ArtifactContractPath
& $releaseOutputScopeContractPath
& $nativeReleasePackageContractPath
Assert-Contains $nativeProcessVerifier "verify-process-child-drop-once.ps1" "native process Child structural drop gate"
Assert-Contains $nativeProcessVerifier "verify-llvm-direct-call-closure.ps1" "native process Child direct-call closure gate"
Assert-Contains $nativeProcessVerifier "Wait-ProcessLifecycleStep `$build 180000" "native process Child build timeout"
Assert-Contains $nativeProcessVerifier "Wait-ProcessLifecycleStep `$run 30000" "native process Child execution timeout"
Assert-Contains $nativeProcessVerifier '^(?:warning S\d+|note N\d+)\b' "native process Child warning and note zero gate"
Assert-Contains $nativeProcessVerifier 'child`nid true`nwait 0' "native process Child identifier/spawn/wait execution proof"
Assert-Contains $nativeProcessVerifier '"--jobs", $Jobs.ToString' "native process Child explicit compiler job budget"
Assert-Contains $linuxProcessVerifier "verify-process-child-drop-once.ps1" "Linux process Child structural drop gate"
Assert-Contains $linuxProcessVerifier "verify-llvm-direct-call-closure.ps1" "Linux process Child direct-call closure gate"
Assert-Contains $linuxProcessVerifier "Wait-LinuxProcessLifecycleStep `$build 180000" "Linux process Child build timeout"
Assert-Contains $linuxProcessVerifier "Wait-LinuxProcessLifecycleStep `$run 30000" "Linux process Child execution timeout"
Assert-Contains $linuxProcessVerifier '^(?:warning S\d+|note N\d+)\b' "Linux process Child warning and note zero gate"
Assert-Contains $linuxProcessVerifier 'child`nid true`nwait 0' "Linux process Child identifier/spawn/wait execution proof"
Assert-Contains $linuxProcessVerifier '"--jobs", $Jobs.ToString' "Linux process Child explicit compiler job budget"
Assert-Contains $textContext "usesStandardError -> textOutputRuntime.emitWasmTextRuntime" "WASM stderr capability routing"
Assert-Contains $textOutputRuntime "declare i32 @sollang_browser_eprint(ptr, i32)" "WASM stderr host boundary"
Assert-Contains $textOutputRuntime "define internal void @sollang_runtime_eprint" "WASM stderr runtime helper"
Assert-Contains $directCallClosure "sollang_runtime_[-a-zA-Z`$._0-9]+" "target-runtime direct-call closure"
Assert-Contains $incrementalVerifier 'verify-selfhost-compiler-contracts.ps1' "pre-build compiler contract gate"
Assert-Contains $incrementalVerifier 'format-authoritative-slg.ps1") -Check' "incremental pre-emission authoritative format gate"
Assert-Contains $incrementalVerifier 'verify-llvm-direct-call-closure.ps1' "focused LLVM direct-call closure gate"
Assert-Contains $incrementalVerifier '. (Join-Path $PSScriptRoot "verification-process.ps1")' "shared bounded verification process helper"
Assert-Contains $incrementalVerifier '[int]$CompilerTimeoutMilliseconds = 3600000' "measured bounded selfhost compiler emission default"
Assert-Contains $nativeExactFixtureVerifier '[int]$TimeoutMilliseconds = 3600000' "native exact fixture measured timeout default"
Assert-Contains $nativeExactFixtureVerifier '-TimeoutMilliseconds $TimeoutMilliseconds' "native exact fixture timeout routing"
Assert-Contains $nativeExactFixtureBatchVerifier '[int]$TimeoutMilliseconds = 3600000' "native exact batch measured timeout default"
Assert-Contains $nativeExactFixtureBatchVerifier '-TimeoutMilliseconds $using:TimeoutMilliseconds' "native exact batch timeout routing"
$sharedTimeoutDefaults = ([regex]::Matches($verificationProcess, '\[int\]\$TimeoutMilliseconds = 3600000')).Count
if ($sharedTimeoutDefaults -ne 4) {
    throw "shared verification timeout defaults drifted: expected 4, actual $sharedTimeoutDefaults"
}
foreach ($timeoutVerifier in @(
    [ordered]@{ Name = "Windows Stage2"; Text = $stage2Verifier; Variable = '$stage2TimeoutMilliseconds' },
    [ordered]@{ Name = "Windows Stage3"; Text = $stage3Verifier; Variable = '$stage3TimeoutMilliseconds' },
    [ordered]@{ Name = "Linux Stage2"; Text = $linuxStage2; Variable = '$stage2TimeoutMilliseconds' },
    [ordered]@{ Name = "Linux Stage3"; Text = $linuxStage3; Variable = '$stage3TimeoutMilliseconds' }
)) {
    Assert-Contains $timeoutVerifier.Text "$($timeoutVerifier.Variable) = 3600000" "$($timeoutVerifier.Name) measured compiler timeout"
    Assert-Contains $timeoutVerifier.Text '-TimeoutMilliseconds $' "$($timeoutVerifier.Name) named timeout budget routing"
    Assert-Contains $timeoutVerifier.Text '-TimeoutStartedAt $' "$($timeoutVerifier.Name) original deadline routing"
    if ($timeoutVerifier.Text -match 'Wait-VerificationProcess[^\r\n]*\s1\s*(?:\r?\n|$)') {
        throw "$($timeoutVerifier.Name) retains the misleading positional one-millisecond timeout"
    }
}
Assert-Contains ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'scripts/measure-selfhost-compiler-emission.ps1'))) '[int]$TimeoutMilliseconds = 3600000' "compiler performance measured timeout"
Assert-Contains $compilerEmissionBenchmark '[int]$TimeoutMilliseconds = 3600000' "compiler benchmark measured timeout"
Assert-Contains $incrementalVerifier 'Invoke-VerificationProcessToFile' "selfhost compiler bounded file-capture path"
Assert-Contains $verificationProcess 'Wait-VerificationProcess' "selfhost compiler process-tree timeout enforcement"
Assert-Contains $verificationProcess 'Publish-VerificationFailureArtifacts' "selfhost compiler timeout and nonzero partial-output preservation"
Assert-Contains $verificationProcess 'throw $originalInvokeError' "selfhost compiler failure preservation retains original diagnostic"
Assert-Contains $verificationProcessContract 'timed-out file capture' "timeout-to-partial-output integration contract"
Assert-Contains $incrementalVerifier 'function Invoke-ProfilePhase' "isolated selfhost profile process boundary"
Assert-Contains $incrementalVerifier '$process.StandardOutput.ReadToEndAsync()' "selfhost profile asynchronous stdout drain"
Assert-Contains $incrementalVerifier '$process.StandardError.ReadToEndAsync()' "selfhost profile asynchronous stderr drain"
Assert-Contains $incrementalVerifier '$process.WaitForExit(25)' "selfhost profile bounded live telemetry sampling"
Assert-Contains $incrementalVerifier '[profile wait]' "selfhost profile long-phase telemetry"
Assert-Contains $incrementalVerifier '$processorMilliseconds = [Math]::Max(' "selfhost profile sampled CPU measurement"
Assert-Contains $incrementalVerifier '$peakWorkingSetBytes = [Math]::Max(' "selfhost profile sampled peak working-set measurement"
Assert-Contains $incrementalVerifier 'Remove-Item -LiteralPath $stage1Receipt -ErrorAction SilentlyContinue' "Stage1 replacement invalidates stale executable receipt"
Assert-Contains $incrementalVerifier 'Remove-Item -LiteralPath $stage1GenerationReceipt -ErrorAction SilentlyContinue' "Stage1 replacement invalidates stale generation receipt"
Assert-Contains $incrementalVerifier 'generatedByCompilerFingerprint = $stage1GeneratorHash' "Stage1 generation receipt records generator identity"
Assert-Contains $incrementalVerifier 'focusedExecutionVerified = $true' "Stage1 generation receipt follows focused execution"
Assert-Contains $incrementalVerifier '$verifiedSourceFingerprint -cne $compilerEmissionSourceFingerprint' "Stage1 generation receipt mid-verification source drift gate"
Assert-NotContains $incrementalVerifier 'RedirectStandardOutput $stdoutPath' "selfhost profile no capture-file lifetime race"
Assert-Contains $coreCalls 'sollang compiler verification failure V009: readonly projected call argument lost its addressable root' "missing readonly projection root diagnostic before bounds access"
Assert-Contains $coreCalls 'referenceNeedsTemporaryRoot and referenceRootBinding >= 0' "missing readonly projection root bounds guard"
Assert-Matches $coreCalls '(?s)referenceRootValueIndex rootBinding: Int.*?rootBinding => valueIndex!.*?context\.ir\[rootBinding\]\.kind != 29.*?context\.ir\[rootBinding\]\.operand0 -> aggregateValueIndex.*?valueIndex!' "projected enum payload roots materialize from their own SSA binding"
Assert-MatchCount $coreCalls 'referenceRootBinding -> referenceRootValueIndex\(context, state\)' 2 "ordinary and while projected-reference paths share enum payload root resolution"
Assert-Contains $coreCalls 'rootBinding -> referenceRootValueIndex(context, state) => referenceRootValue' "forwarded readonly payload addresses share enum payload root resolution"
Assert-Matches $coreCalls 'resolved! >= 0\s+and resolved! < \(context\.ir -> len\)\s+and resolved! != wrapperIndex' "aggregate wrapper sentinel bounds guard"
Assert-Contains $coreCalls 'resolved! >= 0 and resolved! < (context.ir -> len) => commonArmRootOpen!' "missing enum arm result sentinel guard"
Assert-Contains $textOutputRuntime '%redirected_offset = phi i32' "self-host Windows redirected stdout short-write loop"
Assert-Contains $textOutputRuntime '%console_offset = phi i32' "self-host Windows console stdout short-write loop"
Assert-MatchCount $textOutputRuntime '%succeeded = icmp ne i32 %ok, 0' 4 "self-host stdout flush and direct-write failure gates"
Assert-Contains $managedWindowsProcessRuntime '%redirected_offset = phi i32' "managed Windows redirected stdout short-write loop"
Assert-Contains $managedWindowsProcessRuntime '%console_offset = phi i32' "managed Windows console stdout short-write loop"
Assert-Contains $managedWindowsProcessRuntime 'write_direct_failure:' "managed Windows direct stdout failure gate"
Assert-Contains $nativeExactFixtureVerifier '[long]$ExpectedStdoutLength = 0' "native exact stdout length contract"
Assert-Contains $nativeExactFixtureVerifier '$run.Stderr.Length -ne 0 -or $actual.Length -ne $ExpectedStdoutLength' "native exact stdout length and stderr gate"
Assert-Contains $stage2Verifier '1287-windows-large-stdout-complete' "Windows Stage2 complete-write execution fixture"
Assert-Contains $stage2Verifier '-ExpectedStdoutLength 2097152' "Windows Stage2 exact 2 MiB stdout contract"
$partitionExecutionOffset = $stage2Verifier.IndexOf('for ($streamExecutionIndex = 0;', [StringComparison]::Ordinal)
$fullNativeBatchOffset = $stage2Verifier.LastIndexOf('verify-native-exact-fixture-batch.ps1', [StringComparison]::Ordinal)
if ($partitionExecutionOffset -lt 0 -or $fullNativeBatchOffset -lt 0 -or $partitionExecutionOffset -gt $fullNativeBatchOffset) {
    throw "Stage2 partition execution must fail fast before the full native exact batch"
}
$sourceWorkerGoldenProbeOffset = $stage2Verifier.IndexOf('--exact 377-selfhost-llvm-source-text-worker-transfer', [StringComparison]::Ordinal)
if ($sourceWorkerGoldenProbeOffset -lt 0 -or $sourceWorkerGoldenProbeOffset -gt $fullNativeBatchOffset) {
    throw "Stage2 source-worker LLVM golden probe must fail fast before the full native exact batch"
}
Assert-NotContains $stage2Verifier '--update-expected' "Stage2 verification never mutates golden output"
Assert-Contains $typedValueAliases 'sealLateValueAliasTypes nodes: mut [TypedIrNode; ~], prepared: ref semanticContext.SemanticSnapshot -> Unit' "late value alias type sealing helper"
Assert-Contains $typedValueAliases 'sealLateResolvedCallResultTypes nodes: mut [TypedIrNode; ~]' "late resolved call result type sealing helper"
Assert-Contains $typedValueAliases 'mayRefreshValueAlias binding: ref TypedIrNode, value: ref TypedIrNode -> Bool' "canonical value alias no-downgrade authority"
Assert-Contains $typedValueAliases 'canonicalMutableBindingBySymbol![canonicalMutableGlobalSymbol]' "linear exact-symbol mutable rebind type index"
Assert-Contains $typedValueAliases 'nodes[nodes[binding!.operand0].operand0].operand0 == bindingIndex!' "mutable rebind authority is limited to an exact self-referential Result cycle"
Assert-Contains $typedFunctionLowering 'sealLateGrowablePushCollisions results: mut [TypedIrNode; ~]' "late growable push collision recovery helper"
Assert-Contains $typedFunctionLowering 'arm.kind == 19 -> if { arm.nextOperand => armIndex! } else { -1 => armIndex! }' "direct final subject-when arm terminal closure"
Assert-Contains $typedFunctionLowering 'types[growablePushReceiverTypeId!].kind == 3' "late push collision recovery requires a canonical growable-array receiver"
Assert-Contains $typedFunctionLowering 'flowIntrinsicOpcode(' "late push collision recovery reuses canonical intrinsic spelling"
Assert-Contains $typedResolvedContextFinalize 'nodes -> sealLateGrowablePushCollisions(prepared, frozenRecursiveSemanticTypes)' "late push collision recovery follows final nominal member sealing"
Assert-Contains $typedResolvedContextNormalize 'postIndexBinding! -> mayRefreshValueAlias(postIndexBindingValue)' "post-index value alias no-downgrade gate"
Assert-MatchCount $typedResolvedContextFinalize 'nodes -> sealLateResolvedCallResultTypes' 4 "bounded late resolved call result type sealing rounds"
Assert-Matches $typedFunctionLowering 'finalProjectedMethod!\.opcode == -1\s+or finalProjectedMethod!\.opcode == -225\s+or finalProjectedMethod!\.opcode == -226\s+or finalProjectedMethod!\.opcode == -215\s+or finalProjectedMethod!\.opcode == -230' "provisional path and generic trait opcode final declaration resolution"
Assert-MatchCount $typedCore 'nodes -> sealPathRuntimeOpcodes\(prepared\)' 3 "path opcode identity validation checkpoints"
Assert-Matches $typedValueAliases 'binding!\.typeId < 0\s+or \(binding!\.typeOrigin == 1 and binding!\.typeSymbol == 0\)' "late value alias provisional-type boundary"
Assert-Matches $typedValueAliases 'binding!\.flags != 1\s+and nodes\[binding!\.operand0\]\.kind == 15\s+and binding!\.typeId != nodes\[binding!\.operand0\]\.typeId' "immutable indexed binding follows its canonical element type"
Assert-Matches $typedValueAliases '(?s)sealLateResultPropagations nodes: mut \[TypedIrNode; ~\].*?wrapper\.operand1 == producerChild!.*?nodes\[propagationParent!\]\.kind == 30.*?not hasFollowingProducer!.*?resultValue\.typeId -> intrinsicResultTypeId\(types\).*?resultValueIndex! => resultValueByPropagation!\[propagationParent!\].*?producerIndex => propagation!\.operand0' "late Result propagation follows the terminal merged value, including named reads and transparent flow shells"
Assert-MatchCount $typedResolvedContextFinalize 'nodes -> sealLateValueAliasTypes' 11 "Result producers and projected-control aliases seal before and after propagation"
Assert-Contains $lateTypeSealingVerifier 'scripts\contracts\late-type-sealing.sources.txt' "late type sealing uses one authoritative focused source manifest"
Assert-Contains $lateTypeSealingVerifier 'verify-source-manifest-closure.ps1' "late type sealing rejects an incomplete focused source closure before compilation"
Assert-Contains $lateTypeSealingVerifier '$compileOutput$compileErrors' "late type sealing failure reports stdout diagnostics as well as stderr"
Assert-Contains $invariants 'context.ir[node.operand0].kind == 17' "immutable binding read type invariant classification"
Assert-Contains $invariants 'node.opcode == -1 or node.opcode == -215 or node.opcode == -230' "ordinary and provisional path unresolved call identity invariant"
Assert-Contains $invariantDiagnostics 'compiler verification failure V010: immutable value binding read disagrees with its canonical binding' "immutable binding read type mismatch compiler diagnostic"
Assert-Contains $invariantDiagnostics 'do not rewrite the valid `value => name` source' "tap mismatch source repair guidance"
Assert-Contains $typedFunctionLowering 'match! -> normalizeMatchResultTypeFromCompleteArms(matchIndex!, unitTypeId, results, types, flags)' "late enum match authoritative complete-arm closure"
Assert-Contains $invariants 'matchHasCompleteCanonicalNonUnitTerminals context: ref emitterContext.EmitContext' "complete value-producing match terminal invariant"
Assert-Contains $invariants 'typedIr.matchArmTerminalValueIndex(context.ir)' "V011 shares the Typed IR arm-terminal resolver"
Assert-Contains $invariants 'and (context -> matchHasCompleteCanonicalNonUnitTerminals(irIndex))' "V011 production rule integration"
Assert-Contains $invariantDiagnostics 'compiler verification failure V011: value-producing enum match retained provisional Unit' "provisional Unit match compiler diagnostic"
Assert-Contains $invariantDiagnostics 'do not rewrite the valid `when` expression' "provisional Unit match source repair guidance"
Assert-Contains $invariants 'and context.ir[node.operand0].typeOrigin == 1' "Unit value binding canonical initializer origin invariant"
Assert-Contains $invariants 'and context.ir[node.operand0].typeSymbol == 0' "Unit value binding canonical initializer symbol invariant"
Assert-Contains $invariants 'if { 54 => code! }' "Unit value binding pre-LLVM invariant"
Assert-Contains $invariantDiagnostics 'sollang compiler error S054: cannot bind a unit value' "Unit value binding actionable diagnostic"
Assert-Matches $typedResolvedContextFinalize '(?s)settleLateFinalFunctionControlResults.*?candidate\.kind == 18.*?candidate\.kind == 27.*?candidate\.kind == 33.*?candidate\.kind == 34.*?ancestorNode\.kind == 19.*?candidateStart > selectedStart!.*?selectedResult! => functionBody!\.operand0' "late function result convergence selects only the latest top-level type-compatible control"
Assert-Contains $typedResolvedContextFinalize 'nodes -> settleLateFinalFunctionControlResults(prepared)' "late function result convergence runs after final control typing"
Assert-Contains $typedResolvedContextFinalize 'sealFinalFunctionReturnAncestors nodes:' "final implicit return ancestor authority"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> settleLateFinalFunctionControlResults\(prepared\).*?nodes -> sealFinalFunctionReturnAncestors' "function return ancestor sealing is the final result-edge pass"
Assert-Contains $typedResolvedContextFinalize 'sealFinalContextualNumericLiterals nodes:' "final contextual numeric literal closure"
Assert-Matches $typedResolvedContextFinalize '(?s)nodes -> sealFinalFunctionReturnAncestors\(prepared\).*?nodes -> sealLateNominalMemberTypes\(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags, lateNominalMemberChanges!\)\s+nodes -> sealFinalBinaryOperandTopology\(prepared\)\s+nodes -> sealFinalContextualNumericLiterals' "late aliases feed final nominal-member, binary-topology, and numeric-literal consumers"
Assert-Contains $typedResolvedContextFinalize 'canonicalLeft.typeId == canonicalRight.typeId' "final arithmetic width requires exact operand identity"
Assert-Contains $typedResolvedContextSeal 'not finalReturnRootInsideControl! -> if {' "branch-local returned aggregate parent preservation"
Assert-Contains $functionReturns 'scheduledTopLevelReturnCandidate.kind != 26' "straight-line return excludes contextual enum wrapper candidates"
Assert-Matches $functionReturns '(?s)preScheduledReturnCandidate\.kind == 18.*?preScheduledReturnCandidate\.kind == 27.*?preScheduledReturnCandidate\.kind == 33.*?preScheduledReturnCandidate\.kind == 34' "value-producing controls bypass straight-line return replacement"
Assert-Contains $functionReturns 'not preScheduledReturnEmitted!' "materialized source-final return bypasses scheduler replacement"
Assert-Contains $functionReturns 'expressionEmitted[returnValueIndex! - expressionStart] => preScheduledReturnEmitted!' "return replacement reads exact materialization state"
Assert-Contains $functionReturns 'preScheduledReturnCandidate.parent != function.operand0' "nested same-type argument still permits scheduler replacement"
Assert-Contains $coreCalls 'aggregateWrapper.operand0 => resolved!' "transparent aggregate wrapper exact direct value authority"
Assert-Contains $coreCalls 'aggregateWrapper -> sameCanonicalIrType(directAggregateValue)' "transparent aggregate wrapper exact canonical type guard"
Assert-Contains $invariantDiagnostics 'remove the binding when only effects are needed' "Unit value binding effect-only repair guidance"
Assert-Contains $containers 'sollang compiler verification failure V007: while value request escaped canonical Typed IR bounds' "while value writer reports invalid producer edges before indexing"
Assert-Contains $coreCalls 'referencePlaceRootBindingForEmission' "captured readonly projection root resolver"
Assert-Contains $coreCalls 'capturedRoot.sourceModule == context.ir[rootRead!].sourceModule' "captured readonly root source identity"
Assert-Contains $coreCalls 'capturedRoot.symbol == context.ir[rootRead!].symbol' "captured readonly root symbol identity"
Assert-Contains $coreCalls 'functionCapturePositionForBinding' "captured readonly root ABI position resolver"
Assert-Contains $coreCalls 'rootBinding > ownerIndex and rootBinding < state.frozenFunctionEnds[ownerIndex]' "ordinary reference roots bypass capture scans"
Assert-Contains $coreCalls '"%capture_$(capturedRootPosition)" -> print' "captured readonly root address emission"
Assert-Contains $containers 'context.ir[bindingRoot!].kind == 13 or context.ir[bindingRoot!].kind == 15' "mutable parameter classification walks the exact projection root"
Assert-Contains $containers 'bindingRoot! == owner.operand1' "primary mutable parameter exact root identity"
Assert-Contains $containers 'bindingRoot! == parameterIndex!' "additional mutable parameter exact root identity"
Assert-NotContains $containers 'binding.symbol == parameter.symbol' "mutable parameter symbol-number collision fallback"
Assert-Contains $memberSymbolCollisionFixture 'snapshot.package.nodes[index].value' "nested readonly member-index root regression"
Assert-Contains $memberSymbolCollisionFixture 'read snapshot: Snapshot, nodes: mut [Node; ~]' "member and mutable-parameter symbol collision regression"
Assert-Contains $incrementalVerifier 'measurement = "single-process-wall-clock-cpu-peak-working-set"' "selfhost profile schema-v3 measurement identity"
Assert-Contains $incrementalVerifier '$targetExpectedPath = Join-Path $expectedDir "$fixtureName.stdout.$expectedTargetName.txt"' "focused target-specific stdout contract"
Assert-Contains $incrementalVerifier 'Test-Path -LiteralPath $targetExpectedPath' "focused target-specific stdout fallback selection"
Assert-Contains $processStdioLinuxExpected 'stderr=13' "Linux process stdio target-specific stdout fixture"
$incrementalClosureCalls = ([regex]::Matches($incrementalVerifier, 'verify-llvm-direct-call-closure\.ps1')).Count
if ($incrementalClosureCalls -ne 2) {
    throw "incremental LLVM direct-call closure gates drifted: expected host and focused checks, found $incrementalClosureCalls"
}
Assert-Contains $directCallClosure 'compiler verification failure V004' "unresolved direct-call compiler diagnostic"
Assert-Contains $directCallClosure 'compiler verification failure V005' "duplicate LLVM function compiler diagnostic"
Assert-Contains $stage2Verifier 'verify-selfhost-compiler-contracts.ps1' "Stage2 pre-build compiler contract gate"
Assert-Contains $stage2Verifier 'format-authoritative-slg.ps1") -Check' "Stage2 pre-emission authoritative format gate"
Assert-Contains $stage2Verifier 'Assert-VerifiedStage3SeedProvenance' "Windows Stage2 structured Stage3 seed provenance gate"
$windowsLateArraySeedGate = $stage2Verifier.IndexOf('"1217-selfhost-late-indexed-array-type-contract"', [StringComparison]::Ordinal)
$windowsStage2Emission = $stage2Verifier.IndexOf('Write-Host "[stage2 2/7] Build or reuse the complete stage-2 compiler."', [StringComparison]::Ordinal)
if ($windowsLateArraySeedGate -lt 0 -or $windowsStage2Emission -lt 0 -or $windowsLateArraySeedGate -gt $windowsStage2Emission) {
    throw "Windows late indexed-array seed gate must run before complete Stage2 emission"
}
$linuxLateArraySeedGate = $linuxStage2.IndexOf('-Label "linux-stage1-seed"', [StringComparison]::Ordinal)
$linuxStage2Emission = $linuxStage2.IndexOf('Write-Host "[linux-stage2 2/6] Build or reuse the complete Linux stage-2 compiler."', [StringComparison]::Ordinal)
if ($linuxLateArraySeedGate -lt 0 -or $linuxStage2Emission -lt 0 -or $linuxLateArraySeedGate -gt $linuxStage2Emission) {
    throw "Linux late indexed-array seed gate must run before complete Stage2 emission"
}
Assert-Contains $linuxStage2 '-CompilerHost windows' "Linux Stage1 seed exact gate declares its Windows compiler host"
Assert-Contains $linuxStage2 '-CompilationMode raw-llvm' "Linux Stage1 seed exact gate uses the explicit raw Linux LLVM path"
Assert-Contains $linuxStage2 '-AdditionalSource $compilerRuntimeSources' "Linux Stage1 seed exact gate includes its runtime source closure"
Assert-Contains $exampleRunner 'FAIL reusable native sollangc bootstrap emitted a warning or note' "native bootstrap warning and note zero gate"
Assert-Contains $exampleRunner 'unexpected Sollang compiler warning or note' "example compiler warning and note zero gate"
Assert-Contains $stage2Verifier 'verify-llvm-direct-call-closure.ps1' "Stage2 LLVM direct-call closure gate"
Assert-Contains $stage2Verifier 'selfhost-stage2-runtime-intrinsic-abi-separation.slg' "Stage2 runtime intrinsic ABI separation source"
Assert-Contains $stage2Verifier 'stage-2 classified a bodyless runtime intrinsic as a foreign native-library call target' "Stage2 runtime intrinsic ABI separation gate"
Assert-Contains $stage2Verifier '$windowsRuntimeLibraries = @("-lshell32", "-lbcrypt", "-lws2_32")' "Stage2 Windows runtime link contract"
Assert-MatchCount $stage2Verifier '@windowsRuntimeLibraries' 7 "Stage2 runtime and compiler link-contract use"
Assert-Contains $stage2Verifier 'Assert-InputFingerprintStable' "Stage2 promotion input-stability gate"
Assert-Contains $stage2Verifier 'verify-selfhost-owned-block-result-diagnostics.ps1' "Stage2 E27 parity gate"
Assert-Contains $stage2Verifier 'verify-selfhost-unresolved-call-diagnostic.ps1' "Stage2 unresolved-call negative-control gate"
Assert-Contains $stage2Verifier 'verify-selfhost-result-propagation-diagnostics.ps1' "Stage2 Result propagation owner diagnostic gate"
Assert-Contains $stage2Verifier 'Name = "stage1"; Path = $stage1Path' "Stage2 Stage1 unresolved-call diagnostic parity"
Assert-Contains $stage2Verifier 'Name = "stage2"; Path = $stage2Path' "Stage2 candidate unresolved-call diagnostic parity"
Assert-Contains $stage2Verifier '-Label $diagnosticCompiler.Name' "Stage2 unresolved-call generation label"
Assert-Contains $stage2Verifier '--exact 1128-selfhost-late-set-intrinsic-classification' "Stage2 late Set intrinsic differential fixture"
Assert-Contains $stage2Verifier '--exact 1129-selfhost-control-producer-call-shape' "Stage2 control-producer wrapper differential fixture"
Assert-Contains $stage2Verifier '--exact 1162-selfhost-zero-argument-mut-receiver' "Stage2 zero-argument receiver runtime fixture"
Assert-Contains $stage2Verifier '--exact 1163-selfhost-method-receiver-metadata' "Stage2 receiver metadata fixture"
Assert-Contains $stage2Verifier '--exact 1164-selfhost-unqualified-literal-receiver-resolution' "Stage2 literal receiver resolution fixture"
Assert-Contains $stage2Verifier '--exact 1165-selfhost-method-receiver-invariant' "Stage2 receiver invariant fixture"
Assert-Contains $stage2Verifier '--exact 1168-qualified-literal-instance-precedence' "Stage2 typed instance precedence fixture"
Assert-Contains $stage2Verifier '--exact 1169-selfhost-process-instance-precedence' "Stage2 process instance precedence fixture"
Assert-Contains $stage2Verifier '--exact 1170-instance-call-after-each-return' "Stage2 each followed by instance return fixture"
Assert-Contains $stage2Verifier '--exact 1171-process-call-after-each-return' "Stage2 process return after each fixture"
Assert-Contains $stage2Verifier '--exact 1172-selfhost-qualified-impl-receiver' "Stage2 imported nominal impl receiver fixture"
Assert-Contains $stage2Verifier '--exact 1173-selfhost-projected-binding-method' "Stage2 projected inferred binding method fixture"
Assert-Contains $stage2Verifier '--exact 987-selfhost-nested-arithmetic-width-contract' "Stage2 final contextual arithmetic width fixture"
Assert-Contains $stage2Verifier '--exact 1174-selfhost-projected-socket-close-intrinsic' "Stage2 projected socket close intrinsic fixture"
Assert-Contains $stage2Verifier '--exact 1175-ref-struct-receiver-inside-while' "Stage2 readonly struct-reference receiver fixture"
Assert-Contains $stage2Verifier '--exact 1388-selfhost-imported-ref-struct-value-receiver' "Stage2 imported readonly struct-reference receiver fixture"
Assert-Contains $stage2Verifier '--exact 1176-ref-struct-direct-call-forwarding' "Stage2 direct readonly struct-reference forwarding fixture"
Assert-Contains $stage2Verifier '--exact 1095-selfhost-checked-borrowed-owned-return' "Stage2 borrowed owned container-store differential fixture"
Assert-Contains $stage2Verifier '--exact 892-quic-frame-codec' "Stage2 QUIC frame codec fixture"
Assert-Contains $stage2Verifier '--exact 901-quic-ack-frame-ranges' "Stage2 QUIC Ack instance fixture"
Assert-Contains $stage2Verifier '--exact 941-quic-one-rtt-application-engine' "Stage2 QUIC KeyState encode receiver fixture"
Assert-Contains $stage2Verifier '--exact 942-owned-frame-result-field-match' "Stage2 QUIC owned frame result fixture"
Assert-Contains $stage2Verifier '--exact 965-consecutive-frame-encode-owned-payload' "Stage2 QUIC consecutive owned-payload fixture"
Assert-Contains $stage2Verifier '--exact 915-quic-version-negotiation' "Stage2 QUIC version-negotiation instance fixture"
Assert-Contains $stage2Verifier '--exact 916-quic-version-packet' "Stage2 QUIC version-packet instance fixture"
Assert-Contains $stage2Verifier '--exact 1015-quic-p2p-peer-record' "Stage2 QUIC P2P record instance fixture"
Assert-Contains $stage2Verifier '1141-socket-no-delay-instance.slg' "Stage2 socket no-delay native fixture"
Assert-Contains $stage2Verifier 'verify-native-socket-timeouts.ps1' "Stage2 socket-timeout native fixture"
Assert-Contains $stage2Verifier '--exact 854-set-key-only' "Stage2 Set key-only managed oracle fixture"
Assert-Contains $stage2Verifier 'verify-native-set-intrinsics.ps1' "Stage2 candidate Set intrinsic executable gate"
Assert-Contains $stage2Verifier 'verify-native-process-child-lifecycle.ps1' "Stage2 candidate process Child lifecycle and single-drop gate"
Assert-Contains $stage2Verifier 'verify-native-quic-endpoint-ownership.ps1' "Stage2 partial move and QUIC Endpoint routing gate"
Assert-Contains $stage2Verifier 'Wait-VerificationProcess' "Stage2 bounded subprocess gate"
Assert-NotMatches $stage2Verifier '\.WaitForExit\(\s*\)' "Stage2 unbounded subprocess wait"
Assert-Matches $stage2Verifier '(?s)\$stage2WasRebuilt = \$true.*?verify-native-set-intrinsics\.ps1.*?\$stage2Llvm = ' "Stage2 Set gate runs before later candidate inspection"
Assert-Contains $stage3Verifier 'verify-selfhost-compiler-contracts.ps1' "Stage3 pre-build compiler contract gate"
Assert-Contains $stage3Verifier 'format-authoritative-slg.ps1") -Check' "Stage3 pre-emission authoritative format gate"
Assert-Contains $stage3Verifier 'verify-llvm-direct-call-closure.ps1' "Stage3 LLVM direct-call closure gate"
Assert-Contains $stage3Verifier 'Assert-InputFingerprintStable' "Stage3 promotion input-stability gate"
Assert-Contains $stage3Verifier 'selfhost-stage3.inputs.sha256' "Stage3 published content input fingerprint"
Assert-Contains $stage3Verifier 'selfhost-stage3.outputs.sha256' "Stage3 published output artifact receipt"
Assert-Contains $stage3Verifier 'verify-selfhost-stage3-artifacts.ps1' "Stage3 published receipt consumption gate"
Assert-Contains $stage3Verifier 'Write-VerifiedStage3SeedProvenance' "Windows Stage3 structured seed provenance publication"
Assert-Contains $stage3SeedSchema '"mode": { "const": "verified-selfhost-stage3-seed" }' "Stage3 seed provenance schema mode"
Assert-Contains $stage3SeedSchema '"producer"' "Stage3 seed provenance producer binding"
Assert-Contains $stage3SeedSchema '"optimization": { "const": "O1" }' "Stage3 seed provenance optimization binding"
Assert-Contains $stage3SeedSchema '"publishedByStage3Gate": { "const": true }' "Stage3 seed provenance publisher gate"
Assert-Contains $stage3SeedProvenance 'Stage2 and Stage3 LLVM do not form a fixed point' "Stage3 seed publication fixed-point gate"
Assert-Contains $stage3SeedProvenance 'Formal Stage2 SLG seed is not the recorded verified Stage3 executable' "Stage3 seed source-executable identity gate"
Assert-Contains $stage3SeedProvenanceContract 'incremental-stage1.exe' "Stage1-only seed negative control"
Assert-Contains $stage3SeedProvenanceContract 'path escapes the repository' "Stage3 seed provenance path escape negative control"
Assert-Contains $stage3Verifier 'verify-selfhost-owned-block-result-diagnostics.ps1' "Stage3 E27 parity gate"
Assert-Contains $stage3Verifier 'verify-selfhost-unresolved-call-diagnostic.ps1' "Stage3 unresolved-call negative-control gate"
Assert-Contains $stage3Verifier 'verify-selfhost-result-propagation-diagnostics.ps1' "Stage3 Result propagation owner diagnostic gate"
Assert-Contains $stage3Verifier 'Name = "stage2"; Path = $stage2Path' "Stage3 Stage2 unresolved-call diagnostic parity"
Assert-Contains $stage3Verifier 'Name = "stage3"; Path = $stage3Path' "Stage3 candidate unresolved-call diagnostic parity"
Assert-Contains $stage3Verifier '-Label $diagnosticCompiler.Name' "Stage3 unresolved-call generation label"
Assert-Contains $linuxStage2 'verify-selfhost-unresolved-call-diagnostic.ps1' "Linux Stage2 unresolved-call negative-control gate"
Assert-Contains $linuxStage2 'verify-selfhost-result-propagation-diagnostics.ps1' "Linux Stage2 Result propagation owner diagnostic gate"
Assert-MatchCount $linuxStage2 'verify-selfhost-trait-ownership-diagnostics\.ps1' 2 "Linux Stage2 host and candidate trait signature diagnostics"
Assert-Contains $linuxStage2 '-Fixture $traitContractFixtures' "Linux Stage2 focused trait signature selection"
Assert-Contains $linuxStage2 '-Compiler $stage1Path' "Linux Stage2 host Stage1 unresolved-call diagnostic parity"
Assert-Contains $linuxStage2 '-Compiler $stage2Path' "Linux Stage2 candidate unresolved-call diagnostic parity"
Assert-Contains $linuxStage3 'verify-selfhost-unresolved-call-diagnostic.ps1' "Linux Stage3 unresolved-call negative-control gate"
Assert-Contains $linuxStage3 'verify-selfhost-result-propagation-diagnostics.ps1' "Linux Stage3 Result propagation owner diagnostic gate"
Assert-MatchCount $linuxStage3 'verify-selfhost-trait-ownership-diagnostics\.ps1' 1 "Linux Stage3 fixed-point trait signature diagnostic loop"
Assert-Contains $linuxStage3 '-Fixture $traitContractFixtures' "Linux Stage3 focused trait signature selection"
Assert-Contains $linuxStage3 'Name = "linux-stage2"; Path = $stage2Path' "Linux Stage3 Stage2 unresolved-call diagnostic parity"
Assert-Contains $linuxStage3 'Name = "linux-stage3"; Path = $stage3Path' "Linux Stage3 candidate unresolved-call diagnostic parity"
Assert-Contains $traitOwnershipDiagnosticVerifier "[ValidateSet('windows', 'linux')]" "trait diagnostics explicit target contract"
Assert-Contains $traitOwnershipDiagnosticVerifier "Convert-ToTraitDiagnosticWslPath" "trait diagnostics WSL path boundary"
Assert-Contains $traitOwnershipDiagnosticVerifier "@('-d', `$Distribution, '--'" "trait diagnostics WSL compiler execution"
foreach ($traitContractCase in @(
    'trait-contract-count',
    'trait-contract-order',
    'trait-contract-ownership',
    'trait-contract-type',
    'trait-contract-dyn'
)) {
    Assert-Contains $traitOwnershipDiagnosticContract ('"id": "' + $traitContractCase + '"') "trait signature diagnostic $traitContractCase"
    Assert-Contains $linuxStage2 ("'" + $traitContractCase + "'") "Linux Stage2 trait signature case $traitContractCase"
    Assert-Contains $linuxStage3 ("'" + $traitContractCase + "'") "Linux Stage3 trait signature case $traitContractCase"
}
Assert-Contains $stage3Verifier '--exact 1128-selfhost-late-set-intrinsic-classification' "Stage3 late Set intrinsic managed fixture"
Assert-Contains $stage3Verifier '--exact 1129-selfhost-control-producer-call-shape' "Stage3 control-producer wrapper managed fixture"
Assert-Contains $stage3Verifier '--exact 1162-selfhost-zero-argument-mut-receiver' "Stage3 zero-argument receiver runtime fixture"
Assert-Contains $stage3Verifier '--exact 1163-selfhost-method-receiver-metadata' "Stage3 receiver metadata fixture"
Assert-Contains $stage3Verifier '--exact 1164-selfhost-unqualified-literal-receiver-resolution' "Stage3 literal receiver resolution fixture"
Assert-Contains $stage3Verifier '--exact 1165-selfhost-method-receiver-invariant' "Stage3 receiver invariant fixture"
Assert-Contains $stage3Verifier '--exact 1168-qualified-literal-instance-precedence' "Stage3 typed instance precedence fixture"
Assert-Contains $stage3Verifier '--exact 1169-selfhost-process-instance-precedence' "Stage3 process instance precedence fixture"
Assert-Contains $stage3Verifier '--exact 1170-instance-call-after-each-return' "Stage3 each followed by instance return fixture"
Assert-Contains $stage3Verifier '--exact 1171-process-call-after-each-return' "Stage3 process return after each fixture"
Assert-Contains $stage3Verifier '--exact 1172-selfhost-qualified-impl-receiver' "Stage3 imported nominal impl receiver fixture"
Assert-Contains $stage3Verifier '--exact 1173-selfhost-projected-binding-method' "Stage3 projected inferred binding method fixture"
Assert-Contains $stage3Verifier '--exact 987-selfhost-nested-arithmetic-width-contract' "Stage3 final contextual arithmetic width fixture"
Assert-Contains $stage3Verifier '--exact 1174-selfhost-projected-socket-close-intrinsic' "Stage3 projected socket close intrinsic fixture"
Assert-Contains $stage3Verifier '--exact 1175-ref-struct-receiver-inside-while' "Stage3 readonly struct-reference receiver fixture"
Assert-Contains $stage3Verifier '--exact 1388-selfhost-imported-ref-struct-value-receiver' "Stage3 imported readonly struct-reference receiver fixture"
Assert-Contains $stage3Verifier '--exact 1176-ref-struct-direct-call-forwarding' "Stage3 direct readonly struct-reference forwarding fixture"
Assert-Contains $stage3Verifier '--exact 1095-selfhost-checked-borrowed-owned-return' "Stage3 borrowed owned container-store preflight fixture"
Assert-Contains $stage3Verifier '--exact 892-quic-frame-codec' "Stage3 QUIC frame codec fixture"
Assert-Contains $stage3Verifier '--exact 901-quic-ack-frame-ranges' "Stage3 QUIC Ack instance fixture"
Assert-Contains $stage3Verifier '--exact 941-quic-one-rtt-application-engine' "Stage3 QUIC KeyState encode receiver fixture"
Assert-Contains $stage3Verifier '--exact 942-owned-frame-result-field-match' "Stage3 QUIC owned frame result fixture"
Assert-Contains $stage3Verifier '--exact 965-consecutive-frame-encode-owned-payload' "Stage3 QUIC consecutive owned-payload fixture"
Assert-Contains $stage3Verifier '--exact 915-quic-version-negotiation' "Stage3 QUIC version-negotiation instance fixture"
Assert-Contains $stage3Verifier '--exact 916-quic-version-packet' "Stage3 QUIC version-packet instance fixture"
Assert-Contains $stage3Verifier '--exact 1015-quic-p2p-peer-record' "Stage3 QUIC P2P record instance fixture"
Assert-Contains $stage3Verifier '1141-socket-no-delay-instance.slg' "Stage3 socket no-delay parity fixture"
Assert-Contains $stage3Verifier 'verify-native-socket-timeouts.ps1' "Stage3 socket-timeout parity fixture"
Assert-Contains $stage3Verifier 'verify-native-quic-endpoint-ownership.ps1' "Stage3 partial move and QUIC Endpoint routing gate"
Assert-Contains $nativeQuicEndpointOwnershipVerifier '1166-move-method-owned-field-drop.slg' "native partial move cleanup source"
Assert-Contains $nativeQuicEndpointOwnershipVerifier '1167-quic-endpoint-two-connection-routing.slg' "native two-connection Endpoint routing source"
Assert-Contains $nativeQuicEndpointOwnershipVerifier '--jobs $Jobs' "native QUIC Endpoint explicit compiler job budget"
Assert-Contains $nativeQuicEndpointOwnershipVerifier 'WaitForExit(20000)' "bounded native QUIC Endpoint execution"
Assert-Contains $linuxStage2 'verify-native-quic-endpoint-ownership-linux.ps1' "Linux Stage2 partial move and QUIC Endpoint routing gate"
Assert-Contains $linuxStage3 'verify-native-quic-endpoint-ownership-linux.ps1' "Linux Stage3 partial move and QUIC Endpoint routing gate"
Assert-Contains $nativeQuicEndpointOwnershipLinuxVerifier '1166-move-method-owned-field-drop.slg' "Linux native partial move cleanup source"
Assert-Contains $nativeQuicEndpointOwnershipLinuxVerifier '1167-quic-endpoint-two-connection-routing.slg' "Linux native two-connection Endpoint routing source"
Assert-Contains $nativeQuicEndpointOwnershipLinuxVerifier '"--jobs", $Jobs.ToString' "Linux native QUIC Endpoint explicit compiler job budget"
Assert-Contains $nativeQuicEndpointOwnershipLinuxVerifier 'Wait-VerificationProcess' "bounded Linux native QUIC Endpoint execution"
Assert-Contains $stage2Verifier '--exact 1143-enum-match-negative-unary-result' "Stage2 negative unary enum-arm differential fixture"
Assert-Contains $stage3Verifier '--exact 1143-enum-match-negative-unary-result' "Stage3 negative unary enum-arm preflight fixture"
Assert-Contains $stage2Verifier '--exact 1147-mut-parameter-refresh-after-call' "Stage2 mutable-parameter freshness differential fixture"
Assert-Contains $stage3Verifier '--exact 1147-mut-parameter-refresh-after-call' "Stage3 mutable-parameter freshness preflight fixture"
Assert-Contains $stage2Verifier '--exact 1148-second-mut-parameter-refresh-after-call' "Stage2 second mutable-parameter freshness differential fixture"
Assert-Contains $stage3Verifier '--exact 1148-second-mut-parameter-refresh-after-call' "Stage3 second mutable-parameter freshness preflight fixture"
Assert-Contains $stage2Verifier '--exact 1149-control-region-mut-parameter-refresh' "Stage2 control-region mutable-parameter freshness differential fixture"
Assert-Contains $stage3Verifier '--exact 1149-control-region-mut-parameter-refresh' "Stage3 control-region mutable-parameter freshness preflight fixture"
Assert-Contains $stage2Verifier '--exact 1150-while-region-mut-parameter-refresh' "Stage2 while-region mutable-parameter freshness differential fixture"
Assert-Contains $stage3Verifier '--exact 1150-while-region-mut-parameter-refresh' "Stage3 while-region mutable-parameter freshness preflight fixture"
Assert-Contains $stage2Verifier '--exact 1151-mutable-parameter-indexing-matrix' "Stage2 mutable-parameter matrix differential fixture"
Assert-Contains $stage3Verifier '--exact 1151-mutable-parameter-indexing-matrix' "Stage3 mutable-parameter matrix preflight fixture"
Assert-Contains $stage2Verifier '--exact 1152-early-return-before-checked-index' "Stage2 early-return checked-index differential fixture"
Assert-Contains $stage3Verifier '--exact 1152-early-return-before-checked-index' "Stage3 early-return checked-index preflight fixture"
Assert-Contains $stage2Verifier '--exact 1153-checked-index-control-before-logical-result' "Stage2 checked-index control/logical differential fixture"
Assert-Contains $stage3Verifier '--exact 1153-checked-index-control-before-logical-result' "Stage3 checked-index control/logical preflight fixture"
Assert-Contains $stage2Verifier '--exact 1157-call-wrapped-checked-index-after-early-return' "Stage2 call-wrapped checked-index differential fixture"
Assert-Contains $stage3Verifier '--exact 1157-call-wrapped-checked-index-after-early-return' "Stage3 call-wrapped checked-index preflight fixture"
Assert-Contains $stage2Verifier '--exact 1154-multiline-redundant-control-parentheses-note' "Stage2 multiline N002 differential fixture"
Assert-Contains $stage3Verifier '--exact 1154-multiline-redundant-control-parentheses-note' "Stage3 multiline N002 preflight fixture"
Assert-Contains $stage2Verifier '--exact 1155-multiline-partial-control-parentheses-preserved' "Stage2 multiline N002 negative-control fixture"
Assert-Contains $stage3Verifier '--exact 1155-multiline-partial-control-parentheses-preserved' "Stage3 multiline N002 negative-control fixture"
Assert-Contains $stage2Verifier '--exact 1156-interpolation-readonly-struct-reference' "Stage2 interpolation readonly-reference differential fixture"
Assert-Contains $stage3Verifier '--exact 1156-interpolation-readonly-struct-reference' "Stage3 interpolation readonly-reference preflight fixture"
Assert-Contains $stage2Verifier 'verify-native-interpolation-reference-arguments.ps1' "Stage2 interpolation readonly-reference native gate"
Assert-Contains $stage3Verifier 'verify-native-interpolation-reference-arguments.ps1' "Stage3 interpolation readonly-reference native gate"
Assert-Contains $linuxStage2 'verify-native-interpolation-reference-arguments.ps1' "Linux Stage2 interpolation readonly-reference native gate"
Assert-Contains $linuxStage3 'verify-native-interpolation-reference-arguments.ps1' "Linux Stage3 interpolation readonly-reference native gate"
Assert-Contains $stage2Verifier 'verify-native-projected-reference-places.ps1' "Stage2 projected member/index/member native gate"
Assert-Contains $stage3Verifier 'verify-native-projected-reference-places.ps1' "Stage3 projected member/index/member native gate"
Assert-Contains $linuxStage2 'verify-native-projected-reference-places.ps1' "Linux Stage2 projected member/index/member native gate"
Assert-Contains $linuxStage3 'verify-native-projected-reference-places.ps1' "Linux Stage3 projected member/index/member native gate"
Assert-Contains $stage2Verifier 'verify-native-mutable-parameter-indexing-batch.ps1' "Stage2 bounded mutable-parameter freshness native gate"
Assert-Contains $stage3Verifier 'verify-native-mutable-parameter-indexing-batch.ps1' "Stage3 bounded mutable-parameter freshness native gate"
Assert-Contains $stage3Verifier 'verify-native-process-child-lifecycle.ps1' "Stage3 process Child lifecycle and single-drop parity gate"
Assert-Contains $stage3Verifier 'Wait-VerificationProcess' "Stage3 bounded subprocess gate"
Assert-NotMatches $stage3Verifier '\.WaitForExit\(\s*\)' "Stage3 unbounded subprocess wait"
Assert-Contains $linuxStage2 'verify-linux-process-child-lifecycle.ps1' "Linux Stage2 process Child lifecycle and single-drop gate"
Assert-Contains $linuxStage3 'verify-linux-process-child-lifecycle.ps1' "Linux Stage3 process Child lifecycle and single-drop gate"
Assert-Contains $linuxStage3 '1141-socket-no-delay-instance.slg' "Linux Stage2/Stage3 socket no-delay parity fixture"
Assert-Contains $linuxStage3 '1141-socket-no-delay-instance.linux-x64.llvm.contains.txt' "Linux socket no-delay platform LLVM contract"
Assert-Contains $linuxStage3 '1141-socket-no-delay-instance.llvm.regex-counts.txt' "Linux socket no-delay direct-call count contract"
Assert-Contains $linuxStage2 'verify-native-socket-timeouts.ps1' "Linux Stage2 socket-timeout native fixture"
Assert-Contains $linuxStage3 'verify-native-socket-timeouts.ps1' "Linux Stage2/Stage3 socket-timeout parity fixture"
Assert-Contains $stage2Verifier 'verify-native-mutable-parameter-indexing-batch.ps1' "Windows Stage2 bounded checked-index batch"
Assert-Contains $stage3Verifier 'verify-native-mutable-parameter-indexing-batch.ps1' "Windows Stage2/Stage3 bounded checked-index batch"
Assert-Contains $linuxStage2 'verify-native-mutable-parameter-indexing-batch.ps1' "Linux Stage2 bounded checked-index batch"
Assert-Contains $linuxStage3 'verify-native-mutable-parameter-indexing-batch.ps1' "Linux Stage2/Stage3 bounded checked-index batch"
Assert-Contains $linuxStage2 'verify-native-exact-fixture-batch.ps1' "Linux Stage2 exact 1184 through 1189 batch"
Assert-Contains $linuxStage3 'verify-native-exact-fixture-batch.ps1' "Linux Stage3 exact 1184 through 1189 batch"
Assert-Contains $linuxStage2 'verify-verification-process-contract.ps1' "Linux Stage2 WSL pipe-capture preflight"
Assert-Contains $linuxStage3 'verify-verification-process-contract.ps1' "Linux Stage3 WSL pipe-capture preflight"
Assert-Contains $nativeSocketTimeoutVerifier '1142-socket-timeout-instance.slg' "socket-timeout fixture source"
Assert-Contains $nativeSocketTimeoutVerifier '1142-socket-timeout-instance.llvm.contains.txt' "Windows socket-timeout LLVM contract"
Assert-Contains $nativeSocketTimeoutVerifier '1142-socket-timeout-instance.linux-x64.llvm.contains.txt' "Linux socket-timeout LLVM contract"
Assert-Contains $nativeSocketTimeoutVerifier '1142-socket-timeout-instance.llvm.regex-counts.txt' "socket-timeout direct-call count contract"
Assert-Contains $nativeSocketTimeoutVerifier '"--jobs", $Jobs.ToString' "socket-timeout explicit compiler job budget"
Assert-Contains $incrementalVerifier 'selfhost.llvm.regex-counts.txt' "focused self-host LLVM regex-count contract"
Assert-Contains $incrementalVerifier 'selfhost.llvm.ordered-regex.txt' "focused self-host LLVM instruction-order contract"
Assert-Contains $nativeMutableParameterVerifier '1147-mut-parameter-refresh-after-call' "first mutable-parameter verifier case"
Assert-Contains $nativeMutableParameterVerifier '1148-second-mut-parameter-refresh-after-call' "second mutable-parameter verifier case"
Assert-Contains $nativeMutableParameterVerifier '1149-control-region-mut-parameter-refresh' "control-region mutable-parameter verifier case"
Assert-Contains $nativeMutableParameterVerifier '1150-while-region-mut-parameter-refresh' "while-region mutable-parameter verifier case"
Assert-Contains $nativeMutableParameterVerifier '1151-mutable-parameter-indexing-matrix' "mutable-parameter matrix verifier case"
Assert-Contains $nativeMutableParameterVerifier '1152-early-return-before-checked-index' "early-return checked-index verifier case"
Assert-Contains $nativeMutableParameterVerifier '1153-checked-index-control-before-logical-result' "checked-index control/logical verifier case"
Assert-Contains $nativeMutableParameterVerifier '1157-call-wrapped-checked-index-after-early-return' "call-wrapped checked-index verifier case"
Assert-Contains $nativeMutableParameterVerifier '"--jobs", $Jobs.ToString' "checked-index explicit compiler job budget"
Assert-Contains $nativeMutableParameterBatchVerifier '$parallelism = [Math]::Min($Fixture.Count, $Jobs)' "checked-index batch bounded outer concurrency"
Assert-Contains $nativeMutableParameterBatchVerifier '$jobsPerFixture = [Math]::Max(1, [Math]::Floor($Jobs / $parallelism))' "checked-index batch divided compiler budget"
Assert-Contains $nativeMutableParameterBatchVerifier 'ForEach-Object -ThrottleLimit $parallelism -Parallel' "checked-index batch parallel execution"
Assert-Contains $nativeMutableParameterBatchVerifier '$failures -join "`n"' "checked-index batch deterministic failure aggregation"
foreach ($nativeExactFixture in @(
    "1184-non-process-collect-has-no-process-runtime",
    "1185-selfhost-projected-receiver-instance-call",
    "1186-selfhost-interpolation-projected-call-topology",
    "1187-selfhost-raw-string-no-interpolation",
    "1188-io-memory-reader-caller-buffer",
    "1189-selfhost-member-assignment-after-while",
    "1192-readonly-captured-nested-parameter-projection",
    "1193-struct-field-collection-binding-baseline",
    "1194-struct-field-collection-binding-perturbed",
    "1198-parallel-transferable-struct-worker",
    "1199-local-function-parallel-callback",
    "1200-parallel-nominal-readonly-captures",
    "1201-parallel-move-parameter",
    "1202-array-element-owner-replacement-after-read",
    "1203-selfhost-enum-payload-binary-binding",
    "1204-selfhost-enum-payload-binary-binding-permuted",
    "1211-quic-directional-owner-transitions",
    "1212-selfhost-member-assignment-after-take",
    "1213-selfhost-result-field-transfer-after-take",
    "1220-zstd-raw-rle-streaming",
    "1221-numeric-subject-when-arm-result",
    "1222-selfhost-numeric-subject-when-binding",
    "1223-contextual-intrinsic-instance-precedence",
    "1236-socket-send-range-all",
    "1267-mutable-name-suffix-resolution",
    "1302-selfhost-imported-mutable-receiver-rebind",
    "1303-quic-reassembly-account-loop",
    "1304-zstd-literal-only-compressed-block",
    "1305-selfhost-interpolation-numeric-separator",
    "945-quic-flow-control-frames"
)) {
    Assert-Contains $nativeExactFixtureBatchVerifier "`"$nativeExactFixture`"" "native exact batch fixture $nativeExactFixture"
}
Assert-Contains $nativeExactFixtureBatchVerifier 'ForEach-Object -ThrottleLimit $parallelism -Parallel' "native exact batch bounded parallel execution"
Assert-Contains $nativeExactFixtureBatchVerifier '-MinimumCompilerJobs $MinimumCompilerJobs' "native exact batch uses structured worker allocation"
Assert-Contains $nativeExactFixtureBatchVerifier '$jobsPerFixture = $_.CompilerWorkerJobs' "native exact batch routes per-fixture compiler jobs"
Assert-Contains $stage2Verifier '$stage1SeedHeavyFixtures = @(' "Stage2 isolates measured heavy seed fixtures"
Assert-Contains $stage2Verifier '$stage1SeedLightFixtures = @(' "Stage2 preserves the broad cache-compatible seed batch"
Assert-Contains $stage2Verifier '-MinimumCompilerJobs $Stage2BuildJobs' "Stage2 gives each measured heavy seed fixture the complete compiler budget"
Assert-Contains $stage2Verifier 'Stage2 seed heavy/light fixture partition is invalid' "Stage2 rejects a drifting cost-class partition before compilation"
Assert-Contains $nativeExactFixtureBatchVerifier '$results = [System.Collections.Generic.List[object]]::new()' "native exact batch retains streamed worker results"
Assert-Matches $nativeExactFixtureBatchVerifier '(?s)ForEach-Object -ThrottleLimit \$parallelism -Parallel.*?\| ForEach-Object \{.*?\$completedCount \+= 1.*?\[native exact batch \$completedCount/\$totalFixtures\]' "native exact batch reports measured completion as each worker result arrives"
Assert-Contains $nativeExactFixtureBatchVerifier '$requiredInputs = @(' "native exact batch shared-input preflight"
Assert-Contains $nativeExactFixtureBatchVerifier 'Test-Path -LiteralPath $input.Path -PathType $input.Type' "native exact batch fails before worker fan-out on shared-input drift"
Assert-Contains $nativeExactFixtureBatchVerifier '$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path' "native exact batch normalizes compiler identity"
Assert-Contains $nativeExactFixtureBatchVerifier 'Assert-NativeExactFixturePlan -Fixture $Fixture' "native exact batch rejects duplicate artifact writers before fan-out"
Assert-Contains $foundation 'and context.ir[functionBodyIndex].operand0 == nodeIndex!' "function-body direct control result materialization demand"
Assert-Contains $foundation 'context.ir[ownerIndex].kind == 0 or context.ir[ownerIndex].kind == 11' "ordinary and entry function control result owners"
Assert-Contains $typedResolvedContextFinalize 'sealBooleanWhenResultTypes nodes: mut [TypedIrNode; ~] -> Unit' "late Boolean when result-type sealing authority"
Assert-Contains $typedResolvedContextFinalize 'booleanWhenFirstArmType.typeId => booleanWhen!.typeId' "Boolean when adopts its first arm canonical result type"
Assert-Contains $foundation 'node.kind == 33 or node.kind == 34 -> if {' "Boolean and subject when hoisted result storage"
Assert-Contains $control 'emitBooleanWhen whenIndex: Int' "shared Boolean when LLVM control emitter"
Assert-Contains $control 'arm.operand1 -> emitRegionValueRoot(emissionOrder, context, state)' "Boolean when conditional arm root emission"
Assert-Contains $control 'armIndex! -> emitRegionValueRoot(emissionOrder, context, state)' "Boolean when else root emission"
Assert-Contains $control 'booleanWhen -> emitIfResultStore' "Boolean when branch result storage"
Assert-Contains $control 'ptr %if$(whenIndex)_result' "Boolean when merged result load"
Assert-Contains $functionExpressions 'expression.kind == 33 -> if { expressionIndex -> emitBooleanWhen(expressionOrder, context, state) }' "ordinary function Boolean when delegation"
Assert-Contains $entryExpressions 'entryExpression.kind == 33 -> if { entryExpressionIndex -> emitBooleanWhen(entryOrder, context, state) }' "entry function Boolean when delegation"
Assert-Contains $functionScheduling 'or context.ir[containmentAncestor!].kind == 33' "ordinary Boolean when owns flattened arm expressions"
Assert-Contains $entryExpressions 'context.ir[entryScheduleAncestor!].kind == 19 or context.ir[entryScheduleAncestor!].kind == 20 or context.ir[entryScheduleAncestor!].kind == 33' "entry Boolean when owns flattened arm expressions"
Assert-Contains $browserStage2 '1681-function-boolean-when-result.slg' "focused browser Boolean when value regression"
Assert-Contains $control 'ownerBody.kind == 1 and ownerBody.operand0 == matchIndex' "direct function-body match emission demand"
Assert-Contains $typedResolvedContextFinalize 'nodes[finalReturnedBodyIndex!].operand0 == finalReturnedMatchIndex!' "returned match contextual type follows the enclosing body"
Assert-Contains $typedResolvedContextFinalize 'function.typeId => directFunctionResult!.typeId' "direct function-body match adopts the declared return type during return sealing"
Assert-Contains $typedResolvedContextFinalize 'finalReturnedMatch => finalReturnedNode' "returned match arm sealing preserves the direct owner-derived type"
Assert-Contains $nativeExactFixtureBatchVerifier '"1253-readonly-self-consecutive-owned-enum-fields"' "native exact expression-bodied nested enum result fixture"
Assert-Contains $nativeExactFixtureBatchVerifier '"1397-selfhost-while-chained-wide-match-result"' "native exact chained wide-match while regression fixture"
Assert-Contains $nativeExactFixtureBatchVerifier 'Get-NativeExactWindowsCommonInputFingerprint `' "native exact batch hashes shared Windows inputs once"
Assert-Contains $nativeExactFixtureBatchVerifier '-CommonInputFingerprint $using:commonInputFingerprint' "native exact batch forwards shared input identity"
Assert-Contains $nativeExactBatchProfiler 'if (-not $IsWindows)' "native exact performance measurement is explicitly Windows-only"
Assert-Contains $nativeExactBatchProfiler 'Get-CimInstance Win32_Process' "native exact performance measurement observes the complete process tree"
Assert-Contains $nativeExactBatchProfiler '$progress.Add([ordered]@{' "native exact performance measurement retains completion chronology"
Assert-Contains $nativeExactBatchProfiler 'Test-Json -SchemaFile $schemaPath' "native exact performance measurement validates its durable result"
Assert-Contains $nativeExactBatchProfileSummary 'Largest no-completion intervals follow' "native exact performance summary identifies long-tail windows without mislabeling fixture durations"
Assert-Contains $nativeExactBatchProfileSchema '"measurement": { "const": "windows-host-visible-process-tree-and-completion-timeline" }' "native exact performance schema pins the measurement boundary"
Assert-Contains $nativeExactBatchProfileContract '$failure.progress[1].status -cne "FAIL"' "native exact performance contract checks failed fixture preservation"
Assert-Contains $nativeExactBatchProfileContract '$failure.stderrFingerprint' "native exact performance contract checks published failure log integrity"
Assert-Contains $nativeExactBatchProfileContract '$checkpoint.batchStopped' "native exact performance contract checks sampler-failure process cleanup"
Assert-Contains $nativeExactFixtureVerifier 'verify-llvm-direct-call-closure.ps1' "native exact direct-call closure gate"
Assert-Contains $nativeExactFixtureVerifier 'llvm-as.exe' "native exact LLVM assembly gate"
Assert-Contains $nativeExactFixtureVerifier '$sourcePaths = @(if (Test-Path -LiteralPath $sourceManifestPath)' "native exact singleton source closure remains an array"
Assert-Contains $nativeExactFixtureVerifier 'Invoke-VerificationProcessCapture `' "native exact external tools use checked process capture"
Assert-Contains $nativeExactFixtureVerifier '[ValidateSet("", "windows", "linux")][string]$CompilerHost' "native exact explicit compiler host"
Assert-Contains $nativeExactFixtureVerifier '[ValidateSet("native-build", "raw-llvm")][string]$CompilationMode' "native exact explicit compilation mode"
Assert-Contains $nativeExactFixtureVerifier 'native-build requires CompilerHost to match Platform' "native exact rejects cross-host native linking"
Assert-Contains $nativeExactFixtureVerifier 'raw-llvm currently requires CompilerHost windows and Platform linux' "native exact limits raw cross-emission to the supported host and target"
Assert-Contains $nativeExactFixtureVerifier '@("linux", "--jobs", $jobText) + $sourcePaths' "native exact Windows seed emits Linux LLVM without unsupported cross-target CLI linking"
Assert-Contains $nativeExactFixtureVerifier '"--target=x86_64-unknown-linux-gnu", "-c", $llvmPath' "native exact Windows seed cross-compiles a Linux object"
Assert-Contains $nativeExactFixtureVerifier '"-d", $Distribution, "--", "gcc"' "native exact Windows seed links the Linux object inside WSL"
Assert-Contains $nativeExactFixtureVerifier '"-pthread", "-o"' "native exact Linux raw link includes the runtime thread dependency"
Assert-NotContains $nativeExactFixtureVerifier '$LASTEXITCODE' "native exact verifier does not read unset native exit state"
Assert-Contains $nativeExactFixtureVerifier 'selfhost.llvm.regex-counts.txt' "native exact regex-count routing"
Assert-Contains $nativeExactFixtureVerifier 'selfhost.llvm.ordered-regex.txt' "native exact ordered-regex routing"
Assert-Contains $nativeExactFixtureVerifier 'selfhost.llvm.not-contains.txt' "native exact forbidden-text routing"
Assert-Contains $nativeExactFixtureVerifier '(?:warning S\d+|note N\d+)' "native exact warning and note zero gate"
Assert-Contains $nativeExactFixtureVerifier 'Test-NativeExactFixtureReceipt `' "native exact cache requires current input and output identities"
Assert-Contains $nativeExactFixtureVerifier 'cached artifacts authenticated and exact execution revalidated' "native exact cache still executes the verified binary"
Assert-Contains $nativeExactFixtureVerifier 'Get-CurrentWindowsExactInputFingerprint' "native exact rechecks inputs before reuse or publication"
Assert-Contains $nativeExactFixtureVerifier 'Publish-NativeExactFixtureReceipt `' "native exact publishes output and input receipts after execution"
Assert-Matches $nativeExactFixtureVerifier '(?s)if \(-not \$reuseVerifiedArtifacts\) \{.*?verify-llvm-direct-call-closure\.ps1.*?Invoke-VerificationProcessCapture.*?\$run = if.*?Publish-NativeExactFixtureReceipt' "native exact receipt publication follows build, LLVM validation, and execution"
Assert-Contains $nativeSourceStyleVerifier '1154-multiline-redundant-control-parentheses-note' "native multiline N002 diagnostic fixture"
Assert-Contains $nativeSourceStyleVerifier '1155-multiline-partial-control-parentheses-preserved' "native multiline N002 partial-expression negative control"
Assert-Contains $nativeFormatVerifier 'native-format-multiline-parentheses-unformatted.slg' "native multiline N002 formatter input"
Assert-Contains $nativeFormatVerifier 'native-format-multiline-parentheses-formatted.slg' "native multiline N002 formatter output"
Assert-Contains $nativeFormatVerifier 'multiline control-parenthesis idempotence' "native multiline N002 formatter idempotence gate"
Assert-Contains $interpolationReferenceFixture '"$(item -> entryNumber)" -> println' "interpolation readonly-reference call shape"
Assert-Contains $interpolationReferenceSelfhostCounts '_arg0_ref = alloca %sollang\.struct' "interpolation readonly-reference entry slot contract"
Assert-Contains $interpolationReferenceSelfhostCounts ("0`t" + 'call i32 @sollang_m[0-9]+_s[0-9]+\(ptr %v[0-9]+\)') "interpolation aggregate-as-pointer rejection contract"
Assert-Contains $interpolationReferenceSelfhostOrder 'store %sollang\.struct' "interpolation readonly-reference initialization order"
Assert-Contains $nativeInterpolationReferenceVerifier '"--jobs", $Jobs.ToString' "interpolation-reference explicit compiler job budget"
Assert-Contains $foundation 'interpolationCallArgumentNeedsReferenceSlot' "interpolation readonly-reference ABI classification"
Assert-Contains $foundation '_arg$(argumentOrdinal!)_ref = alloca' "interpolation readonly-reference hoisted slot spelling"
Assert-Contains $coreCalls 'emitInterpolationCallReferenceArgumentAllocas' "interpolation readonly-reference entry alloca discovery"
Assert-Contains $nativeInterpolationReferenceVerifier '1156-interpolation-readonly-struct-reference' "native interpolation readonly-reference fixture"
Assert-Contains $nativeInterpolationReferenceVerifier 'verify-llvm-direct-call-closure.ps1' "native interpolation readonly-reference closure gate"
Assert-Contains $nativeInterpolationReferenceVerifier 'llvm-as.exe' "native interpolation readonly-reference structural gate"
Assert-Contains $nativeInterpolationReferenceVerifier 'Invoke-VerificationProcessCapture' "native interpolation readonly-reference bounded subprocess gate"
Assert-Contains $projectedReferenceFixture 'container.items[index].value -> read' "projected member/index/member reference regression shape"
Assert-Contains $projectedReferenceSelfhostOrder '_arg0_place0 = getelementptr inbounds' "projected array-member address contract"
Assert-Contains $projectedReferenceSelfhostOrder '_arg0_array = load %sollang\.array\.i32, ptr %callref' "projected array header load contract"
Assert-Contains $projectedReferenceSelfhostOrder '_arg0_place2 = getelementptr inbounds' "projected indexed-member address contract"
Assert-Contains $projectedReferenceSelfhostForbidden '_arg0_array = load %sollang.array.i32, ptr %arg' "projected root-array reinterpretation rejection contract"
Assert-Contains $nativeProjectedReferenceVerifier '"--jobs", $Jobs.ToString' "projected-reference explicit compiler job budget"
Assert-Contains $coreCalls 'indexedPlace.operand0 -> emitMutableReferenceMemberPlace(' "indexed-reference base member projection"
Assert-Contains $coreCalls '_arg$(referenceArgumentOrdinal)_place$(indexedBaseProjectionDepth! - 1)' "indexed-reference array load from projected member"
Assert-Contains $coreCalls '_arg$(referenceArgumentOrdinal)_place$(indexedBaseProjectionDepth!) = getelementptr' "indexed-reference projection-depth continuation"
Assert-Contains $nativeProjectedReferenceVerifier '1158-member-array-indexed-member-reference' "native projected-reference fixture"
Assert-Contains $nativeProjectedReferenceVerifier 'selfhost.llvm.not-contains.txt' "native projected-reference root-array negative contract"
Assert-Contains $nativeProjectedReferenceVerifier 'verify-llvm-direct-call-closure.ps1' "native projected-reference direct-call closure gate"
Assert-Contains $nativeProjectedReferenceVerifier 'llvm-as.exe' "native projected-reference structural gate"
Assert-Contains $nativeProjectedReferenceVerifier 'Invoke-VerificationProcessCapture' "native projected-reference bounded subprocess gate"
Assert-Contains $nativeMutableParameterBatchVerifier '"1151-mutable-parameter-indexing-matrix"' "checked-index batch mutable-parameter matrix gate"
Assert-Contains $nativeMutableParameterBatchVerifier '"1153-checked-index-control-before-logical-result"' "checked-index batch control/logical gate"
Assert-Contains $nativeMutableParameterBatchVerifier '"1157-call-wrapped-checked-index-after-early-return"' "checked-index batch call-wrapped gate"
Assert-Contains $nativeMutableParameterBatchVerifier '-Fixture $fixtureName' "checked-index batch fixture routing"
Assert-Contains $nativeMutableParameterVerifier '$Fixture.selfhost.llvm.regex-counts.txt' "mutable-parameter freshness count contract routing"
Assert-Contains $nativeMutableParameterVerifier '$Fixture.selfhost.llvm.ordered-regex.txt' "mutable-parameter freshness instruction-order contract routing"
Assert-Contains $mutableParameterFixture 'documents[index] -> documentTextLength' "mutable-parameter freshness regression shape"
Assert-Contains $mutableParameterSelfhostCounts '%callref[0-9]+_arg0_length = load i64, ptr %arg_mut_len_addr' "mutable-reference current-length contract"
Assert-Contains $mutableParameterSelfhostCounts ("0`t" + '%callref[0-9]+_arg0_length = extractvalue') "mutable-reference stale-length rejection contract"
Assert-Contains $mutableParameterSelfhostOrder '%v[0-9]+_in_bounds = icmp ult' "mutable value pre-load bounds contract"
Assert-Contains $secondMutableParameterFixture 'dispatch offset: Int, documents: mut [Document; ~]' "second mutable-parameter freshness regression shape"
Assert-Contains $secondMutableParameterSelfhostCounts '%callref[0-9]+_arg0_length = load i64, ptr %arg1_mut_len_addr' "second mutable-reference current-length contract"
Assert-Contains $secondMutableParameterSelfhostCounts ("0`t" + '%callref[0-9]+_arg0_length = extractvalue') "second mutable-reference stale-length rejection contract"
Assert-Contains $secondMutableParameterSelfhostOrder '%v[0-9]+_in_bounds = icmp ult' "second mutable value pre-load bounds contract"
Assert-Contains $controlRegionMutableParameterFixture 'enabled -> if' "control-region mutable-parameter freshness regression shape"
Assert-Contains $controlRegionMutableParameterSelfhostCounts '%callref[0-9]+_arg0_length = load i64, ptr %arg_mut_len_addr' "control-region mutable-reference current-length contract"
Assert-Contains $controlRegionMutableParameterSelfhostCounts ("0`t" + '%callref[0-9]+_arg0_length = extractvalue') "control-region mutable-reference stale-length rejection contract"
Assert-Contains $controlRegionMutableParameterSelfhostOrder '%v[0-9]+_in_bounds = icmp ult' "control-region mutable value pre-load bounds contract"
Assert-Contains $whileRegionMutableParameterFixture 'iteration! < (documents[index] -> documentTextLength)' "while-region mutable-parameter freshness regression shape"
Assert-Contains $whileRegionMutableParameterSelfhostCounts '%while[0-9]+_v[0-9]+_length = load i64, ptr %arg_mut_len_addr' "while-region current-length contract"
Assert-Contains $whileRegionMutableParameterSelfhostCounts ("0`t" + '%callref[0-9]+_arg0_length = extractvalue') "while-region mutable-reference stale-length rejection contract"
Assert-Contains $whileRegionMutableParameterSelfhostOrder '%while[0-9]+_v[0-9]+_in_bounds = icmp ult' "while-region pre-load bounds contract"
Assert-Contains $mutableParameterMatrixFixture 'dispatchSecond offset: Int, documents: mut [Document; ~]' "mutable-parameter matrix second-ordinal shape"
Assert-Contains $mutableParameterMatrixFixture 'dispatchControl documents: mut [Document; ~], enabled: Bool' "mutable-parameter matrix control-region shape"
Assert-Contains $mutableParameterMatrixFixture 'dispatchWhile documents: mut [Document; ~]' "mutable-parameter matrix while-region shape"
Assert-Contains $mutableParameterMatrixSelfhostCounts ("3`t" + '%v[0-9]+_in_bounds = icmp ult') "mutable-parameter matrix ordinary/control bounds count"
Assert-Contains $mutableParameterMatrixSelfhostCounts ("1`t" + '%while[0-9]+_v[0-9]+_in_bounds = icmp ult') "mutable-parameter matrix while bounds count"
Assert-Contains $mutableParameterMatrixSelfhostOrder '%arg1_mut_len_addr' "mutable-parameter matrix second-ordinal ordering"
Assert-Contains $earlyReturnCheckedIndexFixture '(preferred -> len) > 0 -> if { preferred -> return }' "early-return checked-index control shape"
Assert-Contains $earlyReturnCheckedIndexFixture 'fallback[0]' "early-return checked-index fallback shape"
Assert-Contains $callWrappedCheckedIndexFixture 'fallback[0] -> identityText' "call-wrapped checked-index fallback shape"
Assert-Contains $functionScheduling 'effectAncestor! => effectOrderingIndex!' "checked-index ordering identity promotes to the pure source call"
Assert-Contains $functionScheduling 'context.ir[effectOrderingIndex!] -> sourceStart(context, state)' "checked-index ordering compares from the promoted call root"
Assert-Contains $functionScheduling 'scheduleNode.kind == 6 or scheduleNode.kind == 15 or scheduleNode.kind == 18' "checked-index ordered-effect classification"
Assert-NotContains $functionScheduling 'earlierEffect.kind == 6 or earlierEffect.kind == 15 or earlierEffect.kind == 18' "checked-index child reused as generic earlier-effect barrier"
Assert-Matches $functionScheduling '(?s)parallelRoleMatchesSourceType nodeIndex: Int, parallelIndex: Int.*?false => matches!.*?context\.types\[sourceTypeId!\]\.kind == 8.*?context\.types\[sourceTypeId!\]\.first => sourceTypeId!.*?context\.types\[sourceTypeId!\]\.kind == 3.*?context\.types\[sourceTypeId!\]\.kind == 4.*?context\.types\[sourceTypeId!\]\.kind == 12.*?context\.ir\[nodeIndex\]\.typeId == context\.types\[sourceTypeId!\]\.first\s+=> matches!' "structured parallel roles require exact source-element type identity"
Assert-Matches $functionScheduling '(?s)roleSymbol\.kind == 35.*?parallelCallbackOwner\(context\) => owner!.*?not \(nodeIndex -> parallelRoleMatchesSourceType\(owner!, context\)\).*?-1 => owner!' "provisional structured role symbols fail closed when source element type differs"
Assert-Matches $functionScheduling '(?s)scheduleReady! and \(scheduleNode\.kind == 18 or scheduleNode\.kind == 20 or scheduleNode\.kind == 27 or scheduleNode\.kind == 33 or scheduleNode\.kind == 34\).*?controlDependencyInside! and controlDependencyUse\.kind == 5.*?context\.ir\[controlDependencyUse\.operand0\]\.kind == 17.*?context\.ir\[controlDependencyUse\.operand0\]\.operand0 => controlDependencyValue.*?not controlDependencyValueInside! and not expressionScheduled!\[controlDependencyValue - expressionStart\].*?false => scheduleReady!' "enum matches share the immutable lexical initializer dominance contract with every structured control region"
Assert-Contains $checkedIndexControlLogicalFixture 'context.nodes[context.nodes[parameterIndex].symbol].kind == 3' "nested checked-index logical result shape"
Assert-Contains $stage3Verifier 'Verify LLVM structure, then compare the complete compiler fixed point.' "Windows Stage3 structural verification before fixed-point comparison"
Assert-Contains $linuxStage3 'Verify LLVM structure, compare the fixed point, and link the native compiler.' "Linux Stage3 structural verification before fixed-point comparison"
Assert-Contains $coreCalls 'referenceRootIsMutableContainer' "mutable-reference parameter freshness classification"
Assert-Contains $coreCalls '_arg$(referenceArgumentOrdinal)_length = load i64, ptr' "mutable-reference current-length lowering"
Assert-Contains $functions '%v$(expressionIndex)_length = load i64, ptr' "mutable indexed-value current-length lowering"
Assert-Contains $functions '"v$(expressionIndex)_index_ok:"' "indexed-value pre-load bounds block"
Assert-Contains $control '"  %v$(regionNodeIndex)_length = load i64, ptr "' "control-region mutable indexed-value current-length lowering"
Assert-Contains $control '"v$(regionNodeIndex)_index_ok:"' "control-region indexed-value pre-load bounds block"
Assert-Contains $containers '"  %while$(whileIndex)_v$(valueNodeIndex)_length = load i64, ptr "' "while-region mutable indexed-value current-length lowering"
Assert-Contains $containers '"while$(whileIndex)_v$(valueNodeIndex)_index_ok:"' "while-region indexed-value pre-load bounds block"
Assert-Contains $containers '[Int; ~] => entryValueNodes!' "logical entry-block value schedule"
Assert-Contains $containers 'not emittedLogicalLabel! -> if { entryValueNodes! -> push(valueNodeIndex) }' "logical entry-block dominance capture"
Assert-Contains $containers 'not valueProvidedByEntry! -> if {' "logical RHS duplicate-value suppression"
Assert-MatchCount $containers 'pushBorrowOrdinal >= 0 and not pushStructMember\s+-> if \{' 2 "projected growable-field push excludes direct container-parameter ABI"
Assert-MatchCount $containers 'takeBorrowOrdinal >= 0 and not takeStructMember\s+-> if \{' 2 "projected growable-field take excludes direct container-parameter ABI"
Assert-Contains $containers 'false => hasMemberProjection!' "mutable borrow parameter projection classification"
Assert-Contains $containers 'context.ir[bindingRoot!].kind == 13 -> if { true => hasMemberProjection! }' "nominal member boundary excludes direct container ABI"
Assert-Matches $containers 'parameterIndex! >= 0 and ordinal! < 0 and not hasMemberProjection!\s+-> while \{' "additional mutable parameters exclude projected members"
Assert-Contains $control 'and not armBindingMoved!' "unconditionally transferred enum payload excludes retained cleanup"
Assert-Contains $nativeLanguageServerVerifier 'file:///ascii.slg' "native language-server ASCII URI prefix gate"
Assert-Contains $nativeLanguageServerVerifier 'file:///한글-😀.slg' "native language-server Unicode URI prefix gate"
Assert-Contains $coreCalls 'commonArmRootCandidate.operand0 == resolved!' "enum-arm outer value-root selection"
Assert-Contains $coreCalls 'commonArmRootCandidate.operand1 == resolved!' "enum-arm binary value-root selection"
Assert-Contains $coreCalls 'commonArmRootCandidate.kind != 19' "enum-arm structural region exclusion"
Assert-Contains $coreCalls '# representations.' "enum-arm block and expression common root-selection policy"
Assert-Contains $typedCore 'enumArmNegatedLiteralMatch.typeId => enumArmNegatedLiteralCandidate!.typeId' "enum-arm negated unary contextual type"
Assert-Contains $typedCore 'enumArmNegatedLiteralMatch.typeId => enumArmNegatedLiteralValue!.typeId' "enum-arm negated literal contextual type"
Assert-Contains $enumNegativeFixture 'Option<Long>.None => -1' "negative unary enum-arm regression fixture"
Assert-Contains $enumNegativeSelfhostCounts 'store i64 1, ptr %v[0-9]+_result' "negative unary literal-store rejection contract"
Assert-Contains $nativeSocketTimeoutVerifier 'verify-llvm-direct-call-closure.ps1' "socket-timeout direct-call closure gate"
Assert-Contains $nativeSocketTimeoutVerifier 'Invoke-VerificationProcessCapture' "socket-timeout bounded compiler and executable gate"
Assert-NotMatches $nativeSocketTimeoutVerifier '\.WaitForExit\(\s*\)' "socket-timeout unbounded subprocess wait"
Assert-Contains $linuxStage2 'artifacts\incremental-selfhost\selfhost-slg-seed.exe' "Linux Stage2 receipt-bound SLG-first seed"
Assert-Contains $linuxStage2 'selfhost-slg-seed.sha256' "Linux Stage2 SLG seed verification receipt"
Assert-Contains $linuxStage2 'Assert-VerifiedStage3SeedProvenance' "Linux Stage2 structured Windows Stage3 seed provenance gate"
Assert-NotContains $linuxStage2 'dotnet run' "Linux Stage2 managed bootstrap"
Assert-Contains $linuxStage2 'selfhost-stage2-linux.inputs.sha256' "Linux Stage2 content input fingerprint"
Assert-Contains $linuxStage2 'selfhost-stage2-linux.outputs.sha256' "Linux Stage2 output artifact receipt"
Assert-MatchCount $linuxStage2 '-AdditionalArtifacts\s+@\{\s*object\s*=' 6 "Linux Stage2 object receipt coverage"
Assert-Contains $linuxStage2 'Get-CandidateArtifactPath' "Linux Stage2 candidate-only generation"
Assert-Contains $linuxStage2 '[switch]$ResumeCandidate' "Linux Stage2 authenticated candidate resume option"
Assert-Contains $linuxStage2 'RESUME receipt-bound Linux Stage2 candidate' "Linux Stage2 candidate resume path"
Assert-Contains $linuxStage2 '-AdditionalArtifacts @{ object = $stage2CandidateObjectPath }' "Linux Stage2 resumed object receipt authentication"
Assert-Contains $linuxStage2 'Assert-InputFingerprintStable' "Linux Stage2 pre-promotion input stability"
Assert-NotContains $linuxStage2 '.LastWriteTimeUtc' "Linux Stage2 timestamp cache authority"
Assert-Contains $linuxStage2 'Wait-VerificationProcess' "Linux Stage2 bounded subprocess gate"
Assert-Contains $linuxStage3 'Wait-VerificationProcess' "Linux Stage3 bounded subprocess gate"
Assert-NotMatches $linuxStage2 '\.WaitForExit\(\s*\)' "Linux Stage2 unbounded subprocess wait"
Assert-NotMatches $linuxStage3 '\.WaitForExit\(\s*\)' "Linux Stage3 unbounded subprocess wait"
Assert-Contains $linuxStage3 'selfhost-stage2-linux.outputs.sha256' "Linux Stage3 verified Stage2 input artifact receipt"
Assert-Contains $linuxStage3 '$stage2ObjectPath = Join-Path $artifactsDir "selfhost-stage2-linux.o"' "Linux Stage3 declared Stage2 object receipt input"
Assert-Contains $linuxStage3 'selfhost-stage3-linux.inputs.sha256' "Linux Stage3 content input fingerprint"
Assert-Contains $linuxStage3 'selfhost-stage3-linux.outputs.sha256' "Linux Stage3 output artifact receipt"
Assert-MatchCount $linuxStage3 '-AdditionalArtifacts\s+@\{\s*object\s*=' 4 "Linux Stage3 object receipt coverage"
Assert-Contains $linuxStage3 'verify-selfhost-stage3-artifacts.ps1' "Linux Stage3 published receipt consumption gate"
Assert-Contains $linuxStage3 'Get-CandidateArtifactPath' "Linux Stage3 candidate-only generation"
Assert-Contains $linuxStage3 'Assert-InputFingerprintStable' "Linux Stage3 pre-promotion input stability"
Assert-NotContains $linuxStage3 '.LastWriteTimeUtc' "Linux Stage3 timestamp cache authority"
Assert-Contains $stage3Verifier '--exact 854-set-key-only' "Stage3 Set key-only managed fixture"
Assert-Contains $stage3Verifier 'verify-native-set-intrinsics.ps1' "Stage3 candidate Set intrinsic executable gate"
Assert-Matches $stage3Verifier '(?s)WriteAllText\(\$stage3CandidateFingerprintPath.*?verify-native-set-intrinsics\.ps1.*?verify-selfhost-owned-block-result-diagnostics\.ps1' "Stage3 Set gate runs before later native gates"
Assert-Contains $releasePublisher 'verify-selfhost-compiler-contracts.ps1' "release pre-build compiler contract gate"
Assert-Contains $releasePublisher '-RequireZeroKnownDefects' "release zero-known-defect gate"
Assert-Matches $releasePublisher '(?s)verify-selfhost-compiler-contracts\.ps1.*?verify-compiler-defects\.ps1.*?-RequireZeroKnownDefects.*?native-release-package\.ps1.*?Invoke-NativeReleasePackaging' "release gates precede package work"
Assert-Contains $nativeReleasePackage 'verify-selfhost-stage3-artifacts.ps1' "release Stage3 provenance gate"
Assert-Contains $nativeReleasePackage 'Remove-OwnedReleasePath' "release owned-child cleanup gate"
Assert-Contains $nativeReleasePackage 'Native release dry-run output must stay under the OS temporary directory' "release dry-run OS-temp boundary"
Assert-Contains $nativeReleasePackageContract 'keep-unowned.txt' "release unowned output-root sentinel negative control"
Assert-Contains $nativeReleasePackageContract '[System.IO.Path]::GetPathRoot($temporaryRoot)' "release volume-root negative control"
Assert-Contains $nativeReleasePackageContract 'foreach ($broadRoot in @($repositoryRoot,' "release repository-root negative control"
Assert-NotContains $nativeReleasePackageContract 'publish-release.ps1' "release dry-run has no zero-defect circular dependency"
Assert-NotMatches $releasePublisher 'Remove-Item\s+-LiteralPath\s+\$OutputRoot\s+-Recurse' "release broad output-root deletion"
Assert-Contains $stage3ArtifactVerifier 'Test-Stage2ArtifactReceipt' "published Stage3 output receipt verification"
Assert-Contains $stage3ArtifactVerifier 'actualInputFingerprint -cne $expectedInputFingerprint' "published Stage3 current-input verification"
Assert-Contains $stage3ArtifactVerifier 'stage2LlvmHash -cne $stage3LlvmHash' "published Stage2/Stage3 fixed-point verification"
Assert-Contains $stage3ArtifactVerifier 'stage2OutputReceiptPath' "published Stage2 artifact receipt verification"
Assert-Contains $stage3ArtifactVerifier '$additionalArtifacts.object' "published Linux Stage3 object verification"
Assert-Contains $browserStage2 'verify-llvm-direct-call-closure.ps1' "browser Stage2 LLVM direct-call closure gate"
Assert-Contains $browserStage2 'Wait-VerificationProcess' "browser Stage2 bounded compiler emission"
Assert-Contains $browserStage2 'Invoke-VerificationProcess' "browser Stage2 bounded toolchain and Node execution"
Assert-Contains $browserStage2 'sollangc-browser.inputs.sha256' "browser compiler input fingerprint receipt"
Assert-Contains $browserStage2 'sollangc-browser.outputs.sha256' "browser compiler output artifact receipt"
Assert-Contains $browserStage2 'Test-Stage2ArtifactReceipt' "browser compiler reuse output authentication"
Assert-Contains $browserStage2 'Get-BrowserStage2InputFingerprint' "browser compiler reuse current-input authentication"
Assert-Contains $browserStage2 'browser-stage2-input-fingerprint.ps1' "browser compiler shared current-input inventory"
Assert-Contains $browserStage2Fingerprint '(?:examples|tests)' "browser input fingerprint executable and diagnostic fixture inventory"
Assert-Contains $browserStage2Fingerprint '(?:ps1|mjs)' "browser input fingerprint verifier and host inventory"
Assert-Contains $browserStage2Fingerprint 'verify-browser-stage2-artifacts.ps1' "browser input fingerprint independent artifact consumer"
Assert-Contains $browserStage2ArtifactVerifier 'Test-Stage2ArtifactReceipt' "browser artifact output integrity verification"
Assert-Contains $browserStage2ArtifactVerifier 'Get-BrowserStage2InputFingerprint' "browser artifact current input fingerprint verification"
Assert-Contains $browserStage2ArtifactVerifier 'published browser compiler differs from the verified Stage2 artifact' "browser public artifact equality verification"
Assert-Contains $browserStage2 'browser compiler artifact is missing, mutated, or stale' "browser compiler stale reuse fail-fast guidance"
Assert-Contains $browserStage2 '(@("format", "--check") + $browserSources)' "browser compiler complete source-format gate"
Assert-Contains $browserStage2 'verify-selfhost-stage3-artifacts.ps1' "browser compiler current native fixed-point preflight"
Assert-Contains $browserStage2 '-Platform windows' "browser compiler Windows fixed-point platform"
Assert-Contains $browserStage2 '$AllowUnpromotedCandidate -ne $focusedMode' "focused browser candidate requires an explicit single-fixture mode"
Assert-Contains $browserStage2 'browser compiler output must remain under $artifactRoot' "focused browser outputs remain inside artifacts"
Assert-Contains $browserStage2 'focused browser fixture is not registered exactly once' "focused browser fixture selection is exact and fail-fast"
Assert-Contains $browserStage2 'if (-not $focusedMode)' "focused browser candidate skips the unrelated diagnostic suite"
Assert-Contains $browserStage2 'Retain the verified focused candidate under artifacts without publication' "focused browser candidate cannot publish the public compiler"
Assert-Contains $browserStage2 'compiler builds require empty stderr' "browser compiler warning and note zero gate"
Assert-Contains $browserStage2 '_append_capacity, 32' "browser compiler SourceText 32-byte allocation gate"
Assert-Contains $browserStage2 'getelementptr %sollang\.source_text' "browser compiler SourceText typed-slot allocation gate"
$browserDiagnosticSuiteOffset = $browserStage2.IndexOf('foreach ($diagnosticCase in @(', [StringComparison]::Ordinal)
$browserReceiptPublishOffset = $browserStage2.LastIndexOf('Write-Stage2ArtifactReceipt', [StringComparison]::Ordinal)
if ($browserDiagnosticSuiteOffset -lt 0 -or $browserReceiptPublishOffset -le $browserDiagnosticSuiteOffset) {
    throw "browser compiler receipts must publish only after the executable and diagnostic regression suites"
}
Assert-NotMatches $browserStage2 'Start-Process(?s:.*?)-Wait\b' "browser Stage2 unbounded compiler emission"
Assert-NotMatches $browserStage2 '(?m)^\s*&\s+(?:node|\$llvmAs|\$clang|\$wasmLd)\b' "browser Stage2 direct unbounded toolchain or Node execution"
Assert-Contains $browserStage2 'examples\regression\854-set-key-only.slg' "browser Stage2 Set key-only fixture"
Assert-Contains $browserStage2 'examples\regression\1134-wasm-struct-array-i64-fragment-identity.slg' "browser produced-program realloc preservation fixture"
Assert-Contains $browserStage2 'examples\regression\1135-wasm-uintsize-interpolation-width.slg' "browser emitted-storage interpolation width fixture"
Assert-Contains $browserStage2 'examples\regression\1136-wasm-trailing-value-if-effect.slg' "browser trailing value-if scheduling fixture"
Assert-Contains $browserStage2 'examples\regression\1137-browser-open-import-second-fragment.slg' "browser second-fragment open-import fixture"
Assert-Contains $browserStage2 'examples\regression\1321-parallel-additional-borrow-result.slg' "browser parallel additional-reference argument fixture"
Assert-Contains $browserStage2 'examples\regression\1017-quic-friendly-ipv4-endpoints.slg' "browser pure QUIC endpoint non-poisoning fixture"
Assert-Contains $browserStage2 'examples\regression\1024-socket-ipv6-udp-roundtrip.slg' "browser reachable socket capability diagnostic fixture"
Assert-Contains $browserStage2 'network sockets are unavailable on wasm32-browser; use a host-provided networking adapter' "browser reachable socket repair guidance"
Assert-Contains $browserStage2 'examples\regression\diagnostics\return-outside-function.slg' "browser return-outside-function parity fixture"
Assert-Contains $emitterDiagnostics 'returnOutsideFunctionCount' "selfhost return-outside-function semantic gate"
Assert-Contains $emitterDiagnostics "'return' is only valid inside a value or Unit function" "selfhost return-outside-function repair guidance"
Assert-Contains $emitterDiagnostics 'resultPropagationOutsideResultFunctionCount' "selfhost Result propagation owner semantic gate"
Assert-Contains $emitterDiagnostics "in main, match the Result explicitly with '-> when' and handle Ok/Err" "selfhost entry Result propagation repair guidance"
Assert-Contains $resultPropagationDiagnosticVerifier 'result-propagation-in-entry.slg' "selfhost entry Result propagation negative fixture"
Assert-Contains $resultPropagationDiagnosticVerifier 'compiler verification failure V006' "selfhost entry Result propagation invariant-cascade rejection"
Assert-Contains $semanticContext 'calls.resolveModulesTyped(semanticSet)' "semantic context typed multi-fragment call resolver"
Assert-Matches $foundation 'node\.kind == 6 and \(node\.opcode == -101 or node\.opcode == -236\)\s*-> if \{ 64 => width! \}' "selfhost interpolation length/capacity emitted-storage width override"
Assert-NotContains $foundation '(node.kind == 6 and node.opcode == -101)' "selfhost interpolation redundant whole-condition parentheses"
Assert-Contains $ownership 'symbol == 24 -> if { 32 => result! }' "SourceText target-independent emitted ABI size"
Assert-Contains $ownership 'symbol == 24 -> if { 8 => result! }' "SourceText i64-bearing emitted ABI alignment"
Assert-Contains $text 'entryPriorControlValueInsideRegion!' "entry control scheduler ignores separately emitted control-region values"
Assert-Contains $text 'entryPriorControlValueOwnsControl' "entry control scheduler ignores values owned by the control being scheduled"
Assert-Contains $text 'entryScheduleReady! and (entryScheduleNode -> isEntrySchedulingControl)' "entry enum matches wait for prior external value dependencies"
Assert-Contains $browserStage2Runner 'sourceName === "1135-wasm-uintsize-interpolation-width.slg"' "browser interpolation width structural gate"
Assert-Contains $browserStage2Runner 'sourceName === "1136-wasm-trailing-value-if-effect.slg"' "browser trailing value-if structural gate"
Assert-Contains $browserStage2Runner '!output.includes("call void @sollang_runtime_print(")' "browser trailing value-if stable console abstraction gate"
Assert-Contains $browserStage2Runner 'const fragments = stdlibByNamespace.get(entry.namespace) ?? []' "browser stdlib multi-fragment namespace collection"
Assert-Contains $browserStage2Runner 'for (const entry of fragments)' "browser stdlib multi-fragment namespace expansion"
Assert-Contains $browserStage2Runner 'option === "--source-manifest"' "browser explicit selfhost source-manifest option"
Assert-Contains $browserStage2Runner 'option === "--expect-diagnostic"' "browser explicit diagnostic option"
Assert-Contains $browserStage2Runner 'option === "--expect-diagnostic-base64"' "browser process-safe encoded diagnostic option"
Assert-Contains $browserStage2Runner 'const compilerMessages = diagnostics + output' "browser compiler combined diagnostic-channel verification"
Assert-Contains $browserStage2 '"--source-manifest"' "browser source-manifest invocation without an empty positional placeholder"
Assert-Contains $browserStage2 '[Convert]::ToBase64String(' "browser UTF-8 diagnostic process-boundary encoding"
Assert-Contains $browserStage2 '"--expect-diagnostic-base64"' "browser diagnostic invocation with a process-safe explicit option"
Assert-NotContains $browserStage2 '$compilerArguments += ""' "browser empty positional verifier placeholder"
Assert-Contains $browserStage2Runner 'explicitSources.flatMap(entry => importedNamespaces(entry.source))' "browser explicit-source transitive stdlib imports"
Assert-NotMatches $browserStage2Runner 'new Map\(stdlib\.map\(entry => \[entry\.namespace, entry\]\)\)' "browser last-fragment-wins stdlib namespace map"
Assert-Contains $browserProgramRunner 'const allocationSizes = new Map()' "browser program allocation-size tracking"
Assert-Contains $browserProgramRunner 'const copyLength = Math.min(previousLength, length)' "browser program realloc content preservation"
Assert-NotMatches $browserProgramRunner 'sollang_browser_realloc:\s*\(_pointer, length\)\s*=>\s*allocate\(length\)' "browser program discarding realloc"
Assert-Contains $linuxStage2 'verify-llvm-direct-call-closure.ps1' "Linux Stage2 LLVM direct-call closure gate"
Assert-Contains $linuxStage2 '854-set-key-only.selfhost.llvm.not-contains.txt' "Linux Stage2 Set intrinsic candidate gate"
Assert-Contains $linuxStage3 'verify-llvm-direct-call-closure.ps1' "Linux Stage3 LLVM direct-call closure gate"
Assert-Contains $linuxStage3 '854-set-key-only.selfhost.llvm.not-contains.txt' "Linux Stage3 Set intrinsic candidate gate"
Assert-Contains $nativeBinaryVerifier 'verify-llvm-direct-call-closure.ps1' "native binary LLVM direct-call closure gate"
Assert-Contains $nativeSetVerifier '854-set-key-only.selfhost.llvm.not-contains.txt' "native Set unresolved-sentinel negative contract"
Assert-Contains $nativeSetVerifier 'verify-llvm-direct-call-closure.ps1' "native Set LLVM direct-call closure gate"
Assert-Contains $nativeSetVerifier 'if (-not $?)' "PowerShell-native Set closure gate status"
Assert-Contains $nativeQuicEndpointOwnershipVerifier 'verify-llvm-direct-call-closure.ps1' "native QUIC Endpoint ownership direct-call closure gate"
Assert-Contains $nativeQuicEndpointOwnershipLinuxVerifier 'verify-llvm-direct-call-closure.ps1' "Linux QUIC Endpoint ownership direct-call closure gate"
foreach ($quicOwnershipGate in @(
    [ordered]@{ Name = "Windows"; Text = $nativeQuicEndpointOwnershipVerifier },
    [ordered]@{ Name = "Linux"; Text = $nativeQuicEndpointOwnershipLinuxVerifier }
)) {
    Assert-Contains $quicOwnershipGate.Text '$totalCases = $cases.Count' "$($quicOwnershipGate.Name) QUIC ownership measured denominator"
    Assert-Contains $quicOwnershipGate.Text '[native QUIC Endpoint ownership $caseNumber/$totalCases] BUILD' "$($quicOwnershipGate.Name) QUIC ownership live build progress"
    Assert-Contains $quicOwnershipGate.Text '[native QUIC Endpoint ownership $completedCases/$totalCases] PASS' "$($quicOwnershipGate.Name) QUIC ownership live pass progress"
}
Assert-Contains $unresolvedCallDiagnosticVerifier 'unknown-value-flow-target.slg' "unresolved-call diagnostic fixture"
Assert-Contains $unresolvedCallDiagnosticVerifier "unresolved call target 'println2'" "exact unresolved-call diagnostic"
Assert-Contains $unresolvedCallDiagnosticVerifier 'open-import-ambiguous.slg' "open-import ambiguity diagnostic fixture"
Assert-Contains $unresolvedCallDiagnosticVerifier 'open-import-ambiguous.stderr.contains.txt' "open-import ambiguity expected guidance"
Assert-Contains $unresolvedCallDiagnosticVerifier '[regex]::Matches' "single unresolved-call diagnostic gate"
Assert-Contains $unresolvedCallDiagnosticVerifier "'(?m)^target (datalayout|triple)'" "unresolved-call pre-LLVM gate"
Assert-Contains $unresolvedCallDiagnosticVerifier 'Invoke-VerificationProcessCapture' "unresolved-call bounded capture helper"
Assert-Contains $unresolvedCallDiagnosticVerifier '[ValidateSet("windows", "linux")]' "unresolved-call target contract"
Assert-Contains $unresolvedCallDiagnosticVerifier '"-d", $Distribution, "--"' "unresolved-call WSL compiler execution"
foreach ($boundedVerifier in @(
    [ordered]@{ Name = "native Set"; Text = $nativeSetVerifier },
    [ordered]@{ Name = "native binary"; Text = $nativeBinaryVerifier },
    [ordered]@{ Name = "native source style"; Text = $nativeSourceStyleVerifier },
    [ordered]@{ Name = "native format"; Text = $nativeFormatVerifier },
    [ordered]@{ Name = "owned block diagnostic"; Text = $ownedBlockVerifier }
)) {
    Assert-Contains $boundedVerifier.Text 'Wait-VerificationProcess' "$($boundedVerifier.Name) bounded subprocess gate"
    Assert-NotMatches $boundedVerifier.Text '\s-Wait\b|\.WaitForExit\(\s*\)' "$($boundedVerifier.Name) unbounded subprocess wait"
}
Assert-NotMatches $stage3Verifier '(?m)^\s*&\s+\$stage3Path\s+build\b' "Stage3 direct unbounded compiler build"
Assert-NotMatches $stage2Verifier '(?m)=\s*\(&\s+\$[A-Za-z][A-Za-z0-9]*Executable\b' "Stage2 direct unbounded fixture execution"
Assert-NotMatches $stage3Verifier '(?m)=\s*\(&\s+\$[A-Za-z][A-Za-z0-9]*Executable\b' "Stage3 direct unbounded fixture execution"
Assert-NotMatches $nativeSetVerifier '(?m)=\s*\(&\s+\$executablePath\b' "native Set direct unbounded fixture execution"
Assert-NotMatches $nativeBinaryVerifier '(?m)=\s*\(&\s+\$Executable\b' "native binary direct unbounded fixture execution"
Assert-Contains $unresolvedCallFixture 'materialized linked-argument unresolved call invariant' "V006 materialized call-shape fixture"
Assert-Contains $unresolvedCallFixture 'transparent control producer wrapper invariant' "S047 and V006 transparent producer positive control"
Assert-Contains $unresolvedCallFixture 'duplicate trailing call invariant' "S047 concrete trailing-call negative control"
Assert-Contains $unresolvedCallFixture 'compiler stream slice invariant' "V006 compiler stream-slice positive control"
Assert-Contains $lateSetFixture 'makeSet: -> Set<Int> uses Console' "late Set effect-bearing function fixture"
Assert-Contains $lateSetFixture 'set ordinary=$(ordinarySetCalls!),materialized=$(materializedSetCalls!)' "late Set ordinary/materialized call-shape fixture"
Assert-Contains $lateSetExpected 'set ordinary=16,materialized=4' "late Set ordinary/materialized expected split"
Assert-Contains $lateSetExpected 'set ordinaryMissingTypeIds=0,ordinaryFlatSetReceivers=16' "late Set ordinary receiver type contract"
Assert-Contains $projectedSocketCloseFixture 'impl TcpListener {' "projected socket close overload fixture listener owner"
Assert-Contains $projectedSocketCloseFixture 'impl TcpStream {' "projected socket close overload fixture stream owner"
Assert-Contains $projectedSocketCloseFixture 'impl UdpSocket {' "projected socket close overload fixture datagram owner"
Assert-Contains $projectedSocketCloseExpected 'projected-socket-close=-270,1' "projected socket close canonical opcode"
Assert-Contains $referenceStructReceiverFixture 'counter: ref Counter' "readonly struct-reference receiver fixture"
Assert-Contains $referenceStructReceiverFixture 'remaining! > 0 -> while {' "readonly struct-reference control-region fixture"
Assert-Contains $referenceStructReceiverFixture 'counter -> readInsideLoop' "readonly struct-reference forwarding fixture"
Assert-Contains $referenceStructReceiverExpected 'ref-struct-loop=42' "readonly struct-reference receiver result"
Assert-Contains $referenceStructForwardingFixture 'encodePoint(point) => encoded' "direct readonly struct-reference forwarding fixture"
Assert-Contains $referenceStructForwardingExpected 'ref-struct-direct=42' "direct readonly struct-reference forwarding result"
Assert-Contains $coreCalls 'referenceParameterValueIsMaterialized' "canonical materialized reference-parameter predicate"
Assert-Contains $containers 'assignmentReferenceValueIsMaterialized!' "array assignment avoids a second reference-parameter load"
Assert-Contains $referenceStructAssignmentFixture 'replacement => records[index]' "readonly struct-reference array assignment fixture"
Assert-Contains $referenceStructAssignmentExpected 'ref-struct-array=42' "readonly struct-reference array assignment result"
Assert-Contains $stage2Verifier '--exact 1177-ref-struct-array-element-assignment' "Stage2 readonly struct-reference array assignment fixture"
Assert-Contains $stage3Verifier '--exact 1177-ref-struct-array-element-assignment' "Stage3 readonly struct-reference array assignment fixture"
Assert-Contains $calls 'receiverLiteralFollowing.kind == grammar.tokenIdArrow()' "literal-led flow call detection"
Assert-Contains $calls 'not receiverLiteralFeedsCall!' "resolved call-result receiver precedes terminal literal fallback"
Assert-Contains $calls 'package -> declaredIntrinsicMethodNames => declaredIntrinsicNames' "contextual intrinsic collision names are indexed once per package"
Assert-Contains $calls 'struct TypedCallCandidate {' "contextual intrinsic fallback state stays private to typed call resolution"
Assert-Contains $calls 'intrinsicFallback: intrinsicFallback and declaredCollision' "contextual intrinsic calls retain a typed-receiver fallback marker"
Assert-Contains $calls 'local.intrinsicFallback and not siblingFound!' "unrelated same-name methods return to intrinsic resolution"
Assert-Contains $calls 'result.status != 6' "temporary intrinsic fallback resolutions do not escape semantic call analysis"
Assert-Contains $typedCore 'knownCallExpression! -> if { -1 => flowEmissionOpcode! }' "resolved receiver method suppresses duplicate intrinsic lowering in functions"
Assert-Contains $typedCore 'knownEntryCallExpression! -> if { -1 => entryFlowEmissionOpcode! }' "resolved receiver method suppresses duplicate intrinsic lowering in entry points"
Assert-Contains $callResultReceiverFixture 'model.Builder { seed: 0 } -> create? => ready' "fallible call-result receiver fixture"
Assert-Contains $callResultReceiverExpected 'call-result-receiver=42' "fallible call-result receiver result"
Assert-Contains $stage2Verifier '--exact 1178-call-result-receiver-before-literal-fallback' "Stage2 call-result receiver fixture"
Assert-Contains $stage3Verifier '--exact 1178-call-result-receiver-before-literal-fallback' "Stage3 call-result receiver fixture"
Assert-Contains $managedControlEmitter 'RuntimeDynamicInlineArray array => EmitDynamicInlineArrayPhi(prefix, array, incoming)' "managed growable inline-array control join"
Assert-Contains $managedControlEmitter 'array.ArrayType != first.ArrayType' "managed growable inline-array type agreement"
Assert-Contains $managedControlEmitter 'array.ElementType != first.ElementType' "managed growable inline-array element agreement"
Assert-Contains $managedControlEmitter 'array.Storage != first.Storage' "managed growable inline-array storage agreement"
Assert-Contains $managedControlEmitter 'return first with { PointerName = pointer, LengthName = length, CapacityName = capacity };' "managed growable inline-array phi carrier"
Assert-Contains $controlStructArrayResultFixture 'enabled -> if {' "growable struct-array value-producing if fixture"
Assert-Contains $controlStructArrayResultFixture 'entries[0].value + 2 -> println' "growable struct-array merged owner use"
if ($controlStructArrayResultExpected.Trim() -cne '42') {
    throw "growable struct-array control-result expected output must be exactly 42"
}
Assert-Contains $stage2Verifier '--exact 1197-control-struct-array-result' "Stage2 growable struct-array control-result fixture"
Assert-Contains $stage3Verifier '--exact 1197-control-struct-array-result' "Stage3 growable struct-array control-result fixture"
Assert-Contains $parallelTransferableStructFixture 'struct Request {' "parallel worker-transfer request record fixture"
Assert-Contains $parallelTransferableStructFixture 'struct Batch {' "parallel worker-transfer result record fixture"
Assert-Contains $parallelTransferableStructFixture 'requests -> parallel request {' "parallel worker-transfer nominal input fixture"
if ($parallelTransferableStructExpected.Trim() -cne 'batches=2') {
    throw "parallel worker-transfer expected output must be exactly batches=2"
}
Assert-Contains $localParallelCallbackFixture 'map current: [Int; ~] -> [Int; ~] {' "reachable local parallel owner fixture"
Assert-Contains $localParallelCallbackFixture 'current -> parallel value {' "local parallel callback fixture"
if ($localParallelCallbackExpected.Trim() -cne 'mapped=3') {
    throw "local parallel callback expected output must be exactly mapped=3"
}
Assert-Contains $parallelNominalReadonlyCapturesFixture 'lowerAll requests: [Request; ~], config: ref LoweringConfig, scale: Int' "parallel nominal readonly-capture signature"
Assert-Contains $parallelNominalReadonlyCapturesFixture 'requests -> parallel request {' "parallel nominal readonly-capture worker"
Assert-Contains $parallelNominalReadonlyCapturesFixture 'request -> lower' "parallel local capture target"
if ($parallelNominalReadonlyCapturesExpected.Trim() -cne 'batches=2') {
    throw "parallel nominal readonly-capture expected output must be exactly batches=2"
}
Assert-Contains $parallelMoveParameterFixture 'mapOwned values: move [Int; ~], useParallel: Bool' "parallel move-parameter signature"
Assert-Contains $parallelMoveParameterFixture 'values -> parallel value {' "control-region parallel move-parameter source"
if ($parallelMoveParameterExpected.Trim() -cne 'mapped=3') {
    throw "parallel move-parameter expected output must be exactly mapped=3"
}
Assert-Contains $arrayElementOwnerReplacementFixture 'appendValues output: mut [Int; ~], chunk: ref Chunk' "readonly owned array-element helper"
Assert-Contains $arrayElementOwnerReplacementFixture 'output -> appendValues(chunks[index])' "readonly owned array-element call before replacement"
Assert-Contains $arrayElementOwnerReplacementFixture 'Chunk { values: [Int; ~] } => chunks[index]' "O(1) whole array-element owner replacement"
Assert-NotContains $arrayElementOwnerReplacementFixture '-> take(' "no shifting array-element owner extraction"
if ($arrayElementOwnerReplacementExpected.Trim() -cne 'sum=10 remaining=0,0') {
    throw "array-element owner replacement expected output must be exactly sum=10 remaining=0,0"
}
Assert-Contains $enumPayloadBinaryBindingFixture 'DataBlocked(limit) { Result<Bool, errors.Error>.Ok(limit == 70_000) }' "enum payload binary binding baseline"
Assert-Contains $enumPayloadBinaryBindingPermutedFixture 'struct Unrelated {' "enum payload binding table-shape permutation"
Assert-Contains $enumPayloadBinaryBindingPermutedFixture 'DataBlocked(limit) { Result<Bool, errors.Error>.Ok(limit == 70_000 and not ignored) }' "enum payload binding permuted condition"
Assert-Contains $typedCore 'whenConditionPatternResolution.astNode == whenConditionNameAst!' "function when-arm exact resolved pattern identity"
Assert-Contains $typedCore 'whenConditionPatternCandidate.kind == 29' "function when-arm exact pattern IR binding"
Assert-Contains $typedCore 'whenConditionPatternCandidate.symbol == whenConditionPatternSymbolIndex!' "function when-arm exact pattern symbol binding"
Assert-Contains $typedCore 'whenConditionPatternCandidate.astNode == prepared.package.symbols[sourceRange.symbolStart + whenConditionPatternSymbolIndex!].astNode' "function when-arm exact pattern AST binding"
Assert-Contains $typedCore 'entryWhenConditionPatternResolution.astNode == entryWhenConditionNameAst!' "entry when-arm exact resolved pattern identity"
Assert-Contains $typedCore 'entryWhenConditionPatternCandidate.kind == 29' "entry when-arm exact pattern IR binding"
Assert-Contains $typedCore 'entryWhenConditionPatternCandidate.symbol == entryWhenConditionPatternSymbolIndex!' "entry when-arm exact pattern symbol binding"
Assert-Contains $typedCore 'entryWhenConditionPatternCandidate.astNode == prepared.package.symbols[sourceRange.symbolStart + entryWhenConditionPatternSymbolIndex!].astNode' "entry when-arm exact pattern AST binding"
Assert-Contains $typedCore 'whenBinaryRepairResolution.astNode == whenBinaryRepairNameAst!' "cross-region when-arm exact resolved pattern identity"
Assert-Contains $typedCore 'prepared.package.symbols[whenBinaryRepairRange.symbolStart + whenBinaryRepairPatternSymbol.parent].astNode == whenBinaryRepairArmAst!' "cross-region when-arm exact owner arm identity"
Assert-Contains $typedCore 'whenBinaryRepairCandidate.symbol == whenBinaryRepairPatternSymbolIndex!' "cross-region when-arm exact pattern symbol identity"
Assert-Contains $typedCore 'whenBinaryRepairCandidate.astNode == prepared.package.symbols[whenBinaryRepairRange.symbolStart + whenBinaryRepairPatternSymbolIndex!].astNode' "cross-region when-arm exact pattern AST identity"
Assert-Contains $typedCore 'whenBinaryRepairCandidateRoot! == whenBinaryRepairRoot!' "cross-region when-arm exact owner root identity"
Assert-NotContains $typedFunctionLowering 'baseChanged!' "final nominal member seal avoids the former per-member changed-index rescan"
Assert-Contains $typedFunctionLowering 'public terminalValueReturnsFromArm terminalIndex: Int, armIndex: Int' "shared match terminal return-ancestor classifier"
Assert-Matches $typedFunctionLowering '(?s)terminalValueReturnsFromArm.*?nodes\[ancestor!\]\.kind == 23.*?nodes\[ancestor!\]\.parent => ancestor!.*?terminal\.kind != 23.*?terminalIndex -> terminalValueReturnsFromArm\(armIndex!, nodes\)' "match result sealing rejects values consumed by an enclosing explicit return"
Assert-Contains $invariants 'terminalIndex -> typedIr.terminalValueReturnsFromArm(armIndex!, context.ir)' "V011 shares returned-terminal classification with late match result sealing"
Assert-Matches $typedFunctionLowering '(?s)field\.status == 0 and field\.ownerType == ownerType! and fieldMatches!.*?field\.ordinal => member!\.symbol.*?field\.fieldType => member!\.typeId' "final nominal member seal restores field ordinal and type together"
Assert-Contains $typedFunctionLowering 'results[receiverPathNext!].operand0 == canonicalReceiverIndex!' "projected flow receiver follows exact contiguous member identity"
Assert-Contains $typedFunctionLowering '(returnedEnumMatch!.kind == 27 or returnedEnumMatch!.kind == 34)' "returned enum and numeric-subject matches share the canonical arm-result repair"
Assert-Matches $typedFunctionLowering '(?s)results\[returnedEnumMatch!\.parent\]\.kind == 1.*?returnedEnumMatchRepairIndex! => returnedEnumReturn!\.operand0.*?returnedEnumReturn! => results\[returnedEnumMatch!\.parent\]' "returned expression-body match replaces the function provisional result through exact parent identity"
Assert-NotContains $typedFunctionLowering 'returnedEnumReturn.' "mutable returned function node cannot be read as a nonexistent immutable binding"
$lateNominalMemberTypesStart = $typedFunctionLowering.IndexOf(
    'sealLateNominalMemberTypes results:',
    [System.StringComparison]::Ordinal)
$sealLateTypesStart = $typedFunctionLowering.IndexOf(
    'sealLateTypes results:',
    [System.StringComparison]::Ordinal)
if ($lateNominalMemberTypesStart -lt 0 -or $sealLateTypesStart -le $lateNominalMemberTypesStart) {
    throw 'late nominal member type sealing contract cannot isolate its declaration'
}
$lateNominalMemberTypes = $typedFunctionLowering.Substring(
    $lateNominalMemberTypesStart,
    $sealLateTypesStart - $lateNominalMemberTypesStart)
Assert-NotContains $lateNominalMemberTypes 'changedTypeIndices!' "mutable parameters use their declared parameter identity without a local bang suffix"
Assert-Matches $typedFunctionLowering '(?s)canonicalReceiverIndex! != call!\.operand0.*?canonicalReceiverIndex! => call!\.operand0.*?results\[canonicalReceiverIndex!\]\.nextOperand => call!\.operand1' "projected flow receiver replaces its base without reordering explicit arguments"
Assert-Contains $invariants 'and count! <= maximum' "resolved call invariant observes one excess linked argument"
Assert-Contains $invariants 'and (not targetHasBlockRole! or count! < maximum)' "resolved call invariant excludes the block callback tail from runtime ABI slots"
Assert-Contains $invariants 'and context.symbols[targetGlobalSymbol].blockTypeNode >= 0' "block callback-tail exclusion uses the declared target role contract"
Assert-Contains $invariants 'implicitFlowArgumentCount context: ref emitterContext.EmitContext, callIndex: Int, linkedCount: Int, expectedCount: Int -> Int' "implicit parallel role count receives the concrete call-plan counts"
Assert-NotContains $invariants 'and context.ir[callIndex].operand0 < 0' "implicit role suppression based only on the first linked capture"
Assert-MatchCount $invariants 'invariantRules\.implicitFlowArgumentCount\(' 2 "parallel and stream callback ancestry share the pure implicit-role rule"
Assert-Contains $invariantRules 'flowOwner and not childIsSource and linkedCount < expectedCount' "implicit role fills one missing slot without suppressing captures or duplicating the linked role"
Assert-Contains $coreCalls 'depth! == 0 -> if { 1 => depth! }' "member reference projection retains one structural depth when AST is token-narrowed"
Assert-Matches $typedCore '(?s)# Pattern identity must win before the broader continuation repair below\..*?whenBinaryRepairPatternIr! >= 0.*?# Nested two-argument calls can leave their first argument in the sibling' "exact pattern repair precedes broad continuation repair"
Assert-NotContains $typedCore 'whenConditionNameToken.span.length == whenResolvedNameToken.span.length' "no function when-arm spelling fallback"
Assert-NotContains $typedCore 'entryWhenConditionNameToken.span.length == entryWhenResolvedNameToken.span.length' "no entry when-arm spelling fallback"
Assert-NotContains $typedCore 'whenBinaryRepairName.span.length == whenBinaryRepairCandidateName.span.length' "no cross-region when-arm spelling fallback"
Assert-NotContains $typedCore 'whenBinaryRepairCandidateName.span.start' "no cross-region when-arm source-byte comparison"
Assert-MatchCount $control 'regionParallelSource\.kind == 5 and ownerIndex >= 0' 2 "control-region parallel function-parameter input and length resolution"
$stage1SeedFixtureBlock = [regex]::Match(
    $stage2Verifier,
    '(?s)\$stage1SeedExactFixtures\s*=\s*@\((.*?)\)\s*# Every exact build')
if (-not $stage1SeedFixtureBlock.Success) {
    throw "Stage2 seed capability preflight must declare one authoritative fixture array"
}
foreach ($requiredStage1SeedFixture in @(
    '787-selfhost-file-write-match-subject-ir',
    '1196-selfhost-cross-fragment-ref-dynamic-array',
    '1208-multiline-projected-assignment',
    '1217-selfhost-late-indexed-array-type-contract',
    '1291-quic-unidirectional-stream-registry',
    '1292-selfhost-unary-not-enum-match-value',
    '1293-selfhost-call-result-member-enum-subject'
    '1357-selfhost-projected-enum-subject-call-plan'
    '1358-selfhost-take-control-wrapper-owner'
    '1359-selfhost-private-empty-slice-helper-reachability'
    '1361-selfhost-nested-all-return-control'
    '1362-selfhost-qualified-flow-after-builtin-conversion'
    '1294-selfhost-statement-match-complete-arm-result'
    '1295-selfhost-late-match-if-result'
    '1296-selfhost-projected-receiver-instance-precedence'
    '1308-selfhost-nested-result-many-argument-owner'
    '1309-selfhost-terminating-if-branch-result'
    '1320-parallel-role-two-reference-captures'
    '1321-parallel-additional-borrow-result'
    '1380-selfhost-final-binding-return-selection'
    '1381-selfhost-terminal-return-only-if'
    '1382-selfhost-terminal-flow-control-return'
    '1383-selfhost-inferred-receiver-method-owner'
    '1384-nested-result-logical-condition'
)) {
    if (-not [regex]::IsMatch(
            $stage1SeedFixtureBlock.Groups[1].Value,
            '(?m)^\s*"' + [regex]::Escape($requiredStage1SeedFixture) + '"\s*$')) {
        throw "Stage2 seed capability preflight is missing required fixture: $requiredStage1SeedFixture"
    }
}
Assert-NotContains $stage1SeedFixtureBlock.Groups[1].Value '1393-selfhost-opaque-struct-diagnostics' "Stage2 seed avoids recompiling the 97-source diagnostic meta-fixture"
Assert-MatchCount $stage2Verifier '1393-selfhost-opaque-struct-diagnostics' 1 "Stage2 keeps 1393 only as its managed integrated regression"
Assert-MatchCount $stage3Verifier '1393-selfhost-opaque-struct-diagnostics' 1 "Stage3 keeps 1393 only as its managed integrated regression"
Assert-MatchCount $stage2Verifier 'verify-selfhost-private-field-diagnostics\.ps1' 2 "Stage2 checks private fields through both seed and candidate compilers"
Assert-MatchCount $stage3Verifier 'verify-selfhost-private-field-diagnostics\.ps1' 1 "Stage3 checks private fields for both fixed-point generations"
Assert-MatchCount $linuxStage2 'verify-selfhost-private-field-diagnostics\.ps1' 2 "Linux Stage2 checks private fields through both seed and candidate compilers"
Assert-MatchCount $linuxStage3 'verify-selfhost-private-field-diagnostics\.ps1' 1 "Linux Stage3 checks private fields for both fixed-point generations"
foreach ($privateFieldCase in @(
    'opaque-struct-construction'
    'opaque-struct-field-read'
    'opaque-struct-field-write'
)) {
    Assert-Contains $privateFieldDiagnosticVerifier $privateFieldCase "Direct private-field diagnostic gate case"
}
Assert-Contains $privateFieldDiagnosticVerifier '$result.ExitCode -ne 1' "Direct private-field diagnostics require the compiler diagnostic exit"
Assert-Contains $privateFieldDiagnosticVerifier "(?m)^target (datalayout|triple)" "Direct private-field diagnostics reject LLVM emission"
Assert-Contains $stage2Verifier '-Fixture $stage1SeedHeavyFixtures' "Stage2 seed exact batch consumes the measured heavy partition"
Assert-Contains $stage2Verifier '-Fixture $stage1SeedLightFixtures' "Stage2 seed exact batch consumes the cache-compatible light partition"
Assert-Contains $stage2Verifier '--exact 1198-parallel-transferable-struct-worker' "Stage2 nominal worker-transfer fixture"
Assert-Contains $stage3Verifier '--exact 1198-parallel-transferable-struct-worker' "Stage3 nominal worker-transfer fixture"
Assert-Contains $stage2Verifier '--exact 1199-local-function-parallel-callback' "Stage2 local parallel callback fixture"
Assert-Contains $stage3Verifier '--exact 1199-local-function-parallel-callback' "Stage3 local parallel callback fixture"
Assert-Contains $stage2Verifier '--exact 1200-parallel-nominal-readonly-captures' "Stage2 nominal readonly-capture fixture"
Assert-Contains $stage2Verifier '--exact 1321-parallel-additional-borrow-result' "Stage2 parallel bound-reference fixture"
Assert-Contains $stage3Verifier '--exact 1321-parallel-additional-borrow-result' "Stage3 parallel bound-reference fixture"
Assert-Contains $stage3Verifier '--exact 1200-parallel-nominal-readonly-captures' "Stage3 nominal readonly-capture fixture"
Assert-Contains $stage2Verifier '--exact 1201-parallel-move-parameter' "Stage2 control-region parallel move-parameter fixture"
Assert-Contains $stage3Verifier '--exact 1201-parallel-move-parameter' "Stage3 control-region parallel move-parameter fixture"
Assert-Contains $stage2Verifier '--exact 787-selfhost-file-write-match-subject-ir' "Stage2 final file Result producer ownership fixture"
Assert-Contains $stage3Verifier '--exact 787-selfhost-file-write-match-subject-ir' "Stage3 final file Result producer ownership fixture"
Assert-Contains $stage2Verifier '--exact 1202-array-element-owner-replacement-after-read' "Stage2 prompt owner-release fixture"
Assert-Contains $stage3Verifier '--exact 1202-array-element-owner-replacement-after-read' "Stage3 prompt owner-release fixture"
Assert-Contains $stage2Verifier '--exact 1203-selfhost-enum-payload-binary-binding' "Stage2 enum payload binary binding fixture"
Assert-Contains $stage3Verifier '--exact 1203-selfhost-enum-payload-binary-binding' "Stage3 enum payload binary binding fixture"
Assert-Contains $stage2Verifier '--exact 1204-selfhost-enum-payload-binary-binding-permuted' "Stage2 enum payload binding permutation fixture"
Assert-Contains $stage3Verifier '--exact 1204-selfhost-enum-payload-binary-binding-permuted' "Stage3 enum payload binding permutation fixture"
Assert-Contains $stage2Verifier '--exact 1221-numeric-subject-when-arm-result' "Stage2 numeric subject-when arm-result fixture"
Assert-Contains $stage3Verifier '--exact 1221-numeric-subject-when-arm-result' "Stage3 numeric subject-when arm-result fixture"
Assert-Contains $stage2Verifier '--exact 1222-selfhost-numeric-subject-when-binding' "Stage2 self-host numeric subject-when binding fixture"
Assert-Contains $stage3Verifier '--exact 1222-selfhost-numeric-subject-when-binding' "Stage3 self-host numeric subject-when binding fixture"
Assert-Contains $stage2Verifier '--exact 1223-contextual-intrinsic-instance-precedence' "Stage2 contextual intrinsic instance precedence fixture"
Assert-Contains $stage3Verifier '--exact 1223-contextual-intrinsic-instance-precedence' "Stage3 contextual intrinsic instance precedence fixture"
Assert-Contains $stage2Verifier '--exact 1233-http-response-head-writer' "Stage2 HTTP response head fixture"
Assert-Contains $stage3Verifier '--exact 1233-http-response-head-writer' "Stage3 HTTP response head fixture"
Assert-Contains $stage2Verifier '--exact 1385-http-request-head-writer' "Stage2 HTTP request head fixture"
Assert-Contains $stage3Verifier '--exact 1385-http-request-head-writer' "Stage3 HTTP request head fixture"
$ordinaryFinalize = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost\ir\typed\ordinary_function_finalize.slg")) + "`n" + [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost\ir\typed\ordinary_function_finalize_phases.slg"))
$entryFinalize = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost\ir\typed\source_lowering_finalize.slg"))
Assert-Contains $ordinaryFinalize 'nominalCallWrapper!.kind == 6' "ordinary qualified nominal enum payload call wrapper recognition"
Assert-Contains $ordinaryFinalize '-1 => nominalCallWrapper!.targetModule' "ordinary qualified nominal enum payload call wrapper target clearing"
Assert-Contains $ordinaryFinalize 'expressionIrStart => bindingControlResultIndex!' "ordinary expression binding normalization boundary"
Assert-Matches $ordinaryFinalize '(?s)bindingFlowControlCandidate\.kind == 27 or bindingFlowControlCandidate\.kind == 34.*?bindingFlowControlCandidate\.parent == bindingControlResultIndex!' "ordinary binding directly owns control initializer"
Assert-Matches $typedResolvedContextSeal '(?s)finalProducerControl\.parent == finalProducerWrapperIndex!.*?finalProducerWrapper!\.operand1.*?finalProducerSubjectWrapper!\.operand0' "final control producer wrapper canonicalization"
Assert-Contains $entryFinalize 'entryNominalCallWrapper!.kind == 6' "entry qualified nominal enum payload call wrapper recognition"
Assert-Contains $entryFinalize '-1 => entryNominalCallWrapper!.targetModule' "entry qualified nominal enum payload call wrapper target clearing"
Assert-Contains $stage2Verifier '--exact 1234-selfhost-parallel-nested-flow-arguments' "Stage2 parallel role flow fixture"
Assert-Contains $stage3Verifier '--exact 1234-selfhost-parallel-nested-flow-arguments' "Stage3 parallel role flow fixture"
Assert-Contains $stage2Verifier '--exact 1236-socket-send-range-all' "Stage2 socket range write fixture"
Assert-Contains $stage3Verifier '--exact 1236-socket-send-range-all' "Stage3 socket range write fixture"
Assert-Contains $managedUtilitiesEmitter 'expression is TryExpression attempt' "managed try-wrapped owner transfer traversal"
Assert-Contains $managedUtilitiesEmitter 'CallTransfersOwnerName(call, callFunction, ownerName)' "managed declared call owner transfer mapping"
Assert-Contains $managedUtilitiesEmitter 'parameters[index].Ownership == BoundFunctionInputOwnership.Move' "managed additional move-parameter transfer mapping"
Assert-Contains $managedEnumEmitter 'RemoveOwnedLiteralSources(expression.Arguments[0], payloadType);' "managed enum payload recursive owner transfer"
Assert-NotContains $managedEnumEmitter 'expression.Arguments[0] is NameExpression sourceName' "managed enum payload direct-name-only transfer"
Assert-Matches $managedEnumEmitter '(?s)if \(armTransfers\[arm\]\)\s*\{\s*DropOwnedStructFieldsExcept\(.*?\}\s*else\s*\{\s*DropOwnedProjectedSubjectIfRetained' "managed projected enum payload known-transfer cleanup"
Assert-Matches $managedEnumEmitter '(?s)anonymousSubject \|\| removedNamedSubject.*?payloadTransferFlag is not null\)\s*\{\s*if \(!armTransfers\[arm\]\)\s*\{\s*DropOwnedRuntimeValueIfRetained' "managed enum payload known transfer omits unreachable root drop"
Assert-NotContains $managedEnumEmitter 'var outerOwnerTransfers = _locals' "managed enum arms do not balance ownership by dropping live outer owners"
Assert-Contains $managedEnumEmitter 'var continuingPaths = new List<EnumContinuingPath>();' "managed enum ownership normalization records only continuing predecessors"
Assert-Contains $managedEnumEmitter 'NormalizeEnumOuterOwnerScopes(outerOwnedLocals, continuingPaths);' "managed enum outer-owner cleanup uses continuing-path normalization"
Assert-Matches $managedEnumEmitter '(?s)presentPaths.Length == 0 \|\| presentPaths.Length == continuingPaths.Count.*?DropOwnedRuntimeValue\(path.Scope.Locals\[name\]\).*?RemoveLocalsFromScope\(path.Scope, normalizedNames\)' "managed enum inconsistent continuing owners drop only retained-path values before scope merge"
Assert-Contains $managedEnumEmitter 'var transfersAnyPayload = armTransfers.Values.Any(static transfers => transfers);' "managed enum subject removal requires an actual payload transfer"
Assert-Contains $managedStructEmitter 'TryGetOwnedFieldProjection(expression, out var ownerName, out var fieldPath)' "managed nested owned projection transfer path"
Assert-Contains $mutableOwnedProjectionEnumFixture 'Stored.Value(envelope!.payload) => stored' "mutable nested projection enum ownership fixture"
Assert-Contains $mutableOwnedProjectionEnumFixture '"mutable-projection=$((payload.bytes -> len) == 3)"' "mutable nested projection enum execution proof"
Assert-Contains $typedCore 'flowIntrinsicOpcode source: Text, tokens: ref [syntax.SyntaxToken; ~]' "self-host flow intrinsic token borrow"
Assert-NotContains $typedCore 'struct FlowIntrinsicRequest' "obsolete owned flow intrinsic request"
Assert-Contains $managedSemanticCompiler 'flowAggregateSourceNames' "managed flow aggregate ownership accounting"
Assert-Matches $managedSemanticCompiler '(?s)private void BindFieldAssignment\(.*?InferContextualValue\(\s*assignment\.Value,\s*field\.Type,' "managed field assignment declared-type contextual binding"
Assert-Contains $managedStatementsEmitter 'var value = EmitFunctionArgumentExpression(assignment.Value, field.Type);' "managed field assignment declared-type contextual lowering"
Assert-Contains $flowAggregateOwnedProjectionDiagnostic "declare read-only request fields or helper parameters as 'ref T'" "flow aggregate ownership diagnostic guidance"
Assert-Contains $grammar 'rule BindingStatement = Expression NewLine* FatArrow MutableName StatementEnd' "multiline binding assignment grammar"
Assert-Contains $grammar 'rule IndexAssignmentStatement = Expression NewLine* FatArrow MutableName LeftBracket Expression RightBracket StatementEnd' "multiline indexed assignment grammar"
Assert-Contains $grammar 'rule FieldAssignmentStatement = Expression NewLine* FatArrow MutableName Dot Identifier StatementEnd' "multiline field assignment grammar"
Assert-Contains $stage2Verifier '--exact 1206-quic-bidirectional-multi-stream-routing' "Stage2 QUIC multi-stream integration fixture"
Assert-Contains $stage3Verifier '--exact 1206-quic-bidirectional-multi-stream-routing' "Stage3 QUIC multi-stream integration fixture"
Assert-Contains $stage2Verifier '--exact 1207-enum-owned-payload-projected-queue' "Stage2 try-wrapped enum payload transfer fixture"
Assert-Contains $stage3Verifier '--exact 1207-enum-owned-payload-projected-queue' "Stage3 try-wrapped enum payload transfer fixture"
Assert-Contains $stage2Verifier '--exact 1208-multiline-projected-assignment' "Stage2 multiline projected assignment grammar fixture"
Assert-Contains $stage3Verifier '--exact 1208-multiline-projected-assignment' "Stage3 multiline projected assignment grammar fixture"
Assert-Contains $stage2Verifier '--exact 1209-quic-connection-options-queue-limits' "Stage2 QUIC options and atomic queue limit fixture"
Assert-Contains $stage3Verifier '--exact 1209-quic-connection-options-queue-limits' "Stage3 QUIC options and atomic queue limit fixture"
Assert-Contains $stage2Verifier '"1208-multiline-projected-assignment"' "Stage2 selected-seed multiline projected assignment preflight"
Assert-Contains $stage2Verifier '"1380-selfhost-final-binding-return-selection"' "Stage2 selected-seed materialized final-return preflight"
Assert-Contains $stage2Verifier '"1381-selfhost-terminal-return-only-if"' "Stage2 selected-seed terminal-only if preflight"
Assert-Contains $stage2Verifier '"1382-selfhost-terminal-flow-control-return"' "Stage2 selected-seed terminal flow-control preflight"
Assert-Contains $stage2Verifier '"1384-nested-result-logical-condition"' "Stage2 selected-seed nested Result logical-condition preflight"
Assert-Contains $stage2Verifier '"1394-selfhost-when-binding-reassignment"' "Stage2 selected-seed when-binding reassignment preflight"
Assert-Contains $stage3Verifier '--exact 1394-selfhost-when-binding-reassignment' "Stage3 when-binding reassignment fixture"
foreach ($nativeExactGate in @(
    [ordered]@{ Name = "authoritative"; Text = $nativeExactFixtureBatchVerifier }
)) {
    Assert-Contains $nativeExactGate.Text '"1203-selfhost-enum-payload-binary-binding"' "$($nativeExactGate.Name) native exact enum payload binding fixture"
    Assert-Contains $nativeExactGate.Text '"1204-selfhost-enum-payload-binary-binding-permuted"' "$($nativeExactGate.Name) native exact enum payload permutation fixture"
    Assert-Contains $nativeExactGate.Text '"1206-quic-bidirectional-multi-stream-routing"' "$($nativeExactGate.Name) native exact QUIC multi-stream fixture"
    Assert-Contains $nativeExactGate.Text '"1207-enum-owned-payload-projected-queue"' "$($nativeExactGate.Name) native exact try-wrapped enum transfer fixture"
    Assert-Contains $nativeExactGate.Text '"1208-multiline-projected-assignment"' "$($nativeExactGate.Name) native exact multiline projected assignment fixture"
    Assert-Contains $nativeExactGate.Text '"1209-quic-connection-options-queue-limits"' "$($nativeExactGate.Name) native exact QUIC options and atomic queue limit fixture"
    Assert-Contains $nativeExactGate.Text '"1220-zstd-raw-rle-streaming"' "$($nativeExactGate.Name) native exact Zstandard foundation fixture"
    Assert-Contains $nativeExactGate.Text '"1304-zstd-literal-only-compressed-block"' "$($nativeExactGate.Name) native exact Zstandard compressed literal fixture"
    Assert-Contains $nativeExactGate.Text '"1305-selfhost-interpolation-numeric-separator"' "$($nativeExactGate.Name) native exact interpolation numeric separator fixture"
    Assert-Contains $nativeExactGate.Text '"1306-zstd-direct-huffman-literals"' "$($nativeExactGate.Name) native exact Zstandard direct Huffman fixture"
    Assert-Contains $nativeExactGate.Text '"1379-selfhost-nested-control-implicit-return"' "$($nativeExactGate.Name) native exact nested-control implicit-return fixture"
    Assert-Contains $nativeExactGate.Text '"1380-selfhost-final-binding-return-selection"' "$($nativeExactGate.Name) native exact materialized final-return fixture"
    Assert-Contains $nativeExactGate.Text '"1381-selfhost-terminal-return-only-if"' "$($nativeExactGate.Name) native exact terminal-only if fixture"
    Assert-Contains $nativeExactGate.Text '"1382-selfhost-terminal-flow-control-return"' "$($nativeExactGate.Name) native exact terminal flow-control fixture"
    Assert-Contains $nativeExactGate.Text '"1383-selfhost-inferred-receiver-method-owner"' "$($nativeExactGate.Name) native exact inferred receiver method owner fixture"
    Assert-Contains $nativeExactGate.Text '"1384-nested-result-logical-condition"' "$($nativeExactGate.Name) native exact nested Result logical-condition fixture"
    Assert-Contains $nativeExactGate.Text '"1308-selfhost-nested-result-many-argument-owner"' "$($nativeExactGate.Name) native exact enum-payload projected reference root fixture"
    Assert-Contains $nativeExactGate.Text '"1309-selfhost-terminating-if-branch-result"' "$($nativeExactGate.Name) native exact single-continuing-branch if result fixture"
    Assert-Contains $nativeExactGate.Text '"1228-xxhash64-streaming"' "$($nativeExactGate.Name) native exact unsigned XXH64 fixture"
    Assert-Contains $nativeExactGate.Text '"1229-http-body-framing"' "$($nativeExactGate.Name) native exact HTTP body framing fixture"
    Assert-Contains $nativeExactGate.Text '"1230-selfhost-short-circuit-array-argument"' "$($nativeExactGate.Name) native exact short-circuit array argument fixture"
    Assert-Contains $nativeExactGate.Text '"1231-selfhost-nested-result-match-value"' "$($nativeExactGate.Name) native exact nested result-match value fixture"
    Assert-Contains $nativeExactGate.Text '"1232-selfhost-console-call-owns-if-result"' "$($nativeExactGate.Name) native exact if-result console ownership fixture"
    Assert-Contains $nativeExactGate.Text '"1233-http-response-head-writer"' "$($nativeExactGate.Name) native exact HTTP response head fixture"
    Assert-Contains $nativeExactGate.Text '"1385-http-request-head-writer"' "$($nativeExactGate.Name) native exact HTTP request head fixture"
    Assert-Contains $nativeExactGate.Text '"1234-selfhost-parallel-nested-flow-arguments"' "$($nativeExactGate.Name) native exact parallel role flow fixture"
    Assert-Contains $nativeExactGate.Text '"1236-socket-send-range-all"' "$($nativeExactGate.Name) native exact socket range write fixture"
    Assert-Contains $nativeExactGate.Text '"1221-numeric-subject-when-arm-result"' "$($nativeExactGate.Name) native exact numeric subject-when result fixture"
    Assert-Contains $nativeExactGate.Text '"1222-selfhost-numeric-subject-when-binding"' "$($nativeExactGate.Name) native exact self-host numeric subject binding fixture"
    Assert-Contains $nativeExactGate.Text '"1223-contextual-intrinsic-instance-precedence"' "$($nativeExactGate.Name) native exact contextual intrinsic instance precedence fixture"
    Assert-Contains $nativeExactGate.Text '"945-quic-flow-control-frames"' "$($nativeExactGate.Name) native exact QUIC stream-count boundary fixture"
}
Assert-Contains $nativeExactFixtureBatchVerifier '"1279-brotli-decoder-compressed-stream"' "native exact public Brotli compressed-stream fixture"
Assert-Contains $nativeExactFixtureBatchVerifier '"1280-mutable-owned-projection-enum-transfer"' "native exact mutable owned projection enum fixture"
Assert-Contains $stage2Verifier 'verify-selfhost-owned-container-rebind-diagnostic.ps1' "Stage2 E28 owned container rebind gate"
Assert-Contains $stage3Verifier 'verify-selfhost-owned-container-rebind-diagnostic.ps1' "Stage3 E28 owned container rebind gate"
Assert-Contains $semanticOwnership 'code: 28' "self-host owned container rebind diagnostic"
Assert-Contains $semanticOwnership '(previousCandidateIr -> lexicalExecutableAst) == (mutableBindingIrIndex! -> lexicalExecutableAst)' "self-host E28 uses canonical lexical function scope"
Assert-Contains $semanticOwnership 'typed[previousCandidateIr].astNode != mutableBinding.astNode' "self-host E28 compares distinct source declarations rather than duplicate Typed IR nodes"
Assert-Contains $semanticOwnership 'previousCandidateIr -> useReachableAfterMove(mutableBindingIrIndex!)' "self-host E28 excludes mutually exclusive and terminating predecessor bindings"
Assert-Contains $emitterDiagnostics 'error[E28]: owned container binding' "self-host actionable owned container rebind diagnostic"
foreach ($processStdioFixture in @(
    '1179-process-stdio-file-instance',
    '1180-process-stdio-null-instance',
    '1181-process-status-to-file-configuration',
    '1182-process-bounded-concurrent-capture'
)) {
    Assert-Contains $stage2Verifier "--exact $processStdioFixture" "Stage2 process stdio fixture $processStdioFixture"
    Assert-Contains $stage3Verifier "--exact $processStdioFixture" "Stage3 process stdio fixture $processStdioFixture"
}
Assert-Contains $stage2Verifier '--exact 631-selfhost-native-handle-type' "Stage2 direct each-role member interpolation fixture"
Assert-Contains $stage3Verifier '--exact 631-selfhost-native-handle-type' "Stage3 direct each-role member interpolation fixture"
Assert-Contains $stage2Verifier '582-billion-sensor-alerts.slg' "Stage2 stream each-role member interpolation negative control"
Assert-Contains $stage3Verifier '--exact 582-billion-sensor-alerts' "Stage3 stream each-role member interpolation negative control"
Assert-MatchCount $stage2Verifier '"--jobs", \$Stage2BuildJobs\.ToString' 4 "Stage2 compiler and repeated native-build worker forwarding"
Assert-MatchCount $stage3Verifier '"--jobs", \$Jobs\.ToString' 6 "Stage3 compiler, native-build, and public-stdlib worker forwarding"
Assert-Contains $controlProducerFixture 'typedIr.isTransparentControlProducerWrapper' "control-producer wrapper structural fixture"
Assert-Contains $controlProducerExpected 'control producer wrappers=1,invalid trailing calls=0,take control subjects=1' "control-producer wrapper expected topology"
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure-contract.ps1")

$formalExactFixtures = [regex]::Matches("$stage2Verifier`n$stage3Verifier", '--exact\s+(?<name>[a-zA-Z0-9_/-]+)') |
    ForEach-Object { $_.Groups['name'].Value } |
    Sort-Object -Unique
foreach ($fixtureName in $formalExactFixtures) {
    $isDiagnostic = $fixtureName.StartsWith('diagnostic/', [System.StringComparison]::Ordinal)
    $fixtureLeaf = if ($isDiagnostic) { $fixtureName.Substring('diagnostic/'.Length) } else { $fixtureName }
    $fixtureRelativePath = if ($isDiagnostic) {
        "examples/regression/diagnostics/$fixtureLeaf.slg"
    } else {
        "examples/regression/$fixtureLeaf.slg"
    }
    $fixturePath = Join-Path $RepositoryRoot $fixtureRelativePath
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
        throw "Formal exact compiler fixture source is missing: $fixtureName"
    }
    $fixtureSource = [IO.File]::ReadAllText($fixturePath)
    if ($fixtureSource.Contains("import sollang.compiler.")) {
        $fixtureSourcesRelativePath = if ($isDiagnostic) {
            "examples/regression/diagnostics/$fixtureLeaf.sources.txt"
        } else {
            "examples/regression/expected/$fixtureLeaf.sources.txt"
        }
        $fixtureSourcesPath = Join-Path $RepositoryRoot $fixtureSourcesRelativePath
        if (-not (Test-Path -LiteralPath $fixtureSourcesPath -PathType Leaf)) {
            throw "Formal exact compiler fixture is missing its source closure: $fixtureName"
        }
        $fixtureSources = [IO.File]::ReadAllLines($fixtureSourcesPath)
        $expectedRoot = $fixtureRelativePath
        if ($fixtureSources.Count -eq 0 -or $fixtureSources[0] -cne $expectedRoot) {
            throw "Formal exact compiler fixture source closure must start with '$expectedRoot'"
        }
        & (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
            -Manifest @($fixtureSourcesPath, $runtimeSupportManifestPath) `
            -RepositoryRoot $RepositoryRoot
    }
}
Assert-NotContains $functionScheduling "scheduleNode.kind == 6 and (scheduleNode.symbol == -101" "function console scheduling"
Assert-NotContains $functions "(expression.kind == 6 and expression.symbol != -103" "function general console emission"
Assert-NotContains $control "(regionNode.kind == 6 and regionNode.symbol != -103" "control-region general console emission"
Assert-NotContains $text "entryScheduleNode.kind == 6 and (entryScheduleNode.symbol == -101" "entry-point console scheduling"
Assert-NotContains $text "(entryExpression.kind == 6 and entryExpression.symbol != -103" "entry-point general console emission"
Assert-Contains $incrementalVerifier '$fixtureEntrypointRoots.Count -gt 1' "independent fixture-root fail-fast"
Assert-Contains $incrementalVerifier 'independent roots must be verified separately' "independent fixture-root diagnostic"
Assert-Contains $incrementalVerifier 'function Assert-SlgSeedBootstrapCapabilities' "incremental SLG seed capability preflight"
Assert-Contains $incrementalVerifier '1267-mutable-name-suffix-resolution.slg' "incremental mutable suffix seed capability fixture"
Assert-Contains $incrementalVerifier 'The receipt proves artifact identity, not source-language capability' "seed receipt and capability separation diagnostic"
Assert-Matches $incrementalVerifier '(?s)Assert-SlgSeedBootstrapCapabilities \$SlgSeedCompiler.*?\[fast 1/5\] SLG-first selfhost compiler cache MISS' "seed capability preflight precedes expensive compiler emission"

Assert-Contains $semanticContext 'public nominalIsOwnedResource snapshot: SemanticSnapshot, typeId: Int -> Bool' "single affine native-resource semantic authority"
Assert-Contains $semanticOwnership 'prepared -> semanticContext.nominalIsOwnedResource(currentTypeId)' "ownership checker uses the affine native-resource authority"
Assert-Contains $typedFunctionLowering 'prepared -> semanticContext.ownedResourceSeeds(resolved.types) => resourceSeeds' "Typed IR seeds affine native-resource traits from the semantic authority"
Assert-Contains $typedResolvedContextFinalize 'and (recursiveTypeFlags[ownedResourceNode!.typeId] / 4) % 2 == 1' "Typed IR finalization publishes the frozen affine native-resource trait"
Assert-Contains $typedCore 'or (ir[site.operand0].typeFlags / 4) % 2 == 1)' "affine native-resource member move classification"
Assert-Contains $typedCore 'bindingIr: moveBindingIr!' "move events retain exact pattern-binding identity"
Assert-Contains $semanticOwnership 'borrowedSlice.operand0 -> placeRootBinding => borrowedSliceRootBinding' "borrowed Text return traces a projected SourceText receiver to its root"
Assert-Contains $semanticOwnership 'borrowedSliceRootBinding == borrowedParameterIr!' "borrowed Text return matches the exact parameter root"
Assert-Contains $borrowedProjectedTextFixture 'request!.head -> text => view' "projected borrowed Text regression origin"
Assert-Contains $borrowedProjectedTextFixture 'request! -> consume' "projected borrowed Text regression owner move"
Assert-Contains $borrowedProjectedTextFixture 'view -> len -> println' "projected borrowed Text regression use after move"
Assert-Contains $functions 'emitCompletedPatternBindingTransferMarks(context, state)' "function call and aggregate pattern-transfer liveness marks"
Assert-Contains $control 'emitCompletedPatternBindingTransferMarks(context, state)' "control-region call and aggregate pattern-transfer liveness marks"
Assert-Matches $controlRegions 'returnParameter\.flags % 2 == 1\s+and returnParameterHasPartialMoves! and not returnParameterTransferred!\s+and \(returnParameter -> isNominalStructType\)\s+-> if' "explicit return partial-move cleanup requires move ownership and skips an already transferred parameter"
Assert-Contains $controlRegions 'hasPartialMoves: true' "explicit return partial drop glue"
Assert-Contains $controlRegions 'partial_arg_owned = load i1' "explicit return partial cleanup checks path ownership before dropping"
Assert-Contains $controlRegions 'partial_arg_path' "explicit return partial cleanup owns a guarded drop path"
Assert-Matches $controlRegions '(?s)moveParameterNeedsPathOwnershipFlag\(ownerIndex!.*?returnParameterHasPathOwnershipFlag -> if \{.*?partial_arg_owned = load i1' "explicit return emits an ownership guard only when the parameter owns that runtime flag"
Assert-Contains $ownership 'moveParameterNeedsPathOwnershipFlag parameterIndex:' "path-sensitive move-parameter ownership predicate"
Assert-Contains $foundation '%arg$(pathOwnedParameterIndex!)_owned = alloca i1' "path-sensitive move-parameter liveness flag is hoisted to function entry"
Assert-Contains $coreCalls 'parameterIndexForFunction(transferOwner!, moveEvent.symbol)' "completed transfers resolve the exact move-parameter declaration"
Assert-Contains $coreCalls 'moveEvent.sourceModule == context.ir[transferOwner!].sourceModule' "completed transfers preserve source-module identity"
Assert-Contains $coreCalls 'store i1 false, ptr %arg$(transferredParameter)_owned' "successful aggregate construction transfers the path-owned parameter"
Assert-Contains $ownership 'enumMatchOwnsSubject subjectIndex:' "enum payload cleanup has one producer-ownership authority"
Assert-Contains $ownership 'context.types[producerType].kind == 8' "reference-result enum producers remain borrowed"
Assert-NotContains $ownership 'producerType -> semanticTypeOwns(context, state)' "fresh enum payload cleanup does not depend on the container ownership trait"
Assert-Matches $ownership '(?s)regionFullyMovesBinding regionIndex:.*?regionIndex -> regionReturns\(context, state\)\s+-> if \{ true -> return \}' "terminating regions do not retain ownership at a continuing merge"
Assert-Contains $ownership 'armIndex! -> enumMatchArmRegion(context, state) => armRegion' "enum ownership analysis resolves the emitted body region"
Assert-Contains $control 'enumMatchArmRegion armIndex:' "canonical enum arm body resolver"
Assert-Contains $control 'armIndex! -> enumMatchArmRegion(context, state) => emittedArmRegion' "enum emission shares the ownership body resolver"
Assert-Contains $control '(match.operand0 -> enumMatchOwnsSubject(context, state))' "enum match derives fresh-producer ownership from its exact subject"
Assert-Matches $control '(?s)subject\.kind == 5 and subject\.operand0 >= 0.*?context\.ir\[subject\.operand0\]\.kind == 17.*?kind == 29.*?state\.frozenEnumMatchConsumed -> ownershipEmitter\.enumMatchConsumes\(match\.operand0, subject\.kind, subject\.operand0\).*?=> matchOwnsSubject' "enum match also derives transferred binding ownership from the frozen consumption snapshot"
Assert-Matches $control 'armBindingIndex >= 0\s+and matchOwnsSubject\s+and context.ir\[armBindingIndex\].typeId >= 0' "borrowed enum payloads have no independent cleanup"
$memberAssignmentSource = [IO.File]::ReadAllText($containerControlPath)
Assert-Matches $memberAssignmentSource '(?s)store %sollang.struct.*?assignmentBinding -> storageAlign\(context, state\) -> writeDecimalLine\s+request.nodeIndex -> emitCompletedPatternBindingTransferMarks' "member assignment marks ownership transfer after the successful store"
Assert-Matches $memberAssignmentSource '(?s)producerPipelineConsumesBinding bindingIndex:.*?context\.streamPlan\.junctions.*?junction\.kind == 1.*?junction\.source0 -> streamIr\.resolveProducer\(context\.ir\).*?source == context\.ir\[bindingIndex\]\.operand0' "partition source ownership is consumed by its direct-dispatch junction"
Assert-Contains $functions '%drop_arg$(ownedParameterOrdinal!)_still_owned = load i1' "common epilogue guards the sibling-path parameter drop"

Assert-Contains $ownership 'integerQuotientOperation expression:' "canonical integer quotient signedness helper"
Assert-Contains $ownership 'if { "sdiv" } else { "udiv" }' "signed and unsigned integer quotient selection"
Assert-Contains $ownership 'integerRemainderOperation expression:' "canonical integer remainder signedness helper"
Assert-Contains $ownership 'if { "srem" } else { "urem" }' "signed and unsigned integer remainder selection"
Assert-Matches $ownership '(?s)node\.kind == 7.*?node\.opcode == -26.*?unaryOperand\.kind != 3.*?unaryOperand -> integerNodeWidth\(context, state\).*?unaryOperandWidth => width!' "computed unary expression preserves operand integer width while literal magnitude keeps contextual bounds"
Assert-Matches $ast '(?s)astKind! == 20.*?operatorTokenIndex! != node\.firstToken.*?candidateOperator == grammar\.tokenIdPlus\(\).*?candidateOperator == grammar\.tokenIdMinus\(\)' "additive AST operator selection skips a leading unary sign"
Assert-Contains $foundation 'interpolationIntegerSigned nodeIndex:' "interpolation integer signedness helper"
Assert-Contains ([IO.File]::ReadAllText((Join-Path $RepositoryRoot 'selfhost/llvm/text/control_regions.slg'))) '_whole_arg_owned = load i1' "early whole-parameter cleanup observes path ownership"
Assert-Contains $foundation 'node.kind != 1 or node.symbol < 0 -> if { -1 -> return }' "interpolation bindings require a resolved lexical identity"
Assert-Contains $foundation 'interpolationQuotientOperation nodeIndex:' "interpolation quotient signedness helper"
Assert-Contains $foundation 'interpolationRemainderOperation nodeIndex:' "interpolation remainder signedness helper"
Assert-Contains $foundation 'interpolationComparisonOperation nodeIndex:' "interpolation comparison signedness helper"
foreach ($genericEmitter in @(
    [ordered]@{ Name = "entry emitter"; Text = $text },
    [ordered]@{ Name = "function interpolation emitter"; Text = $functionCalls },
    [ordered]@{ Name = "control interpolation emitter"; Text = $controlRegions }
)) {
    Assert-NotMatches $genericEmitter.Text 'tokenIdPercent\(\)[\s\S]{0,120}"srem"' "$($genericEmitter.Name) hard-coded signed remainder"
    Assert-NotMatches $genericEmitter.Text 'tokenIdSlash\(\)[\s\S]{0,120}"sdiv"' "$($genericEmitter.Name) hard-coded signed quotient"
}

$staleRanges = Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot "selfhost") -Recurse -File -Filter "*.slg" |
    Where-Object { $_.FullName -ne $typedPath } |
    Select-String -SimpleMatch ">= -274"
if ($staleRanges) {
    $locations = $staleRanges | ForEach-Object { "$($_.Path):$($_.LineNumber)" }
    throw "socket opcode consumers must use typed predicates instead of a contiguous range:`n$($locations -join "`n")"
}

Assert-Contains $detachedVerification 'executionMode = "detached-supervisor"' "detached execution mode evidence"
Assert-Matches $detachedVerification '(?s)\$scratchRoot = .*?if \(\$Verification -eq "Stage3" -and \$SeedMode -eq "Stage2Bridge"\)' "Stage3 seed mode fail-fast before launch"
Assert-Contains $detachedVerification '-WindowStyle Hidden' "hidden detached supervisor launch"
Assert-Contains $detachedVerification '"Stage2Linux" { Join-Path $PSScriptRoot "verify-selfhost-stage2-linux.ps1" }' "detached Linux Stage2 routing"
Assert-Contains $detachedVerification '"Stage3Linux" { Join-Path $PSScriptRoot "verify-selfhost-stage3-linux.ps1" }' "detached Linux Stage3 routing"
Assert-Contains $detachedVerification '"BrowserStage2" { Join-Path $PSScriptRoot "build-stage2-browser.ps1" }' "detached browser Stage2 routing"
Assert-Contains $detachedVerification 'BrowserCandidateCompiler and BrowserFocusedFixture must be supplied together' "detached focused browser inputs are paired"
Assert-Contains $detachedVerification '"-AllowUnpromotedCandidate"' "detached focused browser route is explicitly unpromoted"
Assert-Contains $detachedVerification '"artifacts\scratch\browser-focused-" + $RunId' "detached focused browser outputs are run-scoped"
Assert-Contains $detachedVerification 'if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" } else { $targetArguments += "-Rebuild" }' "detached Linux Stage2 fresh rebuild or receipt-bound resume"
Assert-Matches $detachedVerification '(?s)Start-Process.*?-RedirectStandardOutput \$LogPath.*?-PassThru' "supervised process with authoritative exit code"
Assert-NotMatches $detachedVerification '(?s)Start-Process.*?-RedirectStandardOutput \$LogPath.*?-Wait\b' "no inherited-handle Start-Process wait"
Assert-Contains $detachedVerification '$targetProcess.WaitForExit(1000)' "exact supervised-process bounded wait sampling"
Assert-Contains $detachedVerification '$exitCode = $targetProcess.ExitCode' "actual supervised process exit code capture"
Assert-Contains $detachedVerification 'finally {' "completion record termination guarantee"
Assert-Contains $detachedVerification 'failureIds = @($failureIds)' "exact failure identifier recording"
Assert-Matches $detachedVerification '(?s)if \(-not \$cancelled -and \$exitCode -ne 0.*?fail\(\?:ed\|ure\)\?.*?\[regex\]::Matches\(\$line' "failure identifiers require nonzero exit and failure context"
Assert-Contains $detachedVerification 'Move-Item -LiteralPath $temporaryPath -Destination $Path -Force' "atomic completion record publication"
Assert-Contains $detachedVerification '$targetProcess.Kill($true)' "supported cancellation terminates the supervised process tree"
Assert-Matches $detachedVerification '(?s)Get-DescendantProcessIds.*?CreationDate.*?CreationDate -lt \$CreatedAfter.*?-CreatedAfter \$targetProcess\.StartTime' "detached cancellation rejects stale PID-reuse descendants"
Assert-Contains $detachedVerification '$failureIds.Add("CANCELLATION_REQUESTED")' "supported cancellation preserves its exact failure ID"
Assert-Contains $detachedProgress '"browserstage2" { "browser" }' "detached browser progress stage mapping"
Assert-Contains $detachedProgress '"browserstage2" { 4 }' "detached browser progress total"
Assert-Contains $detachedResultSchema '"BrowserStage2"' "detached browser result schema"
Assert-Contains $detachedCancellation 'The recorded supervisor PID does not identify the expected run' "cancellation request binds to the recorded supervisor identity"
Assert-Contains $detachedCancellation '@($result.orphanProcessIds).Count -ne 0' "cancellation request rejects orphan processes"
Assert-Contains $detachedVerificationContract '$observer.Id -eq $result.supervisorPid' "observer and supervisor process separation check"
Assert-Contains $detachedVerificationContract 'exit code 7 and 2/2 failure IDs preserved' "detached execution behavior evidence"
Assert-Contains $detachedProgress '"interrupted-without-result"' "missing completion record interruption classification"
Assert-Contains $detachedProgress '"stage2linux" { "linux-stage2" }' "detached Linux Stage2 progress prefix"
Assert-Contains $detachedProgress '"stage3linux" { "linux-stage3" }' "detached Linux Stage3 progress prefix"
Assert-Contains $detachedProgress '"stage2linux" { 6 }' "detached Linux Stage2 measured denominator"
Assert-Contains $detachedProgress '$current - 1' "running stage completion excludes the active ordinal"
Assert-Contains $detachedProgress 'percent = [math]::Round' "measured detached stage percentage"
Assert-Contains $detachedProgress '[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete' "live log share-safe progress read"
Assert-Contains $detachedVerificationContract 'Test-Json -SchemaFile $resultSchemaPath' "completion record schema execution"
Assert-Contains $detachedResultSchema '"failureIds": { "maxItems": 0 }' "successful completion forbids failure identifiers"
Assert-Matches $detachedResultSchema '(?s)"status": \{ "const": "passed" \}.*?"orphanProcessIds": \{ "maxItems": 0 \}' "successful completion forbids orphan processes"
Assert-Contains $detachedVerificationContract 'result schema accepted an orphan process on success' "successful completion orphan negative control"
Assert-Contains $detachedResultSchema '"status": { "const": "cancelled" }' "completion schema defines cancelled terminal state"
Assert-Contains $detachedResultSchema '"failureIds": { "const": ["CANCELLATION_REQUESTED"] }' "cancelled completion requires the exact failure ID"
Assert-Contains $detachedVerificationContract 'supported cancellation preserved cancelled, non-zero exit, CANCELLATION_REQUESTED, and zero orphans' "supported cancellation behavior evidence"

Write-Host "[selfhost compiler contracts] PASS native/browser analysis routing, exact runtime intrinsic identity, native-library ABI separation, explicit socket/process opcodes, affine Child cleanup, fixed-point artifact provenance, materialized console effects, reachable parallel callbacks, and Set intrinsic regression gates."
