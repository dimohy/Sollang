[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$LlvmObservationsOnly,
    [string]$ContractPath = 'scripts/contracts/interpolation-semantic-parity.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Invoke-InterpolationVerificationSource {
    param([string]$Root, [string]$RelativePath)
    if ($RelativePath -cne 'scripts/verify-utf8-each-runtime.ps1') {
        throw "Unsupported interpolation verification script: $RelativePath"
    }
    $path = Join-Path $Root $RelativePath
    $before = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    & $path -RepositoryRoot $Root
    if (-not $?) { throw "Current interpolation verification script failed: $RelativePath" }
    $after = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($before -cne $after) { throw "Interpolation verification script changed during execution: $RelativePath" }
    return $after
}
$root = [IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $PSScriptRoot 'verification-artifact-identity.ps1')
. (Join-Path $PSScriptRoot 'verification-c527-historical-baseline.ps1')
$resolvedContractPath = [IO.Path]::GetFullPath($ContractPath, $root)
$contract = Get-Content -LiteralPath $resolvedContractPath -Raw | ConvertFrom-Json
$llvmObservation = $contract.llvmObservationEvidence
function Read-CurrentLlvmObservations([object]$reference) {
    $compiler = (Resolve-Path -LiteralPath (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $reference.compiler)).Path
    if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -cne $reference.compilerSha256) {
        throw 'Current LLVM observation compiler changed'
    }
    $json = & python -X utf8 (Join-Path $PSScriptRoot 'verification_llvm_observations.py') `
        --repo $root --contract (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $reference.contract) --verify-proof (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $reference.proof)
    if ($LASTEXITCODE -ne 0) { throw 'Current LLVM observations are invalid' }
    ($json | ConvertFrom-Json -AsHashtable)['fixtures']
}
$llvmObservedFixtures = Read-CurrentLlvmObservations $llvmObservation
$dynamicObservation = $contract.currentDynamicRangeEvidence
$dynamicObservedFixtures = Read-CurrentLlvmObservations $dynamicObservation
$streamObservedFixtures = Read-CurrentLlvmObservations $contract.currentStreamCallbackLlvmEvidence
if ($LlvmObservationsOnly) {
    $observedCount = $llvmObservedFixtures.Count + $dynamicObservedFixtures.Count + $streamObservedFixtures.Count
    [ordered]@{ status = 'passed'; scope = 'llvm-observations-only'; completed = $observedCount
        total = $observedCount; claimsWholeParityComplete = $false
        compilerSha256 = $llvmObservation.compilerSha256 } | ConvertTo-Json
    return
}
$unaryDirect = Get-Content -LiteralPath (Join-Path $root $contract.unaryDirectOperandPreIrEvidence) -Raw | ConvertFrom-Json
$memberDirect = Get-Content -LiteralPath (Join-Path $root $contract.memberDirectFieldPreIrEvidence) -Raw | ConvertFrom-Json
$indexedArray = Get-Content -LiteralPath (Join-Path $root $contract.indexedArrayPreIrEvidence) -Raw | ConvertFrom-Json
& (Join-Path $PSScriptRoot 'verify-cli-diagnostic-encoding.ps1') -RepositoryRoot $root -ContractPath $contract.diagnosticEncodingEvidence
$expressionContract = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/expression-lowering-parity.json') -Raw | ConvertFrom-Json
$interpolationSourceText = Get-Content -LiteralPath (Join-Path $root 'selfhost/ir/interpolation.slg') -Raw
$semanticContext = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/context.slg') -Raw
$semanticAnalysis = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/analysis.slg') -Raw
$ownershipCheck = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/ownership_check.slg') -Raw
$emitterPreparation = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/context_prepare.slg') -Raw
$semanticInference = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/interpolation_inference.slg') -Raw
$collectionTypeIds = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/type_ids.slg') -Raw
$currentShared = $contract.currentSharedQueryEvidence
$currentSharedContractPath = [IO.Path]::GetFullPath((Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentShared.contract))
$currentSharedContract = Get-Content -LiteralPath $currentSharedContractPath -Raw | ConvertFrom-Json
$currentSharedManagedPath = [IO.Path]::GetFullPath((Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentShared.managed))
$currentSharedManaged = Get-Content -LiteralPath $currentSharedManagedPath -Raw | ConvertFrom-Json
$currentSharedPaired = Get-Content -LiteralPath (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentShared.paired) -Raw | ConvertFrom-Json
$currentSharedCompiler = [IO.Path]::GetFullPath((Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentShared.compiler))
if (@($currentSharedContract.cases).Count -ne 16 -or
    @($currentSharedContract.cases.id | Sort-Object -Unique).Count -ne 16 -or
    (Get-FileHash -LiteralPath $currentSharedCompiler -Algorithm SHA256).Hash -cne $currentShared.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentSharedPaired.inputHashes -LiteralPath $currentSharedCompiler) -cne $currentShared.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentSharedManaged.inputHashes -LiteralPath $currentSharedContractPath) -cne (Get-FileHash -LiteralPath $currentSharedContractPath -Algorithm SHA256).Hash -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentSharedPaired.inputHashes -LiteralPath $currentSharedContractPath) -cne (Get-FileHash -LiteralPath $currentSharedContractPath -Algorithm SHA256).Hash -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentSharedPaired.inputHashes -LiteralPath $currentSharedManagedPath) -cne (Get-FileHash -LiteralPath $currentSharedManagedPath -Algorithm SHA256).Hash) {
    throw 'CURRENT_SHARED_QUERY_IDENTITY_INVALID'
}
foreach ($entry in @(@{ proof = $currentSharedManaged; mode = 'managed' }, @{ proof = $currentSharedPaired; mode = 'paired' })) {
    $proof = $entry.proof
    if ($proof.status -cne 'passed' -or $proof.mode -cne $entry.mode -or
        $proof.completed -ne 16 -or $proof.total -ne 16 -or @($proof.cases).Count -ne 16 -or
        @($proof.cases.id | Sort-Object -Unique).Count -ne 16 -or
        -not $proof.inputsStable -or -not $proof.processesStopped) {
        throw 'CURRENT_SHARED_QUERY_PROOF_INCOMPLETE'
    }
    foreach ($inputHash in $proof.inputHashes.PSObject.Properties) {
        if ((Get-FileHash -LiteralPath $inputHash.Name -Algorithm SHA256).Hash -cne $inputHash.Value) {
            throw "CURRENT_SHARED_QUERY_INPUT_CHANGED: $($inputHash.Name)"
        }
    }
    foreach ($expectedCase in $currentSharedContract.cases) {
        $observed = @($proof.cases | Where-Object id -ceq $expectedCase.id)
        if ($observed.Count -ne 1 -or $observed[0].status -cne 'passed' -or -not $observed[0].passed -or
            $observed[0].buildExit -ne $expectedCase.exit -or $observed[0].buildStderr -cne $expectedCase.stderr -or
            ($expectedCase.exit -eq 0 -and ($observed[0].runExit -ne 0 -or
                $observed[0].runStdout -cne $expectedCase.stdout -or $observed[0].runStderr -cne ''))) {
            throw "CURRENT_SHARED_QUERY_EXACT_MISMATCH: $($expectedCase.id)"
        }
    }
}
Write-Host '[interpolation shared queries] PASS current original16 exact managed/native behavior'
$semanticTypeIds = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/expression_type_ids.slg') -Raw
$managedSemantic = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw
$managedCodegen = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Expressions.Core.cs') -Raw
$managedConversionCodegen = Get-Content -LiteralPath (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs') -Raw
$interpolationLowering = Get-Content -LiteralPath (Join-Path $root 'selfhost/ir/interpolation.slg') -Raw
$emitterDiagnostics = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/emitter/diagnostics.slg') -Raw
$numericLiteralRange = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/numeric_literal_range.slg') -Raw
$interpolationCodegen = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Raw
$interpolationEntryCodegen = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/entry_expressions.slg') -Raw
$integerAlias = Get-Content -LiteralPath (Join-Path $root $contract.integerLiteralAliasEvidence) -Raw | ConvertFrom-Json
$integerAliasBuild = Get-Content -LiteralPath (Join-Path $root $integerAlias.candidateBuild) -Raw | ConvertFrom-Json
$integerAliasFocused = Get-Content -LiteralPath (Join-Path $root $integerAlias.focusedPair) -Raw | ConvertFrom-Json
$integerAliasControls = Get-Content -LiteralPath (Join-Path $root $integerAlias.controlPair) -Raw | ConvertFrom-Json
$integerAliasBaseline = Get-Content -LiteralPath (Join-Path $root $integerAlias.baselineWideLiteralPair) -Raw | ConvertFrom-Json
$integerAliasManaged = Get-Content -LiteralPath (Join-Path $root $integerAlias.managedWideLiteralProof) -Raw | ConvertFrom-Json
$integerAliasCompiler = Join-Path (Split-Path -Parent (Join-Path $root $integerAlias.candidateBuild)) 'compiler.exe'
$integerAliasSameWidthLlChecks = $llvmObservedFixtures['1877-interpolation-same-width-integer-conversion']
$integerAliasWideLlChecks = $llvmObservedFixtures['1878-interpolation-wide-integer-literal-conversion']
if ($integerAlias.status -cne 'passed-slice-unit-open' -or $integerAlias.focusedPassed -cne '6/6' -or
    $integerAlias.semanticOwnedKindsComplete -cne '3/12' -or
    $integerAliasBuild.status -cne 'passed' -or $integerAliasBuild.compilerSha256 -cne $integerAlias.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $integerAliasCompiler -Algorithm SHA256).Hash -cne $integerAlias.compilerSha256 -or
    $integerAliasFocused.status -cne 'passed' -or $integerAliasFocused.completed -ne 2 -or $integerAliasFocused.total -ne 2 -or -not $integerAliasFocused.inputStable -or
    $integerAliasControls.status -cne 'passed' -or $integerAliasControls.completed -ne 4 -or $integerAliasControls.total -ne 4 -or -not $integerAliasControls.inputStable -or
    $integerAliasBaseline.status -cne 'failed' -or $integerAliasManaged.status -cne 'passed' -or
    $integerAliasSameWidthLlChecks['no-freeze'] -or
    -not $integerAliasSameWidthLlChecks['upper'] -or
    -not $integerAliasSameWidthLlChecks['lower'] -or
    -not $integerAliasWideLlChecks['positive-wide'] -or
    -not $integerAliasWideLlChecks['negative-wide'] -or
    $integerAliasWideLlChecks['no-truncated-source'] -or
    -not $interpolationCodegen.Contains('sameWidthNumericConversionOperand', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('writeInterpolationIntegerSyntaxLiteral', [StringComparison]::Ordinal) -or
    -not $interpolationEntryCodegen.Contains('entryExpressionIndex -> writeInterpolationValue(entryExpressionRootSearch!, entryExpressionInterpolation, runtimeArgument.sourceModule, functionIndex, entryExpressionIndex, context, state)', [StringComparison]::Ordinal)) {
    throw 'integer interpolation literal and same-width alias lack source, LLVM, and paired evidence'
}
$negativeSize = Get-Content -LiteralPath (Join-Path $root $contract.negativeSizeEvidence) -Raw | ConvertFrom-Json
$negativeSizeManaged = Get-Content -LiteralPath (Join-Path $root $negativeSize.managedProof) -Raw | ConvertFrom-Json
$negativeSizeBaseline = Get-Content -LiteralPath (Join-Path $root $negativeSize.baselineFailure) -Raw | ConvertFrom-Json
$negativeSizeBuild = Get-Content -LiteralPath (Join-Path $root $negativeSize.candidateBuild) -Raw | ConvertFrom-Json
$negativeSizeFocused = Get-Content -LiteralPath (Join-Path $root $negativeSize.focusedPair) -Raw | ConvertFrom-Json
$negativeSizeControls = Get-Content -LiteralPath (Join-Path $root $negativeSize.controlPair) -Raw | ConvertFrom-Json
$negativeSizeCompiler = Join-Path (Split-Path -Parent (Join-Path $root $negativeSize.candidateBuild)) 'compiler.exe'
$negativeSizeLlChecks = $llvmObservedFixtures['1879-interpolation-negative-size-conversion']
if ($negativeSize.status -cne 'passed-slice-unit-open' -or $negativeSize.focusedPassed -cne '5/5' -or
    $negativeSize.semanticOwnedKindsComplete -cne '3/12' -or
    $negativeSizeManaged.status -cne 'passed' -or -not $negativeSizeManaged.inputsStable -or
    $negativeSizeManaged.stdout -cne "negative=-7,nested=-9`n" -or
    $negativeSizeBaseline.status -cne 'failed' -or -not $negativeSizeBaseline.inputStable -or
    $negativeSizeBuild.status -cne 'passed' -or -not $negativeSizeBuild.inputsStable -or
    $negativeSizeBuild.compilerSha256 -cne $negativeSize.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $negativeSizeCompiler -Algorithm SHA256).Hash -cne $negativeSize.compilerSha256 -or
    $negativeSizeFocused.status -cne 'passed' -or $negativeSizeFocused.completed -ne 1 -or $negativeSizeFocused.total -ne 1 -or -not $negativeSizeFocused.inputStable -or
    $negativeSizeControls.status -cne 'passed' -or $negativeSizeControls.completed -ne 4 -or $negativeSizeControls.total -ne 4 -or -not $negativeSizeControls.inputStable -or
    -not $negativeSizeLlChecks['negative-constant'] -or
    -not $negativeSizeLlChecks['negative-value'] -or
    -not $managedSemantic.Contains('private static bool IsSignedIntegerType(BoundType type)', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('operandBuiltin -> typeIds.isSignedNumericBuiltinSymbol', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('labelIndex -> writeInterpolationScalarValue(node.operand0, nodes, sourceModule, ownerIndex, beforeIndex, context, state)', [StringComparison]::Ordinal)) {
    throw 'signed Size unary interpolation lacks current source and paired LLVM evidence'
}
$nestedOperand = Get-Content -LiteralPath (Join-Path $root $contract.nestedOperandEvidence) -Raw | ConvertFrom-Json
$nestedManaged = Get-Content -LiteralPath (Join-Path $root $nestedOperand.managedProof) -Raw | ConvertFrom-Json
$nestedFunctionBaseline = Get-Content -LiteralPath (Join-Path $root $nestedOperand.baselineFunctionFailure) -Raw | ConvertFrom-Json
$nestedArithmeticBaseline = Get-Content -LiteralPath (Join-Path $root $nestedOperand.baselineArithmeticFailure) -Raw | ConvertFrom-Json
$nestedBuild = Get-Content -LiteralPath (Join-Path $root $nestedOperand.candidateBuild) -Raw | ConvertFrom-Json
$nestedFocused = Get-Content -LiteralPath (Join-Path $root $nestedOperand.focusedPair) -Raw | ConvertFrom-Json
$nestedControls = Get-Content -LiteralPath (Join-Path $root $nestedOperand.controlPair) -Raw | ConvertFrom-Json
$nestedCompiler = Join-Path (Split-Path -Parent (Join-Path $root $nestedOperand.candidateBuild)) 'compiler.exe'
$nestedFunctionCodegen = Get-Content -LiteralPath (Join-Path $root $nestedOperand.selfhostFunctionSource) -Raw
$nestedFunctionLlChecks = $llvmObservedFixtures['1880-function-interpolation-negative-size-conversion']
$nestedArithmeticLlChecks = $llvmObservedFixtures['1881-interpolation-nested-conversion-arithmetic']
if ($nestedOperand.status -cne 'passed-slice-unit-open' -or $nestedOperand.focusedPassed -cne '6/6' -or
    $nestedOperand.semanticOwnedKindsComplete -cne '3/12' -or
    $nestedManaged.status -cne 'passed' -or $nestedManaged.completed -ne 2 -or $nestedManaged.total -ne 2 -or -not $nestedManaged.inputsStable -or
    $nestedFunctionBaseline.status -cne 'failed' -or -not $nestedFunctionBaseline.inputStable -or
    $nestedArithmeticBaseline.status -cne 'failed' -or -not $nestedArithmeticBaseline.inputStable -or
    $nestedBuild.status -cne 'passed' -or -not $nestedBuild.inputsStable -or
    $nestedBuild.compilerSha256 -cne $nestedOperand.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $nestedCompiler -Algorithm SHA256).Hash -cne $nestedOperand.compilerSha256 -or
    $nestedFocused.status -cne 'passed' -or $nestedFocused.completed -ne 2 -or $nestedFocused.total -ne 2 -or -not $nestedFocused.inputStable -or
    $nestedControls.status -cne 'passed' -or $nestedControls.completed -ne 4 -or $nestedControls.total -ne 4 -or -not $nestedControls.inputStable -or
    -not $nestedFunctionLlChecks['negative-constant'] -or
    -not $nestedArithmeticLlChecks['nested-add'] -or
    -not $interpolationCodegen.Contains('labelIndex -> writeInterpolationScalarValue(node.operand1, nodes, sourceModule, ownerIndex, beforeIndex, context, state)', [StringComparison]::Ordinal) -or
    -not $nestedFunctionCodegen.Contains('expressionIndex -> emitInterpolationOperation(', [StringComparison]::Ordinal) -or
    -not $nestedFunctionCodegen.Contains('expressionIndex -> writeInterpolationValue(functionExpressionRootIndex, functionExpressionInterpolation, runtimeArgument.sourceModule, functionIndex, expressionIndex, context, state)', [StringComparison]::Ordinal)) {
    throw 'nested interpolation conversion operands lack C# first, SLG source, LLVM, and paired evidence'
}
$firstError = Get-Content -LiteralPath (Join-Path $root $contract.firstErrorSelectionEvidence) -Raw | ConvertFrom-Json
$firstUnaryManaged = Get-Content -LiteralPath (Join-Path $root $firstError.managedFirstUnaryProof) -Raw | ConvertFrom-Json
$firstRangeManaged = Get-Content -LiteralPath (Join-Path $root $firstError.managedFirstRangeProof) -Raw | ConvertFrom-Json
$firstBaseline = Get-Content -LiteralPath (Join-Path $root $firstError.baselineFailure) -Raw | ConvertFrom-Json
$firstBuild = Get-Content -LiteralPath (Join-Path $root $firstError.candidateBuild) -Raw | ConvertFrom-Json
$firstUnaryPair = Get-Content -LiteralPath (Join-Path $root $firstError.firstUnaryPair) -Raw | ConvertFrom-Json
$firstRangePair = Get-Content -LiteralPath (Join-Path $root $firstError.firstRangePair) -Raw | ConvertFrom-Json
$firstControl = Get-Content -LiteralPath (Join-Path $root $firstError.retainedCharacterRangePair) -Raw | ConvertFrom-Json
$firstCompiler = Join-Path (Split-Path -Parent (Join-Path $root $firstError.candidateBuild)) 'compiler.exe'
$firstUnaryStderr = Get-Content -LiteralPath (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $firstUnaryPair.logs.selfhostStderr) -Raw
$firstRangeStderr = Get-Content -LiteralPath (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $firstRangePair.logs.selfhostStderr) -Raw
$firstBaselineStderr = Get-Content -LiteralPath (Join-Path (Split-Path -Parent (Join-Path $root $firstError.baselineFailure)) 'stderr.txt') -Raw
$interpolationDiagnostics = Get-Content -LiteralPath (Join-Path $root $firstError.selfhostDecisionSource) -Raw
if ($firstError.status -cne 'passed-slice-unit-open' -or $firstError.focusedPassed -cne '3/3' -or
    $firstError.semanticOwnedKindsComplete -cne '3/12' -or $firstError.exactStderrFormattingComplete -cne '0/2' -or
    $firstUnaryManaged.status -cne 'passed' -or -not $firstUnaryManaged.inputsStable -or
    $firstUnaryManaged.stderr -notmatch "operand of unary '-' must be a signed numeric value" -or
    $firstUnaryManaged.stderr -match 'numeric literal 128 is out of range' -or
    $firstRangeManaged.status -cne 'passed' -or -not $firstRangeManaged.inputsStable -or
    $firstRangeManaged.stderr -notmatch 'numeric literal 128 is out of range' -or
    $firstRangeManaged.stderr -match "operand of unary '-' must be a signed numeric value" -or
    $firstBaseline.buildExit -ne 1 -or -not $firstBaseline.inputsStable -or
    $firstBaselineStderr -notmatch "operand of unary '-' must be a signed numeric value" -or
    $firstBaselineStderr -notmatch 'numeric literal 128 is out of range' -or
    $firstBuild.status -cne 'passed' -or -not $firstBuild.inputsStable -or
    $firstBuild.compilerSha256 -cne $firstError.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $firstCompiler -Algorithm SHA256).Hash -cne $firstError.compilerSha256 -or
    $firstUnaryPair.state -cne 'passed' -or -not $firstUnaryPair.inputsStable -or
    $firstRangePair.state -cne 'passed' -or -not $firstRangePair.inputsStable -or
    $firstControl.state -cne 'passed' -or -not $firstControl.inputsStable -or
    ([regex]::Matches($firstUnaryStderr, '(?m)^; sollang semantic error:')).Count -ne 1 -or
    ([regex]::Matches($firstRangeStderr, '(?m)^; sollang semantic error:')).Count -ne 1 -or
    $firstUnaryStderr -match 'numeric literal 128 is out of range' -or
    $firstRangeStderr -match "operand of unary '-' must be a signed numeric value" -or
    -not $interpolationDiagnostics.Contains('firstBlockingInterpolationNode', [StringComparison]::Ordinal) -or
    -not $interpolationDiagnostics.Contains('context -> firstBlockingInterpolationNode => nodeIndex!', [StringComparison]::Ordinal)) {
    throw 'first interpolation failure selection lacks managed source-order proof and focused paired evidence'
}
$exactSlice = Get-Content -LiteralPath (Join-Path $root $contract.exactStderrEvidence) -Raw | ConvertFrom-Json
$exactBuild = Get-Content -LiteralPath (Join-Path $root $exactSlice.candidateBuild) -Raw | ConvertFrom-Json
$exactReport = Get-Content -LiteralPath (Join-Path $root $exactSlice.exactStderrEvidence) -Raw | ConvertFrom-Json
$exactCompiler = Join-Path (Split-Path -Parent (Join-Path $root $exactSlice.candidateBuild)) 'compiler.exe'
$semanticDiagnostics = Get-Content -LiteralPath (Join-Path $root $exactSlice.selfhostSemanticSource) -Raw
$driver = Get-Content -LiteralPath (Join-Path $root $exactSlice.selfhostCliSource) -Raw
if ($exactSlice.status -cne 'passed-slice-unit-open' -or $exactSlice.focusedExact -cne '5/5' -or
    $exactSlice.semanticOwnedKindsComplete -cne '3/12' -or
    $exactBuild.status -cne 'passed' -or -not $exactBuild.inputsStable -or
    $exactBuild.compilerSha256 -cne $exactSlice.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $exactCompiler -Algorithm SHA256).Hash -cne $exactSlice.compilerSha256 -or
    $exactReport.comparison -cne 'whole-stderr-ordinal-after-crlf-normalization' -or
    $exactReport.status -cne 'passed' -or $exactReport.completed -ne 5 -or $exactReport.total -ne 5 -or
    @($exactReport.cases).Count -ne 5 -or @($exactReport.cases | Where-Object { -not $_.exact }).Count -ne 0 -or
    -not $managedSemantic.Contains('private SollangException Error(int line, int column, string message)', [StringComparison]::Ordinal) -or
    -not $semanticDiagnostics.Contains('public interpolationFragmentLocation', [StringComparison]::Ordinal) -or
    -not $semanticDiagnostics.Contains('public interpolationBelongsToMain', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('emitInterpolationSemanticPrefix', [StringComparison]::Ordinal) -or
    -not $driver.Contains('diagnostics -> slice(start!, length - start!) -> runtime.eprint', [StringComparison]::Ordinal)) {
    throw 'interpolation exact stderr slice lacks current source, build, or 5/5 paired evidence'
}
function Assert-ExactStderrReport([object]$Report, [int]$Total, [string]$CompilerSha256) {
    if ($Report.comparison -cne 'whole-stderr-ordinal-after-crlf-normalization' -or
        $Report.status -cne 'passed' -or $Report.completed -ne $Total -or $Report.total -ne $Total -or
        @($Report.cases).Count -ne $Total -or @($Report.cases | Where-Object { -not $_.exact }).Count -ne 0) {
        throw "interpolation exact stderr report is incomplete: $($Report.completed)/$($Report.total)"
    }
    foreach ($case in $Report.cases) {
        $pair = Get-Content -LiteralPath (Join-Path $root $case.receipt) -Raw | ConvertFrom-Json
        $managedLog = Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $pair.logs.managedStderr
        $selfhostLog = Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $pair.logs.selfhostStderr
        $managedStderr = [IO.File]::ReadAllText($managedLog).Replace("`r`n", "`n")
        $selfhostStderr = [IO.File]::ReadAllText($selfhostLog).Replace("`r`n", "`n")
        if ($pair.state -cne 'passed' -or -not $pair.inputsStable -or
            $pair.sourceSha256 -cne $case.sourceSha256 -or
            $pair.selfhostCompilerSha256 -cne $CompilerSha256 -or
            $pair.managedCompilerSha256 -cne $case.managedCompilerSha256 -or
            (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $pair.source -Algorithm SHA256).Hash -cne $pair.sourceSha256 -or
            (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $pair.expected -Algorithm SHA256).Hash -cne $pair.expectedSha256 -or
            (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedManagedExecutionRecord $case.receipt -LiteralPath $pair.managedCompilerPath -Algorithm SHA256).Hash -cne $pair.managedCompilerSha256 -or
            (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $pair.selfhostCompilerPath -Algorithm SHA256).Hash -cne $pair.selfhostCompilerSha256 -or
            [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($managedStderr))) -cne $case.managedStderrSha256 -or
            [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($selfhostStderr))) -cne $case.selfhostStderrSha256 -or
            $managedStderr -cne $selfhostStderr) {
            throw "interpolation exact stderr case is stale or mismatched: $($case.receipt)"
        }
    }
}
Assert-ExactStderrReport $exactReport 5 $exactSlice.compilerSha256
$conversionExact = Get-Content -LiteralPath (Join-Path $root $contract.numericConversionExactDiagnosticEvidence) -Raw | ConvertFrom-Json
$conversionExactBuild = Get-Content -LiteralPath (Join-Path $root $conversionExact.candidateBuild) -Raw | ConvertFrom-Json
$conversionExactReport = Get-Content -LiteralPath (Join-Path $root $conversionExact.exactStderrEvidence) -Raw | ConvertFrom-Json
$conversionCompiler = Join-Path (Split-Path -Parent (Join-Path $root $conversionExact.candidateBuild)) 'compiler.exe'
$conversionInference = Get-Content -LiteralPath (Join-Path $root $conversionExact.selfhostDecisionSource) -Raw
if ($conversionExact.status -cne 'passed-slice-unit-open' -or
    $conversionExact.newCasesExact -cne '4/4' -or $conversionExact.retainedCasesExact -cne '5/5' -or
    $conversionExact.combinedExact -cne '9/9' -or $conversionExact.semanticOwnedKindsComplete -cne '3/12' -or
    $conversionExactBuild.status -cne 'passed' -or -not $conversionExactBuild.inputsStable -or
    $conversionExactBuild.compilerSha256 -cne $conversionExact.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $conversionCompiler -Algorithm SHA256).Hash -cne $conversionExact.compilerSha256 -or
    -not $managedSemantic.Contains('if (expression.Arguments.Count != 1)', [StringComparison]::Ordinal) -or
    -not $conversionInference.Contains('public invalidNumericConversionArityByNode', [StringComparison]::Ordinal) -or
    -not $conversionInference.Contains('public invalidNumericConversionTypeByNode', [StringComparison]::Ordinal) -or
    -not $conversionInference.Contains('public invalidCodePointFloatConversionByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context -> emitInterpolationSemanticPrefix(nodeIndex!, sourceModule)', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context -> emitInterpolationSemanticPrefix(interpolationNode.operand0, sourceModule)', [StringComparison]::Ordinal)) {
    throw 'numeric-conversion exact diagnostic slice lacks C# source, semantic decisions, or current build'
}
Assert-ExactStderrReport $conversionExactReport 9 $conversionExact.compilerSha256
$unknownBinding = Get-Content -LiteralPath (Join-Path $root $contract.unknownBindingSemanticEvidence) -Raw | ConvertFrom-Json
$unknownBuild = Get-Content -LiteralPath (Join-Path $root $unknownBinding.candidateBuild) -Raw | ConvertFrom-Json
$unknownBaseline = Get-Content -LiteralPath (Join-Path $root $unknownBinding.baselineFailure) -Raw | ConvertFrom-Json
$unknownExact = Get-Content -LiteralPath (Join-Path $root $unknownBinding.unknownBindingExactEvidence) -Raw | ConvertFrom-Json
$unknownRetained = Get-Content -LiteralPath (Join-Path $root $unknownBinding.retainedDiagnosticExactEvidence) -Raw | ConvertFrom-Json
$unknownFunctionExact = Get-Content -LiteralPath (Join-Path $root $unknownBinding.functionNameExactEvidence) -Raw | ConvertFrom-Json
$unknownLocalExact = Get-Content -LiteralPath (Join-Path $root $unknownBinding.localFunctionScopeExactEvidence) -Raw | ConvertFrom-Json
$unknownPositive = Get-Content -LiteralPath (Join-Path $root $unknownBinding.positivePair) -Raw | ConvertFrom-Json
$unknownCompiler = Join-Path (Split-Path -Parent (Join-Path $root $unknownBinding.candidateBuild)) 'compiler.exe'
$unknownSemantic = Get-Content -LiteralPath (Join-Path $root $unknownBinding.selfhostDecisionSource) -Raw
$unknownCallResolution = Get-Content -LiteralPath (Join-Path $root $unknownBinding.selfhostCallResolutionSource) -Raw
$unknownPackageCallResolution = Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/call_resolution_sources.slg') -Raw
$currentUnknown = $contract.currentUnknownBindingEvidence
$unknownScopeComparisonPath = Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.sourceComparison
$unknownScopeComparison = Get-Content -LiteralPath $unknownScopeComparisonPath -Raw | ConvertFrom-Json
$unknownScopePaired = Get-Content -LiteralPath (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.paired) -Raw | ConvertFrom-Json
if ($unknownScopeComparison.status -cne 'compared-before-slg-edit' -or
    $unknownScopeComparison.slgCompilerEdits -ne 0 -or
    (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $unknownScopeComparison.managedFirst) -cne
        (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.managed) -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $unknownScopePaired.inputHashes -LiteralPath $unknownScopeComparisonPath) -cne
        (Get-FileHash -LiteralPath $unknownScopeComparisonPath -Algorithm SHA256).Hash) {
    throw 'CURRENT_UNKNOWN_SOURCE_COMPARISON_INVALID'
}
# The current resolver indexes functions by declaration parent instead of
# comparing candidate.parent in a linear scan. Bind the reviewed scope walk
# to the current exact13 execution rather than requiring obsolete source text.
$unknownScopeSources = @('src/Sollang.Compiler/Semantics/SemanticCompiler.cs', 'selfhost/semantic/calls.slg',
    'selfhost/semantic/call_resolution_sources.slg', 'selfhost/ir/interpolation.slg',
    'selfhost/semantic/interpolation_inference.slg', 'selfhost/llvm/text/context_prepare.slg',
    'selfhost/llvm/emitter/diagnostics.slg')
