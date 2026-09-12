[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = 'artifacts/scratch/portable-memory-io/contract'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/portable-memory-io.json'
$schemaPath = Join-Path $root 'scripts/contracts/portable-memory-io.schema.json'
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw 'Portable memory I/O contract does not satisfy its schema'
}
$contract = $contractText | ConvertFrom-Json
if ($contract.completion.requiredUnsupportedCount -ne 0) {
    throw 'Portable memory I/O completion target must require unsupported=0'
}
if ($contract.completion.status -ceq 'complete' -and
    ($contract.unsupported.Count -ne 0 -or $contract.blockers.Count -ne 0)) {
    throw 'Portable memory I/O cannot be complete while unsupported capabilities or blockers remain'
}
if ($contract.completion.status -ceq 'blocked' -and
    ($contract.unsupported.Count -eq 0 -or $contract.blockers.Count -eq 0)) {
    throw 'Portable memory I/O blocked state requires explicit unsupported capabilities and blockers'
}
foreach ($relativePath in $contract.sources) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "Portable memory I/O source is missing: $relativePath"
    }
}
foreach ($fixture in $contract.fixtures) {
    foreach ($relativePath in @(
        "examples/regression/$fixture.slg",
        "examples/regression/expected/$fixture.stdout.txt"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
            throw "Portable memory I/O evidence is missing: $relativePath"
        }
    }
}
foreach ($probe in $contract.focusedProbes) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $probe.source) -PathType Leaf)) {
        throw "Portable memory I/O focused probe is missing: $($probe.source)"
    }
}

