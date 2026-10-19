[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$schemaPath = Join-Path $PSScriptRoot 'contracts/c477-canonical-rebind-result.schema.json'
$negativeRunner = Join-Path $PSScriptRoot 'verify-compiler-parity-negative-fixture.ps1'
$negativeSchema = Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'
$closureScript = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$verificationProcessScript = Join-Path $PSScriptRoot 'verification-process.ps1'
$nativeExactScript = Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'
$fixturePins = [ordered]@{
    bareMissingBang = @('scripts/probes/typed/c476-mutable-read-missing-bang.slg', '7DF54907E9FDB98292A7659BA8FE5FAE5D65F63B221A8586F229D5FBF6943351', 'scripts/probes/typed/c476-mutable-read-missing-bang.stderr.contains.txt', '5CCECD405C6D137A3E4AE86822FF8C28EEB038061385EE45E1BF34E16C8C0C0E')
    ownInitializer = @('scripts/probes/typed/c477-own-initializer-unresolved-name.slg', 'B1D13968288245174731E57BEADEF20ADA8F1603BAD0EF94980E2115A086A04C', 'scripts/probes/typed/c477-own-initializer-unresolved-name.stderr.contains.txt', '5CCECD405C6D137A3E4AE86822FF8C28EEB038061385EE45E1BF34E16C8C0C0E')
    rebind = @('scripts/probes/typed/c477-canonical-mutable-rebind-struct.slg', '6F4EF172805F3B2FAD729EE8368DE277F71A650CD23E61300B1AE3CFB6F1C790', 'scripts/probes/typed/c477-canonical-mutable-rebind-struct.stdout.txt', '7DE1555DF0C2700329E815B93B32C571C3EA54DC967B89E81AB73B9972B72D1D')
    shadow = @('scripts/probes/typed/c477-canonical-mutable-nested-shadow.slg', 'F32F29DC320CE4D8FFE8F1B46BC5FE23244CD02E2B33464B2D16E851E919952E', 'scripts/probes/typed/c477-canonical-mutable-nested-shadow.stdout.txt', '039B4ED8321933CF48BA0776912D29E646CC7217CBA690379E72BEE9FD7CF935')
}
# Run independent positive evidence first: known negative output-transaction
# failures must not hide the canonical-slot regression measurements.
$stepNames = @('managedRebind', 'selfhostRebind', 'managedShadow', 'selfhostShadow', 'bareMissingBang', 'ownInitializer')

function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-NoReparse([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = [IO.Path]::GetPathRoot($full)
    foreach ($part in ($full.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $part) { continue }
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "C477CR_REPARSE: $cursor" }
    }
}
function Assert-Fixtures {
    foreach ($fixture in $fixturePins.Values) {
        for ($index = 0; $index -lt 4; $index += 2) {
            $path = Resolve-Input $fixture[$index]
            Assert-NoReparse $path
            if ((Get-Sha $path) -cne $fixture[$index + 1]) { throw "C477CR_FIXTURE_PIN: $path" }
            if ((Get-Item -LiteralPath $path).Length -eq 0) { throw "C477CR_FIXTURE_EMPTY: $path" }
        }
    }
}
function New-ExclusiveDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "C477CR_PARENT_MISSING: $parent" }
    Assert-NoReparse $parent
    if (-not ('C477CanonicalDirectoryNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C477CanonicalDirectoryNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C477CanonicalDirectoryNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        throw "C477CR_OUTPUT_EXISTS_OR_CREATE_FAILED: $Path"
    }
    Assert-NoReparse $Path
}
function Write-AtomicResult([string]$Path, [string]$Json) {
    $temp = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    $backup = "$Path.backup-$PID-$([guid]::NewGuid().ToString('N'))"
    $replaced = $false
    try {
        [IO.File]::WriteAllText($temp, $Json, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temp, $Path, $backup)
            $replaced = $true
        } else { [IO.File]::Move($temp, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temp -PathType Leaf) { Remove-Item -LiteralPath $temp -Force }
        if ($replaced -and (Test-Path -LiteralPath $backup -PathType Leaf)) { Remove-Item -LiteralPath $backup -Force }
    }
}
function Assert-ExactNames([string]$Directory, [string[]]$Expected) {
    $entries = @(Get-ChildItem -LiteralPath $Directory -Force)
    $found = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $entries) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "C477CR_ARTIFACT_REPARSE: $($entry.FullName)" }
        if (-not $found.Add($entry.Name)) { throw "C477CR_ARTIFACT_DUPLICATE: $($entry.FullName)" }
    }
    if ($found.Count -ne $Expected.Count) { throw "C477CR_ARTIFACT_SET: $Directory contains $($found.Count), expected $($Expected.Count)" }
    foreach ($name in $Expected) {
        if (-not $found.Contains($name)) { throw "C477CR_ARTIFACT_SET: $Directory missing $name" }
    }
}
function Assert-PositiveArtifacts([string]$Directory, [bool]$Managed) {
    $names = @('probe.exe', 'probe.bc', 'build.stdout.txt', 'build.stderr.txt', 'closure.stdout.txt', 'closure.stderr.txt', 'llvm-as.stdout.txt', 'llvm-as.stderr.txt', 'run.stdout.txt', 'run.stderr.txt')
    $names += 'probe.exe.ll'
    if ($Managed) { $names += '.sollang-cache' }
    Assert-ExactNames $Directory $names
    foreach ($name in $names) {
        $path = Join-Path $Directory $name
        if ($name -eq '.sollang-cache') {
            if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "C477CR_ARTIFACT_TYPE: $path" }
        } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C477CR_ARTIFACT_TYPE: $path" }
    }
    if (-not $Managed) { return }
    $cache = Join-Path $Directory '.sollang-cache'
    $cacheEntries = @(Get-ChildItem -LiteralPath $cache -Force)
    if ($cacheEntries.Count -ne 4) { throw "C477CR_CACHE_SET: expected four cache files; found $($cacheEntries.Count)" }
    $stem = $null
    $suffixes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $cacheEntries) {
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $entry.Name -cnotmatch '^(probe\.windows-x64\..+\.o1-executable)\.(cgu|product|semantic|sources)$') { throw "C477CR_CACHE_SET: unexpected cache entry $($entry.FullName)" }
        if ($null -eq $stem) { $stem = $Matches[1] }
        elseif ($stem -cne $Matches[1]) { throw 'C477CR_CACHE_SET: cache stems differ' }
        if (-not $suffixes.Add($Matches[2])) { throw "C477CR_CACHE_SET: duplicate cache suffix $($Matches[2])" }
    }
}
function Get-LiveDescendants([int]$RootId, [datetime]$RootStartUtc, [object[]]$Records) {
    $seen = [Collections.Generic.HashSet[int]]::new()
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $Records) {
            $id = [int]$record.ProcessId
            if ([datetime]$record.CreationDate -lt $RootStartUtc.ToLocalTime()) { continue }
            if ($frontier -contains [int]$record.ParentProcessId -and $id -ne $RootId -and $seen.Add($id)) { $next += $id }
        }
        $frontier = $next
    }
    return @($seen | Sort-Object)
}
function Invoke-Logged([string]$File, [string[]]$Arguments, [string]$WorkingDirectory, [string]$Description, [string]$StdoutPath, [string]$StderrPath) {
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
    $stdout = [IO.File]::Create($StdoutPath)
    $stderr = [IO.File]::Create($StderrPath)
    $started = $false
    $rootStartUtc = [datetime]::MinValue
    try {
        if (-not $process.Start()) { throw "C477CR_SPAWN_FAILED: $Description" }
        $started = $true
        $rootStartUtc = $process.StartTime.ToUniversalTime()
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $waitFailure = $null
        try { Wait-VerificationProcess -Process $process -Description $Description -TimeoutMilliseconds $TimeoutMilliseconds }
        catch { $waitFailure = $_ }
        if (-not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) {
                $script:orphanIds.Add($process.Id)
                throw "C477CR_PROCESS_ORPHANED: root $($process.Id)"
            }
        }
        $descendants = @(Get-LiveDescendants $process.Id $rootStartUtc @(Get-CimInstance Win32_Process))
        if ($descendants.Count -gt 0) {
            foreach ($id in $descendants) { if (-not $script:orphanIds.Contains($id)) { $script:orphanIds.Add($id) } }
            throw "C477CR_PROCESS_ORPHANED: descendants $($descendants -join ',')"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "C477CR_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult()
        $stdout.Flush()
        $stderr.Flush()
        if ($null -ne $waitFailure) { throw $waitFailure }
        return $process.ExitCode
    } finally {
        if ($started -and -not $process.HasExited) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) { $script:orphanIds.Add($process.Id) }
        }
        $stdout.Dispose()
        $stderr.Dispose()
        $process.Dispose()
    }
}
function New-Step([string]$FixtureId, [string]$Compiler) {
    return [ordered]@{
        state = 'not-run'; fixtureId = $FixtureId; compiler = $Compiler; caseDirectory = $null
        nestedResultPath = $null; validationCount = $null; semanticCount = $null; irCount = $null
        buildExitCode = $null; closureExitCode = $null; llvmAsExitCode = $null; runExitCode = $null
        failure = $null
    }
}
function New-PositiveBuildArguments([bool]$Managed, [string]$ManagedCompilerPath, [string]$Source, [string]$Product, [string]$LlvmPath, [string]$StdlibPath) {
    [string[]]$arguments = @()
    if ($Managed) { $arguments += $ManagedCompilerPath }
    $arguments += @('build', $Source, '-o', $Product, '--target', 'windows-x64', '--llvm', $LlvmPath)
    if (-not $Managed) { $arguments += @('--stdlib', $StdlibPath, '--jobs', '1') }
    $arguments += @('-O1', '--keep-temps')
    return ,$arguments
}
function Complete-StepRecord([System.Collections.IDictionary]$Record, [string]$Name, [ref]$AlreadyCounted, [scriptblock]$Writer) {
    $Record.steps[$Name].state = 'passed'
    $Record.completed++
    $Record.passed++
    $AlreadyCounted.Value = $true
    & $Writer
}
function Set-FailedStepRecord([System.Collections.IDictionary]$Record, [string]$Name, [bool]$AlreadyCounted, [string]$Message) {
    $step = $Record.steps[$Name]
    $step.state = 'failed'
    $step.failure = $Message
    if ($AlreadyCounted) { $Record.passed-- } else { $Record.completed++ }
}
function Assert-Result([object]$Record) {
    $json = $Record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) { throw 'C477CR_RESULT_SCHEMA: record rejected' }
    return $json
}
function Get-Fingerprint {
    $managedCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $managedPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $selfhostCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $selfhostPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'c477-canonical-rebind-v1'
        managedCommon = $managedCommon
        selfhostCommon = $selfhostCommon
        timeoutMilliseconds = [string]$TimeoutMilliseconds
    }
    $inputs = @($PSCommandPath, $schemaPath, $negativeRunner, $negativeSchema, $closureScript, $verificationProcessScript, $nativeExactScript, $dotnetPath, $pwshPath)
    foreach ($fixture in $fixturePins.Values) { $inputs += @((Resolve-Input $fixture[0]), (Resolve-Input $fixture[2])) }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $inputs
}