if (@($unknownScopeComparison.sourceHashes.PSObject.Properties).Count -ne $unknownScopeSources.Count) {
    throw 'CURRENT_UNKNOWN_SOURCE_COMPARISON_INVALID'
}
foreach ($source in $unknownScopeSources) {
    $sourceHash = Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $unknownScopeComparison.sourceHashes -LiteralPath $source
    if ((Get-FileHash -LiteralPath (Join-Path $root $source) -Algorithm SHA256).Hash -cne $sourceHash -or
        (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $unknownScopePaired.inputHashes -LiteralPath $source) -cne $sourceHash) {
        throw 'CURRENT_UNKNOWN_SOURCE_COMPARISON_INVALID'
    }
}
if ($unknownBinding.status -cne 'passed-slice-unit-open' -or
    $unknownBinding.unknownBindingExact -cne '5/5' -or
    $unknownBinding.retainedDiagnosticExact -cne '9/9' -or
    $unknownBinding.retainedPositive -cne '3/3' -or
    $unknownBinding.functionNameExact -cne '3/3' -or
    $unknownBinding.localFunctionScopeExact -cne '2/2' -or
    $unknownBinding.semanticOwnedKindsComplete -cne '3/12' -or
    $unknownBuild.status -cne 'passed' -or -not $unknownBuild.inputsStable -or
    $unknownBuild.compilerSha256 -cne $unknownBinding.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $unknownCompiler -Algorithm SHA256).Hash -cne $unknownBinding.compilerSha256 -or
    $unknownBaseline.failureId -cne 'NEGATIVE_CHECK_FAILED' -or $unknownBaseline.selfhost.expectedInStderr -or
    $unknownPositive.status -cne 'passed' -or -not $unknownPositive.inputStable -or
    $unknownPositive.completed -ne 3 -or $unknownPositive.total -ne 3 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $unknownPositive.inputHashesStart -LiteralPath $unknownCompiler) -cne $unknownBinding.compilerSha256 -or
    @($unknownBinding.managedFirstProofs).Count -ne 5 -or
    @($unknownBinding.functionNameBaselines).Count -ne 2 -or
    -not $managedSemantic.Contains('private BoundType InferStringExpression(', [StringComparison]::Ordinal) -or
    -not $managedSemantic.Contains('bindings.Keys', [StringComparison]::Ordinal) -or
    -not $managedSemantic.Contains('private BoundType InferNameExpression(', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('public prefixSymbol: Int', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('public bareFunctionStatus: Int', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('functionSymbol.parent == localFunctionOwner!', [StringComparison]::Ordinal) -or
    -not $unknownCallResolution.Contains('resolveLexicalFunction source:', [StringComparison]::Ordinal) -or
    -not $unknownCallResolution.Contains('resolveLexicalFunction(source, nodes, tokens, table', [StringComparison]::Ordinal) -or
    -not $unknownPackageCallResolution.Contains('resolveLexicalFunction(source, package.nodes, package.tokens, package.symbols', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('candidateVisible! -> if {', [StringComparison]::Ordinal) -or
    -not $unknownSemantic.Contains('public unresolvedInterpolationBindingByNode', [StringComparison]::Ordinal) -or
    -not $unknownSemantic.Contains('public uninvokedInterpolationFunctionByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('semanticDiagnostics.unresolvedInterpolationBindingByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('semanticDiagnostics.uninvokedInterpolationFunctionByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.unresolvedInterpolationBindingByNode[nodeIndex!]', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.uninvokedInterpolationFunctionByNode[interpolationIndex!]', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.uninvokedInterpolationFunctionByNode[nodeIndex!]', [StringComparison]::Ordinal) -or
    $emitterDiagnostics.Contains('isBlockingUnknownInterpolation', [StringComparison]::Ordinal)) {
    throw 'unknown interpolation binding slice lacks source-first semantic decision or current paired evidence'
}
$currentUnknownContractPath = [IO.Path]::GetFullPath((Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.contract))
$currentUnknownContract = Get-Content -LiteralPath $currentUnknownContractPath -Raw | ConvertFrom-Json
$currentUnknownManagedPath = [IO.Path]::GetFullPath((Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.managed))
$currentUnknownManaged = Get-Content -LiteralPath $currentUnknownManagedPath -Raw | ConvertFrom-Json
$currentUnknownPaired = Get-Content -LiteralPath (Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.paired) -Raw | ConvertFrom-Json
$currentUnknownCompiler = [IO.Path]::GetFullPath((Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $currentUnknown.compiler))
if (@($currentUnknownContract.cases).Count -ne 13 -or
    @($currentUnknownContract.cases.id | Sort-Object -Unique).Count -ne 13 -or
    (Get-FileHash -LiteralPath $currentUnknownCompiler -Algorithm SHA256).Hash -cne $currentUnknown.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentUnknownPaired.inputHashes -LiteralPath $currentUnknownCompiler) -cne $currentUnknown.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentUnknownManaged.inputHashes -LiteralPath $currentUnknownContractPath) -cne (Get-FileHash -LiteralPath $currentUnknownContractPath -Algorithm SHA256).Hash -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentUnknownPaired.inputHashes -LiteralPath $currentUnknownContractPath) -cne (Get-FileHash -LiteralPath $currentUnknownContractPath -Algorithm SHA256).Hash -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentUnknownPaired.inputHashes -LiteralPath $currentUnknownManagedPath) -cne (Get-FileHash -LiteralPath $currentUnknownManagedPath -Algorithm SHA256).Hash) {
    throw 'CURRENT_UNKNOWN_BINDING_IDENTITY_INVALID'
}
foreach ($entry in @(@{ proof = $currentUnknownManaged; mode = 'managed' }, @{ proof = $currentUnknownPaired; mode = 'paired' })) {
    $proof = $entry.proof
    if ($proof.status -cne 'passed' -or $proof.mode -cne $entry.mode -or
        $proof.completed -ne 13 -or $proof.total -ne 13 -or @($proof.cases).Count -ne 13 -or
        @($proof.cases.id | Sort-Object -Unique).Count -ne 13 -or
        -not $proof.inputsStable -or -not $proof.processesStopped) {
        throw 'CURRENT_UNKNOWN_BINDING_PROOF_INCOMPLETE'
    }
    foreach ($inputHash in $proof.inputHashes.PSObject.Properties) {
        if ((Get-FileHash -LiteralPath $inputHash.Name -Algorithm SHA256).Hash -cne $inputHash.Value) {
            throw "CURRENT_UNKNOWN_BINDING_INPUT_CHANGED: $($inputHash.Name)"
        }
    }
    foreach ($expectedCase in $currentUnknownContract.cases) {
        $observed = @($proof.cases | Where-Object id -ceq $expectedCase.id)
        if ($observed.Count -ne 1 -or $observed[0].status -cne 'passed' -or -not $observed[0].passed -or
            $observed[0].buildExit -ne $expectedCase.exit -or $observed[0].buildStderr -cne $expectedCase.stderr -or
            ($expectedCase.exit -eq 0 -and ($observed[0].runExit -ne 0 -or
                $observed[0].runStdout -cne $expectedCase.stdout -or $observed[0].runStderr -cne ''))) {
            throw "CURRENT_UNKNOWN_BINDING_EXACT_MISMATCH: $($expectedCase.id)"
        }
    }
}
Write-Host '[interpolation lexical scope] PASS current original13 exact managed/native behavior and shared resolver consumers'
$importedMethod = Get-Content -LiteralPath (Join-Path $root $contract.importedInstanceMethodEvidence) -Raw | ConvertFrom-Json
$importedBuild = Get-Content -LiteralPath (Join-Path $root $importedMethod.selfhostBuild) -Raw | ConvertFrom-Json
$importedPositive = Get-Content -LiteralPath (Join-Path $root $importedMethod.positivePair) -Raw | ConvertFrom-Json
$importedNegative = Get-Content -LiteralPath (Join-Path $root $importedMethod.unknownCallNegativePair) -Raw | ConvertFrom-Json
$importedExact = Get-Content -LiteralPath (Join-Path $root $importedMethod.unknownCallExactStderr) -Raw | ConvertFrom-Json
if ($importedMethod.status -cne 'focused-complete-phase-open' -or
    $importedBuild.status -cne 'passed' -or -not $importedBuild.inputsStable -or
    $importedBuild.compilerSha256 -cne $importedMethod.selfhostCompilerSha256 -or
    $importedPositive.status -cne 'passed' -or -not $importedPositive.inputStable -or
    $importedPositive.completed -ne 2 -or $importedPositive.total -ne 2 -or
    $importedNegative.state -cne 'passed' -or -not $importedNegative.inputsStable -or
    $importedNegative.selfhostCompilerSha256 -cne $importedMethod.selfhostCompilerSha256 -or
    $importedExact.status -cne 'passed' -or $importedExact.completed -ne 1 -or
    -not $semanticInference.Contains('public importedFlowCallTargets', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.importedFlowCallTargets', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('unknown value-flow target', [StringComparison]::Ordinal)) {
    throw 'imported interpolation method lacks current source and focused paired evidence'
}
$privateMethod = Get-Content -LiteralPath (Join-Path $root $contract.privateInstanceMethodEvidence) -Raw | ConvertFrom-Json
$privateManaged = Get-Content -LiteralPath (Join-Path $root $privateMethod.managedFirst) -Raw | ConvertFrom-Json
$privateBuild = Get-Content -LiteralPath (Join-Path $root $privateMethod.selfhostBuild) -Raw | ConvertFrom-Json
$privateNegative = Get-Content -LiteralPath (Join-Path $root $privateMethod.privateNegativePair) -Raw | ConvertFrom-Json
$privateExact = Get-Content -LiteralPath (Join-Path $root $privateMethod.privateExactStderr) -Raw | ConvertFrom-Json
$privateRetainedPositive = Get-Content -LiteralPath (Join-Path $root $privateMethod.retainedPositivePair) -Raw | ConvertFrom-Json
$privateRetainedUnknown = Get-Content -LiteralPath (Join-Path $root $privateMethod.retainedUnknownNegativePair) -Raw | ConvertFrom-Json
$privateRetainedExact = Get-Content -LiteralPath (Join-Path $root $privateMethod.retainedUnknownExactStderr) -Raw | ConvertFrom-Json
if ($privateMethod.status -cne 'focused-complete-phase-open' -or
    $privateManaged.status -cne 'managed-first-passed' -or $privateManaged.exitCode -ne 1 -or
    -not $privateManaged.noEmittedExecutable -or
    $privateBuild.status -cne 'passed' -or -not $privateBuild.inputsStable -or
    $privateBuild.compilerSha256 -cne $privateMethod.selfhostCompilerSha256 -or
    $privateNegative.state -cne 'passed' -or -not $privateNegative.inputsStable -or
    $privateNegative.selfhostCompilerSha256 -cne $privateMethod.selfhostCompilerSha256 -or
    $privateExact.status -cne 'passed' -or $privateExact.completed -ne 1 -or
    $privateRetainedPositive.status -cne 'passed' -or -not $privateRetainedPositive.inputStable -or
    $privateRetainedPositive.completed -ne 2 -or $privateRetainedPositive.total -ne 2 -or
    $privateRetainedUnknown.state -cne 'passed' -or -not $privateRetainedUnknown.inputsStable -or
    $privateRetainedExact.status -cne 'passed' -or $privateRetainedExact.completed -ne 1 -or
    -not $semanticInference.Contains('inaccessible! >= 0', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('is internal to module', [StringComparison]::Ordinal)) {
    throw 'private imported interpolation method lacks current source and focused paired evidence'
}
$precedence = Get-Content -LiteralPath (Join-Path $root $contract.instanceMethodPrecedenceEvidence) -Raw | ConvertFrom-Json
$precedenceManaged = Get-Content -LiteralPath (Join-Path $root $precedence.managedFirst) -Raw | ConvertFrom-Json
$precedenceComparison = Get-Content -LiteralPath (Join-Path $root $precedence.sourceComparison) -Raw | ConvertFrom-Json
$precedenceBuild = Get-Content -LiteralPath (Join-Path $root $precedence.selfhostBuild) -Raw | ConvertFrom-Json
$precedencePositive = Get-Content -LiteralPath (Join-Path $root $precedence.positivePair) -Raw | ConvertFrom-Json
$precedenceRetained = Get-Content -LiteralPath (Join-Path $root $precedence.retainedPositivePair) -Raw | ConvertFrom-Json
$precedenceUnknown = Get-Content -LiteralPath (Join-Path $root $precedence.unknownNegativePair) -Raw | ConvertFrom-Json
$precedencePrivate = Get-Content -LiteralPath (Join-Path $root $precedence.privateNegativePair) -Raw | ConvertFrom-Json
$precedenceExact = Get-Content -LiteralPath (Join-Path $root $precedence.negativeExact) -Raw | ConvertFrom-Json
$currentFoundation = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/foundation.slg'))
if ($precedence.status -cne 'focused-complete-phase-open' -or
    $precedence.focusedPassed -cne '5/5' -or
    $precedenceManaged.status -cne 'managed-first-passed' -or
    $precedenceManaged.stdout -cne 'value=7' -or
    $precedenceComparison.status -cne 'source-aligned-focused-complete' -or
    $precedenceComparison.semanticPhaseClosed -or
    $precedenceBuild.status -cne 'passed' -or -not $precedenceBuild.inputsStable -or
    $precedenceBuild.compilerSha256 -cne $precedence.selfhostCompilerSha256 -or
    $precedencePositive.status -cne 'passed' -or -not $precedencePositive.inputStable -or
    $precedencePositive.completed -ne 1 -or $precedencePositive.total -ne 1 -or
    $precedenceRetained.status -cne 'passed' -or -not $precedenceRetained.inputStable -or
    $precedenceRetained.completed -ne 2 -or $precedenceRetained.total -ne 2 -or
    $precedenceUnknown.state -cne 'passed' -or -not $precedenceUnknown.inputsStable -or
    $precedencePrivate.state -cne 'passed' -or -not $precedencePrivate.inputsStable -or
    $precedenceUnknown.selfhostCompilerSha256 -cne $precedence.selfhostCompilerSha256 -or
    $precedencePrivate.selfhostCompilerSha256 -cne $precedence.selfhostCompilerSha256 -or
    -not $semanticInference.Contains('instanceMethod!', [StringComparison]::Ordinal) -or
    -not $currentFoundation.Contains('interpolationRange.nodeStart + nodeIndex', [StringComparison]::Ordinal) -or
    -not $currentFoundation.Contains('(nodes -> len) != (context.interpolations -> len)', [StringComparison]::Ordinal)) {
    throw 'instance method precedence or interpolation index boundary lacks current source and paired evidence'
}
Assert-ExactStderrReport $precedenceExact 2 $precedence.selfhostCompilerSha256
$directEach = Get-Content -LiteralPath (Join-Path $root $contract.directEachRoleDisplayEvidence) -Raw | ConvertFrom-Json
$directEachManaged = Get-Content -LiteralPath (Join-Path $root $directEach.managedFirst) -Raw | ConvertFrom-Json
$directEachComparison = Get-Content -LiteralPath (Join-Path $root $directEach.sourceComparison) -Raw | ConvertFrom-Json
$directEachBaseline = Get-Content -LiteralPath (Join-Path $root $directEach.baseline) -Raw | ConvertFrom-Json
$directEachBuild = Get-Content -LiteralPath (Join-Path $root $directEach.selfhostBuild) -Raw | ConvertFrom-Json
$directEachNegative = Get-Content -LiteralPath (Join-Path $root $directEach.negativePair) -Raw | ConvertFrom-Json
$directEachExact = Get-Content -LiteralPath (Join-Path $root $directEach.negativeExact) -Raw | ConvertFrom-Json
$directEachPositive = Get-Content -LiteralPath (Join-Path $root $directEach.positivePair) -Raw | ConvertFrom-Json
$directEachRetainedPositive = Get-Content -LiteralPath (Join-Path $root $directEach.retainedPositivePair) -Raw | ConvertFrom-Json
$directEachRetainedUnknown = Get-Content -LiteralPath (Join-Path $root $directEach.retainedUnknownNegative) -Raw | ConvertFrom-Json
$directEachRetainedPrivate = Get-Content -LiteralPath (Join-Path $root $directEach.retainedPrivateNegative) -Raw | ConvertFrom-Json
$directEachRetainedExact = Get-Content -LiteralPath (Join-Path $root $directEach.retainedC531Exact) -Raw | ConvertFrom-Json
$directEachFloat = Get-Content -LiteralPath (Join-Path $root $directEach.retainedDisplayNegative) -Raw | ConvertFrom-Json
$directEachFloatExact = Get-Content -LiteralPath (Join-Path $root $directEach.retainedDisplayExact) -Raw | ConvertFrom-Json
$directEachCompiler = Join-Path (Split-Path -Parent (Join-Path $root $directEach.selfhostBuild)) 'compiler.exe'
if ($directEach.status -cne 'focused-complete-phase-open' -or
    $directEach.focusedPassed -cne '8/8' -or $directEach.semanticOwnedKindsComplete -cne '3/12' -or
    $directEachManaged.status -cne 'managed-first-passed' -or $directEachManaged.exitCode -ne 1 -or
    -not $directEachManaged.noEmittedExecutable -or
    $directEachComparison.status -cne 'source-aligned-focused-complete' -or
    $directEachComparison.semanticPhaseClosed -or
    $directEachBaseline.failureId -cne 'NEGATIVE_CHECK_FAILED' -or
    -not $directEachBaseline.inputsStable -or $directEachBaseline.selfhost.expectedInStderr -or
    $directEachBuild.status -cne 'passed' -or -not $directEachBuild.inputsStable -or
    $directEachBuild.compilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $directEachCompiler -Algorithm SHA256).Hash -cne $directEach.selfhostCompilerSha256 -or
    $directEachNegative.state -cne 'passed' -or -not $directEachNegative.inputsStable -or
    $directEachPositive.status -cne 'passed' -or -not $directEachPositive.inputStable -or
    $directEachPositive.completed -ne 1 -or $directEachPositive.total -ne 1 -or
    $directEachRetainedPositive.status -cne 'passed' -or -not $directEachRetainedPositive.inputStable -or
    $directEachRetainedPositive.completed -ne 3 -or $directEachRetainedPositive.total -ne 3 -or
    $directEachRetainedUnknown.state -cne 'passed' -or -not $directEachRetainedUnknown.inputsStable -or
    $directEachRetainedPrivate.state -cne 'passed' -or -not $directEachRetainedPrivate.inputsStable -or
    $directEachFloat.state -cne 'passed' -or -not $directEachFloat.inputsStable -or
    $directEachNegative.selfhostCompilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    $directEachRetainedUnknown.selfhostCompilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    $directEachRetainedPrivate.selfhostCompilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    $directEachFloat.selfhostCompilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    -not $semanticTypeIds.Contains('directEachRoleTypeBySymbol: [Int; ~]', [StringComparison]::Ordinal) -or
    -not $semanticTypeIds.Contains('directEachSourceExpressionByAst![range.astStart + scope.astNode]', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('bindingFacts.interpolationLexicalTypeByNode[nodeIndex] -> return', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('syntaxDiagnostics.sourceLocation(stringToken.span.start)', [StringComparison]::Ordinal)) {
    throw 'direct each interpolation role lacks current semantic type, exact diagnostic, or retained paired evidence'
}
Assert-ExactStderrReport $directEachExact 1 $directEach.selfhostCompilerSha256
Assert-ExactStderrReport $directEachRetainedExact 2 $directEach.selfhostCompilerSha256
Assert-ExactStderrReport $directEachFloatExact 1 $directEach.selfhostCompilerSha256
$notUnit = Get-Content -LiteralPath (Join-Path $root $contract.interpolationNotEvidence) -Raw | ConvertFrom-Json
$notComparison = Get-Content -LiteralPath (Join-Path $root $notUnit.sourceComparison) -Raw | ConvertFrom-Json
$notBuild = Get-Content -LiteralPath (Join-Path $root $notUnit.selfhostBuild) -Raw | ConvertFrom-Json
$notNegative = Get-Content -LiteralPath (Join-Path $root $notUnit.negativePair) -Raw | ConvertFrom-Json
$notExact = Get-Content -LiteralPath (Join-Path $root $notUnit.negativeExact) -Raw | ConvertFrom-Json
$notPositive = Get-Content -LiteralPath (Join-Path $root $notUnit.positivePair) -Raw | ConvertFrom-Json
$notRetained = Get-Content -LiteralPath (Join-Path $root $notUnit.retainedNegativePair) -Raw | ConvertFrom-Json
$notCompiler = Join-Path (Split-Path -Parent (Join-Path $root $notUnit.selfhostBuild)) 'compiler.exe'
if ($notUnit.status -cne 'passed' -or $notUnit.focusedPassed -cne '2/2' -or
    $notUnit.semanticOwnedKindsComplete -cne '3/12' -or
    $notComparison.status -cne 'source-aligned-focused-complete' -or $notComparison.semanticPhaseClosed -or
    $notBuild.status -cne 'passed' -or -not $notBuild.inputsStable -or
    $notBuild.compilerSha256 -cne $notUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $notCompiler -Algorithm SHA256).Hash -cne $notUnit.selfhostCompilerSha256 -or
    $notNegative.state -cne 'passed' -or -not $notNegative.inputsStable -or
    $notNegative.managedCompilerSha256 -cne $notUnit.managedCompilerSha256 -or
    $notNegative.selfhostCompilerSha256 -cne $notUnit.selfhostCompilerSha256 -or
    $notPositive.status -cne 'passed' -or -not $notPositive.inputStable -or
    $notPositive.completed -ne 1 -or $notPositive.total -ne 1 -or
    $notRetained.state -cne 'passed' -or -not $notRetained.inputsStable -or
    $notRetained.selfhostCompilerSha256 -cne $notUnit.selfhostCompilerSha256 -or
    -not $semanticInference.Contains('public invalidNotUnaryByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.invalidNotUnaryByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains("'not' expects Bool", [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('isBlockingInvalidNotInterpolation', [StringComparison]::Ordinal)) {
    throw 'interpolation not operand lacks C# first, semantic ownership, exact negative, or retained paired evidence'
}
Assert-ExactStderrReport $notExact 1 $notUnit.selfhostCompilerSha256
$negateUnit = Get-Content -LiteralPath (Join-Path $root $contract.interpolationNegateNominalEvidence) -Raw | ConvertFrom-Json
$negateComparison = Get-Content -LiteralPath (Join-Path $root $negateUnit.sourceComparison) -Raw | ConvertFrom-Json
$negateBuild = Get-Content -LiteralPath (Join-Path $root $negateUnit.selfhostBuild) -Raw | ConvertFrom-Json
$negateNegative = Get-Content -LiteralPath (Join-Path $root $negateUnit.negativePair) -Raw | ConvertFrom-Json
$negateExact = Get-Content -LiteralPath (Join-Path $root $negateUnit.negativeExact) -Raw | ConvertFrom-Json
$negatePositive = Get-Content -LiteralPath (Join-Path $root $negateUnit.retainedPositivePair) -Raw | ConvertFrom-Json
$negateBaseline = Get-Content -LiteralPath (Join-Path $root $negateUnit.baselineSelfhost) -Raw
$negateManaged = Get-Content -LiteralPath (Join-Path $root $negateUnit.managedFirst) -Raw
$negateCompiler = Join-Path (Split-Path -Parent (Join-Path $root $negateUnit.selfhostBuild)) 'compiler.exe'
if ($negateUnit.status -cne 'passed' -or $negateUnit.focusedPassed -cne '2/2' -or
    $negateUnit.semanticOwnedKindsComplete -cne '3/12' -or
    $negateComparison.status -cne 'source-aligned-focused-complete' -or $negateComparison.semanticPhaseClosed -or
    -not $negateManaged.Contains("operand of unary '-' must be a signed numeric value", [StringComparison]::Ordinal) -or
    -not $negateBaseline.Contains('expected ''i32''', [StringComparison]::Ordinal) -or
    $negateBuild.status -cne 'passed' -or -not $negateBuild.inputsStable -or
    $negateBuild.compilerSha256 -cne $negateUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $negateCompiler -Algorithm SHA256).Hash -cne $negateUnit.selfhostCompilerSha256 -or
    $negateNegative.state -cne 'passed' -or -not $negateNegative.inputsStable -or
    $negateNegative.managedCompilerSha256 -cne $negateUnit.managedCompilerSha256 -or
    $negateNegative.selfhostCompilerSha256 -cne $negateUnit.selfhostCompilerSha256 -or
    $negatePositive.status -cne 'passed' -or -not $negatePositive.inputStable -or
    $negatePositive.completed -ne 1 -or $negatePositive.total -ne 1 -or
    -not $semanticInference.Contains('operandType.kind == 1 and operandType.origin == 1', [StringComparison]::Ordinal)) {
    throw 'interpolation negate nominal lacks C# first, source comparison, exact negative, or signed positive evidence'
}
Assert-ExactStderrReport $negateExact 1 $negateUnit.selfhostCompilerSha256
$lengthUnit = Get-Content -LiteralPath (Join-Path $root $contract.intrinsicLengthEvidence) -Raw | ConvertFrom-Json
$lengthComparison = Get-Content -LiteralPath (Join-Path $root $lengthUnit.sourceComparison) -Raw | ConvertFrom-Json
$lengthBuild = Get-Content -LiteralPath (Join-Path $root $lengthUnit.selfhostBuild) -Raw | ConvertFrom-Json
$lengthPositive = Get-Content -LiteralPath (Join-Path $root $lengthUnit.positivePair) -Raw | ConvertFrom-Json
$lengthNegative = Get-Content -LiteralPath (Join-Path $root $lengthUnit.negativePair) -Raw | ConvertFrom-Json
$lengthExact = Get-Content -LiteralPath (Join-Path $root $lengthUnit.negativeExact) -Raw | ConvertFrom-Json
$lengthManagedPositive = Get-Content -LiteralPath (Join-Path $root $lengthUnit.managedPositive) -Raw
$lengthManagedNegative = Get-Content -LiteralPath (Join-Path $root $lengthUnit.managedNegative) -Raw
$lengthBaseline = Get-Content -LiteralPath (Join-Path $root $lengthUnit.baselineSelfhost) -Raw
$lengthCompiler = Join-Path (Split-Path -Parent (Join-Path $root $lengthUnit.selfhostBuild)) 'compiler.exe'
if ($lengthUnit.status -cne 'passed' -or $lengthUnit.focusedPassed -cne '2/2' -or
    $lengthUnit.semanticOwnedKindsComplete -cne '3/12' -or
    $lengthComparison.status -cne 'source-aligned-focused-complete' -or $lengthComparison.semanticPhaseClosed -or
    $lengthManagedPositive.Trim() -cne 'value=-2' -or
    -not $lengthManagedNegative.Contains("operand of unary '-' must be a signed numeric value", [StringComparison]::Ordinal) -or
    -not $lengthBaseline.Contains("operand of unary '-' must be a signed numeric value", [StringComparison]::Ordinal) -or
    $lengthBuild.status -cne 'passed' -or -not $lengthBuild.inputsStable -or
    $lengthBuild.compilerSha256 -cne $lengthUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $lengthCompiler -Algorithm SHA256).Hash -cne $lengthUnit.selfhostCompilerSha256 -or
    $lengthPositive.status -cne 'passed' -or -not $lengthPositive.inputStable -or
    $lengthPositive.completed -ne 1 -or $lengthPositive.total -ne 1 -or
    $lengthNegative.state -cne 'passed' -or -not $lengthNegative.inputsStable -or
    $lengthNegative.managedCompilerSha256 -cne $lengthUnit.managedCompilerSha256 -or
    $lengthNegative.selfhostCompilerSha256 -cne $lengthUnit.selfhostCompilerSha256 -or
    -not $semanticInference.Contains('public intrinsicFlowResultBuiltinByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.intrinsicFlowResultBuiltinByNode', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('public flowResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.flowResultTypeByNode(streamPlan, recursiveTypes!, ir!, semanticTypes!, semanticFields!)', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationFlowTypeByNode: flowResultTypeByNode', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('context.interpolationFlowTypeByNode[semanticIndex] => typeId!', [StringComparison]::Ordinal)) {
    throw 'receiver-dependent interpolation len type lacks C# first, semantic source, native positive, or exact negative proof'
}
Assert-ExactStderrReport $lengthExact 1 $lengthUnit.selfhostCompilerSha256
$capacityUnit = Get-Content -LiteralPath (Join-Path $root $contract.intrinsicCapacityEvidence) -Raw | ConvertFrom-Json
$capacityComparison = Get-Content -LiteralPath (Join-Path $root $capacityUnit.sourceComparison) -Raw | ConvertFrom-Json
$capacityBuild = Get-Content -LiteralPath (Join-Path $root $capacityUnit.selfhostBuild) -Raw | ConvertFrom-Json
$capacityPositive = Get-Content -LiteralPath (Join-Path $root $capacityUnit.positivePair) -Raw | ConvertFrom-Json
$capacityNegative = Get-Content -LiteralPath (Join-Path $root $capacityUnit.negativePair) -Raw | ConvertFrom-Json
$capacityExact = Get-Content -LiteralPath (Join-Path $root $capacityUnit.negativeExact) -Raw | ConvertFrom-Json
$capacityManagedPositive = Get-Content -LiteralPath (Join-Path $root $capacityUnit.managedPositive) -Raw
$capacityManagedNegative = Get-Content -LiteralPath (Join-Path $root $capacityUnit.managedNegative) -Raw
$capacityBaseline = Get-Content -LiteralPath (Join-Path $root $capacityUnit.baselineSelfhost) -Raw
$capacityCompiler = Join-Path (Split-Path -Parent (Join-Path $root $capacityUnit.selfhostBuild)) 'compiler.exe'
if ($capacityUnit.status -cne 'passed' -or $capacityUnit.focusedPassed -cne '2/2' -or
    $capacityUnit.semanticOwnedKindsComplete -cne '3/12' -or
    $capacityComparison.status -cne 'source-aligned-focused-complete' -or $capacityComparison.semanticPhaseClosed -or
    $capacityManagedPositive.Trim() -cne 'value=-2' -or
    -not $capacityManagedNegative.Contains("operand of unary '-' must be a signed numeric value", [StringComparison]::Ordinal) -or
    -not $capacityBaseline.Contains("operand of unary '-' must be a signed numeric value", [StringComparison]::Ordinal) -or
    $capacityBuild.status -cne 'passed' -or -not $capacityBuild.inputsStable -or
    $capacityBuild.compilerSha256 -cne $capacityUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $capacityCompiler -Algorithm SHA256).Hash -cne $capacityUnit.selfhostCompilerSha256 -or
    $capacityPositive.status -cne 'passed' -or -not $capacityPositive.inputStable -or
    $capacityPositive.completed -ne 1 -or $capacityPositive.total -ne 1 -or
    $capacityNegative.state -cne 'passed' -or -not $capacityNegative.inputsStable -or
    $capacityNegative.managedCompilerSha256 -cne $capacityUnit.managedCompilerSha256 -or
    $capacityNegative.selfhostCompilerSha256 -cne $capacityUnit.selfhostCompilerSha256 -or
    -not $semanticInference.Contains('flow.opcode -> typeIds.collectionFlowResultBuiltinSymbol(types[receiverValueTypeId])', [StringComparison]::Ordinal) -or
    -not $collectionTypeIds.Contains('public collectionFlowResultBuiltinSymbol', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('node.opcode == -101 -> if {', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('node.opcode == -236 -> if {', [StringComparison]::Ordinal)) {
    throw 'receiver-dependent interpolation capacity type lacks C# first, semantic source, native positive, or exact negative proof'
}
Assert-ExactStderrReport $capacityExact 1 $capacityUnit.selfhostCompilerSha256
$textUnit = Get-Content -LiteralPath (Join-Path $root $contract.textIntrinsicIndexEvidence) -Raw | ConvertFrom-Json
$textComparison = Get-Content -LiteralPath (Join-Path $root $textUnit.sourceComparison) -Raw | ConvertFrom-Json
$textBuild = Get-Content -LiteralPath (Join-Path $root $textUnit.selfhostBuild) -Raw | ConvertFrom-Json
$textPositive = Get-Content -LiteralPath (Join-Path $root $textUnit.positivePair) -Raw | ConvertFrom-Json
$textExact = Get-Content -LiteralPath (Join-Path $root $textUnit.negativeExact) -Raw | ConvertFrom-Json
$textCompiler = Join-Path (Split-Path -Parent (Join-Path $root $textUnit.selfhostBuild)) 'compiler.exe'
if ($textUnit.status -cne 'passed' -or $textUnit.focusedPassed -cne '3/3' -or
    $textComparison.status -cne 'source-aligned-focused-complete' -or $textComparison.semanticPhaseClosed -or
    $textBuild.status -cne 'passed' -or -not $textBuild.inputsStable -or
    $textBuild.compilerSha256 -cne $textUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $textCompiler -Algorithm SHA256).Hash -cne $textUnit.selfhostCompilerSha256 -or
    $textPositive.status -cne 'passed' -or -not $textPositive.inputStable -or
    $textPositive.completed -ne 3 -or $textPositive.total -ne 3 -or
    -not $semanticInference.Contains('public invalidTextIntrinsicArgumentByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.invalidTextIntrinsicArgumentByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.invalidTextIntrinsicArgumentByNode', [StringComparison]::Ordinal)) {
    throw 'Text byte/slice interpolation index types lack C# first, semantic source, positive, or negative proof'
}
foreach ($receiptPath in $textUnit.negativePair) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.managedCompilerSha256 -cne $textUnit.managedCompilerSha256 -or
        $receipt.selfhostCompilerSha256 -cne $textUnit.selfhostCompilerSha256) {
        throw "Text byte/slice negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $textExact 2 $textUnit.selfhostCompilerSha256
$shellUnit = Get-Content -LiteralPath (Join-Path $root $contract.nestedConversionShellEvidence) -Raw | ConvertFrom-Json
$shellComparison = Get-Content -LiteralPath (Join-Path $root $shellUnit.sourceComparison) -Raw | ConvertFrom-Json
$shellBaseline = Get-Content -LiteralPath (Join-Path $root $shellUnit.baselineSelfhost) -Raw | ConvertFrom-Json
$shellBuild = Get-Content -LiteralPath (Join-Path $root $shellUnit.selfhostBuild) -Raw | ConvertFrom-Json
$shellPositive = Get-Content -LiteralPath (Join-Path $root $shellUnit.positivePair) -Raw | ConvertFrom-Json
$shellExpected = Get-Content -LiteralPath (Join-Path $root 'examples/regression/expected/1916-selfhost-nested-conversion-ir.stdout.txt') -Raw
$shellActual = Get-Content -LiteralPath (Join-Path $root 'artifacts/scratch/c538-nested-conversion-positive-pair-20260927-01/1916-selfhost-nested-conversion-ir.selfhost.native.stdout.txt') -Raw
if ($shellUnit.status -cne 'passed' -or $shellUnit.focusedPassed -cne '3/3' -or
    $shellComparison.status -cne 'source-aligned-focused-complete' -or $shellComparison.semanticPhaseClosed -or
    $shellBaseline.status -cne 'failed' -or $shellBaseline.inputStable -cne $true -or
    $shellBuild.status -cne 'passed' -or -not $shellBuild.inputsStable -or
    $shellBuild.compilerSha256 -cne $shellUnit.selfhostCompilerSha256 -or
    $shellPositive.status -cne 'passed' -or -not $shellPositive.inputStable -or
    $shellPositive.completed -ne 3 -or $shellPositive.total -ne 3 -or
    $shellActual.Replace("`r`n", "`n") -cne $shellExpected.Replace("`r`n", "`n") -or
    -not $interpolationLowering.Contains('flowTarget.kind == 11 and flowTarget.start == fragmentNode.start', [StringComparison]::Ordinal)) {
    throw 'nested conversion shell lacks source-aligned node topology and paired control proof'
}
$arityUnit = Get-Content -LiteralPath (Join-Path $root $contract.textIntrinsicArityEvidence) -Raw | ConvertFrom-Json
$arityComparison = Get-Content -LiteralPath (Join-Path $root $arityUnit.sourceComparison) -Raw | ConvertFrom-Json
$arityBuild = Get-Content -LiteralPath (Join-Path $root $arityUnit.selfhostBuild) -Raw | ConvertFrom-Json
$arityPositive = Get-Content -LiteralPath (Join-Path $root $arityUnit.positivePair) -Raw | ConvertFrom-Json
$arityPriorControls = Get-Content -LiteralPath (Join-Path $root $arityUnit.priorCandidateStructuralControls) -Raw | ConvertFrom-Json
$arityExact = Get-Content -LiteralPath (Join-Path $root $arityUnit.negativeExact) -Raw | ConvertFrom-Json
$arityRetained = Get-Content -LiteralPath (Join-Path $root $arityUnit.retainedTypeExact) -Raw | ConvertFrom-Json
$arityCompiler = Join-Path (Split-Path -Parent (Join-Path $root $arityUnit.selfhostBuild)) 'compiler.exe'
$arityExpected = Get-Content -LiteralPath (Join-Path $root 'examples/regression/expected/1922-selfhost-text-intrinsic-argument-count-ir.stdout.txt') -Raw
$arityActual = Get-Content -LiteralPath (Join-Path $root 'artifacts/scratch/c539-text-intrinsic-arity-positive-pair-20260927-01/1922-selfhost-text-intrinsic-argument-count-ir.selfhost.native.stdout.txt') -Raw
if ($arityUnit.status -cne 'passed' -or $arityUnit.focusedPassed -cne '5/5' -or
    $arityComparison.status -cne 'source-aligned-focused-complete' -or $arityComparison.semanticPhaseClosed -or
    $arityBuild.status -cne 'passed' -or -not $arityBuild.inputsStable -or
    $arityBuild.compilerSha256 -cne $arityUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $arityCompiler -Algorithm SHA256).Hash -cne $arityUnit.selfhostCompilerSha256 -or
    $arityPositive.status -cne 'passed' -or -not $arityPositive.inputStable -or
    $arityPositive.completed -ne 1 -or $arityPositive.total -ne 1 -or
    $arityPriorControls.status -cne 'passed' -or -not $arityPriorControls.inputStable -or
    $arityPriorControls.completed -ne 4 -or $arityPriorControls.total -ne 4 -or
    $arityActual.Replace("`r`n", "`n") -cne $arityExpected.Replace("`r`n", "`n") -or
    -not $interpolationLowering.Contains('argumentCount: loweredArgumentCount!', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('public invalidIntrinsicFlowArityByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.invalidIntrinsicFlowArityByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('semanticDiagnostics.interpolationCallTargetLocation(context.sources[sourceModule], nodeIndex!)', [StringComparison]::Ordinal)) {
    throw 'Text byte/slice intrinsic arity lacks source, semantic ownership, exact diagnostic, or paired runtime proof'
}
foreach ($baselinePath in $arityUnit.baselineSelfhost) {
    $baseline = Get-Content -LiteralPath (Join-Path $root $baselinePath) -Raw | ConvertFrom-Json
    if ($baseline.failureId -cne 'NEGATIVE_CHECK_FAILED' -or $baseline.selfhost.expectedInStderr) {
        throw "Text intrinsic arity baseline did not reproduce mismatch: $baselinePath"
    }
}
foreach ($receiptPath in $arityUnit.negativePair) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.managedCompilerSha256 -cne $arityUnit.managedCompilerSha256 -or
        $receipt.selfhostCompilerSha256 -cne $arityUnit.selfhostCompilerSha256) {
        throw "Text intrinsic arity negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $arityExact 4 $arityUnit.selfhostCompilerSha256
Assert-ExactStderrReport $arityRetained 2 $arityUnit.selfhostCompilerSha256

$receiverUnit = Get-Content -LiteralPath (Join-Path $root $contract.textIntrinsicReceiverEvidence) -Raw | ConvertFrom-Json
$receiverComparison = Get-Content -LiteralPath (Join-Path $root $receiverUnit.sourceComparison) -Raw | ConvertFrom-Json
$receiverBuild = Get-Content -LiteralPath (Join-Path $root $receiverUnit.selfhostBuild) -Raw | ConvertFrom-Json
$receiverPositive = Get-Content -LiteralPath (Join-Path $root $receiverUnit.positivePair) -Raw | ConvertFrom-Json
$receiverRetainedPositive = Get-Content -LiteralPath (Join-Path $root $receiverUnit.retainedPositivePair) -Raw | ConvertFrom-Json
$receiverSourceTextPositive = Get-Content -LiteralPath (Join-Path $root $receiverUnit.sourceTextPositivePair) -Raw | ConvertFrom-Json
$receiverExact = Get-Content -LiteralPath (Join-Path $root $receiverUnit.negativeExact) -Raw | ConvertFrom-Json
$receiverRetainedExact = Get-Content -LiteralPath (Join-Path $root $receiverUnit.retainedExact) -Raw | ConvertFrom-Json
$receiverCompiler = Join-Path (Split-Path -Parent (Join-Path $root $receiverUnit.selfhostBuild)) 'compiler.exe'
if ($receiverUnit.status -cne 'passed' -or $receiverUnit.focusedPassed -cne '3/3' -or
    $receiverUnit.retainedPassed -cne '4/4' -or
    $receiverComparison.status -cne 'source-compared-implemented-focused-passed' -or $receiverComparison.semanticPhaseClosed -or
    $receiverBuild.status -cne 'passed' -or -not $receiverBuild.inputsStable -or
    $receiverBuild.compilerSha256 -cne $receiverUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $receiverCompiler -Algorithm SHA256).Hash -cne $receiverUnit.selfhostCompilerSha256 -or
    $receiverPositive.status -cne 'passed' -or -not $receiverPositive.inputStable -or
    $receiverPositive.completed -ne 1 -or $receiverPositive.total -ne 1 -or
    $receiverRetainedPositive.status -cne 'passed' -or -not $receiverRetainedPositive.inputStable -or
    $receiverRetainedPositive.completed -ne 1 -or $receiverRetainedPositive.total -ne 1 -or
    $receiverSourceTextPositive.status -cne 'passed' -or -not $receiverSourceTextPositive.inputStable -or
    $receiverSourceTextPositive.completed -ne 1 -or $receiverSourceTextPositive.total -ne 1 -or
    -not $semanticInference.Contains('public classifyIntrinsicFlowReceivers', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.classifyIntrinsicFlowReceivers', [StringComparison]::Ordinal)) {
    throw 'Text byte/slice receiver dispatch lacks source, semantic, or paired runtime proof'
}
foreach ($receiptPath in @($receiverUnit.negativePair) + @($receiverUnit.retainedNegativePair)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.managedCompilerSha256 -cne $receiverUnit.managedCompilerSha256 -or
        $receipt.selfhostCompilerSha256 -cne $receiverUnit.selfhostCompilerSha256) {
        throw "Text intrinsic receiver negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $receiverExact 2 $receiverUnit.selfhostCompilerSha256
Assert-ExactStderrReport $receiverRetainedExact 2 $receiverUnit.selfhostCompilerSha256

$containerUnit = Get-Content -LiteralPath (Join-Path $root $contract.containerIntrinsicReceiverEvidence) -Raw | ConvertFrom-Json
$containerComparison = Get-Content -LiteralPath (Join-Path $root $containerUnit.sourceComparison) -Raw | ConvertFrom-Json
$containerBuild = Get-Content -LiteralPath (Join-Path $root $containerUnit.selfhostBuild) -Raw | ConvertFrom-Json
$containerPositive = Get-Content -LiteralPath (Join-Path $root $containerUnit.positivePair) -Raw | ConvertFrom-Json
$containerRetained = Get-Content -LiteralPath (Join-Path $root $containerUnit.retainedPositivePair) -Raw | ConvertFrom-Json
$containerExact = Get-Content -LiteralPath (Join-Path $root $containerUnit.negativeExact) -Raw | ConvertFrom-Json
$containerCompiler = Join-Path (Split-Path -Parent (Join-Path $root $containerUnit.selfhostBuild)) 'compiler.exe'
if ($containerUnit.status -cne 'passed' -or $containerUnit.focusedPassed -cne '3/3' -or
    $containerUnit.retainedPassed -cne '5/5' -or
    $containerComparison.status -cne 'source-compared-implemented-focused-passed' -or $containerComparison.semanticPhaseClosed -or
    $containerBuild.status -cne 'passed' -or -not $containerBuild.inputsStable -or
    $containerBuild.compilerSha256 -cne $containerUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $containerCompiler -Algorithm SHA256).Hash -cne $containerUnit.selfhostCompilerSha256 -or
    $containerPositive.status -cne 'passed' -or -not $containerPositive.inputStable -or
    $containerPositive.completed -ne 1 -or $containerPositive.total -ne 1 -or
    $containerRetained.status -cne 'passed' -or -not $containerRetained.inputStable -or
    $containerRetained.completed -ne 5 -or $containerRetained.total -ne 5 -or
    -not $semanticInference.Contains('intrinsicFlowReceiverSupported', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('node.opcode -> intrinsicFlowReceiverSupported(receiverType)', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.intrinsicFlowResultBuiltinByNode(streamPlan, recursiveTypes!, analysisInterpolations,', [StringComparison]::Ordinal)) {
    throw 'len/capacity receiver dispatch lacks source, semantic, or paired runtime proof'
}
foreach ($receiptPath in $containerUnit.negativePair) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.managedCompilerSha256 -cne $containerUnit.managedCompilerSha256 -or
        $receipt.selfhostCompilerSha256 -cne $containerUnit.selfhostCompilerSha256) {
        throw "len/capacity receiver negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $containerExact 2 $containerUnit.selfhostCompilerSha256

$containerArity = Get-Content -LiteralPath (Join-Path $root $contract.containerIntrinsicArityEvidence) -Raw | ConvertFrom-Json
$containerArityComparison = Get-Content -LiteralPath (Join-Path $root $containerArity.sourceComparison) -Raw | ConvertFrom-Json
$containerArityBuild = Get-Content -LiteralPath (Join-Path $root $containerArity.selfhostBuild) -Raw | ConvertFrom-Json
$containerArityPositive = Get-Content -LiteralPath (Join-Path $root $containerArity.retainedPositivePair) -Raw | ConvertFrom-Json
$containerArityExact = Get-Content -LiteralPath (Join-Path $root $containerArity.negativeExact) -Raw | ConvertFrom-Json
$containerArityCompiler = Join-Path (Split-Path -Parent (Join-Path $root $containerArity.selfhostBuild)) 'compiler.exe'
if ($containerArity.status -cne 'passed' -or $containerArity.focusedPassed -cne '2/2' -or
    $containerArity.retainedNegativePassed -cne '4/4' -or $containerArity.retainedPositivePassed -cne '6/6' -or
    $containerArityComparison.status -cne 'source-compared-implemented-focused-passed' -or $containerArityComparison.semanticPhaseClosed -or
    $containerArityBuild.status -cne 'passed' -or -not $containerArityBuild.inputsStable -or
    $containerArityBuild.compilerSha256 -cne $containerArity.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $containerArityCompiler -Algorithm SHA256).Hash -cne $containerArity.selfhostCompilerSha256 -or
    $containerArityPositive.status -cne 'passed' -or -not $containerArityPositive.inputStable -or
    $containerArityPositive.completed -ne 6 -or $containerArityPositive.total -ne 6 -or
    -not $interpolationLowering.Contains('or intrinsicFlowOpcode! == -101 or intrinsicFlowOpcode! == -236', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('public invalidIntrinsicFlowArityByNode', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('node.argumentCount != 0', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('len does not accept arguments', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('capacity does not accept arguments', [StringComparison]::Ordinal)) {
    throw 'len/capacity arity-first decision lacks IR, semantic, diagnostic, or paired runtime proof'
}
foreach ($receiptPath in @($containerArity.negativePair) + @($containerArity.retainedNegativePair)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.managedCompilerSha256 -cne $containerArity.managedCompilerSha256 -or
        $receipt.selfhostCompilerSha256 -cne $containerArity.selfhostCompilerSha256) {
        throw "len/capacity arity negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $containerArityExact 6 $containerArity.selfhostCompilerSha256

$bitSetCount = Get-Content -LiteralPath (Join-Path $root $contract.bitSetCountEvidence) -Raw | ConvertFrom-Json
$bitSetComparison = Get-Content -LiteralPath (Join-Path $root $bitSetCount.sourceComparison) -Raw | ConvertFrom-Json
$bitSetBaseline = Get-Content -LiteralPath (Join-Path $root $bitSetCount.baselineSelfhost) -Raw | ConvertFrom-Json
$bitSetBuild = Get-Content -LiteralPath (Join-Path $root $bitSetCount.selfhostBuild) -Raw | ConvertFrom-Json
$bitSetPositive = Get-Content -LiteralPath (Join-Path $root $bitSetCount.positivePair) -Raw | ConvertFrom-Json
$bitSetControls = Get-Content -LiteralPath (Join-Path $root $bitSetCount.positiveAndRetainedPair) -Raw | ConvertFrom-Json
$bitSetNegative = Get-Content -LiteralPath (Join-Path $root $bitSetCount.negativePair) -Raw | ConvertFrom-Json
$bitSetExact = Get-Content -LiteralPath (Join-Path $root $bitSetCount.negativeExact) -Raw | ConvertFrom-Json
$bitSetCompiler = Join-Path (Split-Path -Parent (Join-Path $root $bitSetCount.selfhostBuild)) 'compiler.exe'
if ($bitSetCount.status -cne 'passed' -or $bitSetCount.focusedPassed -cne '4/4' -or
    $bitSetCount.retainedPassed -cne '1/1' -or
    $bitSetComparison.status -cne 'source-compared-implemented-focused-passed' -or $bitSetComparison.semanticPhaseClosed -or
    $bitSetBaseline.status -cne 'failed' -or
    $bitSetBuild.status -cne 'passed' -or -not $bitSetBuild.inputsStable -or
    $bitSetBuild.compilerSha256 -cne $bitSetCount.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $bitSetCompiler -Algorithm SHA256).Hash -cne $bitSetCount.selfhostCompilerSha256 -or
    $bitSetPositive.status -cne 'passed' -or -not $bitSetPositive.inputStable -or
    $bitSetPositive.completed -ne 1 -or $bitSetPositive.total -ne 1 -or
    $bitSetControls.status -cne 'passed' -or -not $bitSetControls.inputStable -or
    $bitSetControls.completed -ne 3 -or $bitSetControls.total -ne 3 -or
    $bitSetNegative.state -cne 'passed' -or -not $bitSetNegative.inputsStable -or
    $bitSetNegative.selfhostCompilerSha256 -cne $bitSetCount.selfhostCompilerSha256 -or
    -not $interpolationLowering.Contains('-244 => intrinsicFlowOpcode!', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('opcode == -244', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('node.opcode == -244 -> if {', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('call i64 @llvm.ctpop.i64', [StringComparison]::Ordinal)) {
    throw 'BitSet count interpolation lacks C# source, typed receiver, LLVM popcount, or paired proof'
}
Assert-ExactStderrReport $bitSetExact 1 $bitSetCount.selfhostCompilerSha256

$bitSetReference = Get-Content -LiteralPath (Join-Path $root $contract.bitSetCountReferenceEvidence) -Raw | ConvertFrom-Json
$bitSetReferenceComparison = Get-Content -LiteralPath (Join-Path $root $bitSetReference.sourceComparison) -Raw | ConvertFrom-Json
$bitSetReferenceBaseline = Get-Content -LiteralPath (Join-Path $root $bitSetReference.baselineSelfhost) -Raw | ConvertFrom-Json
$bitSetReferenceBuild = Get-Content -LiteralPath (Join-Path $root $bitSetReference.selfhostBuild) -Raw | ConvertFrom-Json
$bitSetReferencePair = Get-Content -LiteralPath (Join-Path $root $bitSetReference.positivePair) -Raw | ConvertFrom-Json
$bitSetReferenceControls = Get-Content -LiteralPath (Join-Path $root $bitSetReference.retainedPositivePair) -Raw | ConvertFrom-Json
$bitSetReferenceNegative = Get-Content -LiteralPath (Join-Path $root $bitSetReference.retainedNegativePair) -Raw | ConvertFrom-Json
$bitSetReferenceExact = Get-Content -LiteralPath (Join-Path $root $bitSetReference.retainedNegativeExact) -Raw | ConvertFrom-Json
$bitSetReferenceCompiler = Join-Path (Split-Path -Parent (Join-Path $root $bitSetReference.selfhostBuild)) 'compiler.exe'
if ($bitSetReference.status -cne 'passed' -or $bitSetReference.focusedPassed -cne '1/1' -or
    $bitSetReference.retainedPassed -cne '5/5' -or
    $bitSetReferenceComparison.status -cne 'source-compared-implemented-focused-passed' -or $bitSetReferenceComparison.semanticPhaseClosed -or
    $bitSetReferenceBaseline.status -cne 'failed' -or
    $bitSetReferenceBuild.status -cne 'passed' -or -not $bitSetReferenceBuild.inputsStable -or
    $bitSetReferenceBuild.compilerSha256 -cne $bitSetReference.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $bitSetReferenceCompiler -Algorithm SHA256).Hash -cne $bitSetReference.selfhostCompilerSha256 -or
    $bitSetReferencePair.status -cne 'passed' -or -not $bitSetReferencePair.inputStable -or
    $bitSetReferencePair.completed -ne 1 -or $bitSetReferencePair.total -ne 1 -or
    $bitSetReferenceControls.status -cne 'passed' -or -not $bitSetReferenceControls.inputStable -or
    $bitSetReferenceControls.completed -ne 4 -or $bitSetReferenceControls.total -ne 4 -or
    $bitSetReferenceNegative.state -cne 'passed' -or -not $bitSetReferenceNegative.inputsStable -or
    $bitSetReferenceNegative.selfhostCompilerSha256 -cne $bitSetReference.selfhostCompilerSha256 -or
    -not $interpolationCodegen.Contains('bitSetReference! -> if {', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('bitSetStorageRoot! >= 0 or bitSetReference! -> if {', [StringComparison]::Ordinal)) {
    throw 'readonly BitSet count interpolation lacks C# source, reference load, or paired runtime proof'
}
Assert-ExactStderrReport $bitSetReferenceExact 1 $bitSetReference.selfhostCompilerSha256

$bitSetTail = Get-Content -LiteralPath (Join-Path $root $contract.bitSetCountTailMaskEvidence) -Raw | ConvertFrom-Json
$bitSetTailComparison = Get-Content -LiteralPath (Join-Path $root $bitSetTail.sourceComparison) -Raw | ConvertFrom-Json
$bitSetTailBaseline = Get-Content -LiteralPath (Join-Path $root $bitSetTail.baselineStructural) -Raw | ConvertFrom-Json
$bitSetTailBuild = Get-Content -LiteralPath (Join-Path $root $bitSetTail.selfhostBuild) -Raw | ConvertFrom-Json
$bitSetTailMultiword = Get-Content -LiteralPath (Join-Path $root $bitSetTail.multiwordAndRetainedPair) -Raw | ConvertFrom-Json
$bitSetTailFullWord = Get-Content -LiteralPath (Join-Path $root $bitSetTail.fullWordPair) -Raw | ConvertFrom-Json
$bitSetTail63 = Get-Content -LiteralPath (Join-Path $root $bitSetTail.tail63Pair) -Raw | ConvertFrom-Json
$bitSetTailNegative = Get-Content -LiteralPath (Join-Path $root $bitSetTail.retainedNegativePair) -Raw | ConvertFrom-Json
$bitSetTailExact = Get-Content -LiteralPath (Join-Path $root $bitSetTail.retainedNegativeExact) -Raw | ConvertFrom-Json
$bitSetTailStructural = Get-Content -LiteralPath (Join-Path $root $bitSetTail.structuralGate) -Raw | ConvertFrom-Json
$bitSetTailCompiler = Join-Path (Split-Path -Parent (Join-Path $root $bitSetTail.selfhostBuild)) 'compiler.exe'
$bitSetContainers = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/containers.slg') -Raw
if ($bitSetTail.status -cne 'passed' -or $bitSetTail.nativePassed -cne '6/6' -or
    $bitSetTail.structuralPassed -cne '4/4' -or $bitSetTail.retainedExactPassed -cne '1/1' -or
    $bitSetTailComparison.status -cne 'source-compared-implemented-focused-passed' -or $bitSetTailComparison.semanticPhaseClosed -or
    $bitSetTailBaseline.status -cne 'failed' -or $bitSetTailBaseline.completed -ne 0 -or
    $bitSetTailBuild.status -cne 'passed' -or -not $bitSetTailBuild.inputsStable -or
    $bitSetTailBuild.compilerSha256 -cne $bitSetTail.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $bitSetTailCompiler -Algorithm SHA256).Hash -cne $bitSetTail.selfhostCompilerSha256 -or
    $bitSetTailMultiword.status -cne 'passed' -or -not $bitSetTailMultiword.inputStable -or
    $bitSetTailMultiword.completed -ne 4 -or $bitSetTailMultiword.total -ne 4 -or
    $bitSetTailFullWord.status -cne 'passed' -or -not $bitSetTailFullWord.inputStable -or
    $bitSetTailFullWord.completed -ne 1 -or $bitSetTailFullWord.total -ne 1 -or
    $bitSetTail63.status -cne 'passed' -or -not $bitSetTail63.inputStable -or
    $bitSetTail63.completed -ne 1 -or $bitSetTail63.total -ne 1 -or
    $bitSetTailNegative.state -cne 'passed' -or -not $bitSetTailNegative.inputsStable -or
    $bitSetTailNegative.selfhostCompilerSha256 -cne $bitSetTail.selfhostCompilerSha256 -or
    $bitSetTailStructural.status -cne 'passed' -or -not $bitSetTailStructural.inputsStable -or
    $bitSetTailStructural.completed -ne 4 -or $bitSetTailStructural.total -ne 4 -or
    -not $bitSetContainers.Contains('bitSetCountTailMask bitCount: Int -> UInt64', [StringComparison]::Ordinal) -or
    -not $bitSetContainers.Contains('bitCount -> bitSetCountTailMask', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('bitCount -> bitSetCountTailMask', [StringComparison]::Ordinal)) {
    throw 'BitSet count final-word masking lacks source, LLVM, or paired evidence'
}
Assert-ExactStderrReport $bitSetTailExact 1 $bitSetTail.selfhostCompilerSha256

$bitSetLength = Get-Content -LiteralPath (Join-Path $root $contract.bitSetLengthEvidence) -Raw | ConvertFrom-Json
$bitSetLengthComparison = Get-Content -LiteralPath (Join-Path $root $bitSetLength.sourceComparison) -Raw | ConvertFrom-Json
$bitSetLengthBaseline = Get-Content -LiteralPath (Join-Path $root $bitSetLength.baselineSelfhost) -Raw | ConvertFrom-Json
$bitSetLengthBuild = Get-Content -LiteralPath (Join-Path $root $bitSetLength.selfhostBuild) -Raw | ConvertFrom-Json
$bitSetLengthPair = Get-Content -LiteralPath (Join-Path $root $bitSetLength.focusedAndRetainedPair) -Raw | ConvertFrom-Json
$bitSetLengthReference = Get-Content -LiteralPath (Join-Path $root $bitSetLength.readonlyReferencePair) -Raw | ConvertFrom-Json
$bitSetLengthCompiler = Join-Path (Split-Path -Parent (Join-Path $root $bitSetLength.selfhostBuild)) 'compiler.exe'
$bitSetLengthValueLlChecks = $llvmObservedFixtures['1940-interpolation-bitset-length']
$bitSetLengthReferenceLlChecks = $llvmObservedFixtures['1941-interpolation-bitset-length-readonly-receiver']
if ($bitSetLength.status -cne 'passed' -or $bitSetLength.focusedPassed -cne '2/2' -or
    $bitSetLength.retainedPassed -cne '5/5' -or
    $bitSetLengthComparison.status -cne 'source-compared-before-selfhost-change' -or
    $bitSetLengthComparison.semanticPhaseClosed -or
    $bitSetLengthBaseline.status -cne 'failed' -or
    $bitSetLengthBuild.status -cne 'passed' -or -not $bitSetLengthBuild.inputsStable -or
    $bitSetLengthBuild.compilerSha256 -cne $bitSetLength.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $bitSetLengthCompiler -Algorithm SHA256).Hash -cne $bitSetLength.selfhostCompilerSha256 -or
    $bitSetLengthPair.status -cne 'passed' -or -not $bitSetLengthPair.inputStable -or
    $bitSetLengthPair.completed -ne 6 -or $bitSetLengthPair.total -ne 6 -or
    $bitSetLengthReference.status -cne 'passed' -or -not $bitSetLengthReference.inputStable -or
    $bitSetLengthReference.completed -ne 1 -or $bitSetLengthReference.total -ne 1 -or
    -not $bitSetLengthValueLlChecks['length'] -or
    -not $bitSetLengthReferenceLlChecks['length'] -or
    -not $interpolationCodegen.Contains('bitSetLengthTypeId! >= 0 and (context.types[bitSetLengthTypeId!].kind == 14 or context.types[bitSetLengthTypeId!].kind == 4 or context.types[bitSetLengthTypeId!].kind == 12)', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('nodeIndex -> interpolationNodeIntegerWidth(nodes, sourceModule, ownerIndex, beforeIndex, context, state) => lengthResultWidth', [StringComparison]::Ordinal)) {
    throw 'BitSet length interpolation lacks fixed-width C# source, LLVM constant, or paired runtime proof'
}

$bitSetContains = Get-Content -LiteralPath (Join-Path $root $contract.bitSetContainsEvidence) -Raw | ConvertFrom-Json
$bitSetContainsComparison = Get-Content -LiteralPath (Join-Path $root $bitSetContains.sourceComparison) -Raw | ConvertFrom-Json
$bitSetContainsBaseline = Get-Content -LiteralPath (Join-Path $root $bitSetContains.baselineSelfhost) -Raw | ConvertFrom-Json
$bitSetContainsBuild = Get-Content -LiteralPath (Join-Path $root $bitSetContains.selfhostBuild) -Raw | ConvertFrom-Json
$bitSetContainsPair = Get-Content -LiteralPath (Join-Path $root $bitSetContains.positiveAndRetainedPair) -Raw | ConvertFrom-Json
$bitSetContainsArity = Get-Content -LiteralPath (Join-Path $root $bitSetContains.arityNegative) -Raw | ConvertFrom-Json
$bitSetContainsType = Get-Content -LiteralPath (Join-Path $root $bitSetContains.typeNegative) -Raw | ConvertFrom-Json
$bitSetContainsExact = Get-Content -LiteralPath (Join-Path $root $bitSetContains.negativeExact) -Raw | ConvertFrom-Json
$bitSetContainsCompiler = Join-Path (Split-Path -Parent (Join-Path $root $bitSetContains.selfhostBuild)) 'compiler.exe'
$bitSetContainsDynamicLlChecks = $llvmObservedFixtures['1946-interpolation-bitset-contains-dynamic-index']
if ($bitSetContains.status -cne 'passed' -or $bitSetContains.focusedPassed -cne '3/3' -or
    $bitSetContains.retainedPassed -cne '2/2' -or $bitSetContains.negativeExactPassed -cne '2/2' -or
    $bitSetContainsComparison.status -cne 'source-compared-before-selfhost-change' -or
    $bitSetContainsComparison.semanticPhaseClosed -or
    $bitSetContainsBaseline.status -cne 'failed' -or
    $bitSetContainsBuild.status -cne 'passed' -or -not $bitSetContainsBuild.inputsStable -or
    $bitSetContainsBuild.compilerSha256 -cne $bitSetContains.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $bitSetContainsCompiler -Algorithm SHA256).Hash -cne $bitSetContains.selfhostCompilerSha256 -or
    $bitSetContainsPair.status -cne 'passed' -or -not $bitSetContainsPair.inputStable -or
    $bitSetContainsPair.completed -ne 5 -or $bitSetContainsPair.total -ne 5 -or
    $bitSetContainsArity.state -cne 'passed' -or -not $bitSetContainsArity.inputsStable -or
    $bitSetContainsType.state -cne 'passed' -or -not $bitSetContainsType.inputsStable -or
    -not $bitSetContainsDynamicLlChecks['bounds'] -or
    -not $bitSetContainsDynamicLlChecks['wide-index'] -or
    -not $bitSetContainsDynamicLlChecks['mask'] -or
    -not $bitSetContainsDynamicLlChecks['trap'] -or
    -not $interpolationLowering.Contains('-> if { -243 => intrinsicFlowOpcode! }', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('public collectionMembershipDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('typeIds.collectionMembershipExpectedTypeId(receiver)', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.collectionMembershipDiagnosticByNode', [StringComparison]::Ordinal)) {
    throw 'BitSet contains interpolation lacks source, typed index, checked LLVM, or paired proof'
}
Assert-ExactStderrReport $bitSetContainsExact 2 $bitSetContains.selfhostCompilerSha256

$publicCrossFile = Get-Content -LiteralPath (Join-Path $root $contract.publicCrossFileLexicalControlEvidence) -Raw | ConvertFrom-Json
$publicCrossFilePair = Get-Content -LiteralPath (Join-Path $root $publicCrossFile.pairedNegative) -Raw | ConvertFrom-Json
$publicCrossFileExact = Get-Content -LiteralPath (Join-Path $root $publicCrossFile.exactStderr) -Raw | ConvertFrom-Json
if ($publicCrossFile.status -cne 'passed-control-unit-open' -or
    $publicCrossFile.focusedPassed -cne '1/1' -or
    $publicCrossFile.semanticOwnedKindsComplete -cne '3/12' -or
    $publicCrossFilePair.state -cne 'passed' -or -not $publicCrossFilePair.inputsStable -or
    $publicCrossFilePair.selfhostCompilerSha256 -cne $bitSetContains.selfhostCompilerSha256 -or
    $publicCrossFileExact.status -cne 'passed' -or $publicCrossFileExact.completed -ne 1 -or
    $publicCrossFileExact.total -ne 1) {
    throw 'cross-file public function interpolation control lacks current paired exact evidence'
}
Assert-ExactStderrReport $publicCrossFileExact 1 $bitSetContains.selfhostCompilerSha256

$binaryArithmetic = Get-Content -LiteralPath (Join-Path $root $contract.binaryArithmeticEvidence) -Raw | ConvertFrom-Json
$binarySourceComparison = Get-Content -LiteralPath (Join-Path $root $binaryArithmetic.sourceComparison) -Raw | ConvertFrom-Json
$binaryBuild = Get-Content -LiteralPath (Join-Path $root $binaryArithmetic.selfhostBuild) -Raw | ConvertFrom-Json
$binaryPositive = Get-Content -LiteralPath (Join-Path $root $binaryArithmetic.positivePair) -Raw | ConvertFrom-Json
$binaryExact = Get-Content -LiteralPath (Join-Path $root $binaryArithmetic.negativeExact) -Raw | ConvertFrom-Json
$binaryCompiler = Join-Path (Split-Path -Parent (Join-Path $root $binaryArithmetic.selfhostBuild)) 'compiler.exe'
$binaryContractLog = Get-Content -LiteralPath (Join-Path $root $binaryArithmetic.fullContractLog) -Raw
if ($binaryArithmetic.status -cne 'passed' -or $binaryArithmetic.semanticPhaseClosed -or
    $binaryArithmetic.focusedPassed -cne '5/5' -or $binaryArithmetic.retainedPassed -cne '4/4' -or
    $binaryArithmetic.negativeExactPassed -cne '5/5' -or
    $binarySourceComparison.status -cne 'source-compared-before-selfhost-change' -or
    $binaryBuild.status -cne 'passed' -or -not $binaryBuild.inputsStable -or
    $binaryBuild.compilerSha256 -cne $binaryArithmetic.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $binaryCompiler -Algorithm SHA256).Hash -cne $binaryArithmetic.selfhostCompilerSha256 -or
    $binaryPositive.status -cne 'passed' -or -not $binaryPositive.inputStable -or
    $binaryPositive.completed -ne 4 -or $binaryPositive.total -ne 4 -or
    $binaryArithmetic.negativePairs.Count -ne 5 -or
    -not (Test-Path -LiteralPath (Join-Path $root $binaryArithmetic.additionalManagedFirst) -PathType Leaf) -or
    -not $binaryContractLog.Contains('[selfhost compiler contracts] PASS', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('binaryArithmeticDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.binaryArithmeticDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.binaryArithmeticDiagnosticByNode[nodeIndex!].code > 0', [StringComparison]::Ordinal)) {
    throw 'Interpolation binary arithmetic lacks source comparison, semantic decision, or paired proof'
}
foreach ($receiptPath in $binaryArithmetic.negativePairs) {
    $binaryNegative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($binaryNegative.state -cne 'passed' -or -not $binaryNegative.inputsStable -or
        $binaryNegative.selfhostCompilerSha256 -cne $binaryArithmetic.selfhostCompilerSha256) {
        throw "Interpolation binary arithmetic negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $binaryExact 5 $binaryArithmetic.selfhostCompilerSha256

$binaryComparison = Get-Content -LiteralPath (Join-Path $root $contract.binaryComparisonEvidence) -Raw | ConvertFrom-Json
$comparisonSource = Get-Content -LiteralPath (Join-Path $root $binaryComparison.sourceComparison) -Raw | ConvertFrom-Json
$comparisonBuild = Get-Content -LiteralPath (Join-Path $root $binaryComparison.selfhostBuild) -Raw | ConvertFrom-Json
$comparisonExact = Get-Content -LiteralPath (Join-Path $root $binaryComparison.negativeExact) -Raw | ConvertFrom-Json
$comparisonRetainedExact = Get-Content -LiteralPath (Join-Path $root $binaryComparison.retainedNegativeExact) -Raw | ConvertFrom-Json
$comparisonCompiler = Join-Path (Split-Path -Parent (Join-Path $root $binaryComparison.selfhostBuild)) 'compiler.exe'
$comparisonContractLog = Get-Content -LiteralPath (Join-Path $root $binaryComparison.fullContractLog) -Raw
if ($binaryComparison.status -cne 'passed' -or $binaryComparison.semanticPhaseClosed -or
    $binaryComparison.focusedPassed -cne '6/6' -or $binaryComparison.retainedPassed -cne '7/7' -or
    $comparisonSource.status -cne 'source-compared-before-selfhost-change' -or
    $comparisonBuild.status -cne 'passed' -or -not $comparisonBuild.inputsStable -or
    $comparisonBuild.compilerSha256 -cne $binaryComparison.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $comparisonCompiler -Algorithm SHA256).Hash -cne $binaryComparison.selfhostCompilerSha256 -or
    $binaryComparison.negativePairs.Count -ne 4 -or
    -not $comparisonContractLog.Contains('[selfhost compiler contracts] PASS', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('binaryComparisonDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.binaryComparisonDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.binaryComparisonDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('semanticInterpolationNodeIndex', [StringComparison]::Ordinal) -or
    -not $interpolationEntryCodegen.Contains('emitInterpolationOperation', [StringComparison]::Ordinal)) {
    throw 'Interpolation comparison lacks source comparison, semantic decision, or current build proof'
}
foreach ($receiptPath in $binaryComparison.negativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $binaryComparison.selfhostCompilerSha256) {
        throw "Interpolation comparison negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $comparisonExact 4 $binaryComparison.selfhostCompilerSha256
Assert-ExactStderrReport $comparisonRetainedExact 5 $binaryComparison.selfhostCompilerSha256
foreach ($pairPath in @($binaryComparison.positiveMainPair, $binaryComparison.positiveFunctionPair,
        $binaryComparison.retainedPositivePair)) {
    $pair = Get-Content -LiteralPath (Join-Path $root $pairPath) -Raw | ConvertFrom-Json
    if ($pair.status -cne 'passed' -or -not $pair.inputStable -or
        (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $pair.inputHashesStart -LiteralPath $comparisonCompiler) -cne $binaryComparison.selfhostCompilerSha256) {
        throw "Interpolation comparison positive pair invalid: $pairPath"
    }
}

$binaryLogical = Get-Content -LiteralPath (Join-Path $root $contract.binaryLogicalEvidence) -Raw | ConvertFrom-Json
$logicalSource = Get-Content -LiteralPath (Join-Path $root $binaryLogical.sourceComparison) -Raw | ConvertFrom-Json
$logicalBuild = Get-Content -LiteralPath (Join-Path $root $binaryLogical.selfhostBuild) -Raw | ConvertFrom-Json
$logicalExact = Get-Content -LiteralPath (Join-Path $root $binaryLogical.negativeExact) -Raw | ConvertFrom-Json
$logicalComparisonExact = Get-Content -LiteralPath (Join-Path $root $binaryLogical.retainedComparisonExact) -Raw | ConvertFrom-Json
$logicalArithmeticExact = Get-Content -LiteralPath (Join-Path $root $binaryLogical.retainedArithmeticExact) -Raw | ConvertFrom-Json
$logicalCompiler = Join-Path (Split-Path -Parent (Join-Path $root $binaryLogical.selfhostBuild)) 'compiler.exe'
$logicalContractLog = Get-Content -LiteralPath (Join-Path $root $binaryLogical.fullContractLog) -Raw
if ($binaryLogical.status -cne 'passed' -or $binaryLogical.semanticPhaseClosed -or
    $binaryLogical.focusedPassed -cne '3/3' -or $binaryLogical.retainedPassed -cne '13/13' -or
    $logicalSource.status -cne 'source-compared-before-selfhost-change' -or
    $logicalBuild.status -cne 'passed' -or -not $logicalBuild.inputsStable -or
    $logicalBuild.compilerSha256 -cne $binaryLogical.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $logicalCompiler -Algorithm SHA256).Hash -cne $binaryLogical.selfhostCompilerSha256 -or
    $binaryLogical.negativePairs.Count -ne 2 -or
    -not $logicalContractLog.Contains('[selfhost compiler contracts] PASS', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('binaryLogicalDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $emitterPreparation.Contains('interpolationInference.binaryLogicalDiagnosticByNode', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.binaryLogicalDiagnosticByNode', [StringComparison]::Ordinal)) {
    throw 'Interpolation logical operands lack source comparison, semantic decision, or current build proof'
}
foreach ($receiptPath in $binaryLogical.negativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $binaryLogical.selfhostCompilerSha256) {
        throw "Interpolation logical negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $logicalExact 2 $binaryLogical.selfhostCompilerSha256
Assert-ExactStderrReport $logicalComparisonExact 4 $binaryLogical.selfhostCompilerSha256
Assert-ExactStderrReport $logicalArithmeticExact 5 $binaryLogical.selfhostCompilerSha256
$logicalPairPaths = @($binaryLogical.positivePair, $binaryLogical.retainedComparisonPositive,
    $binaryLogical.retainedArithmeticPositive)
$logicalPairTotals = @(1, 2, 2)
for ($pairIndex = 0; $pairIndex -lt $logicalPairPaths.Count; $pairIndex++) {
    $pairPath = $logicalPairPaths[$pairIndex]
    $pair = Get-Content -LiteralPath (Join-Path $root $pairPath) -Raw | ConvertFrom-Json
    if ($pair.status -cne 'passed' -or -not $pair.inputStable -or
        $pair.completed -ne $logicalPairTotals[$pairIndex] -or
        $pair.total -ne $logicalPairTotals[$pairIndex] -or
        (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $pair.inputHashesStart -LiteralPath $logicalCompiler) -cne $binaryLogical.selfhostCompilerSha256) {
        throw "Interpolation logical positive pair invalid: $pairPath"
    }
}

$nestedLogical = Get-Content -LiteralPath (Join-Path $root $contract.nestedLogicalLocationEvidence) -Raw | ConvertFrom-Json
$nestedSource = Get-Content -LiteralPath (Join-Path $root $nestedLogical.sourceComparison) -Raw | ConvertFrom-Json
$nestedBaseline = Get-Content -LiteralPath (Join-Path $root $nestedSource.baselineExact) -Raw | ConvertFrom-Json
$nestedBuild = Get-Content -LiteralPath (Join-Path $root $nestedLogical.selfhostBuild) -Raw | ConvertFrom-Json
$nestedExact = Get-Content -LiteralPath (Join-Path $root $nestedLogical.negativeExact) -Raw | ConvertFrom-Json
$nestedRetainedExact = Get-Content -LiteralPath (Join-Path $root $nestedLogical.retainedDirectExact) -Raw | ConvertFrom-Json
$nestedPositive = Get-Content -LiteralPath (Join-Path $root $nestedLogical.retainedPositivePair) -Raw | ConvertFrom-Json
$nestedCompiler = Join-Path (Split-Path -Parent (Join-Path $root $nestedLogical.selfhostBuild)) 'compiler.exe'
$nestedContractLog = Get-Content -LiteralPath (Join-Path $root $nestedLogical.fullContractLog) -Raw
if ($nestedLogical.status -cne 'passed' -or $nestedLogical.semanticPhaseClosed -or
    $nestedLogical.focusedPassed -cne '2/2' -or $nestedLogical.retainedPassed -cne '4/4' -or
    $nestedSource.status -cne 'source-compared-before-selfhost-change' -or
    $nestedBaseline.status -cne 'mismatched' -or $nestedBaseline.completed -ne 0 -or $nestedBaseline.total -ne 2 -or
    $nestedBuild.status -cne 'passed' -or -not $nestedBuild.inputsStable -or
    $nestedBuild.compilerSha256 -cne $nestedLogical.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $nestedCompiler -Algorithm SHA256).Hash -cne $nestedLogical.selfhostCompilerSha256 -or
    $nestedLogical.negativePairs.Count -ne 2 -or
    -not $nestedContractLog.Contains('PASS LLVM emitter split ABI:', [StringComparison]::Ordinal) -or
    -not $nestedContractLog.Contains('[selfhost compiler contracts] PASS', [StringComparison]::Ordinal) -or
    -not $semanticDiagnostics.Contains('interpolationExpressionLocation', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('semanticDiagnostics.interpolationExpressionLocation', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('diagnosticStart: loweredDiagnosticStart!', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('diagnosticStart: node.diagnosticStart', [StringComparison]::Ordinal)) {
    throw 'Nested logical operand location lacks source comparison and focused proof'
}
foreach ($receiptPath in $nestedLogical.negativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $nestedLogical.selfhostCompilerSha256) {
        throw "Nested logical operand negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $nestedExact 2 $nestedLogical.selfhostCompilerSha256
Assert-ExactStderrReport $nestedRetainedExact 2 $nestedLogical.selfhostCompilerSha256
if ($nestedPositive.status -cne 'passed' -or -not $nestedPositive.inputStable -or
    $nestedPositive.completed -ne 2 -or $nestedPositive.total -ne 2 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $nestedPositive.inputHashesStart -LiteralPath $nestedCompiler) -cne $nestedLogical.selfhostCompilerSha256) {
    throw 'Nested logical operand retained positive pair invalid'
}

$unaryUnit = Get-Content -LiteralPath (Join-Path $root $contract.unaryResultTypeEvidence) -Raw | ConvertFrom-Json
$unarySource = Get-Content -LiteralPath (Join-Path $root $unaryUnit.sourceComparison) -Raw | ConvertFrom-Json
$unaryBuild = Get-Content -LiteralPath (Join-Path $root $unaryUnit.selfhostBuild) -Raw | ConvertFrom-Json
$unaryExact = Get-Content -LiteralPath (Join-Path $root $unaryUnit.negativeExact) -Raw | ConvertFrom-Json
$unaryCompiler = Join-Path (Split-Path -Parent (Join-Path $root $unaryUnit.selfhostBuild)) 'compiler.exe'
if ($unaryUnit.status -cne 'passed' -or $unaryUnit.semanticPhaseClosed -or
    $unaryUnit.focusedPassed -cne '2/2' -or $unaryUnit.retainedPassed -cne '2/2' -or
    $unarySource.status -cne 'source-compared-before-selfhost-change' -or
    $unaryBuild.status -cne 'passed' -or
    $unaryBuild.compilerSha256 -cne $unaryUnit.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $unaryCompiler -Algorithm SHA256).Hash -cne $unaryUnit.selfhostCompilerSha256 -or
    -not $managedSemantic.Contains('private BoundType InferNotExpression(', [StringComparison]::Ordinal) -or
    -not $managedSemantic.Contains('private BoundType InferNegateExpression(', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('node.kind == 2 and node.operand0 >= 0 -> if {', [StringComparison]::Ordinal)) {
    throw 'Interpolation unary result type lacks source comparison or current compiler proof'
}
foreach ($receiptPath in $unaryUnit.negativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $unaryUnit.selfhostCompilerSha256) {
        throw "Interpolation unary negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $unaryExact 2 $unaryUnit.selfhostCompilerSha256
foreach ($pairPath in $unaryUnit.retainedPositivePairs) {
    $pair = Get-Content -LiteralPath (Join-Path $root $pairPath) -Raw | ConvertFrom-Json
    if ($pair.status -cne 'passed' -or -not $pair.inputStable -or
        $pair.completed -ne 1 -or $pair.total -ne 1 -or
        (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $pair.inputHashesStart -LiteralPath $unaryCompiler) -cne $unaryUnit.selfhostCompilerSha256) {
        throw "Interpolation unary retained positive pair invalid: $pairPath"
    }
}

$logicalResult = Get-Content -LiteralPath (Join-Path $root $contract.logicalResultTypeEvidence) -Raw | ConvertFrom-Json
$logicalResultSource = Get-Content -LiteralPath (Join-Path $root $logicalResult.sourceComparison) -Raw | ConvertFrom-Json
$logicalResultBuild = Get-Content -LiteralPath (Join-Path $root $logicalResult.selfhostBuild) -Raw | ConvertFrom-Json
$logicalResultExact = Get-Content -LiteralPath (Join-Path $root $logicalResult.negativeExact) -Raw | ConvertFrom-Json
$logicalResultRetainedExact = Get-Content -LiteralPath (Join-Path $root $logicalResult.retainedNegativeExact) -Raw | ConvertFrom-Json
$logicalResultPositive = Get-Content -LiteralPath (Join-Path $root $logicalResult.retainedPositivePair) -Raw | ConvertFrom-Json
$logicalResultCompiler = Join-Path (Split-Path -Parent (Join-Path $root $logicalResult.selfhostBuild)) 'compiler.exe'
if ($logicalResult.status -cne 'passed' -or $logicalResult.semanticPhaseClosed -or
    $logicalResult.focusedPassed -cne '1/1' -or $logicalResult.retainedPassed -cne '5/5' -or
    $logicalResultSource.status -cne 'source-compared-before-selfhost-change' -or
    $logicalResultBuild.status -cne 'passed' -or
    $logicalResultBuild.compilerSha256 -cne $logicalResult.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $logicalResultCompiler -Algorithm SHA256).Hash -cne $logicalResult.selfhostCompilerSha256 -or
    -not $managedSemantic.Contains('private BoundType InferLogicalExpression(', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('node.kind == 3 and node.operand0 >= 0 and node.operand1 >= 0', [StringComparison]::Ordinal)) {
    throw 'Interpolation logical result type lacks source comparison or current compiler proof'
}
foreach ($receiptPath in @($logicalResult.negativePair) + @($logicalResult.retainedNegativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $logicalResult.selfhostCompilerSha256) {
        throw "Interpolation logical result negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $logicalResultExact 1 $logicalResult.selfhostCompilerSha256
Assert-ExactStderrReport $logicalResultRetainedExact 4 $logicalResult.selfhostCompilerSha256
if ($logicalResultPositive.status -cne 'passed' -or -not $logicalResultPositive.inputStable -or
    $logicalResultPositive.completed -ne 1 -or $logicalResultPositive.total -ne 1 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $logicalResultPositive.inputHashesStart -LiteralPath $logicalResultCompiler) -cne $logicalResult.selfhostCompilerSha256) {
    throw 'Interpolation logical result retained positive pair invalid'
}

$comparisonResult = Get-Content -LiteralPath (Join-Path $root $contract.comparisonResultTypeEvidence) -Raw | ConvertFrom-Json
$comparisonResultSource = Get-Content -LiteralPath (Join-Path $root $comparisonResult.sourceComparison) -Raw | ConvertFrom-Json
$comparisonResultBuild = Get-Content -LiteralPath (Join-Path $root $comparisonResult.selfhostBuild) -Raw | ConvertFrom-Json
$comparisonResultExact = Get-Content -LiteralPath (Join-Path $root $comparisonResult.negativeExact) -Raw | ConvertFrom-Json
$comparisonResultRetainedExact = Get-Content -LiteralPath (Join-Path $root $comparisonResult.retainedNegativeExact) -Raw | ConvertFrom-Json
$comparisonResultCompiler = Join-Path (Split-Path -Parent (Join-Path $root $comparisonResult.selfhostBuild)) 'compiler.exe'
if ($comparisonResult.status -cne 'passed' -or $comparisonResult.semanticPhaseClosed -or
    $comparisonResult.focusedPassed -cne '2/2' -or $comparisonResult.retainedPassed -cne '7/7' -or
    $comparisonResultSource.status -cne 'source-compared-before-selfhost-change' -or
    $comparisonResultBuild.status -cne 'passed' -or
    $comparisonResultBuild.compilerSha256 -cne $comparisonResult.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $comparisonResultCompiler -Algorithm SHA256).Hash -cne $comparisonResult.selfhostCompilerSha256 -or
    -not $managedSemantic.Contains('private BoundType InferCompareExpression(', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('comparisonDecision prepared:', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('prepared -> comparisonDecision(plan, bindingFacts, ir, types, fields, sourceModule, nodeIndex) => decision', [StringComparison]::Ordinal)) {
    throw 'Interpolation comparison result type lacks shared semantic decision or current compiler proof'
}
foreach ($receiptPath in @($comparisonResult.negativePairs) + @($comparisonResult.retainedNegativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $comparisonResult.selfhostCompilerSha256) {
        throw "Interpolation comparison result negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $comparisonResultExact 2 $comparisonResult.selfhostCompilerSha256
Assert-ExactStderrReport $comparisonResultRetainedExact 4 $comparisonResult.selfhostCompilerSha256
$comparisonPositiveTotals = @(2, 1)
for ($pairIndex = 0; $pairIndex -lt $comparisonResult.retainedPositivePairs.Count; $pairIndex++) {
    $pairPath = $comparisonResult.retainedPositivePairs[$pairIndex]
    $pair = Get-Content -LiteralPath (Join-Path $root $pairPath) -Raw | ConvertFrom-Json
    if ($pair.status -cne 'passed' -or -not $pair.inputStable -or
        $pair.completed -ne $comparisonPositiveTotals[$pairIndex] -or
        $pair.total -ne $comparisonPositiveTotals[$pairIndex] -or
        (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $pair.inputHashesStart -LiteralPath $comparisonResultCompiler) -cne $comparisonResult.selfhostCompilerSha256) {
        throw "Interpolation comparison result retained positive pair invalid: $pairPath"
    }
}

$arithmeticResult = Get-Content -LiteralPath (Join-Path $root $contract.arithmeticResultTypeEvidence) -Raw | ConvertFrom-Json
$arithmeticResultSource = Get-Content -LiteralPath (Join-Path $root $arithmeticResult.sourceComparison) -Raw | ConvertFrom-Json
$arithmeticResultBuild = Get-Content -LiteralPath (Join-Path $root $arithmeticResult.selfhostBuild) -Raw | ConvertFrom-Json
$arithmeticResultExact = Get-Content -LiteralPath (Join-Path $root $arithmeticResult.negativeExact) -Raw | ConvertFrom-Json
$arithmeticResultContract = Get-Content -LiteralPath (Join-Path $root $arithmeticResult.fullContract) -Raw | ConvertFrom-Json
$arithmeticResultCompiler = Join-Path (Split-Path -Parent (Join-Path $root $arithmeticResult.selfhostBuild)) 'compiler.exe'
if ($arithmeticResult.status -cne 'passed' -or $arithmeticResult.semanticPhaseClosed -or
    $arithmeticResult.focusedPassed -cne '5/5' -or $arithmeticResult.retainedPassed -cne '9/9' -or
    $arithmeticResultSource.status -cne 'source-compared-before-selfhost-change' -or
    $arithmeticResultBuild.status -cne 'passed' -or
    $arithmeticResultBuild.compilerSha256 -cne $arithmeticResult.selfhostCompilerSha256 -or
    $arithmeticResultContract.status -cne 'passed' -or
    $arithmeticResultContract.compilerSha256 -cne $arithmeticResult.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $arithmeticResultContract.log) -Algorithm SHA256).Hash -cne $arithmeticResultContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $arithmeticResultCompiler -Algorithm SHA256).Hash -cne $arithmeticResult.selfhostCompilerSha256 -or
    -not $managedSemantic.Contains('private BoundType InferIntegerBinaryExpression(', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('prepared -> arithmeticDecision(plan, bindingFacts, ir, types, fields, sourceModule, nodeIndex) => decision', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('"fadd" => floatOperation!', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('not sourceIsFloat! -> if {', [StringComparison]::Ordinal) -or
    -not $interpolationEntryCodegen.Contains('entryExpressionIndex -> emitInterpolationOperation(', [StringComparison]::Ordinal)) {
    throw 'Interpolation arithmetic result type lacks shared semantic and LLVM decisions or current compiler proof'
}
foreach ($receiptPath in $arithmeticResult.negativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $arithmeticResult.selfhostCompilerSha256) {
        throw "Interpolation arithmetic result negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $arithmeticResultExact 6 $arithmeticResult.selfhostCompilerSha256
$arithmeticPositiveTotals = @(1, 2, 1, 4)
for ($pairIndex = 0; $pairIndex -lt $arithmeticResult.positivePairs.Count; $pairIndex++) {
    $pairPath = $arithmeticResult.positivePairs[$pairIndex]
    $pair = Get-Content -LiteralPath (Join-Path $root $pairPath) -Raw | ConvertFrom-Json
    if ($pair.status -cne 'passed' -or -not $pair.inputStable -or
        $pair.completed -ne $arithmeticPositiveTotals[$pairIndex] -or
        $pair.total -ne $arithmeticPositiveTotals[$pairIndex] -or
        (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $pair.inputHashesStart -LiteralPath $arithmeticResultCompiler) -cne $arithmeticResult.selfhostCompilerSha256) {
        throw "Interpolation arithmetic result positive pair invalid: $pairPath"
    }
}

$textRoutes = Get-Content -LiteralPath (Join-Path $root $contract.textComparisonRoutesEvidence) -Raw | ConvertFrom-Json
$textRoutesSource = Get-Content -LiteralPath (Join-Path $root $textRoutes.sourceComparison) -Raw | ConvertFrom-Json
$textRoutesBuild = Get-Content -LiteralPath (Join-Path $root $textRoutes.selfhostBuild) -Raw | ConvertFrom-Json
$textRoutesFocused = Get-Content -LiteralPath (Join-Path $root $textRoutes.focusedPositivePair) -Raw | ConvertFrom-Json
$textRoutesRetained = Get-Content -LiteralPath (Join-Path $root $textRoutes.retainedPositivePair) -Raw | ConvertFrom-Json
$textRoutesExact = Get-Content -LiteralPath (Join-Path $root $textRoutes.retainedNegativeExact) -Raw | ConvertFrom-Json
$textRoutesContract = Get-Content -LiteralPath (Join-Path $root $textRoutes.fullContract) -Raw | ConvertFrom-Json
$textRoutesCompiler = Join-Path (Split-Path -Parent (Join-Path $root $textRoutes.selfhostBuild)) 'compiler.exe'
if ($textRoutes.status -cne 'passed' -or $textRoutes.semanticPhaseClosed -or
    $textRoutes.focusedPassed -cne '2/2' -or $textRoutes.retainedPassed -cne '9/9' -or
    $textRoutesSource.status -cne 'source-compared-before-selfhost-change' -or
    $textRoutesBuild.status -cne 'passed' -or
    $textRoutesBuild.compilerSha256 -cne $textRoutes.selfhostCompilerSha256 -or
    $textRoutesContract.status -cne 'passed' -or
    $textRoutesContract.compilerSha256 -cne $textRoutes.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $textRoutesContract.log) -Algorithm SHA256).Hash -cne $textRoutesContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $textRoutesCompiler -Algorithm SHA256).Hash -cne $textRoutes.selfhostCompilerSha256 -or
    $textRoutesFocused.status -cne 'passed' -or $textRoutesFocused.completed -ne 2 -or $textRoutesFocused.total -ne 2 -or -not $textRoutesFocused.inputStable -or
    $textRoutesRetained.status -cne 'passed' -or $textRoutesRetained.completed -ne 6 -or $textRoutesRetained.total -ne 6 -or -not $textRoutesRetained.inputStable -or
    -not $interpolationCodegen.Contains('emitInterpolationOperation labelIndex:', [StringComparison]::Ordinal)) {
    throw 'Interpolation Text equality emitter routes lack current source or paired proof'
}
foreach ($receiptPath in $textRoutes.retainedNegativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $textRoutes.selfhostCompilerSha256) {
        throw "Interpolation Text equality route retained negative invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $textRoutesExact 3 $textRoutes.selfhostCompilerSha256

$floatComparison = Get-Content -LiteralPath (Join-Path $root $contract.floatComparisonEvidence) -Raw | ConvertFrom-Json
$floatComparisonSource = Get-Content -LiteralPath (Join-Path $root $floatComparison.sourceComparison) -Raw | ConvertFrom-Json
$floatComparisonManaged = Get-Content -LiteralPath (Join-Path $root $floatComparison.managedFirst) -Raw | ConvertFrom-Json
$floatComparisonBuild = Get-Content -LiteralPath (Join-Path $root $floatComparison.selfhostBuild) -Raw | ConvertFrom-Json
$floatComparisonFocused = Get-Content -LiteralPath (Join-Path $root $floatComparison.focusedPositivePair) -Raw | ConvertFrom-Json
$floatComparisonRetained = Get-Content -LiteralPath (Join-Path $root $floatComparison.retainedPositivePair) -Raw | ConvertFrom-Json
$floatComparisonExact = Get-Content -LiteralPath (Join-Path $root $floatComparison.retainedNegativeExact) -Raw | ConvertFrom-Json
$floatComparisonContract = Get-Content -LiteralPath (Join-Path $root $floatComparison.fullContract) -Raw | ConvertFrom-Json
$floatComparisonCompiler = Join-Path (Split-Path -Parent (Join-Path $root $floatComparison.selfhostBuild)) 'compiler.exe'
if ($floatComparison.status -cne 'passed' -or $floatComparison.semanticPhaseClosed -or
    $floatComparison.focusedPassed -cne '3/3' -or $floatComparison.retainedPassed -cne '12/12' -or
    $floatComparisonSource.status -cne 'source-compared-before-selfhost-change' -or
    $floatComparisonManaged.status -cne 'passed' -or $floatComparisonManaged.completed -ne 3 -or $floatComparisonManaged.total -ne 3 -or
    $floatComparisonBuild.status -cne 'passed' -or
    $floatComparisonBuild.compilerSha256 -cne $floatComparison.selfhostCompilerSha256 -or
    $floatComparisonContract.status -cne 'passed' -or
    $floatComparisonContract.compilerSha256 -cne $floatComparison.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $floatComparisonContract.log) -Algorithm SHA256).Hash -cne $floatComparisonContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $floatComparisonCompiler -Algorithm SHA256).Hash -cne $floatComparison.selfhostCompilerSha256 -or
    $floatComparisonFocused.status -cne 'passed' -or $floatComparisonFocused.completed -ne 3 -or $floatComparisonFocused.total -ne 3 -or -not $floatComparisonFocused.inputStable -or
    $floatComparisonRetained.status -cne 'passed' -or $floatComparisonRetained.completed -ne 8 -or $floatComparisonRetained.total -ne 8 -or -not $floatComparisonRetained.inputStable -or
    -not $interpolationCodegen.Contains('interpolationFloatComparisonBuiltin node:', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('node.opcode -> floatBinaryOperation => comparisonOperation', [StringComparison]::Ordinal) -or
    -not $interpolationEntryCodegen.Contains('entryExpressionIndex -> emitInterpolationOperation(', [StringComparison]::Ordinal)) {
    throw 'Interpolation Float comparison lacks managed-first, source, LLVM, or paired proof'
}
foreach ($receiptPath in $floatComparison.retainedNegativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $floatComparison.selfhostCompilerSha256) {
        throw "Interpolation Float comparison retained negative invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $floatComparisonExact 4 $floatComparison.selfhostCompilerSha256

$operationConvergence = Get-Content -LiteralPath (Join-Path $root $contract.operationEmitterConvergenceEvidence) -Raw | ConvertFrom-Json
$operationSource = Get-Content -LiteralPath (Join-Path $root $operationConvergence.sourceComparison) -Raw | ConvertFrom-Json
$operationBuild = Get-Content -LiteralPath (Join-Path $root $operationConvergence.selfhostBuild) -Raw | ConvertFrom-Json
$operationContract = Get-Content -LiteralPath (Join-Path $root $operationConvergence.fullContract) -Raw | ConvertFrom-Json
$operationFocused = Get-Content -LiteralPath (Join-Path $root $operationConvergence.focusedPositivePair) -Raw | ConvertFrom-Json
$operationRetained = Get-Content -LiteralPath (Join-Path $root $operationConvergence.retainedPositivePair) -Raw | ConvertFrom-Json
$operationStreamRetained = Get-Content -LiteralPath (Join-Path $root $operationConvergence.retainedStreamPair) -Raw | ConvertFrom-Json
$operationStreamBaseline = Get-Content -LiteralPath (Join-Path $root $operationConvergence.streamRoleBaseline) -Raw | ConvertFrom-Json
$operationStreamMismatch = Get-Content -LiteralPath (Join-Path $root $operationConvergence.streamRoleInitialMismatch) -Raw | ConvertFrom-Json
$operationStreamFixed = Get-Content -LiteralPath (Join-Path $root $operationConvergence.streamRoleFixedPair) -Raw | ConvertFrom-Json
$operationSplitAbi = Get-Content -LiteralPath (Join-Path $root $operationConvergence.splitAbiGate) -Raw
$operationExact = Get-Content -LiteralPath (Join-Path $root $operationConvergence.retainedNegativeExact) -Raw | ConvertFrom-Json
$operationCompiler = Join-Path (Split-Path -Parent (Join-Path $root $operationConvergence.selfhostBuild)) 'compiler.exe'
$operationCallCodegen = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/function_calls.slg') -Raw
$operationControlCodegen = Get-Content -LiteralPath (Join-Path $root 'selfhost/llvm/text/control_region_expressions.slg') -Raw
if ($operationConvergence.status -cne 'passed' -or $operationConvergence.semanticPhaseClosed -or
    $operationConvergence.focusedPassed -cne '4/4' -or $operationConvergence.retainedPassed -cne '13/13' -or $operationConvergence.retainedStreamPassed -cne '3/3' -or
    $operationSource.status -cne 'source-compared-before-selfhost-change' -or
    $operationBuild.status -cne 'passed' -or $operationBuild.compilerSha256 -cne $operationConvergence.selfhostCompilerSha256 -or
    $operationContract.status -cne 'passed' -or $operationContract.compilerSha256 -cne $operationConvergence.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $operationContract.log) -Algorithm SHA256).Hash -cne $operationContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $operationCompiler -Algorithm SHA256).Hash -cne $operationConvergence.selfhostCompilerSha256 -or
    $operationFocused.status -cne 'passed' -or $operationFocused.completed -ne 4 -or $operationFocused.total -ne 4 -or -not $operationFocused.inputStable -or
    $operationRetained.status -cne 'passed' -or $operationRetained.completed -ne 13 -or $operationRetained.total -ne 13 -or -not $operationRetained.inputStable -or
    $operationStreamRetained.status -cne 'passed' -or $operationStreamRetained.completed -ne 3 -or $operationStreamRetained.total -ne 3 -or -not $operationStreamRetained.inputStable -or
    $operationStreamBaseline.status -cne 'passed' -or $operationStreamBaseline.completed -ne 1 -or
    $operationStreamMismatch.status -cne 'failed' -or $operationStreamMismatch.completed -ne 0 -or
    $operationStreamFixed.status -cne 'passed' -or $operationStreamFixed.completed -ne 1 -or -not $operationStreamFixed.inputStable -or
    -not $operationSplitAbi.Contains('PASS LLVM emitter split ABI: stateful helpers=342', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('interpolationBinaryNumericWidth node:', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('beforeIndex -> regionOwnedStreamPipeline(context, state) => streamPipeline', [StringComparison]::Ordinal) -or
    -not $interpolationEntryCodegen.Contains('entryExpressionIndex -> emitInterpolationOperation(', [StringComparison]::Ordinal) -or
    -not $operationCallCodegen.Contains('expressionIndex -> emitInterpolationOperation(', [StringComparison]::Ordinal) -or
    -not $operationControlCodegen.Contains('regionNodeIndex -> emitInterpolationOperation(', [StringComparison]::Ordinal) -or
    $interpolationCodegen.Contains('interpolationNeedsSharedBinaryEmitter node:', [StringComparison]::Ordinal)) {
    throw 'Interpolation operation emitter convergence lacks current source, build, or paired proof'
}
foreach ($receiptPath in $operationConvergence.retainedNegativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $operationConvergence.selfhostCompilerSha256) {
        throw "Interpolation operation emitter negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $operationExact 4 $operationConvergence.selfhostCompilerSha256

$streamCallbackType = Get-Content -LiteralPath (Join-Path $root $contract.streamCallbackTypeEvidence) -Raw | ConvertFrom-Json
$streamCallbackSource = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.sourceComparison) -Raw | ConvertFrom-Json
$streamCallbackBaseline = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.baselinePair) -Raw | ConvertFrom-Json
$streamCallbackBuild = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.selfhostBuild) -Raw | ConvertFrom-Json
$streamCallbackFocused = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.focusedPositivePair) -Raw | ConvertFrom-Json
$streamCallbackRetained = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.retainedPositivePair) -Raw | ConvertFrom-Json
$streamCallbackExact = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.retainedNegativeExact) -Raw | ConvertFrom-Json
$streamCallbackContract = Get-Content -LiteralPath (Join-Path $root $streamCallbackType.fullContract) -Raw | ConvertFrom-Json
$streamCallbackCompiler = Join-Path (Split-Path -Parent (Join-Path $root $streamCallbackType.selfhostBuild)) 'compiler.exe'
$streamCallbackLlChecks = $streamObservedFixtures['1983-interpolation-stream-role-arithmetic-width']
if ($streamCallbackType.status -cne 'passed' -or $streamCallbackType.semanticPhaseClosed -or
    $streamCallbackType.focusedPassed -cne '1/1' -or $streamCallbackType.retainedPassed -cne '8/8' -or
    $streamCallbackSource.status -cne 'source-compared-before-selfhost-change' -or
    $streamCallbackBaseline.status -cne 'failed' -or $streamCallbackBaseline.completed -ne 0 -or
    $streamCallbackBuild.status -cne 'passed' -or $streamCallbackBuild.compilerSha256 -cne $streamCallbackType.selfhostCompilerSha256 -or
    $streamCallbackFocused.status -cne 'passed' -or $streamCallbackFocused.completed -ne 1 -or $streamCallbackFocused.total -ne 1 -or -not $streamCallbackFocused.inputStable -or
    $streamCallbackRetained.status -cne 'passed' -or $streamCallbackRetained.completed -ne 8 -or $streamCallbackRetained.total -ne 8 -or -not $streamCallbackRetained.inputStable -or
    $streamCallbackContract.status -cne 'passed' -or $streamCallbackContract.compilerSha256 -cne $streamCallbackType.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $streamCallbackContract.log) -Algorithm SHA256).Hash -cne $streamCallbackContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $streamCallbackCompiler -Algorithm SHA256).Hash -cne $streamCallbackType.selfhostCompilerSha256 -or
    -not $streamCallbackLlChecks['callback-sign-extension'] -or
    -not $interpolationCodegen.Contains('context -> emitterContext.streamCallbackInput(streamPipeline, streamSourceModule, node.symbol) => callbackInput', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('nodeIndex -> interpolationNodeTypeId(nodes, sourceModule, ownerIndex, beforeIndex, context, state) => roleTypeId', [StringComparison]::Ordinal)) {
    throw 'Interpolation stream callback type lacks current source, LLVM, or paired proof'
}
foreach ($receiptPath in $streamCallbackType.retainedNegativePairs) {
    $negative = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $streamCallbackType.selfhostCompilerSha256) {
        throw "Interpolation stream callback type negative pair invalid: $receiptPath"
    }
}
Assert-ExactStderrReport $streamCallbackExact 4 $streamCallbackType.selfhostCompilerSha256

$streamRoleSemantic = Get-Content -LiteralPath (Join-Path $root $contract.streamRoleSemanticArithmeticEvidence) -Raw | ConvertFrom-Json
$streamRoleSource = Get-Content -LiteralPath (Join-Path $root $streamRoleSemantic.sourceComparison) -Raw | ConvertFrom-Json
$streamRoleBuild = Get-Content -LiteralPath (Join-Path $root $streamRoleSemantic.selfhostBuild) -Raw | ConvertFrom-Json
$streamRoleContract = Get-Content -LiteralPath (Join-Path $root $streamRoleSemantic.fullContract) -Raw | ConvertFrom-Json
$streamRoleFocused = Get-Content -LiteralPath (Join-Path $root $streamRoleSemantic.focusedNegativePair) -Raw | ConvertFrom-Json
$streamRoleRetained = @($streamRoleSemantic.retainedPositivePairs | ForEach-Object {
    Get-Content -LiteralPath (Join-Path $root $_) -Raw | ConvertFrom-Json
})
$streamRoleCompiler = Join-Path (Split-Path -Parent (Join-Path $root $streamRoleSemantic.selfhostBuild)) 'compiler.exe'
$streamRolePairDirectory = Split-Path -Parent (Join-Path $root $streamRoleSemantic.focusedNegativePair)
$streamRoleManagedStderr = [IO.File]::ReadAllText((Join-Path $streamRolePairDirectory 'managed.stderr.txt')).Replace("`r`n", "`n")
$streamRoleSelfhostStderr = [IO.File]::ReadAllText((Join-Path $streamRolePairDirectory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
if ($streamRoleSemantic.status -cne 'passed' -or $streamRoleSemantic.semanticPhaseClosed -or
    $streamRoleSemantic.focusedPassed -cne '1/1' -or $streamRoleSemantic.retainedPassed -cne '3/3' -or
    $streamRoleSource.status -cne 'source-compared-before-selfhost-build' -or
    $streamRoleBuild.status -cne 'passed' -or $streamRoleBuild.compilerSha256 -cne $streamRoleSemantic.selfhostCompilerSha256 -or
    $streamRoleContract.status -cne 'passed' -or $streamRoleContract.compilerSha256 -cne $streamRoleSemantic.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $streamRoleContract.log) -Algorithm SHA256).Hash -cne $streamRoleContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $streamRoleCompiler -Algorithm SHA256).Hash -cne $streamRoleSemantic.selfhostCompilerSha256 -or
    $streamRoleFocused.state -cne 'passed' -or -not $streamRoleFocused.inputsStable -or
    $streamRoleFocused.selfhostCompilerSha256 -cne $streamRoleSemantic.selfhostCompilerSha256 -or
    $streamRoleManagedStderr -cne $streamRoleSelfhostStderr -or
    -not $streamRoleManagedStderr.Contains("operands of '+' must have the same numeric type; left is UInt64, right is Int", [StringComparison]::Ordinal) -or
    $streamRoleRetained.Count -ne 2 -or
    $streamRoleRetained[0].status -cne 'passed' -or $streamRoleRetained[0].completed -ne 1 -or
    $streamRoleRetained[1].status -cne 'passed' -or $streamRoleRetained[1].completed -ne 2 -or
    @($streamRoleRetained | Where-Object { -not $_.inputStable -or (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $_.inputHashesStart -LiteralPath $streamRoleCompiler) -cne $streamRoleSemantic.selfhostCompilerSha256 }).Count -ne 0 -or
    -not ([IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/expression_type_ids.slg')).Contains('streamRoleTypeBySymbol: [Int; ~]', [StringComparison]::Ordinal))) {
    throw 'Interpolation stream callback semantic arithmetic lacks source, compiler, or paired proof'
}

$streamComparison = Get-Content -LiteralPath (Join-Path $root $contract.streamRoleSemanticComparisonEvidence) -Raw | ConvertFrom-Json
$streamComparisonSource = Get-Content -LiteralPath (Join-Path $root $streamComparison.sourceComparison) -Raw | ConvertFrom-Json
$streamComparisonBuild = Get-Content -LiteralPath (Join-Path $root $streamComparison.selfhostBuild) -Raw | ConvertFrom-Json
$streamComparisonContract = Get-Content -LiteralPath (Join-Path $root $streamComparison.fullContract) -Raw | ConvertFrom-Json
$streamComparisonFocused = Get-Content -LiteralPath (Join-Path $root $streamComparison.focusedNegativePair) -Raw | ConvertFrom-Json
$streamComparisonPositive = Get-Content -LiteralPath (Join-Path $root $streamComparison.retainedPositivePair) -Raw | ConvertFrom-Json
$streamComparisonTextPositive = Get-Content -LiteralPath (Join-Path $root $streamComparison.retainedTextPositivePair) -Raw | ConvertFrom-Json
$streamComparisonCompiler = Join-Path (Split-Path -Parent (Join-Path $root $streamComparison.selfhostBuild)) 'compiler.exe'
$streamComparisonSourceCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
$streamComparisonNegatives = @($streamComparison.focusedNegativePair) + @($streamComparison.retainedNegativePairs)
$streamComparisonExact = @($streamComparisonNegatives | ForEach-Object {
    $receipt = Get-Content -LiteralPath (Join-Path $root $_) -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent (Join-Path $root $_)
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    $receipt.state -ceq 'passed' -and $receipt.inputsStable -and
        $receipt.selfhostCompilerSha256 -ceq $streamComparison.selfhostCompilerSha256 -and
        $managedStderr -ceq $selfhostStderr
})
if ($streamComparison.status -cne 'passed' -or $streamComparison.semanticPhaseClosed -or
    $streamComparison.focusedPassed -cne '1/1' -or $streamComparison.retainedNegativePassed -cne '3/3' -or
    $streamComparison.retainedPositivePassed -cne '5/5' -or
    $streamComparisonSource.status -cne 'source-compared-before-selfhost-change' -or
    $streamComparisonBuild.status -cne 'passed' -or $streamComparisonBuild.compilerSha256 -cne $streamComparison.selfhostCompilerSha256 -or
    $streamComparisonContract.status -cne 'passed' -or $streamComparisonContract.compilerSha256 -cne $streamComparison.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $streamComparisonContract.log) -Algorithm SHA256).Hash -cne $streamComparisonContract.logSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $streamComparisonCompiler -Algorithm SHA256).Hash -cne $streamComparison.selfhostCompilerSha256 -or
    $streamComparisonFocused.state -cne 'passed' -or $streamComparisonExact.Count -ne 4 -or
    @($streamComparisonExact | Where-Object { -not $_ }).Count -ne 0 -or
    $streamComparisonPositive.status -cne 'passed' -or $streamComparisonPositive.completed -ne 4 -or
    $streamComparisonPositive.total -ne 4 -or -not $streamComparisonPositive.inputStable -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $streamComparisonPositive.inputHashesStart -LiteralPath $streamComparisonCompiler) -cne $streamComparison.selfhostCompilerSha256 -or
    $streamComparisonTextPositive.status -cne 'passed' -or $streamComparisonTextPositive.completed -ne 1 -or
    $streamComparisonTextPositive.total -ne 1 -or -not $streamComparisonTextPositive.inputStable -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $streamComparisonTextPositive.inputHashesStart -LiteralPath $streamComparisonCompiler) -cne $streamComparison.selfhostCompilerSha256 -or
    -not $streamComparisonSourceCode.Contains('comparisonDecisionForOperands', [StringComparison]::Ordinal) -or
    -not $streamComparisonSourceCode.Contains('arithmeticDecisionForOperands', [StringComparison]::Ordinal) -or
    -not $streamComparisonSourceCode.Contains('binary.opcode -> comparisonDecisionForOperands(operands) -> return', [StringComparison]::Ordinal)) {
    throw 'Interpolation stream callback semantic comparison lacks source, compiler, or paired proof'
}

$streamRoleCommon = Get-Content -LiteralPath (Join-Path $root $contract.streamRoleCommonTypeEvidence) -Raw | ConvertFrom-Json
$streamRoleCommonSource = Get-Content -LiteralPath (Join-Path $root $streamRoleCommon.sourceComparison) -Raw | ConvertFrom-Json
$streamRoleCommonBuild = Get-Content -LiteralPath (Join-Path $root $streamRoleCommon.selfhostBuild) -Raw | ConvertFrom-Json
$streamRoleCommonFocused = Get-Content -LiteralPath (Join-Path $root $streamRoleCommon.focusedNegativePair) -Raw | ConvertFrom-Json
$streamRoleCommonPositive = Get-Content -LiteralPath (Join-Path $root $streamRoleCommon.retainedPositivePair) -Raw | ConvertFrom-Json
$streamRoleCommonCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
$streamRoleCommonCompiler = Join-Path (Split-Path -Parent (Join-Path $root $streamRoleCommon.selfhostBuild)) 'compiler.exe'
if ($streamRoleCommon.status -cne 'passed' -or $streamRoleCommon.semanticPhaseClosed -or
    $streamRoleCommon.focusedPassed -cne '1/1' -or $streamRoleCommon.retainedNegativePassed -cne '2/2' -or
    $streamRoleCommon.retainedPositivePassed -cne '5/5' -or -not $streamRoleCommon.focusedExactStderr -or
    $streamRoleCommonSource.status -cne 'source-compared-before-selfhost-change' -or
    $streamRoleCommonBuild.status -cne 'passed' -or -not $streamRoleCommonBuild.inputsStable -or
    $streamRoleCommonBuild.compilerSha256 -cne $streamRoleCommon.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $streamRoleCommonCompiler -Algorithm SHA256).Hash -cne $streamRoleCommon.selfhostCompilerSha256 -or
    $streamRoleCommonFocused.state -cne 'passed' -or -not $streamRoleCommonFocused.inputsStable -or
    $streamRoleCommonPositive.status -cne 'passed' -or $streamRoleCommonPositive.completed -ne 5 -or
    $streamRoleCommonPositive.total -ne 5 -or -not $streamRoleCommonPositive.inputStable -or
    -not $streamRoleCommonCode.Contains('bindingFacts.interpolationLexicalTypeByNode[nodeIndex] -> return', [StringComparison]::Ordinal) -or
    $streamRoleCommonCode.Contains('streamBinaryOperands prepared:', [StringComparison]::Ordinal)) {
    throw 'Stream role common interpolation type lacks current structural or paired proof'
}
foreach ($receiptPath in @($streamRoleCommon.focusedNegativePair) + @($streamRoleCommon.retainedNegativePairs)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent (Join-Path $root $receiptPath)
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.selfhostCompilerSha256 -cne $streamRoleCommon.selfhostCompilerSha256 -or
        $managedStderr -cne $selfhostStderr) {
        throw "Stream role common interpolation type exact negative invalid: $receiptPath"
    }
}

$flowResult = Get-Content -LiteralPath (Join-Path $root $contract.intrinsicFlowResultTypeEvidence) -Raw | ConvertFrom-Json
$flowResultSource = Get-Content -LiteralPath (Join-Path $root $flowResult.sourceComparison) -Raw | ConvertFrom-Json
$flowResultManagedNegative = Get-Content -LiteralPath (Join-Path $root $flowResult.managedNegativeFirst) -Raw | ConvertFrom-Json
$flowResultManagedPositive = Get-Content -LiteralPath (Join-Path $root $flowResult.managedPositiveFirst) -Raw | ConvertFrom-Json
$flowResultBuild = Get-Content -LiteralPath (Join-Path $root $flowResult.selfhostBuild) -Raw | ConvertFrom-Json
$flowResultPositive = Get-Content -LiteralPath (Join-Path $root $flowResult.positivePair) -Raw | ConvertFrom-Json
$flowResultCompiler = Join-Path (Split-Path -Parent (Join-Path $root $flowResult.selfhostBuild)) 'compiler.exe'
$flowResultCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
if ($flowResult.status -cne 'passed' -or $flowResult.semanticPhaseClosed -or
    $flowResult.focusedPassed -cne '2/2' -or $flowResult.retainedNegativePassed -cne '2/2' -or
    $flowResult.retainedPositivePassed -cne '2/2' -or -not $flowResult.focusedExactStderr -or
    $flowResultSource.status -cne 'source-compared-before-selfhost-change' -or
    $flowResultManagedNegative.status -cne 'passed' -or -not $flowResultManagedNegative.inputStable -or
    $flowResultManagedPositive.status -cne 'passed' -or -not $flowResultManagedPositive.inputStable -or
    $flowResultBuild.status -cne 'passed' -or -not $flowResultBuild.inputsStable -or
    $flowResultBuild.compilerSha256 -cne $flowResult.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $flowResultCompiler -Algorithm SHA256).Hash -cne $flowResult.selfhostCompilerSha256 -or
    $flowResultPositive.status -cne 'passed' -or $flowResultPositive.completed -ne 3 -or
    $flowResultPositive.total -ne 3 -or -not $flowResultPositive.inputStable -or
    -not $flowResultCode.Contains('node.kind == 6 -> if {', [StringComparison]::Ordinal) -or
    -not $flowResultCode.Contains('prepared -> intrinsicFlowResultBuiltinSymbol(plan, bindingFacts, prepared.interpolations, ir, types, fields, sourceModule, nodeIndex) => builtin', [StringComparison]::Ordinal)) {
    throw 'Interpolation flow result type lacks C# first, source, or paired proof'
}
foreach ($receiptPath in @($flowResult.focusedNegativePair) + @($flowResult.retainedNegativePairs)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent (Join-Path $root $receiptPath)
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.selfhostCompilerSha256 -cne $flowResult.selfhostCompilerSha256 -or
        $managedStderr -cne $selfhostStderr) {
        throw "Interpolation flow result type exact negative invalid: $receiptPath"
    }
}

$methodResult = Get-Content -LiteralPath (Join-Path $root $contract.methodFlowResultTypeEvidence) -Raw | ConvertFrom-Json
$methodResultSource = Get-Content -LiteralPath (Join-Path $root $methodResult.sourceComparison) -Raw | ConvertFrom-Json
$methodResultManagedNegative = Get-Content -LiteralPath (Join-Path $root $methodResult.managedNegativeFirst) -Raw | ConvertFrom-Json
$methodResultManagedPositive = Get-Content -LiteralPath (Join-Path $root $methodResult.managedPositiveFirst) -Raw | ConvertFrom-Json
$methodResultBuild = Get-Content -LiteralPath (Join-Path $root $methodResult.selfhostBuild) -Raw | ConvertFrom-Json
$methodResultPositive = Get-Content -LiteralPath (Join-Path $root $methodResult.positivePair) -Raw | ConvertFrom-Json
$methodResultCompiler = Join-Path (Split-Path -Parent (Join-Path $root $methodResult.selfhostBuild)) 'compiler.exe'
$methodResultCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
if ($methodResult.status -cne 'passed' -or $methodResult.semanticPhaseClosed -or
    $methodResult.focusedPassed -cne '2/2' -or $methodResult.retainedNegativePassed -cne '2/2' -or
    $methodResult.retainedPositivePassed -cne '2/2' -or -not $methodResult.focusedExactStderr -or
    $methodResultSource.status -cne 'source-compared-before-selfhost-change' -or
    $methodResultManagedNegative.status -cne 'passed' -or
    $methodResultManagedPositive.status -cne 'passed' -or -not $methodResultManagedPositive.warningFree -or
    -not $methodResultManagedPositive.inputStable -or
    $methodResultBuild.status -cne 'passed' -or -not $methodResultBuild.inputsStable -or
    $methodResultBuild.compilerSha256 -cne $methodResult.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $methodResultCompiler -Algorithm SHA256).Hash -cne $methodResult.selfhostCompilerSha256 -or
    $methodResultPositive.status -cne 'passed' -or $methodResultPositive.completed -ne 3 -or
    $methodResultPositive.total -ne 3 -or -not $methodResultPositive.inputStable -or
    -not $methodResultCode.Contains('flowCallTargetAt prepared:', [StringComparison]::Ordinal) -or
    -not $methodResultCode.Contains('prepared -> flowCallTargetAt(plan, bindingFacts, prepared.interpolations, ir, types, fields, nodeIndex, false) => target', [StringComparison]::Ordinal) -or
    -not $methodResultCode.Contains('prepared -> flowCallTargetAt(plan, bindingFacts, nodes, ir, types, fields, nodeIndex!, false) => target', [StringComparison]::Ordinal)) {
    throw 'Interpolation method result type lacks C# first, source, or paired proof'
}
foreach ($receiptPath in @($methodResult.focusedNegativePair) + @($methodResult.retainedNegativePairs)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent (Join-Path $root $receiptPath)
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.selfhostCompilerSha256 -cne $methodResult.selfhostCompilerSha256 -or
        $managedStderr -cne $selfhostStderr) {
        throw "Interpolation method result type exact negative invalid: $receiptPath"
    }
}

$nominalIntrinsic = Get-Content -LiteralPath (Join-Path $root $contract.nominalIntrinsicMethodResultTypeEvidence) -Raw | ConvertFrom-Json
$nominalSource = Get-Content -LiteralPath (Join-Path $root $nominalIntrinsic.sourceComparison) -Raw | ConvertFrom-Json
$nominalManaged = Get-Content -LiteralPath (Join-Path $root $nominalIntrinsic.managedFirst) -Raw | ConvertFrom-Json
$nominalBuild = Get-Content -LiteralPath (Join-Path $root $nominalIntrinsic.selfhostBuild) -Raw | ConvertFrom-Json
$nominalPositive = Get-Content -LiteralPath (Join-Path $root $nominalIntrinsic.positivePair) -Raw | ConvertFrom-Json
$nominalCompiler = Join-Path (Split-Path -Parent (Join-Path $root $nominalIntrinsic.selfhostBuild)) 'compiler.exe'
if ($nominalIntrinsic.status -cne 'passed' -or $nominalIntrinsic.semanticPhaseClosed -or
    $nominalIntrinsic.focusedPassed -cne '2/2' -or $nominalIntrinsic.retainedNegativePassed -cne '2/2' -or
    $nominalIntrinsic.retainedPositivePassed -cne '3/3' -or -not $nominalIntrinsic.focusedExactStderr -or
    $nominalSource.status -cne 'source-compared-before-selfhost-change' -or
    $nominalManaged.status -cne 'passed' -or -not $nominalManaged.warningFree -or -not $nominalManaged.inputStable -or
    $nominalBuild.status -cne 'passed' -or -not $nominalBuild.inputsStable -or
    $nominalBuild.compilerSha256 -cne $nominalIntrinsic.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $nominalCompiler -Algorithm SHA256).Hash -cne $nominalIntrinsic.selfhostCompilerSha256 -or
    $nominalPositive.status -cne 'passed' -or $nominalPositive.completed -ne 4 -or
    $nominalPositive.total -ne 4 -or -not $nominalPositive.inputStable -or
    -not $methodResultCode.Contains('prepared -> methodFlowFallback(plan, bindingFacts, ir, types, fields, nodeIndex) => methodFallback', [StringComparison]::Ordinal) -or
    -not $methodResultCode.Contains('prepared -> flowCallTargetAt(plan, bindingFacts, prepared.interpolations, ir, types, fields, nodeIndex, true) => target', [StringComparison]::Ordinal) -or
    -not $methodResultCode.Contains('node.kind == 6 or node.kind == 8', [StringComparison]::Ordinal)) {
    throw 'Nominal intrinsic-name result type lacks C# first, source, or paired proof'
}
foreach ($receiptPath in @($nominalIntrinsic.focusedNegativePair) + @($nominalIntrinsic.retainedNegativePairs)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent (Join-Path $root $receiptPath)
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.selfhostCompilerSha256 -cne $nominalIntrinsic.selfhostCompilerSha256 -or
        $managedStderr -cne $selfhostStderr) {
        throw "Nominal intrinsic-name result type exact negative invalid: $receiptPath"
    }
}

$methodArithmetic = Get-Content -LiteralPath (Join-Path $root $contract.methodScalarArithmeticEvidence) -Raw | ConvertFrom-Json
$methodArithmeticSource = Get-Content -LiteralPath (Join-Path $root $methodArithmetic.sourceComparison) -Raw | ConvertFrom-Json
$methodArithmeticManaged = Get-Content -LiteralPath (Join-Path $root $methodArithmetic.managedFirst) -Raw | ConvertFrom-Json
$methodArithmeticBaseline = Get-Content -LiteralPath (Join-Path $root $methodArithmetic.selfhostBaseline) -Raw | ConvertFrom-Json
$methodArithmeticBuild = Get-Content -LiteralPath (Join-Path $root $methodArithmetic.selfhostBuild) -Raw | ConvertFrom-Json
$methodArithmeticPositive = Get-Content -LiteralPath (Join-Path $root $methodArithmetic.positivePair) -Raw | ConvertFrom-Json
$methodArithmeticCompiler = Join-Path (Split-Path -Parent (Join-Path $root $methodArithmetic.selfhostBuild)) 'compiler.exe'
if ($methodArithmetic.status -cne 'passed' -or $methodArithmetic.semanticPhaseClosed -or
    $methodArithmetic.focusedPassed -cne '2/2' -or $methodArithmetic.retainedNegativePassed -cne '2/2' -or
    $methodArithmetic.retainedPositivePassed -cne '2/2' -or -not $methodArithmetic.focusedExactStderr -or
    $methodArithmeticSource.status -cne 'source-compared-before-selfhost-change' -or
    $methodArithmeticManaged.negativeExit -ne 1 -or $methodArithmeticManaged.positiveBuildExit -ne 0 -or
    $methodArithmeticManaged.positiveRunExit -ne 0 -or
    $methodArithmeticBaseline.negativeExit -ne 1 -or
    $methodArithmeticBaseline.negativeStderr -notlike '*left operand of*compatible numeric value*' -or
    $methodArithmeticBuild.status -cne 'passed' -or -not $methodArithmeticBuild.inputsStable -or
    $methodArithmeticBuild.compilerSha256 -cne $methodArithmetic.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $methodArithmeticCompiler -Algorithm SHA256).Hash -cne $methodArithmetic.selfhostCompilerSha256 -or
    $methodArithmeticPositive.status -cne 'passed' -or $methodArithmeticPositive.completed -ne 3 -or
    $methodArithmeticPositive.total -ne 3 -or -not $methodArithmeticPositive.inputStable -or
    -not $methodResultCode.Contains('node.kind == 9 or node.kind == 10 or node.kind == 11', [StringComparison]::Ordinal)) {
    throw 'Interpolation method arithmetic lacks C# first, source, or paired proof'
}
foreach ($receiptPath in @($methodArithmetic.focusedNegativePair) + @($methodArithmetic.retainedNegativePairs)) {
    $receipt = Get-Content -LiteralPath (Join-Path $root $receiptPath) -Raw | ConvertFrom-Json
    $directory = Split-Path -Parent (Join-Path $root $receiptPath)
    $managedStderr = [IO.File]::ReadAllText((Join-Path $directory 'managed.stderr.txt')).Replace("`r`n", "`n")
    $selfhostStderr = [IO.File]::ReadAllText((Join-Path $directory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
    if ($receipt.state -cne 'passed' -or -not $receipt.inputsStable -or
        $receipt.selfhostCompilerSha256 -cne $methodArithmetic.selfhostCompilerSha256 -or
        $managedStderr -cne $selfhostStderr) {
        throw "Interpolation method arithmetic exact negative invalid: $receiptPath"
    }
}

$lexicalFoundation = Get-Content -LiteralPath (Join-Path $root $contract.preIrOrdinaryLexicalFoundationEvidence) -Raw | ConvertFrom-Json
$lexicalSource = Get-Content -LiteralPath (Join-Path $root $lexicalFoundation.sourceComparison) -Raw | ConvertFrom-Json
$lexicalManaged = Get-Content -LiteralPath (Join-Path $root $lexicalFoundation.managedFirst) -Raw | ConvertFrom-Json
$lexicalBuild = Get-Content -LiteralPath (Join-Path $root $lexicalFoundation.currentBuild) -Raw | ConvertFrom-Json
$lexicalPair = Get-Content -LiteralPath (Join-Path $root $lexicalFoundation.currentPairedProof) -Raw | ConvertFrom-Json
$lexicalContract = Get-Content -LiteralPath (Join-Path $root $lexicalFoundation.fullContract) -Raw | ConvertFrom-Json
$lexicalCompiler = Join-Path (Split-Path -Parent (Join-Path $root $lexicalFoundation.currentBuild)) 'compiler.exe'
$lexicalCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/expression_type_ids.slg'))
if ($lexicalFoundation.status -cne 'passed-foundation' -or
    $lexicalFoundation.preIrConsumerIntegrated -or $lexicalFoundation.semanticPhaseClosed -or
    $lexicalFoundation.semanticOwnedKindsUnchanged -cne '3/12' -or
    $lexicalFoundation.focusedPassed -cne '2/2' -or
    $lexicalSource.status -cne 'source-compared-before-selfhost-change' -or
    $lexicalManaged.buildExit -ne 0 -or $lexicalManaged.runExit -ne 0 -or
    $lexicalManaged.runStdout -cne "7,3`n" -or
    $lexicalBuild.status -cne 'passed' -or -not $lexicalBuild.inputsStable -or
    $lexicalBuild.compilerSha256 -cne $lexicalFoundation.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $lexicalCompiler -Algorithm SHA256).Hash -cne $lexicalFoundation.selfhostCompilerSha256 -or
    $lexicalPair.status -cne 'passed' -or $lexicalPair.completed -ne 2 -or
    $lexicalPair.total -ne 2 -or -not $lexicalPair.inputStable -or
    $lexicalPair.timeoutMilliseconds -ne 300000 -or
    $lexicalContract.status -cne 'passed' -or
    $lexicalContract.compilerSha256 -cne $lexicalFoundation.selfhostCompilerSha256 -or
    -not $lexicalCode.Contains('lexicalBindingTypeBySymbol: [Int; ~]', [StringComparison]::Ordinal) -or
    -not $lexicalCode.Contains('valueAst.parent => bindingAstIndex!', [StringComparison]::Ordinal) -or
    -not $lexicalCode.Contains('ordinaryBindingSymbolByAst![bindingRange.astStart + bindingAstIndex!] => ownerSymbolIndex!', [StringComparison]::Ordinal) -or
    -not $lexicalCode.Contains('valueExpression.typeId => lexicalBindingTypeBySymbol![ownerSymbolIndex!]', [StringComparison]::Ordinal)) {
    throw 'Pre-IR ordinary lexical binding type foundation lacks current source or focused proof'
}

$lexicalConsumer = Get-Content -LiteralPath (Join-Path $root $contract.preIrOrdinaryLexicalConsumerEvidence) -Raw | ConvertFrom-Json
$lexicalConsumerSource = Get-Content -LiteralPath (Join-Path $root $lexicalConsumer.sourceComparison) -Raw | ConvertFrom-Json
$lexicalConsumerBuild = Get-Content -LiteralPath (Join-Path $root $lexicalConsumer.selfhostBuild) -Raw | ConvertFrom-Json
$lexicalConsumerPair = Get-Content -LiteralPath (Join-Path $root $lexicalConsumer.focusedPair) -Raw | ConvertFrom-Json
$lexicalConsumerContract = if ($lexicalConsumer.status -ceq 'passed-integration') {
    Get-Content -LiteralPath (Join-Path $root $lexicalConsumer.fullContract) -Raw | ConvertFrom-Json
} else { $null }
$lexicalConsumerCompiler = Join-Path (Split-Path -Parent (Join-Path $root $lexicalConsumer.selfhostBuild)) 'compiler.exe'
$lexicalInferenceCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
$lexicalPrepareCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/context_prepare.slg'))
if ($lexicalConsumer.status -cnotin @('pending-contract', 'passed-integration') -or
    -not $lexicalConsumer.preIrConsumerIntegrated -or $lexicalConsumer.semanticPhaseClosed -or
    $lexicalConsumer.semanticOwnedKindsUnchanged -cne '3/12' -or
    $lexicalConsumer.focusedPassed -cne '2/2' -or
    $lexicalConsumerSource.status -cne 'source-compared-before-selfhost-change' -or
    $lexicalConsumerBuild.status -cne 'passed' -or -not $lexicalConsumerBuild.inputsStable -or
    $lexicalConsumerBuild.compilerSha256 -cne $lexicalConsumer.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $lexicalConsumerCompiler -Algorithm SHA256).Hash -cne $lexicalConsumer.selfhostCompilerSha256 -or
    $lexicalConsumerPair.status -cne 'passed' -or $lexicalConsumerPair.completed -ne 2 -or
    $lexicalConsumerPair.total -ne 2 -or -not $lexicalConsumerPair.inputStable -or
    ($lexicalConsumer.status -ceq 'passed-integration' -and
        ($lexicalConsumerContract.status -cne 'passed' -or
        $lexicalConsumerContract.compilerSha256 -cne $lexicalConsumer.selfhostCompilerSha256)) -or
    -not $lexicalInferenceCode.Contains('bindingFacts.interpolationLexicalTypeByNode[nodeIndex] -> return', [StringComparison]::Ordinal) -or
    -not $lexicalPrepareCode.Contains('interpolationInference.classifyIntrinsicFlowReceivers(streamPlan, recursiveTypes!,', [StringComparison]::Ordinal)) {
    throw 'Pre-IR ordinary lexical binding type consumer lacks current source or focused proof'
}

$directEach = Get-Content -LiteralPath (Join-Path $root $contract.preIrDirectEachRoleEvidence) -Raw | ConvertFrom-Json
$directEachSource = Get-Content -LiteralPath (Join-Path $root $directEach.sourceComparison) -Raw | ConvertFrom-Json
$directEachManaged = Get-Content -LiteralPath (Join-Path $root $directEach.managedFirst) -Raw | ConvertFrom-Json
$directEachManagedTypes = Get-Content -LiteralPath (Join-Path $root $directEach.managedSourceTypesFirst) -Raw | ConvertFrom-Json
$directEachBuild = Get-Content -LiteralPath (Join-Path $root $directEach.selfhostBuild) -Raw | ConvertFrom-Json
$directEachPositive = Get-Content -LiteralPath (Join-Path $root $directEach.focusedPositivePair) -Raw | ConvertFrom-Json
$directEachNegative = Get-Content -LiteralPath (Join-Path $root $directEach.focusedNegativePair) -Raw | ConvertFrom-Json
$directEachContract = if ($directEach.status -ceq 'passed-integration') {
    Get-Content -LiteralPath (Join-Path $root $directEach.fullContract) -Raw | ConvertFrom-Json
} else { $null }
$directEachCompiler = Join-Path (Split-Path -Parent (Join-Path $root $directEach.selfhostBuild)) 'compiler.exe'
$directEachProducerCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/expression_type_ids.slg'))
$directEachConsumerCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/semantic/interpolation_inference.slg'))
$directEachPrepareCode = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/context_prepare.slg'))
$directEachNegativeDirectory = Split-Path -Parent (Join-Path $root $directEach.focusedNegativePair)
$directEachManagedStderr = [IO.File]::ReadAllText((Join-Path $directEachNegativeDirectory 'managed.stderr.txt')).Replace("`r`n", "`n")
$directEachSelfhostStderr = [IO.File]::ReadAllText((Join-Path $directEachNegativeDirectory 'selfhost.stderr.txt')).Replace("`r`n", "`n")
if ($directEach.status -cnotin @('pending-contract', 'passed-integration') -or
    -not $directEach.preIrConsumerIntegrated -or $directEach.semanticPhaseClosed -or
    $directEach.semanticOwnedKindsUnchanged -cne '3/12' -or
    $directEach.focusedPositivePassed -cne '3/3' -or $directEach.focusedNegativePassed -cne '1/1' -or
    $directEachSource.status -cne 'source-compared-before-selfhost-change' -or
    $directEachManaged.status -cne 'passed' -or $directEachManaged.buildExit -ne 0 -or
    $directEachManaged.runExit -ne 0 -or -not $directEachManaged.inputStable -or
    $directEachManagedTypes.status -cne 'passed' -or $directEachManagedTypes.buildExit -ne 0 -or
    $directEachManagedTypes.runExit -ne 0 -or
    [IO.File]::ReadAllText((Join-Path $root $directEach.preIrBaselineProbe)).Replace("`r`n", "`n") -cne "1`n0`n" -or
    [IO.File]::ReadAllText((Join-Path $root $directEach.preIrCurrentProbe)).Replace("`r`n", "`n") -cne "1`n0`n1`n" -or
    $directEachBuild.status -cne 'passed' -or -not $directEachBuild.inputsStable -or
    $directEachBuild.compilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $directEachCompiler -Algorithm SHA256).Hash -cne $directEach.selfhostCompilerSha256 -or
    $directEachPositive.status -cne 'passed' -or -not $directEachPositive.inputStable -or
    $directEachPositive.completed -ne 3 -or $directEachPositive.total -ne 3 -or
    $directEachNegative.state -cne 'passed' -or -not $directEachNegative.inputsStable -or
    $directEachNegative.selfhostCompilerSha256 -cne $directEach.selfhostCompilerSha256 -or
    $directEachManagedStderr -cne $directEachSelfhostStderr -or
    ($directEach.status -ceq 'passed-integration' -and
        ($directEachContract.status -cne 'passed' -or
        $directEachContract.compilerSha256 -cne $directEach.selfhostCompilerSha256)) -or
    -not $directEachProducerCode.Contains('directEachRoleTypeBySymbol: [Int; ~]', [StringComparison]::Ordinal) -or
    -not $directEachProducerCode.Contains('directEachSourceExpressionByAst![range.astStart + scope.astNode]', [StringComparison]::Ordinal) -or
    -not $directEachConsumerCode.Contains('bindingFacts.interpolationLexicalTypeByNode[nodeIndex] -> return', [StringComparison]::Ordinal) -or
    -not $directEachPrepareCode.Contains('interpolationInference.classifyIntrinsicFlowReceivers(streamPlan, recursiveTypes!,', [StringComparison]::Ordinal)) {
    throw 'Pre-IR direct each role type lacks current source, managed-first, or focused proof'
}

