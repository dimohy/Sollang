[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = '',
    [string]$ZstdPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $scratch ('zstd-fse-huffman-' + [guid]::NewGuid().ToString('N')) }
$output = [IO.Path]::GetFullPath($OutputDirectory)
$scratchPrefix = $scratch.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Zstandard focused output must be under artifacts/scratch: $output" }
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw "Zstandard focused output must be a new or empty directory: $output" }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$compilerInput = if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }
$compiler = [IO.Path]::GetFullPath($compilerInput)
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$contractPath = Join-Path $root 'scripts/contracts/zstd-fse-huffman-weights.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/zstd-fse-huffman-weights.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/zstd-fse-huffman-weights-result.schema.json'
$fixtureInventoryPath = Join-Path $root 'scripts/verify-native-exact-fixture-batch.ps1'
$exampleRunnerSourcePath = Join-Path $root 'tests/Sollang.ExampleTests/Program.cs'
$fixturePath = Join-Path $root 'examples/regression/1753-zstd-fse-huffman-weights.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1753-zstd-fse-huffman-weights.stdout.txt'
$zstdSource = Join-Path $root 'stdlib/std/compress/zstd.slg'
$huffmanSource = Join-Path $root 'stdlib/std/compress/zstd/huffman.slg'
$fseSource = Join-Path $root 'stdlib/std/compress/zstd/fse.slg'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clang = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$allocationAuditShim = Join-Path $root 'tests/native-interop/owned_array_audit.c'

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Bytes-Equal([byte[]]$Left, [byte[]]$Right) { $Left.Length -eq $Right.Length -and (Hash-Bytes $Left) -ceq (Hash-Bytes $Right) }
function Get-InputSnapshot([Collections.Specialized.OrderedDictionary]$Paths) {
    $snapshot = [ordered]@{}
    foreach ($entry in $Paths.GetEnumerator()) { $snapshot[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) { Hash $entry.Value } else { $null } }
    $snapshot
}
function Get-ProcessRecords {
    if (-not $IsWindows) { throw 'Zstandard focused process genealogy currently requires Windows' }
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object ProcessId, ParentProcessId, CreationDate)
}
function Update-ObservedDescendants([Collections.Generic.Dictionary[string, object]]$Observed, [string]$RootIdentity) {
    $records = @(Get-ProcessRecords)
    $byId = @{}
    foreach ($record in $records) { $byId[[int]$record.ProcessId] = $record }
    $pending = [Collections.Generic.Queue[string]]::new()
    foreach ($identity in @($Observed.Keys)) { $pending.Enqueue($identity) }
    $visited = [Collections.Generic.HashSet[string]]::new()
    while ($pending.Count -gt 0) {
        $identity = $pending.Dequeue()
        if (-not $visited.Add($identity)) { continue }
        $parent = $Observed[$identity]
        $parentId = [int]$parent.ProcessId
        $parentTicks = [long]$parent.CreatedTicks
        if (-not $byId.ContainsKey($parentId) -or $byId[$parentId].CreationDate.ToUniversalTime().Ticks -ne $parentTicks) { continue }
        foreach ($record in $records) {
            if ([int]$record.ParentProcessId -ne $parentId) { continue }
            $created = $record.CreationDate.ToUniversalTime().Ticks
            if ($created -lt $parentTicks) { continue }
            $childId = [int]$record.ProcessId
            $childIdentity = "${childId}:$created"
            if (-not $Observed.ContainsKey($childIdentity)) { $Observed.Add($childIdentity, [pscustomobject]@{ ProcessId = $childId; CreatedTicks = $created }) }
            $pending.Enqueue($childIdentity)
        }
    }
    @($Observed.GetEnumerator() | Where-Object Key -cne $RootIdentity | ForEach-Object {
        $processId = [int]$_.Value.ProcessId
        if ($byId.ContainsKey($processId) -and $byId[$processId].CreationDate.ToUniversalTime().Ticks -eq [long]$_.Value.CreatedTicks) { $processId }
    })
}
function Run-Raw([string]$Id, [string]$FilePath, [string[]]$Arguments, [int]$TimeoutMilliseconds = 60000) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "$Id could not start '$FilePath'" }
        $rootProcessId = $process.Id
        $rootRecord = @(Get-ProcessRecords | Where-Object { [int]$_.ProcessId -eq $rootProcessId })
        # Very small validators can terminate before the first CIM snapshot.
        # Their Process object still supplies the exact launched PID and start
        # time; longer compiler processes use the CIM identity for descendant
        # discovery and PID-reuse protection.
        $rootTicks = if ($rootRecord.Count -eq 1) {
            $rootRecord[0].CreationDate.ToUniversalTime().Ticks
        } else {
            $process.StartTime.ToUniversalTime().Ticks
        }
        $rootIdentity = "${rootProcessId}:$rootTicks"
        $observed = [Collections.Generic.Dictionary[string, object]]::new()
        $observed.Add($rootIdentity, [pscustomobject]@{ ProcessId = $rootProcessId; CreatedTicks = $rootTicks })
        $stdoutStream = [IO.MemoryStream]::new()
        $stderrStream = [IO.MemoryStream]::new()
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutStream)
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrStream)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(10) -and [DateTimeOffset]::UtcNow -lt $deadline) { Update-ObservedDescendants $observed $rootIdentity | Out-Null }
        if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit(); throw "$Id exceeded $TimeoutMilliseconds ms" }
        $process.WaitForExit()
        $stdoutTask.GetAwaiter().GetResult()
        $stderrTask.GetAwaiter().GetResult()
        $orphanDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
        do {
            $orphans = @(Update-ObservedDescendants $observed $rootIdentity)
            if ($orphans.Count -eq 0 -or [DateTimeOffset]::UtcNow -ge $orphanDeadline) { break }
            Start-Sleep -Milliseconds 25
        } while ($true)
        [pscustomobject]@{
            Id = $Id; ExitCode = $process.ExitCode; StdoutBytes = $stdoutStream.ToArray(); StderrBytes = $stderrStream.ToArray()
            RootProcessId = $rootProcessId
            DescendantProcessIds = @($observed.GetEnumerator() | Where-Object Key -cne $rootIdentity | ForEach-Object { [int]$_.Value.ProcessId } | Sort-Object -Unique)
            OrphanProcessIds = @($orphans | Sort-Object -Unique)
        }
    } finally { $process.Dispose() }
}
function Save-Capture($Capture) {
    $safeId = $Capture.Id -replace '[^A-Za-z0-9_.-]', '-'
    $stdoutPath = Join-Path $output "$safeId.stdout.bin"
    $stderrPath = Join-Path $output "$safeId.stderr.bin"
    [IO.File]::WriteAllBytes($stdoutPath, $Capture.StdoutBytes)
    [IO.File]::WriteAllBytes($stderrPath, $Capture.StderrBytes)
    $artifact = [ordered]@{
        id = $Capture.Id; exitCode = $Capture.ExitCode; rootProcessId = $Capture.RootProcessId
        descendantProcessIds = @($Capture.DescendantProcessIds); orphanProcessIds = @($Capture.OrphanProcessIds)
        stdoutPath = [IO.Path]::GetRelativePath($root, $stdoutPath).Replace('\', '/'); stderrPath = [IO.Path]::GetRelativePath($root, $stderrPath).Replace('\', '/')
        stdoutSha256 = Hash $stdoutPath; stderrSha256 = Hash $stderrPath
        stdoutBytes = $Capture.StdoutBytes.Length; stderrBytes = $Capture.StderrBytes.Length
    }
    $script:record.processAudit.invocations += $artifact
    $script:record.processAudit.rootProcessIds += $Capture.RootProcessId
    $script:record.processAudit.descendantProcessIds += @($Capture.DescendantProcessIds)
    $script:record.processAudit.orphanProcessIds += @($Capture.OrphanProcessIds)
    $artifact
}
function Invoke-Captured([string]$Id, [string]$FilePath, [string[]]$Arguments, [int]$TimeoutMilliseconds = 60000) {
    # PowerShell can surface a void-returning framework call from a provider as
    # AutomationNull in some hosts.  The authoritative capture is always the
    # final object returned by Run-Raw.
    $capture = @(Run-Raw $Id $FilePath $Arguments $TimeoutMilliseconds)[-1]
    $artifact = Save-Capture $capture
    [pscustomobject]@{ Capture = $capture; Artifact = $artifact }
}
function Require-Success($Run, [string]$FailureId, [switch]$RejectDiagnostics) {
    if ($Run.Capture.ExitCode -ne 0 -or $Run.Capture.StderrBytes.Length -ne 0 -or $Run.Capture.OrphanProcessIds.Count -ne 0) {
        $script:currentFailureId = $FailureId
        throw "$($Run.Capture.Id) failed exit=$($Run.Capture.ExitCode), stderrBytes=$($Run.Capture.StderrBytes.Length), orphans=$($Run.Capture.OrphanProcessIds.Count)"
    }
    if ($RejectDiagnostics) {
        $combined = [Text.Encoding]::UTF8.GetString($Run.Capture.StdoutBytes) + "`n" + [Text.Encoding]::UTF8.GetString($Run.Capture.StderrBytes)
        if ($combined -match '(?im)(?:^|\r?\n)\s*(?:warning|note)\b') { $script:currentFailureId = $FailureId; throw "$($Run.Capture.Id) emitted a warning or note" }
    }
}
function Invoke-Compiler([string]$Id, [string[]]$Arguments) {
    if ($script:record.compilerDispatch -ceq 'dotnet') { Invoke-Captured $Id $script:dotnetPath (@($compiler) + $Arguments) } else { Invoke-Captured $Id $compiler $Arguments }
}
function Save-Result {
    $json = ($script:record | ConvertTo-Json -Depth 10) + "`n"
    if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw 'Zstandard focused result does not match its schema' }
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), $json, [Text.UTF8Encoding]::new($false))
}