Assert-Fixtures
if ($SelfTest) {
    $rootStart = [datetime]::UtcNow
    $oldChild = [pscustomobject]@{ ProcessId = 201; ParentProcessId = 200; CreationDate = $rootStart.AddMinutes(-5).ToLocalTime() }
    if (@(Get-LiveDescendants 200 $rootStart @($oldChild)).Count -ne 0) {
        throw 'C477CR_SELFTEST: process predating recycled root PID was reported as a child'
    }
    $liveChild = [pscustomobject]@{ ProcessId = 202; ParentProcessId = 200; CreationDate = $rootStart.AddSeconds(1).ToLocalTime() }
    if (@(Get-LiveDescendants 200 $rootStart @($liveChild)).Count -ne 1) {
        throw 'C477CR_SELFTEST: live child was missed'
    }
    [string[]]$managedArguments = New-PositiveBuildArguments $true 'managed.dll' 'probe.slg' 'probe.exe' 'llvm' 'stdlib'
    [string[]]$selfhostArguments = New-PositiveBuildArguments $false 'managed.dll' 'probe.slg' 'probe.exe' 'llvm' 'stdlib'
    [string[]]$expectedManagedArguments = @('managed.dll', 'build', 'probe.slg', '-o', 'probe.exe', '--target', 'windows-x64', '--llvm', 'llvm', '-O1', '--keep-temps')
    [string[]]$expectedSelfhostArguments = @('build', 'probe.slg', '-o', 'probe.exe', '--target', 'windows-x64', '--llvm', 'llvm', '--stdlib', 'stdlib', '--jobs', '1', '-O1', '--keep-temps')
    if ($managedArguments.Count -ne $expectedManagedArguments.Count -or $selfhostArguments.Count -ne $expectedSelfhostArguments.Count) { throw 'C477CR_SELFTEST: build argument count differs' }
    for ($index = 0; $index -lt $expectedManagedArguments.Count; $index++) {
        if ($managedArguments[$index] -cne $expectedManagedArguments[$index]) { throw "C477CR_SELFTEST: managed build argument $index differs" }
    }
    for ($index = 0; $index -lt $expectedSelfhostArguments.Count; $index++) {
        if ($selfhostArguments[$index] -cne $expectedSelfhostArguments[$index]) { throw "C477CR_SELFTEST: selfhost build argument $index differs" }
    }
    $steps = [ordered]@{}
    foreach ($name in $stepNames) {
        $kind = if ($name -in @('bareMissingBang', 'ownInitializer')) { 'pair' } elseif ($name -like 'managed*') { 'managed' } else { 'selfhost' }
        $fixtureId = if ($name -like '*Rebind') { 'rebind' } elseif ($name -like '*Shadow') { 'shadow' } else { $name }
        $steps[$name] = New-Step $fixtureId $kind
    }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c477-canonical-rebind'; state = 'running'; total = 6; completed = 0; passed = 0
        managedCompilerPath = 'managed'; managedCompilerSha256 = ('A' * 64)
        selfhostCompilerPath = 'selfhost'; selfhostCompilerSha256 = ('B' * 64)
        inputFingerprintStart = ('C' * 64); inputFingerprintEnd = $null; inputsStable = $false
        processObservationScope = 'bounded-supervised-process-tree-and-post-exit-CIM-parent-snapshot;exited-intermediate-descendants-not-proven'
        negativeProofScope = 'strict-managed-selfhost-cli-negative-pair-plus-pre-LLVM-semantic-only-count;no-product'
        steps = $steps; orphanProcessIds = @(); failureId = $null; failure = $null
    }
    $null = Assert-Result $sample
    foreach ($name in $stepNames) {
        $step = $sample.steps[$name]
        $step.state = 'passed'
        $step.caseDirectory = $name
        if ($step.compiler -ceq 'pair') {
            $step.nestedResultPath = "$name/result.json"
            $step.validationCount = 1
            $step.semanticCount = 1
            $step.irCount = 0
        } else {
            $step.buildExitCode = 0
            $step.closureExitCode = 0
            $step.llvmAsExitCode = 0
            $step.runExitCode = 0
        }
    }
    $sample.state = 'passed'; $sample.completed = 6; $sample.passed = 6
    $sample.inputFingerprintEnd = ('C' * 64); $sample.inputsStable = $true
    $null = Assert-Result $sample
    $sample.steps.selfhostRebind.closureExitCode = $null
    $rejected = $false
    try { $rejected = -not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $schemaPath -ErrorAction Stop) }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'C477CR_SELFTEST: incomplete passing record accepted' }
    $sample.steps.selfhostRebind.closureExitCode = 0
    $sample.steps.selfhostRebind.fixtureId = 'shadow'
    $rejected = $false
    try { $rejected = -not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $schemaPath -ErrorAction Stop) }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'C477CR_SELFTEST: swapped fixture identity accepted' }
    $sample.steps.selfhostRebind.fixtureId = 'rebind'
    $sample.state = 'running'; $sample.completed = 5; $sample.passed = 5
    $sample.inputFingerprintEnd = $null; $sample.inputsStable = $false
    $sample.steps.ownInitializer.state = 'not-run'
    $counted = $false
    $injected = $false
    try {
        Complete-StepRecord $sample 'ownInitializer' ([ref]$counted) { throw 'C477CR_SELFTEST_INJECTED_WRITE_FAILURE' }
    } catch {
        $injected = $_.Exception.Message -ceq 'C477CR_SELFTEST_INJECTED_WRITE_FAILURE'
        Set-FailedStepRecord $sample 'ownInitializer' $counted $_.Exception.Message
    }
    $sample.state = 'failed'; $sample.failureId = 'C477CR_STEP_FAILED'; $sample.failure = 'C477CR_SELFTEST_INJECTED_WRITE_FAILURE'
    if (-not $injected -or $sample.completed -ne 6 -or $sample.passed -ne 5 -or $sample.steps.ownInitializer.state -cne 'failed') { throw 'C477CR_SELFTEST: result-write failure counted twice or lost' }
    $null = Assert-Result $sample
    Write-Host '[c477 canonical rebind] self-test passed; no compiler launched'
    return
}

