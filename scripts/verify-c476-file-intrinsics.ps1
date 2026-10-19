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

$schemaPath = Join-Path $PSScriptRoot 'contracts/c476-file-intrinsics-result.schema.json'
$closurePath = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$nativeExactContractPath = Join-Path $PSScriptRoot 'contracts/native-exact-fixture-receipt.json'
$fixedCases = @(
    [pscustomobject]@{
        id = 'exclusive-remove'
        source = 'scripts/probes/file/c476-exclusive-remove-managed.slg'
        sha = '42DCBA57B33AA65CD722812F01EFB14D9A187E0B621540EC5609794FCB6EA115'
        stdout = "1/0/1/0/-1`n"
    },
    [pscustomobject]@{
        id = 'nul-path'
        source = 'scripts/probes/file/c476-nul-path-managed.slg'
        sha = '6EE2B08F99AF0E358F832F6EF5489D956FC1642EE720A4BD9DA03B2C2FD212A6'
        stdout = "-1/1/-1/0/1`n"
    }
)

function Get-C476Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-C476BytesSha([byte[]]$Bytes) {
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
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

function Get-C476NativeToolPaths([string]$LlvmDirectory) {
    if (-not (Test-Path -LiteralPath $nativeExactContractPath -PathType Leaf)) {
        throw 'C476_NATIVE_TOOL_CONTRACT_MISSING'
    }
    $contract = [IO.File]::ReadAllText($nativeExactContractPath) | ConvertFrom-Json
    $names = @($contract.platformEnvironment.windows.contentHashedTools)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($name in $names) {
        if ($name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.exe$' -or -not $seen.Add($name)) {
            throw 'C476_NATIVE_TOOL_CONTRACT_INVALID'
        }
        $path = Join-Path $LlvmDirectory "bin/$name"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "C476_NATIVE_TOOL_MISSING: $path"
        }
        $paths.Add($path)
    }
    foreach ($required in @('clang.exe', 'llvm-as.exe', 'llvm-lib.exe', 'llvm-split.exe', 'lld-link.exe')) {
        if (-not $seen.Contains($required)) { throw "C476_NATIVE_TOOL_CONTRACT_INCOMPLETE: $required" }
    }
    return $paths.ToArray()
}

function Assert-C476PinnedSource([string]$Path, [string]$ExpectedSha) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or
        (Get-C476Sha $Path) -cne $ExpectedSha) {
        throw "C476_FIXTURE_SHA_MISMATCH: $Path"
    }
}

function Assert-C476Schema([object]$Record) {
    $json = $Record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
        throw 'C476_RESULT_SCHEMA_INVALID'
    }
    return $json
}

function Write-C476Result([string]$Path, [object]$Record) {
    $json = Assert-C476Schema $Record
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

# CIM samples are identity observations, not authority to terminate a PID.
# A descendant created and reparented between samples cannot be attributed.
$script:c476OrphanProcessIds = [Collections.Generic.HashSet[int]]::new()
$script:c476RootSurvivorProcessIds = [Collections.Generic.HashSet[int]]::new()
$script:c476SurvivorHandles = [Collections.Generic.List[Diagnostics.Process]]::new()
$script:c476ProcessAuditFailed = $false
$script:c476ObservedRootId = 0

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
        $script:c476ProcessAuditFailed = $true
        throw "C476_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)"
    }
}

