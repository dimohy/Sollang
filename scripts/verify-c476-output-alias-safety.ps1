[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [Parameter(Mandatory, ParameterSetName = 'Validate')][string]$Compiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [Parameter(Mandatory, ParameterSetName = 'Validate')][string]$CompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [Parameter(Mandatory, ParameterSetName = 'Validate')][string]$PositiveSource,
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [Parameter(Mandatory, ParameterSetName = 'Validate')][string]$PositiveSourceSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [Parameter(Mandatory, ParameterSetName = 'Validate')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [ValidateRange(1000, 15000)][int]$PreflightMilliseconds = 15000,
    [Parameter(Mandatory, ParameterSetName = 'Validate')][switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $PSScriptRoot 'contracts/c476-output-alias-safety.json'
$schemaPath = Join-Path $PSScriptRoot 'contracts/c476-output-alias-safety.schema.json'
$originalContractPath = Join-Path $PSScriptRoot 'contracts/c476-output-transaction.json'
$fixedCases = @('reservedBase', 'reservedMixed', 'reservedLl', 'trailingDot', 'trailingSpace')
$allCases = @($fixedCases) + @('shortNameAlias')

function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Assert-NoReparsePath([string]$Path) {
    $cursor = [IO.Path]::GetPathRoot($Path)
    foreach ($segment in ($Path.Substring($cursor.Length) -split '[\\/]')) {
        if ([string]::IsNullOrEmpty($segment)) { continue }
        $cursor = Join-Path $cursor $segment
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "OUTPUT_ALIAS_REPARSE_PATH: $cursor"
        }
    }
}
function Assert-Names([string[]]$Actual, [string[]]$Expected, [string]$Where) {
    $actualSorted = @($Actual | Sort-Object -CaseSensitive)
    $expectedSorted = @($Expected | Sort-Object -CaseSensitive)
    if ($actualSorted.Count -ne $expectedSorted.Count) {
        throw "OUTPUT_ALIAS_ARTIFACT_SET: $Where actual=$($actualSorted -join ',') expected=$($expectedSorted -join ',')"
    }
    for ($index = 0; $index -lt $actualSorted.Count; $index++) {
        if ($actualSorted[$index] -cne $expectedSorted[$index]) {
            throw "OUTPUT_ALIAS_ARTIFACT_SET: $Where actual=$($actualSorted -join ',') expected=$($expectedSorted -join ',')"
        }
    }
}
function Get-Names([string]$Directory) { return @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name) }
function Assert-RegularFile([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "OUTPUT_ALIAS_ARTIFACT_TYPE: expected a regular file: $Path"
    }
}
function Assert-CaseInventory([string]$CaseDirectory, [string]$ArtifactDirectory, [string[]]$ExpectedArtifacts, [string]$Sentinel) {
    Assert-NoReparsePath $CaseDirectory
    Assert-NoReparsePath $ArtifactDirectory
    if (-not (Test-Path -LiteralPath $CaseDirectory -PathType Container) -or
        -not (Test-Path -LiteralPath $ArtifactDirectory -PathType Container)) {
        throw "OUTPUT_ALIAS_ARTIFACT_TYPE: expected case/artifacts directories: $CaseDirectory"
    }
    Assert-Names @(Get-Names $CaseDirectory) @('artifacts', 'build.stdout.txt', 'build.stderr.txt') $CaseDirectory
    Assert-RegularFile (Join-Path $CaseDirectory 'build.stdout.txt')
    Assert-RegularFile (Join-Path $CaseDirectory 'build.stderr.txt')
    Assert-Names @(Get-Names $ArtifactDirectory) $ExpectedArtifacts $ArtifactDirectory
    if (-not [string]::IsNullOrEmpty($Sentinel)) { Assert-RegularFile $Sentinel }
}
function New-ExclusiveDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "OUTPUT_ALIAS_PARENT_MISSING: $parent" }
    Assert-NoReparsePath $parent
    if (-not ('C476AliasDirectoryNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C476AliasDirectoryNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
    [DllImport("kernel32.dll", EntryPoint = "GetShortPathNameW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern uint GetShortPathName(string longPath, System.Text.StringBuilder shortPath, uint bufferLength);
}
'@
    }
    if (-not [C476AliasDirectoryNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        throw "OUTPUT_ALIAS_PATH_EXISTS_OR_CREATE_FAILED: $Path; Win32=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    Assert-NoReparsePath $Path
}
function Get-ShortPath([string]$Path) {
    $buffer = [Text.StringBuilder]::new(32768)
    $count = [C476AliasDirectoryNative]::GetShortPathName($Path, $buffer, [uint32]$buffer.Capacity)
    if ($count -eq 0 -or $count -ge $buffer.Capacity) {
        throw "OUTPUT_ALIAS_SHORT_NAME_QUERY_FAILED: $Path; Win32=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    return $buffer.ToString()
}
function New-CaseRecord {
    return [ordered]@{
        state = 'not-run'; outputPath = $null; exitCode = $null; elapsedMilliseconds = $null; stdoutPath = $null; stderrPath = $null
        products = @(); sentinelSha256Before = $null; sentinelSha256After = $null; reason = $null; failure = $null
    }
}
function Assert-Contract {
    $contractJson = [IO.File]::ReadAllText($contractPath)
    if (-not (Test-Json -Json $contractJson -SchemaFile $schemaPath)) { throw 'OUTPUT_ALIAS_CONTRACT_INVALID: supplemental contract rejected by schema' }
    $contract = $contractJson | ConvertFrom-Json
    $names = @($contract.cases.PSObject.Properties.Name)
    if ($names.Count -ne $allCases.Count) { throw 'OUTPUT_ALIAS_CONTRACT_INVALID: fixed case count changed' }
    foreach ($name in $allCases) { if ($names -cnotcontains $name) { throw "OUTPUT_ALIAS_CONTRACT_INVALID: missing $name" } }
    $expectedNames = [ordered]@{
        reservedBase = 'foo.sollang-txn-lock'
        reservedMixed = 'foo.SoLlAnG-TxN-lock'
        reservedLl = 'foo.ll.sollang-txn-lock'
        trailingDot = 'foo.'
        trailingSpace = 'foo '
    }
    foreach ($name in $fixedCases) {
        if ($contract.cases.$name.outputName -cne $expectedNames[$name]) {
            throw "OUTPUT_ALIAS_CONTRACT_INVALID: output identity changed for $name"
        }
    }
    if ((Get-Sha $originalContractPath) -cne '65EACDEC301F36F7052E84C989EE9BB8AA0A8AB37E2E3C754F1F9913E7DEAD61') {
        throw 'OUTPUT_ALIAS_ORIGINAL_CONTRACT_DRIFT: original 13-scenario contract changed'
    }
    return $contract
}
function Assert-Result([object]$Result) {
    $json = $Result | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) { throw 'OUTPUT_ALIAS_RESULT_SCHEMA_INVALID: result rejected by schema' }
    $states = @($allCases | ForEach-Object { $Result.cases[$_].state })
    if ($Result.completed -ne @($states | Where-Object { $_ -ne 'not-run' }).Count -or
        $Result.passed -ne @($states | Where-Object { $_ -eq 'passed' }).Count -or
        $Result.unverified -ne @($states | Where-Object { $_ -eq 'unverified' }).Count) {
        throw 'OUTPUT_ALIAS_RESULT_COUNTS_INVALID: case states and counts differ'
    }
    if ($Result.state -eq 'passed' -and @($states | Where-Object { $_ -ne 'passed' }).Count -ne 0) {
        throw 'OUTPUT_ALIAS_RESULT_OVERCLAIM: all six cases must pass'
    }
    if ($Result.state -eq 'deterministic-passed-8dot3-unverified' -and
        (@($fixedCases | Where-Object { $Result.cases[$_].state -ne 'passed' }).Count -ne 0 -or
         $Result.cases.shortNameAlias.state -ne 'unverified')) {
        throw 'OUTPUT_ALIAS_RESULT_OVERCLAIM: five deterministic cases must pass and 8.3 must be unverified'
    }
    return $json
}
function Publish-Result([string]$Path, [object]$Result) {
    $json = Assert-Result $Result
    $temporary = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
    }
}
function Publish-TerminalFallback([string]$Path, [object]$Result, [string]$OriginalFailure) {
    $fallbackPath = Join-Path (Split-Path -Parent $Path) 'terminal-failure.json'
    try {
        [IO.File]::WriteAllText($fallbackPath, ($Result | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    } catch {
        throw "OUTPUT_ALIAS_RESULT_PERSIST_FAILED: $OriginalFailure; fallback: $($_.Exception.Message)"
    }
}
function Get-LiveDescendants([int]$RootId) {
    $records = @(Get-CimInstance Win32_Process)
    $found = [Collections.Generic.HashSet[int]]::new()
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $records) {
            $id = [int]$record.ProcessId
            if ($frontier -contains [int]$record.ParentProcessId -and $id -ne $RootId -and $found.Add($id)) { $next += $id }
        }
        $frontier = $next
    }
    return @($found | Sort-Object)
}
function Invoke-Supervised([string]$Exe, [string[]]$Arguments, [string]$WorkingDirectory, [string]$StdoutPath, [string]$StderrPath, [string[]]$ExpectedArtifacts) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Exe
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
    try {
        if (-not $process.Start()) { throw 'OUTPUT_ALIAS_SPAWN_FAILED: compiler did not start' }
        $started = $true
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $preflightLimit = [Math]::Min([Math]::Min($TimeoutMilliseconds, $PreflightMilliseconds), 15000)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($preflightLimit)
        $artifactDirectory = Join-Path $WorkingDirectory 'artifacts'
        while (-not $process.WaitForExit(250)) {
            Assert-Names @(Get-Names $artifactDirectory) $ExpectedArtifacts 'preflight active output'
            $workChildren = @(Get-LiveDescendants $process.Id | Where-Object {
                $child = Get-Process -Id $_ -ErrorAction Stop
                $child.ProcessName -notin @('conhost', 'OpenConsole')
            })
            if ($workChildren.Count -gt 0) {
                throw "OUTPUT_ALIAS_PRE_EFFECT_VIOLATION: compiler spawned child before rejecting unsafe output: $($workChildren -join ',')"
            }
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                throw "OUTPUT_ALIAS_PREFLIGHT_TIMEOUT: unsafe output was not rejected within $PreflightMilliseconds ms"
            }
        }
        if (-not $process.WaitForExit(0)) { throw 'OUTPUT_ALIAS_PROCESS_NOT_TERMINAL: compiler remained active' }
        $elapsedMilliseconds = ($process.ExitTime - $process.StartTime).TotalMilliseconds
        if ($elapsedMilliseconds -lt 0) { throw 'OUTPUT_ALIAS_PROCESS_TIME_INVALID: process exit preceded start' }
        if ($elapsedMilliseconds -gt $preflightLimit) {
            throw "OUTPUT_ALIAS_PREFLIGHT_TIMEOUT: unsafe output was rejected after $([Math]::Ceiling($elapsedMilliseconds)) ms (limit $preflightLimit ms)"
        }
        $descendants = @(Get-LiveDescendants $process.Id)
        foreach ($id in $descendants) { if (-not $script:orphanProcessIds.Contains($id)) { $script:orphanProcessIds.Add($id) } }
        if ($descendants.Count -gt 0) { throw "OUTPUT_ALIAS_ORPHAN_PROCESS: $($descendants -join ',')" }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw 'OUTPUT_ALIAS_LOG_DRAIN_TIMEOUT: compiler output streams' }
        $copies.GetAwaiter().GetResult()
        $stdout.Flush(); $stderr.Flush()
        return [pscustomobject]@{ exitCode = $process.ExitCode; elapsedMilliseconds = [long][Math]::Ceiling($elapsedMilliseconds) }
    } finally {
        if ($started -and -not $process.HasExited) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000) -and -not $script:orphanProcessIds.Contains($process.Id)) {
                $script:orphanProcessIds.Add($process.Id)
            }
        }
        if ($started) {
            try {
                foreach ($id in @(Get-LiveDescendants $process.Id)) {
                    if (-not $script:orphanProcessIds.Contains($id)) { $script:orphanProcessIds.Add($id) }
                }
            } catch {
                if ($script:orphanProcessIds.Count -eq 0) { throw "OUTPUT_ALIAS_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)" }
            }
        }
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}

