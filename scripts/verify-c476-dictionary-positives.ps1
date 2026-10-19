[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$Compiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$CompilerSha256,
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

$manifestPath = Join-Path $PSScriptRoot 'contracts/c476-dictionary-positives.json'
$manifestSchema = Join-Path $PSScriptRoot 'contracts/c476-dictionary-positives.schema.json'
$resultSchema = Join-Path $PSScriptRoot 'contracts/c476-dictionary-positives-result.schema.json'
$fixedIds = @(
    '25-arrays-dictionaries', '35-mutable-int-dictionary-parameters',
    '71-user-defined-dictionary-keys', '857-dictionary-put-if-absent',
    'c476-contextual-key-put-field-order', 'c476-user-put-method-precedence',
    'c476-uint8-integer-key-control-hash', 'c476-nominal-key-put-if-absent',
    'c476-nominal-key-index-assignment', 'c476-bounded-nominal-key-update'
)
$fixedManifestSha256 = '85D9E94C8DA2361FBE7C0F2A923E484CE93E5476C65D5534C220CA26AE375B56'
# Independent of the editable manifest and of the run-scoped fingerprint.
# A coordinated fixture/expectation edit must be reviewed before this gate changes.
$fixedFixtureSha256 = @{
    '25-arrays-dictionaries' = @('8EEAC4DE4DDE977FC6A2D844CD14FAD7E3DEB8F5C6C5D2F97DE2D3AE94BDBC7F', 'A9C25F4EB66340A19B3961EF8F993FE009E9CB8F54273084A036420E0195CCDD')
    '35-mutable-int-dictionary-parameters' = @('9CFC05F091EFFC52D73092DB79142859265A44D42EFF32BF4E57A5776B0CF32A', 'C7C12AE31482B18DF3A7818A5468B33471AE1C15F9BF43F6684A1A8735D82379')
    '71-user-defined-dictionary-keys' = @('F5D9949789A5DA05554FEC6927E0423194A08919F3404CBB802AC4FD8562B28D', '3B2043E8E4E7A82532350B2E61780C5F1B5BA2C247286B603D36D4F29DE97054')
    '857-dictionary-put-if-absent' = @('A5C0C2AA1729E3DA0C3A32F93699576C78989E6771EF0666D1012E2C57FD4E1A', 'E2472B7CC9D5F101A7C4A043A88A7AD071D1E79448375A8E41250AFDD4200ADC')
    'c476-contextual-key-put-field-order' = @('121CF957D8CBC31E1F74401193C146A4F937CE8C1BBC785354B1B84AB82FE9B0', '9123B2D5CD84BCEA403A1473C5071D2D610228899A5CAC5C71232428644F0035')
    'c476-user-put-method-precedence' = @('BCAD02E58CB46BB793A3F0FDA7EAFD717472F63E4C0C6F13D90D88960AD2FFA4', '084C799CD551DD1D8D5C5F9A5D593B2E931F5E36122EE5C793C1D08A19839CC0')
    'c476-uint8-integer-key-control-hash' = @('36EBE856BBEAEE922B36E7E243BAAC74F0D27438E1660B84396A6BDABB47AB07', '8D592F743725E1DFF8955B6C3C01457DAD8428ECC217D36B64E175CFDA6C63F7')
    'c476-nominal-key-put-if-absent' = @('CAAF148681F8689A88EF02893FC17DE92AFAE8BC13EB6147AD59A317E6CD75DC', '5C93F3E3B40861A54EAF29F57A0B7B99CCA417B034C6114C00715E9928DD2C4A')
    'c476-nominal-key-index-assignment' = @('C1ECEBDB2204FD5764CC28F2B7D509027D4AEAB41F389520AD965ABE2E63E5F8', '5EA364AFF60D715454F43CEAD52770A8C07179F0346C958C54213D7699762D8E')
    'c476-bounded-nominal-key-update' = @('120DD37431788ABF7A2318189AE0D6A7D30C94C65E70AE0100425807877A7E1C', '05CE880FDACE507A82E7B1EEC284A7DAC27AF58F593DAFB802D8A552433514B0')
}

function Assert-C476PinnedTriplet([string]$ManifestFile, [string]$SourceFile,
        [string]$ExpectedFile, [string]$Id) {
    if (-not $fixedFixtureSha256.ContainsKey($Id) -or
        (Get-C476Sha $ManifestFile) -cne $fixedManifestSha256 -or
        (Get-C476Sha $SourceFile) -cne $fixedFixtureSha256[$Id][0] -or
        (Get-C476Sha $ExpectedFile) -cne $fixedFixtureSha256[$Id][1]) {
        throw "C476_PINNED_INPUT_MISMATCH: $Id"
    }
}

function Write-C476AtomicText([string]$Path, [string]$Content) {
    $temporary = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText($temporary, $Content, [Text.UTF8Encoding]::new($false))
        # Move with overwrite accepts an existing destination without requiring
        # a nonempty backup path on Windows.
        [IO.File]::Move($temporary, $Path, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Assert-C476Manifest {
    if ((Get-C476Sha $manifestPath) -cne $fixedManifestSha256) {
        throw 'C476_PINNED_INPUT_MISMATCH: manifest'
    }
    $raw = [IO.File]::ReadAllText($manifestPath)
    if (-not (Test-Json -Json $raw -SchemaFile $manifestSchema)) {
        throw 'C476_MANIFEST_INVALID: schema validation failed'
    }
    $manifest = $raw | ConvertFrom-Json
    for ($i = 0; $i -lt $fixedIds.Count; $i++) {
        $case = $manifest.cases[$i]
        if ($case.id -cne $fixedIds[$i]) {
            throw "C476_MANIFEST_INVALID: case order or identity changed at $i"
        }
        $stem = [IO.Path]::GetFileNameWithoutExtension($case.source)
        if ($stem -cne $case.id -or
            [IO.Path]::GetFileName($case.expected) -cne "$($case.id).stdout.txt") {
            throw "C476_MANIFEST_INVALID: source/expected stem mismatch: $($case.id)"
        }
        $expectedSource = if ($i -lt 4) { "examples/regression/$($case.id).slg" }
            else { "scripts/probes/dictionary/$($case.id).slg" }
        $expectedOutput = if ($i -lt 4) { "examples/regression/expected/$($case.id).stdout.txt" }
            else { "scripts/probes/dictionary/$($case.id).stdout.txt" }
        if ($case.source -cne $expectedSource -or $case.expected -cne $expectedOutput) {
            throw "C476_MANIFEST_INVALID: fixture path changed: $($case.id)"
        }
    }
    return $manifest
}

function Get-C476Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-C476NoReparse([string]$Path) {
    $cursor = [IO.Path]::GetPathRoot($Path)
    foreach ($segment in ($Path.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $segment) { continue }
        $cursor = Join-Path $cursor $segment
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
    if (-not ('C476PositiveDirectoryNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C476PositiveDirectoryNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C476PositiveDirectoryNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "C476_OUTPUT_EXISTS_OR_CREATE_FAILED: exclusive CreateDirectoryW failed ($errorCode): $Path"
    }
    Assert-C476NoReparse $Path
}

function Assert-C476EqualBytes([string]$Actual, [string]$Expected, [string]$Description) {
    $actualBytes = [IO.File]::ReadAllBytes($Actual)
    $expectedBytes = [IO.File]::ReadAllBytes($Expected)
    if (-not [Linq.Enumerable]::SequenceEqual($actualBytes, $expectedBytes)) {
        throw "C476_OUTPUT_MISMATCH: $Description actual=$($actualBytes.Length) expected=$($expectedBytes.Length)"
    }
}

function Assert-C476Empty([string]$Path, [string]$Description) {
    if ((Get-Item -LiteralPath $Path).Length -ne 0) {
        throw "C476_UNEXPECTED_STDERR: $Description wrote nonempty $Path"
    }
}

function Assert-C476Products([string]$Directory, [string[]]$Names) {
    $actual = @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name | Sort-Object -CaseSensitive)
    $expected = @($Names | Sort-Object -CaseSensitive)
    if ($actual.Count -ne $expected.Count) {
        throw "C476_PRODUCTS_MISMATCH: actual=$($actual -join ',') expected=$($expected -join ',')"
    }
    for ($i = 0; $i -lt $actual.Count; $i++) {
        if ($actual[$i] -cne $expected[$i]) {
            throw "C476_PRODUCTS_MISMATCH: actual=$($actual -join ',') expected=$($expected -join ',')"
        }
    }
}

# Track identities, not bare PIDs. A PID reused after its original child exits
# must never be treated as an owned descendant or used as a kill target.
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

$script:c476OrphanProcessIds = [Collections.Generic.HashSet[int]]::new()
$script:c476ObservedRootId = 0

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
    $stdout = [IO.File]::Create($StdoutPath)
    $stderr = [IO.File]::Create($StderrPath)
    $started = $false
    $known = [Collections.Generic.Dictionary[int, long]]::new()
    try {
        if (-not $process.Start()) { throw "C476_PROCESS_START_FAILED: $Description" }
        $started = $true
        $script:c476ObservedRootId = $process.Id
        $rootStartTicks = $process.StartTime.ToUniversalTime().Ticks
        $known.Add($process.Id, $rootStartTicks)
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(1000)) {
            $nowTicks = [DateTimeOffset]::UtcNow.UtcTicks
            Update-C476Descendants $known @(Get-C476ProcessSnapshot) $nowTicks
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                throw "C476_PROCESS_TIMEOUT: $Description exceeded $TimeoutMilliseconds ms"
            }
        }
        $rootExitTicks = $process.ExitTime.ToUniversalTime().Ticks
        $lastSnapshot = @(Get-C476ProcessSnapshot)
        Update-C476Descendants $known $lastSnapshot $rootExitTicks
        $liveDescendants = @(Get-C476LiveDescendantIds $known $lastSnapshot $process.Id)
        if ($liveDescendants.Count -gt 0) {
            foreach ($id in $liveDescendants) { [void]$script:c476OrphanProcessIds.Add([int]$id) }
            throw "C476_PROCESS_ORPHANED: $Description left verified descendants $($liveDescendants -join ','); no descendant was terminated"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "C476_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult()
        $stdout.Flush(); $stderr.Flush()
        return $process.ExitCode
    } finally {
        if ($started -and -not $process.WaitForExit(0)) {
            # The held process handle identifies the root. Never kill a child
            # selected only by a CIM ParentProcessId or an old numeric PID.
            try { $process.Kill() } catch { }
            if (-not $process.WaitForExit(5000)) {
                [void]$script:c476OrphanProcessIds.Add($process.Id)
                Write-Warning "C476_PROCESS_ORPHANED: $Description root pid=$($process.Id)"
            }
            try {
                $lastSnapshot = @(Get-C476ProcessSnapshot)
                Update-C476Descendants $known $lastSnapshot ([DateTimeOffset]::UtcNow.UtcTicks)
                foreach ($id in @(Get-C476LiveDescendantIds $known $lastSnapshot $process.Id)) {
                    [void]$script:c476OrphanProcessIds.Add([int]$id)
                }
            } catch { }
        }
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}

$manifest = Assert-C476Manifest
if ($SelfTest) {
    $emptyFile = [IO.Path]::GetTempFileName()
    $oneFile = [IO.Path]::GetTempFileName()
    $testManifest = [IO.Path]::GetTempFileName()
    $testSource = [IO.Path]::GetTempFileName()
    $testExpected = [IO.Path]::GetTempFileName()
    $testResult = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllBytes($emptyFile, [byte[]]@())
        [IO.File]::WriteAllBytes($oneFile, [byte[]]@(1))
        Assert-C476EqualBytes $emptyFile $emptyFile 'equal'
        $mismatchRejected = $false
        try { Assert-C476EqualBytes $emptyFile $oneFile 'different' } catch { $mismatchRejected = $true }
        if (-not $mismatchRejected) { throw 'C476 self-test accepted unequal output' }
        $record = [ordered]@{
            schemaVersion = 1; gate = 'c476-dictionary-positives'; state = 'running'
            total = 10; completed = 0; passed = 0; compilerPath = 'compiler.exe'
            compilerSha256 = ('A' * 64); inputFingerprintStart = ('B' * 64)
            inputFingerprintEnd = $null; inputsStable = $false; orphanProcessIds = @(); cases = @()
            failureId = $null; failure = $null
        }
        if (-not (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $resultSchema)) {
            throw 'C476 self-test schema rejected a running result'
        }
        $record.state = 'passed'
        if (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $resultSchema -ErrorAction SilentlyContinue) {
            throw 'C476 self-test schema accepted incomplete success'
        }
        $rootTicks = [datetime]::UtcNow.Ticks
        $script:c476ObservedRootId = 100
        $known = [Collections.Generic.Dictionary[int, long]]::new()
        $known.Add(100, $rootTicks)
        $snapshot = @(
            [pscustomobject]@{ id = 101; parentId = 100; startedTicks = $rootTicks + 1 },
            [pscustomobject]@{ id = 102; parentId = 101; startedTicks = $rootTicks + 2 },
            [pscustomobject]@{ id = 103; parentId = 100; startedTicks = $rootTicks - 1 },
            [pscustomobject]@{ id = 200; parentId = 1; startedTicks = $rootTicks + 1 }
        )
        Update-C476Descendants $known $snapshot ($rootTicks + 3)
        $live = @(Get-C476LiveDescendantIds $known $snapshot 100)
        if ($live.Count -ne 2 -or $live[0] -ne 101 -or $live[1] -ne 102) {
            throw 'C476 self-test did not isolate live descendants by identity'
        }
        $reused = @([pscustomobject]@{ id = 101; parentId = 100; startedTicks = $rootTicks + 50 })
        if (@(Get-C476LiveDescendantIds $known $reused 100).Count -ne 0) {
            throw 'C476 self-test attributed a reused PID to an old descendant'
        }
        $record.inputFingerprintEnd = ('B' * 64)
        $record.inputsStable = $true
        $record.completed = 10; $record.passed = 10
        $goodCase = [ordered]@{
            id = 'case'; source = 'source'; sourceSha256 = ('A' * 64)
            expected = 'expected'; expectedSha256 = ('B' * 64)
            state = 'passed'; buildExitCode = 0; llvmAsExitCode = 0; runExitCode = 0
            buildStdoutPath = 'build-out'; buildStderrPath = 'build-err'
            runStdoutPath = 'run-out'; runStderrPath = 'run-err'
            exePath = 'exe'; llvmPath = 'll'; bitcodePath = 'bc'; failure = $null
        }
        $record.cases = @($goodCase) * 10
        if (-not (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $resultSchema)) {
            throw 'C476 self-test schema rejected complete success'
        }
        $record.orphanProcessIds = @(101)
        if (Test-Json -Json ($record | ConvertTo-Json -Depth 8) -SchemaFile $resultSchema -ErrorAction SilentlyContinue) {
            throw 'C476 self-test schema accepted orphaned success'
        }
        $testId = 'c476-contextual-key-put-field-order'
        $originalSource = Join-Path $PSScriptRoot "probes/dictionary/$testId.slg"
        $originalExpected = Join-Path $PSScriptRoot "probes/dictionary/$testId.stdout.txt"
        [IO.File]::WriteAllBytes($testManifest, [IO.File]::ReadAllBytes($manifestPath))
        [IO.File]::WriteAllBytes($testSource, [IO.File]::ReadAllBytes($originalSource))
        [IO.File]::WriteAllBytes($testExpected, [IO.File]::ReadAllBytes($originalExpected))
        Assert-C476PinnedTriplet $testManifest $testSource $testExpected $testId
        [IO.File]::AppendAllText($testManifest, "`n ") # Still valid JSON.
        [IO.File]::AppendAllText($testSource, "`n# coordinated mutation")
        [IO.File]::AppendAllText($testExpected, "`ncoordinated mutation")
        $mutationRejected = $false
        try { Assert-C476PinnedTriplet $testManifest $testSource $testExpected $testId }
        catch { $mutationRejected = $_.Exception.Message -match '^C476_PINNED_INPUT_MISMATCH:' }
        if (-not $mutationRejected) { throw 'C476 self-test accepted simultaneous manifest/source/expected mutation' }
        [IO.File]::WriteAllBytes($testManifest, [IO.File]::ReadAllBytes($manifestPath))
        $mutationRejected = $false
        try { Assert-C476PinnedTriplet $testManifest $testSource $testExpected $testId }
        catch { $mutationRejected = $_.Exception.Message -match '^C476_PINNED_INPUT_MISMATCH:' }
        if (-not $mutationRejected) { throw 'C476 self-test accepted changed source and expectation under the original manifest' }
        [IO.File]::WriteAllBytes($testSource, [IO.File]::ReadAllBytes($originalSource))
        [IO.File]::WriteAllBytes($testExpected, [IO.File]::ReadAllBytes($originalExpected))
        [IO.File]::AppendAllText($testManifest, "`n ")
        $mutationRejected = $false
        try { Assert-C476PinnedTriplet $testManifest $testSource $testExpected $testId }
        catch { $mutationRejected = $_.Exception.Message -match '^C476_PINNED_INPUT_MISMATCH:' }
        if (-not $mutationRejected) { throw 'C476 self-test accepted a valid-JSON manifest-only mutation' }
        Write-C476AtomicText $testResult 'first'
        Write-C476AtomicText $testResult 'second'
        if ([IO.File]::ReadAllText($testResult) -cne 'second') {
            throw 'C476 self-test failed to replace an existing result file'
        }
        Write-Host '[C476 positives self-test] PASS 10-case manifest, pinned SHA mutations, byte equality, and fail-closed result state; no compiler executed.'
    } finally {
        Remove-Item -LiteralPath $emptyFile, $oneFile, $testManifest, $testSource, $testExpected, $testResult -Force
    }
    return
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-C476Path([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}
$compilerPath = Resolve-C476Path $Compiler
$llvmPath = Resolve-C476Path $LlvmRoot
$stdlibPath = Resolve-C476Path $StdlibRoot
$outputPath = Resolve-C476Path $OutputDirectory
$scratchPath = Resolve-C476Path 'artifacts/scratch'
if (-not $outputPath.StartsWith($scratchPath + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "C476_OUTPUT_SCOPE: OutputDirectory must be below $scratchPath"
}
if (Test-Path -LiteralPath $outputPath) { throw "C476_OUTPUT_EXISTS: $outputPath" }
foreach ($path in @($compilerPath, $llvmPath, $stdlibPath, $outputPath, $manifestPath, $manifestSchema, $resultSchema)) {
    Assert-C476NoReparse $path
}
if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf) -or
    [IO.Path]::GetExtension($compilerPath) -cne '.exe') { throw 'C476_COMPILER_INVALID: Windows selfhost exe required' }
if ($CompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or
    (Get-C476Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) {
    throw 'C476_COMPILER_SHA_MISMATCH: current compiler differs from requested SHA'
}
$llvmAs = Join-Path $llvmPath 'bin/llvm-as.exe'
$clang = Join-Path $llvmPath 'bin/clang.exe'
foreach ($path in @($llvmAs, $clang)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C476_TOOL_MISSING: $path" }
}
if (-not (Test-Path -LiteralPath $stdlibPath -PathType Container)) { throw "C476_STDLIB_MISSING: $stdlibPath" }

$cases = @($manifest.cases | ForEach-Object {
    $source = Resolve-C476Path $_.source
    $expected = Resolve-C476Path $_.expected
    if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or
        -not (Test-Path -LiteralPath $expected -PathType Leaf)) {
        throw "C476_FIXTURE_MISSING: $($_.id)"
    }
    [pscustomobject]@{
        id = $_.id; source = $source; expected = $expected
        sourceSha256 = Get-C476Sha $source; expectedSha256 = Get-C476Sha $expected
    }
})

function Assert-C476Snapshots {
    if ((Get-C476Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) {
        throw 'C476_INPUT_DRIFT: compiler SHA changed'
    }
    foreach ($case in $cases) {
        Assert-C476PinnedTriplet $manifestPath $case.source $case.expected $case.id
        if ($case.sourceSha256 -cne $fixedFixtureSha256[$case.id][0] -or
            $case.expectedSha256 -cne $fixedFixtureSha256[$case.id][1]) {
            throw "C476_INPUT_DRIFT: fixture snapshot changed: $($case.id)"
        }
    }
}

function Get-C476Fingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'c476-dictionary-positives-v1'; common = $common
        timeoutMilliseconds = [string]$TimeoutMilliseconds
    }
    $inputs = @($PSCommandPath, $manifestPath, $manifestSchema, $resultSchema)
    foreach ($case in $cases) { $inputs += @($case.source, $case.expected) }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $inputs
}
$fingerprintStart = Get-C476Fingerprint
Assert-C476Snapshots
if ((Get-C476Fingerprint) -cne $fingerprintStart) { throw 'C476_INPUT_DRIFT: preflight changed' }
if ($ValidateInputsOnly) {
    [pscustomobject]@{
        state = 'preflight-passed'; total = $cases.Count; compilerSha256 = $CompilerSha256.ToUpperInvariant()
        inputFingerprint = $fingerprintStart; cases = $cases
    } | ConvertTo-Json -Depth 5
    return
}

New-C476ExclusiveDirectory $outputPath
$resultPath = Join-Path $outputPath 'result.json'
$record = [ordered]@{
    schemaVersion = 1; gate = 'c476-dictionary-positives'; state = 'running'
    total = $cases.Count; completed = 0; passed = 0; compilerPath = $compilerPath
    compilerSha256 = $CompilerSha256.ToUpperInvariant(); inputFingerprintStart = $fingerprintStart
    inputFingerprintEnd = $null; inputsStable = $false; orphanProcessIds = @(); cases = @()
    failureId = $null; failure = $null
}
function Write-C476Result {
    $json = $record | ConvertTo-Json -Depth 10
    if (-not (Test-Json -Json $json -SchemaFile $resultSchema)) { throw 'C476_RESULT_SCHEMA_INVALID' }
    Write-C476AtomicText $resultPath $json
}
Write-C476Result
$active = $null
try {
    foreach ($case in $cases) {
        Assert-C476Snapshots
        if ((Get-C476Fingerprint) -cne $fingerprintStart) { throw 'C476_INPUT_DRIFT: before case' }
        $caseDirectory = Join-Path $outputPath $case.id
        $artifactDirectory = Join-Path $caseDirectory 'artifacts'
        New-C476ExclusiveDirectory $caseDirectory
        New-C476ExclusiveDirectory $artifactDirectory
        $exe = Join-Path $artifactDirectory 'probe.exe'
        $ll = "$exe.ll"
        $bc = "$exe.bc"
        $active = [ordered]@{
            id = $case.id; source = $case.source; sourceSha256 = $case.sourceSha256
            expected = $case.expected; expectedSha256 = $case.expectedSha256
            state = 'running'; buildExitCode = $null; llvmAsExitCode = $null; runExitCode = $null
            buildStdoutPath = Join-Path $caseDirectory 'build.stdout.txt'
            buildStderrPath = Join-Path $caseDirectory 'build.stderr.txt'
            runStdoutPath = Join-Path $caseDirectory 'run.stdout.txt'
            runStderrPath = Join-Path $caseDirectory 'run.stderr.txt'
            exePath = $exe; llvmPath = $ll; bitcodePath = $bc; failure = $null
        }
        $record.cases += $active
        Write-C476Result
        $arguments = @('build', $case.source, '-o', $exe, '--target', 'windows-x64',
            '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps')
        $active.buildExitCode = Invoke-C476LoggedProcess $compilerPath $arguments $caseDirectory `
            $active.buildStdoutPath $active.buildStderrPath "C476 $($case.id) build"
        if ($active.buildExitCode -ne 0) { throw "C476_BUILD_EXIT: $($case.id) exit=$($active.buildExitCode)" }
        Assert-C476Empty $active.buildStderrPath "$($case.id) build"
        $buildText = [IO.File]::ReadAllText($active.buildStdoutPath)
        if ($buildText -match '(?m)^(?:warning\s|note\s)') { throw "C476_BUILD_WARNING: $($case.id)" }
        Assert-C476Products $artifactDirectory @('probe.exe', 'probe.exe.ll')
        if ((Get-Item -LiteralPath $exe).Length -eq 0 -or (Get-Item -LiteralPath $ll).Length -eq 0) {
            throw "C476_BUILD_PRODUCT_EMPTY: $($case.id)"
        }
        if ([IO.File]::ReadAllText($ll) -notmatch '(?m)^define\s') {
            throw "C476_LLVM_DIAGNOSTIC_ONLY: $($case.id)"
        }
        $asStdout = Join-Path $caseDirectory 'llvm-as.stdout.txt'
        $asStderr = Join-Path $caseDirectory 'llvm-as.stderr.txt'
        $active.llvmAsExitCode = Invoke-C476LoggedProcess $llvmAs @($ll, '-o', $bc) $caseDirectory `
            $asStdout $asStderr "C476 $($case.id) llvm-as"
        if ($active.llvmAsExitCode -ne 0) { throw "C476_LLVM_AS_EXIT: $($case.id) exit=$($active.llvmAsExitCode)" }
        Assert-C476Empty $asStdout "$($case.id) llvm-as stdout"
        Assert-C476Empty $asStderr "$($case.id) llvm-as stderr"
        Assert-C476Products $artifactDirectory @('probe.exe', 'probe.exe.ll', 'probe.exe.bc')
        if ((Get-Item -LiteralPath $bc).Length -eq 0) { throw "C476_BITCODE_EMPTY: $($case.id)" }
        $active.runExitCode = Invoke-C476LoggedProcess $exe @() $caseDirectory `
            $active.runStdoutPath $active.runStderrPath "C476 $($case.id) native run"
        if ($active.runExitCode -ne 0) { throw "C476_RUN_EXIT: $($case.id) exit=$($active.runExitCode)" }
        Assert-C476Empty $active.runStderrPath "$($case.id) native run"
        Assert-C476EqualBytes $active.runStdoutPath $case.expected "$($case.id) native stdout"
        Assert-C476Products $artifactDirectory @('probe.exe', 'probe.exe.ll', 'probe.exe.bc')
        Assert-C476Products $caseDirectory @('artifacts', 'build.stdout.txt', 'build.stderr.txt',
            'llvm-as.stdout.txt', 'llvm-as.stderr.txt', 'run.stdout.txt', 'run.stderr.txt')
        Assert-C476Snapshots
        if ((Get-C476Fingerprint) -cne $fingerprintStart) { throw 'C476_INPUT_DRIFT: after case' }
        $active.state = 'passed'
        $record.completed++; $record.passed++
        Write-C476Result
        Write-Host "[C476 positives] $($record.completed)/$($record.total) $($case.id) passed"
        $active = $null
    }
    $record.inputFingerprintEnd = Get-C476Fingerprint
    Assert-C476Snapshots
    $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    if (-not $record.inputsStable) { throw 'C476_INPUT_DRIFT: final input changed' }
    $record.state = 'passed'
    Write-C476Result
    Write-Host "[C476 positives] PASS $($record.passed)/$($record.total); $resultPath"
} catch {
    $failure = $_.Exception.Message
    if ($null -ne $active) { $active.state = 'failed'; $active.failure = $failure; $record.completed++ }
    try {
        $record.inputFingerprintEnd = Get-C476Fingerprint
        $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    } catch { $failure += "; end fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'
    $record.orphanProcessIds = @($script:c476OrphanProcessIds | Sort-Object)
    $record.failureId = if ($record.orphanProcessIds.Count -gt 0) { 'C476_PROCESS_ORPHANED' }
        elseif (-not $record.inputsStable) { 'C476_INPUT_DRIFT' }
        elseif ($failure -match '^(C476_[A-Z_]+):') { $Matches[1] }
        else { 'C476_VERIFIER_FAILED' }
    $record.failure = $failure
    Write-C476Result
    throw
}
