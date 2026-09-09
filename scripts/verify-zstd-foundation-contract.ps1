[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\zstd-foundation.json"
$schemaPath = Join-Path $root "scripts\contracts\zstd-foundation.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "Zstandard foundation contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
foreach ($relativePath in $contract.sources) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Zstandard source is missing: $path"
    }
}
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
$compressedLiteralFixturePath = Join-Path $root "examples\regression\$($contract.compressedLiteralFixture).slg"
$compressedLiteralExpectedPath = Join-Path $root "examples\regression\expected\$($contract.compressedLiteralFixture).stdout.txt"
$huffmanFixturePath = Join-Path $root "examples\regression\$($contract.huffmanFixture).slg"
$huffmanExpectedPath = Join-Path $root "examples\regression\expected\$($contract.huffmanFixture).stdout.txt"
$fseFixturePath = Join-Path $root "examples\regression\$($contract.fseFixture).slg"
$fseExpectedPath = Join-Path $root "examples\regression\expected\$($contract.fseFixture).stdout.txt"
$sequenceFixturePath = Join-Path $root "examples\regression\$($contract.sequenceFixture).slg"
$sequenceExpectedPath = Join-Path $root "examples\regression\expected\$($contract.sequenceFixture).stdout.txt"
$compressedFseFixturePath = Join-Path $root "examples\regression\$($contract.compressedFseFixture).slg"
$compressedFseExpectedPath = Join-Path $root "examples\regression\expected\$($contract.compressedFseFixture).stdout.txt"
$hashFixturePath = Join-Path $root "examples\regression\$($contract.hashFixture).slg"
$hashExpectedPath = Join-Path $root "examples\regression\expected\$($contract.hashFixture).stdout.txt"
foreach ($path in @($fixturePath, $expectedPath, $compressedLiteralFixturePath, $compressedLiteralExpectedPath, $huffmanFixturePath, $huffmanExpectedPath, $fseFixturePath, $fseExpectedPath, $sequenceFixturePath, $sequenceExpectedPath, $compressedFseFixturePath, $compressedFseExpectedPath, $hashFixturePath, $hashExpectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Zstandard evidence is missing: $path"
    }
}

$sourcePath = Join-Path $root $contract.sources[0]
$source = [System.IO.File]::ReadAllText($sourcePath)
foreach ($required in @(
    "public struct Limits",
    "maxEncodedBytes: Int",
    "maxDecodedBytes: Int",
    "maxWindowBytes: Int",
    "maxFrames: Int",
    "maxSkippableFrameBytes: Int",
    "public struct FrameOptions",
    "checksum: Bool",
    "public struct Codec",
    "public struct Encoder",
    "public struct Decoder",
    "compressedBlock: [UInt8; ~]",
    "public codec: self, frame: FrameOptions",
    "public encoder: self, expectedInputBytes: Int",
    "public decoder: self",
    "public compress: self, input: [UInt8]",
    "public decompress: self, input: [UInt8]",
    "public write: mut self, input: [UInt8], output: mut [UInt8; ~]",
    "public finish: move self, output: mut [UInt8; ~]",
    "public write: mut self, input: [UInt8]",
    "errors.Kind.UnsupportedCompressedBlock",
    "decodeCompressedBlock",
    "decodeHuffmanStreams",
    "huffman.parseDirectDescription",
    "import std.compress.zstd.fse as fse",
    "import std.compress.zstd.sequence as sequence",
    "hasHuffmanTable: Bool",
    "literalLengthTable: fse.Table",
    "offsetTable: fse.Table",
    "matchLengthTable: fse.Table",
    "recentOffset1: Int",
    "finishSequenceBlock",
    "phases.Phase.BlockCompressed",
    "errors.Kind.UnsupportedDictionary",
    "errors.Kind.ChecksumMismatch",
    "import std.hash.xxhash64 as xxhash64",
    "decoder.frameHash -> writeByte(byte)",
    "output -> appendChecksum(self.hash -> checksum)"
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard implementation is missing: $required"
    }
}
foreach ($forbidden in @("public encoder expected", "public decoder:", "public compress input", "public decompress input")) {
    if ($source -cmatch "(?m)^$([regex]::Escape($forbidden))") {
        throw "Zstandard stateful operation escaped its natural instance: $forbidden"
    }
}
$decoderDeclaration = [regex]::Match($source, '(?ms)^public struct Decoder \{(?<body>.*?)^\}')
if (-not $decoderDeclaration.Success) {
    throw "Zstandard decoder declaration is missing"
}
if ($decoderDeclaration.Groups['body'].Value.Contains('encodedInput:', [System.StringComparison]::Ordinal)) {
    throw "Zstandard decoder must not retain the complete encoded input"
}
if ($source.Contains('errors.Kind.UnsupportedChecksum', [System.StringComparison]::Ordinal)) {
    throw "Zstandard checksum support regressed to an unsupported capability"
}

