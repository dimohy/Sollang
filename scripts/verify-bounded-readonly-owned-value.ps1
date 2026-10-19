[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedAssemblySha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 120000,
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$schemaPath = Join-Path $PSScriptRoot 'contracts/bounded-readonly-owned-value-result.schema.json'
$fixedCases = @(
    [pscustomobject]@{
        id = 'primary'
        source = 'scripts/probes/dictionary/bounded-readonly-owned-value.slg'
        sourceSha256 = '606039356F1EB63CF82E5DE15A00645C15C2AC80E4A6497CA4CA651063675C93'
        expected = 'scripts/probes/dictionary/bounded-readonly-owned-value.stdout.txt'
        expectedSha256 = 'EA94C59DE5B64B3D83FA44748F301C681427895033F20986D2873EFB7A24A00B'
    },
    [pscustomobject]@{
        id = 'additional'
        source = 'scripts/probes/dictionary/c480-bounded-readonly-additional-argument.slg'
        sourceSha256 = '6801DD5F6609AC01ABDE90F3BBC0018A8D0E9F4F260196B431BE19800838E981'
        expected = 'scripts/probes/dictionary/c480-bounded-readonly-additional-argument.stdout.txt'
        expectedSha256 = '7312E985D4618E9CEDEFF3E1680EEF8BCDD09A58BE3E1A17449CBB409F72DD01'
    }
)

function Assert-BRVSchema($Value) {
    $json = $Value | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
        throw 'BRV_SCHEMA_INVALID: result does not satisfy its schema'
    }
    return $json
}

