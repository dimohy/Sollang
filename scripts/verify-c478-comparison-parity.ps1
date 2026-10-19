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
$schemaPath = Join-Path $PSScriptRoot 'contracts/c478-comparison-parity-result.schema.json'
$negativeRunner = Join-Path $PSScriptRoot 'verify-compiler-parity-negative-fixture.ps1'
$negativeSchema = Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'
$closureScript = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$processScript = Join-Path $PSScriptRoot 'verification-process.ps1'
$fingerprintScript = Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'
$fixturePins = [ordered]@{
    control = @('scripts/probes/typed/c478-comparison-control.slg', '30FAEFCB633C6666305F6992BAFA55325B4BC79806298DD0993067CAE692E4A2', 'scripts/probes/typed/c478-comparison-control.stdout.txt', '4A3FCE12C50804E0EDED7A836BF5AB62DF7BC3543BD2708A922C3800A61AB1D5')
    boolEqualityRejected = @('scripts/probes/typed/c478-bool-equality-rejected.slg', '0FEE099E8F6F10CB553F39D9BFCA210E12CB7EFD58F405C46383B08AEB38B269', 'scripts/probes/typed/c478-bool-equality-rejected.stderr.contains.txt', 'F56472A9A3C8177D559C9197786607E4908C6C58B655263475A4F5C1E244A15B')
    textOrderingRejected = @('examples/regression/diagnostics/1328-text-ordering-requires-explicit-api.slg', '7E0819BAD130C18165CC16AD418BDF80C287C0F13992230DF1408E9CFA6C9AAE', 'examples/regression/diagnostics/1328-text-ordering-requires-explicit-api.stderr.contains.txt', 'A0B7EA1D3FB2E1166D428D25FEFDF7DF8AA16DEF9237A8B87ADE28014C635898')
    contextualWhenOverflowRejected = @('scripts/probes/typed/c478-contextual-when-u8-overflow-rejected.slg', '39F096408F2C1FA2419E19A1DF5F7A20BAD1D299EB371A7E6785E055A8578556', 'scripts/probes/typed/c478-contextual-when-u8-overflow-rejected.stderr.contains.txt', 'E424220B0090F748CB57F878D4FD630ACCDE9D0AE244DFE86B7014F549A936E5')
}
$stepNames = @('managedControl', 'selfhostControl', 'boolEqualityRejected', 'textOrderingRejected', 'contextualWhenOverflowRejected')

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
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "C478_REPARSE: $cursor" }
    }
}
function Assert-Fixtures {
    foreach ($fixture in $fixturePins.Values) {
        for ($index = 0; $index -lt 4; $index += 2) {
            $path = Resolve-Input $fixture[$index]
            Assert-NoReparse $path
            if ((Get-Sha $path) -cne $fixture[$index + 1]) { throw "C478_FIXTURE_PIN: $path" }
            if ((Get-Item -LiteralPath $path).Length -eq 0) { throw "C478_FIXTURE_EMPTY: $path" }
        }
    }
}
function New-ExclusiveDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "C478_PARENT_MISSING: $parent" }
    Assert-NoReparse $parent
    if (-not ('C478ComparisonDirectoryNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C478ComparisonDirectoryNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C478ComparisonDirectoryNative]::CreateDirectory($Path, [IntPtr]::Zero)) { throw "C478_OUTPUT_EXISTS_OR_CREATE_FAILED: $Path" }
    Assert-NoReparse $Path
}
function Write-AtomicResult([string]$Path, [string]$Json) {
    $temp = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    $backup = "$Path.backup-$PID-$([guid]::NewGuid().ToString('N'))"
    $replaced = $false
    try {
        [IO.File]::WriteAllText($temp, $Json, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path -PathType Leaf) { [IO.File]::Replace($temp, $Path, $backup); $replaced = $true }
        else { [IO.File]::Move($temp, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temp -PathType Leaf) { Remove-Item -LiteralPath $temp -Force }
        if ($replaced -and (Test-Path -LiteralPath $backup -PathType Leaf)) { Remove-Item -LiteralPath $backup -Force }
    }
}
function Get-LiveDescendants([int]$RootId) {
    $records = @(Get-CimInstance Win32_Process)
    $seen = [Collections.Generic.HashSet[int]]::new()
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $records) {
            $id = [int]$record.ProcessId
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
    try {
        if (-not $process.Start()) { throw "C478_SPAWN_FAILED: $Description" }
        $started = $true
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $waitFailure = $null
        try { Wait-VerificationProcess -Process $process -Description $Description -TimeoutMilliseconds $TimeoutMilliseconds }
        catch { $waitFailure = $_ }
        if (-not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) { $script:orphanIds.Add($process.Id); throw "C478_PROCESS_ORPHANED: root $($process.Id)" }
        }
        $descendants = @(Get-LiveDescendants $process.Id)
        if ($descendants.Count -gt 0) {
            foreach ($id in $descendants) { if (-not $script:orphanIds.Contains($id)) { $script:orphanIds.Add($id) } }
            throw "C478_PROCESS_ORPHANED: descendants $($descendants -join ',')"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "C478_LOG_DRAIN_TIMEOUT: $Description" }
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
function Assert-Result([object]$Record) {
    $json = $Record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) { throw 'C478_RESULT_SCHEMA: record rejected' }
    return $json
}
function Assert-OverflowDiagnostics([string]$ManagedText, [string]$SelfhostText) {
    if (-not $ManagedText.Contains('numeric literal 300 is out of range for UInt8', [StringComparison]::Ordinal) -or
        -not $SelfhostText.Contains('comparison operands must have the same numeric type', [StringComparison]::Ordinal)) {
        throw 'C478_OVERFLOW_DIAGNOSTIC: compiler-specific rejection differs'
    }
}
function Get-Fingerprint {
    $managedCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $managedPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $selfhostCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $selfhostPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'c478-comparison-parity-v1'; managedCommon = $managedCommon; selfhostCommon = $selfhostCommon
        timeoutMilliseconds = [string]$TimeoutMilliseconds
    }
    $inputs = @($PSCommandPath, $schemaPath, $negativeRunner, $negativeSchema, $closureScript, $processScript, $fingerprintScript, $dotnetPath, $pwshPath)
    foreach ($fixture in $fixturePins.Values) { $inputs += @((Resolve-Input $fixture[0]), (Resolve-Input $fixture[2])) }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $inputs
}

Assert-Fixtures
if ($SelfTest) {
    $steps = [ordered]@{
        managedControl = New-Step 'control' 'managed'
        selfhostControl = New-Step 'control' 'selfhost'
        boolEqualityRejected = New-Step 'boolEqualityRejected' 'pair'
        textOrderingRejected = New-Step 'textOrderingRejected' 'pair'
        contextualWhenOverflowRejected = New-Step 'contextualWhenOverflowRejected' 'pair'
    }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c478-comparison-parity'; state = 'running'; total = 5; completed = 0; passed = 0
        managedCompilerPath = 'managed'; managedCompilerSha256 = ('A' * 64)
        selfhostCompilerPath = 'selfhost'; selfhostCompilerSha256 = ('B' * 64)
        inputFingerprintStart = ('C' * 64); inputFingerprintEnd = $null; inputsStable = $false
        processObservationScope = 'bounded-supervised-process-tree-and-post-exit-CIM-parent-snapshot;exited-intermediate-descendants-not-proven'
        steps = $steps; orphanProcessIds = @(); failureId = $null; failure = $null
    }
    $null = Assert-Result $sample
    foreach ($name in $stepNames) {
        $step = $sample.steps[$name]
        $step.state = 'passed'; $step.caseDirectory = $name
        if ($step.compiler -ceq 'pair') { $step.nestedResultPath = "$name/result.json"; $step.validationCount = 1; $step.semanticCount = 1; $step.irCount = 0 }
        else { $step.buildExitCode = 0; $step.closureExitCode = 0; $step.llvmAsExitCode = 0; $step.runExitCode = 0 }
    }
    $sample.state = 'passed'; $sample.completed = 5; $sample.passed = 5
    $sample.inputFingerprintEnd = ('C' * 64); $sample.inputsStable = $true
    $null = Assert-Result $sample
    $sample.steps.selfhostControl.closureExitCode = $null
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) { throw 'C478_SELFTEST: incomplete positive accepted' }
    $sample.steps.selfhostControl.closureExitCode = 0
    $sample.steps.boolEqualityRejected.fixtureId = 'textOrderingRejected'
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) { throw 'C478_SELFTEST: swapped negative accepted' }
    $sample.steps.boolEqualityRejected.fixtureId = 'boolEqualityRejected'
    $sample.steps.textOrderingRejected.semanticCount = 0
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) { throw 'C478_SELFTEST: IR-only negative accepted' }
    Assert-OverflowDiagnostics 'numeric literal 300 is out of range for UInt8' 'comparison operands must have the same numeric type'
    try {
        Assert-OverflowDiagnostics 'numeric literal 300 is out of range for UInt8' 'unrelated semantic error'
        throw 'C478_SELFTEST: unrelated overflow diagnostic accepted'
    } catch {
        if ($_.Exception.Message -cne 'C478_OVERFLOW_DIAGNOSTIC: compiler-specific rejection differs') { throw }
    }
    Write-Host '[c478 comparison parity] self-test passed; no compiler launched'
    return
}

