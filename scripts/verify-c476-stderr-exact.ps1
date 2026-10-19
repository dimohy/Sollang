[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedDllSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$StdlibRoot = 'stdlib',
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$schemaPath = Join-Path $PSScriptRoot 'contracts/c476-stderr-exact-result.schema.json'
$sourcePath = Join-Path $PSScriptRoot 'probes/console/c476-eprint-exact.slg'
$closurePath = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$nativeContractPath = Join-Path $PSScriptRoot 'contracts/native-exact-fixture-receipt.json'
$sourceSha256 = 'EFE8898E252D4EC59B50B7EF7DBC2FE7505D8B98A3BE83EFD09A54283242EF36'
# old + CRLF (eprintln), line1 + CRLF (eprint), tail (eprint, no final newline).
$expectedStderrHex = '6F6C640D0A6C696E65310D0A7461696C'
$expectedStderr = [Convert]::FromHexString($expectedStderrHex)
$expectedStderrSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expectedStderr))
$processObservationScope = 'root-handle-wait-and-1s-CIM-descendant-samples-with-creation-time;short-lived-reparented-descendants-not-proven'
$script:c476OrphanProcessIds = [Collections.Generic.HashSet[int]]::new()
$script:c476SurvivorHandles = [Collections.Generic.List[Diagnostics.Process]]::new()

function Get-C476Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-C476Source {
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
        (Get-C476Sha $sourcePath) -cne $sourceSha256) {
        throw 'C476_STDERR_SOURCE_SHA_MISMATCH'
    }
}

function Assert-C476ResultSchema([object]$Record) {
    $json = $Record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
        throw 'C476_STDERR_RESULT_SCHEMA_INVALID'
    }
    return $json
}

function Write-C476Result([string]$Path, [object]$Record) {
    $json = Assert-C476ResultSchema $Record
    $temporary = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

function Assert-C476ExactStderr([byte[]]$Actual) {
    if (-not [Linq.Enumerable]::SequenceEqual($Actual, $expectedStderr)) {
        throw 'C476_STDERR_BYTES_MISMATCH'
    }
}

function New-C476BuildArguments([bool]$Managed, [string]$Source, [string]$Product,
        [string]$LlvmDirectory, [string]$StdlibDirectory) {
    [string[]]$arguments = @('build', $Source, '-o', $Product,
        '--target', 'windows-x64', '--llvm', $LlvmDirectory)
    if (-not $Managed) {
        $arguments += @('--stdlib', $StdlibDirectory, '--jobs', '1')
    }
    $arguments += @('-O1', '--keep-temps')
    return $arguments
}

function Get-C476ExpectedArtifacts([bool]$Managed, [bool]$WithBitcode) {
    [string[]]$names = if ($Managed) {
        @('.sollang-cache', 'probe.slg-tmp', 'probe.exe', 'probe.ll')
    } else {
        @('probe.exe', 'probe.exe.ll')
    }
    if ($WithBitcode) { $names += 'probe.exe.bc' }
    return $names
}

if (-not $IsWindows) { throw 'C476_STDERR_PLATFORM_UNSUPPORTED: focused gate is windows-x64' }
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-C476Path([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

function Assert-C476NoReparse([string]$Path) {
    $cursor = [IO.Path]::GetPathRoot($Path)
    foreach ($part in ($Path.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $part) { continue }
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "C476_STDERR_REPARSE_PATH: $cursor"
        }
    }
}

function New-C476ExclusiveDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "C476_STDERR_OUTPUT_PARENT_MISSING: $parent"
    }
    Assert-C476NoReparse $parent
    if (-not ('C476StderrGateNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C476StderrGateNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C476StderrGateNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        throw "C476_STDERR_OUTPUT_EXISTS_OR_CREATE_FAILED: $Path"
    }
    Assert-C476NoReparse $Path
}

function Get-C476ProcessSnapshot {
    try {
        return @(Get-CimInstance Win32_Process -OperationTimeoutSec 5 -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                id = [int]$_.ProcessId
                parentId = [int]$_.ParentProcessId
                startedTicks = ([datetime]$_.CreationDate).ToUniversalTime().Ticks
            }
        })
    } catch {
        throw "C476_STDERR_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)"
    }
}