$source = [IO.File]::ReadAllText((Join-Path $root 'stdlib/std/io.slg'))
foreach ($required in @(
    'public trait Reader',
    'readInto: mut self, output: mut [UInt8; ~] -> Result<Int, Failure>',
    'public trait Writer',
    'writeRange: mut self, input: ref [UInt8; ~], offset: UIntSize, length: UIntSize -> Result<Int, Failure>',
    'impl Reader for MemoryReader',
    'type Failure = Error',
    'public readInto: mut self, output: mut [UInt8; ~] -> Result<Int, Error>',
    'impl Writer for MemoryWriter',
    'public writeRange: mut self, input: [UInt8], offset: UIntSize, length: UIntSize -> Result<Int, Error>',
    'public readExactInto: mut self, output: mut [UInt8; ~] -> Result<Int, Error>',
    'public writeAll: mut self, input: [UInt8] -> Result<Int, Error>',
    'public struct TransferPolicy',
    'public copy<R, W>: self, reader: mut R, writer: mut W -> Result<CopyOutcome, Error>',
    'where R: Reader, R.Failure == Error, W: Writer, W.Failure == Error',
    'public struct ReplayBuffer',
    'public replayBuffer maxReplayBytes: Int -> Result<ReplayBuffer, Error>',
    'public readExactFrom<R>: mut self, reader: mut R, output: mut [UInt8; ~] -> Result<Int, Error> where R: Reader, R.Failure == Error',
    'public readAll<R>: self, replay: mut ReplayBuffer, reader: mut R -> Result<[UInt8; ~], Error> where R: Reader, R.Failure == Error',
    'self.maxBytes < replay.maxReplayBytes',
    '(self.maxBytes + 1) - (replay -> bufferedBytes)',
    'model.ErrorKind.OutputLimitExceeded',
    'compactPrefix(self.bytes, self.start)',
    'reader -> model.Reader.readInto(self.scratch)',
    'model.ErrorKind.WriteZero',
    'model.CopyCompletion.Limit'
)) {
    if (-not $source.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable memory I/O implementation is missing: $required"
    }
}
$asyncSourcePath = Join-Path $root 'stdlib/std/io/async.slg'
$asyncSource = [IO.File]::ReadAllText($asyncSourcePath)
foreach ($required in @(
    'namespace std.io.async',
    'public readMemoryInto reader: move io.MemoryReader, output: move [UInt8; ~]',
    'public writeMemoryRange writer: move io.MemoryWriter, input: move [UInt8; ~]',
    '-> async Result<ReadSuccess, ReadFailure>',
    '-> async Result<WriteSuccess, WriteFailure>',
    'public struct BufferQueue',
    'public bufferQueue highWatermark: Int, lowWatermark: Int',
    'highWatermark: Int',
    'lowWatermark: Int',
    'producerPaused: Bool',
    'Error.Cancelled',
    'Error.Backpressure',
    'Error.WriteZero',
    'public offer: move self, input: move [UInt8; ~]',
    'public drain: move self, output: move [UInt8; ~]',
    'public intoQueue: move self -> BufferQueue',
    'yield'
)) {
    if (-not $asyncSource.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable asynchronous memory I/O candidate is missing: $required"
    }
}
foreach ($forbidden in @(' -> sleep', 'readIntoAt(', 'receiveInto(')) {
    if ($asyncSource.Contains($forbidden, [StringComparison]::Ordinal)) {
        throw "Portable asynchronous memory I/O must not hide synchronous work or fake suspension: $forbidden"
    }
}
$socketSource = [IO.File]::ReadAllText((Join-Path $root 'stdlib/std/net/socket.slg'))
foreach ($required in @(
    'import std.io as io',
    'impl io.Reader for TcpStream',
    'impl io.Writer for TcpStream',
    'type Failure = SocketError',
    'public readInto: mut self, output: mut [UInt8; ~] -> Result<Int, SocketError> uses Network',
    'self -> receiveInto(output)',
    'public writeRange: mut self, input: ref [UInt8; ~], offset: UIntSize, length: UIntSize -> Result<Int, SocketError> uses Network',
    'self -> sendRange(input, offset, length)'
)) {
    if (-not $socketSource.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable socket I/O adapter is missing: $required"
    }
}
$fileSourcePath = Join-Path $root 'stdlib/std/io/file.slg'
$fileSource = [IO.File]::ReadAllText($fileSourcePath)
foreach ($required in @(
    'public struct ByteReader',
    'file: sysfile.File',
    'offset: UInt64',
    'public byteReader file: move sysfile.File -> ByteReader',
    'impl io.Reader for ByteReader',
    'type Failure = Text',
    'public readInto: mut self, output: mut [UInt8; ~] -> Result<Int, Text> uses File',
    'self.file -> readIntoAt(output, self.offset)? => count',
    'public intoFile: move self -> sysfile.File',
    'public struct ByteWriter',
    'file: sysfile.FileWriter',
    'public byteWriter file: move sysfile.FileWriter -> ByteWriter',
    'impl io.Writer for ByteWriter',
    'public writeRange: mut self, input: ref [UInt8; ~], offset: UIntSize, length: UIntSize -> Result<Int, Text> uses File',
    'self.file -> writeRangeAt(input, offset, length, self.offset)? => count',
    'public intoFileWriter: move self -> sysfile.FileWriter',
    'import std.io.async as asyncio',
    'public struct AsyncReadSuccess',
    'public struct AsyncReadFailure',
    'public struct AsyncWriteSuccess',
    'public struct AsyncWriteFailure',
    'public readIntoAsync: move self, output: move [UInt8; ~], cancellation: asyncio.Cancellation',
    'readIntoAtAsync(output, currentOffset, cancellation.requested) -> await',
    'public writeRangeAsync: move self, input: move [UInt8; ~], offset: UIntSize, length: UIntSize, cancellation: asyncio.Cancellation',
    'writeRangeAtAsync(input, offset, length, currentOffset, cancellation.requested) -> await',
    'adaptReadCompletion',
    'adaptWriteCompletion'
)) {
    if (-not $fileSource.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable file I/O adapter is missing: $required"
    }
}
if ([regex]::Matches($fileSource, 'self\.offset \+ UInt64\(count\) => self\.offset').Count -ne 2) {
    throw 'Portable file adapters must advance each explicit position exactly once after successful progress'
}
$sysFilePath = Join-Path $root 'stdlib/sys/file.slg'
$sysFileSource = [IO.File]::ReadAllText($sysFilePath)
foreach ($required in @(
    'public readIntoAt: self, output: mut [UInt8; ~], offset: UInt64 -> Result<UIntSize, Text> uses File = intrinsic',
    'public writeRangeAt: self, input: ref [UInt8; ~], inputOffset: UIntSize, length: UIntSize, offset: UInt64 -> Result<UIntSize, Text> uses File = intrinsic',
    'public enum AsyncTransferError',
    'Io(Text)',
    'public struct ReadAtSuccess',
    'public struct ReadAtFailure',
    'public struct WriteAtSuccess',
    'public struct WriteAtFailure',
    'public readIntoAtAsync: move self, output: move [UInt8; ~], offset: UInt64, cancelled: Bool -> async Result<ReadAtSuccess, ReadAtFailure> uses File = intrinsic',
    'public writeRangeAtAsync: move self, input: move [UInt8; ~], inputOffset: UIntSize, length: UIntSize, offset: UInt64, cancelled: Bool -> async Result<WriteAtSuccess, WriteAtFailure> uses File = intrinsic'
)) {
    if (-not $sysFileSource.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable file I/O intrinsic surface is missing: $required"
    }
}
$managedSemantic = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'))
$managedEmitter = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.RuntimeIntrinsics.cs'))
$managedStructsPath = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Structs.cs'
$managedStructs = [IO.File]::ReadAllText($managedStructsPath)
$selfhostTyped = [IO.File]::ReadAllText((Join-Path $root 'selfhost/ir/typed.slg'))
$selfhostEmitter = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/platform_io.slg'))
$selfhostRuntime = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/runtime.slg'))
$selfhostContext = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/context_prepare.slg'))
foreach ($check in @(
    @{ Text = $managedSemantic; Needle = '"sys.file.File.readIntoAt" => RequireFileReadIntoAtSignature' },
    @{ Text = $managedSemantic; Needle = '"sys.file.FileWriter.writeRangeAt" => RequireFileWriteRangeAtSignature' },
    @{ Text = $managedEmitter; Needle = 'EmitRuntimeReadBytesAt(function, file, arguments)' },
    @{ Text = $managedEmitter; Needle = 'EmitRuntimeWriteBytesAt(function, file, arguments)' },
    @{ Text = $managedEmitter; Needle = 'EmitUIntSizeFromI64(count)' },
    @{ Text = $managedSemantic; Needle = '"sys.file.File.readIntoAtAsync" => RequireFileReadIntoAtSignature' },
    @{ Text = $managedSemantic; Needle = '"sys.file.FileWriter.writeRangeAtAsync" => RequireFileWriteRangeAtSignature' },
    @{ Text = $managedEmitter; Needle = 'EmitRuntimeReadBytesAtAsync' },
    @{ Text = $managedEmitter; Needle = 'EmitRuntimeWriteBytesAtAsync' },
    @{ Text = $managedEmitter; Needle = 'EmitAsyncFileBufferCancelFunctions' },
    @{ Text = $managedEmitter; Needle = 'EmitRuntimeErrorText("io")' },
    @{ Text = $managedStructs; Needle = 'CollectOwnedLiteralTransfers' },
    @{ Text = $managedStructs; Needle = 'DropOwnedStructFieldsExceptMovedAndTransferred(ownerName, owner, transferredPaths)' },
    @{ Text = $selfhostTyped; Needle = '-> if { -304 => opcode! }' },
    @{ Text = $selfhostTyped; Needle = '-> if { -305 => opcode! }' },
    @{ Text = $selfhostEmitter; Needle = 'call.opcode == -304 or call.opcode == -305' },
    @{ Text = $selfhostEmitter; Needle = '@sollang_platform_read_owned_file_at' },
    @{ Text = $selfhostEmitter; Needle = '@sollang_platform_write_owned_file_at' },
    @{ Text = $selfhostEmitter; Needle = '@sollang_file_error_range' },
    @{ Text = $selfhostEmitter; Needle = '_file_buffer_count32 = trunc i64' },
    @{ Text = $selfhostRuntime; Needle = 'public emitWasmOwnedFile:' },
    @{ Text = $selfhostContext; Needle = 'needsOwnedFileRuntime -> if { llvmRuntime.emitWasmOwnedFile() }' }
)) {
    if (-not $check.Text.Contains($check.Needle, [StringComparison]::Ordinal)) {
        throw "Portable file I/O managed/self-host lowering is missing: $($check.Needle)"
    }
}
$windowsRuntime = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'))
$linuxRuntime = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'))
$browserRuntime = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/CodeGen/WasmBrowserLlvmRuntimePlatform.cs'))
if (-not $windowsRuntime.Contains('%eof = icmp eq i32 %error, 38', [StringComparison]::Ordinal)) {
    throw 'Windows positional file reads must classify ERROR_HANDLE_EOF as successful zero progress'
}
foreach ($required in @('call i64 @pread(', 'call i64 @pwrite(')) {
    if (-not $linuxRuntime.Contains($required, [StringComparison]::Ordinal)) {
        throw "Linux positional file I/O lowering is missing: $required"
    }
}
foreach ($required in @(
    'define internal i32 @sollang_platform_sync_owned_file',
    'define internal %sollang.file_count_result @sollang_platform_read_owned_file_at',
    'define internal %sollang.file_count_result @sollang_platform_write_owned_file_at',
    '%fail1 = insertvalue %sollang.file_count_result %fail0, i32 0, 1'
)) {
    if (-not $browserRuntime.Contains($required, [StringComparison]::Ordinal)) {
        throw "Browser file I/O must retain an explicit unavailable result: $required"
    }
}
if ([regex]::Matches($source, '(?m)^public trait Reader \{').Count -ne 1 -or
    [regex]::Matches($source, '(?m)^public trait Writer \{').Count -ne 1) {
    throw 'Portable memory I/O must declare exactly one public Reader and Writer protocol'
}
foreach ($forbidden in @('public readAll: ', 'ReplayReader', 'BufferedReader', 'BufferedWriter')) {
    if ($source.Contains($forbidden, [StringComparison]::Ordinal)) {
        throw "Portable memory I/O published an unsupported unbounded or buffered surface: $forbidden"
    }
}

$fixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1680-io-shared-caller-buffer-traits.slg'))
foreach ($required in @(
    'reader! -> io.Reader.readInto(output!)',
    'writer! -> io.Writer.writeRange(output!, 0, UIntSize(output! -> len))',
    'read=$readCount,$(output![0]),$(output![1]),$(output![2]),pos=$(reader! -> position)',
    'write=$writeCount,$(written[0]),$(written[1])'
)) {
    if (-not $fixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable memory I/O fixture no longer proves: $required"
    }
}
$copyFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1683-io-bounded-transfer-policy.slg'))
foreach ($required in @(
    'impl io.Writer for ChunkWriter',
    'impl io.Writer for ZeroWriter',
    'completePolicy -> copy(completeReader!, completeWriter!)',
    'limitedPolicy -> copy(limitedReader!, limitedWriter!)',
    'WriteZero',
    'io.transferPolicy(1, 0)'
)) {
    if (-not $copyFixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable memory I/O copy fixture no longer proves: $required"
    }
}
$replayFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1684-io-bounded-transactional-replay.slg'))
foreach ($required in @(
    'impl io.Reader for ChunkReader',
    'impl io.Reader for InvalidReader',
    'io.replayBuffer(4)',
    'replay! -> readExactFrom(source!, oversized!)',
    'replay! -> readExactFrom(source!, short!)',
    'replay! -> readExactFrom(source!, retained!)',
    'bounded! -> readExactFrom(boundedSource!, exact!)',
    'invalid! -> readExactFrom(invalidSource!, invalidOutput!)'
)) {
    if (-not $replayFixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable memory I/O replay fixture no longer proves: $required"
    }
}
$readAllFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1689-io-bounded-transactional-read-all.slg'))
foreach ($required in @(
    'narrow -> readAll(replay!, source!)',
    'complete -> readAll(replay!, source!)',
    'OutputLimitExceeded',
    'invalidPolicy -> readAll(invalidReplay!, untouched!)',
    'emptyPolicy -> readAll(emptyReplay!, emptySource!)'
)) {
    if (-not $readAllFixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable bounded read-all fixture no longer proves: $required"
    }
}
$socketFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1685-io-socket-protocol-adapters.slg'))
foreach ($required in @(
    'stream! -> io.Writer.writeRange(bytes!, 2, 4)',
    'stream! -> io.Reader.readInto(received!)',
    'Result<UIntSize, socket.SocketError>',
    'Result<Bool, socket.SocketError>'
)) {
    if (-not $socketFixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable socket I/O fixture no longer proves: $required"
    }
}
$fileFixture = [IO.File]::ReadAllText((Join-Path $root 'examples/regression/1688-io-file-protocol-adapters.slg'))
foreach ($required in @(
    'writer! -> io.Writer.writeRange(bytes!, 1, 4)? => written',
    'writer! -> io.Writer.writeRange(bytes!, 5, 4)',
    'reader! -> io.Reader.readInto(output!)? => first',
    'reader! -> io.Reader.readInto(output!)? => second',
    'writer! -> intoFileWriter => rawWriter',
    'reader! -> intoFile => rawFile',
    'file-protocol=$writePosition,$(read.first),$(read.firstByte),$(read.lastByte),$(read.tailA),$(read.tailB),$(read.second),$(read.position)'
)) {
    if (-not $fileFixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable file I/O fixture no longer proves: $required"
    }
}
$fileBrowserExpected = [IO.File]::ReadAllText(
    (Join-Path $root 'examples/regression/expected/1688-io-file-protocol-adapters.browser.stdout.txt')).Trim()
