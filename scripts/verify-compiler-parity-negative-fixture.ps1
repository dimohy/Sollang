[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$Source,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$Expected,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$ExternalOutputRoot = '',
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 120000,
    [switch]$ValidateInputsOnly,
    [string]$PhaseExecutionContract = "",
    [ValidateSet('', 'managed', 'selfhost')][string]$PhaseCompilerSide = '',
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-UnderRoot([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}
function Assert-UnderRoot([string]$Path, [string]$Parent, [string]$Name) {
    if (-not $Path.StartsWith($Parent + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name must be a child of $Parent`: $Path"
    }
}
function Assert-NoReparseAncestors([string]$Path, [string]$Name) {
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = [IO.Path]::GetPathRoot($full)
    $segments = $full.Substring($cursor.Length) -split '[\\/]'
    foreach ($segment in @('') + $segments) {
        if ($segment) { $cursor = Join-Path $cursor $segment }
        try {
            $attributes = [IO.File]::GetAttributes($cursor)
        } catch [IO.FileNotFoundException] {
            return
        } catch [IO.DirectoryNotFoundException] {
            return
        }
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Name traverses a junction or symbolic link: $cursor"
        }
    }
}

function Get-NegativeLiveDescendantIds([int]$RootProcessId, [datetime]$RootStartTime, [object[]]$ProcessRecords) {
    $descendants = [System.Collections.Generic.HashSet[int]]::new()
    $frontier = @([pscustomobject]@{ Id = $RootProcessId; StartTime = $RootStartTime })
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($parent in $frontier) {
            foreach ($record in $ProcessRecords) {
                $childId = [int]$record.ProcessId
                $childStartTime = [datetime]$record.CreationDate
                if ([int]$record.ParentProcessId -eq $parent.Id -and
                    $childStartTime -ge $parent.StartTime -and
                    $childId -ne $RootProcessId -and $descendants.Add($childId)) {
                    $next += [pscustomobject]@{ Id = $childId; StartTime = $childStartTime }
                }
            }
        }
        $frontier = $next
    }
    return @($descendants | Sort-Object)
}

if ($SelfTest) {
    $schema = Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'
    $scriptText = [IO.File]::ReadAllText($PSCommandPath)
    if ($scriptText -match '\$process\.WaitForExit\(\s*\)' -or
        $scriptText -notmatch '\$process\.WaitForExit\(0\)' -or
        $scriptText -notmatch '\$copies\.Wait\(5000\)') {
        throw 'Negative runner lost its bounded process or output-drain waits'
    }
    $rootStartTime = [datetime]'2026-09-25T12:00:00'
    $processRecords = @(
        [pscustomobject]@{ ProcessId = 101; ParentProcessId = 100; CreationDate = [datetime]'2026-09-25T12:00:01' },
        [pscustomobject]@{ ProcessId = 102; ParentProcessId = 101; CreationDate = [datetime]'2026-09-25T12:00:02' },
        [pscustomobject]@{ ProcessId = 200; ParentProcessId = 1; CreationDate = [datetime]'2026-09-25T12:00:03' },
        [pscustomobject]@{ ProcessId = 201; ParentProcessId = 100; CreationDate = [datetime]'2026-09-23T19:59:58' })
    $liveDescendants = @(Get-NegativeLiveDescendantIds 100 $rootStartTime $processRecords)
    if ($liveDescendants.Count -ne 2 -or $liveDescendants[0] -ne 101 -or $liveDescendants[1] -ne 102) {
        throw 'Negative runner failed to detect live descendants of an exited root process'
    }
    if (@(Get-NegativeLiveDescendantIds 100 $rootStartTime @($processRecords[2], $processRecords[3])).Count -ne 0) {
        throw 'Negative runner attributed an unrelated or old PID-parent process to the compiler'
    }
    $check = [ordered]@{
        exitCode = 1; nonzeroExit = $true; expectedInStderr = $true
        noEmittedProducts = $true; generatedProducts = @()
        outputDirectory = 'output'; stdoutPath = 'stdout'; stderrPath = 'stderr'
    }
    $record = [ordered]@{
        schemaVersion = 1; gate = 'compiler-parity-negative-fixture'; state = 'passed'
        source = 'source'; expected = 'expected'
        managedCompilerPath = 'managed'; selfhostCompilerPath = 'selfhost'
        llvmRoot = 'llvm'; stdlibRoot = 'stdlib'; timeoutMilliseconds = 120000
        sourceSha256 = ('A' * 64); expectedSha256 = ('B' * 64)
        managedCompilerSha256 = ('C' * 64); selfhostCompilerSha256 = ('D' * 64)
        inputFingerprintStart = ('E' * 64); inputFingerprintEnd = ('E' * 64)
        inputsStable = $true
        logs = @{ managedStdout = 'a'; managedStderr = 'b'; selfhostStdout = 'c'; selfhostStderr = 'd' }
        managed = $check; selfhost = $check; orphanProcessIds = @()
        failureId = $null; failure = $null
    }
    if (-not (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $schema)) {
        throw 'Negative result schema rejected a complete passing record'
    }
    $captured = $record | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable
    $captured.state='phase-captured'; $captured.phaseCompilerSide='managed'; $captured.selfhost=$null
    if (-not (Test-Json -Json ($captured | ConvertTo-Json -Depth 8) -SchemaFile $schema)) { throw 'Negative schema rejected managed-only phase capture' }
    $captured.state='passed'
    if (Test-Json -Json ($captured | ConvertTo-Json -Depth 8) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'Negative schema promoted one side to paired pass' }
    $record.orphanProcessIds = @(1234)
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $schema -ErrorAction SilentlyContinue) {
        throw 'Negative result schema accepted orphaned process as a pass'
    }
    $record.state = 'failed'
    $record.failureId = 'NEGATIVE_PROCESS_ORPHANED'
    $record.failure = 'bounded termination left process 1234 alive'
    if (-not (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $schema)) {
        throw 'Negative result schema rejected an orphan-aware terminal failure'
    }
    $record.orphanProcessIds = @()
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $schema -ErrorAction SilentlyContinue) {
        throw 'Negative result schema accepted an orphan failure without a process ID'
    }
    $record.failureId = 'NEGATIVE_PROCESS_INSPECTION_FAILED'
    $record.failure = 'simulated process inspection failure'
    if (-not (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $schema)) {
        throw 'Negative result schema rejected a process-inspection failure'
    }
    [void]$record.Remove('managedCompilerPath')
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $schema -ErrorAction SilentlyContinue) {
        throw 'Negative result schema accepted a missing managed compiler path'
    }
    Write-Host '[compiler parity negative self-test] PASS bounded waits and result state contract; no compiler executed.'
    return
}

$managedPath = Resolve-UnderRoot $ManagedCompiler
$selfhostPath = Resolve-UnderRoot $SelfhostCompiler
$sourcePath = Resolve-UnderRoot $Source
$expectedPath = Resolve-UnderRoot $Expected
$llvmPath = Resolve-UnderRoot $LlvmRoot
$stdlibPath = Resolve-UnderRoot $StdlibRoot
$outputPath = Resolve-UnderRoot $OutputDirectory
$scratchPath = Join-Path $root 'artifacts/scratch'
$schemaPath = Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'
foreach ($entry in @(
    @{ Path = $root; Name = 'RepositoryRoot' }, @{ Path = $managedPath; Name = 'ManagedCompiler' },
    @{ Path = $selfhostPath; Name = 'SelfhostCompiler' }, @{ Path = $sourcePath; Name = 'Source' },
    @{ Path = $expectedPath; Name = 'Expected' }, @{ Path = $llvmPath; Name = 'LlvmRoot' },
    @{ Path = $stdlibPath; Name = 'StdlibRoot' }, @{ Path = $schemaPath; Name = 'ResultSchema' },
    @{ Path = $outputPath; Name = 'OutputDirectory' })) {
    Assert-NoReparseAncestors $entry.Path $entry.Name
}
Assert-UnderRoot $sourcePath $root 'Source'
Assert-UnderRoot $expectedPath $root 'Expected'
if ([string]::IsNullOrWhiteSpace($ExternalOutputRoot)) {
    Assert-UnderRoot $outputPath $scratchPath 'OutputDirectory'
} else {
    if (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
        throw 'External OutputDirectory must be absolute'
    }
    $externalRoot = [IO.Path]::GetFullPath($ExternalOutputRoot)
    if (-not (Test-Path -LiteralPath $externalRoot -PathType Container)) {
        throw "ExternalOutputRoot does not exist: $externalRoot"
    }
    Assert-NoReparseAncestors $externalRoot 'ExternalOutputRoot'
    Assert-UnderRoot $outputPath $externalRoot 'OutputDirectory'
}
if ($managedPath -ceq $selfhostPath) { throw 'Managed and selfhost compilers must be distinct files' }
if ([IO.Path]::GetExtension($managedPath) -cne '.dll') { throw 'ManagedCompiler must be a .dll' }
if ([IO.Path]::GetExtension($selfhostPath) -cne '.exe') { throw 'SelfhostCompiler must be a Windows .exe' }
if ([IO.Path]::GetExtension($sourcePath) -cne '.slg') { throw 'Source must be a .slg file' }
if (-not $expectedPath.Equals(($sourcePath.Substring(0, $sourcePath.Length - 4) + '.stderr.contains.txt'),
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Expected must be the same-stem .stderr.contains.txt beside Source'
}
foreach ($item in @(
    @{ Path = $managedPath; Kind = 'Leaf' }, @{ Path = $selfhostPath; Kind = 'Leaf' },
    @{ Path = $sourcePath; Kind = 'Leaf' }, @{ Path = $expectedPath; Kind = 'Leaf' },
    @{ Path = $schemaPath; Kind = 'Leaf' },
    @{ Path = (Join-Path $llvmPath 'bin/clang.exe'); Kind = 'Leaf' },
    @{ Path = (Join-Path $llvmPath 'bin/llvm-as.exe'); Kind = 'Leaf' },
    @{ Path = $stdlibPath; Kind = 'Container' })) {
    if (-not (Test-Path -LiteralPath $item.Path -PathType $item.Kind)) {
        throw "Required $($item.Kind) not found: $($item.Path)"
    }
}
$managedPath = (Resolve-Path -LiteralPath $managedPath).ProviderPath
$selfhostPath = (Resolve-Path -LiteralPath $selfhostPath).ProviderPath
$sourcePath = (Resolve-Path -LiteralPath $sourcePath).ProviderPath
$expectedPath = (Resolve-Path -LiteralPath $expectedPath).ProviderPath
$llvmPath = (Resolve-Path -LiteralPath $llvmPath).ProviderPath
$stdlibPath = (Resolve-Path -LiteralPath $stdlibPath).ProviderPath
$sourceManifest = [IO.Path]::ChangeExtension($sourcePath, '.sources.txt')
$sourcePaths = @($sourcePath)
if (Test-Path -LiteralPath $sourceManifest -PathType Leaf) {
    Assert-NoReparseAncestors $sourceManifest 'SourceManifest'
    $sourcePaths = @(
        foreach ($entry in [IO.File]::ReadAllLines($sourceManifest)) {
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            if ([IO.Path]::IsPathRooted($entry)) { throw "Absolute source manifest entry: $entry" }
            $path = [IO.Path]::GetFullPath((Join-Path $root $entry.Trim()))
            Assert-UnderRoot $path $root 'SourceManifestEntry'
            Assert-NoReparseAncestors $path 'SourceManifestEntry'
            if ([IO.Path]::GetExtension($path) -cne '.slg' -or
                -not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Invalid source manifest entry: $entry"
            }
            $path
        }
    )
    if ($sourcePaths.Count -eq 0 -or $sourcePath -notin $sourcePaths -or
        @($sourcePaths | Select-Object -Unique).Count -ne $sourcePaths.Count) {
        throw "Invalid source manifest: $sourceManifest"
    }
}
if (Test-Path -LiteralPath $outputPath) { throw "OutputDirectory must not already exist: $outputPath" }
if ($ManagedCompilerSha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or
    $SelfhostCompilerSha256 -cnotmatch '^[a-fA-F0-9]{64}$') {
    throw 'Both fixed compiler identities must be SHA-256 values'
}
$actualManagedSha = (Get-FileHash -LiteralPath $managedPath -Algorithm SHA256).Hash
$actualSelfhostSha = (Get-FileHash -LiteralPath $selfhostPath -Algorithm SHA256).Hash
if ($actualManagedSha -cne $ManagedCompilerSha256.ToUpperInvariant() -or
    $actualSelfhostSha -cne $SelfhostCompilerSha256.ToUpperInvariant()) {
    throw 'A compiler differs from its fixed SHA-256 identity'
}
$diagnostic = [IO.File]::ReadAllText($expectedPath).Trim()
if ([string]::IsNullOrWhiteSpace($diagnostic)) { throw 'Expected diagnostic fragment must not be blank' }
$dotnetPath = (Get-Command dotnet -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath $dotnetPath -PathType Leaf)) { throw "dotnet command not found: $dotnetPath" }
Assert-NoReparseAncestors $dotnetPath 'dotnet'
$dotnetPath = (Resolve-Path -LiteralPath $dotnetPath).ProviderPath

function Get-InputFingerprint {
    foreach ($entry in @(
        @{ Path = $managedPath; Name = 'ManagedCompiler' }, @{ Path = $selfhostPath; Name = 'SelfhostCompiler' },
        @{ Path = $sourcePath; Name = 'Source' }, @{ Path = $expectedPath; Name = 'Expected' },
        @{ Path = $llvmPath; Name = 'LlvmRoot' }, @{ Path = $stdlibPath; Name = 'StdlibRoot' },
        @{ Path = $schemaPath; Name = 'ResultSchema' }, @{ Path = $dotnetPath; Name = 'dotnet' })) {
        Assert-NoReparseAncestors $entry.Path $entry.Name
    }
    $managedCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $managedPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $selfhostCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $selfhostPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'compiler-parity-negative-fixture-v1'
        managedCommon = $managedCommon
        selfhostCommon = $selfhostCommon
        managedSha256 = $actualManagedSha
        selfhostSha256 = $actualSelfhostSha
        timeoutMilliseconds = [string]$TimeoutMilliseconds
    }
    $fingerprintInputs = @($PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1'),
            (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'), $schemaPath,
            $dotnetPath, $sourcePath, $expectedPath) +
            @(if (Test-Path -LiteralPath $sourceManifest -PathType Leaf) { $sourceManifest }) + $sourcePaths
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings `
        -InputPath $fingerprintInputs
}

$phaseContexts = @{}
$phaseCases = @{}
if (-not [string]::IsNullOrWhiteSpace($PhaseExecutionContract)) {
    if ([string]::IsNullOrWhiteSpace($PhaseCompilerSide)) { throw 'PHASE_EXECUTION_NEGATIVE_SIDE_REQUIRED' }
    foreach ($side in @($PhaseCompilerSide)) {
        $binary = if ($side -ceq 'managed') { $managedPath } else { $selfhostPath }
        $context = Get-NativeExactPhaseContext $root $PhaseExecutionContract $side $binary $PSCommandPath
        [void](Assert-NativeExactPhaseOutputPath $root $outputPath)
        $cases = @($context.Contract.cases | Where-Object { $_.fixture.path -ceq [IO.Path]::GetRelativePath($root, $sourcePath).Replace('\', '/') })
        if ($cases.Count -ne 1 -or (Get-NativeExactPhaseExpectedStage $cases[0] compile $PhaseCompilerSide).exitCode -eq 0) { throw 'PHASE_EXECUTION_NEGATIVE_CASE_REQUIRED' }
        $prefix = Get-NativeExactPhaseOutcomePrefix $context $cases[0]
        if (Test-Path -LiteralPath "$prefix.compile.json") { throw 'PHASE_EXECUTION_CACHED_OUTCOME_FORBIDDEN' }
        $phaseContexts[$side] = $context; $phaseCases[$side] = $cases[0]
    }
} elseif ($PhaseCompilerSide) { throw 'PHASE_EXECUTION_CONTRACT_REQUIRED' }
$fingerprintStart = Get-InputFingerprint
if ($ValidateInputsOnly) {
    [pscustomobject]@{
        status = 'preflight-passed'
        managedCompilerSha256 = $actualManagedSha
        selfhostCompilerSha256 = $actualSelfhostSha
        sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        expectedSha256 = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
        inputFingerprint = $fingerprintStart
    } | ConvertTo-Json -Compress
    return
}

[void][IO.Directory]::CreateDirectory($outputPath)
Assert-NoReparseAncestors $outputPath 'OutputDirectory'
$resultPath = Join-Path $outputPath 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    gate = 'compiler-parity-negative-fixture'
    state = 'running'
    source = $sourcePath
    sourceManifest = if (Test-Path -LiteralPath $sourceManifest -PathType Leaf) { $sourceManifest } else { $null }
    sources = @($sourcePaths)
    expected = $expectedPath
    managedCompilerPath = $managedPath
    selfhostCompilerPath = $selfhostPath
    llvmRoot = $llvmPath
    stdlibRoot = $stdlibPath
    timeoutMilliseconds = $TimeoutMilliseconds
    sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    expectedSha256 = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
    managedCompilerSha256 = $actualManagedSha
    selfhostCompilerSha256 = $actualSelfhostSha
    inputFingerprintStart = $fingerprintStart
    inputFingerprintEnd = $null
    inputsStable = $false
    logs = [ordered]@{
        managedStdout = (Join-Path $outputPath 'managed.stdout.txt')
        managedStderr = (Join-Path $outputPath 'managed.stderr.txt')
        selfhostStdout = (Join-Path $outputPath 'selfhost.stdout.txt')
        selfhostStderr = (Join-Path $outputPath 'selfhost.stderr.txt')
    }
    managed = $null
    selfhost = $null
    orphanProcessIds = @()
    failureId = $null
    failure = $null
}
if ($PhaseCompilerSide) { $record.phaseCompilerSide=$PhaseCompilerSide }
function Write-Result {
    $json = $record | ConvertTo-Json -Depth 8
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
        throw 'Negative fixture result does not satisfy its result schema'
    }
    [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
}
Write-Result

function Invoke-NegativeBuild {
    param(
        [string]$File,
        [string[]]$Arguments,
        [string]$Name,
        [string]$StdoutPath,
        [string]$StderrPath,
        [System.Collections.Generic.List[int]]$OrphanProcessIds,
        [string]$ExecutionRecordPath = ""
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $stdoutFile = [IO.File]::Create($StdoutPath)
    $stderrFile = [IO.File]::Create($StderrPath)
    $execution = [ordered]@{schemaVersion=1;status='starting';pid=$null;command=@($File)+$Arguments;
        description="parity negative $Name build";startedAtUtc=[DateTime]::UtcNow.ToString('o');finishedAtUtc=$null;
        exit=$null;processesStopped=$false;stdoutPath=$StdoutPath;stderrPath=$StderrPath;failure=$null}
    if ($ExecutionRecordPath -and (Test-Path -LiteralPath $ExecutionRecordPath)) { throw 'PHASE_EXECUTION_RECORD_ALREADY_EXISTS' }

    try {
        if (-not $process.Start()) { throw "parity negative $Name could not start: $File" }
        $execution.pid=$process.Id; $execution.status='running'
        if ($ExecutionRecordPath) { [IO.File]::WriteAllText($ExecutionRecordPath, ($execution | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false)) }
        $stdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdoutFile)
        $stderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderrFile)
        $waitFailure = $null
        try {
            Wait-VerificationProcess -Process $process -Description "parity negative $Name build" `
                -TimeoutMilliseconds $TimeoutMilliseconds
        } catch {
            $waitFailure = $_
        }
        # Wait-VerificationProcess is bounded, including its termination grace.
        # A second parameterless wait would erase that bound if termination fails.
        if (-not $process.WaitForExit(0)) {
            $OrphanProcessIds.Add($process.Id)
            throw "NEGATIVE_PROCESS_ORPHANED: $Name process $($process.Id) remained alive after bounded termination"
        }
        try {
            $liveDescendants = @(Get-NegativeLiveDescendantIds $process.Id $process.StartTime @(Get-CimInstance Win32_Process))
        } catch {
            throw "NEGATIVE_PROCESS_INSPECTION_FAILED: $Name descendant inspection failed: $($_.Exception.Message)"
        }
        if ($liveDescendants.Count -gt 0) {
            foreach ($descendantId in $liveDescendants) { $OrphanProcessIds.Add($descendantId) }
            throw "NEGATIVE_PROCESS_ORPHANED: $Name process $($process.Id) exited with live descendants $($liveDescendants -join ',')"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($stdoutCopy, $stderrCopy))
        if (-not $copies.Wait(5000)) {
            throw "NEGATIVE_LOG_DRAIN_TIMEOUT: $Name process exited but output pipes did not drain within 5000 ms"
        }
        $copies.GetAwaiter().GetResult()
        $stdoutFile.Flush()
        $stderrFile.Flush()
        if ($null -ne $waitFailure) { throw $waitFailure }
        $execution.exit=$process.ExitCode; $execution.processesStopped=$true
        $execution.status=if ($process.ExitCode -eq 0) { 'passed' } else { 'failed' }
        return [pscustomobject]@{ ExitCode = $process.ExitCode }
    } catch {
        $execution.status='failed'; $execution.failure=$_.Exception.Message
        throw
    } finally {
        $execution.finishedAtUtc=[DateTime]::UtcNow.ToString('o')
        if ($ExecutionRecordPath) { [IO.File]::WriteAllText($ExecutionRecordPath, ($execution | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false)) }
        $process.Dispose()
        $stdoutFile.Dispose()
        $stderrFile.Dispose()
    }
}

try {
    $orphanProcessIds = [System.Collections.Generic.List[int]]::new()
    $selectedCompilers = @(
        @{ Name = 'managed'; File = $dotnetPath; Prefix = @($managedPath) },
        @{ Name = 'selfhost'; File = $selfhostPath; Prefix = @() })
    if ($PhaseCompilerSide) { $selectedCompilers = @($selectedCompilers | Where-Object Name -CEQ $PhaseCompilerSide) }
    foreach ($compiler in $selectedCompilers) {
        $name = $compiler.Name
        $compilerOutput = Join-Path $outputPath $name
        [void][IO.Directory]::CreateDirectory($compilerOutput)
        $executable = Join-Path $compilerOutput 'negative.exe'
        $llvm = "$executable.ll"
        $arguments = @($compiler.Prefix) + @('build') + $sourcePaths + @('-o', $executable,
            '--target', 'windows-x64', '--llvm', $llvmPath)
        if ($name -ceq 'selfhost') { $arguments += @('--stdlib', $stdlibPath, '--jobs', '1') }
        $arguments += @('-O1', '--keep-temps')
        $stdoutPath = Join-Path $outputPath "$name.stdout.txt"
        $stderrPath = Join-Path $outputPath "$name.stderr.txt"
        $executionPath = ''
        if ($phaseContexts.ContainsKey($name)) {
            $executionPath = Join-Path $outputPath "$name.compile.execution.json"
            $phaseInputs = Get-NativeExactPhaseCommandInputs $phaseContexts[$name] ($sourcePaths + @($expectedPath) + @(Get-ChildItem -LiteralPath $stdlibPath -Recurse -File -Filter '*.slg' | ForEach-Object FullName))
        }
        $run = Invoke-NegativeBuild -File $compiler.File -Arguments $arguments -Name $name `
            -StdoutPath $stdoutPath -StderrPath $stderrPath -OrphanProcessIds $orphanProcessIds -ExecutionRecordPath $executionPath
        $stderr = [IO.File]::ReadAllText($stderrPath)
        $generated = @(Get-ChildItem -LiteralPath $compilerOutput -Recurse -Force |
            ForEach-Object FullName)
        $check = [ordered]@{
            exitCode = $run.ExitCode
            nonzeroExit = $run.ExitCode -ne 0
            expectedInStderr = $stderr.Contains($diagnostic, [StringComparison]::Ordinal)
            noEmittedProducts = $generated.Count -eq 0
            generatedProducts = @($generated)
            outputDirectory = $compilerOutput
            stdoutPath = $stdoutPath
            stderrPath = $stderrPath
        }
        $record[$name] = $check
        Write-Result
        if (-not $check.nonzeroExit -or -not $check.expectedInStderr -or -not $check.noEmittedProducts) {
            throw "$name negative fixture failed: exit=$($check.exitCode), expectedInStderr=$($check.expectedInStderr), noEmittedProducts=$($check.noEmittedProducts)"
        }
        if ($phaseContexts.ContainsKey($name)) {
            $prefix = Get-NativeExactPhaseOutcomePrefix $phaseContexts[$name] $phaseCases[$name]
            [void](Write-NativeExactPhaseOutcome -Context $phaseContexts[$name] -Case $phaseCases[$name] -Stage compile -ProcessRecordPath $executionPath -OutputPath $prefix -InputHashesStart $phaseInputs)
        }
    }
    $record.inputFingerprintEnd = Get-InputFingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'Negative fixture inputs changed during verification' }
    $record.state = if ($PhaseCompilerSide) { 'phase-captured' } else { 'passed' }
    Write-Result
    foreach ($context in $phaseContexts.Values) {
        [void](Complete-NativeExactPhaseExecution $context)
    }
    if ($PhaseCompilerSide) { Write-Host "[compiler phase negative] CAPTURED $PhaseCompilerSide exact diagnostic; paired closure remains separate; $resultPath" }
    else { Write-Host "[compiler parity negative] PASS managed and selfhost expected diagnostic fragment; $resultPath" }
} catch {
    $record.orphanProcessIds = @($orphanProcessIds)
    $record.failureId = if ($orphanProcessIds.Count -gt 0) { 'NEGATIVE_PROCESS_ORPHANED' }
        elseif ($_.Exception.Message -match 'exceeded the configured verification limit') { 'NEGATIVE_PROCESS_TIMEOUT' }
        elseif ($_.Exception.Message -match '^NEGATIVE_LOG_DRAIN_TIMEOUT') { 'NEGATIVE_LOG_DRAIN_TIMEOUT' }
        elseif ($_.Exception.Message -match '^NEGATIVE_PROCESS_INSPECTION_FAILED') { 'NEGATIVE_PROCESS_INSPECTION_FAILED' }
        else { 'NEGATIVE_CHECK_FAILED' }
    $record.failure = $_.Exception.Message
    try {
        $record.inputFingerprintEnd = Get-InputFingerprint
        $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    } catch {
        $record.failure += "; end fingerprint failed: $($_.Exception.Message)"
    }
    $record.state = 'failed'
    Write-Result
    throw
}