function Update-C476Descendants([Collections.Generic.Dictionary[int, long]]$Known,
        [object[]]$Snapshot, [int]$RootId, [long]$RootExitTicks) {
    $current = @{}
    foreach ($entry in $Snapshot) { $current[$entry.id] = $entry }
    $added = $true
    while ($added) {
        $added = $false
        foreach ($entry in $Snapshot) {
            if ($Known.ContainsKey($entry.id) -or -not $Known.ContainsKey($entry.parentId)) { continue }
            if ($entry.startedTicks -lt $Known[$entry.parentId]) { continue }
            if ($entry.parentId -eq $RootId) {
                if ($entry.startedTicks -gt $RootExitTicks) { continue }
            } elseif (-not $current.ContainsKey($entry.parentId) -or
                    $current[$entry.parentId].startedTicks -ne $Known[$entry.parentId]) {
                continue
            }
            $Known.Add($entry.id, [long]$entry.startedTicks)
            $added = $true
        }
    }
}

function Assert-C476NoLiveDescendants([Collections.Generic.Dictionary[int, long]]$Known,
        [object[]]$Snapshot, [int]$RootId, [string]$Description) {
    $live = @($Snapshot | Where-Object {
        $_.id -ne $RootId -and $Known.ContainsKey($_.id) -and
        $Known[$_.id] -eq $_.startedTicks
    } | ForEach-Object id | Sort-Object -Unique)
    if ($live.Count -eq 0) { return }
    foreach ($id in $live) { [void]$script:c476OrphanProcessIds.Add([int]$id) }
    throw "C476_STDERR_PROCESS_ORPHANED: $Description left observed descendants $($live -join ','); no PID-based termination attempted"
}

function Invoke-C476LoggedProcess([string]$File, [string[]]$Arguments, [string]$WorkingDirectory,
        [string]$StdoutPath, [string]$StderrPath, [string]$Description) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $out = [IO.File]::Create($StdoutPath)
    $err = [IO.File]::Create($StderrPath)
    $started = $false
    $known = [Collections.Generic.Dictionary[int, long]]::new()
    try {
        if (-not $process.Start()) { throw "C476_STDERR_PROCESS_START_FAILED: $Description" }
        $started = $true
        $known.Add($process.Id, $process.StartTime.ToUniversalTime().Ticks)
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($out)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($err)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(1000)) {
            Update-C476Descendants $known @(Get-C476ProcessSnapshot) $process.Id ([DateTimeOffset]::UtcNow.UtcTicks)
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                try { $process.Kill($true) } catch { }
                if (-not $process.WaitForExit(5000)) {
                    [void]$script:c476OrphanProcessIds.Add($process.Id)
                    throw "C476_STDERR_PROCESS_ORPHANED: $Description root survived timeout kill pid=$($process.Id)"
                }
                throw "C476_STDERR_PROCESS_TIMEOUT: $Description"
            }
        }
        $lastSnapshot = @(Get-C476ProcessSnapshot)
        Update-C476Descendants $known $lastSnapshot $process.Id $process.ExitTime.ToUniversalTime().Ticks
        Assert-C476NoLiveDescendants $known $lastSnapshot $process.Id $Description
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "C476_STDERR_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult()
        $out.Flush(); $err.Flush()
        return $process.ExitCode
    } finally {
        $rootSurvived = $false
        try {
            if ($started -and -not $process.HasExited) {
                try { $process.Kill($true) } catch { }
                if (-not $process.WaitForExit(5000)) {
                    $rootSurvived = $true
                    [void]$script:c476OrphanProcessIds.Add($process.Id)
                }
            }
            if ($started) {
                $lastSnapshot = @(Get-C476ProcessSnapshot)
                $rootExitTicks = if ($process.HasExited) { $process.ExitTime.ToUniversalTime().Ticks }
                    else { [DateTimeOffset]::UtcNow.UtcTicks }
                Update-C476Descendants $known $lastSnapshot $process.Id $rootExitTicks
                Assert-C476NoLiveDescendants $known $lastSnapshot $process.Id $Description
            }
            if ($rootSurvived) {
                throw "C476_STDERR_PROCESS_ORPHANED: $Description root survived kill pid=$($process.Id)"
            }
        } finally {
            if ($rootSurvived) { $script:c476SurvivorHandles.Add($process) }
            else { $process.Dispose() }
            $out.Dispose(); $err.Dispose()
        }
    }
}