if (-not $IsWindows) { throw 'C478_PLATFORM: windows-x64 only' }
$managedPath = Resolve-Input $ManagedCompiler
$selfhostPath = Resolve-Input $SelfhostCompiler
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$pwshPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$llvmAsPath = Join-Path $llvmPath 'bin/llvm-as.exe'
foreach ($path in @($managedPath, $selfhostPath, $llvmPath, $stdlibPath, $dotnetPath, $pwshPath, $llvmAsPath, $schemaPath, $negativeRunner, $negativeSchema, $closureScript, $processScript, $fingerprintScript)) {
    Assert-NoReparse $path
    if (-not (Test-Path -LiteralPath $path)) { throw "C478_INPUT_MISSING: $path" }
}
if ([IO.Path]::GetExtension($managedPath) -cne '.dll' -or [IO.Path]::GetExtension($selfhostPath) -cne '.exe') { throw 'C478_COMPILER_TYPE: expected managed .dll and selfhost .exe' }
if ($managedPath -ceq $selfhostPath) { throw 'C478_COMPILER_IDENTITY: compilers must be distinct' }
if ($ManagedCompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $managedPath) -cne $ManagedCompilerSha256.ToUpperInvariant()) { throw 'C478_MANAGED_SHA: compiler identity differs' }
if ($SelfhostCompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $selfhostPath) -cne $SelfhostCompilerSha256.ToUpperInvariant()) { throw 'C478_SELFHOST_SHA: compiler identity differs' }
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "C478_OUTPUT_SCOPE: $outputPath" }
Assert-NoReparse $outputPath
if (Test-Path -LiteralPath $outputPath) { throw "C478_OUTPUT_EXISTS: $outputPath" }
$fingerprintStart = Get-Fingerprint
foreach ($name in @('boolEqualityRejected', 'textOrderingRejected', 'contextualWhenOverflowRejected')) {
    $fixture = $fixturePins[$name]
    $preflight = & $negativeRunner -ManagedCompiler $managedPath -SelfhostCompiler $selfhostPath -ManagedCompilerSha256 $ManagedCompilerSha256 -SelfhostCompilerSha256 $SelfhostCompilerSha256 -Source (Resolve-Input $fixture[0]) -Expected (Resolve-Input $fixture[2]) -OutputDirectory (Join-Path $outputPath $name) -RepositoryRoot $root -LlvmRoot $llvmPath -StdlibRoot $stdlibPath -TimeoutMilliseconds $TimeoutMilliseconds -ValidateInputsOnly | ConvertFrom-Json
    if ($preflight.status -cne 'preflight-passed') { throw "C478_NEGATIVE_PREFLIGHT: $name" }
}
if ((Get-Fingerprint) -cne $fingerprintStart) { throw 'C478_INPUT_DRIFT: preflight' }
if ($ValidateInputsOnly) {
    [pscustomobject]@{ status = 'preflight-passed'; total = 5; completed = 0; inputFingerprint = $fingerprintStart; managedCompilerSha256 = Get-Sha $managedPath; selfhostCompilerSha256 = Get-Sha $selfhostPath } | ConvertTo-Json -Compress
    return
}