function Get-BRVBuildArguments([string]$Source, [string]$Executable, [string]$Llvm) {
    return [string[]]@('build', $Source, '-o', $Executable,
        '--target', 'windows-x64', '--llvm', $Llvm, '-O1', '--keep-temps')
}
function Assert-BRVStdlibAuthority([string]$Root, [string]$Actual) {
    $canonical = [IO.Path]::GetFullPath((Join-Path $Root 'stdlib'))
    if (-not [string]::Equals($Actual, $canonical,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'BRV_STDLIB_AUTHORITY: Managed compiler resolves the repository stdlib; custom StdlibRoot is not supported'
    }
}

if ($SelfTest) {
    $sha = 'A' * 64
    $sampleCase = [ordered]@{
        id = 'primary'; state = 'passed'
        sourcePath = 'source.slg'; sourceSha256 = $sha
        expectedPath = 'expected.txt'; expectedSha256 = $sha
        buildExitCode = 0; closureExitCode = 0; llvmAsExitCode = 0; runExitCode = 0
        warningCount = 0; directCallClosurePassed = $true; stdoutExact = $true
        executableSha256 = $sha; llvmSha256 = $sha; bitcodeSha256 = $sha; stdoutSha256 = $sha
        orphanProcessIds = @(); failureId = $null; failure = $null
    }
    $additionalCase = $sampleCase | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $additionalCase.id = 'additional'
    $sample = [ordered]@{
        schemaVersion = 2; gate = 'bounded-readonly-owned-value'; state = 'passed'
        compilerExecutablePath = 'compiler.exe'; compilerExecutableSha256 = $sha
        compilerAssemblyPath = 'compiler.dll'; compilerAssemblySha256 = $sha
        inputFingerprintStart = $sha; inputFingerprintEnd = $sha; inputsStable = $true
        completed = 2; total = 2; cases = @($sampleCase, $additionalCase)
        orphanProcessIds = @(); failureId = $null; failure = $null
    }
    [void](Assert-BRVSchema $sample)
    foreach ($mutation in @(
        @{ Case = -1; Field = 'inputsStable'; Value = $false },
        @{ Case = -1; Field = 'completed'; Value = 1 },
        @{ Case = -1; Field = 'compilerAssemblySha256'; Value = $null },
        @{ Case = -1; Field = 'orphanProcessIds'; Value = @(1234) },
        @{ Case = 0; Field = 'id'; Value = 'additional' },
        @{ Case = 0; Field = 'state'; Value = 'pending' },
        @{ Case = 0; Field = 'buildExitCode'; Value = 1 },
        @{ Case = 0; Field = 'closureExitCode'; Value = 1 },
        @{ Case = 1; Field = 'llvmAsExitCode'; Value = 1 },
        @{ Case = 1; Field = 'runExitCode'; Value = -1073740940 },
        @{ Case = 1; Field = 'warningCount'; Value = 1 },
        @{ Case = 1; Field = 'directCallClosurePassed'; Value = $false },
        @{ Case = 1; Field = 'stdoutExact'; Value = $false },
        @{ Case = 1; Field = 'orphanProcessIds'; Value = @(1234) },
        @{ Case = 1; Field = 'llvmSha256'; Value = $null }
    )) {
        $copy = $sample | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $target = if ($mutation.Case -lt 0) { $copy } else { $copy.cases[$mutation.Case] }
        $target.($mutation.Field) = $mutation.Value
        $accepted = try {
            Test-Json -Json ($copy | ConvertTo-Json -Depth 12) -SchemaFile $schemaPath
        } catch {
            $false
        }
        if ($accepted) {
            throw "BRV_SELFTEST_FALSE_PASS: $($mutation.Field)"
        }
    }
    [string[]]$arguments = Get-BRVBuildArguments 'fixture.slg' 'probe.exe' 'llvm'
    [string[]]$expectedArguments = @('build', 'fixture.slg', '-o',
        'probe.exe', '--target', 'windows-x64', '--llvm', 'llvm', '-O1', '--keep-temps')
    if ($arguments.Count -ne $expectedArguments.Count -or
        (@(Compare-Object -ReferenceObject $expectedArguments -DifferenceObject $arguments -SyncWindow 0).Count -ne 0)) {
        throw 'BRV_SELFTEST_ARGUMENT_VECTOR: Managed build arguments are not distinct and ordered'
    }
    $sampleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    Assert-BRVStdlibAuthority $sampleRoot (Join-Path $sampleRoot 'stdlib')
    $customAccepted = try {
        Assert-BRVStdlibAuthority $sampleRoot (Join-Path $sampleRoot 'stdlib-other')
        $true
    } catch { $false }
    if ($customAccepted) { throw 'BRV_SELFTEST_STDLIB_AUTHORITY' }
    Write-Host '[bounded readonly owned value self-test] PASS two-case schema, Managed arguments, and stdlib authority; no compiler executed.'
    return
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-BRVPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}
function Assert-BRVNoReparse([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) { return }
    $relative = [IO.Path]::GetRelativePath($root, $full)
    $cursor = $root
    foreach ($segment in ($relative -split '[\\/]')) {
        $cursor = Join-Path $cursor $segment
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "BRV_REPARSE_POINT: $cursor"
        }
    }
}
function Get-BRVSha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$compilerPath = Resolve-BRVPath $ManagedCompiler
$assemblyPath = Join-Path (Split-Path -Parent $compilerPath) 'Sollang.Compiler.dll'
$llvmPath = Resolve-BRVPath $LlvmRoot
$stdlibPath = Resolve-BRVPath $StdlibRoot
$outputPath = Resolve-BRVPath $OutputDirectory
$scratchPath = Resolve-BRVPath 'artifacts/scratch'
Assert-BRVStdlibAuthority $root $stdlibPath
$cases = @($fixedCases | ForEach-Object {
    [pscustomobject]@{
        id = $_.id
        sourcePath = Resolve-BRVPath $_.source
        sourceSha256 = $_.sourceSha256
        expectedPath = Resolve-BRVPath $_.expected
        expectedSha256 = $_.expectedSha256
    }
})
$casePaths = @($cases | ForEach-Object { $_.sourcePath; $_.expectedPath })
$closureScript = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$llvmAsPath = Join-Path $llvmPath 'bin/llvm-as.exe'
$clangPath = Join-Path $llvmPath 'bin/clang.exe'
$pwshPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
if (-not $outputPath.StartsWith($scratchPath + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'BRV_OUTPUT_SCOPE: OutputDirectory must be below artifacts/scratch'
}
if (Test-Path -LiteralPath $outputPath) { throw "BRV_OUTPUT_EXISTS: $outputPath" }
foreach ($path in @($compilerPath, $assemblyPath, $llvmPath, $stdlibPath) + $casePaths +
        @($schemaPath, $closureScript, $llvmAsPath, $clangPath, $pwshPath, $outputPath)) {
    Assert-BRVNoReparse $path
}
if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf) -or
    [IO.Path]::GetFileName($compilerPath) -cne 'Sollang.Compiler.exe' -or
    -not (Test-Path -LiteralPath $assemblyPath -PathType Leaf)) {
    throw 'BRV_COMPILER_INVALID: Managed EXE with adjacent DLL required'
}
if ($ManagedCompilerSha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or
    (Get-BRVSha $compilerPath) -cne $ManagedCompilerSha256.ToUpperInvariant()) {
    throw 'BRV_COMPILER_SHA_MISMATCH: Managed EXE differs from requested SHA'
}
if ($ManagedAssemblySha256 -cnotmatch '^[a-fA-F0-9]{64}$' -or
    (Get-BRVSha $assemblyPath) -cne $ManagedAssemblySha256.ToUpperInvariant()) {
    throw 'BRV_ASSEMBLY_SHA_MISMATCH: Managed DLL differs from requested SHA'
}
$compilerPackageFiles = @(Get-ChildItem -LiteralPath (Split-Path -Parent $compilerPath) -File -Force |
    Sort-Object FullName | ForEach-Object FullName)