$record = [ordered]@{
    schemaVersion = 1; mode = 'zstd-fse-huffman-weights-focused'; status = 'failed'; completed = 0; total = 5; failureIds = @()
    compilerPath = $compiler; expectedCompilerSha256 = $ExpectedCompilerSha256; compilerSha256Start = $null; compilerSha256End = $null; compilerDispatch = 'unavailable'
    inputStable = $false; inputDrift = @(); inputHashesStart = [ordered]@{ bootstrap = $null }; inputHashesEnd = [ordered]@{ bootstrap = $null }
    managed = [ordered]@{ completed = 0; total = 2; checks = @(
        [ordered]@{ optimization = 'O0'; status = 'not-run'; nativeStdoutSha256 = $null; nativeStdoutBytes = $null; llvmSha256 = $null; bitcodeSha256 = $null; executableSha256 = $null },
        [ordered]@{ optimization = 'O2'; status = 'not-run'; nativeStdoutSha256 = $null; nativeStdoutBytes = $null; llvmSha256 = $null; bitcodeSha256 = $null; executableSha256 = $null }) }
    malformedMatrix = [ordered]@{ completed = 0; total = 11; status = 'not-run'; caseIds = @('terminal-zero-bit-state', 'even-symbol-termination', 'odd-symbol-termination', 'normalized-count-corruption', 'end-marker-corruption', 'truncation', 'trailing-bits', 'weight-12-overflow', 'weight-count-255-bound', 'table-accuracy-bound', 'zstd-invalid-tree-headers') }
    independentZstd = [ordered]@{ completed = 0; total = 1; status = 'not-run'; path = 'unavailable'; sha256 = $null; version = $null; decodedSha256 = $null }
    recompression = [ordered]@{ completed = 0; total = 1; status = 'not-run'; failureReason = $null; runs = @() }
    allocationAudit = [ordered]@{ completed = 0; total = 1; status = 'not-run'; expectedAllocations = 1339; maximumAllocations = 2048; allocations = $null; releases = $null; invalidReleases = $null }
    processAudit = [ordered]@{ rootProcessIds = @(); descendantProcessIds = @(); orphanProcessIds = @(); invocations = @() }
}
$inputPaths = [ordered]@{
    compiler = $compiler; contract = $contractPath; contractSchema = $contractSchemaPath; resultSchema = $resultSchemaPath; verifier = $PSCommandPath
    fixtureInventory = $fixtureInventoryPath; exampleRunnerSource = $exampleRunnerSourcePath; fixture = $fixturePath; expected = $expectedPath
    zstdSource = $zstdSource; huffmanSource = $huffmanSource; fseSource = $fseSource; formatter = $formatVerifier; closure = $closureVerifier; llvmAs = $llvmAs
    clang = $clang; allocationAuditShim = $allocationAuditShim
}
if (Test-Path -LiteralPath (Join-Path $root 'stdlib') -PathType Container) {
    foreach ($source in @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg' | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($root, $source.FullName).Replace('\', '/')
        $inputPaths["stdlib:$relative"] = $source.FullName
    }
}
$currentFailureId = 'VERIFIER_EXCEPTION'
$failure = $null
$dotnetPath = $null