function Update-C476Descendants([Collections.Generic.Dictionary[int, long]]$Known,
        [object[]]$Snapshot, [long]$RootExitTicks) {
    $current = @{}
    foreach ($entry in $Snapshot) { $current[$entry.id] = $entry }
    $added = $true
    while ($added) {
        $added = $false
        foreach ($entry in $Snapshot) {
            if ($Known.ContainsKey($entry.id) -or -not $Known.ContainsKey($entry.parentId)) { continue }
            if ($entry.startedTicks -lt $Known[$entry.parentId]) { continue }
            if ($entry.parentId -eq $script:c476ObservedRootId) {
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

function Get-C476LiveDescendantIds([Collections.Generic.Dictionary[int, long]]$Known,
        [object[]]$Snapshot, [int]$RootId) {
    return @($Snapshot | Where-Object {
        $_.id -ne $RootId -and $Known.ContainsKey($_.id) -and
        $Known[$_.id] -eq $_.startedTicks
    } | ForEach-Object id | Sort-Object -Unique)
}

function Assert-C476NoLiveDescendants([Collections.Generic.Dictionary[int, long]]$Known,
        [object[]]$Snapshot, [int]$RootId, [string]$Description) {
    $live = @(Get-C476LiveDescendantIds $Known $Snapshot $RootId)
    if ($live.Count -eq 0) { return }
    foreach ($id in $live) { [void]$script:c476OrphanProcessIds.Add([int]$id) }
    throw "C476_PROCESS_ORPHANED: $Description left verified live descendants $($live -join ','); none terminated by PID"
}

if ($SelfTest) {
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) { throw 'C476_SCHEMA_MISSING' }
    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $managedArguments = @(New-C476BuildArguments $true 'case.slg' 'case.exe' 'llvm' 'stdlib')
    $selfhostArguments = @(New-C476BuildArguments $false 'case.slg' 'case.exe' 'llvm' 'stdlib')
    if ($managedArguments.Count -ne 10 -or $managedArguments -ccontains '--stdlib' -or
        $managedArguments -ccontains '--jobs' -or $selfhostArguments.Count -ne 14 -or
        $selfhostArguments -cnotcontains '--stdlib' -or $selfhostArguments -cnotcontains '--jobs') {
        throw 'C476_SELFTEST_BUILD_ARGUMENTS_INVALID'
    }
    $managedProducts = @(Get-C476ExpectedArtifacts $true $true)
    $selfhostProducts = @(Get-C476ExpectedArtifacts $false $true)
    if ($managedProducts.Count -ne 5 -or $managedProducts -cnotcontains 'probe.ll' -or
        $managedProducts -cnotcontains 'probe.slg-tmp' -or $selfhostProducts.Count -ne 3 -or
        $selfhostProducts -cnotcontains 'probe.exe.ll' -or $selfhostProducts -ccontains 'probe.ll') {
        throw 'C476_SELFTEST_ARTIFACT_TOPOLOGY_INVALID'
    }
    foreach ($case in $fixedCases) {
        Assert-C476PinnedSource (Join-Path $root $case.source) $case.sha
    }
    $record = [ordered]@{
        schemaVersion = 1; gate = 'c476-file-intrinsics'; state = 'running'
        total = 4; completed = 0; passed = 0
        managedCompilerSha256 = ('A' * 64); managedDllSha256 = ('B' * 64)
        selfhostCompilerSha256 = ('C' * 64); inputFingerprintStart = ('D' * 64)
        inputFingerprintEnd = $null; inputsStable = $false; cases = @()
        failureId = $null; failure = $null
    }
    $null = Assert-C476Schema $record
    $record.state = 'passed'
    $incorrectSuccessRejected = $false
    try { $null = Assert-C476Schema $record }
    catch { $incorrectSuccessRejected = $true }
    if (-not $incorrectSuccessRejected) { throw 'C476_SELFTEST_ACCEPTED_INCOMPLETE_SUCCESS' }
    $passCase = [ordered]@{
        compiler = 'managed'; fixture = 'exclusive-remove'; sourceSha256 = ('A' * 64)
        expectedStdoutSha256 = ('B' * 64); caseDirectory = 'case'; state = 'passed'
        buildExitCode = 0; closureExitCode = 0; llvmAsExitCode = 0; runExitCode = 0
        exeSha256 = ('C' * 64); llvmSha256 = ('D' * 64)
        bitcodeSha256 = ('E' * 64); stdoutSha256 = ('F' * 64); failure = $null
    }
    $record.inputFingerprintEnd = ('D' * 64)
    $record.inputsStable = $true
    $record.completed = 4; $record.passed = 4; $record.cases = @($passCase) * 4
    $duplicateRejected = $false
    try { $null = Assert-C476Schema $record }
    catch { $duplicateRejected = $true }
    if (-not $duplicateRejected) { throw 'C476_SELFTEST_ACCEPTED_DUPLICATE_CASES' }
    $identities = @(
        @('managed', 'exclusive-remove'), @('managed', 'nul-path'),
        @('selfhost', 'exclusive-remove'), @('selfhost', 'nul-path')
    )
    $distinctCases = @()
    foreach ($identity in $identities) {
        $copy = [ordered]@{}
        foreach ($key in $passCase.Keys) { $copy[$key] = $passCase[$key] }
        $copy.compiler = $identity[0]
        $copy.fixture = $identity[1]
        $distinctCases += $copy
    }
    $record.cases = $distinctCases
    $null = Assert-C476Schema $record
    $record.cases[0].buildExitCode = $null
    $incompleteCaseRejected = $false
    try { $null = Assert-C476Schema $record }
    catch { $incompleteCaseRejected = $true }
    if (-not $incompleteCaseRejected) { throw 'C476_SELFTEST_ACCEPTED_INCOMPLETE_CASE' }
    $record.cases[0].buildExitCode = 0
    $script:c476ObservedRootId = 100
    $rootTicks = [DateTime]::UtcNow.Ticks
    $known = [Collections.Generic.Dictionary[int, long]]::new()
    $known.Add(100, $rootTicks)
    $snapshot = @(
        [pscustomobject]@{ id = 101; parentId = 100; startedTicks = $rootTicks + 1 },
        [pscustomobject]@{ id = 102; parentId = 101; startedTicks = $rootTicks + 2 },
        [pscustomobject]@{ id = 103; parentId = 100; startedTicks = $rootTicks - 1 }
    )
    Update-C476Descendants $known $snapshot ($rootTicks + 3)
    $live = @(Get-C476LiveDescendantIds $known $snapshot 100)
    if ($live.Count -ne 2 -or $live[0] -ne 101 -or $live[1] -ne 102) {
        throw 'C476_SELFTEST_DESCENDANT_IDENTITY_FAILED'
    }
    $orphanRejected = $false
    try { Assert-C476NoLiveDescendants $known $snapshot 100 'self-test' }
    catch { $orphanRejected = $_.Exception.Message -match '^C476_PROCESS_ORPHANED:' }
    if (-not $orphanRejected -or $script:c476OrphanProcessIds.Count -ne 2) {
        throw 'C476_SELFTEST_ACCEPTED_ORPHANED_SUCCESS'
    }
    $record.state = 'failed'; $record.failureId = 'C476_PROCESS_ORPHANED'
    $record.failure = 'C476_PROCESS_ORPHANED: self-test'
    $null = Assert-C476Schema $record
    $reused = @([pscustomobject]@{ id = 101; parentId = 100; startedTicks = $rootTicks + 50 })
    if (@(Get-C476LiveDescendantIds $known $reused 100).Count -ne 0) {
        throw 'C476_SELFTEST_PID_REUSE_ATTRIBUTED'
    }
    $liveSnapshot = @(Get-C476ProcessSnapshot)
    if (@($liveSnapshot | Where-Object { $_.id -eq $PID }).Count -ne 1) {
        throw 'C476_SELFTEST_LIVE_PROCESS_INSPECTION_FAILED'
    }
    $temporary = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllBytes($temporary, [IO.File]::ReadAllBytes((Join-Path $root $fixedCases[0].source)))
        Assert-C476PinnedSource $temporary $fixedCases[0].sha
        [IO.File]::AppendAllText($temporary, "`n# mutation")
        $mutationRejected = $false
        try { Assert-C476PinnedSource $temporary $fixedCases[0].sha }
        catch { $mutationRejected = $_.Exception.Message -match 'C476_FIXTURE_SHA_MISMATCH' }
        if (-not $mutationRejected) { throw 'C476_SELFTEST_ACCEPTED_MUTATED_SOURCE' }
    } finally {
        Remove-Item -LiteralPath $temporary -Force
    }
    $nativeToolDirectory = [IO.Directory]::CreateTempSubdirectory('c476-native-tools-')
    try {
        $fakeBin = Join-Path $nativeToolDirectory.FullName 'bin'
        [IO.Directory]::CreateDirectory($fakeBin) | Out-Null
        $toolContract = [IO.File]::ReadAllText($nativeExactContractPath) | ConvertFrom-Json
        foreach ($name in @($toolContract.platformEnvironment.windows.contentHashedTools)) {
            [IO.File]::WriteAllText((Join-Path $fakeBin $name), 'tool-v1')
        }
        $fakeTools = @(Get-C476NativeToolPaths $nativeToolDirectory.FullName)
        $fakeNames = @($fakeTools | ForEach-Object { [IO.Path]::GetFileName($_) })
        foreach ($required in @('clang.exe', 'llvm-as.exe', 'llvm-lib.exe', 'llvm-split.exe', 'lld-link.exe')) {
            if ($fakeNames -cnotcontains $required) { throw "C476_SELFTEST_TOOL_NOT_FINGERPRINTED: $required" }
        }
        $fakeInputs = @($nativeExactContractPath) + $fakeTools
        $beforeToolChange = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
            -Settings ([ordered]@{ gate = 'c476-native-tool-selftest' }) -InputPath $fakeInputs
        $linkerPath = Join-Path $fakeBin 'lld-link.exe'
        [IO.File]::AppendAllText($linkerPath, '-mutated')
        $afterToolChange = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
            -Settings ([ordered]@{ gate = 'c476-native-tool-selftest' }) -InputPath $fakeInputs
        if ($afterToolChange -ceq $beforeToolChange) { throw 'C476_SELFTEST_ACCEPTED_LINKER_DRIFT' }
        [IO.File]::Delete($linkerPath)
        $missingRejected = $false
        try { $null = @(Get-C476NativeToolPaths $nativeToolDirectory.FullName) }
        catch { $missingRejected = $_.Exception.Message -like 'C476_NATIVE_TOOL_MISSING:*' }
        if (-not $missingRejected) { throw 'C476_SELFTEST_ACCEPTED_MISSING_LINKER' }
    } finally {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $nativeToolDirectory.FullName.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'C476_SELFTEST_TEMP_SCOPE_INVALID'
        }
        Remove-Item -LiteralPath $nativeToolDirectory.FullName -Recurse -Force
    }
    Write-Host '[C476 file intrinsics self-test] PASS build arguments, exact 2x2 schema identity, incomplete/duplicate cases, source mutation, descendant/orphan and PID reuse identity; no compiler executed.'
    return
}

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
            throw "C476_REPARSE_PATH: $cursor"
        }
    }
}

