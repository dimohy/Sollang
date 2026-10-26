[CmdletBinding()]
param(
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = "Stop"
function Test-UnreferencedSplitHelper {
    param([string]$Name, [string]$SourceText, [string]$LlvmText)
    $escaped = [regex]::Escape($Name)
    return [regex]::Matches($SourceText, '\b' + $escaped + '\b').Count -eq 1 -and
        [regex]::Matches($LlvmText, '@sollang_fn_sollang_compiler_llvm_text_' + $escaped + '\(').Count -eq 0
}
function Get-SplitContextStateParameters {
    param([string[]]$Parameters, [ValidateRange(0, 64)][int]$FollowingParameters)
    if ($Parameters.Count -lt 2 + $FollowingParameters) { throw 'Split ABI parameter inventory is incomplete.' }
    return @($Parameters[$Parameters.Count - 2 - $FollowingParameters], $Parameters[$Parameters.Count - 1 - $FollowingParameters])
}
function Get-SplitContextMaterializations {
    param([string]$LlvmText)
    foreach ($function in [regex]::Matches($LlvmText, '(?ms)^define [^\r\n]+\([^\r\n]*\)[^{]*\{(?<body>.*?)^\}')) {
        $body = $function.Groups['body'].Value
        $calls = [regex]::Matches($body, '(?m)^\s*(?:%[A-Za-z0-9_]+ = )?call [^\r\n]*@sollang_fn_sollang_compiler_llvm_text_emitCore\((?<arguments>[^\r\n]*)\)')
        if ($calls.Count -eq 0) { continue }
        if ($calls.Count -ne 1) { throw 'Entry function must invoke emitCore exactly once.' }
        $arguments = @($calls[0].Groups['arguments'].Value.Split(',') | ForEach-Object { $_.Trim() })
        $pointers = @(Get-SplitContextStateParameters -Parameters $arguments -FollowingParameters 0)
        if ($pointers[0] -notmatch '^ptr (?<owner>%[A-Za-z0-9_]+)$') { throw 'Entry context argument is not a pointer.' }
        $owner = [regex]::Escape($Matches.owner)
        $allocations = [regex]::Matches($body, '(?m)^\s*(?<pointer>' + $owner + ') = alloca (?<type>%sollang\.struct\.[0-9]+), align [0-9]+\r?$')
        if ($allocations.Count -ne 1) { throw 'Entry context must have exactly one owner in its own function.' }
        $allocations[0]
    }
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $repoRoot "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll"
$manifest = Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
$outputRoot = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $repoRoot ("artifacts/scratch/llvm-emitter-split-abi-" + [guid]::NewGuid().ToString('N'))
} else {
    [IO.Path]::GetFullPath($OutputDirectory)
}
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -and
    (Test-Path -LiteralPath $outputRoot)) {
    throw "LLVM emitter split ABI output already exists: $outputRoot"
}
$output = Join-Path $outputRoot "generator.exe"
$llvm = "${output}.ll"
$fragmentPaths = @(
    "selfhost/llvm/text/entry_expressions.slg"
    "selfhost/llvm/text/core_prepare.slg"
    "selfhost/llvm/text/core_calls.slg"
    "selfhost/llvm/text/call_arguments.slg"
    "selfhost/llvm/text/ownership.slg"
    "selfhost/llvm/text/platform_io.slg"
    "selfhost/llvm/text/containers.slg"
    "selfhost/llvm/text/container_control.slg"
    "selfhost/llvm/text/control.slg"
    "selfhost/llvm/text/control_regions.slg"
    "selfhost/llvm/text/control_region_expressions.slg"
    "selfhost/llvm/text/functions.slg"
    "selfhost/llvm/text/function_expressions.slg"
    "selfhost/llvm/text/function_calls.slg"
    "selfhost/llvm/text/function_returns.slg"
)
$readonlyFragmentPaths = @(
    "selfhost/llvm/emitter/diagnostics.slg"
    "selfhost/llvm/text/foundation.slg"
    "selfhost/llvm/text/text_literals.slg"
    "selfhost/llvm/text/native_handles.slg"
)