$compressedLiteralFixture = [System.IO.File]::ReadAllText($compressedLiteralFixturePath)
foreach ($required in @(
    "decodeBytewise",
    "rawLiteralsFrame",
    "rleLiteralsFrame",
    "mediumHeaderFrame",
    "longHeaderFrame",
    "boundedCodec -> rejects(longHeaderFrame, 2)? => outputLimit",
    "fseWeightFrame",
    "sequenceFrame",
    '"zstd-compressed-raw=$(rawDecoded)"',
    '"zstd-compressed-rle=$(rleDecoded)"',
    '"zstd-size-header-12=$(mediumOutput -> uniform(98, 32))"',
    '"zstd-size-header-20=$(longOutput -> uniform(99, 4_096))"',
    '"zstd-output-limit=$(outputLimit)"',
    "codec -> rejects(fseWeightFrame, 11)? => fseWeightExplicit",
    "codec -> rejects(sequenceFrame, 12)? => sequenceInvalid",
    '"zstd-huffman-explicit=$(fseWeightExplicit)"',
    '"zstd-sequence-invalid=$(sequenceInvalid)"'
)) {
    if (-not $compressedLiteralFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard compressed-literal fixture no longer proves: $required"
    }
}

$fseSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\zstd\fse.slg"))
foreach ($required in @(
    "public struct Table",
    "public struct ReverseBits",
    "public predefinedLiteralLengths",
    "public predefinedOffsets",
    "public predefinedMatchLengths",
    "public fromNormalized",
    "public parseDescription",
    "public decodeReverse",
    "public update: self",
    "public read: mut self")) {
    if (-not $fseSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard FSE implementation is missing: $required"
    }
}
$sequenceSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\zstd\sequence.slg"))
foreach ($required in @(
    "public struct Decoded",
    "sequenceCount",
    "prepareTable",
    "literalLengthBase",
    "matchLengthBase",
    "copyMatch",
    "public decode input:",
    "public resolve: mut self")) {
    if (-not $sequenceSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard sequence implementation is missing: $required"
    }
}
foreach ($fixtureContract in @(
    @{ Path = $fseFixturePath; Markers = @("predefinedLiteralLengths", '"zstd-fse-literals=$(literals -> accuracy),$state0Symbol', '"zstd-fse-reverse=$newestBit,$oldestBit') },
    @{ Path = $sequenceFixturePath; Markers = @("officialPredefined", "repeatedTables", '"zstd-sequence-official=$(officialOutput -> matches(officialExpected))"') },
    @{ Path = $compressedFseFixturePath; Markers = @("sha256.create() => digestHasher!", "digestHasher! -> update(output)", "digestHasher! -> finish => digest", "1_296", '"zstd-compressed-fse=$valid"') }
)) {
    $fixtureText = [System.IO.File]::ReadAllText($fixtureContract.Path)
    foreach ($required in $fixtureContract.Markers) {
        if (-not $fixtureText.Contains($required, [System.StringComparison]::Ordinal)) {
            throw "Zstandard entropy fixture no longer proves: $required"
        }
    }
}

$huffmanSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\zstd\huffman.slg"))
foreach ($required in @(
    "public struct Table",
    "symbolsByCode: [Int; ~]",
    "maxBits: Int",
    "public parseDirectDescription",
    "public decodeStream",
    "lastWeight",
    "highestSetBit",
    "endBit")) {
    if (-not $huffmanSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard Huffman implementation is missing: $required"
    }
}
if ($huffmanSource -cmatch '(?m)^public\s+decodeStream\s+table:') {
    throw "Zstandard Huffman decoding escaped its Table instance"
}
if ($huffmanSource -notmatch '(?m)^\s+public\s+decodeStream:\s+self,') {
    throw "Zstandard Huffman Table instance decoder is missing"
}
if ($fseSource -cmatch '(?m)^public\s+reverse\s+') {
    throw "Zstandard reverse bitstream parser retained its ambiguous old name"
}
$huffmanFixture = [System.IO.File]::ReadAllText($huffmanFixturePath)
foreach ($required in @(
    "oneStream!",
    "fourStreams!",
    "treeless!",
    "terminalRejected",
    '"zstd-huffman-one=$(oneOutput -> matches(ababa))"',
    '"zstd-huffman-four=$(fourOutput -> matches(fourExpected))"',
    '"zstd-huffman-treeless=$(treelessOutput -> matches(treelessExpected))"',
    '"zstd-huffman-terminal=$(terminalRejected)"')) {
    if (-not $huffmanFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard Huffman fixture no longer proves: $required"
    }
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "decodeBytewise",
    "decoder! -> write(chunk)",
    "skippedThenRaw",
    "finalRaw",
    "rleFrame",
    "checkedFrame",
    'printCheck("checksum"',
    'printCheck("checksum-reject"',
    'printCheck("checksum-transactional"',
    'printCheck("transactional"',
    "import std.compress.zstd.error as zstd_errors",
    "InvalidMagic { 7 }"
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Zstandard fixture no longer proves: $required"
    }
}

$hashSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\hash\xxhash64.slg"))
foreach ($required in @(
    "public struct Seed",
    "public struct Hasher",
    "buffer: [UInt8; 32]",
    "public hasher: self",
    "public writeByte: mut self",
    "public write: mut self",
    "public checksum: self")) {
    if (-not $hashSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "XXH64 implementation is missing: $required"
    }
}
if ($hashSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "XXH64 hasher must not retain a growable copy of complete input"
}
$hashFixture = [System.IO.File]::ReadAllText($hashFixturePath)
foreach ($required in @(
    "17241709254077376921",
    "4952883123889572249",
    "stripeHash % 4_294_967_296",
    "split! -> write")) {
    if (-not $hashFixture.Contains($required, [System.StringComparison]::Ordinal) -and
        -not [System.IO.File]::ReadAllText($hashExpectedPath).Contains($required, [System.StringComparison]::Ordinal)) {
        throw "XXH64 fixture no longer proves: $required"
    }
}

$nativeBatch = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"))
foreach ($fixtureName in @($contract.fixture, $contract.compressedLiteralFixture, $contract.huffmanFixture, $contract.fseFixture, $contract.sequenceFixture, $contract.compressedFseFixture, $contract.hashFixture)) {
    if (-not $nativeBatch.Contains($fixtureName, [System.StringComparison]::Ordinal)) {
        throw "native exact batch does not retain $fixtureName"
    }
}
foreach ($gateName in @(
    "verify-selfhost-stage2.ps1",
    "verify-selfhost-stage3.ps1",
    "verify-selfhost-stage2-linux.ps1",
    "verify-selfhost-stage3-linux.ps1"
)) {
    $gate = [System.IO.File]::ReadAllText((Join-Path $root "scripts\$gateName"))
    if (-not $gate.Contains("verify-zstd-foundation-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the Zstandard contract preflight"
    }
    if (-not $gate.Contains("verify-native-exact-fixture-batch.ps1", [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.fixture, [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.compressedLiteralFixture, [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.huffmanFixture, [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.fseFixture, [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.sequenceFixture, [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.compressedFseFixture, [System.StringComparison]::Ordinal) -or
        -not $nativeBatch.Contains($contract.hashFixture, [System.StringComparison]::Ordinal)) {
        throw "$gateName does not retain every contracted Zstandard fixture"
    }
}

Write-Host "[Zstandard foundation contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, including predefined, RLE, compressed, and repeat FSE fixtures."