$contract = Assert-Contract
if ($SelfTest) {
    $cases = [ordered]@{}
    foreach ($name in $allCases) { $cases[$name] = New-CaseRecord }
    $sample = [ordered]@{
        recordType = 'result'; schemaVersion = 1; gate = 'c476-output-alias-safety'; state = 'running'
        contractSha256 = ('A' * 64); compilerPath = 'compiler'; compilerSha256 = ('B' * 64)
        sourcePath = 'source'; sourceSha256 = ('C' * 64); stdlibRoot = 'stdlib'; llvmRoot = 'llvm'
        inputFingerprintStart = ('D' * 64); inputFingerprintEnd = $null; inputsStable = $false
        completed = 0; passed = 0; unverified = 0; cases = $cases; orphanProcessIds = @(); failureId = $null; failure = $null
    }
    [void](Assert-Result $sample)
    $sample.state = 'passed'
    try { [void](Assert-Result $sample); throw 'OUTPUT_ALIAS_SELFTEST_FAILED: accepted false full pass' }
    catch { if ($_.Exception.Message -match 'SELFTEST_FAILED') { throw } }
    $sample.state = 'running'
    foreach ($name in $fixedCases) {
        $sample.cases[$name].state = 'passed'; $sample.cases[$name].exitCode = 1
        $sample.cases[$name].elapsedMilliseconds = 100
        $sample.cases[$name].stdoutPath = 'stdout'; $sample.cases[$name].stderrPath = 'stderr'
    }
    $sample.cases.shortNameAlias.state = 'unverified'; $sample.cases.shortNameAlias.reason = '8.3 unavailable'
    $sample.completed = 6; $sample.passed = 5; $sample.unverified = 1
    $sample.state = 'deterministic-passed-8dot3-unverified'; $sample.inputsStable = $true; $sample.inputFingerprintEnd = ('D' * 64)
    [void](Assert-Result $sample)
    $sample.cases.shortNameAlias.state = 'passed'; $sample.cases.shortNameAlias.reason = $null
    $sample.cases.shortNameAlias.exitCode = 1; $sample.cases.shortNameAlias.elapsedMilliseconds = 100
    $sample.cases.shortNameAlias.stdoutPath = 'stdout'; $sample.cases.shortNameAlias.stderrPath = 'stderr'
    $sample.passed = 6; $sample.unverified = 0; $sample.state = 'passed'
    [void](Assert-Result $sample)
    $sample.cases.reservedBase.elapsedMilliseconds = 15001
    try { [void](Assert-Result $sample); throw 'OUTPUT_ALIAS_SELFTEST_FAILED: accepted late rejection' }
    catch { if ($_.Exception.Message -match 'SELFTEST_FAILED') { throw } }
    Write-Host '[c476 output alias safety] self-test passed; compiler not launched'
    return
}