try {
    $record.inputHashesStart = Get-InputSnapshot $inputPaths
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { $currentFailureId = 'COMPILER_MISSING'; throw "Zstandard focused compiler is missing: $compiler" }
    $compilerExtension = [IO.Path]::GetExtension($compiler).ToLowerInvariant()
    if ($compilerExtension -notin @('.dll', '.exe')) { $currentFailureId = 'COMPILER_EXTENSION_INVALID'; throw "Zstandard focused compiler must be a .dll or .exe: $compiler" }
    $record.compilerSha256Start = $record.inputHashesStart.compiler
    if ($record.compilerSha256Start -cne $ExpectedCompilerSha256) { $currentFailureId = 'COMPILER_HASH_MISMATCH'; throw "Zstandard focused compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($record.compilerSha256Start)" }
    if ($compilerExtension -ceq '.dll') { $dotnetPath = @((Get-Command dotnet -CommandType Application -ErrorAction Stop))[0].Source; $record.compilerDispatch = 'dotnet' } else { $record.compilerDispatch = 'direct' }
    if ($null -ne $dotnetPath) { $inputPaths.dotnet = $dotnetPath }
    $zstd = if ([string]::IsNullOrWhiteSpace($ZstdPath)) { @((Get-Command zstd -CommandType Application -ErrorAction Stop))[0].Source } else { [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ZstdPath)) { $ZstdPath } else { Join-Path $root $ZstdPath })) }
    $zstd = [IO.Path]::GetFullPath($zstd)
    $record.independentZstd.path = $zstd
    $inputPaths.zstd = $zstd
    $record.inputHashesStart = Get-InputSnapshot $inputPaths
    $record.compilerSha256Start = $record.inputHashesStart.compiler
    foreach ($entry in $inputPaths.GetEnumerator()) { if ($null -eq $record.inputHashesStart[$entry.Key]) { $currentFailureId = 'AUTHORITY_INPUT_MISSING'; throw "Zstandard focused input is missing: $($entry.Value)" } }

    $currentFailureId = 'CONTRACT_SCHEMA_INVALID'
    $contractText = [IO.File]::ReadAllText($contractPath)
    if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath)) { throw 'Zstandard FSE Huffman contract does not satisfy its schema' }
    $contract = $contractText | ConvertFrom-Json
    $expectedCaseIds = @('terminal-zero-bit-state', 'even-symbol-termination', 'odd-symbol-termination', 'normalized-count-corruption', 'end-marker-corruption', 'truncation', 'trailing-bits', 'weight-12-overflow', 'weight-count-255-bound', 'table-accuracy-bound', 'zstd-invalid-tree-headers')
    if (@($contract.malformedMatrix).Count -ne $expectedCaseIds.Count -or (@($contract.malformedMatrix.id) -join ',') -cne ($expectedCaseIds -join ',')) { $currentFailureId = 'MALFORMED_MATRIX_IDENTITY_MISMATCH'; throw 'Zstandard malformed FSE boundary matrix identity drifted' }
    $encoded = [Convert]::FromBase64String($contract.reference.encodedBase64)
    if ($encoded.Length -ne $contract.reference.encodedLength -or (Hash-Bytes $encoded) -cne $contract.reference.encodedSha256 -or $encoded[$contract.reference.treeHeaderOffset] -ne $contract.reference.fseDescriptionBytes) { $currentFailureId = 'REFERENCE_VECTOR_IDENTITY_MISMATCH'; throw 'Zstandard reference vector identity drifted' }
    $generator = $contract.reference.decodedGenerator
    $phrase = [Text.Encoding]::ASCII.GetBytes([string]$generator.phraseAscii)
    $expectedDecoded = [byte[]]::new([int]$contract.reference.decodedLength)
    for ($index = 0; $index -lt $expectedDecoded.Length; $index++) { $expectedDecoded[$index] = if ($index % [int]$generator.highBytePeriod -eq 0) { [byte]([int]$generator.highByteBase + ($index % [int]$generator.highByteModulus)) } else { $phrase[$index % $phrase.Length] } }
    if ((Hash-Bytes $expectedDecoded) -cne $contract.reference.decodedSha256) { $currentFailureId = 'REFERENCE_GENERATOR_MISMATCH'; throw 'Zstandard decoded reference generator drifted' }
    $expectedBytes = [IO.File]::ReadAllBytes($expectedPath)
    if (-not (Bytes-Equal $expectedBytes ([Text.UTF8Encoding]::new($false).GetBytes([string]$contract.expectedStdout)))) { $currentFailureId = 'EXPECTED_STDOUT_AUTHORITY_MISMATCH'; throw 'Zstandard expected stdout file differs from the contract bytes' }
    $inventoryText = [IO.File]::ReadAllText($fixtureInventoryPath)
    $runnerText = [IO.File]::ReadAllText($exampleRunnerSourcePath)
    if (-not $inventoryText.Contains('"1753-zstd-fse-huffman-weights"', [StringComparison]::Ordinal) -or -not $runnerText.Contains('EnumerateFiles(expectedDir, "*.stdout.txt")', [StringComparison]::Ordinal)) { $currentFailureId = 'FIXTURE_INVENTORY_MISSING'; throw '1753 is not registered in the native exact fixture inventory and ExampleTests discovery authority' }

    $pwshPath = @((Get-Command pwsh -CommandType Application -ErrorAction Stop))[0].Source
    foreach ($source in @($zstdSource, $huffmanSource, $fseSource, $fixturePath)) {
        $id = 'format-' + [IO.Path]::GetFileNameWithoutExtension($source)
        $format = Invoke-Captured $id $pwshPath @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $source)
        Require-Success $format 'FORMAT_FAILED' -RejectDiagnostics
    }
    $huffmanText = [IO.File]::ReadAllText($huffmanSource)
    $zstdText = [IO.File]::ReadAllText($zstdSource)
    foreach ($required in @('import std.compress.zstd.fse as fse', 'decodeFseWeights', 'fse.parseDescription(input, offset, encodedBytes, 12, 6)', 'public parseDescription')) { if (-not $huffmanText.Contains($required, [StringComparison]::Ordinal)) { $currentFailureId = 'IMPLEMENTATION_INVARIANT_MISSING'; throw "Zstandard Huffman implementation is missing: $required" } }
    if ($huffmanText.Contains('UnsupportedFseWeights', [StringComparison]::Ordinal) -or $zstdText.Contains('errors.Kind.UnsupportedCompressedBlock', [StringComparison]::Ordinal) -or (@($contract.unsupported) -join ',') -cne 'dictionaries') { $currentFailureId = 'UNSUPPORTED_BOUNDARY_DRIFT'; throw 'Zstandard unsupported capability boundary drifted' }
    $fixtureText = [IO.File]::ReadAllText($fixturePath)
    foreach ($required in @('terminalZeroBit', 'fse.fromNormalized', 'fse.decodeReverse', 'fse.parseDescription', 'huffman.parseDescription', 'error.offset == expectedOffset', 'withByte(14, 255)', 'withByte(70, 0)', 'withByte(70, 255)', 'weightTwelve', 'symbolBoundRejected')) {
        if (-not $fixtureText.Contains($required, [StringComparison]::Ordinal)) { $currentFailureId = 'MALFORMED_MATRIX_FIXTURE_INVARIANT_MISSING'; throw "Zstandard malformed boundary fixture is missing: $required" }
    }

    $auditLlvmSource = $null
    foreach ($optimization in @('O0', 'O2')) {
        $check = @($record.managed.checks | Where-Object optimization -CEQ $optimization)[0]
        try {
            $artifact = Join-Path $output "1753-$optimization.exe"
            $compile = Invoke-Compiler "1753-$optimization-compile" @('build', $fixturePath, '-o', $artifact, '--target', 'windows-x64', '--llvm', $llvmRoot, "-$optimization", '--keep-temps')
            Require-Success $compile "MANAGED_${optimization}_COMPILE_FAILED" -RejectDiagnostics
            $stem = [IO.Path]::GetFileNameWithoutExtension($artifact)
            $llvm = Join-Path $output "$stem.slg-tmp/$stem.ll"
            if (-not (Test-Path -LiteralPath $llvm -PathType Leaf)) { $currentFailureId = "MANAGED_${optimization}_LLVM_MISSING"; throw "1753 $optimization did not retain LLVM" }
            $closure = Invoke-Captured "1753-$optimization-V004" $pwshPath @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm)
            Require-Success $closure "MANAGED_${optimization}_V004_FAILED" -RejectDiagnostics
            $bitcode = Join-Path $output "$stem.bc"
            $assembly = Invoke-Captured "1753-$optimization-llvm-as" $llvmAs @($llvm, '-o', $bitcode)
            Require-Success $assembly "MANAGED_${optimization}_LLVM_AS_FAILED" -RejectDiagnostics
            $execution = Invoke-Captured "1753-$optimization-native" $artifact @()
            Require-Success $execution "MANAGED_${optimization}_NATIVE_FAILED"
            if (-not (Bytes-Equal $execution.Capture.StdoutBytes $expectedBytes)) { $currentFailureId = "MANAGED_${optimization}_STDOUT_BYTES_MISMATCH"; throw "1753 $optimization raw stdout differs from the expected bytes" }
            $check.status = 'passed'; $check.nativeStdoutSha256 = $execution.Artifact.stdoutSha256; $check.nativeStdoutBytes = $execution.Artifact.stdoutBytes
            $check.llvmSha256 = Hash $llvm; $check.bitcodeSha256 = Hash $bitcode; $check.executableSha256 = Hash $artifact
            if ($optimization -ceq 'O0') { $auditLlvmSource = $llvm }
            $record.managed.completed++; $record.completed++
        } catch { $check.status = 'failed'; throw }
    }
    $record.malformedMatrix.completed = 11; $record.malformedMatrix.status = 'passed'

    $referenceInput = Join-Path $output 'reference.zst'
    $referenceOutput = Join-Path $output 'reference.decoded'
    [IO.File]::WriteAllBytes($referenceInput, $encoded)
    $zstdVersion = Invoke-Captured 'zstd-version' $zstd @('--version')
    Require-Success $zstdVersion 'ZSTD_VERSION_FAILED'
    $versionText = [Text.Encoding]::UTF8.GetString($zstdVersion.Capture.StdoutBytes).Trim()
    if ($versionText -notmatch 'v1\.5\.7\b') { $currentFailureId = 'ZSTD_VERSION_MISMATCH'; throw "Zstandard reference version drifted: $versionText" }
    $reference = Invoke-Captured 'zstd-independent-decode' $zstd @('-q', '-d', '-f', $referenceInput, '-o', $referenceOutput)
    Require-Success $reference 'ZSTD_DIFFERENTIAL_FAILED'
    if (-not (Test-Path -LiteralPath $referenceOutput -PathType Leaf) -or (Get-Item -LiteralPath $referenceOutput).Length -ne $contract.reference.decodedLength -or (Hash $referenceOutput) -cne $contract.reference.decodedSha256 -or -not (Bytes-Equal ([IO.File]::ReadAllBytes($referenceOutput)) $expectedDecoded)) { $currentFailureId = 'ZSTD_DIFFERENTIAL_MISMATCH'; throw 'Zstandard independent differential output mismatch' }
    $record.independentZstd.completed = 1; $record.independentZstd.status = 'passed'; $record.independentZstd.sha256 = $record.inputHashesStart.zstd
    $record.independentZstd.version = $versionText; $record.independentZstd.decodedSha256 = Hash $referenceOutput; $record.completed++

    try {
        $recompressionInput = Join-Path $output 'recompression.input'
        [IO.File]::WriteAllBytes($recompressionInput, $expectedDecoded)
        1..([int]$contract.recompression.deterministicRuns) | ForEach-Object {
            $runIndex = $_
            $recompressed = Join-Path $output "recompressed-$runIndex.zst"
            $recompress = Invoke-Captured "zstd-recompress-$runIndex" $zstd @('-q', '-3', '-f', $recompressionInput, '-o', $recompressed)
            Require-Success $recompress 'ZSTD_RECOMPRESSION_PROCESS_FAILED'
            if (-not (Test-Path -LiteralPath $recompressed -PathType Leaf)) { $currentFailureId = 'ZSTD_RECOMPRESSION_OUTPUT_MISSING'; throw "Zstandard recompression run $runIndex did not produce output" }
            $recompressedBytes = [IO.File]::ReadAllBytes($recompressed)
            $recompressedHash = Hash-Bytes $recompressedBytes
            $matchesFrozen = $recompressedBytes.Length -eq [int]$contract.recompression.expectedLength -and $recompressedHash -ceq [string]$contract.recompression.expectedSha256 -and (Bytes-Equal $recompressedBytes $encoded)
            $record.recompression.runs += [ordered]@{ index = $runIndex; encodedBytes = $recompressedBytes.Length; encodedSha256 = $recompressedHash; matchesFrozen = $matchesFrozen }
            if (-not $matchesFrozen) { $currentFailureId = 'ZSTD_RECOMPRESSION_BYTES_MISMATCH'; throw "Zstandard 1.5.7 -3 recompression run $runIndex differs from the frozen vector" }
        }
        if (@($record.recompression.runs.encodedSha256 | Sort-Object -Unique).Count -ne 1) { $currentFailureId = 'ZSTD_RECOMPRESSION_NONDETERMINISTIC'; throw 'Zstandard 1.5.7 -3 recompression was not deterministic' }
        $record.recompression.completed = 1; $record.recompression.status = 'passed'; $record.completed++
    } catch {
        $record.recompression.status = 'failed'; $record.recompression.failureReason = $currentFailureId; throw
    }

    try {
        if ($null -eq $auditLlvmSource -or -not (Test-Path -LiteralPath $auditLlvmSource -PathType Leaf)) { $currentFailureId = 'ALLOCATION_AUDIT_LLVM_MISSING'; throw 'Zstandard allocation audit source LLVM is missing' }
        $auditLl = Join-Path $output '1753-allocation-audit.ll'
        $auditExe = Join-Path $output '1753-allocation-audit.exe'
        $llvmText = [IO.File]::ReadAllText($auditLlvmSource)
        $auditText = $llvmText.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('ptr @sollang_free', 'ptr @audit_free').Replace('@sollang_start()', '@slg_program_main()')
        $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
        [IO.File]::WriteAllText($auditLl, $auditText, [Text.UTF8Encoding]::new($false))
        $auditLink = Invoke-Captured '1753-allocation-audit-link' $clang @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$([int]$contract.allocationAudit.expectedAllocations)", $auditLl, $allocationAuditShim, '-O1', '-o', $auditExe, '-lws2_32', '-lshell32', '-lbcrypt')
        Require-Success $auditLink 'ALLOCATION_AUDIT_LINK_FAILED' -RejectDiagnostics
        $auditRun = Invoke-Captured '1753-allocation-audit-native' $auditExe @()
        $auditStdout = [Text.Encoding]::UTF8.GetString($auditRun.Capture.StdoutBytes)
        $auditStderr = [Text.Encoding]::UTF8.GetString($auditRun.Capture.StderrBytes)
        $match = [regex]::Match($auditStdout, 'allocations=(?<allocations>\d+),releases=(?<releases>\d+)\r?\n\z', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
        if (-not $match.Success) { $currentFailureId = 'ALLOCATION_AUDIT_OUTPUT_INVALID'; throw 'Zstandard allocation audit did not emit its structured count line' }
        $record.allocationAudit.allocations = [int]$match.Groups['allocations'].Value
        $record.allocationAudit.releases = [int]$match.Groups['releases'].Value
        $record.allocationAudit.invalidReleases = [regex]::Matches($auditStderr, 'invalid release:', [Text.RegularExpressions.RegexOptions]::CultureInvariant).Count
        $expectedPrefix = [Text.Encoding]::UTF8.GetString($expectedBytes)
        if (-not $auditStdout.StartsWith($expectedPrefix, [StringComparison]::Ordinal)) { $currentFailureId = 'ALLOCATION_AUDIT_PROGRAM_STDOUT_MISMATCH'; throw 'Zstandard allocation audit program output differs from the exact expected prefix' }
        if ($auditRun.Capture.OrphanProcessIds.Count -ne 0) { $currentFailureId = 'ALLOCATION_AUDIT_ORPHAN_PROCESS'; throw 'Zstandard allocation audit left descendant processes' }
        if ($record.allocationAudit.allocations -gt [int]$contract.allocationAudit.maximumAllocations) { $currentFailureId = 'ALLOCATION_AUDIT_BOUND_EXCEEDED'; throw 'Zstandard allocation audit exceeded the bounded allocation contract' }
        if ($auditRun.Capture.ExitCode -ne 0 -or $auditRun.Capture.StderrBytes.Length -ne 0 -or $record.allocationAudit.allocations -ne [int]$contract.allocationAudit.expectedAllocations -or $record.allocationAudit.releases -ne [int]$contract.allocationAudit.expectedReleases -or $record.allocationAudit.invalidReleases -ne [int]$contract.allocationAudit.expectedInvalidReleases) { $currentFailureId = 'ALLOCATION_AUDIT_COUNTS_MISMATCH'; throw "Zstandard allocation audit mismatch: exit=$($auditRun.Capture.ExitCode) allocations=$($record.allocationAudit.allocations) releases=$($record.allocationAudit.releases) invalid=$($record.allocationAudit.invalidReleases) stderrBytes=$($auditRun.Capture.StderrBytes.Length)" }
        $record.allocationAudit.completed = 1; $record.allocationAudit.status = 'passed'; $record.completed++
    } catch { $record.allocationAudit.status = 'failed'; throw }
} catch {
    $failure = $_
    if ($record.independentZstd.status -eq 'not-run' -and $currentFailureId -like 'ZSTD_*') { $record.independentZstd.status = 'failed' }
    if ($record.failureIds -notcontains $currentFailureId) { $record.failureIds += $currentFailureId }
} finally {
    $record.inputHashesEnd = Get-InputSnapshot $inputPaths
    $record.compilerSha256End = $record.inputHashesEnd.compiler
    $allKeys = @($record.inputHashesStart.Keys) + @($record.inputHashesEnd.Keys) | Sort-Object -Unique
    foreach ($key in $allKeys) { if ($record.inputHashesStart[$key] -cne $record.inputHashesEnd[$key]) { $record.inputDrift += $key } }
    $record.inputDrift = @($record.inputDrift | Sort-Object -Unique); $record.inputStable = $record.inputDrift.Count -eq 0
    if (-not $record.inputStable -and $record.failureIds -notcontains 'INPUT_DRIFT') { $record.failureIds += 'INPUT_DRIFT' }
    $record.processAudit.rootProcessIds = @($record.processAudit.rootProcessIds | Sort-Object -Unique)
    $record.processAudit.descendantProcessIds = @($record.processAudit.descendantProcessIds | Sort-Object -Unique)
    $record.processAudit.orphanProcessIds = @($record.processAudit.orphanProcessIds | Sort-Object -Unique)
    if ($record.processAudit.orphanProcessIds.Count -ne 0 -and $record.failureIds -notcontains 'ORPHAN_PROCESS') { $record.failureIds += 'ORPHAN_PROCESS' }
    $record.failureIds = @($record.failureIds | Sort-Object -Unique)
    $record.status = if ($record.completed -eq 5 -and $record.inputStable -and $record.processAudit.orphanProcessIds.Count -eq 0 -and $record.failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    Save-Result
    Write-Host "[Zstandard FSE Huffman focused] $($record.status) $($record.completed)/$($record.total); result=$(Join-Path $output 'result.json')"
}

if ($record.status -ne 'passed') {
    if ($null -ne $failure) { throw $failure }
    throw "Zstandard FSE Huffman focused failed: $($record.failureIds -join ', ')"
}
