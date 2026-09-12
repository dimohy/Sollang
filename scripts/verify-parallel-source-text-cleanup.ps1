[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$BaselineOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$sourcePath = Join-Path $root 'selfhost/llvm/text/ownership.slg'
$transferPath = Join-Path $root 'selfhost/llvm/text/core_calls.slg'
$runtimePath = Join-Path $root 'selfhost/llvm/runtime.slg'
$harnessPath = Join-Path $PSScriptRoot 'contracts/fixtures/parallel-source-text-cleanup.c'
$transferHarnessPath = Join-Path $PSScriptRoot 'contracts/fixtures/c402-worker-transfer-type.slg.in'
$compilerPath = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$closureVerifierPath = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$llvmHome = Join-Path $root '.tools/llvm-22.1.8'
$baselineCommit = 'baf9f8cb897c0971077823c4d4f4ec20ea85f1de'

function Get-PayloadBranch {
    param([string]$Text, [ValidateSet('source', 'array')][string]$Kind)
    $pattern = if ($Kind -eq 'source') {
        '(?ms)^    payloadType\.kind == 1 and payloadType\.origin == 1 and payloadType\.symbol == 24\n        -> if \{\n(?<body>.*?)^        \}'
    } else {
        '(?ms)^    payloadType\.kind == 3 -> if \{\n(?<body>.*?)^    \}'
    }
    $matches = [regex]::Matches($Text.Replace("`r`n", "`n"), $pattern)
    if ($matches.Count -ne 1) { throw "Expected one production $Kind payload branch; found $($matches.Count)." }
    return $matches[0]
}

function Convert-PayloadInstructions {
    param([string]$Body)
    # This narrow renderer accepts only the production print instructions and
    # one explicit ABI alignment lookup. Unexpected new source syntax fails.
    # It does not pretend to execute the entire SLG emitter or its type lookup.
    $output = [Text.StringBuilder]::new()
    foreach ($line in ($Body -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) { continue }
        if ($trimmed -ceq 'context.typeAligns[request.payloadTypeId] -> writeDecimalLine') {
            [void]$output.Append("8`n")
            continue
        }
        $print = [regex]::Match($trimmed, '^"(?<text>[^"\r\n]*)" -> (?<sink>print|println)$')
        if (-not $print.Success) { throw "Unsupported production payload instruction: $trimmed" }
        $value = $print.Groups['text'].Value.Replace('$(request.nameRoot)', '1').Replace('$(request.pointerRoot)', '1')
        if ($value.Contains('$(')) { throw "Unresolved production interpolation: $value" }
        [void]$output.Append($value)
        if ($print.Groups['sink'].Value -ceq 'println') { [void]$output.Append("`n") }
    }
    return $output.ToString()
}

function Get-StringHash {
    param([string]$Text)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text)))
}