if (-not $IsWindows) { throw 'OUTPUT_ALIAS_PLATFORM_UNSUPPORTED: this runner proves windows-x64 only' }
$compilerPath = Resolve-Input $Compiler
$sourcePath = Resolve-Input $PositiveSource
$stdlibPath = Resolve-Input $StdlibRoot
$llvmPath = Resolve-Input $LlvmRoot
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_ALIAS_PATH_INVALID: output must be below $scratchRoot"
}
foreach ($path in @($compilerPath, $sourcePath, $stdlibPath, $llvmPath, $outputPath)) { Assert-NoReparsePath $path }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_ALIAS_PATH_EXISTS: $outputPath" }
if ($CompilerSha256 -cnotmatch '^[A-Fa-f0-9]{64}$' -or (Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) {
    throw 'OUTPUT_ALIAS_COMPILER_IDENTITY: compiler SHA-256 differs from requested input'
}
if ($PositiveSourceSha256 -cnotmatch '^[A-Fa-f0-9]{64}$' -or (Get-Sha $sourcePath) -cne $PositiveSourceSha256.ToUpperInvariant()) {
    throw 'OUTPUT_ALIAS_SOURCE_IDENTITY: source SHA-256 differs from requested input'
}
if (-not (Test-Path -LiteralPath (Join-Path $llvmPath 'bin/clang.exe') -PathType Leaf)) { throw 'OUTPUT_ALIAS_CLANG_MISSING: expected LLVM toolchain' }
function Get-InputFingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'c476-output-alias-safety-v1'; common = $common
        compilerSha256 = $CompilerSha256.ToUpperInvariant(); sourceSha256 = $PositiveSourceSha256.ToUpperInvariant()
        timeoutMilliseconds = [string]$TimeoutMilliseconds; preflightMilliseconds = [string]$PreflightMilliseconds
    }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath @($PSCommandPath, $contractPath, $schemaPath, $originalContractPath, $sourcePath)
}
$fingerprintStart = Get-InputFingerprint
if ($ValidateInputsOnly) {
    Write-Host "[c476 output alias safety] inputs valid; compiler=$($CompilerSha256.ToUpperInvariant()) source=$($PositiveSourceSha256.ToUpperInvariant()) fingerprint=$fingerprintStart; no compiler launched"
    return
}