function New-C476ExclusiveDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "C476_OUTPUT_PARENT_MISSING: $parent"
    }
    Assert-C476NoReparse $parent
    if (-not ('C476FileGateNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C476FileGateNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C476FileGateNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        throw "C476_OUTPUT_EXISTS_OR_CREATE_FAILED: $Path; win32=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    Assert-C476NoReparse $Path
}

function Invoke-C476Process([string]$File, [string[]]$Arguments, [string]$WorkingDirectory,
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
        if (-not $process.Start()) { throw "C476_PROCESS_START_FAILED: $Description" }
        $started = $true
        $script:c476ObservedRootId = $process.Id
        $known.Add($process.Id, $process.StartTime.ToUniversalTime().Ticks)
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($out)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($err)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(1000)) {
            Update-C476Descendants $known @(Get-C476ProcessSnapshot) ([DateTimeOffset]::UtcNow.UtcTicks)
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                try { $process.Kill($true) } catch { }
                if (-not $process.WaitForExit(5000)) {
                    [void]$script:c476RootSurvivorProcessIds.Add($process.Id)
                    [void]$script:c476OrphanProcessIds.Add($process.Id)
                    throw "C476_PROCESS_ORPHANED: $Description root survived timeout kill pid=$($process.Id)"
                }
                throw "C476_PROCESS_TIMEOUT: $Description"
            }
        }
        $lastSnapshot = @(Get-C476ProcessSnapshot)
        Update-C476Descendants $known $lastSnapshot $process.ExitTime.ToUniversalTime().Ticks
        Assert-C476NoLiveDescendants $known $lastSnapshot $process.Id $Description
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "C476_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult()
        $out.Flush(); $err.Flush()
        return $process.ExitCode
    } finally {
        $rootSurvived = $false
        try {
            if ($started -and -not $process.WaitForExit(0)) {
                try { $process.Kill($true) } catch { }
                if (-not $process.WaitForExit(5000)) {
                    $rootSurvived = $true
                    [void]$script:c476RootSurvivorProcessIds.Add($process.Id)
                    [void]$script:c476OrphanProcessIds.Add($process.Id)
                }
            }
            if ($started) {
                $lastSnapshot = @(Get-C476ProcessSnapshot)
                $rootExitTicks = if ($process.HasExited) { $process.ExitTime.ToUniversalTime().Ticks }
                    else { [DateTimeOffset]::UtcNow.UtcTicks }
                Update-C476Descendants $known $lastSnapshot $rootExitTicks
                Assert-C476NoLiveDescendants $known $lastSnapshot $process.Id $Description
            }
            if ($rootSurvived) {
                throw "C476_PROCESS_ORPHANED: $Description root survived kill pid=$($process.Id)"
            }
        } finally {
            if ($rootSurvived) { $script:c476SurvivorHandles.Add($process) }
            else { $process.Dispose() }
            $out.Dispose(); $err.Dispose()
        }
    }
}

