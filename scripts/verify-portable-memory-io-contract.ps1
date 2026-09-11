[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
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
    'compactPrefix(self.bytes, self.start)',
    'reader -> model.Reader.readInto(self.scratch)',
    'model.ErrorKind.WriteZero',
    'model.CopyCompletion.Limit'
)) {
    if (-not $source.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable memory I/O implementation is missing: $required"
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
$fileSource = [IO.File]::ReadAllText((Join-Path $root 'stdlib/std/io/file.slg'))
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
    'public intoFileWriter: move self -> sysfile.FileWriter'
)) {
    if (-not $fileSource.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable file I/O adapter is missing: $required"
    }
}
if ([regex]::Matches($fileSource, 'self\.offset \+ UInt64\(count\) => self\.offset').Count -ne 2) {
    throw 'Portable file adapters must advance each explicit position exactly once after successful progress'
}
$sysFileSource = [IO.File]::ReadAllText((Join-Path $root 'stdlib/sys/file.slg'))
foreach ($required in @(
    'public readIntoAt: self, output: mut [UInt8; ~], offset: UInt64 -> Result<UIntSize, Text> uses File = intrinsic',
    'public writeRangeAt: self, input: ref [UInt8; ~], inputOffset: UIntSize, length: UIntSize, offset: UInt64 -> Result<UIntSize, Text> uses File = intrinsic'
)) {
    if (-not $sysFileSource.Contains($required, [StringComparison]::Ordinal)) {
        throw "Portable file I/O intrinsic surface is missing: $required"
    }
}
$managedSemantic = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'))
$managedEmitter = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.RuntimeIntrinsics.cs'))
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
foreach ($forbidden in @('public readAll:', 'ReplayReader', 'BufferedReader', 'BufferedWriter')) {
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

Write-Host "[portable memory I/O contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixtures $($contract.fixtures -join ', ')."