$script:orphanProcessIds = [Collections.Generic.List[int]]::new()
$cases = [ordered]@{}
foreach ($name in $allCases) { $cases[$name] = New-CaseRecord }
$result = [ordered]@{
    recordType = 'result'; schemaVersion = 1; gate = 'c476-output-alias-safety'; state = 'running'
    contractSha256 = Get-Sha $contractPath; compilerPath = $compilerPath; compilerSha256 = $CompilerSha256.ToUpperInvariant()
    sourcePath = $sourcePath; sourceSha256 = $PositiveSourceSha256.ToUpperInvariant(); stdlibRoot = $stdlibPath; llvmRoot = $llvmPath
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null; inputsStable = $false
    completed = 0; passed = 0; unverified = 0; cases = $cases; orphanProcessIds = @(); failureId = $null; failure = $null
}
$resultPath = Join-Path $outputPath 'result.json'
New-ExclusiveDirectory $outputPath
try {
    Publish-Result $resultPath $result
} catch {
    $initialFailure = $_.Exception.Message
    $result.state = 'failed'; $result.failureId = 'OUTPUT_ALIAS_INITIAL_RESULT_FAILED'; $result.failure = $initialFailure
    Publish-TerminalFallback $resultPath $result $initialFailure
    throw
}
$activeName = $null
try {
    foreach ($name in $allCases) {
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_ALIAS_INPUT_DRIFT: before case' }
        $activeName = $name
        $case = $result.cases[$name]
        $caseDirectory = Join-Path $outputPath $name
        $artifactDirectory = Join-Path $caseDirectory 'artifacts'
        New-ExclusiveDirectory $caseDirectory
        New-ExclusiveDirectory $artifactDirectory
        $case.stdoutPath = Join-Path $caseDirectory 'build.stdout.txt'
        $case.stderrPath = Join-Path $caseDirectory 'build.stderr.txt'
        $expectedArtifacts = @()
        if ($name -eq 'shortNameAlias') {
            $sentinel = Join-Path $artifactDirectory 'sollang-long-output-target.exe'
            [IO.File]::WriteAllBytes($sentinel, [Text.Encoding]::ASCII.GetBytes('C476-owned-existing-output-sentinel'))
            $case.sentinelSha256Before = Get-Sha $sentinel
            $case.outputPath = Get-ShortPath $sentinel
            $expectedArtifacts = @('sollang-long-output-target.exe')
            $shortBasename = [IO.Path]::GetFileName($case.outputPath)
            if (-not $shortBasename.Contains('~') -or [string]::Equals($shortBasename, [IO.Path]::GetFileName($sentinel), [StringComparison]::OrdinalIgnoreCase)) {
                $case.state = 'unverified'; $case.reason = '8.3 short basename was not generated for the owned sentinel on this volume'
                $case.sentinelSha256After = Get-Sha $sentinel
                $case.products = @(Get-Names $artifactDirectory)
                Assert-Names $case.products $expectedArtifacts $name
                Assert-NoReparsePath $artifactDirectory
                Assert-RegularFile $sentinel
                if ($case.sentinelSha256After -cne $case.sentinelSha256Before) { throw 'OUTPUT_ALIAS_SENTINEL_CHANGED: unavailable 8.3 sentinel changed' }
                $result.completed++; $result.unverified++
                if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_ALIAS_INPUT_DRIFT: during unavailable 8.3 case' }
                Publish-Result $resultPath $result
                $activeName = $null
                continue
            }
        } else {
            $case.outputPath = Join-Path $artifactDirectory ([string]$contract.cases.$name.outputName)
        }
        Publish-Result $resultPath $result
        $arguments = @('build', $sourcePath, '-o', $case.outputPath, '--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps')
        $invocation = Invoke-Supervised -Exe $compilerPath -Arguments $arguments -WorkingDirectory $caseDirectory -StdoutPath $case.stdoutPath -StderrPath $case.stderrPath -ExpectedArtifacts $expectedArtifacts
        $case.exitCode = $invocation.exitCode
        $case.elapsedMilliseconds = $invocation.elapsedMilliseconds
        $case.products = @(Get-Names $artifactDirectory)
        if ($name -eq 'shortNameAlias') { $case.sentinelSha256After = Get-Sha $sentinel }
        if ($case.exitCode -eq 0) { throw "OUTPUT_ALIAS_UNSAFE_ACCEPTANCE: $name build accepted unsafe final output" }
        if ((Get-Item -LiteralPath $case.stdoutPath).Length -ne 0) { throw "OUTPUT_ALIAS_STDOUT_NOT_EMPTY: $name" }
        $diagnostic = [IO.File]::ReadAllText($case.stderrPath)
        $outputDiagnostic = '(?im)^sollang:\s*(?:(?:output|destination|path)[^\r\n]*(?:reserved|alias|trailing|invalid|unsafe|lock|ambiguous)|(?:reserved|alias|trailing|invalid|unsafe|lock|ambiguous)[^\r\n]*(?:output|destination|path))'
        if ($diagnostic -notmatch $outputDiagnostic -or $diagnostic -match '(?i)semantic error') {
            throw "OUTPUT_ALIAS_DIAGNOSTIC_NOT_ACTIONABLE: $name"
        }
        Assert-CaseInventory $caseDirectory $artifactDirectory $expectedArtifacts $(if ($name -eq 'shortNameAlias') { $sentinel } else { $null })
        if ($name -eq 'shortNameAlias' -and $case.sentinelSha256After -cne $case.sentinelSha256Before) {
            throw 'OUTPUT_ALIAS_SENTINEL_CHANGED: existing long-name output was modified'
        }
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_ALIAS_INPUT_DRIFT: during case' }
        $case.state = 'passed'; $result.completed++; $result.passed++
        Publish-Result $resultPath $result
        $activeName = $null
    }
    $result.inputFingerprintEnd = Get-InputFingerprint
    $result.inputsStable = $result.inputFingerprintStart -ceq $result.inputFingerprintEnd
    if (-not $result.inputsStable) { throw 'OUTPUT_ALIAS_INPUT_DRIFT: final fingerprint changed' }
    Assert-Names @(Get-Names $outputPath) (@('result.json') + $allCases) 'result root'
    $result.orphanProcessIds = @($script:orphanProcessIds)
    if ($result.orphanProcessIds.Count -ne 0) { throw 'OUTPUT_ALIAS_ORPHAN_PROCESS: observed surviving process' }
    $result.state = if ($result.unverified -eq 1) { 'deterministic-passed-8dot3-unverified' } else { 'passed' }
    Publish-Result $resultPath $result
    Write-Host "[c476 output alias safety] $($result.state); passed=$($result.passed)/6 unverified=$($result.unverified)/6; $resultPath"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $activeName) {
        $case = $result.cases[$activeName]
        if ($case.state -eq 'passed') { $result.passed-- }
        elseif ($case.state -eq 'unverified') { $result.unverified-- }
        else { $result.completed++ }
        $case.state = 'failed'; $case.reason = $null; $case.failure = $message
        $artifactDirectory = Join-Path (Join-Path $outputPath $activeName) 'artifacts'
        if (Test-Path -LiteralPath $artifactDirectory -PathType Container) { $case.products = @(Get-Names $artifactDirectory) }
    }
    $result.orphanProcessIds = @($script:orphanProcessIds)
    $result.failureId = if ($message -match '^OUTPUT_ALIAS_[A-Z_]+:') { ($message -split ':')[0] }
        elseif ($message -match 'exceeded the configured verification limit') { 'OUTPUT_ALIAS_PROCESS_TIMEOUT' }
        else { 'OUTPUT_ALIAS_ASSERTION_FAILED' }
    $result.failure = $message
    try {
        $result.inputFingerprintEnd = Get-InputFingerprint
        $result.inputsStable = $result.inputFingerprintStart -ceq $result.inputFingerprintEnd
    } catch { $result.failure += "; end fingerprint failed: $($_.Exception.Message)" }
    $result.state = 'failed'
    try { Publish-Result $resultPath $result }
    catch { Publish-TerminalFallback $resultPath $result $_.Exception.Message; throw }
    throw
}