function Assert-C476Empty([string]$Path) {
    if ((Get-Item -LiteralPath $Path).Length -ne 0) { throw "C476_UNEXPECTED_OUTPUT: $Path" }
}

function Assert-C476Products([string]$Directory, [string[]]$Expected) {
    $actual = @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name | Sort-Object -CaseSensitive)
    $names = @($Expected | Sort-Object -CaseSensitive)
    if (($actual -join '|') -cne ($names -join '|')) {
        throw "C476_PRODUCTS_MISMATCH: $Directory actual=$($actual -join ',')"
    }
}

function Assert-C476CaseTopology([string]$CaseDirectory, [string]$Fixture) {
    Assert-C476Products $CaseDirectory @('artifacts', 'work', 'build.stdout.txt',
        'build.stderr.txt', 'closure.stdout.txt', 'closure.stderr.txt',
        'llvm-as.stdout.txt', 'llvm-as.stderr.txt', 'run.stdout.txt', 'run.stderr.txt')
    $work = Join-Path $CaseDirectory 'work'
    if ($Fixture -eq 'nul-path') {
        Assert-C476Products $work @()
        return
    }
    Assert-C476Products $work @('artifacts')
    $inner = Join-Path $work 'artifacts'
    Assert-C476Products $inner @('scratch')
    $inner = Join-Path $inner 'scratch'
    Assert-C476Products $inner @('c476-managed-file-intrinsics-20260924-01')
    $inner = Join-Path $inner 'c476-managed-file-intrinsics-20260924-01'
    Assert-C476Products $inner @()
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
$nativeTools = @(Get-C476NativeToolPaths $llvm)

if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) { throw 'C476_OUTPUT_SCOPE' }
if (Test-Path -LiteralPath $output) { throw "C476_OUTPUT_EXISTS: $output" }
foreach ($path in @($managed, $managedDll, $selfhost, $stdlib, $llvmAs, $clang,
        $closurePath, $schemaPath, $nativeExactContractPath, $output) + $nativeTools) { Assert-C476NoReparse $path }