foreach ($path in $compilerPackageFiles) { Assert-BRVNoReparse $path }
foreach ($path in $casePaths + @($schemaPath, $closureScript, $llvmAsPath, $clangPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "BRV_INPUT_MISSING: $path" }
}
if (-not (Test-Path -LiteralPath $stdlibPath -PathType Container)) {
    throw "BRV_STDLIB_MISSING: $stdlibPath"
}
foreach ($case in $cases) {
    if ((Get-BRVSha $case.sourcePath) -cne $case.sourceSha256 -or
        (Get-BRVSha $case.expectedPath) -cne $case.expectedSha256) {
        throw "BRV_FIXTURE_DRIFT: source or exact stdout differs from fixed case $($case.id)"
    }
}

function Get-BRVInputFingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'bounded-readonly-owned-value-v2'; common = $common
        outputDirectory = $outputPath; timeoutMilliseconds = [string]$TimeoutMilliseconds
        optimization = 'O1'; target = 'windows-x64'
    }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
        -Settings $settings -InputPath (@($PSCommandPath, $schemaPath, $pwshPath) +
            $casePaths + $compilerPackageFiles)
}
function Assert-BRVInputs([string]$Fingerprint) {
    $currentPackageFiles = @(Get-ChildItem -LiteralPath (Split-Path -Parent $compilerPath) -File -Force |
        Sort-Object FullName | ForEach-Object FullName)
    if ([string]::Join([char]10, $currentPackageFiles) -cne
        [string]::Join([char]10, $compilerPackageFiles)) {
        throw 'BRV_INPUT_DRIFT: Managed compiler package file inventory changed'
    }
    if ((Get-BRVSha $compilerPath) -cne $ManagedCompilerSha256.ToUpperInvariant() -or
        (Get-BRVSha $assemblyPath) -cne $ManagedAssemblySha256.ToUpperInvariant() -or
        (Get-BRVInputFingerprint) -cne $Fingerprint) {
        throw 'BRV_INPUT_DRIFT: run-scoped compiler, fixture, stdlib, LLVM, or verifier input changed'
    }
    foreach ($case in $cases) {
        if ((Get-BRVSha $case.sourcePath) -cne $case.sourceSha256 -or
            (Get-BRVSha $case.expectedPath) -cne $case.expectedSha256) {
            throw "BRV_INPUT_DRIFT: fixed case $($case.id) changed"
        }
    }
}