if ($SelfTest) {
    Assert-C476Source
    $managedArguments = @(New-C476BuildArguments $true 'case.slg' 'probe.exe' 'llvm' 'stdlib')
    $selfhostArguments = @(New-C476BuildArguments $false 'case.slg' 'probe.exe' 'llvm' 'stdlib')
    if ($managedArguments -ccontains '--stdlib' -or $managedArguments -ccontains '--jobs' -or
        $selfhostArguments -cnotcontains '--stdlib' -or $selfhostArguments -cnotcontains '--jobs' -or
        (@(Get-C476ExpectedArtifacts $true $false) -cnotcontains 'probe.ll') -or
        (@(Get-C476ExpectedArtifacts $false $false) -cnotcontains 'probe.exe.ll')) {
        throw 'C476_STDERR_SELFTEST_COMPILER_ARGUMENT_OR_PRODUCT_CONTRACT'
    }
    $fixture = [IO.File]::ReadAllText($sourcePath)
    if ($fixture -cnotmatch '(?s)"old"\s*->\s*runtime\.eprintln\s+"line1\\r\\n"\s*->\s*runtime\.eprint\s+"tail"\s*->\s*runtime\.eprint') {
        throw 'C476_STDERR_FIXTURE_CONTRACT_MISMATCH'
    }
    $derivedStderr = [Text.Encoding]::ASCII.GetBytes("old`r`nline1`r`ntail")
    if (-not [Linq.Enumerable]::SequenceEqual($derivedStderr, $expectedStderr)) {
        throw 'C476_STDERR_FIXTURE_EXPECTATION_MISMATCH'
    }
    if ($expectedStderr.Length -ne 16 -or $expectedStderr[-1] -eq 10 -or
        $expectedStderrHex -cne [Convert]::ToHexString($expectedStderr)) {
        throw 'C476_STDERR_EXPECTATION_INVALID'
    }
    Assert-C476ExactStderr $expectedStderr
    $mismatchRejected = $false
    try { Assert-C476ExactStderr ([byte[]]($expectedStderr + 10)) }
    catch { $mismatchRejected = $_.Exception.Message -eq 'C476_STDERR_BYTES_MISMATCH' }
    if (-not $mismatchRejected) { throw 'C476_STDERR_SELFTEST_ACCEPTED_EXTRA_NEWLINE' }
    $case = [ordered]@{
        compiler = 'managed'; state = 'passed'; caseDirectory = 'case'
        buildExitCode = 0; closureExitCode = 0; llvmAsExitCode = 0; runExitCode = 0
        exeSha256 = ('A' * 64); llvmSha256 = ('B' * 64)
        bitcodeSha256 = ('C' * 64); stderrSha256 = $expectedStderrSha256; failure = $null
    }
    $record = [ordered]@{
        schemaVersion = 1; gate = 'c476-stderr-exact'; state = 'passed'
        total = 2; completed = 2; passed = 2; sourceSha256 = $sourceSha256
        expectedStderrSha256 = $expectedStderrSha256
        managedCompilerSha256 = ('D' * 64); managedDllSha256 = ('E' * 64)
        selfhostCompilerSha256 = ('F' * 64); inputFingerprintStart = ('1' * 64)
        inputFingerprintEnd = ('1' * 64); inputsStable = $true
        processObservationScope = $processObservationScope; orphanProcessIds = @()
        cases = @($case, $case); failureId = $null; failure = $null
    }
    $duplicateRejected = $false
    try { $null = Assert-C476ResultSchema $record }
    catch { $duplicateRejected = $true }
    if (-not $duplicateRejected) { throw 'C476_STDERR_SELFTEST_ACCEPTED_DUPLICATE_CASES' }
    $selfhostCase = [ordered]@{}
    foreach ($key in $case.Keys) { $selfhostCase[$key] = $case[$key] }
    $selfhostCase.compiler = 'selfhost'
    $record.cases = @($case, $selfhostCase)
    $null = Assert-C476ResultSchema $record
    $record.cases[1].runExitCode = $null
    $incompleteRejected = $false
    try { $null = Assert-C476ResultSchema $record }
    catch { $incompleteRejected = $true }
    if (-not $incompleteRejected) { throw 'C476_STDERR_SELFTEST_ACCEPTED_INCOMPLETE_PASS' }
    $record.cases[1].runExitCode = 0
    $record.orphanProcessIds = @(1234)
    $orphanRejected = $false
    try { $null = Assert-C476ResultSchema $record }
    catch { $orphanRejected = $true }
    if (-not $orphanRejected) { throw 'C476_STDERR_SELFTEST_ACCEPTED_ORPHAN' }

    $known = [Collections.Generic.Dictionary[int, long]]::new()
    $known.Add(100, 1000L)
    $sample = @(
        [pscustomobject]@{ id = 100; parentId = 1; startedTicks = 1000L },
        [pscustomobject]@{ id = 101; parentId = 100; startedTicks = 1100L },
        [pscustomobject]@{ id = 102; parentId = 101; startedTicks = 1200L },
        [pscustomobject]@{ id = 103; parentId = 100; startedTicks = 900L },
        [pscustomobject]@{ id = 104; parentId = 100; startedTicks = 1400L }
    )
    Update-C476Descendants $known $sample 100 1300L
    if (-not $known.ContainsKey(101) -or -not $known.ContainsKey(102) -or
        $known.ContainsKey(103) -or $known.ContainsKey(104)) {
        throw 'C476_STDERR_SELFTEST_DESCENDANT_IDENTITY'
    }
    $reparented = @([pscustomobject]@{ id = 101; parentId = 999; startedTicks = 1100L })
    $orphanDetected = $false
    try { Assert-C476NoLiveDescendants $known $reparented 100 'self-test' }
    catch { $orphanDetected = $_.Exception.Message -like 'C476_STDERR_PROCESS_ORPHANED:*' }
    if (-not $orphanDetected -or -not $script:c476OrphanProcessIds.Contains(101)) {
        throw 'C476_STDERR_SELFTEST_REPARENTED_ORPHAN'
    }
    $script:c476OrphanProcessIds.Clear()
    $reused = @([pscustomobject]@{ id = 101; parentId = 999; startedTicks = 2000L })
    Assert-C476NoLiveDescendants $known $reused 100 'self-test'
    Write-Host '[C476 stderr exact self-test] PASS byte pin, compiler arguments/products, no-final-newline, schema, descendant identity/reparent/PID reuse; no compiler executed.'
    return
}