if (-not $IsWindows) { throw 'C477CR_PLATFORM: windows-x64 only' }
$managedPath = Resolve-Input $ManagedCompiler
$selfhostPath = Resolve-Input $SelfhostCompiler
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$pwshPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$llvmAsPath = Join-Path $llvmPath 'bin/llvm-as.exe'
foreach ($path in @($managedPath, $selfhostPath, $llvmPath, $stdlibPath, $dotnetPath, $pwshPath, $llvmAsPath, $schemaPath, $negativeRunner, $negativeSchema, $closureScript, $verificationProcessScript, $nativeExactScript)) {
    Assert-NoReparse $path
    if (-not (Test-Path -LiteralPath $path)) { throw "C477CR_INPUT_MISSING: $path" }
}
if ($ManagedCompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $managedPath) -cne $ManagedCompilerSha256.ToUpperInvariant()) { throw 'C477CR_MANAGED_SHA: compiler identity differs' }
if ($SelfhostCompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $selfhostPath) -cne $SelfhostCompilerSha256.ToUpperInvariant()) { throw 'C477CR_SELFHOST_SHA: compiler identity differs' }
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "C477CR_OUTPUT_SCOPE: $outputPath" }
Assert-NoReparse $outputPath
if (Test-Path -LiteralPath $outputPath) { throw "C477CR_OUTPUT_EXISTS: $outputPath" }
$fingerprintStart = Get-Fingerprint
foreach ($name in @('bareMissingBang', 'ownInitializer')) {
    $fixture = $fixturePins[$name]
    $preflight = & $negativeRunner -ManagedCompiler $managedPath -SelfhostCompiler $selfhostPath -ManagedCompilerSha256 $ManagedCompilerSha256 -SelfhostCompilerSha256 $SelfhostCompilerSha256 -Source (Resolve-Input $fixture[0]) -Expected (Resolve-Input $fixture[2]) -OutputDirectory (Join-Path $outputPath $name) -RepositoryRoot $root -LlvmRoot $llvmPath -StdlibRoot $stdlibPath -TimeoutMilliseconds $TimeoutMilliseconds -ValidateInputsOnly | ConvertFrom-Json
    if ($preflight.status -cne 'preflight-passed') { throw "C477CR_NEGATIVE_PREFLIGHT: $name" }
}
if ((Get-Fingerprint) -cne $fingerprintStart) { throw 'C477CR_INPUT_DRIFT: preflight' }
if ($ValidateInputsOnly) {
    [pscustomobject]@{
        status = 'preflight-passed'; total = 6; completed = 0; inputFingerprint = $fingerprintStart
        managedCompilerSha256 = Get-Sha $managedPath; selfhostCompilerSha256 = Get-Sha $selfhostPath
    } | ConvertTo-Json -Compress
    return
}