foreach ($file in @($managed, $managedDll, $selfhost, $closurePath, $schemaPath, $nativeExactContractPath) + $nativeTools) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "C476_INPUT_MISSING: $file" }
}
if (-not (Test-Path -LiteralPath $stdlib -PathType Container)) { throw 'C476_STDLIB_MISSING' }
foreach ($pair in @(@($managed, $ManagedCompilerSha256), @($managedDll, $ManagedDllSha256),
        @($selfhost, $SelfhostCompilerSha256))) {
    if ($pair[1] -cnotmatch '^[0-9A-Fa-f]{64}$' -or
        (Get-C476Sha $pair[0]) -cne $pair[1].ToUpperInvariant()) {
        throw "C476_COMPILER_SHA_MISMATCH: $($pair[0])"
    }
}
$stdlibFile = Join-Path $stdlib 'sys/file.slg'
if (-not (Test-Path -LiteralPath $stdlibFile -PathType Leaf)) { throw 'C476_STDLIB_FILE_MISSING' }
$stdlibText = [IO.File]::ReadAllText($stdlibFile)
if ($stdlibText -notmatch 'public\s+createExclusive\s+path:\s*Text\s*->\s*Int\s+uses\s+File\s*=\s*intrinsic' -or
    $stdlibText -notmatch 'public\s+removePath\s+path:\s*Text\s*->\s*Int\s+uses\s+File\s*=\s*intrinsic') {
    throw 'C476_STDLIB_INTRINSICS_MISSING'
}
$caseSources = @($fixedCases | ForEach-Object {
    $path = Resolve-C476Path $_.source
    Assert-C476PinnedSource $path $_.sha
    $path
})
function Get-C476Fingerprint {
    # Enumerate on every observation; added/removed inputs are drift too.
    $stdlibSources = [string[]][IO.Directory]::GetFiles($stdlib, '*.slg', [IO.SearchOption]::AllDirectories)
    [Array]::Sort($stdlibSources, [StringComparer]::Ordinal)
    $managedFiles = [string[]][IO.Directory]::GetFiles((Split-Path -Parent $managed), '*',
        [IO.SearchOption]::TopDirectoryOnly)
    [Array]::Sort($managedFiles, [StringComparer]::Ordinal)
    $currentNativeTools = @(Get-C476NativeToolPaths $llvm)
    $fingerprintInputs = @($PSCommandPath, $schemaPath, $closurePath, $nativeExactContractPath,
        (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
        (Join-Path $PSScriptRoot 'stage2-artifact-receipt.ps1'),
        $selfhost, $pwsh) + $currentNativeTools + $managedFiles + $caseSources + $stdlibSources
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
        -Settings ([ordered]@{ gate = 'c476-file-intrinsics-v1'; timeoutMilliseconds = [string]$TimeoutMilliseconds }) `
        -InputPath $fingerprintInputs
}
function Assert-C476Stable([string]$Start) {
    foreach ($i in 0..1) { Assert-C476PinnedSource $caseSources[$i] $fixedCases[$i].sha }
    if ((Get-C476Sha $managed) -cne $ManagedCompilerSha256.ToUpperInvariant() -or
        (Get-C476Sha $managedDll) -cne $ManagedDllSha256.ToUpperInvariant() -or
        (Get-C476Sha $selfhost) -cne $SelfhostCompilerSha256.ToUpperInvariant() -or
        (Get-C476Fingerprint) -cne $Start) { throw 'C476_INPUT_DRIFT' }
}
$fingerprintStart = Get-C476Fingerprint
Assert-C476Stable $fingerprintStart
if ($ValidateInputsOnly) {
    [pscustomobject]@{ state = 'preflight-passed'; total = 4; inputFingerprint = $fingerprintStart;
        managedCompilerSha256 = $ManagedCompilerSha256.ToUpperInvariant();
        managedDllSha256 = $ManagedDllSha256.ToUpperInvariant();
        selfhostCompilerSha256 = $SelfhostCompilerSha256.ToUpperInvariant() } | ConvertTo-Json
    return
}

New-C476ExclusiveDirectory $output
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1; gate = 'c476-file-intrinsics'; state = 'running'
    total = 4; completed = 0; passed = 0
    managedCompilerSha256 = $ManagedCompilerSha256.ToUpperInvariant()
    managedDllSha256 = $ManagedDllSha256.ToUpperInvariant()
    selfhostCompilerSha256 = $SelfhostCompilerSha256.ToUpperInvariant()
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null
    inputsStable = $false; cases = @(); failureId = $null; failure = $null
}
Write-C476Result $resultPath $record
$active = $null
try {
    foreach ($compiler in @([pscustomobject]@{ id = 'managed'; path = $managed },
            [pscustomobject]@{ id = 'selfhost'; path = $selfhost })) {
        $compilerDirectory = Join-Path $output $compiler.id
        New-C476ExclusiveDirectory $compilerDirectory
        for ($i = 0; $i -lt $fixedCases.Count; $i++) {
            Assert-C476Stable $fingerprintStart
            $case = $fixedCases[$i]
            $caseDirectory = Join-Path $compilerDirectory $case.id
            New-C476ExclusiveDirectory $caseDirectory
            $artifacts = Join-Path $caseDirectory 'artifacts'
            $work = Join-Path $caseDirectory 'work'
            New-C476ExclusiveDirectory $artifacts
            New-C476ExclusiveDirectory $work
            if ($case.id -eq 'exclusive-remove') {
                $inner = Join-Path $work 'artifacts'
                New-C476ExclusiveDirectory $inner
                $inner = Join-Path $inner 'scratch'
                New-C476ExclusiveDirectory $inner
                $inner = Join-Path $inner 'c476-managed-file-intrinsics-20260924-01'
                New-C476ExclusiveDirectory $inner
            }
            $exe = Join-Path $artifacts 'probe.exe'
            $ll = if ($compiler.id -eq 'managed') { Join-Path $artifacts 'probe.ll' } else { "$exe.ll" }
            $bc = "$exe.bc"
            $expected = [Text.UTF8Encoding]::new($false).GetBytes($case.stdout)
            $active = [ordered]@{
                compiler = $compiler.id; fixture = $case.id; sourceSha256 = $case.sha
                expectedStdoutSha256 = Get-C476BytesSha $expected; caseDirectory = $caseDirectory
                state = 'running'; buildExitCode = $null; closureExitCode = $null
                llvmAsExitCode = $null; runExitCode = $null; exeSha256 = $null
                llvmSha256 = $null; bitcodeSha256 = $null; stdoutSha256 = $null; failure = $null
            }
            $record.cases += $active
            Write-C476Result $resultPath $record
            $buildOut = Join-Path $caseDirectory 'build.stdout.txt'
            $buildErr = Join-Path $caseDirectory 'build.stderr.txt'
            $buildArguments = New-C476BuildArguments ($compiler.id -eq 'managed') `
                $caseSources[$i] $exe $llvm $stdlib
            $active.buildExitCode = Invoke-C476Process $compiler.path $buildArguments `
                $caseDirectory $buildOut $buildErr "$($compiler.id) $($case.id) build"
            if ($active.buildExitCode -ne 0) { throw "C476_BUILD_EXIT: $($compiler.id)/$($case.id)" }
            Assert-C476Empty $buildErr
            if ([IO.File]::ReadAllText($buildOut) -match '(?m)^(?:warning\s|note\s)') {
                throw "C476_BUILD_WARNING: $($compiler.id)/$($case.id)"
            }
            Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($compiler.id -eq 'managed') $false)
            foreach ($product in @($exe, $ll)) {
                if ((Get-Item -LiteralPath $product).Length -eq 0) { throw "C476_EMPTY_PRODUCT: $product" }
            }
            $llvmText = [IO.File]::ReadAllText($ll)
            foreach ($symbol in @('sollang_platform_create_exclusive_file', 'sollang_platform_remove_file')) {
                if ($llvmText -notmatch "(?m)^define\s+[^\r\n]*@$symbol\(") {
                    throw "C476_LLVM_MISSING_SYMBOL: $symbol"
                }
            }
            if ($llvmText -notmatch '(?m)call\s+i(?:32|64)\s+@sollang_platform_create_exclusive_file\(' -or
                $llvmText -notmatch '(?m)call\s+i(?:32|64)\s+@sollang_platform_remove_file\(') {
                throw "C476_LLVM_CALL_ABI_MISSING: $($compiler.id)/$($case.id)"
            }
            if ($compiler.id -eq 'managed' -and
                $llvmText -notmatch '(?m)^define\s+[^\r\n]*@sollang_file_path_has_no_nul\(') {
                throw "C476_LLVM_MANAGED_GUARD_ABI_MISSING: $($case.id)"
            }
            $closureOut = Join-Path $caseDirectory 'closure.stdout.txt'
            $closureErr = Join-Path $caseDirectory 'closure.stderr.txt'
            $active.closureExitCode = Invoke-C476Process $pwsh @('-NoProfile', '-File', $closurePath,
                '-LlvmPath', $ll) $caseDirectory $closureOut $closureErr 'LLVM direct-call closure'
            if ($active.closureExitCode -ne 0) { throw "C476_CLOSURE_EXIT: $($compiler.id)/$($case.id)" }
            Assert-C476Empty $closureErr
            $asOut = Join-Path $caseDirectory 'llvm-as.stdout.txt'
            $asErr = Join-Path $caseDirectory 'llvm-as.stderr.txt'
            $active.llvmAsExitCode = Invoke-C476Process $llvmAs @($ll, '-o', $bc) `
                $caseDirectory $asOut $asErr 'llvm-as'
            if ($active.llvmAsExitCode -ne 0) { throw "C476_LLVM_AS_EXIT: $($compiler.id)/$($case.id)" }
            Assert-C476Empty $asOut
            Assert-C476Empty $asErr
            Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($compiler.id -eq 'managed') $true)
            if ((Get-Item -LiteralPath $bc).Length -eq 0) { throw "C476_EMPTY_PRODUCT: $bc" }
            $exeBefore = Get-C476Sha $exe
            $llvmBefore = Get-C476Sha $ll
            $bitcodeBefore = Get-C476Sha $bc
            $runOut = Join-Path $caseDirectory 'run.stdout.txt'
            $runErr = Join-Path $caseDirectory 'run.stderr.txt'
            $active.runExitCode = Invoke-C476Process $exe @() $work $runOut $runErr `
                "$($compiler.id) $($case.id) native"
            if ($active.runExitCode -ne 0) { throw "C476_RUN_EXIT: $($compiler.id)/$($case.id)" }
            Assert-C476Empty $runErr
            if (-not [Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($runOut), $expected)) {
                throw "C476_STDOUT_MISMATCH: $($compiler.id)/$($case.id)"
            }
            if (Test-Path -LiteralPath (Join-Path $work 'x')) { throw 'C476_NUL_PREFIX_MODIFIED' }
            if (Test-Path -LiteralPath (Join-Path $work 'artifacts/scratch/c476-managed-file-intrinsics-20260924-01/created.txt')) {
                throw 'C476_CREATED_FILE_RETAINED'
            }
            if ([IO.Directory]::GetFiles($work, '*', [IO.SearchOption]::AllDirectories).Length -ne 0) {
                throw "C476_WORK_PRODUCT_RETAINED: $($compiler.id)/$($case.id)"
            }
            Assert-C476CaseTopology $caseDirectory $case.id
            Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($compiler.id -eq 'managed') $true)
            if ((Get-C476Sha $exe) -cne $exeBefore -or
                (Get-C476Sha $ll) -cne $llvmBefore -or
                (Get-C476Sha $bc) -cne $bitcodeBefore) {
                throw "C476_PRODUCT_CHANGED_AFTER_RUN: $($compiler.id)/$($case.id)"
            }
            Assert-C476Stable $fingerprintStart
            $active.exeSha256 = $exeBefore
            $active.llvmSha256 = $llvmBefore
            $active.bitcodeSha256 = $bitcodeBefore
            $active.stdoutSha256 = Get-C476Sha $runOut
            $active.state = 'passed'
            $record.completed++; $record.passed++
            Write-C476Result $resultPath $record
            Write-Host "[C476 file intrinsics] $($record.completed)/4 $($compiler.id)/$($case.id) passed"
            $active = $null
        }
        Assert-C476Products $compilerDirectory @('exclusive-remove', 'nul-path')
    }
    foreach ($caseRecord in $record.cases) {
        Assert-C476CaseTopology $caseRecord.caseDirectory $caseRecord.fixture
        $artifacts = Join-Path $caseRecord.caseDirectory 'artifacts'
        Assert-C476Products $artifacts @(Get-C476ExpectedArtifacts ($caseRecord.compiler -eq 'managed') $true)
        $caseLl = if ($caseRecord.compiler -eq 'managed') { Join-Path $artifacts 'probe.ll' }
            else { Join-Path $artifacts 'probe.exe.ll' }
        if ((Get-C476Sha (Join-Path $artifacts 'probe.exe')) -cne $caseRecord.exeSha256 -or
            (Get-C476Sha $caseLl) -cne $caseRecord.llvmSha256 -or
            (Get-C476Sha (Join-Path $artifacts 'probe.exe.bc')) -cne $caseRecord.bitcodeSha256) {
            throw "C476_PRODUCT_DRIFT: $($caseRecord.compiler)/$($caseRecord.fixture)"
        }
    }
    Assert-C476Products $output @('managed', 'selfhost', 'result.json')
    $record.inputFingerprintEnd = Get-C476Fingerprint
    Assert-C476Stable $fingerprintStart
    $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    if (-not $record.inputsStable) { throw 'C476_INPUT_DRIFT' }
    if ($script:c476ProcessAuditFailed) { throw 'C476_PROCESS_INSPECTION_FAILED' }
    if ($script:c476OrphanProcessIds.Count -gt 0 -or
        $script:c476RootSurvivorProcessIds.Count -gt 0) { throw 'C476_PROCESS_ORPHANED' }
    $record.state = 'passed'
    Write-C476Result $resultPath $record
} catch {
    $failure = $_.Exception.Message
    if ($null -ne $active) { $active.state = 'failed'; $active.failure = $failure; $record.completed++ }
    try {
        $record.inputFingerprintEnd = Get-C476Fingerprint
        $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    } catch { $failure += "; fingerprint error: $($_.Exception.Message)" }
    $record.state = 'failed'
    $record.failureId = if ($script:c476OrphanProcessIds.Count -gt 0) { 'C476_PROCESS_ORPHANED' }
        elseif ($script:c476ProcessAuditFailed) { 'C476_PROCESS_INSPECTION_FAILED' }
        elseif (-not $record.inputsStable) { 'C476_INPUT_DRIFT' }
        elseif ($failure -match '^(C476_[A-Z_]+):?') { $Matches[1] }
        else { 'C476_VERIFIER_FAILED' }
    $record.failure = $failure
    if ($script:c476OrphanProcessIds.Count -gt 0) {
        $orphanPath = Join-Path $output 'orphan-processes.json'
        $temporary = "$orphanPath.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
        try {
            $orphanRecord = [ordered]@{
                schemaVersion = 1; gate = 'c476-file-intrinsics'; state = 'failed'
                observedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
                verifiedLiveDescendantProcessIds = @($script:c476OrphanProcessIds |
                    Where-Object { -not $script:c476RootSurvivorProcessIds.Contains([int]$_) } |
                    Sort-Object)
                verifiedLiveRootProcessIds = @($script:c476RootSurvivorProcessIds | Sort-Object)
                limit = 'CIM sampling cannot identify a descendant created and reparented between samples.'
            }
            [IO.File]::WriteAllText($temporary, ($orphanRecord | ConvertTo-Json -Depth 4),
                [Text.UTF8Encoding]::new($false))
            [IO.File]::Move($temporary, $orphanPath, $false)
        } finally {
            if (Test-Path -LiteralPath $temporary -PathType Leaf) {
                Remove-Item -LiteralPath $temporary -Force
            }
        }
    }
    Write-C476Result $resultPath $record
    throw
}