if ($fileBrowserExpected -cne 'file-error=io') {
    throw 'Portable file I/O browser expectation must expose the unavailable native capability as io'
}

$spec = [IO.File]::ReadAllText((Join-Path $root 'docs/SPEC.md'))
$evolution = [IO.File]::ReadAllText((Join-Path $root 'docs/STDLIB_EVOLUTION.md'))
foreach ($required in @('`std.io.Reader`', '`std.io.Writer`')) {
    if (-not $spec.Contains($required, [StringComparison]::Ordinal)) {
        throw "Sollang specification is missing portable memory I/O contract: $required"
    }
}
if ($spec -notmatch 'associated\s+failure') {
    throw 'Sollang specification is missing the associated portable failure contract'
}
if ($evolution -notmatch 'shared\s+`Reader` and `Writer`\s+protocols') {
    throw 'stdlib evolution backlog is missing shared portable memory I/O protocol status'
}

$nativeBatch = [IO.File]::ReadAllText((Join-Path $root 'scripts/verify-native-exact-fixture-batch.ps1'))
foreach ($fixtureName in $contract.fixtures) {
    if (-not $nativeBatch.Contains($fixtureName, [StringComparison]::Ordinal)) {
        throw "native exact batch does not retain $fixtureName"
    }
}
$browserBatch = [IO.File]::ReadAllText((Join-Path $root 'scripts/build-stage2-browser.ps1'))
if (-not $browserBatch.Contains('1688-io-file-protocol-adapters.browser.stdout.txt', [StringComparison]::Ordinal)) {
    throw 'browser Stage2 regression list does not retain the explicit file-capability failure fixture'
}
if (-not $browserBatch.Contains('1689-io-bounded-transactional-read-all.stdout.txt', [StringComparison]::Ordinal)) {
    throw 'browser Stage2 regression list does not retain bounded transactional read-all'
}
foreach ($gateName in @(
    'verify-selfhost-stage2.ps1',
    'verify-selfhost-stage3.ps1',
    'verify-selfhost-stage2-linux.ps1',
    'verify-selfhost-stage3-linux.ps1'
)) {
    $gate = [IO.File]::ReadAllText((Join-Path $root "scripts/$gateName"))
    if (-not $gate.Contains('verify-portable-memory-io-contract.ps1', [StringComparison]::Ordinal)) {
        throw "$gateName does not run the portable memory I/O contract preflight"
    }
}