function Assert-C476Empty([string]$Path) {
    if ((Get-Item -LiteralPath $Path).Length -ne 0) {
        throw "C476_STDERR_UNEXPECTED_OUTPUT: $Path"
    }
}

function Assert-C476Products([string]$Directory, [string[]]$Expected) {
    $actual = @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name | Sort-Object -CaseSensitive)
    $names = @($Expected | Sort-Object -CaseSensitive)
    if (($actual -join '|') -cne ($names -join '|')) {
        throw "C476_STDERR_PRODUCTS_MISMATCH: $Directory actual=$($actual -join ',')"
    }
}

$managed = Resolve-C476Path $ManagedCompiler
$managedDll = Join-Path (Split-Path -Parent $managed) 'Sollang.Compiler.dll'
$selfhost = Resolve-C476Path $SelfhostCompiler
$stdlib = Resolve-C476Path $StdlibRoot
$llvm = Resolve-C476Path $LlvmRoot
$output = Resolve-C476Path $OutputDirectory
$scratch = Resolve-C476Path 'artifacts/scratch'
$llvmAs = Join-Path $llvm 'bin/llvm-as.exe'
$clang = Join-Path $llvm 'bin/clang.exe'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath $nativeContractPath -PathType Leaf)) {
    throw 'C476_STDERR_NATIVE_TOOL_CONTRACT_MISSING'
}
$nativeToolNames = @(([IO.File]::ReadAllText($nativeContractPath) | ConvertFrom-Json).platformEnvironment.windows.contentHashedTools)
if (@($nativeToolNames | Sort-Object -Unique).Count -ne $nativeToolNames.Count -or
    @('clang.exe', 'llvm-as.exe', 'llvm-lib.exe', 'llvm-split.exe', 'lld-link.exe' |
        Where-Object { $nativeToolNames -cnotcontains $_ }).Count -ne 0) {
    throw 'C476_STDERR_NATIVE_TOOL_CONTRACT_INVALID'
}
$nativeTools = @($nativeToolNames | ForEach-Object { Join-Path $llvm "bin/$_" })
if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) { throw 'C476_STDERR_OUTPUT_SCOPE' }
if (Test-Path -LiteralPath $output) { throw 'C476_STDERR_OUTPUT_EXISTS' }
foreach ($path in @($managed, $managedDll, $selfhost, $stdlib, $llvmAs, $clang,
        $closurePath, $schemaPath, $sourcePath, $output) + $nativeTools) {
    Assert-C476NoReparse $path
}
foreach ($path in @($managed, $managedDll, $selfhost, $llvmAs, $clang,
        $closurePath, $schemaPath, $sourcePath) + $nativeTools) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "C476_STDERR_INPUT_MISSING: $path"
    }
}
if (-not (Test-Path -LiteralPath $stdlib -PathType Container)) {
    throw 'C476_STDERR_STDLIB_MISSING'
}
foreach ($pair in @(@($managed, $ManagedCompilerSha256), @($managedDll, $ManagedDllSha256),
        @($selfhost, $SelfhostCompilerSha256))) {
    if ($pair[1] -cnotmatch '^[0-9A-Fa-f]{64}$' -or
        (Get-C476Sha $pair[0]) -cne $pair[1].ToUpperInvariant()) {
        throw "C476_STDERR_COMPILER_SHA_MISMATCH: $($pair[0])"
    }
}
Assert-C476Source
$consolePath = Join-Path $stdlib 'sys/runtime/console.slg'
if (-not (Test-Path -LiteralPath $consolePath -PathType Leaf) -or
    [IO.File]::ReadAllText($consolePath) -notmatch 'public\s+eprint\s+value:\s*Text\s*->\s*Unit\s*=\s*intrinsic') {
    throw 'C476_STDERR_INTRINSIC_MISSING'
}
if ([IO.File]::ReadAllText($consolePath) -notmatch 'public\s+eprintln\s+value:\s*Text\s*->\s*Unit\s*=\s*intrinsic') {
    throw 'C476_STDERR_LEGACY_INTRINSIC_MISSING'
}