$fingerprintStart = Get-BRVInputFingerprint
Assert-BRVInputs $fingerprintStart
if ($ValidateInputsOnly) {
    [pscustomobject]@{
        state = 'preflight-passed'
        compilerExecutableSha256 = $ManagedCompilerSha256.ToUpperInvariant()
        compilerAssemblySha256 = $ManagedAssemblySha256.ToUpperInvariant()
        cases = @($cases | ForEach-Object {
            [pscustomobject]@{ id = $_.id; sourceSha256 = $_.sourceSha256; expectedSha256 = $_.expectedSha256 }
        })
        inputFingerprint = $fingerprintStart; outputDirectory = $outputPath
    } | ConvertTo-Json -Depth 6
    return
}

function Get-BRVSnapshot {
    try {
        return @(Get-CimInstance Win32_Process -OperationTimeoutSec 5 -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                id = [int]$_.ProcessId; parentId = [int]$_.ParentProcessId
                startedTicks = ([datetime]$_.CreationDate).ToUniversalTime().Ticks
            }
        })
    } catch {
        throw "BRV_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)"
    }
}
function Update-BRVDescendants([Collections.Generic.Dictionary[int, long]]$Known,
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
function Get-BRVLiveDescendants([Collections.Generic.Dictionary[int, long]]$Known,
        [object[]]$Snapshot, [int]$RootId) {
    return @($Snapshot | Where-Object {
        $_.id -ne $RootId -and $Known.ContainsKey($_.id) -and
        $Known[$_.id] -eq $_.startedTicks
    } | ForEach-Object id | Sort-Object -Unique)
}
$script:brvOrphans = [Collections.Generic.HashSet[int]]::new()
function Invoke-BRVLogged([string]$File, [string[]]$Arguments, [string]$Directory,
        [string]$StdoutPath, [string]$StderrPath, [string]$Description) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $Directory
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
        if (-not $process.Start()) { throw "BRV_PROCESS_START_FAILED: $Description" }
        $started = $true
        $rootId = $process.Id
        $known.Add($rootId, $process.StartTime.ToUniversalTime().Ticks)
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(250)) {
            Update-BRVDescendants $known @(Get-BRVSnapshot) $rootId ([DateTime]::MaxValue.Ticks)
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                throw "BRV_PROCESS_TIMEOUT: $Description exceeded $TimeoutMilliseconds ms"
            }
        }
        $snapshot = @(Get-BRVSnapshot)
        Update-BRVDescendants $known $snapshot $rootId $process.ExitTime.ToUniversalTime().Ticks
        $live = @(Get-BRVLiveDescendants $known $snapshot $rootId)
        if ($live.Count -gt 0) {
            foreach ($id in $live) { [void]$script:brvOrphans.Add([int]$id) }
            throw "BRV_PROCESS_ORPHANED: $Description left descendants $($live -join ',')"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "BRV_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult()
        $stdout.Flush(); $stderr.Flush()
        return $process.ExitCode
    } finally {
        if ($started -and -not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { }
            if (-not $process.WaitForExit(5000)) { [void]$script:brvOrphans.Add($process.Id) }
        }
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}
function Assert-BRVEmpty([string]$Path, [string]$Description) {
    if ((Get-Item -LiteralPath $Path).Length -ne 0) { throw "BRV_UNEXPECTED_OUTPUT: $Description" }
}
function Assert-BRVNames([string]$Directory, [string[]]$Names) {
    $actual = @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name | Sort-Object -CaseSensitive)
    $expected = @($Names | Sort-Object -CaseSensitive)
    if (($actual -join "`n") -cne ($expected -join "`n")) {
        throw "BRV_ARTIFACT_INVENTORY: $Directory actual=$($actual -join ',') expected=$($expected -join ',')"
    }
}
function Assert-BRVCompilerScratch([string]$Directory) {
    $cache = Join-Path $Directory '.sollang-cache'
    $temporary = Join-Path $Directory 'probe.slg-tmp'
    foreach ($path in @($cache, $temporary)) {
        $item = Get-Item -LiteralPath $path
        if (-not $item.PSIsContainer -or
            ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "BRV_ARTIFACT_SCRATCH_INVALID: $path"
        }
    }
    Assert-BRVNames $temporary @('kernel32.def', 'kernel32.lib', 'probe.ll',
        'probe.obj', 'shell32.def', 'shell32.lib', 'ucrtbase.def', 'ucrtbase.lib')
    $cacheFiles = @(Get-ChildItem -LiteralPath $cache -Force)
    $suffixes = @('.cgu', '.product', '.semantic', '.sources')
    if ($cacheFiles.Count -ne $suffixes.Count) { throw 'BRV_ARTIFACT_CACHE_INVENTORY' }
    foreach ($suffix in $suffixes) {
        $matched = @($cacheFiles | Where-Object {
            -not $_.PSIsContainer -and
            ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -and
            $_.Name -cmatch ('^probe\.windows-x64\.[A-Za-z0-9-]+\.o1-executable' + [regex]::Escape($suffix) + '$')
        })
        if ($matched.Count -ne 1) { throw "BRV_ARTIFACT_CACHE_INVENTORY: $suffix" }
    }
}