$compilerPath = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvmAsPath = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$closureVerifierPath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
    throw 'Managed compiler is missing for portable memory I/O focused probes'
}
foreach ($toolPath in @($llvmAsPath, $closureVerifierPath)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "Portable memory I/O independent LLVM gate is missing: $toolPath"
    }
}
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
}
[IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null

$formatSources = @($asyncSourcePath, $sysFilePath, $fileSourcePath) + @($contract.focusedProbes | ForEach-Object { Join-Path $root $_.source })
$formatLog = (& dotnet $compilerPath format --check @formatSources 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "Portable memory I/O authoritative format failed:`n$formatLog"
}

$probeResults = @()
foreach ($probe in $contract.focusedProbes) {
    $probePath = Join-Path $root $probe.source
    $target = if ($null -ne $probe.PSObject.Properties['target']) { $probe.target } else { 'windows-x64' }
    $extension = if ($target -ceq 'wasm32-browser') { '.wasm' } elseif ($target -ceq 'linux-x64') { '' } else { '.exe' }
    $executable = Join-Path $resolvedOutput "$($probe.id)$extension"
    $compileArguments = @($compilerPath, 'build', $probePath, '-o', $executable, '--keep-temps', '-O0')
    if ($target -cne 'windows-x64') {
        $compileArguments += @('--target', $target)
    }
    $compileLog = (& dotnet @compileArguments 2>&1) -join "`n"
    $compileExitCode = $LASTEXITCODE
    $llvmAsExitCode = $null
    $closureExitCode = $null
    $llvmSha256 = $null
    $bitcodeSha256 = $null
    if ($probe.expectation -ceq 'compiler-rejected') {
        $log = $compileLog
        $exitCode = $compileExitCode
    } else {
        if ($compileExitCode -ne 0) {
            throw "Portable memory I/O executable probe did not compile: $($probe.id):`n$compileLog"
        }
        $llvmPath = [IO.Path]::ChangeExtension($executable, '.ll')
        $bitcodePath = [IO.Path]::ChangeExtension($executable, '.bc')
        if (-not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
            throw "Portable memory I/O successful probe emitted no LLVM: $($probe.id)"
        }
        $assemblyLog = (& $llvmAsPath $llvmPath -o $bitcodePath 2>&1) -join "`n"
        $llvmAsExitCode = $LASTEXITCODE
        if ($llvmAsExitCode -ne 0 -or $assemblyLog.Length -ne 0) {
            throw "Portable memory I/O llvm-as failed for $($probe.id):`n$assemblyLog"
        }
        $closureLog = (& $closureVerifierPath -LlvmPath $llvmPath 6>&1) -join "`n"
        $closureExitCode = if ($?) { 0 } else { 1 }
        if ($closureExitCode -ne 0) {
            throw "Portable memory I/O V004 direct-call closure failed for $($probe.id):`n$closureLog"
        }
        $llvmSha256 = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
        $bitcodeSha256 = (Get-FileHash -LiteralPath $bitcodePath -Algorithm SHA256).Hash
        if ($target -ceq 'linux-x64') {
            if ($executable -notmatch '^([A-Za-z]):\\(.*)$') {
                throw "Portable memory I/O Linux executable path is not a Windows drive path: $executable"
            }
            $drive = $Matches[1].ToLowerInvariant()
            $tail = $Matches[2].Replace('\', '/')
            $linuxExecutable = "/mnt/$drive/$tail"
            $log = (& wsl.exe -e $linuxExecutable 2>&1) -join "`n"
        } else {
            $log = (& $executable 2>&1) -join "`n"
        }
        $exitCode = $LASTEXITCODE
    }
    if ($probe.expectation -ceq 'exact-stdout') {
        if ($exitCode -ne 0) {
            throw "Portable memory I/O positive probe failed: $($probe.id):`n$log"
        }
        $actualLines = @($log -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        $expectedLines = @($probe.expected)
        if (($actualLines -join "`n") -cne ($expectedLines -join "`n")) {
            throw "Portable memory I/O stdout mismatch for $($probe.id):`n$log"
        }
    } elseif ($probe.expectation -ceq 'compiler-rejected') {
        if ($exitCode -eq 0) {
            throw "Portable memory I/O blocker probe unexpectedly succeeded: $($probe.id)"
        }
        foreach ($expected in $probe.expected) {
            if (-not $log.Contains($expected, [StringComparison]::Ordinal)) {
                throw "Portable memory I/O blocker diagnostic drifted for $($probe.id): $expected"
            }
        }
    } elseif ($probe.expectation -ceq 'native-rejected') {
        if ($exitCode.ToString([Globalization.CultureInfo]::InvariantCulture) -cne $probe.expected[0]) {
            throw "Portable memory I/O native blocker exit drifted for $($probe.id): $exitCode"
        }
    } else {
        throw "Unknown portable memory I/O probe expectation: $($probe.expectation)"
    }
    $probeResults += [ordered]@{
        id = $probe.id
        target = $target
        expectation = $probe.expectation
        compileExitCode = $compileExitCode
        exitCode = $exitCode
        llvmAsExitCode = $llvmAsExitCode
        directCallClosureExitCode = $closureExitCode
        sourceSha256 = (Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash
        llvmSha256 = $llvmSha256
        bitcodeSha256 = $bitcodeSha256
        logSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($log)))
    }
}

$inputHashes = [ordered]@{}
foreach ($path in @($contractPath, $schemaPath, $asyncSourcePath, $sysFilePath, $fileSourcePath, $managedStructsPath, $compilerPath, $llvmAsPath, $closureVerifierPath) + $formatSources) {
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$result = [ordered]@{
    schemaVersion = 1
    status = $contract.completion.status
    completed = if ($contract.completion.status -ceq 'complete') {
        4
    } elseif (@($contract.blockers | Where-Object { $_.layer -ceq 'managed-codegen' }).Count -eq 0) {
        3
    } else {
        2
    }
    total = 4
    surfaces = $contract.surfaces.Count
    invariants = $contract.invariants.Count
    fixtures = $contract.fixtures.Count
    unsupported = $contract.unsupported.Count
    blockerIds = @($contract.blockers | ForEach-Object { $_.id })
    compilerSha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
    probes = $probeResults
    inputHashes = $inputHashes
}
$resultPath = Join-Path $resolvedOutput 'result.json'
[IO.File]::WriteAllText(
    $resultPath,
    ($result | ConvertTo-Json -Depth 8) + "`n",
    [Text.UTF8Encoding]::new($false))

Write-Host "[portable memory I/O contract] $($contract.completion.status.ToUpperInvariant()) $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, $($contract.fixtures.Count) fixtures, $($contract.unsupported.Count) unsupported. Result: $resultPath"