New-Item -ItemType Directory -Force $outputRoot | Out-Null
$sources = [IO.File]::ReadAllLines($manifest)
$sources[0] = "examples/regression/1195-selfhost-emitter-split-abi.slg"
$stdlibSources = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'stdlib') -Recurse -File -Filter '*.slg' |
    ForEach-Object { $_.FullName })
& (Join-Path $PSScriptRoot 'verify-source-manifest-closure.ps1') -SourcePath (@($sources) + $stdlibSources)

$declarationPattern = [regex]::new(
    '(?m)^([A-Za-z_][A-Za-z0-9_]*)[^\r\n{]*context: ref emitterContext\.EmitContext, state: ref CoreEmitterState[^\r\n{]*\{')
$helperTrailingParameters = @{}
$helperNames = foreach ($relativePath in $fragmentPaths) {
    $source = [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
    foreach ($match in $declarationPattern.Matches($source)) {
        $suffix = [regex]::Match($match.Value, 'state: ref CoreEmitterState(?<following>.*?) ->')
        if (-not $suffix.Success -or $suffix.Groups['following'].Value -notmatch '^(?:, [A-Za-z_][A-Za-z0-9_]*: Int)*$') {
            throw "Unsupported split helper parameter suffix: $($match.Value)"
        }
        $helperTrailingParameters[$match.Groups[1].Value] = [regex]::Matches($suffix.Groups['following'].Value, ', ').Count
        $match.Groups[1].Value
    }
}
$helperNames = @($helperNames | Sort-Object -Unique)
if ($helperNames.Count -ne 549) {
    throw "Expected 549 reachable stateful split helpers, found $($helperNames.Count). Update the ABI gate with the intentional split."
}
$requiredStatefulHelpers = @(
    "boundedIntrinsicDictionaryTypeId"
    "emitAsyncFileScalarCall"
    "usesReachableAsyncFileRuntime"
    "usesReachableAsyncRuntime"
    "emitBoundedDictionaryIndexAssignment"
    "emitBoundedDictionaryPut"
    "emitBoundedDictionaryTake"
    "emitCancelTaskValue"
    "emitCompletedFileRead"
    "emitDeferredBoolTextRoot"
    "emitWhilePathText"
    "isImportedLibraryFunction"
    "targetsImportedLibraryFunction"
    "emitNativeTargetLoad"
    "writeResolvedCallTarget"
    "emitImportedLibraryGlobals"
    "isNativePathStyleCall"
    "emitNativePathStyleValue"
    "emitAwaitTaskValue"
    "emitDurationSleepTask"
    "emitAsyncFunction"
    "workerTryParallelResultType"
    "emitExchange"
)
foreach ($requiredStatefulHelper in $requiredStatefulHelpers) {
    if ($requiredStatefulHelper -notin $helperNames) {
        throw "Stateful split helper '$requiredStatefulHelper' is missing from the pointer-ABI gate."
    }
}

$readonlyDeclarationPattern = [regex]::new(
    '(?m)^(?:public\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+context: ref emitterContext\.EmitContext[^\r\n{]*\{')
$readonlyHelpers = foreach ($relativePath in $readonlyFragmentPaths) {
    $source = [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
    $modulePrefix = if ($relativePath -eq "selfhost/llvm/emitter/diagnostics.slg") {
        "sollang_compiler_llvm_emitter_diagnostics"
    } else {
        "sollang_compiler_llvm_text"
    }
    foreach ($match in $readonlyDeclarationPattern.Matches($source)) {
        $helperName = $match.Groups[1].Value
        [pscustomobject]@{
            Name = $helperName
            LlvmName = "sollang_fn_${modulePrefix}_$helperName"
        }
    }
}
$readonlyHelpers = @($readonlyHelpers | Sort-Object LlvmName -Unique)
if ($readonlyHelpers.Count -ne 191) {
    throw "Expected 191 readonly-context helpers, found $($readonlyHelpers.Count). Update the ABI gate with the intentional split."
}
$requiredDiagnosticReadonlyHelpers = @(
    "boundedDictionaryInitializerDiagnostics"
    "comparisonOperandDiagnosticCount"
    "expressionOperandDiagnosticCount"
    "comparisonOperandFailureAt"
    "dictionaryPutArgumentDiagnostics"
    "emitComparisonOperandDiagnostics"
    "emitExpressionOperandDiagnostics"
    "emitUnresolvedMutableNameDiagnostics"
    "emitConsumedBindingReadDiagnostics"
    "invalidInterpolationFlowTargetNode"
    "isBlockingMappedIndexInterpolation"
    "isBlockingInvalidUnaryInterpolation"
    "usesMappedBytesRuntime"
    "arrayElementLayoutDiagnosticCount"
    "emitArrayElementLayoutDiagnostics"
    "libraryImportDiagnosticCount"
    "emitLibraryImportDiagnostics"
    "emitOpenImportAmbiguity"
)
foreach ($requiredDiagnosticReadonlyHelper in $requiredDiagnosticReadonlyHelpers) {
    if ($requiredDiagnosticReadonlyHelper -notin $readonlyHelpers.Name) {
        throw "Diagnostic helper '$requiredDiagnosticReadonlyHelper' is missing from the readonly pointer-ABI gate."
    }
}
# Inventory and closure checks finish before the expensive compiler build.
$llvmHome = Join-Path $repoRoot '.tools/llvm-22.1.8'
if (-not (Test-Path -LiteralPath (Join-Path $llvmHome 'bin/clang.exe') -PathType Leaf)) {
    throw 'LLVM emitter split ABI pinned clang tool is missing.'
}
& dotnet $compiler build @sources -o $output --keep-temps --llvm $llvmHome
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $llvm -PathType Leaf)) {
    throw "Emitter split ABI LLVM was not produced: $llvm"
}
$llvmText = [IO.File]::ReadAllText($llvm)
foreach ($helper in $readonlyHelpers) {
    $helperName = $helper.Name
    $llvmName = $helper.LlvmName
    $escapedName = [regex]::Escape($llvmName)
    $definition = [regex]::Match(
        $llvmText,
        "(?m)^define [^`r`n]*@$escapedName\((?<parameters>[^)]*)\)")
    if (-not $definition.Success) {
        throw "Generated LLVM omits readonly-context helper '$helperName'."
    }
    $parameters = @($definition.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
    if ($parameters.Count -lt 1 -or $parameters[0] -notmatch '^ptr %') {
        throw "Readonly-context helper '$helperName' copies EmitContext by value: $($definition.Value)"
    }
}

$helperLlvmNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$unreferencedHelpers = [Collections.Generic.List[string]]::new()
$selfhostSourceText = [string]::Join("`n", @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'selfhost') -Recurse -File -Filter '*.slg' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }))
foreach ($helperName in $helperNames) {
    $llvmName = "sollang_fn_sollang_compiler_llvm_text_$helperName"
    $null = $helperLlvmNames.Add($llvmName)
    $escapedName = [regex]::Escape($llvmName)
    $definition = [regex]::Match(
        $llvmText,
        "(?m)^define [^`r`n]*@$escapedName\((?<parameters>[^)]*)\)")
    if (-not $definition.Success) {
        # The source inventory also includes unused declarations. Accept their
        # omission only when the name appears exactly once in all selfhost
        # source (its declaration); every referenced helper remains mandatory.
        if (Test-UnreferencedSplitHelper -Name $helperName -SourceText $selfhostSourceText -LlvmText $llvmText) {
            $unreferencedHelpers.Add($helperName)
            continue
        }
        throw "Generated LLVM omits split helper '$helperName'."
    }

    $parameters = @($definition.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
    $pointerParameters = @(Get-SplitContextStateParameters -Parameters $parameters -FollowingParameters $helperTrailingParameters[$helperName])
    if ($pointerParameters[0] -notmatch '^ptr %' -or $pointerParameters[1] -notmatch '^ptr %') {
        throw "Split helper '$helperName' does not pass EmitContext/CoreEmitterState as two pointers: $($definition.Value)"
    }
}

$emitCore = [regex]::Match(
    $llvmText,
    '(?ms)^define [^\r\n]*@sollang_fn_sollang_compiler_llvm_text_emitCore\((?<parameters>[^)]*)\)[^{]*\{(?<body>.*?)^\}')
if (-not $emitCore.Success) {
    throw "Generated LLVM omits emitCore."
}
$emitCoreParameters = @($emitCore.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
if ($emitCoreParameters.Count -lt 2 `
    -or $emitCoreParameters[-2] -notmatch '^ptr %' `
    -or $emitCoreParameters[-1] -notmatch '^ptr %') {
    throw "emitCore must borrow EmitContext and CoreEmitterState as its two trailing pointer parameters: $($emitCore.Value.Split("`n")[0])"
}

$coreAggregateAllocations = @([regex]::Matches(
    $emitCore.Groups["body"].Value,
    '(?m)^\s*(?<pointer>%ref_arg[0-9]+) = alloca (?<type>%sollang\.struct\.[0-9]+), align [0-9]+\r?$'))
if ($coreAggregateAllocations.Count -ne 0) {
    throw "emitCore must reuse its borrowed EmitContext/CoreEmitterState pointers without aggregate rematerialization; found $($coreAggregateAllocations.Count) aggregate reference slots."
}

$stateFactory = [regex]::Match(
    $llvmText,
    '(?m)^define [^\r\n]*?(?<type>%sollang\.struct\.[0-9]+) @sollang_fn_sollang_compiler_llvm_text_prepareScheduledCoreEmitterState\(')
if (-not $stateFactory.Success) {
    throw "Generated LLVM omits the CoreEmitterState preparation boundary."
}
$stateType = $stateFactory.Groups["type"].Value

$contextMaterializations = @(Get-SplitContextMaterializations -LlvmText $llvmText)
if ($contextMaterializations.Count -ne 3) {
    throw "Expected the Windows, Linux, and Wasm entry points to each materialize one EmitContext owner; found $($contextMaterializations.Count)."
}
$contextTypes = @($contextMaterializations | ForEach-Object { $_.Groups["type"].Value } | Sort-Object -Unique)
if ($contextTypes.Count -ne 1) {
    throw "Entry points disagree on the EmitContext LLVM type: $($contextTypes -join ', ')"
}
$contextType = $contextTypes[0]

$helperNamePattern = [string]::Join(
    "|",
    @($helperLlvmNames | ForEach-Object { [regex]::Escape($_) }))
$helperDefinitionPattern = [regex]::new(
    "(?ms)^define [^`r`n]*@(?<name>$helperNamePattern)\((?<parameters>[^)]*)\)[^{]*\{(?<body>.*?)^\}")
$forwardedCalls = 0
foreach ($definition in $helperDefinitionPattern.Matches($llvmText)) {
    $parameters = @($definition.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
    $sourceHelperName = $definition.Groups['name'].Value.Substring('sollang_fn_sollang_compiler_llvm_text_'.Length)
    $pointerParameters = @(Get-SplitContextStateParameters -Parameters $parameters -FollowingParameters $helperTrailingParameters[$sourceHelperName])
    $contextParameter = [regex]::Match($pointerParameters[0], '^ptr (?<pointer>%[A-Za-z0-9_]+)$')
    $stateParameter = [regex]::Match($pointerParameters[1], '^ptr (?<pointer>%[A-Za-z0-9_]+)$')
    if (-not $contextParameter.Success -or -not $stateParameter.Success) {
        throw "Split helper '$($definition.Groups["name"].Value)' has an invalid context/state pointer tail."
    }

    $body = $definition.Groups["body"].Value
    if ($body -match "(?m)^\s*%[A-Za-z0-9_]+ = alloca ($([regex]::Escape($contextType))|$([regex]::Escape($stateType))),") {
        throw "Split helper '$($definition.Groups["name"].Value)' rematerializes EmitContext/CoreEmitterState."
    }

    $calls = [regex]::Matches(
        $body,
        "(?m)^\s*(?:%[A-Za-z0-9_]+ = )?call [^@`r`n]+@(?<name>$helperNamePattern)\((?<arguments>[^`r`n]*)\)")
    foreach ($call in $calls) {
        $arguments = @($call.Groups["arguments"].Value.Split(",") | ForEach-Object { $_.Trim() })
        $calleeHelperName = $call.Groups['name'].Value.Substring('sollang_fn_sollang_compiler_llvm_text_'.Length)
        $tail = @(Get-SplitContextStateParameters -Parameters $arguments -FollowingParameters $helperTrailingParameters[$calleeHelperName])
        $expectedTail = @(
            "ptr $($contextParameter.Groups["pointer"].Value)",
            "ptr $($stateParameter.Groups["pointer"].Value)")
        if ($tail.Count -ne 2 -or $tail[0] -ne $expectedTail[0] -or $tail[1] -ne $expectedTail[1]) {
            throw "Split helper '$($definition.Groups["name"].Value)' recopies context/state when calling '$($call.Groups["name"].Value)'."
        }
        $forwardedCalls++
    }
}
if ($forwardedCalls -lt 1) {
    throw "Split ABI gate did not inspect any helper-to-helper calls."
}

$typedComHelper = [regex]::Match(
    $llvmText,
    '(?m)^define [^\r\n]*@sollang_fn_sollang_compiler_ir_typed_lowerComGeneratedFunction\((?<parameters>[^)]*)\)')
if (-not $typedComHelper.Success) {
    throw "Generated LLVM omits the C80 Typed IR COM fragment helper."
}
$typedComParameters = @($typedComHelper.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
$typedComUserParameters = @($typedComParameters | Select-Object -Last 4)
if ($typedComUserParameters.Count -ne 4 `
    -or $typedComUserParameters[0] -notmatch '^ptr %' `
    -or $typedComUserParameters[1] -notmatch '^ptr %' `
    -or $typedComUserParameters[2] -notmatch '^ptr %') {
    throw "Typed IR COM fragment copies its prepared snapshot or canonical tables by value: $($typedComHelper.Value)"
}

$typedComCalls = @([regex]::Matches(
    $llvmText,
    '(?m)^\s*(?:%[A-Za-z0-9_]+ = )?call [^\r\n]*@sollang_fn_sollang_compiler_ir_typed_lowerComGeneratedFunction\((?<arguments>[^\r\n]*)\)'))
if ($typedComCalls.Count -lt 1) {
    throw "Generated LLVM does not exercise the C80 Typed IR COM fragment call boundary."
}
foreach ($typedComCall in $typedComCalls) {
    $arguments = @($typedComCall.Groups["arguments"].Value.Split(",") | ForEach-Object { $_.Trim() })
    $userArguments = @($arguments | Select-Object -Last 4)
    if ($userArguments.Count -ne 4 `
        -or $userArguments[0] -notmatch '^ptr %' `
        -or $userArguments[1] -notmatch '^ptr %' `
        -or $userArguments[2] -notmatch '^ptr %') {
        throw "Typed IR COM fragment call rematerializes its prepared snapshot or canonical tables: $($typedComCall.Value)"
    }
}

$typedShapeHelper = [regex]::Match(
    $llvmText,
    '(?m)^define [^\r\n]*@sollang_fn_sollang_compiler_ir_typed_declaredArrayShapeKind\((?<parameters>[^)]*)\)')
if (-not $typedShapeHelper.Success) {
    throw "Generated LLVM omits the C80 Typed IR type-query fragment helper."
}
$typedShapeParameters = @($typedShapeHelper.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
$typedShapeUserParameters = @($typedShapeParameters | Select-Object -Last 3)
if ($typedShapeUserParameters.Count -ne 3 `
    -or $typedShapeUserParameters[0] -notmatch '^ptr %' `
    -or $typedShapeUserParameters[1] -notmatch '^i32 %' `
    -or $typedShapeUserParameters[2] -notmatch '^i32 %') {
    throw "Typed IR type-query fragment copies its prepared snapshot or changed its scalar ABI: $($typedShapeHelper.Value)"
}

$typedShapeCalls = @([regex]::Matches(
    $llvmText,
    '(?m)^\s*(?:%[A-Za-z0-9_]+ = )?call [^\r\n]*@sollang_fn_sollang_compiler_ir_typed_declaredArrayShapeKind\((?<arguments>[^\r\n]*)\)'))
if ($typedShapeCalls.Count -lt 1) {
    throw "Generated LLVM does not exercise the C80 Typed IR type-query fragment call boundary."
}
foreach ($typedShapeCall in $typedShapeCalls) {
    $arguments = @($typedShapeCall.Groups["arguments"].Value.Split(",") | ForEach-Object { $_.Trim() })
    $userArguments = @($arguments | Select-Object -Last 3)
    if ($userArguments.Count -ne 3 `
        -or $userArguments[0] -notmatch '^ptr %' `
        -or $userArguments[1] -notmatch '^i32 ' `
        -or $userArguments[2] -notmatch '^i32 ') {
        throw "Typed IR type-query fragment call copies its prepared snapshot or changed its scalar ABI: $($typedShapeCall.Value)"
    }
}

$typedResultQueryHelper = [regex]::Match(
    $llvmText,
    '(?m)^define [^\r\n]*@sollang_fn_sollang_compiler_ir_typed_comGeneratedResultTypeId\((?<parameters>[^)]*)\)')
if (-not $typedResultQueryHelper.Success) {
    throw "Generated LLVM omits the C80 Typed IR COM result-query helper."
}
$typedResultQueryParameters = @($typedResultQueryHelper.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
$typedResultQueryUserParameters = @($typedResultQueryParameters | Select-Object -Last 4)
if ($typedResultQueryUserParameters.Count -ne 4 `
    -or $typedResultQueryUserParameters[0] -notmatch '^ptr %' `
    -or $typedResultQueryUserParameters[1] -notmatch '^i32 %' `
    -or $typedResultQueryUserParameters[2] -notmatch '^i32 %' `
    -or $typedResultQueryUserParameters[3] -notmatch '^i32 %') {
    throw "Typed IR COM result query copies its canonical type table or changed its scalar ABI: $($typedResultQueryHelper.Value)"
}

$typedResultQueryCalls = @([regex]::Matches(
    $llvmText,
    '(?m)^\s*(?:%[A-Za-z0-9_]+ = )?call [^\r\n]*@sollang_fn_sollang_compiler_ir_typed_comGeneratedResultTypeId\((?<arguments>[^\r\n]*)\)'))
if ($typedResultQueryCalls.Count -lt 1) {
    throw "Generated LLVM does not exercise the C80 Typed IR COM result-query boundary."
}
foreach ($typedResultQueryCall in $typedResultQueryCalls) {
    $arguments = @($typedResultQueryCall.Groups["arguments"].Value.Split(",") | ForEach-Object { $_.Trim() })
    $userArguments = @($arguments | Select-Object -Last 4)
    if ($userArguments.Count -ne 4 `
        -or $userArguments[0] -notmatch '^ptr %' `
        -or $userArguments[1] -notmatch '^i32 ' `
        -or $userArguments[2] -notmatch '^i32 ' `
        -or $userArguments[3] -notmatch '^i32 ') {
        throw "Typed IR COM result-query call copies its canonical type table or changed its scalar ABI: $($typedResultQueryCall.Value)"
    }
}

Write-Host "PASS LLVM emitter split ABI: source stateful helpers=$($helperNames.Count), emitted stateful helpers=$($helperNames.Count - $unreferencedHelpers.Count), unreferenced declarations=$($unreferencedHelpers.Count), readonly helpers=$($readonlyHelpers.Count), entry-context owners=3, core-state materializations=0, helper forwards=$forwardedCalls, typed-borrowed-tables=5, typed-com-calls=$($typedComCalls.Count), typed-shape-calls=$($typedShapeCalls.Count), typed-result-query-calls=$($typedResultQueryCalls.Count), per-call aggregate copies=0"