New-ExclusiveDirectory $outputPath
$script:orphanIds = [Collections.Generic.List[int]]::new()
$steps = [ordered]@{
    managedControl = New-Step 'control' 'managed'
    selfhostControl = New-Step 'control' 'selfhost'
    boolEqualityRejected = New-Step 'boolEqualityRejected' 'pair'
    textOrderingRejected = New-Step 'textOrderingRejected' 'pair'
    contextualWhenOverflowRejected = New-Step 'contextualWhenOverflowRejected' 'pair'
}
$record = [ordered]@{
    schemaVersion = 1; gate = 'c478-comparison-parity'; state = 'running'; total = 5; completed = 0; passed = 0
    managedCompilerPath = $managedPath; managedCompilerSha256 = Get-Sha $managedPath
    selfhostCompilerPath = $selfhostPath; selfhostCompilerSha256 = Get-Sha $selfhostPath
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null; inputsStable = $false
    processObservationScope = 'bounded-supervised-process-tree-and-post-exit-CIM-parent-snapshot;exited-intermediate-descendants-not-proven'
    steps = $steps; orphanProcessIds = @(); failureId = $null; failure = $null
}
$resultPath = Join-Path $outputPath 'result.json'
function Write-Result { Write-AtomicResult $resultPath (Assert-Result $record) }
Write-Result
$active = $null
$activeCounted = $false
try {
    foreach ($name in $stepNames) {
        if ((Get-Fingerprint) -cne $fingerprintStart) { throw 'C478_INPUT_DRIFT: before step' }
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
            if ($validateExit -ne 0 -or (Get-Item -LiteralPath $validateErr).Length -ne 0 -or $validateText -cnotmatch '^checked diagnostics = ([1-9][0-9]*)\r?\n$') { throw "C478_VALIDATE: $name" }
            $step.validationCount = [int]$Matches[1]
            $countsExit = Invoke-Logged $selfhostPath @('diagnostic-counts', $source) $validationDir "$name diagnostic counts" $countsOut $countsErr
            $countsText = [IO.File]::ReadAllText($countsOut)
            $countsDetail = [IO.File]::ReadAllText($countsErr)
            if ($countsExit -ne 0 -or $countsText -cnotmatch '^checked diagnostics = ([1-9][0-9]*)\r?\n$') { throw "C478_DIAGNOSTIC_COUNTS: $name" }
            $totalCount = [int]$Matches[1]
            if ($countsDetail -cnotmatch '^semantic diagnostics = ([1-9][0-9]*)\r?\nir diagnostics = ([0-9]+)\r?\n$') { throw "C478_DIAGNOSTIC_DETAIL: $name" }
            $step.semanticCount = [int]$Matches[1]
            $step.irCount = [int]$Matches[2]
            if ($totalCount -ne $step.validationCount -or $step.semanticCount -ne $totalCount -or $step.irCount -ne 0) { throw "C478_PRE_LLVM_PARITY: $name" }
            $step.nestedResultPath = Join-Path $caseDir 'result.json'
            & $negativeRunner -ManagedCompiler $managedPath -SelfhostCompiler $selfhostPath -ManagedCompilerSha256 $ManagedCompilerSha256 -SelfhostCompilerSha256 $SelfhostCompilerSha256 -Source $source -Expected $expected -OutputDirectory $caseDir -RepositoryRoot $root -LlvmRoot $llvmPath -StdlibRoot $stdlibPath -TimeoutMilliseconds $TimeoutMilliseconds
            $nestedText = [IO.File]::ReadAllText($step.nestedResultPath)
            if (-not (Test-Json -Json $nestedText -SchemaFile $negativeSchema)) { throw "C478_NEGATIVE_SCHEMA: $name" }
            $nested = $nestedText | ConvertFrom-Json
            if ($nested.state -cne 'passed' -or -not $nested.inputsStable -or @($nested.orphanProcessIds).Count -ne 0) { throw "C478_NEGATIVE_PARITY: $name" }
            if ($name -ceq 'contextualWhenOverflowRejected') {
                Assert-OverflowDiagnostics ([IO.File]::ReadAllText($nested.logs.managedStderr)) ([IO.File]::ReadAllText($nested.logs.selfhostStderr))
            }
        } else {
            New-ExclusiveDirectory $caseDir
            $managed = $step.compiler -ceq 'managed'
            $product = Join-Path $caseDir 'probe.exe'
            $llvmFile = if ($managed) { Join-Path $caseDir 'probe.ll' } else { "$product.ll" }
            $bitcode = Join-Path $caseDir 'probe.bc'
            $buildFile = if ($managed) { $dotnetPath } else { $selfhostPath }
            [string[]]$arguments = @()
            if ($managed) { $arguments += $managedPath }
            $arguments += @('build', $source, '-o', $product, '--target', 'windows-x64', '--llvm', $llvmPath)
            if (-not $managed) { $arguments += @('--stdlib', $stdlibPath, '--jobs', '1') }
            $arguments += @('-O1', '--keep-temps')
            $buildOut = Join-Path $caseDir 'build.stdout.txt'
            $buildErr = Join-Path $caseDir 'build.stderr.txt'
            $step.buildExitCode = Invoke-Logged $buildFile $arguments $caseDir "$name build" $buildOut $buildErr
            $buildText = [IO.File]::ReadAllText($buildOut) + [IO.File]::ReadAllText($buildErr)
            if ($step.buildExitCode -ne 0 -or $buildText -match '(?im)^\s*(?:warning(?:\s|:)|note(?:\s|:)|sollang:\s*(?:warning|note)(?:\s|:))') { throw "C478_BUILD: $name exit=$($step.buildExitCode) or warning/note" }
            foreach ($path in @($product, $llvmFile)) {
                if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw "C478_PRODUCT: $name $path" }
            }
            $step.closureExitCode = Invoke-Logged $pwshPath @('-NoProfile', '-File', $closureScript, '-LlvmPath', $llvmFile) $caseDir "$name direct-call closure" (Join-Path $caseDir 'closure.stdout.txt') (Join-Path $caseDir 'closure.stderr.txt')
            if ($step.closureExitCode -ne 0) { throw "C478_DIRECT_CALL_CLOSURE: $name" }
            $step.llvmAsExitCode = Invoke-Logged $llvmAsPath @($llvmFile, '-o', $bitcode) $caseDir "$name llvm-as" (Join-Path $caseDir 'llvm-as.stdout.txt') (Join-Path $caseDir 'llvm-as.stderr.txt')
            if ($step.llvmAsExitCode -ne 0 -or -not (Test-Path -LiteralPath $bitcode -PathType Leaf) -or (Get-Item -LiteralPath $bitcode).Length -eq 0) { throw "C478_LLVM_AS: $name" }
            $runOut = Join-Path $caseDir 'run.stdout.txt'
            $runErr = Join-Path $caseDir 'run.stderr.txt'
            $step.runExitCode = Invoke-Logged $product @() $caseDir "$name run" $runOut $runErr
            if ($step.runExitCode -ne 0 -or (Get-Item -LiteralPath $runErr).Length -ne 0) { throw "C478_RUN: $name" }
            if (-not [Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($runOut), [IO.File]::ReadAllBytes($expected))) { throw "C478_STDOUT: $name" }
        }
        if ((Get-Fingerprint) -cne $fingerprintStart) { throw 'C478_INPUT_DRIFT: after step' }
        $step.state = 'passed'
        $record.completed++
        $record.passed++
        $activeCounted = $true
        Write-Result
        $active = $null
    }
    $record.inputFingerprintEnd = Get-Fingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C478_INPUT_DRIFT: final' }
    $record.state = 'passed'
    Write-Result
    Write-Host "[c478 comparison parity] PASS 5/5 checks; $resultPath"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $active) {
        $step = $record.steps[$active]
        $step.state = 'failed'; $step.failure = $message
        if ($activeCounted) { $record.passed-- } else { $record.completed++ }
        if ($step.compiler -ceq 'pair' -and $null -ne $step.nestedResultPath -and (Test-Path -LiteralPath $step.nestedResultPath -PathType Leaf)) {
            try {
                $nested = [IO.File]::ReadAllText($step.nestedResultPath) | ConvertFrom-Json
                foreach ($id in @($nested.orphanProcessIds)) { if ($id -gt 0 -and -not $script:orphanIds.Contains([int]$id)) { $script:orphanIds.Add([int]$id) } }
            } catch { $message += "; nested orphan inspection failed: $($_.Exception.Message)" }
        }
    }
    $record.orphanProcessIds = @($script:orphanIds)
    $record.failureId = if ($message -match '^C478_[A-Z_]+:') { ($message -split ':')[0] } elseif ($message -match 'exceeded the configured verification limit') { 'C478_PROCESS_TIMEOUT' } else { 'C478_STEP_FAILED' }
    $record.failure = $message
    try { $record.inputFingerprintEnd = Get-Fingerprint; $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd }
    catch { $record.failure += "; final fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'
    Write-Result
    throw
}