# A later proven unit supersedes only the source paths it actually changed.
# Keep each earlier receipt immutable while checking one current authority hash per path.
$preIrStreamRole = Get-Content -LiteralPath (Join-Path $root $contract.preIrStreamRoleEvidence) -Raw | ConvertFrom-Json
$preIrStreamBuild = Get-Content -LiteralPath (Join-Path $root $preIrStreamRole.selfhostBuild) -Raw | ConvertFrom-Json
$preIrStreamProbePair = Get-Content -LiteralPath (Join-Path $root $preIrStreamRole.preIrPair) -Raw | ConvertFrom-Json
$preIrStreamPositivePair = Get-Content -LiteralPath (Join-Path $root $preIrStreamRole.focusedPositivePair) -Raw | ConvertFrom-Json
$preIrStreamNegativePair = Get-Content -LiteralPath (Join-Path $root $preIrStreamRole.focusedNegativePair) -Raw | ConvertFrom-Json
$preIrStreamNegativeExact = Get-Content -LiteralPath (Join-Path $root $preIrStreamRole.focusedNegativeExact) -Raw | ConvertFrom-Json
if ($preIrStreamRole.status -cne 'passed-focused-phase-open' -or
    -not $preIrStreamRole.preIrConsumerIntegrated -or $preIrStreamRole.semanticPhaseClosed -or
    $preIrStreamRole.semanticOwnedKindsUnchanged -cne '3/12' -or
    $preIrStreamBuild.status -cne 'passed' -or
    $preIrStreamBuild.compilerSha256 -cne $preIrStreamRole.selfhostCompilerSha256 -or
    $preIrStreamProbePair.status -cne 'passed' -or $preIrStreamProbePair.completed -ne 1 -or
    $preIrStreamPositivePair.status -cne 'passed' -or $preIrStreamPositivePair.completed -ne 2 -or
    $preIrStreamNegativePair.state -cne 'passed' -or
    $preIrStreamNegativeExact.status -cne 'passed') {
    throw 'C572 pre-IR stream role evidence is incomplete'
}
$currentSourceHashes = @{}
foreach ($layer in @(
    $indexedArray.currentSourceHashes,
    $memberDirect.currentSourceHashes,
    $unaryDirect.currentSourceHashes,
    $preIrStreamRole.currentSourceHashes,
    $directEach.currentSourceHashes,
    $lexicalConsumer.currentSourceHashes,
    $methodArithmetic.currentSourceHashes,
    $nominalIntrinsic.currentSourceHashes,
    $methodResult.currentSourceHashes,
    $flowResult.currentSourceHashes,
    $streamRoleCommon.currentSourceHashes,
    $streamComparison.currentSourceHashes,
    $streamRoleSemantic.currentSourceHashes,
    $streamCallbackType.currentSourceHashes,
    $operationConvergence.currentSourceHashes,
    $floatComparison.currentSourceHashes,
    $textRoutes.currentSourceHashes,
    $arithmeticResult.currentSourceHashes,
    $comparisonResult.currentSourceHashes,
    $logicalResult.currentSourceHashes,
    $unaryUnit.currentSourceHashes,
    $nestedLogical.currentSourceHashes,
    $binaryLogical.currentSourceHashes,
    $binaryComparison.currentSourceHashes,
    $binaryArithmetic.currentSourceHashes,
    $bitSetContains.currentSourceHashes, $bitSetLength.currentSourceHashes, $bitSetTail.currentSourceHashes, $bitSetReference.currentSourceHashes, $bitSetCount.currentSourceHashes, $containerArity.currentSourceHashes, $containerUnit.currentSourceHashes, $receiverUnit.currentSourceHashes, $arityUnit.currentSourceHashes, $shellUnit.currentSourceHashes, $textUnit.currentSourceHashes,
    $capacityUnit.currentSourceHashes, $lengthUnit.currentSourceHashes,
    $negateUnit.currentSourceHashes, $notUnit.currentSourceHashes,
    $directEach.currentSourceHashes, $precedence.currentSourceHashes,
    $privateMethod.currentSourceHashes, $importedMethod.currentSourceHashes,
    $unknownBinding.sourceHashes)) {
    foreach ($property in $layer.PSObject.Properties) {
        if (-not $currentSourceHashes.ContainsKey($property.Name)) {
            $currentSourceHashes[$property.Name] = $property.Value
        }
    }
}
# Verification scripts are executed as verification tools; their bytes are not
# language compiler inputs. Keep the historical hash claim intact and validate
# the current script before excluding it from the compiler-source pair closure.
$verifiedVerificationSourceHashes = @{}
foreach ($relative in @($currentSourceHashes.Keys)) {
    if ([IO.Path]::GetExtension($relative) -cne '.ps1') { continue }
    $verifiedVerificationSourceHashes[$relative] = Invoke-InterpolationVerificationSource -Root $root -RelativePath $relative
}
$mismatchedSourcePaths = @(
foreach ($entry in $currentSourceHashes.GetEnumerator()) {
    if ($verifiedVerificationSourceHashes.ContainsKey($entry.Key)) { continue }
    if ((Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root $entry.Key) -Algorithm SHA256).Hash -cne $entry.Value) {
        $entry.Key
    }
}
)
$verifiedCurrentHashes = @{}
if ($mismatchedSourcePaths.Count -gt 0) {
    # Historical focused proofs keep their original hashes. Accept drift only
    # when a frozen current-source proof binds each changed compiler input to
    # the completed C# / selfhost suite pair; documentation remains pinned by
    # its own content hash. This does not claim whole-compiler parity.
    $currentProofPath = Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $contract.currentSourceProofEvidence
    $currentProof = Get-Content -LiteralPath $currentProofPath -Raw | ConvertFrom-Json
    if ($currentProof.schemaVersion -ne 2 -or $currentProof.status -cne 'passed' -or
        @($currentProof.sources).Count -ne $mismatchedSourcePaths.Count -or
        @($currentProof.sources.path | Sort-Object -Unique).Count -ne $mismatchedSourcePaths.Count -or
        @(Compare-Object @($mismatchedSourcePaths | Sort-Object) @($currentProof.sources.path | Sort-Object)).Count -ne 0 -or
        @(Compare-Object @($mismatchedSourcePaths | Sort-Object) @($currentProof.historicalDriftPaths | Sort-Object)).Count -ne 0) {
        throw "current interpolation source proof does not cover exact historical drift: $($mismatchedSourcePaths -join ', ')"
    }
    $currentPairPath = [IO.Path]::GetFullPath($currentProof.pairResult, $root)
    $currentPair = Get-Content -LiteralPath $currentPairPath -Raw | ConvertFrom-Json
    $currentManagedPath = [IO.Path]::GetFullPath($currentProof.managedResult, $root)
    $currentManaged = Get-Content -LiteralPath $currentManagedPath -Raw | ConvertFrom-Json
    $fixtureProofPath = Join-Path $root $currentProof.fixtureProof
    $fixtureProof = Get-Content -LiteralPath $fixtureProofPath -Raw | ConvertFrom-Json
    if ((Get-FileHash -LiteralPath $currentPairPath -Algorithm SHA256).Hash -cne $currentProof.pairResultSha256 -or
        (Get-FileHash -LiteralPath $currentManagedPath -Algorithm SHA256).Hash -cne $currentProof.managedResultSha256 -or
        (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $fixtureProofPath -Algorithm SHA256).Hash -cne $currentProof.fixtureProofSha256 -or
        $currentPair.status -cne 'passed' -or $currentPair.mode -cne 'paired' -or -not $currentPair.inputsStable -or -not $currentPair.processesStopped -or
        $currentPair.completed -ne 1 -or $currentPair.total -ne 1 -or
        $currentManaged.status -cne 'passed' -or $currentManaged.mode -cne 'managed' -or -not $currentManaged.inputsStable -or -not $currentManaged.processesStopped -or
        $currentManaged.completed -ne 1 -or $currentManaged.total -ne 1 -or
        $fixtureProof.status -cne 'passed' -or
        $fixtureProof.currentCompilerSha256 -cne $currentProof.selfhostCompilerSha256 -or
        @($fixtureProof.focusedSuiteProofs).Count -ne 1 -or
        [IO.Path]::GetFullPath($fixtureProof.focusedSuiteProofs[0].paired.path, $root) -cne $currentPairPath -or
        [IO.Path]::GetFullPath($fixtureProof.focusedSuiteProofs[0].managed.path, $root) -cne $currentManagedPath) {
        throw 'current interpolation source proof is not bound to the completed exact suite pair'
    }
    & python -X utf8 (Join-Path $PSScriptRoot 'verify-context-fixture-source-closure.py') --receipt $fixtureProofPath
    if ($LASTEXITCODE -ne 0) { throw 'Current original four context invariants or producer source proof is invalid' }
    foreach ($entry in $currentProof.sources) {
        $sourcePath = (Resolve-Path -LiteralPath (Join-Path $root $entry.path)).Path
        $actualHash = (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $sourcePath -Algorithm SHA256).Hash
        if ($actualHash -cne $entry.sha256) {
            throw "current interpolation source changed after proof: $($entry.path)"
        }
        $verifiedCurrentHashes[$entry.path] = $actualHash
        if ($entry.kind -ceq 'paired-source') {
            if ([IO.Path]::GetExtension($entry.path) -cnotin @('.slg', '.cs')) {
                throw "Invalid executable source identity kind: $($entry.path)"
            }
            $pairedHash = (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentPair.inputHashes -LiteralPath $sourcePath)
            $managedHash = (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentManaged.inputHashes -LiteralPath $sourcePath)
            if ($pairedHash -cne $actualHash -or $managedHash -cne $actualHash) {
                throw "current interpolation source was not a stable paired input: $($entry.path)"
            }
        } elseif ($entry.kind -cne 'document' -or
            $entry.path -cnotin @('docs/SPEC.md', 'docs/AI_SLG_BEST_PRACTICES.md')) {
            throw "unsupported current interpolation source proof kind: $($entry.kind)"
        }
    }
}
foreach ($proof in $unknownBinding.managedFirstProofs) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $proof) -PathType Leaf)) {
        throw "unknown interpolation binding C# first proof missing: $proof"
    }
}
foreach ($baselinePath in $unknownBinding.functionNameBaselines) {
    $baseline = Get-Content -LiteralPath (Join-Path $root $baselinePath) -Raw | ConvertFrom-Json
    if ($baseline.failureId -cne 'NEGATIVE_CHECK_FAILED' -or $baseline.selfhost.expectedInStderr) {
        throw "function-name baseline no longer records the original mismatch: $baselinePath"
    }
}
$localBaseline = Get-Content -LiteralPath (Join-Path $root $unknownBinding.localFunctionScopeBaseline) -Raw | ConvertFrom-Json
if ($localBaseline.failureId -cne 'NEGATIVE_CHECK_FAILED' -or $localBaseline.selfhost.expectedInStderr) {
    throw 'out-of-scope local function baseline no longer records the original mismatch'
}
Assert-ExactStderrReport $unknownExact 5 $unknownBinding.compilerSha256
Assert-ExactStderrReport $unknownRetained 9 $unknownBinding.compilerSha256
Assert-ExactStderrReport $unknownFunctionExact 3 $unknownBinding.compilerSha256
Assert-ExactStderrReport $unknownLocalExact 2 $unknownBinding.compilerSha256
$fractionalCharacter = Get-Content -LiteralPath (Join-Path $root $contract.fractionalCharacterEvidence) -Raw | ConvertFrom-Json
$fractionalPositive = Get-Content -LiteralPath (Join-Path $root $fractionalCharacter.positivePair) -Raw | ConvertFrom-Json
$fractionalDirectNegative = Get-Content -LiteralPath (Join-Path $root $fractionalCharacter.directNegativePair) -Raw | ConvertFrom-Json
$fractionalRangeNegative = Get-Content -LiteralPath (Join-Path $root $fractionalCharacter.rangeNegativePair) -Raw | ConvertFrom-Json
$fractionalCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $fractionalCharacter.candidateBuild)) 'compiler.exe'
if ($fractionalCharacter.status -cne 'passed-slice-unit-open' -or
    $fractionalCharacter.focusedPassed -cne '5/5' -or
    $fractionalCharacter.semanticOwnedKindsComplete -cne '3/12' -or
    $fractionalPositive.status -cne 'passed' -or $fractionalPositive.completed -ne 3 -or
    $fractionalPositive.total -ne 3 -or -not $fractionalPositive.inputStable -or
    $fractionalDirectNegative.state -cne 'passed' -or -not $fractionalDirectNegative.inputsStable -or
    $fractionalRangeNegative.state -cne 'passed' -or -not $fractionalRangeNegative.inputsStable -or
    $fractionalDirectNegative.selfhostCompilerSha256 -cne $fractionalCharacter.compilerSha256 -or
    $fractionalRangeNegative.selfhostCompilerSha256 -cne $fractionalCharacter.compilerSha256 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $fractionalCandidatePath -Algorithm SHA256).Hash -cne $fractionalCharacter.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $fractionalPositive.inputHashesStart -LiteralPath $fractionalCandidatePath) -cne $fractionalCharacter.compilerSha256 -or
    -not $managedCodegen.Contains('return new RuntimeFloat(', [StringComparison]::Ordinal) -or
    -not $managedCodegen.Contains('BoundType.Float32,', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('numericLiteralRange.literalUsesFloatingSyntax', [StringComparison]::Ordinal) -or
    -not $numericLiteralRange.Contains('first < 48 or first > 57', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('21 -> interpolationBuiltinTypeId(context)', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('syntax.decodeCharacterLiteral(characterSpan)', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('".0" -> print', [StringComparison]::Ordinal)) {
    throw 'fractional, exponent, or character interpolation lacks current source and paired evidence'
}
$integerFraction = Get-Content -LiteralPath (Join-Path $root $contract.integerTargetFractionalEvidence) -Raw | ConvertFrom-Json
$integerFractionBaseline = Get-Content -LiteralPath (Join-Path $root $integerFraction.baselineFailure) -Raw | ConvertFrom-Json
$integerFractionRetained = Get-Content -LiteralPath (Join-Path $root $integerFraction.retainedPositivePair) -Raw | ConvertFrom-Json
$integerFractionCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $integerFraction.candidateBuild)) 'compiler.exe'
if ($integerFraction.status -cne 'passed-slice-unit-open' -or
    $integerFraction.focusedPassed -cne '5/5' -or
    $integerFraction.semanticOwnedKindsComplete -cne '3/12' -or
    $integerFractionBaseline.failureId -cne $integerFraction.baselineFailureId -or
    $integerFractionRetained.status -cne 'passed' -or
    $integerFractionRetained.completed -ne 2 -or $integerFractionRetained.total -ne 2 -or
    -not $integerFractionRetained.inputStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $integerFractionCandidatePath -Algorithm SHA256).Hash -cne $integerFraction.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $integerFractionRetained.inputHashesStart -LiteralPath $integerFractionCandidatePath) -cne $integerFraction.compilerSha256 -or
    -not $managedSemantic.Contains('if (IsIntegerType(targetType))', [StringComparison]::Ordinal) -or
    -not $managedSemantic.Contains('numeric literal {text} is not an integer for {targetName}', [StringComparison]::Ordinal) -or
    $semanticInference -notmatch '(?s)literalUsesFloatingSyntax\(0, literal\.payloadLength\).*?targetBuiltin != 14 -> if \{ 4 => invalidStatus! \}' -or
    -not $emitterDiagnostics.Contains('" is not an integer for $targetName" -> print', [StringComparison]::Ordinal)) {
    throw 'integer-target fractional conversion lacks matching source decisions and current paired evidence'
}
if (@($integerFraction.negativePairs).Count -ne 3) {
    throw 'integer-target fractional conversion must retain three negative cases'
}
foreach ($negativePath in @($integerFraction.negativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $negativePath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $integerFraction.compilerSha256) {
        throw "integer-target fractional conversion negative case failed: $negativePath"
    }
}
$dynamicRange = Get-Content -LiteralPath (Join-Path $root $contract.numericConversionDynamicRangeEvidence) -Raw | ConvertFrom-Json
$dynamicManaged = Get-Content -LiteralPath (Join-Path $root $dynamicRange.managedProof) -Raw | ConvertFrom-Json
$dynamicBaseline = Get-Content -LiteralPath (Join-Path $root $dynamicRange.baselineFailure) -Raw | ConvertFrom-Json
$dynamicPlan = Get-Content -LiteralPath (Join-Path $root $dynamicObservation.rangePlan) -Raw | ConvertFrom-Json
$dynamicCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $dynamicRange.candidateBuild)) 'compiler.exe'
if ($dynamicRange.status -cne 'passed-slice-unit-open' -or $dynamicRange.focusedPassed -cne '8/8' -or
    $dynamicRange.semanticOwnedKindsComplete -cne '3/12' -or
    $dynamicManaged.status -cne 'passed' -or $dynamicManaged.completed -ne 4 -or $dynamicManaged.total -ne 4 -or
    $dynamicBaseline.failureId -cne $dynamicRange.baselineFailureId -or
    $dynamicBaseline.runExitCode -ne 0 -or $dynamicBaseline.stdout.Trim() -cne 'converted=44' -or
    $dynamicPlan.status -cne 'passed' -or $dynamicPlan.completed -ne 338 -or $dynamicPlan.total -ne 338 -or
    $dynamicPlan.managedSourceSha256 -cne (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs') -Algorithm SHA256).Hash -or
    ($dynamicPlan.selfhostSourceSha256 -cne (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root 'selfhost/llvm/text/foundation.slg') -Algorithm SHA256).Hash -and
        $null -eq $importedMethod.currentSourceHashes.PSObject.Properties['selfhost/llvm/text/foundation.slg']) -or
    $dynamicPlan.selfhostSignedSourceSha256 -cne (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath (Join-Path $root 'selfhost/llvm/text/ownership.slg') -Algorithm SHA256).Hash -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $dynamicCandidatePath -Algorithm SHA256).Hash -cne $dynamicRange.compilerSha256 -or
    -not $managedConversionCodegen.Contains('EmitCheckedIntegerConversion(checkedInteger, targetType)', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('emitInterpolationIntegerConversionChecks(nodeIndex, nodes, sourceModule, ownerIndex, beforeIndex, context, state)', [StringComparison]::Ordinal)) {
    throw 'computed integer conversion lacks current C# and SLG range decision evidence'
}
$dynamicExpected = @(
    @{ exit = 0; stdout = 'converted=100'; guard = '_upper_valid = icmp sle' },
    @{ exit = -1073741795; stdout = ''; guard = '_upper_valid = icmp sle' },
    @{ exit = -1073741795; stdout = ''; guard = '_lower_valid = icmp sge' },
    @{ exit = -1073741795; stdout = ''; guard = '_valid_scalar = or i1' }
)
$currentDynamicContract = Get-Content -LiteralPath (Join-Path $root $dynamicObservation.contract) -Raw | ConvertFrom-Json
if (@($dynamicRange.selfhostCases).Count -ne $dynamicExpected.Count) {
    throw 'computed integer conversion must cover four runtime cases'
}
for ($caseIndex = 0; $caseIndex -lt $dynamicExpected.Count; $caseIndex++) {
    $casePath = Join-Path $root $dynamicRange.selfhostCases[$caseIndex]
    $case = Get-Content -LiteralPath $casePath -Raw | ConvertFrom-Json
    $dynamicFixtureNames = @('1866-interpolation-checked-integer-conversion', '1867-interpolation-out-of-range-integer-conversion',
        '1868-interpolation-negative-to-unsigned-conversion', '1869-interpolation-codepoint-surrogate-conversion')
    $currentDynamicCase = @($currentDynamicContract.fixtures | Where-Object name -ceq $dynamicFixtureNames[$caseIndex])
    if ($currentDynamicCase.Count -ne 1 -or @($currentDynamicCase[0].checks).Count -ne 1 -or
        $currentDynamicCase[0].checks[0].text -cne $dynamicExpected[$caseIndex].guard -or
        $currentDynamicCase[0].checks[0].expected -cne $true -or
        $currentDynamicCase[0].runtime.exit -ne $dynamicExpected[$caseIndex].exit -or
        $currentDynamicCase[0].runtime.stdout.Trim() -cne $dynamicExpected[$caseIndex].stdout) {
        throw 'Current dynamic conversion contract changed the original guard or runtime expectation'
    }
    if ($case.status -cne 'passed' -or -not $case.inputsStable -or
        $case.compilerSha256 -cne $dynamicRange.compilerSha256 -or
        $case.runExitCode -ne $dynamicExpected[$caseIndex].exit -or
        $case.stdout.Trim() -cne $dynamicExpected[$caseIndex].stdout -or
        -not $dynamicObservedFixtures[$dynamicFixtureNames[$caseIndex]]['original-range-guard']) {
        throw "computed integer conversion runtime case failed: $casePath"
    }
}
$sizeSigned = Get-Content -LiteralPath (Join-Path $root $contract.sizeSignedFloatEvidence) -Raw | ConvertFrom-Json
$sizeManaged = Get-Content -LiteralPath (Join-Path $root $sizeSigned.managedProof) -Raw | ConvertFrom-Json
$sizeBaseline = Get-Content -LiteralPath (Join-Path $root $sizeSigned.baselineFailure) -Raw | ConvertFrom-Json
$sizePair = Get-Content -LiteralPath (Join-Path $root $sizeSigned.positivePair) -Raw | ConvertFrom-Json
$sizeCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $sizeSigned.candidateBuild)) 'compiler.exe'
$sizeBaselineOutput = Join-Path (Split-Path -Parent (Join-Path $root $sizeSigned.baselineFailure)) '1870-interpolation-size-signed-float-conversion.selfhost.native.stdout.txt'
$sizeSignedLlChecks = $llvmObservedFixtures['1870-interpolation-size-signed-float-conversion']
$selfhostSignedCodegen = Get-Content -LiteralPath (Join-Path $root $sizeSigned.selfhostSignedSource) -Raw
if ($sizeSigned.status -cne 'passed-slice-unit-open' -or $sizeSigned.focusedPassed -cne '2/2' -or
    $sizeSigned.semanticOwnedKindsComplete -cne '3/12' -or
    $sizeSigned.retainedDynamicRange -cne $contract.numericConversionDynamicRangeEvidence -or
    $sizeManaged.status -cne 'passed' -or $sizeManaged.exitCode -ne 0 -or
    $sizeManaged.stdout.Trim() -cne 'signed=-7,unsigned=7' -or
    $sizeBaseline.status -cne 'failed' -or
    (Get-Content -LiteralPath $sizeBaselineOutput -Raw).Trim() -cne $sizeSigned.baselineSelfhostOutput -or
    $sizePair.status -cne 'passed' -or $sizePair.completed -ne 2 -or $sizePair.total -ne 2 -or
    -not $sizePair.inputStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $sizeCandidatePath -Algorithm SHA256).Hash -cne $sizeSigned.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $sizePair.inputHashesStart -LiteralPath $sizeCandidatePath) -cne $sizeSigned.compilerSha256 -or
    -not $managedConversionCodegen.Contains('IsSignedIntegerType(source.Type) ? "sitofp" : "uitofp"', [StringComparison]::Ordinal) -or
    -not $selfhostSignedCodegen.Contains('symbol == 7 or symbol == 12', [StringComparison]::Ordinal) -or
    -not $sizeSignedLlChecks['signed'] -or
    -not $sizeSignedLlChecks['unsigned']) {
    throw 'Size signed float conversion lacks current source and paired behavior evidence'
}
$separator = Get-Content -LiteralPath (Join-Path $root $contract.numericSeparatorEvidence) -Raw | ConvertFrom-Json
$separatorPair = Get-Content -LiteralPath (Join-Path $root $separator.positivePair) -Raw | ConvertFrom-Json
$separatorCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $separator.candidateBuild)) 'compiler.exe'
$managedLexer = Get-Content -LiteralPath (Join-Path $root $separator.managedLexerSource.Split(':')[0]) -Raw
$selfhostLexer = Get-Content -LiteralPath (Join-Path $root $separator.selfhostLexerSource) -Raw
if ($separator.status -cne 'passed-slice-unit-open' -or $separator.focusedPassed -cne '1/1' -or
    $separator.semanticOwnedKindsComplete -cne '3/12' -or
    $separatorPair.status -cne 'passed' -or $separatorPair.completed -ne 1 -or
    $separatorPair.total -ne 1 -or -not $separatorPair.inputStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $separatorCandidatePath -Algorithm SHA256).Hash -cne $separator.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $separatorPair.inputHashesStart -LiteralPath $separatorCandidatePath) -cne $separator.compilerSha256 -or
    -not $managedLexer.Contains('source[start.._index].Replace', [StringComparison]::Ordinal) -or
    -not $selfhostLexer.Contains('source -> byte(position! + 1)) -> isDigit', [StringComparison]::Ordinal) -or
    -not $numericLiteralRange.Contains('character != 95 -> if { false -> return }', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('character == 95', [StringComparison]::Ordinal)) {
    throw 'fractional numeric separators lack matching lexer, range, and LLVM source evidence'
}
$largeLiteral = Get-Content -LiteralPath (Join-Path $root $contract.largeIntegerFloatEvidence) -Raw | ConvertFrom-Json
$largePair = Get-Content -LiteralPath (Join-Path $root $largeLiteral.positivePair) -Raw | ConvertFrom-Json
$signedPair = Get-Content -LiteralPath (Join-Path $root $largeLiteral.signedPair) -Raw | ConvertFrom-Json
$largeCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $largeLiteral.candidateBuild)) 'compiler.exe'
$largeManagedCodegen = Get-Content -LiteralPath (Join-Path $root $largeLiteral.managedCodegenSource) -Raw
$largeBaselineAuthority = $null
if ($contract.PSObject.Properties['largeIntegerFloatBaselineAuthority']) {
    $largeBaselineAuthority = Get-Content -LiteralPath (Join-Path $root $contract.largeIntegerFloatBaselineAuthority) -Raw | ConvertFrom-Json
}
$largeBaselineLlvm = Get-C527HistoricalBaselineText -RepositoryRoot $root -OriginalEvidence $largeLiteral -Authority $largeBaselineAuthority
$largeManagedOutput = Get-Content -LiteralPath (Join-Path $root $largeLiteral.managedFixedOutput) -Raw
$signedManagedOutput = Get-Content -LiteralPath (Join-Path $root $largeLiteral.managedSignedOutput) -Raw
if ($largeLiteral.status -cne 'passed-slice-unit-open' -or $largeLiteral.focusedPassed -cne '5/5' -or
    $largeLiteral.semanticOwnedKindsComplete -cne '3/12' -or
    $largePair.status -cne 'passed' -or $largePair.completed -ne 4 -or $largePair.total -ne 4 -or -not $largePair.inputStable -or
    $signedPair.status -cne 'passed' -or $signedPair.completed -ne 1 -or $signedPair.total -ne 1 -or -not $signedPair.inputStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $largeCandidatePath -Algorithm SHA256).Hash -cne $largeLiteral.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $largePair.inputHashesStart -LiteralPath $largeCandidatePath) -cne $largeLiteral.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $signedPair.inputHashesStart -LiteralPath $largeCandidatePath) -cne $largeLiteral.compilerSha256 -or
    -not $largeBaselineLlvm.Contains('sitofp i32 4294967296 to double', [StringComparison]::Ordinal) -or
    $largeManagedOutput.Trim() -cne 'value=4294967296' -or
    ($signedManagedOutput.Trim() -replace "`r`n", "`n") -cne "negative=-4294967296`nfloat32=4294967296" -or
    -not $largeManagedCodegen.Contains('TryGetNumericLiteralText(expression.Arguments[0], out var floatingLiteral)', [StringComparison]::Ordinal) -or
    -not $largeManagedCodegen.Contains('FormatLlvmFloatingLiteral(', [StringComparison]::Ordinal) -or
    -not $managedCodegen.Contains('float.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var single)', [StringComparison]::Ordinal) -or
    -not $managedCodegen.Contains('BitConverter.DoubleToInt64Bits(value):X16', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('interpolationNumericLiteralSyntax(nodes)', [StringComparison]::Ordinal) -or
    -not $interpolationCodegen.Contains('node.operand0 -> writeInterpolationFloatingLiteral(width, nodes, sourceModule, context)', [StringComparison]::Ordinal)) {
    throw 'integer-shaped float literals lack matching source decisions and paired evidence'
}
Write-Host '[C527 integer-shaped float] PASS baseline, source and paired evidence; whole parity remains open'
$characterConversion = Get-Content -LiteralPath (Join-Path $root $contract.characterConversionEvidence) -Raw | ConvertFrom-Json
$characterBaselinePositive = Get-Content -LiteralPath (Join-Path $root $characterConversion.baselinePositivePair) -Raw | ConvertFrom-Json
$characterBaselineNegative = Get-Content -LiteralPath (Join-Path $root $characterConversion.baselineNegativePair) -Raw | ConvertFrom-Json
$characterManagedFloat = Get-Content -LiteralPath (Join-Path $root $characterConversion.managedFloatProof) -Raw | ConvertFrom-Json
$characterManagedInteger = Get-Content -LiteralPath (Join-Path $root $characterConversion.managedIntegerProof) -Raw | ConvertFrom-Json
$characterManagedRange = Get-Content -LiteralPath (Join-Path $root $characterConversion.managedRangeProof) -Raw | ConvertFrom-Json
$characterPositive = Get-Content -LiteralPath (Join-Path $root $characterConversion.positivePair) -Raw | ConvertFrom-Json
$characterNegative = Get-Content -LiteralPath (Join-Path $root $characterConversion.negativePair) -Raw | ConvertFrom-Json
$characterCandidatePath = Join-Path (Split-Path -Parent (Join-Path $root $characterConversion.candidateBuild)) 'compiler.exe'
$characterLexer = Get-Content -LiteralPath (Join-Path $root $characterConversion.managedLexerSource) -Raw
$characterParser = Get-Content -LiteralPath (Join-Path $root $characterConversion.managedParserSource) -Raw
if ($characterConversion.status -cne 'passed-slice-unit-open' -or $characterConversion.focusedPassed -cne '5/5' -or
    $characterConversion.semanticOwnedKindsComplete -cne '3/12' -or
    $characterBaselinePositive.status -cne 'failed' -or $characterBaselineNegative.failureId -cne 'NEGATIVE_CHECK_FAILED' -or
    $characterManagedFloat.status -cne 'passed' -or $characterManagedInteger.status -cne 'passed' -or
    $characterManagedRange.status -cne 'passed' -or
    $characterPositive.status -cne 'passed' -or $characterPositive.completed -ne 4 -or
    $characterPositive.total -ne 4 -or -not $characterPositive.inputStable -or
    $characterNegative.state -cne 'passed' -or -not $characterNegative.inputsStable -or
    -not $characterNegative.managed.expectedInStderr -or -not $characterNegative.selfhost.expectedInStderr -or
    -not $characterNegative.managed.noEmittedProducts -or -not $characterNegative.selfhost.noEmittedProducts -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $characterCandidatePath -Algorithm SHA256).Hash -cne $characterConversion.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $characterPositive.inputHashesStart -LiteralPath $characterCandidatePath) -cne $characterConversion.compilerSha256 -or
    $characterNegative.selfhostCompilerSha256 -cne $characterConversion.compilerSha256 -or
    -not $characterLexer.Contains('new Token(TokenKind.Character, scalar.ToString(CultureInfo.InvariantCulture)', [StringComparison]::Ordinal) -or
    -not $characterParser.Contains('return new NumberExpression(characterToken.Text', [StringComparison]::Ordinal) -or
    -not $managedSemantic.Contains('ValidateNumericLiteralConversion(expression.Arguments[0], targetType, expression.Path[0])', [StringComparison]::Ordinal) -or
    -not $semanticInference.Contains('literalText -> syntax.decodeCharacterLiteral(characterSpan)', [StringComparison]::Ordinal) -or
    -not $numericLiteralRange.Contains('public characterLiteralStatus scalar: Int', [StringComparison]::Ordinal) -or
    -not $emitterDiagnostics.Contains('context.sources[sourceModule] -> syntax.decodeCharacterLiteral(characterSpan)', [StringComparison]::Ordinal)) {
    throw 'character scalar numeric conversion lacks matching semantic and diagnostic source evidence'
}