function Get-C476Fingerprint {
    $stdlibSources = [string[]][IO.Directory]::GetFiles($stdlib, '*.slg', [IO.SearchOption]::AllDirectories)
    [Array]::Sort($stdlibSources, [StringComparer]::Ordinal)
    $managedFiles = [string[]][IO.Directory]::GetFiles((Split-Path -Parent $managed), '*', [IO.SearchOption]::TopDirectoryOnly)
    [Array]::Sort($managedFiles, [StringComparer]::Ordinal)
    $inputs = @($PSCommandPath, $schemaPath, $sourcePath, $closurePath,
        $nativeContractPath, (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
        (Join-Path $PSScriptRoot 'stage2-artifact-receipt.ps1'), $selfhost, $pwsh) +
        $managedFiles + $stdlibSources + $nativeTools
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
        -Settings ([ordered]@{ gate = 'c476-stderr-exact-v1'; timeoutMilliseconds = [string]$TimeoutMilliseconds;
            expectedStderrHex = $expectedStderrHex }) -InputPath $inputs
}

function Assert-C476Stable([string]$Start) {
    Assert-C476Source
    if ((Get-C476Sha $managed) -cne $ManagedCompilerSha256.ToUpperInvariant() -or
        (Get-C476Sha $managedDll) -cne $ManagedDllSha256.ToUpperInvariant() -or
        (Get-C476Sha $selfhost) -cne $SelfhostCompilerSha256.ToUpperInvariant() -or
        (Get-C476Fingerprint) -cne $Start) {
        throw 'C476_STDERR_INPUT_DRIFT'
    }
}

$fingerprintStart = Get-C476Fingerprint
Assert-C476Stable $fingerprintStart
if ($ValidateInputsOnly) {
    [pscustomobject]@{ state = 'preflight-passed'; total = 2; sourceSha256 = $sourceSha256;
        expectedStderrSha256 = $expectedStderrSha256; inputFingerprint = $fingerprintStart } | ConvertTo-Json
    return
}

New-C476ExclusiveDirectory $output
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1; gate = 'c476-stderr-exact'; state = 'running'
    total = 2; completed = 0; passed = 0; sourceSha256 = $sourceSha256
    expectedStderrSha256 = $expectedStderrSha256
    managedCompilerSha256 = $ManagedCompilerSha256.ToUpperInvariant()
    managedDllSha256 = $ManagedDllSha256.ToUpperInvariant()
    selfhostCompilerSha256 = $SelfhostCompilerSha256.ToUpperInvariant()
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null
    inputsStable = $false; processObservationScope = $processObservationScope
    orphanProcessIds = @(); cases = @(); failureId = $null; failure = $null
}
Write-C476Result $resultPath $record
$active = $null
try {
    foreach ($compiler in @([pscustomobject]@{ id = 'managed'; path = $managed },
            [pscustomobject]@{ id = 'selfhost'; path = $selfhost })) {
        Assert-C476Stable $fingerprintStart
        $caseDirectory = Join-Path $output $compiler.id
        New-C476ExclusiveDirectory $caseDirectory
        $artifacts = Join-Path $caseDirectory 'artifacts'
        New-C476ExclusiveDirectory $artifacts
        $exe = Join-Path $artifacts 'probe.exe'
        $ll = if ($compiler.id -eq 'managed') { Join-Path $artifacts 'probe.ll' } else { "$exe.ll" }
        $bc = "$exe.bc"
        $active = [ordered]@{
            compiler = $compiler.id; state = 'running'; caseDirectory = $caseDirectory
            buildExitCode = $null; closureExitCode = $null; llvmAsExitCode = $null
            runExitCode = $null; exeSha256 = $null; llvmSha256 = $null
            bitcodeSha256 = $null; stderrSha256 = $null; failure = $null
        }
        $record.cases += $active
        Write-C476Result $resultPath $record
        $buildOut = Join-Path $caseDirectory 'build.stdout.txt'
        $buildErr = Join-Path $caseDirectory 'build.stderr.txt'
        $buildArguments = New-C476BuildArguments ($compiler.id -eq 'managed') `
            $sourcePath $exe $llvm $stdlib
        $active.buildExitCode = Invoke-C476LoggedProcess $compiler.path $buildArguments `
            $caseDirectory $buildOut $buildErr "$($compiler.id) build"
        if ($active.buildExitCode -ne 0) { throw "C476_STDERR_BUILD_EXIT: $($compiler.id)" }
        Assert-C476Empty $buildErr
        if ([IO.File]::ReadAllText($buildOut) -match '(?m)^(?:warning\s|note\s)') {
            throw "C476_STDERR_BUILD_WARNING: $($compiler.id)"
        }
        Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($compiler.id -eq 'managed') $false)
        foreach ($product in @($exe, $ll)) {
            if ((Get-Item -LiteralPath $product).Length -eq 0) {
                throw "C476_STDERR_EMPTY_PRODUCT: $product"
            }
        }
        $llvmText = [IO.File]::ReadAllText($ll)
        if ($compiler.id -eq 'managed' -and $llvmText -notmatch 'call\s+i32\s+@sollang_write_stderr\(') {
            throw 'C476_STDERR_MANAGED_CALL_MISSING'
        }
        if ($compiler.id -eq 'selfhost' -and
            $llvmText -notmatch 'call\s+void\s+@sollang_runtime_eprint\([^\r\n]*i1\s+false\)') {
            throw 'C476_STDERR_SELFHOST_RAW_CALL_MISSING'
        }
        $closureOut = Join-Path $caseDirectory 'closure.stdout.txt'
        $closureErr = Join-Path $caseDirectory 'closure.stderr.txt'
        $active.closureExitCode = Invoke-C476LoggedProcess $pwsh @('-NoProfile', '-File',
            $closurePath, '-LlvmPath', $ll) $caseDirectory $closureOut $closureErr 'LLVM direct-call closure'
        if ($active.closureExitCode -ne 0) { throw "C476_STDERR_CLOSURE_EXIT: $($compiler.id)" }
        Assert-C476Empty $closureErr
        $asOut = Join-Path $caseDirectory 'llvm-as.stdout.txt'
        $asErr = Join-Path $caseDirectory 'llvm-as.stderr.txt'
        $active.llvmAsExitCode = Invoke-C476LoggedProcess $llvmAs @($ll, '-o', $bc) `
            $caseDirectory $asOut $asErr 'llvm-as'
        if ($active.llvmAsExitCode -ne 0) { throw "C476_STDERR_LLVM_AS_EXIT: $($compiler.id)" }
        Assert-C476Empty $asOut
        Assert-C476Empty $asErr
        Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($compiler.id -eq 'managed') $true)
        if ((Get-Item -LiteralPath $bc).Length -eq 0) { throw "C476_STDERR_EMPTY_PRODUCT: $bc" }
        $active.exeSha256 = Get-C476Sha $exe
        $active.llvmSha256 = Get-C476Sha $ll
        $active.bitcodeSha256 = Get-C476Sha $bc
        $runOut = Join-Path $caseDirectory 'run.stdout.txt'
        $runErr = Join-Path $caseDirectory 'run.stderr.txt'
        $active.runExitCode = Invoke-C476LoggedProcess $exe @() $caseDirectory $runOut $runErr 'native probe'
        if ($active.runExitCode -ne 0) { throw "C476_STDERR_RUN_EXIT: $($compiler.id)" }
        Assert-C476Empty $runOut
        Assert-C476ExactStderr ([IO.File]::ReadAllBytes($runErr))
        $active.stderrSha256 = Get-C476Sha $runErr
        if ($active.stderrSha256 -cne $expectedStderrSha256) {
            throw "C476_STDERR_SHA_MISMATCH: $($compiler.id)"
        }
        if ((Get-C476Sha $exe) -cne $active.exeSha256 -or
            (Get-C476Sha $ll) -cne $active.llvmSha256 -or
            (Get-C476Sha $bc) -cne $active.bitcodeSha256) {
            throw "C476_STDERR_PRODUCT_DRIFT: $($compiler.id)"
        }
        Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($compiler.id -eq 'managed') $true)
        Assert-C476Products $caseDirectory @('artifacts', 'build.stdout.txt', 'build.stderr.txt',
            'closure.stdout.txt', 'closure.stderr.txt', 'llvm-as.stdout.txt', 'llvm-as.stderr.txt',
            'run.stdout.txt', 'run.stderr.txt')
        Assert-C476Stable $fingerprintStart
        $active.state = 'passed'
        $record.completed++; $record.passed++
        Write-C476Result $resultPath $record
        $active = $null
    }
    Assert-C476Products $output @('managed', 'selfhost', 'result.json')
    $record.inputFingerprintEnd = Get-C476Fingerprint
    Assert-C476Stable $fingerprintStart
    $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    if (-not $record.inputsStable) { throw 'C476_STDERR_INPUT_DRIFT' }
    $record.state = 'passed'
    Write-C476Result $resultPath $record
} catch {
    $failure = $_.Exception.Message
    if ($null -ne $active) {
        $active.state = 'failed'; $active.failure = $failure; $record.completed++
    }
    try {
        $record.inputFingerprintEnd = Get-C476Fingerprint
        $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    } catch { $failure += "; fingerprint error: $($_.Exception.Message)" }
    $record.state = 'failed'
    $record.orphanProcessIds = @($script:c476OrphanProcessIds | Sort-Object)
    $record.failureId = if ($record.orphanProcessIds.Count -gt 0) { 'C476_STDERR_PROCESS_ORPHANED' }
        elseif (-not $record.inputsStable) { 'C476_STDERR_INPUT_DRIFT' }
        elseif ($failure -match '^(C476_STDERR_[A-Z_]+):?') { $Matches[1] }
        else { 'C476_STDERR_VERIFIER_FAILED' }
    $record.failure = $failure
    Write-C476Result $resultPath $record
    throw
}