[void][IO.Directory]::CreateDirectory($outputPath)
$resultPath = Join-Path $outputPath 'result.json'
$caseRecords = @($cases | ForEach-Object {
    [ordered]@{
        id = $_.id; state = 'pending'
        sourcePath = $_.sourcePath; sourceSha256 = $_.sourceSha256
        expectedPath = $_.expectedPath; expectedSha256 = $_.expectedSha256
        buildExitCode = $null; closureExitCode = $null; llvmAsExitCode = $null; runExitCode = $null
        warningCount = 0; directCallClosurePassed = $false; stdoutExact = $false
        executableSha256 = $null; llvmSha256 = $null; bitcodeSha256 = $null; stdoutSha256 = $null
        orphanProcessIds = @(); failureId = $null; failure = $null
    }
})
$record = [ordered]@{
    schemaVersion = 2; gate = 'bounded-readonly-owned-value'; state = 'running'
    compilerExecutablePath = $compilerPath
    compilerExecutableSha256 = $ManagedCompilerSha256.ToUpperInvariant()
    compilerAssemblyPath = $assemblyPath
    compilerAssemblySha256 = $ManagedAssemblySha256.ToUpperInvariant()
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null; inputsStable = $false
    completed = 0; total = 2; cases = $caseRecords
    orphanProcessIds = @(); failureId = $null; failure = $null
}
function Write-BRVResult {
    $json = Assert-BRVSchema $record
    $temporary = "$resultPath.tmp-$PID"
    [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $resultPath, $true)
}
Write-BRVResult
$caseRecord = $null
try {
    foreach ($case in $cases) {
    $caseRecord = $record.cases[$record.completed]
    $caseRecord.state = 'running'
    $caseDirectory = Join-Path $outputPath $case.id
    $artifactDirectory = Join-Path $caseDirectory 'artifacts'
    $logDirectory = Join-Path $caseDirectory 'logs'
    [void][IO.Directory]::CreateDirectory($artifactDirectory)
    [void][IO.Directory]::CreateDirectory($logDirectory)
    $sourcePath = $case.sourcePath
    $expectedPath = $case.expectedPath
    $exe = Join-Path $artifactDirectory 'probe.exe'
    $ll = Join-Path $artifactDirectory 'probe.ll'
    $bc = Join-Path $artifactDirectory 'probe.bc'
    $inputReceipt = "$exe.inputs.sha256"
    $outputReceipt = "$exe.outputs.sha256"
    Write-BRVResult
    Assert-BRVInputs $fingerprintStart
    [string[]]$buildArgs = Get-BRVBuildArguments $sourcePath $exe $llvmPath
    $buildOut = Join-Path $logDirectory 'build.stdout.txt'
    $buildErr = Join-Path $logDirectory 'build.stderr.txt'
    $caseRecord.buildExitCode = Invoke-BRVLogged $compilerPath $buildArgs $caseDirectory `
        $buildOut $buildErr "$($case.id) Managed build"
    Write-BRVResult
    if ($caseRecord.buildExitCode -ne 0) { throw "BRV_BUILD_EXIT: $($case.id) $($caseRecord.buildExitCode)" }
    Assert-BRVEmpty $buildErr 'Managed build stderr'
    $caseRecord.warningCount = [regex]::Matches([IO.File]::ReadAllText($buildOut),
        '(?im)^\s*(?:warning|note)\b').Count
    if ($caseRecord.warningCount -ne 0) { throw "BRV_BUILD_WARNING: $($case.id) Managed build emitted a warning or note" }
    Assert-BRVNames $artifactDirectory @('.sollang-cache', 'probe.slg-tmp', 'probe.exe', 'probe.ll')
    Assert-BRVCompilerScratch $artifactDirectory
    if ((Get-Item -LiteralPath $exe).Length -eq 0 -or (Get-Item -LiteralPath $ll).Length -eq 0 -or
        [IO.File]::ReadAllText($ll) -notmatch '(?m)^define\s') {
        throw 'BRV_BUILD_PRODUCT_INVALID: native executable or real LLVM is missing'
    }
    Assert-BRVInputs $fingerprintStart

    $closureOut = Join-Path $logDirectory 'closure.stdout.txt'
    $closureErr = Join-Path $logDirectory 'closure.stderr.txt'
    $caseRecord.closureExitCode = Invoke-BRVLogged $pwshPath `
        ([string[]]@('-NoProfile', '-File', $closureScript, '-LlvmPath', $ll)) $caseDirectory `
        $closureOut $closureErr "$($case.id) LLVM closure"
    Write-BRVResult
    if ($caseRecord.closureExitCode -ne 0) { throw "BRV_CLOSURE_EXIT: $($case.id) $($caseRecord.closureExitCode)" }
    Assert-BRVEmpty $closureErr 'LLVM closure stderr'
    $caseRecord.directCallClosurePassed = $true
    Assert-BRVInputs $fingerprintStart

    $asOut = Join-Path $logDirectory 'llvm-as.stdout.txt'
    $asErr = Join-Path $logDirectory 'llvm-as.stderr.txt'
    $caseRecord.llvmAsExitCode = Invoke-BRVLogged $llvmAsPath ([string[]]@($ll, '-o', $bc)) `
        $caseDirectory $asOut $asErr "$($case.id) llvm-as"
    Write-BRVResult
    if ($caseRecord.llvmAsExitCode -ne 0) { throw "BRV_LLVM_AS_EXIT: $($case.id) $($caseRecord.llvmAsExitCode)" }
    Assert-BRVEmpty $asOut 'llvm-as stdout'
    Assert-BRVEmpty $asErr 'llvm-as stderr'
    Assert-BRVNames $artifactDirectory @('.sollang-cache', 'probe.slg-tmp',
        'probe.exe', 'probe.ll', 'probe.bc')
    Assert-BRVCompilerScratch $artifactDirectory
    if ((Get-Item -LiteralPath $bc).Length -eq 0) { throw 'BRV_BITCODE_EMPTY' }
    Assert-BRVInputs $fingerprintStart

    $runOut = Join-Path $logDirectory 'run.stdout.txt'
    $runErr = Join-Path $logDirectory 'run.stderr.txt'
    $caseRecord.runExitCode = Invoke-BRVLogged $exe ([string[]]@()) $caseDirectory `
        $runOut $runErr "$($case.id) native execution"
    Write-BRVResult
    if ($caseRecord.runExitCode -ne 0) { throw "BRV_RUN_EXIT: $($case.id) $($caseRecord.runExitCode)" }
    Assert-BRVEmpty $runErr 'native stderr'
    $actualBytes = [IO.File]::ReadAllBytes($runOut)
    $expectedBytes = [IO.File]::ReadAllBytes($expectedPath)
    $caseRecord.stdoutExact = $actualBytes.Length -eq $expectedBytes.Length
    if ($caseRecord.stdoutExact) {
        for ($index = 0; $index -lt $actualBytes.Length; $index++) {
            if ($actualBytes[$index] -ne $expectedBytes[$index]) {
                $caseRecord.stdoutExact = $false
                break
            }
        }
    }
    if (-not $caseRecord.stdoutExact) { throw "BRV_STDOUT_MISMATCH: $($case.id) native stdout differs by bytes" }
    Assert-BRVNames $logDirectory @('build.stdout.txt', 'build.stderr.txt',
        'closure.stdout.txt', 'closure.stderr.txt', 'llvm-as.stdout.txt',
        'llvm-as.stderr.txt', 'run.stdout.txt', 'run.stderr.txt')
    Assert-BRVInputs $fingerprintStart
    Publish-NativeExactFixtureReceipt -InputFingerprint $fingerprintStart `
        -InputReceiptPath $inputReceipt -LlvmPath $ll -BitcodePath $bc `
        -ExecutablePath $exe -OutputReceiptPath $outputReceipt
    if (-not (Test-NativeExactFixtureReceipt -InputFingerprint $fingerprintStart `
            -InputReceiptPath $inputReceipt -LlvmPath $ll -BitcodePath $bc `
            -ExecutablePath $exe -OutputReceiptPath $outputReceipt)) {
        throw 'BRV_ARTIFACT_AUTHENTICATION: native exact input or output hash mismatch'
    }
    Assert-BRVNames $artifactDirectory @('.sollang-cache', 'probe.slg-tmp',
        'probe.exe', 'probe.ll', 'probe.bc',
        'probe.exe.inputs.sha256', 'probe.exe.outputs.sha256')
    Assert-BRVCompilerScratch $artifactDirectory
    $caseRecord.executableSha256 = Get-BRVSha $exe
    $caseRecord.llvmSha256 = Get-BRVSha $ll
    $caseRecord.bitcodeSha256 = Get-BRVSha $bc
    $caseRecord.stdoutSha256 = Get-BRVSha $runOut
    $caseRecord.orphanProcessIds = @($script:brvOrphans | Sort-Object)
    if (@($caseRecord.orphanProcessIds).Count -ne 0) { throw "BRV_PROCESS_ORPHANED: $($case.id)" }
    $caseRecord.state = 'passed'
    $record.completed++
    Write-BRVResult
    }
    Assert-BRVNames $outputPath @('result.json', 'primary', 'additional')
    $record.inputFingerprintEnd = Get-BRVInputFingerprint
    $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    if (-not $record.inputsStable) { throw 'BRV_INPUT_DRIFT: final input fingerprint changed' }
    $record.orphanProcessIds = @($script:brvOrphans | Sort-Object)
    if (@($record.orphanProcessIds).Count -ne 0) { throw 'BRV_PROCESS_ORPHANED: verified descendant remains' }
    $record.state = 'passed'
    Write-BRVResult
    Write-Host "[bounded readonly owned value] PASS exact native output, LLVM closure/assembly, stable inputs, no warnings or orphans; $resultPath"
} catch {
    $original = $_
    if ($null -ne $caseRecord -and $caseRecord.state -eq 'running') {
        $caseRecord.state = 'failed'
        $caseRecord.failure = $original.Exception.Message
        $caseRecord.failureId = if ($caseRecord.failure -match '\b(BRV_[A-Z_]+)\b') { $Matches[1] }
            else { 'BRV_GATE_FAILED' }
        $caseRecord.orphanProcessIds = @($script:brvOrphans | Sort-Object)
    }
    $record.state = 'failed'
    $record.failure = $original.Exception.Message
    $record.failureId = if ($record.failure -match '\b(BRV_[A-Z_]+)\b') { $Matches[1] }
        else { 'BRV_GATE_FAILED' }
    $record.orphanProcessIds = @($script:brvOrphans | Sort-Object)
    try {
        $record.inputFingerprintEnd = Get-BRVInputFingerprint
        $record.inputsStable = $record.inputFingerprintEnd -ceq $fingerprintStart
    } catch {
        $record.failure += "; end fingerprint failed: $($_.Exception.Message)"
    }
    Write-BRVResult
    throw $original
}