if ($contract.schemaVersion -ne 1 -or
    $contract.status -cne 'focused-semantic-kinds-complete-final-source-sweep-pending') {
    throw 'interpolation semantic parity contract has an unsupported state'
}
$rows = @($contract.kinds)
$kindIds = @($rows | ForEach-Object kind)
if ($rows.Count -ne 12 -or ($kindIds -join ',') -cne ((0..11) -join ',')) {
    throw 'interpolation semantic parity must cover kinds 0 through 11 in order'
}
$semanticKinds = @($contract.semanticOwnedKinds)
$emitterKinds = @($contract.emitterOwnedKinds)
$ownedKinds = @($semanticKinds + $emitterKinds | Sort-Object)
if ($ownedKinds.Count -ne 12 -or ($ownedKinds -join ',') -cne ((0..11) -join ',')) {
    throw 'interpolation kind decision owners must partition kinds 0 through 11'
}
if ($semanticKinds -ccontains 2) {
    & (Join-Path $PSScriptRoot 'verify-c607-unary-semantic-owner.ps1') -RepositoryRoot $root
}
if ($semanticKinds -ccontains 3) {
    & (Join-Path $PSScriptRoot 'verify-c608-binary-semantic-owner.ps1') -RepositoryRoot $root
}
if ($semanticKinds -ccontains 5) {
    & (Join-Path $PSScriptRoot 'verify-c609-member-semantic-owner.ps1') -RepositoryRoot $root
}
if ($semanticKinds -ccontains 6) {
    & (Join-Path $PSScriptRoot 'verify-c610-flow-semantic-owner.ps1') -RepositoryRoot $root
}
if ($semanticKinds -ccontains 8) {
    & (Join-Path $PSScriptRoot 'verify-c611-source-call-semantic-owner.ps1') -RepositoryRoot $root
}
if ($semanticKinds -ccontains 9) {
    & (Join-Path $PSScriptRoot 'verify-c612-conversion-semantic-owner.ps1') -RepositoryRoot $root
}
if ($semanticKinds -ccontains 1) {
    if ($contract.lexicalNamePreIrEvidence -cne 'artifacts/scratch/c580-lexical-name-preir-unit-20260928-01.json') {
        throw 'lexical interpolation owner has no C580 receipt'
    }
    if ($contract.unaryDirectOperandPreIrEvidence -cne 'artifacts/scratch/c581-unary-direct-operand-unit-20260928-01.json') {
        throw 'current lexical interpolation owner has no C581 successor receipt'
    }
    if ($contract.memberDirectFieldPreIrEvidence -cne 'artifacts/scratch/c582-member-field-preir-unit-20260928-01.json') {
        throw 'current interpolation member type owner has no C582 receipt'
    }
    if ($contract.indexedArrayPreIrEvidence -cne 'artifacts/scratch/c583-index-preir-unit-20260928-01.json') {
        throw 'current interpolation indexed array type owner has no C583 receipt'
    }
    & python (Join-Path $PSScriptRoot 'verify-c583-index-preir.py') --contract $resolvedContractPath
    if ($LASTEXITCODE -ne 0) { throw 'current lexical interpolation owner proof failed' }
    if ($contract.materializeFlowResultEvidence -cne 'artifacts/scratch/c584-materialize-flow-unit-20260928-01.json') {
        throw 'current Text materialize flow result has no C584 receipt'
    }
    & python (Join-Path $PSScriptRoot 'verify-c584-materialize-flow.py') --contract $resolvedContractPath
    if ($LASTEXITCODE -ne 0) { throw 'current Text materialize flow proof failed' }
}
if ($semanticKinds -ccontains 10 -and
    -not (Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/diagnostics.slg') -Raw).Contains(
        'unresolvedInterpolationCallByNode', [StringComparison]::Ordinal)) {
    throw 'unresolved interpolation call has no semantic decision owner'
}
if ($semanticKinds -ccontains 4) {
    $boolEvidencePath = Join-Path $root $contract.boolLiteralDecisionEvidence
    if ($managedSemantic -notmatch 'BoolExpression => BoundType\.Bool' -or
        $semanticInference -notmatch 'node\.kind == 4 -> if \{ types -> typeIds\.builtinTypeId\(23\) -> return \}' -or
        $semanticInference -notmatch 'node\.kind == 1 or node\.kind == 4 or node\.kind == 5' -or
        $semanticInference -notmatch 'node\.parent < 0(?: and invalidTypeId! < 0)?\s*-> if' -or
        -not (Test-Path -LiteralPath $boolEvidencePath -PathType Leaf)) {
        throw 'boolean interpolation literal has no matching semantic type decision'
    }
    $boolEvidence = Get-Content -LiteralPath $boolEvidencePath -Raw | ConvertFrom-Json
    $positivePair = Get-Content -LiteralPath (Join-Path $root $boolEvidence.positivePair) -Raw | ConvertFrom-Json
    $negativePair = Get-Content -LiteralPath (Join-Path $root $boolEvidence.negativePair) -Raw | ConvertFrom-Json
    if ($boolEvidence.status -cne 'passed-slice-unit-open' -or
        $boolEvidence.semanticOwnedKindsComplete -cne '2/12' -or
        $positivePair.status -cne 'passed' -or $positivePair.completed -ne 1 -or
        $positivePair.total -ne 1 -or -not $positivePair.inputStable -or
        $negativePair.state -cne 'passed' -or -not $negativePair.inputsStable -or
        $negativePair.selfhostCompilerSha256 -cne $boolEvidence.compilerSha256) {
        throw 'boolean interpolation semantic decision lacks current paired evidence'
    }
}
if ($semanticKinds -ccontains 0) {
    $integerEvidencePath = Join-Path $root $contract.integerLiteralDecisionEvidence
    if ($managedSemantic -notmatch '(?s)NumberExpression number => number\.Text\.Contains.*?\? BoundType\.Float32\s*:\s*BoundType\.Int' -or
        $managedSemantic -notmatch '(?s)var indexType = expression\.Index is NumberExpression.*?\? BoundType\.UIntSize' -or
        $semanticInference -notmatch '(?s)node\.kind == 0 -> if \{.*?numericLiteralRange\.literalUsesFloatingSyntax.*?builtinTypeId\(20\).*?builtinTypeId\(2\) -> return' -or
        $semanticInference -notmatch 'node\.kind == 0 or node\.kind == 1 or node\.kind == 4' -or
        $semanticInference -notmatch 'index\.kind != 0 -> if' -or
        -not (Test-Path -LiteralPath $integerEvidencePath -PathType Leaf)) {
        throw 'integer interpolation literal lacks matching default and contextual semantic type decisions'
    }
    $integerEvidence = Get-Content -LiteralPath $integerEvidencePath -Raw | ConvertFrom-Json
    $integerPair = Get-Content -LiteralPath (Join-Path $root $integerEvidence.positivePair) -Raw | ConvertFrom-Json
    $contextPair = Get-Content -LiteralPath (Join-Path $root $integerEvidence.retainedContextualIndex) -Raw | ConvertFrom-Json
    if ($integerEvidence.status -cne 'passed-slice-unit-open' -or
        $integerEvidence.semanticOwnedKindsComplete -cne '3/12' -or
        $integerPair.status -cne 'passed' -or $integerPair.completed -ne 2 -or
        $integerPair.total -ne 2 -or -not $integerPair.inputStable -or
        $contextPair.status -cne 'passed' -or $contextPair.completed -ne 1 -or
        $contextPair.total -ne 1 -or -not $contextPair.inputStable) {
        throw 'integer interpolation semantic decision lacks current paired evidence'
    }
    $candidatePath = Join-Path (Split-Path -Parent (Join-Path $root $integerEvidence.candidateBuild)) 'compiler.exe'
    $pairCandidateHash = (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $integerPair.inputHashesStart -LiteralPath $candidatePath)
    $contextCandidateHash = (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $contextPair.inputHashes -LiteralPath $candidatePath)
    if ((Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $candidatePath -Algorithm SHA256).Hash -cne $integerEvidence.compilerSha256 -or
        $pairCandidateHash -cne $integerEvidence.compilerSha256 -or
        $contextCandidateHash -cne $integerEvidence.compilerSha256) {
        throw 'integer interpolation evidence names a different compiler candidate'
    }
}
$kindComment = [regex]::Match($interpolationSourceText, '(?s)# Kinds:.*?(?=# Builtin result ids)')
if (-not $kindComment.Success) { throw 'interpolation kind source contract is missing' }
$documentedKinds = @([regex]::Matches($kindComment.Value, '(?<!\d)(\d{1,2})\s+([^,\r\n]+)'))
$sourceKindCatalog = @($contract.sourceKindCatalog)
if ($sourceKindCatalog.Count -ne 18 -or ($sourceKindCatalog.id -join ',') -cne ((0..17) -join ',') -or
    $documentedKinds.Count -ne $sourceKindCatalog.Count) {
    throw 'interpolation source kinds differ from the semantic parity contract'
}
for ($kindIndex = 0; $kindIndex -lt $sourceKindCatalog.Count; $kindIndex++) {
    $documentedKind = $documentedKinds[$kindIndex]
    $catalogKind = $sourceKindCatalog[$kindIndex]
    if ([int]$documentedKind.Groups[1].Value -ne $catalogKind.id -or
        $documentedKind.Groups[2].Value.Trim().TrimEnd('.') -cne $catalogKind.description) {
        throw 'interpolation source kind identity or description differs from the semantic parity contract'
    }
}
if ($contract.additionalSourceKindsQualification.status -cne 'pending-current-phase-exhaustive-proof' -or
    ($contract.additionalSourceKindsQualification.ids -join ',') -cne '12,13,14,15,16,17' -or
    $sourceKindCatalog[13].role -cne 'field-metadata') {
    throw 'Additional interpolation source kind qualification must remain explicit and separate from original12 families'
}
$managedNames = @($expressionContract.mappings | ForEach-Object managedExpression)
$evidenceCount = 0
foreach ($row in $rows) {
    if ([string]::IsNullOrWhiteSpace($row.name) -or @($row.managedExpression).Count -eq 0) {
        throw "interpolation kind $($row.kind) has no source mapping"
    }
    foreach ($name in @($row.managedExpression)) {
        if ($managedNames -cnotcontains $name) {
            throw "interpolation kind $($row.kind) names an unknown managed expression: $name"
        }
    }
    if ($null -ne $row.focusedEvidence) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $row.focusedEvidence) -PathType Leaf)) {
            throw "interpolation kind $($row.kind) evidence is missing: $($row.focusedEvidence)"
        }
        $evidenceCount++
    }
}
if (-not $interpolationSourceText.Contains('11 Result propagation', [StringComparison]::Ordinal)) {
    throw 'interpolation Result propagation source identity is missing'
}
$partialIndexEvidence = Join-Path $root $contract.partialSemanticIndexRuleEvidence
if (-not (Test-Path -LiteralPath $partialIndexEvidence -PathType Leaf)) {
    throw 'partial semantic index decision evidence is missing'
}
$partialIndex = Get-Content -LiteralPath $partialIndexEvidence -Raw | ConvertFrom-Json
if ($partialIndex.status -cne 'passed-slice-unit-open' -or $partialIndex.focusedPassed -cne '6/6' -or
    $partialIndex.retainedPassed -cne '6/6' -or
    -not (Get-Content -LiteralPath (Join-Path $root 'selfhost/semantic/diagnostics.slg') -Raw).Contains(
        'invalidArgumentsInterpolationIndexByNode', [StringComparison]::Ordinal)) {
    throw 'partial semantic Arguments index decision is not supported by current source and focused evidence'
}
if ($contract.mappedIndexDecisionOwner -cne 'semantic' -or
    $semanticInference -notmatch 'public invalidMappedIndexByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidMappedIndexByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidMappedIndexByNode\[nodeIndex\]' -or
    ([regex]::Match($emitterDiagnostics, '(?s)public isBlockingMappedIndexInterpolation.*?(?=public isBlockingInvalidUnaryInterpolation)').Value -match 'interpolationScalarBuiltinSymbol')) {
    throw 'mapped interpolation index type decision must be prepared by semantic inference and consumed by the emitter'
}
if ($contract.collectionIndexDecisionOwner -cne 'semantic' -or
    $semanticInference -notmatch 'public invalidCollectionIndexExpectedTypeByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidCollectionIndexExpectedTypeByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidCollectionIndexExpectedTypeByNode\[nodeIndex!\]') {
    throw 'collection interpolation index type decision must be prepared by semantic inference and consumed by the emitter'
}
if ($contract.indexOwnerDecisionOwner -cne 'semantic' -or
    $semanticInference -notmatch 'public unsupportedIndexOwnerTypeByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.unsupportedIndexOwnerTypeByNode' -or
    $emitterDiagnostics -notmatch 'context\.unsupportedIndexOwnerTypeByNode\[nodeIndex!\]') {
    throw 'interpolation index source eligibility must be prepared by semantic inference and consumed by the emitter'
}
if ($contract.displayabilityDecisionOwner -cne 'semantic' -or
    $semanticInference -notmatch 'public invalidDisplayTypeByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidDisplayTypeByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidDisplayTypeByNode\[nodeIndex!\]') {
    throw 'interpolation displayability must be decided by semantic inference before LLVM emission'
}
if ($contract.referenceReadDecisionOwner -cne 'semantic' -or
    $managedSemantic -notmatch '(?s)private BoundType InferNameExpression\(.*?bindings\.TryGetValue\(expression\.Name, out var type\).*?_types\.IsReference\(type\).*?_types\.GetReference\(type\)\.ElementType' -or
    $semanticInference -notmatch 'types -> typeIds\.materializedReadTypeId\(bindingTypeId!\)') {
    throw 'interpolation lexical names must materialize readonly references as C# does'
}
$referenceReadEvidence = Join-Path $root $contract.referenceReadDecisionEvidence
if (-not (Test-Path -LiteralPath $referenceReadEvidence -PathType Leaf) -or
    (Get-Content -LiteralPath $referenceReadEvidence -Raw | ConvertFrom-Json).status -cne 'passed-slice-unit-open') {
    throw 'interpolation reference-read decision evidence is missing or failed'
}
foreach ($decisionEvidence in @($contract.displayabilityDecisionEvidence, $contract.indexOwnerDecisionEvidence, $contract.collectionIndexDecisionEvidence, $contract.signedUnaryDecisionEvidence)) {
    $decisionPath = Join-Path $root $decisionEvidence
    if (-not (Test-Path -LiteralPath $decisionPath -PathType Leaf) -or
        (Get-Content -LiteralPath $decisionPath -Raw | ConvertFrom-Json).status -cne 'passed-slice-unit-open') {
        throw "interpolation semantic decision evidence is missing or failed: $decisionEvidence"
    }
}
$topologyPath = Resolve-CompilerEvidencePath -RepositoryRoot $root -LiteralPath $contract.indexedMemberTopologyEvidence
if (-not (Test-Path -LiteralPath $topologyPath -PathType Leaf)) {
    throw 'indexed member interpolation topology evidence is missing'
}
$topology = Get-Content -LiteralPath $topologyPath -Raw | ConvertFrom-Json
if ($topology.status -cne 'passed' -or $topology.completed -ne 1 -or $topology.total -ne 1 -or
    -not $topology.inputStable -or
    -not $interpolationLowering.Contains('postfixValue! => postfixSuffix!.operand0', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('postfixSubscript => postfixSuffix!.operand1', [StringComparison]::Ordinal) -or
    -not $interpolationLowering.Contains('lastPostfixChild! => postfixParent!.operand1', [StringComparison]::Ordinal) -or
    $semanticInference -notmatch 'node\.kind == 7 and node\.operand0 >= 0') {
    throw 'indexed member interpolation topology is not supported by current semantic and IR source'
}
$currentTopologyReference = $contract.currentIndexedMemberTopologyEvidence
$currentTopologyPath = [IO.Path]::GetFullPath($currentTopologyReference.proof, $root)
$currentTopology = Get-Content -LiteralPath $currentTopologyPath -Raw | ConvertFrom-Json
$currentTopologyCompiler = [IO.Path]::GetFullPath($currentTopologyReference.compiler, $root)
$topologyFixture = '1824-c527-indexed-member-interpolation-topology'
$topologySourcePath = (Resolve-Path -LiteralPath (Join-Path $root "examples/regression/$topologyFixture.slg")).Path
$topologyExpected = [IO.File]::ReadAllText((Join-Path $root "examples/regression/expected/$topologyFixture.stdout.txt")).Replace("`r`n", "`n")
if ($currentTopology.status -cne 'passed' -or $currentTopology.completed -ne 1 -or $currentTopology.total -ne 1 -or
    -not $currentTopology.inputsStable -or -not $currentTopology.processesStopped -or @($currentTopology.runs).Count -ne 2 -or
    (Get-FileHash -LiteralPath $currentTopologyCompiler -Algorithm SHA256).Hash -cne $currentTopologyReference.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $currentTopology.inputHashesStart -LiteralPath $currentTopologyCompiler) -cne $currentTopologyReference.compilerSha256 -or
    $topology.actualStdout.Replace("`r`n", "`n") -cne $topologyExpected -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $topology.inputHashes -LiteralPath $topologySourcePath) -cne (Get-FileHash -LiteralPath $topologySourcePath -Algorithm SHA256).Hash) {
    throw 'CURRENT_INDEXED_MEMBER_TOPOLOGY_PROOF_INCOMPLETE'
}
foreach ($hashedInput in $currentTopology.inputHashesStart.PSObject.Properties) {
    if ((Get-FileHash -LiteralPath $hashedInput.Name -Algorithm SHA256).Hash -cne $hashedInput.Value -or
        $currentTopology.inputHashesEnd.PSObject.Properties[$hashedInput.Name].Value -cne $hashedInput.Value) {
        throw "Current indexed member topology input changed: $($hashedInput.Name)"
    }
}
foreach ($side in @('managed', 'selfhost')) {
    $run = @($currentTopology.runs | Where-Object compiler -ceq $side)
    $stdoutPath = Join-Path (Split-Path -Parent $currentTopologyPath) "$topologyFixture.$side.native.stdout.txt"
    $stderrPath = Join-Path (Split-Path -Parent $currentTopologyPath) "$topologyFixture.$side.native.stderr.txt"
    if ($run.Count -ne 1 -or $run[0].fixture -cne $topologyFixture -or
        $run[0].buildExit -ne 0 -or $run[0].llvmAsExit -ne 0 -or $run[0].directCallExit -ne 0 -or $run[0].nativeExit -ne 0 -or
        [IO.File]::ReadAllText($stdoutPath).Replace("`r`n", "`n") -cne $topologyExpected -or
        (Get-Item -LiteralPath $stderrPath).Length -ne 0) {
        throw 'CURRENT_INDEXED_MEMBER_TOPOLOGY_EXACT_MISMATCH'
    }
}
if ($contract.signedUnaryDecisionOwner -cne 'semantic' -or
    $semanticInference -notmatch 'public invalidSignedUnaryByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidSignedUnaryByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidSignedUnaryByNode\[nodeIndex\]' -or
    $emitterDiagnostics -match 'interpolationScalarBuiltinSymbol') {
    throw 'signed unary interpolation decision must be prepared by semantic inference without emitter-side scalar classification'
}
if ($contract.numericConversionOperandDecisionOwner -cne 'semantic' -or
    $managedSemantic -notmatch '(?s)private bool TryInferNumericConversion\(.*?if \(!IsNumericType\(sourceType\)\).*?expects a numeric value' -or
    $semanticInference -notmatch 'public invalidNumericConversionTypeByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidNumericConversionTypeByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidNumericConversionTypeByNode\[nodeIndex!\]' -or
    $emitterDiagnostics -notmatch 'context\.invalidNumericConversionTypeByNode\[interpolationIndex!\]') {
    throw 'numeric conversion nonnumeric operand must be decided before LLVM emission'
}
$conversionEvidencePath = Join-Path $root $contract.numericConversionOperandDecisionEvidence
if (-not (Test-Path -LiteralPath $conversionEvidencePath -PathType Leaf)) {
    throw 'numeric conversion operand decision evidence is missing'
}
$conversionEvidence = Get-Content -LiteralPath $conversionEvidencePath -Raw | ConvertFrom-Json
$conversionPositive = Get-Content -LiteralPath (Join-Path $root $conversionEvidence.positivePair) -Raw | ConvertFrom-Json
$conversionBaseline = Get-Content -LiteralPath (Join-Path $root $conversionEvidence.baselineFailure) -Raw | ConvertFrom-Json
if ($conversionEvidence.status -cne 'passed-slice-unit-open' -or
    $conversionEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $conversionPositive.status -cne 'passed' -or $conversionPositive.completed -ne 2 -or
    $conversionPositive.total -ne 2 -or -not $conversionPositive.inputStable -or
    $conversionBaseline.failureId -cne $conversionEvidence.baselineFailureId -or
    @($conversionEvidence.negativePairs).Count -ne 2) {
    throw 'numeric conversion operand decision lacks positive or baseline evidence'
}
$conversionCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $conversionEvidence.candidateBuild)) 'compiler.exe'
if ((Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $conversionCompilerPath -Algorithm SHA256).Hash -cne $conversionEvidence.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $conversionPositive.inputHashesStart -LiteralPath $conversionCompilerPath) -cne $conversionEvidence.compilerSha256) {
    throw 'numeric conversion operand evidence names a different compiler candidate'
}
foreach ($negativePath in @($conversionEvidence.negativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $negativePath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $conversionEvidence.compilerSha256) {
        throw "numeric conversion negative evidence failed or changed: $negativePath"
    }
}
if ($contract.numericConversionRangeDecisionOwner -cne 'semantic' -or
    $managedSemantic -notmatch '(?s)private void ValidateNumericLiteralConversion\(.*?numeric literal \{text\} is out of range' -or
    $numericLiteralRange -notmatch 'public integerLiteralStatus' -or
    $semanticInference -notmatch 'public invalidNumericConversionLiteralByNode' -or
    $emitterDiagnostics -notmatch 'numericLiteralRange\.integerLiteralStatus' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidNumericConversionLiteralByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidNumericConversionLiteralByNode\[interpolationIndex!\]' -or
    -not (Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') -Raw).Contains(
        'selfhost/semantic/numeric_literal_range.slg', [StringComparison]::Ordinal)) {
    throw 'numeric conversion literal range must use one semantic classifier before LLVM emission'
}
$rangeEvidencePath = Join-Path $root $contract.numericConversionRangeDecisionEvidence
if (-not (Test-Path -LiteralPath $rangeEvidencePath -PathType Leaf)) {
    throw 'numeric conversion range decision evidence is missing'
}
$rangeEvidence = Get-Content -LiteralPath $rangeEvidencePath -Raw | ConvertFrom-Json
$rangePositive = Get-Content -LiteralPath (Join-Path $root $rangeEvidence.positivePair) -Raw | ConvertFrom-Json
$rangeBaseline = Get-Content -LiteralPath (Join-Path $root $rangeEvidence.baselineFailure) -Raw | ConvertFrom-Json
if ($rangeEvidence.status -cne 'passed-slice-unit-open' -or
    $rangeEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $rangePositive.status -cne 'passed' -or $rangePositive.completed -ne 2 -or
    $rangePositive.total -ne 2 -or -not $rangePositive.inputStable -or
    $rangeBaseline.failureId -cne $rangeEvidence.baselineFailureId -or
    @($rangeEvidence.negativePairs).Count -ne 3) {
    throw 'numeric conversion range decision lacks positive or baseline evidence'
}
$rangeCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $rangeEvidence.candidateBuild)) 'compiler.exe'
if ((Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $rangeCompilerPath -Algorithm SHA256).Hash -cne $rangeEvidence.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $rangePositive.inputHashesStart -LiteralPath $rangeCompilerPath) -cne $rangeEvidence.compilerSha256) {
    throw 'numeric conversion range evidence names a different compiler candidate'
}
foreach ($negativePath in @($rangeEvidence.negativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $negativePath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $rangeEvidence.compilerSha256) {
        throw "numeric conversion range negative evidence failed or changed: $negativePath"
    }
}
$two = [Numerics.BigInteger]::new(2)
$one = [Numerics.BigInteger]::One
$float32Cutoff = [Numerics.BigInteger]::Pow($two, 128) - [Numerics.BigInteger]::Pow($two, 104) +
    [Numerics.BigInteger]::Pow($two, 74)
