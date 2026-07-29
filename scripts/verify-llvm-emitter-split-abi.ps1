[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $repoRoot "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll"
$manifest = Join-Path $repoRoot "examples/regression/expected/613-selfhost-com-runtime.sources.txt"
$outputRoot = Join-Path $repoRoot "artifacts/llvm-emitter-split-abi"
$output = Join-Path $outputRoot "generator.exe"
$temporary = [IO.Path]::ChangeExtension($output, ".slg-tmp")
$llvm = Join-Path $temporary "generator.ll"
$fragmentPaths = @(
    "selfhost/llvm/text/core_calls.slg"
    "selfhost/llvm/text/ownership.slg"
    "selfhost/llvm/text/platform_io.slg"
    "selfhost/llvm/text/containers.slg"
    "selfhost/llvm/text/control.slg"
    "selfhost/llvm/text/functions.slg"
)
$readonlyFragmentPaths = @(
    "selfhost/llvm/emitter/diagnostics.slg"
    "selfhost/llvm/text/foundation.slg"
    "selfhost/llvm/text/text_literals.slg"
    "selfhost/llvm/text/native_handles.slg"
)

New-Item -ItemType Directory -Force $outputRoot | Out-Null
$sources = [IO.File]::ReadAllLines($manifest)
& dotnet $compiler build @sources -o $output --keep-temps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path -LiteralPath $llvm -PathType Leaf)) {
    throw "Emitter split ABI LLVM was not produced: $llvm"
}

$declarationPattern = [regex]::new(
    '(?m)^([A-Za-z_][A-Za-z0-9_]*)[^\r\n{]*context: ref emitterContext\.EmitContext, state: ref CoreEmitterState[^\r\n{]*\{')
$helperNames = foreach ($relativePath in $fragmentPaths) {
    $source = [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
    foreach ($match in $declarationPattern.Matches($source)) {
        $match.Groups[1].Value
    }
}
$helperNames = @($helperNames | Sort-Object -Unique)
if ($helperNames.Count -ne 176) {
    throw "Expected 176 stateful split helpers, found $($helperNames.Count). Update the ABI gate with the intentional split."
}
$requiredLibraryHelpers = @(
    "isImportedLibraryFunction"
    "targetsImportedLibraryFunction"
    "emitNativeTargetLoad"
    "writeResolvedCallTarget"
    "emitImportedLibraryGlobals"
    "isNativePathStyleCall"
    "emitNativePathStyleValue"
)
foreach ($requiredLibraryHelper in $requiredLibraryHelpers) {
    if ($requiredLibraryHelper -notin $helperNames) {
        throw "Library interop split helper '$requiredLibraryHelper' is missing from the pointer-ABI gate."
    }
}

$llvmText = [IO.File]::ReadAllText($llvm)
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
if ($readonlyHelpers.Count -ne 50) {
    throw "Expected 50 readonly-context helpers, found $($readonlyHelpers.Count). Update the ABI gate with the intentional split."
}
$requiredLibraryReadonlyHelpers = @(
    "libraryImportDiagnosticCount"
    "emitLibraryImportDiagnostics"
)
foreach ($requiredLibraryReadonlyHelper in $requiredLibraryReadonlyHelpers) {
    if ($requiredLibraryReadonlyHelper -notin $readonlyHelpers.Name) {
        throw "Library diagnostic helper '$requiredLibraryReadonlyHelper' is missing from the readonly pointer-ABI gate."
    }
}
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
foreach ($helperName in $helperNames) {
    $llvmName = "sollang_fn_sollang_compiler_llvm_text_$helperName"
    $null = $helperLlvmNames.Add($llvmName)
    $escapedName = [regex]::Escape($llvmName)
    $definition = [regex]::Match(
        $llvmText,
        "(?m)^define [^`r`n]*@$escapedName\((?<parameters>[^)]*)\)")
    if (-not $definition.Success) {
        throw "Generated LLVM omits split helper '$helperName'."
    }

    $parameters = @($definition.Groups["parameters"].Value.Split(",") | ForEach-Object { $_.Trim() })
    if ($parameters.Count -lt 2 `
        -or $parameters[$parameters.Count - 2] -notmatch '^ptr %' `
        -or $parameters[$parameters.Count - 1] -notmatch '^ptr %') {
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
if ($emitCoreParameters.Count -lt 1 -or $emitCoreParameters[-1] -notmatch '^ptr %') {
    throw "emitCore copies EmitContext by value: $($emitCore.Value.Split("`n")[0])"
}

$stableAllocations = @([regex]::Matches(
    $emitCore.Groups["body"].Value,
    '(?m)^\s*(?<pointer>%ref_arg[0-9]+) = alloca (?<type>%sollang\.struct\.[0-9]+), align [0-9]+\r?$'))
if ($stableAllocations.Count -ne 1) {
    throw "emitCore must reuse its EmitContext pointer and materialize exactly one stable CoreEmitterState slot; found $($stableAllocations.Count) aggregate reference slots."
}
$statePointer = $stableAllocations[0].Groups["pointer"].Value
$stateType = $stableAllocations[0].Groups["type"].Value
$stateStores = [regex]::Matches(
    $emitCore.Groups["body"].Value,
    "(?m)^\s*store $([regex]::Escape($stateType)) [^,]+, ptr $([regex]::Escape($statePointer)),")
if ($stateStores.Count -ne 1) {
    throw "emitCore must initialize the stable CoreEmitterState slot exactly once; found $($stateStores.Count)."
}

$contextMaterializationPattern =
    '(?ms)^\s*(?<pointer>%ref_arg[0-9]+) = alloca (?<type>%sollang\.struct\.[0-9]+), align [0-9]+\r?\n' +
    '.*?^\s*call void @sollang_fn_sollang_compiler_llvm_text_emitCore\([^\r\n]*ptr \k<pointer>\)'
$contextMaterializations = @([regex]::Matches($llvmText, $contextMaterializationPattern))
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
    $contextParameter = [regex]::Match($parameters[$parameters.Count - 2], '^ptr (?<pointer>%[A-Za-z0-9_]+)$')
    $stateParameter = [regex]::Match($parameters[$parameters.Count - 1], '^ptr (?<pointer>%[A-Za-z0-9_]+)$')
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
        $tail = @($arguments | Select-Object -Last 2)
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

Write-Host "PASS LLVM emitter split ABI: stateful helpers=$($helperNames.Count), readonly helpers=$($readonlyHelpers.Count), entry-context owners=3, core-state materializations=1, helper forwards=$forwardedCalls, per-call aggregate copies=0"