$inputHashes = [ordered]@{}
foreach ($path in @($sourcePath, $transferPath, $runtimePath, $harnessPath, $transferHarnessPath,
    $compilerPath, $closureVerifierPath, $PSCommandPath,
    (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Probe input is missing: $path" }
    $inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$baseline = (& git -C $root show "${baselineCommit}:selfhost/llvm/text/ownership.slg") -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Frozen selfhost payload cleanup baseline is unavailable.' }
$candidate = [IO.File]::ReadAllText($sourcePath)
$transferSource = [IO.File]::ReadAllText($transferPath).Replace("`r`n", "`n")
$runtime = [IO.File]::ReadAllText($runtimePath).Replace("`r`n", "`n")
$workerTransferMatches = [regex]::Matches(
    $transferSource,
    '(?ms)^workerTransferType typeId:.*?^\}')
if ($workerTransferMatches.Count -ne 1) {
    throw "Expected one production workerTransferType declaration; found $($workerTransferMatches.Count)."
}
$workerTransferBody = $workerTransferMatches[0].Value
if (-not $workerTransferBody.Contains(
        '(currentType.symbol >= 19 and currentType.symbol <= 23)',
        [StringComparison]::Ordinal) -or
    $workerTransferBody.Contains('currentType.symbol <= 24', [StringComparison]::Ordinal)) {
    throw 'General recursive worker transfer policy must keep SourceText containers and nested enums closed.'
}
$directTransferMatches = [regex]::Matches(
    $transferSource,
    '(?ms)^directWorkerSourceTextType typeId:.*?^\}')
$tryResultTransferMatches = [regex]::Matches(
    $transferSource,
    '(?ms)^workerTryParallelResultType typeId:.*?^\}')
if ($directTransferMatches.Count -ne 1 -or $tryResultTransferMatches.Count -ne 1) {
    throw 'Expected one direct SourceText and one tryParallel Result worker-transfer authority.'
}
$directTransferBody = $directTransferMatches[0].Value
$tryResultTransferBody = $tryResultTransferMatches[0].Value
foreach ($required in @(
    'candidate.symbol == 24',
    'resultType.symbol == 1',
    'resultType.first -> directWorkerSourceTextType(context)',
    'resultType.second -> directWorkerSourceTextType(context)')) {
    if (-not ($directTransferBody + $tryResultTransferBody).Contains($required, [StringComparison]::Ordinal)) {
        throw "Direct SourceText tryParallel worker-transfer authority lost: $required"
    }
}
if (-not $transferSource.Contains(
        'parallelCall.typeId -> workerTryParallelResultType(context, state)',
        [StringComparison]::Ordinal)) {
    throw 'tryParallel compute-pool admission no longer uses the direct Result transfer authority.'
}
$sourceBranches = [ordered]@{ baseline = (Get-PayloadBranch $baseline source) }
if (-not $BaselineOnly) { $sourceBranches.candidate = Get-PayloadBranch $candidate source }
$arrayBaseline = Get-PayloadBranch $baseline array
$arrayCandidate = Get-PayloadBranch $candidate array
if ($arrayBaseline.Value -cne $arrayCandidate.Value) { throw 'The existing array cleanup branch changed outside this repair.' }
$arrayInstructions = Convert-PayloadInstructions $arrayCandidate.Groups['body'].Value
$runtimeFunctions = [regex]::Matches($runtime, '(?ms)^\s*define void @sollang_runtime_unmap_text\([^\n]+\) \{.*?^\s*\}')
if ($runtimeFunctions.Count -ne 2) { throw 'Expected exactly two production native SourceText runtime cleanup declarations.' }
$platformRuntimes = [ordered]@{}
foreach ($platform in @('windows', 'linux')) {
    $symbol = if ($platform -eq 'windows') { '@UnmapViewOfFile(' } else { '@munmap(' }
    $matching = @($runtimeFunctions | Where-Object { $_.Value.Contains($symbol) })
    if ($matching.Count -ne 1) { throw "Expected one $platform runtime cleanup body." }
    $platformRuntimes[$platform] = $matching[0].Value
}

$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name 'parallel-source-text-cleanup' -Harness $harnessPath
$resultPath = Join-Path $probe.Output 'result.json'
$transferGeneratedPath = Join-Path $probe.Output 'c402-worker-transfer-type.slg'
$transferExecutablePath = Join-Path $probe.Output 'c402-worker-transfer-type.exe'
$transferLlvmPath = Join-Path $probe.Output 'c402-worker-transfer-type.ll'
$transferRunLogPath = Join-Path $probe.Output 'c402-worker-transfer-type.stdout.txt'
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'production-worker-transfer-policy-payload-instructions-and-runtime-cfg-native-execution-with-observed-terminals'
    completed = 0
    total = 8
    baselineCommit = $baselineCommit
    baselineOnly = [bool]$BaselineOnly
    inputHashes = $inputHashes
    modes = @()
    transferPolicy = [ordered]@{
        status = 'pending'
        completed = 0
        total = 45
        rows = 15
        stdout = $transferRunLogPath
    }
    observedTerminalSymbols = @('free', 'UnmapViewOfFile', 'munmap')
    fixedExtractionInputs = @('tryParallel Result admits direct SourceText builtin symbol=24', 'general recursive workerTransferType excludes SourceText', 'SourceText builtin kind=1/origin=1/symbol=24', 'array kind=3', 'payload alignment=8', 'nameRoot=pointerRoot=1')
    excluded = @('whole SLG LLVM emitter execution', 'tryParallel scheduling and initialized-slot selection', 'real allocator and OS unmap execution', 'Linux target execution', 'whole selfhost compiler integration', 'Stage2/Stage3')
    compilerIntegration = 'pending'
}
function Save-Result { [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 7) + "`n")) }
$declarations = @'
%sollang.source_text = type { ptr, i64, ptr, i64 }
%sollang.array.i32 = type { ptr, i64, i64 }
declare void @sollang_probe_free(ptr)
declare i32 @sollang_probe_windows_unmap(ptr)
declare i32 @sollang_probe_linux_unmap(ptr, i64)
'@
$wrappers = @'
define void @sollang_probe_source(ptr %owner, i64 %length) {
entry:
  %enumdrop1_payload_ptr = alloca %sollang.source_text, align 8
  %v0 = insertvalue %sollang.source_text zeroinitializer, ptr %owner, 2
  %v1 = insertvalue %sollang.source_text %v0, i64 %length, 3
  store %sollang.source_text %v1, ptr %enumdrop1_payload_ptr, align 8
__SOURCE_PAYLOAD__
  ret void
}
define void @sollang_probe_array(ptr %data) {
entry:
  %enumdrop1_payload_ptr = alloca %sollang.array.i32, align 8
  %v0 = insertvalue %sollang.array.i32 zeroinitializer, ptr %data, 0
  store %sollang.array.i32 %v0, ptr %enumdrop1_payload_ptr, align 8
__ARRAY_PAYLOAD__
  ret void
}
'@
try {
    Save-Result
    $transferTemplate = [IO.File]::ReadAllText($transferHarnessPath).Replace("`r`n", "`n")
    $transferReplacements = [ordered]@{
        '__WORKER_TRANSFER_TYPE__' = $workerTransferBody.Replace('emitterContext.EmitContext', 'EmitContext')
        '__DIRECT_SOURCE_TEXT_TYPE__' = $directTransferBody.Replace('emitterContext.EmitContext', 'EmitContext')
        '__TRY_PARALLEL_RESULT_TYPE__' = $tryResultTransferBody.Replace('emitterContext.EmitContext', 'EmitContext')
    }
    foreach ($placeholder in $transferReplacements.Keys) {
        if ([regex]::Matches($transferTemplate, [regex]::Escape($placeholder)).Count -ne 1) {
            throw "C402 transfer fixture must contain exactly one $placeholder placeholder."
        }
        $transferTemplate = $transferTemplate.Replace($placeholder, $transferReplacements[$placeholder])
    }
    [IO.File]::WriteAllText($transferGeneratedPath, $transferTemplate, [Text.UTF8Encoding]::new($false))
    & dotnet $compilerPath format --check $transferGeneratedPath
    if ($LASTEXITCODE -ne 0) { throw 'Generated C402 worker-transfer fixture is not authoritative-format clean.' }

    $transferActual = (& dotnet $compilerPath run $transferGeneratedPath --llvm $llvmHome -o $transferExecutablePath --keep-temps 2>&1) -join "`n"
    $transferExitCode = $LASTEXITCODE
    [IO.File]::WriteAllText($transferRunLogPath, $transferActual + "`n", [Text.UTF8Encoding]::new($false))
    $transferExpected = @(
        'int=true,false,false',
        'source-text=false,true,false',
        'dynamic-source-text=false,false,false',
        'fixed-source-text=false,false,false',
        'option-source-text=false,false,false',
        'direct-result-source-text-ok=false,false,true',
        'direct-result-source-text-error=false,false,true',
        'direct-result-source-text-both=false,false,true',
        'result-dynamic-source-text=false,false,false',
        'result-fixed-source-text=false,false,false',
        'result-option-source-text=false,false,false',
        'result-nested-result=false,false,false',
        'invalid-source-text=false,false,false',
        'result-missing-error=true,false,false',
        'out-of-range=false,false,false',
        'C402 worker transfer matrix=true: 15/15,45/45'
    ) -join "`n"
    if ($transferExitCode -ne 0 -or $transferActual.Replace("`r`n", "`n").TrimEnd("`n") -cne $transferExpected) {
        throw "C402 worker-transfer matrix output mismatch (exit=$transferExitCode)."
    }
    if (-not (Test-Path -LiteralPath $transferLlvmPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $transferExecutablePath -PathType Leaf)) {
        throw 'C402 worker-transfer probe did not produce LLVM and executable outputs.'
    }
    & (Join-Path $llvmHome 'bin/llvm-as.exe') $transferLlvmPath -o (Join-Path $probe.Output 'c402-worker-transfer-type.bc')
    if ($LASTEXITCODE -ne 0) { throw 'C402 worker-transfer probe LLVM assembly failed.' }
    & $closureVerifierPath -LlvmPath $transferLlvmPath
    if ($LASTEXITCODE -ne 0) { throw 'C402 worker-transfer probe direct-call closure failed.' }
    $record.transferPolicy.status = 'passed'
    $record.transferPolicy.completed = 45
    $record.transferPolicy.warningCount = 0
    $record.transferPolicy.stdoutSha256 = Get-StringHash ($transferActual.Replace("`r`n", "`n").TrimEnd("`n") + "`n")
    $record.transferPolicy.generatedSourceSha256 = (Get-FileHash -LiteralPath $transferGeneratedPath -Algorithm SHA256).Hash
    $record.transferPolicy.llvmSha256 = (Get-FileHash -LiteralPath $transferLlvmPath -Algorithm SHA256).Hash
    $record.transferPolicy.executableSha256 = (Get-FileHash -LiteralPath $transferExecutablePath -Algorithm SHA256).Hash
    $record.transferPolicy.productionFunctionsSha256 = [ordered]@{
        workerTransferType = Get-StringHash $workerTransferBody
        directWorkerSourceTextType = Get-StringHash $directTransferBody
        workerTryParallelResultType = Get-StringHash $tryResultTransferBody
    }
    Save-Result
    foreach ($mode in $sourceBranches.Keys) {
        $sourceInstructions = Convert-PayloadInstructions $sourceBranches[$mode].Groups['body'].Value
        foreach ($platform in $platformRuntimes.Keys) {
            $body = "$declarations`n$($platformRuntimes[$platform])`n" + $wrappers.Replace('__SOURCE_PAYLOAD__', $sourceInstructions).Replace('__ARRAY_PAYLOAD__', $arrayInstructions)
            # Only terminal symbols are redirected. All production LLVM owner,
            # sentinel, payload load and control-flow instructions stay intact.
            $body = $body.Replace('@free(', '@sollang_probe_free(').Replace('@UnmapViewOfFile(', '@sollang_probe_windows_unmap(').Replace('@munmap(', '@sollang_probe_linux_unmap(')
            $expectedLines = if ($mode -eq 'baseline') {
                @('borrowed:free=1,windows=0,linux=0', 'heap:free=1,windows=0,linux=0', 'mapped:free=1,windows=0,linux=0', 'array:free=1,windows=0,linux=0')
            } elseif ($platform -eq 'windows') {
                @('borrowed:free=0,windows=0,linux=0', 'heap:free=1,windows=0,linux=0', 'mapped:free=0,windows=1,linux=0', 'array:free=1,windows=0,linux=0')
            } else {
                @('borrowed:free=0,windows=0,linux=0', 'heap:free=1,windows=0,linux=0', 'mapped:free=0,windows=0,linux=1', 'array:free=1,windows=0,linux=0')
            }
            $expected = ($expectedLines + "parallel cleanup $mode ${platform}: 4/4") -join "`r`n"
            $actual = Invoke-RuntimeLlvmProbe -Probe $probe -Authority "$mode-$platform" -Llvm $body -Arguments @($mode, $platform) -ExpectedOutput $expected
            $record.modes += [ordered]@{
                mode = $mode; runtimePlatform = $platform; executionHost = 'windows-x64'; completed = 4; total = 4
                branchSha256 = Get-StringHash $sourceBranches[$mode].Value
                runtimeDeclarationSha256 = Get-StringHash $platformRuntimes[$platform]
                arrayBranchSha256 = Get-StringHash $arrayCandidate.Value
                llvmSha256 = $actual.LlvmHash; executableSha256 = $actual.ExecutableHash
                runLog = Join-Path $probe.Output "$mode-$platform.execute.stdout.txt"
            }
            Save-Result
        }
    }
    foreach ($path in $inputHashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$path]) { throw "Probe input changed: $path" }
    }
    $record.completed = 8
    $record.status = 'passed'
    $record.baselineMappedMisdispatchObserved = $true
    $record.arrayBranchUnchanged = $true
    $record.inputsStable = $true
} catch {
    $record.status = 'failed'
    if ($record.transferPolicy.status -ne 'passed') { $record.transferPolicy.status = 'failed' }
    $record.failure = $_.Exception.Message
    throw
}
finally { Save-Result }
Write-Host "[parallel SourceText cleanup] PASS 8/8 per mode; worker transfer 45/45; $resultPath"