$float64Cutoff = [Numerics.BigInteger]::Pow($two, 1024) - [Numerics.BigInteger]::Pow($two, 970)
$numberStyle = [Globalization.NumberStyles]::Float
$invariantCulture = [Globalization.CultureInfo]::InvariantCulture
[double]$float32At = 0
[double]$float32Over = 0
[double]$float64Under = 0
[double]$float64At = 0
$thresholdParse =
    [double]::TryParse($float32Cutoff.ToString(), $numberStyle, $invariantCulture, [ref]$float32At) -and
    [double]::TryParse(($float32Cutoff + $one).ToString(), $numberStyle, $invariantCulture, [ref]$float32Over) -and
    [double]::TryParse(($float64Cutoff - $one).ToString(), $numberStyle, $invariantCulture, [ref]$float64Under) -and
    [double]::TryParse($float64Cutoff.ToString(), $numberStyle, $invariantCulture, [ref]$float64At)
if (-not $thresholdParse -or
    -not $numericLiteralRange.Contains($float32Cutoff.ToString(), [StringComparison]::Ordinal) -or
    -not $numericLiteralRange.Contains($float64Cutoff.ToString(), [StringComparison]::Ordinal) -or
    $numericLiteralRange -notmatch 'public floatingLiteralWithinRange' -or
    $semanticInference -notmatch 'numericLiteralRange\.floatingLiteralWithinRange' -or
    $float32At -ne [double][float]::MaxValue -or
    $float32Over -le [double][float]::MaxValue -or
    [double]::IsInfinity($float64Under) -or
    -not [double]::IsInfinity($float64At)) {
    throw 'floating literal range thresholds differ from the managed Float64 parse boundary'
}
$floatingRangeEvidence = Get-Content -LiteralPath (Join-Path $root $contract.floatingLiteralRangeEvidence) -Raw | ConvertFrom-Json
$floatingRangeBaseline = Get-Content -LiteralPath (Join-Path $root $floatingRangeEvidence.baselineFailure) -Raw | ConvertFrom-Json
$floatingRangeCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $floatingRangeEvidence.candidateBuild)) 'compiler.exe'
if ($floatingRangeEvidence.status -cne 'passed-slice-unit-open' -or
    $floatingRangeEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $floatingRangeBaseline.failureId -cne $floatingRangeEvidence.baselineFailureId -or
    @($floatingRangeEvidence.managedNegatives).Count -ne 3 -or
    @($floatingRangeEvidence.negativePairs).Count -ne 3 -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $floatingRangeCompilerPath -Algorithm SHA256).Hash -cne $floatingRangeEvidence.compilerSha256) {
    throw 'floating literal range lacks stable baseline and candidate identity'
}
foreach ($managedPath in @($floatingRangeEvidence.managedNegatives)) {
    $managedCase = Get-Content -LiteralPath (Join-Path $root $managedPath) -Raw | ConvertFrom-Json
    if ($managedCase.exitCode -ne 1 -or $managedCase.start.compiler -cne $managedCase.end.compiler -or
        $managedCase.start.source -cne $managedCase.end.source) {
        throw "floating literal managed rejection failed or drifted: $managedPath"
    }
}
foreach ($negativePath in @($floatingRangeEvidence.negativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $negativePath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $floatingRangeEvidence.compilerSha256) {
        throw "floating literal paired rejection failed or drifted: $negativePath"
    }
}
if ($contract.numericConversionArityDecisionOwner -cne 'semantic' -or
    $managedSemantic -notmatch '(?s)private bool TryInferNumericConversion\(.*?expression\.Arguments\.Count != 1.*?expects exactly one argument' -or
    $semanticInference -notmatch 'public invalidNumericConversionArityByNode' -or
    $semanticInference -notmatch 'node\.operand0 < 0 or node\.operand1 >= 0' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidNumericConversionArityByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidNumericConversionArityByNode\[nodeIndex!\]' -or
    $emitterDiagnostics -notmatch 'context\.invalidNumericConversionArityByNode\[interpolationIndex!\]') {
    throw 'numeric conversion argument count must be decided by semantic inference before LLVM'
}
$arityEvidencePath = Join-Path $root $contract.numericConversionArityDecisionEvidence
if (-not (Test-Path -LiteralPath $arityEvidencePath -PathType Leaf)) {
    throw 'numeric conversion arity decision evidence is missing'
}
$arityEvidence = Get-Content -LiteralPath $arityEvidencePath -Raw | ConvertFrom-Json
$arityPositive = Get-Content -LiteralPath (Join-Path $root $arityEvidence.positivePair) -Raw | ConvertFrom-Json
$arityBaseline = Get-Content -LiteralPath (Join-Path $root $arityEvidence.baselineFailure) -Raw | ConvertFrom-Json
if ($arityEvidence.status -cne 'passed-slice-unit-open' -or
    $arityEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $arityPositive.status -cne 'passed' -or $arityPositive.completed -ne 1 -or
    $arityPositive.total -ne 1 -or -not $arityPositive.inputStable -or
    $arityBaseline.failureId -cne $arityEvidence.baselineFailureId -or
    @($arityEvidence.negativePairs).Count -ne 3) {
    throw 'numeric conversion arity decision lacks positive or baseline evidence'
}
$arityCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $arityEvidence.candidateBuild)) 'compiler.exe'
if ((Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $arityCompilerPath -Algorithm SHA256).Hash -cne $arityEvidence.compilerSha256 -or
    (Get-CompilerEvidencePinnedHash -RepositoryRoot $root -InputHashes $arityPositive.inputHashesStart -LiteralPath $arityCompilerPath) -cne $arityEvidence.compilerSha256) {
    throw 'numeric conversion arity evidence names a different compiler candidate'
}
foreach ($negativePath in @($arityEvidence.negativePairs)) {
    $negative = Get-Content -LiteralPath (Join-Path $root $negativePath) -Raw | ConvertFrom-Json
    if ($negative.state -cne 'passed' -or -not $negative.inputsStable -or
        $negative.selfhostCompilerSha256 -cne $arityEvidence.compilerSha256) {
        throw "numeric conversion arity negative evidence failed or changed: $negativePath"
    }
}
if ($managedSemantic -notmatch '(?s)private bool TryInferNumericConversion\(.*?!IsNumericType\(targetType\)' -or
    $interpolationLowering -notmatch '"CodePoint", "Float", "Float32", "Float64", "Double"' -or
    $interpolationLowering -notmatch '14, 19, 20, 21, 22' -or
    $interpolationLowering -match '"CodePoint", "Bool"' -or
    $semanticInference -notmatch 'canonical == 20 or canonical == 21' -or
    $interpolationCodegen -notmatch '"sitofp"' -or
    $interpolationCodegen -notmatch '"uitofp"' -or
    $interpolationCodegen -notmatch '"fptrunc "' -or
    $interpolationCodegen -notmatch '"fpext "' -or
    $interpolationCodegen -notmatch 'nodeIndex -> sameWidthNumericConversionOperand' -or
    $interpolationCodegen -notmatch 'conversionSourceFloatWidth! != conversionTargetFloatWidth!') {
    throw 'numeric conversion targets or floating lowering differ from C# source decisions'
}
$targetEvidence = Get-Content -LiteralPath (Join-Path $root $contract.numericConversionTargetClassificationEvidence) -Raw | ConvertFrom-Json
$targetPositive = Get-Content -LiteralPath (Join-Path $root $targetEvidence.positivePair) -Raw | ConvertFrom-Json
$targetNegative = Get-Content -LiteralPath (Join-Path $root $targetEvidence.negativePair) -Raw | ConvertFrom-Json
$targetCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $targetEvidence.candidateBuild)) 'compiler.exe'
if ($targetEvidence.status -cne 'passed-slice-unit-open' -or
    $targetEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $targetPositive.status -cne 'passed' -or $targetPositive.completed -ne 1 -or
    $targetPositive.total -ne 1 -or -not $targetPositive.inputStable -or
    $targetNegative.state -cne 'passed' -or -not $targetNegative.inputsStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $targetCompilerPath -Algorithm SHA256).Hash -cne $targetEvidence.compilerSha256 -or
    $targetNegative.selfhostCompilerSha256 -cne $targetEvidence.compilerSha256) {
    throw 'numeric conversion target classification lacks current paired evidence'
}
$floatAliasEvidence = Get-Content -LiteralPath (Join-Path $root $contract.numericConversionFloatAliasEvidence) -Raw | ConvertFrom-Json
$floatAliasPositive = Get-Content -LiteralPath (Join-Path $root $floatAliasEvidence.positivePair) -Raw | ConvertFrom-Json
$floatAliasNegative = Get-Content -LiteralPath (Join-Path $root $floatAliasEvidence.negativePair) -Raw | ConvertFrom-Json
$floatAliasManaged = Get-Content -LiteralPath (Join-Path $root $floatAliasEvidence.managedWidthPositive) -Raw | ConvertFrom-Json
$floatAliasCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $floatAliasEvidence.candidateBuild)) 'compiler.exe'
if ($floatAliasEvidence.status -cne 'passed-slice-unit-open' -or
    $floatAliasEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $floatAliasManaged.buildExit -ne 0 -or $floatAliasManaged.runExit -ne 0 -or
    $floatAliasPositive.status -cne 'passed' -or $floatAliasPositive.completed -ne 2 -or
    $floatAliasPositive.total -ne 2 -or -not $floatAliasPositive.inputStable -or
    $floatAliasNegative.state -cne 'passed' -or -not $floatAliasNegative.inputsStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $floatAliasCompilerPath -Algorithm SHA256).Hash -cne $floatAliasEvidence.compilerSha256 -or
    $floatAliasNegative.selfhostCompilerSha256 -cne $floatAliasEvidence.compilerSha256) {
    throw 'same-width float alias or direct Float display boundary lacks paired evidence'
}
if ($contract.codePointFloatDecisionOwner -cne 'semantic' -or
    $managedSemantic -notmatch 'targetType == BoundType\.CodePoint && IsFloatType\(sourceType\)' -or
    $semanticInference -notmatch 'public invalidCodePointFloatConversionByNode' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.invalidCodePointFloatConversionByNode' -or
    $emitterDiagnostics -notmatch 'context\.invalidCodePointFloatConversionByNode\[nodeIndex!\]' -or
    $emitterDiagnostics -notmatch 'context\.invalidCodePointFloatConversionByNode\[interpolationIndex!\]') {
    throw 'CodePoint float conversion must be rejected by semantic inference before LLVM'
}
$codePointEvidence = Get-Content -LiteralPath (Join-Path $root $contract.codePointFloatDecisionEvidence) -Raw | ConvertFrom-Json
$codePointNegative = Get-Content -LiteralPath (Join-Path $root $codePointEvidence.negativePair) -Raw | ConvertFrom-Json
$codePointRetained = Get-Content -LiteralPath (Join-Path $root $codePointEvidence.retainedPositivePair) -Raw | ConvertFrom-Json
$codePointManaged = Get-Content -LiteralPath (Join-Path $root $codePointEvidence.managedNegative) -Raw | ConvertFrom-Json
$codePointCompilerPath = Join-Path (Split-Path -Parent (Join-Path $root $codePointEvidence.candidateBuild)) 'compiler.exe'
if ($codePointEvidence.status -cne 'passed-slice-unit-open' -or
    $codePointEvidence.semanticOwnedKindsComplete -cne '3/12' -or
    $codePointManaged.exitCode -ne 1 -or
    $codePointManaged.stderr -notmatch 'CodePoint conversion requires an integer Unicode scalar value' -or
    $codePointNegative.state -cne 'passed' -or -not $codePointNegative.inputsStable -or
    $codePointRetained.status -cne 'passed' -or $codePointRetained.completed -ne 1 -or
    $codePointRetained.total -ne 1 -or -not $codePointRetained.inputStable -or
    (Get-CompilerEvidenceHash -RepositoryRoot $root -ArchivedNativeBuild -LiteralPath $codePointCompilerPath -Algorithm SHA256).Hash -cne $codePointEvidence.compilerSha256 -or
    $codePointNegative.selfhostCompilerSha256 -cne $codePointEvidence.compilerSha256) {
    throw 'CodePoint float conversion lacks managed, paired negative, or retained positive evidence'
}
$snapshotInterpolationQuery = [regex]::Match($semanticContext, '(?s)public lowerAnalyzedInterpolations .*?(?=\r?\nprepareAnalyzed\s)')
if ([regex]::Matches($semanticAnalysis, '-> interpolation\.lowerPreparedWithTypes').Count -ne 1 -or
    $semanticAnalysis -notmatch 'public completeSourceInterpolations source: Text, nodes: ref \[ast\.AstNode; ~\]' -or
    -not $semanticAnalysis.Contains('source -> completeSourceInterpolations(lowered.nodes, originalTokens, originalSymbols) => completed', [StringComparison]::Ordinal) -or
    $semanticContext -match 'interpolation\.lowerPrepared' -or
    -not $snapshotInterpolationQuery.Success -or
    -not $snapshotInterpolationQuery.Value.Contains('package.interpolations -> each node { nodes! -> push(node) }', [StringComparison]::Ordinal) -or
    -not $snapshotInterpolationQuery.Value.Contains('package.interpolationRanges -> each range { ranges! -> push(range) }', [StringComparison]::Ordinal) -or
    $semanticContext -notmatch 'packageAnalysis -> lowerAnalyzedInterpolations' -or
    $semanticContext -notmatch 'interpolations: analyzedInterpolations\.nodes' -or
    $ownershipCheck -match 'interpolation\.lowerPrepared' -or
    $ownershipCheck -notmatch 'prepared\.interpolations -> each node' -or
    $emitterPreparation -match 'interpolation\.lowerPrepared' -or
    $emitterPreparation -notmatch 'prepared -> interpolationInference\.classifyIntrinsicFlowReceivers\(streamPlan, recursiveTypes!, ir!, recursiveTypes!\.types, recursiveTypes!\.fields\) => analysisInterpolations') {
    throw 'interpolation source nodes must be prepared once in the semantic snapshot and consumed downstream'
}
Write-Output "[interpolation semantic parity] PASS original mapped kinds 12/12; source kind inventory$($sourceKindCatalog.Count)/$($sourceKindCatalog.Count); recorded focused receipts $evidenceCount/12; original semantic decision owners $($semanticKinds.Count)/12; additional kinds and whole source ownership pending"