New-ExclusiveDirectory $outputPath
$script:orphanIds = [Collections.Generic.List[int]]::new()
$steps = [ordered]@{}
foreach ($name in $stepNames) {
    $kind = if ($name -in @('bareMissingBang', 'ownInitializer')) { 'pair' } elseif ($name -like 'managed*') { 'managed' } else { 'selfhost' }
    $fixtureId = if ($name -like '*Rebind') { 'rebind' } elseif ($name -like '*Shadow') { 'shadow' } else { $name }
    $steps[$name] = New-Step $fixtureId $kind
}
$record = [ordered]@{
    schemaVersion = 1; gate = 'c477-canonical-rebind'; state = 'running'; total = 6; completed = 0; passed = 0
    managedCompilerPath = $managedPath; managedCompilerSha256 = Get-Sha $managedPath
    selfhostCompilerPath = $selfhostPath; selfhostCompilerSha256 = Get-Sha $selfhostPath
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null; inputsStable = $false
    processObservationScope = 'bounded-supervised-process-tree-and-post-exit-CIM-parent-snapshot;exited-intermediate-descendants-not-proven'
    negativeProofScope = 'strict-managed-selfhost-cli-negative-pair-plus-pre-LLVM-semantic-only-count;no-product'
    steps = $steps; orphanProcessIds = @(); failureId = $null; failure = $null
}
$resultPath = Join-Path $outputPath 'result.json'
function Write-Result { Write-AtomicResult $resultPath (Assert-Result $record) }
Write-Result
$active = $null
$activeCounted = $false
try {
    foreach ($name in $stepNames) {
        if ((Get-Fingerprint) -cne $fingerprintStart) { throw 'C477CR_INPUT_DRIFT: before step' }
        $active = $name
        $activeCounted = $false
        $step = $record.steps[$name]
        $caseDir = Join-Path $outputPath $name
        $step.caseDirectory = $caseDir
        $fixture = $fixturePins[$step.fixtureId]
        $source = Resolve-Input $fixture[0]
        $expected = Resolve-Input $fixture[2]
        if ($step.compiler -ceq 'pair') {
            $validationDir = Join-Path $outputPath "$name-validation"
            New-ExclusiveDirectory $validationDir
            $validateOut = Join-Path $validationDir 'validate.stdout.txt'
            $validateErr = Join-Path $validationDir 'validate.stderr.txt'
            $countsOut = Join-Path $validationDir 'diagnostic-counts.stdout.txt'
            $countsErr = Join-Path $validationDir 'diagnostic-counts.stderr.txt'
            $validateExit = Invoke-Logged $selfhostPath @('validate', $source) $validationDir "$name validate" $validateOut $validateErr
            $validateText = [IO.File]::ReadAllText($validateOut)
            if ($validateExit -ne 0 -or (Get-Item -LiteralPath $validateErr).Length -ne 0 -or $validateText -cnotmatch '^checked diagnostics = ([1-9][0-9]*)\r?\n$') { throw "C477CR_VALIDATE: $name" }
            $step.validationCount = [int]$Matches[1]
            $countExit = Invoke-Logged $selfhostPath @('diagnostic-counts', $source) $validationDir "$name diagnostic counts" $countsOut $countsErr
            $countText = [IO.File]::ReadAllText($countsOut)
            $detailText = [IO.File]::ReadAllText($countsErr)
            if ($countExit -ne 0 -or $countText -cnotmatch '^checked diagnostics = ([1-9][0-9]*)\r?\n$') { throw "C477CR_DIAGNOSTIC_COUNTS: $name" }
            $totalCount = [int]$Matches[1]
            if ($detailText -cnotmatch '^semantic diagnostics = ([1-9][0-9]*)\r?\nir diagnostics = ([0-9]+)\r?\n$') { throw "C477CR_DIAGNOSTIC_DETAIL: $name" }
            $step.semanticCount = [int]$Matches[1]
            $step.irCount = [int]$Matches[2]
            if ($totalCount -ne $step.validationCount -or $step.semanticCount -ne $totalCount -or $step.irCount -ne 0) { throw "C477CR_PRE_LLVM_PARITY: $name" }
            Assert-ExactNames $validationDir @('validate.stdout.txt', 'validate.stderr.txt', 'diagnostic-counts.stdout.txt', 'diagnostic-counts.stderr.txt')
            $step.nestedResultPath = Join-Path $caseDir 'result.json'
            & $negativeRunner -ManagedCompiler $managedPath -SelfhostCompiler $selfhostPath -ManagedCompilerSha256 $ManagedCompilerSha256 -SelfhostCompilerSha256 $SelfhostCompilerSha256 -Source $source -Expected $expected -OutputDirectory $caseDir -RepositoryRoot $root -LlvmRoot $llvmPath -StdlibRoot $stdlibPath -TimeoutMilliseconds $TimeoutMilliseconds
            $nestedText = [IO.File]::ReadAllText($step.nestedResultPath)
            if (-not (Test-Json -Json $nestedText -SchemaFile $negativeSchema)) { throw "C477CR_NEGATIVE_SCHEMA: $name" }
            $nested = $nestedText | ConvertFrom-Json
            if ($nested.state -cne 'passed' -or -not $nested.inputsStable -or @($nested.orphanProcessIds).Count -ne 0) { throw "C477CR_NEGATIVE_PARITY: $name" }
        } else {
            New-ExclusiveDirectory $caseDir
            $managed = $step.compiler -ceq 'managed'
            $product = Join-Path $caseDir 'probe.exe'
            $llvmFile = "$product.ll"
            $bitcode = Join-Path $caseDir 'probe.bc'
            $buildFile = if ($managed) { $dotnetPath } else { $selfhostPath }
            [string[]]$arguments = New-PositiveBuildArguments $managed $managedPath $source $product $llvmPath $stdlibPath
            $buildOut = Join-Path $caseDir 'build.stdout.txt'
            $buildErr = Join-Path $caseDir 'build.stderr.txt'
            $step.buildExitCode = Invoke-Logged $buildFile $arguments $caseDir "$name build" $buildOut $buildErr
            $buildText = [IO.File]::ReadAllText($buildOut) + [IO.File]::ReadAllText($buildErr)
            if ($step.buildExitCode -ne 0 -or $buildText -match '(?im)^\s*(?:warning(?:\s|:)|note(?:\s|:)|sollang:\s*(?:warning|note)(?:\s|:))') { throw "C477CR_BUILD: $name exit=$($step.buildExitCode) or warning/note" }
            foreach ($path in @($product, $llvmFile)) {
                if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw "C477CR_PRODUCT: $name $path" }
            }
            $step.closureExitCode = Invoke-Logged $pwshPath @('-NoProfile', '-File', $closureScript, '-LlvmPath', $llvmFile) $caseDir "$name direct-call closure" (Join-Path $caseDir 'closure.stdout.txt') (Join-Path $caseDir 'closure.stderr.txt')
            if ($step.closureExitCode -ne 0) { throw "C477CR_DIRECT_CALL_CLOSURE: $name" }
            $step.llvmAsExitCode = Invoke-Logged $llvmAsPath @($llvmFile, '-o', $bitcode) $caseDir "$name llvm-as" (Join-Path $caseDir 'llvm-as.stdout.txt') (Join-Path $caseDir 'llvm-as.stderr.txt')
            if ($step.llvmAsExitCode -ne 0 -or -not (Test-Path -LiteralPath $bitcode -PathType Leaf) -or (Get-Item -LiteralPath $bitcode).Length -eq 0) { throw "C477CR_LLVM_AS: $name" }
            $runOut = Join-Path $caseDir 'run.stdout.txt'
            $runErr = Join-Path $caseDir 'run.stderr.txt'
            $step.runExitCode = Invoke-Logged $product @() $caseDir "$name run" $runOut $runErr
            if ($step.runExitCode -ne 0 -or (Get-Item -LiteralPath $runErr).Length -ne 0) { throw "C477CR_RUN: $name" }
            if (-not [Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($runOut), [IO.File]::ReadAllBytes($expected))) { throw "C477CR_STDOUT: $name" }
            Assert-PositiveArtifacts $caseDir $managed
        }
        if ((Get-Fingerprint) -cne $fingerprintStart) { throw 'C477CR_INPUT_DRIFT: after step' }
        Complete-StepRecord $record $name ([ref]$activeCounted) { Write-Result }
        $active = $null
    }
    $record.inputFingerprintEnd = Get-Fingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C477CR_INPUT_DRIFT: final' }
    $record.state = 'passed'
    Write-Result
    Write-Host "[c477 canonical rebind] PASS 6/6 checks; $resultPath"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $active) {
        Set-FailedStepRecord $record $active $activeCounted $message
        $step = $record.steps[$active]
        if ($step.compiler -ceq 'pair' -and $null -ne $step.nestedResultPath -and (Test-Path -LiteralPath $step.nestedResultPath -PathType Leaf)) {
            try {
                $nested = [IO.File]::ReadAllText($step.nestedResultPath) | ConvertFrom-Json
                foreach ($id in @($nested.orphanProcessIds)) {
                    if ($id -gt 0 -and -not $script:orphanIds.Contains([int]$id)) { $script:orphanIds.Add([int]$id) }
                }
            } catch { $message += "; nested orphan inspection failed: $($_.Exception.Message)" }
        }
    }
    $record.orphanProcessIds = @($script:orphanIds)
    $record.failureId = if ($message -match '^C477CR_[A-Z_]+:') { ($message -split ':')[0] } elseif ($message -match 'exceeded the configured verification limit') { 'C477CR_PROCESS_TIMEOUT' } else { 'C477CR_STEP_FAILED' }
    $record.failure = $message
    try { $record.inputFingerprintEnd = Get-Fingerprint; $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd }
    catch { $record.failure += "; final fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'
    Write-Result
    throw
}
