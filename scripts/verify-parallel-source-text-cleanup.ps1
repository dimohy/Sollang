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
$runtimePath = Join-Path $root 'selfhost/llvm/runtime.slg'
$harnessPath = Join-Path $PSScriptRoot 'contracts/fixtures/parallel-source-text-cleanup.c'
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
foreach ($path in @($sourcePath, $runtimePath, $harnessPath, $PSCommandPath,
    (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1'))) {
    $inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$baseline = (& git -C $root show "${baselineCommit}:selfhost/llvm/text/ownership.slg") -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Frozen selfhost payload cleanup baseline is unavailable.' }
$candidate = [IO.File]::ReadAllText($sourcePath)
$runtime = [IO.File]::ReadAllText($runtimePath).Replace("`r`n", "`n")
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
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'production-payload-instructions-and-runtime-cfg-native-execution-with-observed-terminals'
    completed = 0
    total = 8
    baselineCommit = $baselineCommit
    baselineOnly = [bool]$BaselineOnly
    inputHashes = $inputHashes
    modes = @()
    observedTerminalSymbols = @('free', 'UnmapViewOfFile', 'munmap')
    fixedExtractionInputs = @('SourceText builtin kind=1/origin=1/symbol=24', 'array kind=3', 'payload alignment=8', 'nameRoot=pointerRoot=1')
    excluded = @('SLG emitter/type lookup execution', 'tryParallel scheduling and initialized-slot selection', 'real allocator and OS unmap execution', 'Linux target execution', 'whole selfhost compiler integration', 'Stage2/Stage3')
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
} catch { $record.status = 'failed'; $record.failure = $_.Exception.Message; throw }
finally { Save-Result }
Write-Host "[parallel SourceText cleanup] PASS 8/8 per mode; $resultPath"
