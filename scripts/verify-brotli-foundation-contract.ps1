[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\brotli-foundation.json"
$schemaPath = Join-Path $root "scripts\contracts\brotli-foundation.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "Brotli foundation contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
foreach ($relativePath in $contract.sources) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Brotli source is missing: $path"
    }
}
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
$prefixFixturePath = Join-Path $root "examples\regression\$($contract.prefixFixture).slg"
$prefixExpectedPath = Join-Path $root "examples\regression\expected\$($contract.prefixFixture).stdout.txt"
$prefixCodeFixturePath = Join-Path $root "examples\regression\$($contract.prefixCodeFixture).slg"
$prefixCodeExpectedPath = Join-Path $root "examples\regression\expected\$($contract.prefixCodeFixture).stdout.txt"
$prefixDescriptionFixturePath = Join-Path $root "examples\regression\$($contract.prefixDescriptionFixture).slg"
$prefixDescriptionExpectedPath = Join-Path $root "examples\regression\expected\$($contract.prefixDescriptionFixture).stdout.txt"
$complexPrefixDescriptionFixturePath = Join-Path $root "examples\regression\$($contract.complexPrefixDescriptionFixture).slg"
$complexPrefixDescriptionExpectedPath = Join-Path $root "examples\regression\expected\$($contract.complexPrefixDescriptionFixture).stdout.txt"
$complexPrefixRepeatFixturePath = Join-Path $root "examples\regression\$($contract.complexPrefixRepeatFixture).slg"
$complexPrefixRepeatExpectedPath = Join-Path $root "examples\regression\expected\$($contract.complexPrefixRepeatFixture).stdout.txt"
$contextMapFixturePath = Join-Path $root "examples\regression\$($contract.contextMapFixture).slg"
$contextMapExpectedPath = Join-Path $root "examples\regression\expected\$($contract.contextMapFixture).stdout.txt"
$contextMapStreamFixturePath = Join-Path $root "examples\regression\$($contract.contextMapStreamFixture).slg"
$contextMapStreamExpectedPath = Join-Path $root "examples\regression\expected\$($contract.contextMapStreamFixture).stdout.txt"
$treeGroupFixturePath = Join-Path $root "examples\regression\$($contract.treeGroupFixture).slg"
$treeGroupExpectedPath = Join-Path $root "examples\regression\expected\$($contract.treeGroupFixture).stdout.txt"
$treeGroupStreamFixturePath = Join-Path $root "examples\regression\$($contract.treeGroupStreamFixture).slg"
$treeGroupStreamExpectedPath = Join-Path $root "examples\regression\expected\$($contract.treeGroupStreamFixture).stdout.txt"
$compressedHeaderFixturePath = Join-Path $root "examples\regression\$($contract.compressedHeaderFixture).slg"
$compressedHeaderExpectedPath = Join-Path $root "examples\regression\expected\$($contract.compressedHeaderFixture).stdout.txt"
$compressedPreludeFixturePath = Join-Path $root "examples\regression\$($contract.compressedPreludeFixture).slg"
$compressedPreludeExpectedPath = Join-Path $root "examples\regression\expected\$($contract.compressedPreludeFixture).stdout.txt"
$literalContextFixturePath = Join-Path $root "examples\regression\$($contract.literalContextFixture).slg"
$literalContextExpectedPath = Join-Path $root "examples\regression\expected\$($contract.literalContextFixture).stdout.txt"
$commandFixturePath = Join-Path $root "examples\regression\$($contract.commandFixture).slg"
$commandExpectedPath = Join-Path $root "examples\regression\expected\$($contract.commandFixture).stdout.txt"
$commandStreamFixturePath = Join-Path $root "examples\regression\$($contract.commandStreamFixture).slg"
$commandStreamExpectedPath = Join-Path $root "examples\regression\expected\$($contract.commandStreamFixture).stdout.txt"
$commandBlockSwitchFixturePath = Join-Path $root "examples\regression\$($contract.commandBlockSwitchFixture).slg"
$commandBlockSwitchExpectedPath = Join-Path $root "examples\regression\expected\$($contract.commandBlockSwitchFixture).stdout.txt"
$staticDictionaryFixturePath = Join-Path $root "examples\regression\$($contract.staticDictionaryFixture).slg"
$staticDictionaryExpectedPath = Join-Path $root "examples\regression\expected\$($contract.staticDictionaryFixture).stdout.txt"
$blockStreamFixturePath = Join-Path $root "examples\regression\$($contract.blockStreamFixture).slg"
$blockStreamExpectedPath = Join-Path $root "examples\regression\expected\$($contract.blockStreamFixture).stdout.txt"
$headerReaderFixturePath = Join-Path $root "examples\regression\$($contract.headerReaderFixture).slg"
$headerReaderExpectedPath = Join-Path $root "examples\regression\expected\$($contract.headerReaderFixture).stdout.txt"
$contextReaderFixturePath = Join-Path $root "examples\regression\$($contract.contextReaderFixture).slg"
$contextReaderExpectedPath = Join-Path $root "examples\regression\expected\$($contract.contextReaderFixture).stdout.txt"
$treeReaderFixturePath = Join-Path $root "examples\regression\$($contract.treeReaderFixture).slg"
$treeReaderExpectedPath = Join-Path $root "examples\regression\expected\$($contract.treeReaderFixture).stdout.txt"
$commandHistoryFixturePath = Join-Path $root "examples\regression\$($contract.commandHistoryFixture).slg"
$commandHistoryExpectedPath = Join-Path $root "examples\regression\expected\$($contract.commandHistoryFixture).stdout.txt"
$bulkCompressedFixturePath = Join-Path $root "examples\regression\$($contract.bulkCompressedFixture).slg"
$bulkCompressedExpectedPath = Join-Path $root "examples\regression\expected\$($contract.bulkCompressedFixture).stdout.txt"
$decoderCompressedStreamFixturePath = Join-Path $root "examples\regression\$($contract.decoderCompressedStreamFixture).slg"
$decoderCompressedStreamExpectedPath = Join-Path $root "examples\regression\expected\$($contract.decoderCompressedStreamFixture).stdout.txt"
foreach ($path in @(
    $fixturePath,
    $expectedPath,
    $prefixFixturePath,
    $prefixExpectedPath,
    $prefixCodeFixturePath,
    $prefixCodeExpectedPath,
    $prefixDescriptionFixturePath,
    $prefixDescriptionExpectedPath,
    $complexPrefixDescriptionFixturePath,
    $complexPrefixDescriptionExpectedPath,
    $complexPrefixRepeatFixturePath,
    $complexPrefixRepeatExpectedPath,
    $contextMapFixturePath,
    $contextMapExpectedPath,
    $contextMapStreamFixturePath,
    $contextMapStreamExpectedPath,
    $treeGroupFixturePath,
    $treeGroupExpectedPath,
    $treeGroupStreamFixturePath,
    $treeGroupStreamExpectedPath,
    $compressedHeaderFixturePath,
    $compressedHeaderExpectedPath,
    $compressedPreludeFixturePath,
    $compressedPreludeExpectedPath,
    $literalContextFixturePath,
    $literalContextExpectedPath,
    $commandFixturePath,
    $commandExpectedPath,
    $commandStreamFixturePath,
    $commandStreamExpectedPath,
    $commandBlockSwitchFixturePath,
    $commandBlockSwitchExpectedPath,
    $staticDictionaryFixturePath,
    $staticDictionaryExpectedPath,
    $blockStreamFixturePath,
    $blockStreamExpectedPath,
    $headerReaderFixturePath,
    $headerReaderExpectedPath,
    $contextReaderFixturePath,
    $contextReaderExpectedPath,
    $treeReaderFixturePath,
    $treeReaderExpectedPath,
    $commandHistoryFixturePath,
    $commandHistoryExpectedPath,
    $bulkCompressedFixturePath,
    $bulkCompressedExpectedPath,
    $decoderCompressedStreamFixturePath,
    $decoderCompressedStreamExpectedPath
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Brotli evidence is missing: $path"
    }
}

$prefixSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\prefix_table.slg"))
foreach ($required in @(
    "public struct Limits",
    "maxSymbols: Int",
    "maxTableEntries: Int",
    "public struct Builder",
    "public struct Table",
    "public struct Probed",
    "public enum Probe",
    "public struct WindowLimits",
    "public struct Window",
    "public enum BitRead",
    "public builder: self",
    "public table: self, codeLengths: [Int], rootBits: Int",
    "public probe: self, bufferedBits: Int, availableBits: Int",
    "public read: self, input: [UInt8], position: Position",
    "public window: self -> Result<Window, Error>",
    "public available: self -> Int",
    "public fill: mut self, input: [UInt8], position: Position, requiredBits: Int",
    "public read: mut self, width: Int",
    "public symbol: mut self, table: ref Table",
    "self.maxBufferedBits <= 56",
    "model.BitRead.Incomplete",
    "model.BitRead.Complete",
    "model.Probe.NeedMore",
    "model.Probe.Ready",
    "availableBits < bits",
    "NeedMore(bits - availableBits)",
    "consumedBits: Int",
    "self.maxSymbols <= 704",
    "rootBits <= 15",
    "self.maxTableEntries",
    "nextTableBitSize",
    "replicateValue"
)) {
    if (-not $prefixSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli prefix implementation is missing: $required"
    }
}
if ($prefixSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "Brotli prefix table must not retain growable encoded input"
}

$prefixCodeSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\prefix_code.slg"))
foreach ($required in @(
    "public struct Parser",
    "public struct FixedCodeLengthReader",
    "public enum FixedCodeLengthRead",
    "public struct DescriptionReader",
    "public enum DescriptionRead",
    "maxAlphabetSize: Int",
    "maxTableEntries: Int",
    "public parser: self",
    "public fixedCodeLengthReader: self",
    "public descriptionReader: self, alphabetSize: Int, rootBits: Int -> Result<DescriptionReader, Error>",
    "public read: mut self, window: mut prefix.Window",
    "public takeTable: mut self -> Result<prefix.Table, Error>",
    "public intoTable: move self -> Result<prefix.Table, Error>",
    "public parse: self, input: [UInt8], position: prefix.Position, alphabetSize: Int, rootBits: Int",
    "readFixedCodeLength",
    "FixedCodeLengthPhase.Third",
    "FixedCodeLengthPhase.Fourth",
    "true -> while",
    "codeLengthOrder",
    "decoded.symbol == 16",
    "repeat! - oldRepeat",
    "self -> buildTable(codeLengthLengths!, 5)",
    "self -> buildTable(lengths!, rootBits)",
    "model.DescriptionPhase.ComplexSymbols",
    "model.DescriptionPhase.ComplexRepeatBits",
    "window -> symbol(table)",
    "self.pendingRepeatSymbol == 16",
    "self.outputSpace == 0",
    "symbol.value < alphabetSize",
    "Int(encoded) < self.alphabetSize",
    "errors.Kind.InvalidSymbol"
)) {
    if (-not $prefixCodeSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli prefix-code parser is missing: $required"
    }
}
if ($prefixCodeSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "Brotli prefix-code parser must not retain growable encoded input"
}
if ($prefixCodeSource.Contains('self -> read(window)', [System.StringComparison]::Ordinal)) {
    throw "Brotli fixed code-length reader must advance its bounded phase loop without recursive instance dispatch"
}

$contextMapSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\context_map.slg"))
foreach ($required in @(
    "public struct Limits",
    "maxEntries: Int",
    "maxTrees: Int",
    "maxTableEntries: Int",
    "public struct Parser",
    "public struct Parsed",
    "public struct Reader",
    "public enum ReaderRead",
    "public struct Streamed",
    "public parser: self",
    "public reader: self, entryCount: Int -> Result<Reader, Error>",
    "public prefixDescription: self -> Result<prefix_code.DescriptionReader, Error>",
    "public installPrefix: mut self, table: move prefix.Table -> Result<Unit, Error>",
    "public read: mut self, window: mut prefix.Window -> Result<ReaderRead, Error>",
    "public finish: move self -> Result<Streamed, Error>",
    "public takeAndReset: mut self, nextEntryCount: Int -> Result<Streamed, Error>",
    "public parse: self, input: [UInt8], position: prefix.Position, entryCount: Int",
    "self.maxEntries <= 16_384",
    "self.maxTrees <= 256",
    "self.maxTableEntries <= 1_080",
    "maxRunLengthPrefix",
    "inverseMoveToFront",
    "public intoValues: move self",
    "errors.Kind.RunLengthExceeded",
    "errors.Kind.InvalidTreeIndex"
)) {
    if (-not $contextMapSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli context-map parser is missing: $required"
    }
}
if ($contextMapSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "Brotli context-map parser must not retain growable encoded input"
}
$contextReaderDeclaration = [regex]::Match($contextMapSource, '(?ms)^public struct Reader \{(?<body>.*?)^\}')
if (-not $contextReaderDeclaration.Success) {
    throw "Brotli context-map reader declaration is missing"
}
if ($contextReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli context-map reader must retain semantic state, not caller input"
}

$treeGroupSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\tree_group.slg"))
foreach ($required in @(
    "public struct Limits",
    "maxTrees: Int",
    "maxAlphabetSize: Int",
    "maxTableEntries: Int",
    "maxTotalTableEntries: Int",
    "public struct Parser",
    "public struct Parsed",
    "public struct Reader",
    "public enum ReaderRead",
    "public struct Streamed",
    "public parser: self",
    "public reader: self, alphabetSize: Int, treeCount: Int, rootBits: Int -> Result<Reader, Error>",
    "public next: self -> ReaderRead",
    "public prefixDescription: self -> Result<prefix_code.DescriptionReader, Error>",
    "public installTree: mut self, table: move prefix.Table -> Result<Unit, Error>",
    "public finish: move self -> Result<Streamed, Error>",
    "public takeAndReset: mut self, alphabetSize: Int, treeCount: Int, rootBits: Int -> Result<Streamed, Error>",
    "public parse: self, input: [UInt8], position: prefix.Position, alphabetSize: Int, treeCount: Int, rootBits: Int",
    "self.maxTrees <= 256",
    "self.maxAlphabetSize <= 704",
    "self.maxTableEntries <= 1_080",
    "self.maxTotalTableEntries <= 276_480",
    "trees! -> push(parsed.table)",
    "public intoTrees: move self",
    "errors.Kind.TotalTableLimitExceeded"
)) {
    if (-not $treeGroupSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli tree-group parser is missing: $required"
    }
}
if ($treeGroupSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "Brotli tree-group parser must not retain growable encoded input"
}
$treeGroupReaderDeclaration = [regex]::Match($treeGroupSource, '(?ms)^public struct Reader \{(?<body>.*?)^\}')
if (-not $treeGroupReaderDeclaration.Success) {
    throw "Brotli tree-group reader declaration is missing"
}
if ($treeGroupReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli tree-group reader must retain semantic state, not caller input"
}

$compressedHeaderSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\compressed_header.slg"))
foreach ($required in @(
    "public struct Limits",
    "maxBlockTypes: Int",
    "maxBlockLength: Int",
    "maxContextEntries: Int",
    "maxTrees: Int",
    "maxTableEntries: Int",
    "maxTotalTableEntries: Int",
    "public struct Parser",
    "public struct PreludeReader",
    "public struct BlockStreamReader",
    "public enum BlockStreamRead",
    "public struct HeaderReader",
    "public enum HeaderRead",
    "public struct HeaderPrelude",
    "public struct ContextReader",
    "public enum ContextRead",
    "public struct ContextPrelude",
    "public struct TreeReader",
    "public enum TreeRead",
    "public struct Prelude",
    "public enum PreludeRead",
    "public enum TableSlot",
    "public struct BlockStream",
    "public struct BlockSwitch",
    "public struct Parsed",
    "public parser: self",
    "public preludeReader: self",
    "public blockStreamReader: self",
    "public headerReader: self",
    "public prefixDescription: self -> Result<prefix_code.DescriptionReader, Error>",
    "public installPrefix: mut self, table: move prefix.Table -> Result<Unit, Error>",
    "public read: mut self, window: mut prefix.Window -> Result<BlockStreamRead, Error>",
    "public finish: move self -> Result<BlockStream, Error>",
    "public finishBlock: mut self -> Result<Unit, Error>",
    "public finishPrelude: move self -> Result<HeaderPrelude, Error>",
    "public contextReader: move self, parser: ref Parser -> Result<ContextReader, Error>",
    "public treeReader: move self, parser: ref Parser -> Result<TreeReader, Error>",
    "public next: mut self -> Result<TreeRead, Error>",
    "public finish: move self, position: prefix.Position -> Result<Parsed, Error>",
    "public read: mut self, window: mut prefix.Window",
    "public parse: self, input: [UInt8], position: prefix.Position",
    "public switch: self, input: [UInt8], position: prefix.Position, previousType: Int, currentType: Int",
    "streamIndex! < 3",
    "self.maxBlockTypes <= 256",
    "self.maxBlockLength <= 16_793_840",
    "directDistanceCodes + 48 *",
    "blockStreams![0].typeCount * 64",
    "blockStreams![2].typeCount * 4",
    "self -> parseTrees(input, current!, 256",
    "self -> parseTrees(input, current!, 704",
    "errors.Kind.BlockLengthLimitExceeded"
)) {
    if (-not $compressedHeaderSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli compressed-header parser is missing: $required"
    }
}
if ($compressedHeaderSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "Brotli compressed-header parser must not retain growable encoded input"
}
$preludeReaderDeclaration = [regex]::Match($compressedHeaderSource, '(?ms)^public struct PreludeReader \{(?<body>.*?)^\}')
if (-not $preludeReaderDeclaration.Success) {
    throw "Brotli compressed-header prelude reader declaration is missing"
}
if ($preludeReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli compressed-header prelude reader must retain semantic scalars, not caller input"
}
$blockStreamReaderDeclaration = [regex]::Match($compressedHeaderSource, '(?ms)^public struct BlockStreamReader \{(?<body>.*?)^\}')
if (-not $blockStreamReaderDeclaration.Success) {
    throw "Brotli block-stream reader declaration is missing"
}
if ($blockStreamReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli block-stream reader must retain semantic state and installed tables, not caller input"
}
$headerReaderDeclaration = [regex]::Match($compressedHeaderSource, '(?ms)^public struct HeaderReader \{(?<body>.*?)^\}')
if (-not $headerReaderDeclaration.Success) {
    throw "Brotli compressed-header HeaderReader declaration is missing"
}
if ($headerReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli HeaderReader must retain composed semantic state, not caller input"
}
$compressedContextReaderDeclaration = [regex]::Match($compressedHeaderSource, '(?ms)^public struct ContextReader \{(?<body>.*?)^\}')
if (-not $compressedContextReaderDeclaration.Success) {
    throw "Brotli compressed-header ContextReader declaration is missing"
}
if ($compressedContextReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli ContextReader must retain semantic state and owned maps, not caller input"
}
$compressedTreeReaderDeclaration = [regex]::Match($compressedHeaderSource, '(?ms)^public struct TreeReader \{(?<body>.*?)^\}')
if (-not $compressedTreeReaderDeclaration.Success) {
    throw "Brotli compressed-header TreeReader declaration is missing"
}
if ($compressedTreeReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|\[UInt8') {
    throw "Brotli TreeReader must retain semantic state and owned tables, not caller input"
}

$compressedStreamSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\compressed_stream.slg"))
foreach ($required in @(
    "public struct Limits",
    "public struct Reader",
    "public enum Read",
    "Header(headers.HeaderReader)",
    "HeaderPrefix(HeaderPrefix)",
    "Context(headers.ContextReader)",
    "ContextPrefix(ContextPrefix)",
    "Tree(headers.TreeReader)",
    "TreePrefix(TreePrefix)",
    "Command(commands.Reader)",
    "Complete([UInt8; ~])",
    "public dormantReader: self, parser: headers.Parser -> Result<Reader, Error>",
    "public reader: self, parser: headers.Parser, expectedOutputBytes: Int, history: move [UInt8; ~] -> Result<Reader, Error>",
    "public active: self -> Bool",
    "public read: mut self, window: mut prefix.Window, position: prefix.Position -> Result<Read, Error>",
    "public finish: move self -> Result<[UInt8; ~], Error>",
    "public takeOutput: mut self -> Result<[UInt8; ~], Error>",
    "prefixState!.description -> takeTable",
    "owner.history => history",
    "executor -> reader(history)"
)) {
    if (-not $compressedStreamSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli compressed-stream reader is missing: $required"
    }
}
$compressedStreamReaderDeclaration = [regex]::Match($compressedStreamSource, '(?ms)^public struct Reader \{(?<body>.*?)^\}')
if (-not $compressedStreamReaderDeclaration.Success) {
    throw "Brotli compressed-stream Reader declaration is missing"
}
if ($compressedStreamReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:|encodedInput') {
    throw "Brotli compressed-stream Reader must retain semantic state and private history, not caller input"
}

$literalContextSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\literal_context.slg"))
foreach ($required in @(
    "public enum Mode",
    "Lsb6",
    "Msb6",
    "Utf8",
    "Signed",
    "public id: self, previous: UInt8, secondPrevious: UInt8",
    "utf8Last",
    "utf8Second",
    "signedClass"
)) {
    if (-not $literalContextSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli literal-context implementation is missing: $required"
    }
}

$commandSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\command.slg"))
foreach ($required in @(
    "public struct Limits",
    "maxOutputBytes: Int",
    "maxCommands: Int",
    "maxWindowBytes: Int",
    "public struct Executor",
    "public struct Decoded",
    "public struct Reader",
    "public enum ReaderRead",
    "public struct Streamed",
    "public executor: self, header: move headers.Parsed, expectedOutputBytes: Int",
    "public reader: move self, history: move [UInt8; ~] -> Result<Reader, Error>",
    "public read: mut self, window: mut prefix.Window -> Result<ReaderRead, Error>",
    "public finish: move self -> Result<Streamed, Error>",
    "public intoOutput: move self -> [UInt8; ~]",
    "model.ReaderPhase.BlockTypeSymbol",
    "model.ReaderPhase.BlockLengthSymbol",
    "model.ReaderPhase.BlockLengthExtra",
    "self.resumePhase => self.phase",
    "public decode: move self, input: [UInt8]",
    "public decodeWithHistory: move self, input: [UInt8], history: move [UInt8; ~]",
    "public decodeInto: move self, input: [UInt8], output: mut [UInt8; ~]",
    "[Int; ~] => distanceRing!",
    "distanceRing! -> push(16)",
    "output -> len => outputLength!",
    "outputLength! + self.expectedOutputBytes => targetOutputLength",
    "self.header.commandTrees -> len => commandTreeCount",
    "self.header.literalContextMap -> len => literalContextCount",
    "outputLength! + 1 => outputLength!",
    "commands! <= self.maxCommands",
    "dictionary.Resolver",
    "dictionary.Limits { maxOutputBytes: maximumOutputBytes } -> resolver",
    "self.dictionary -> appendDictionary(self.copyLength, distance!, maxDistance, self.output)",
    "currentTypes![0] < contextModeCount",
    "self.header.contextModes[currentTypes![0]] -> id"
)) {
    if (-not $commandSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli command implementation is missing: $required"
    }
}
if ($commandSource.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "Brotli command executor must not retain growable encoded input"
}
$commandReaderDeclaration = [regex]::Match($commandSource, '(?ms)^public struct Reader \{(?<body>.*?)^\}')
if (-not $commandReaderDeclaration.Success) {
    throw "Brotli command reader declaration is missing"
}
if ($commandReaderDeclaration.Groups['body'].Value -match '(?m)^\s*input\s*:') {
    throw "Brotli command reader must retain semantic state and private output, not caller input"
}

$source = [System.IO.File]::ReadAllText((Join-Path $root $contract.sources[0]))
foreach ($required in @(
    "public struct Limits",
    "maxEncodedBytes: Int",
    "maxDecodedBytes: Int",
    "maxWindowBytes: Int",
    "maxMetaBlocks: Int",
    "maxMetadataBytes: Int",
    "public struct Codec",
    "public struct Encoder",
    "public struct Decoder",
    "bitWindow: prefix.Window",
    "headerParser: headers.Parser",
    "windowBytes: Int",
    "public codec: self",
    "public encoder: self, expectedInputBytes: Int",
    "public decoder: self",
    "public compress: self, input: [UInt8]",
    "public decompress: self, input: [UInt8]",
    "public write: mut self, input: [UInt8], output: mut [UInt8; ~]",
    "public finish: move self, output: mut [UInt8; ~]",
    "verifiedOutput: [UInt8; ~]",
    "prefix.WindowLimits { maxBufferedBits: 56 } -> window",
    "self.limits -> compressedParser -> when",
    "compressed: streams.Reader",
    "self.limits -> dormantCompressed(headerParser)? => compressed",
    "phases.Phase.Compressed",
    "decoder.compressed -> read(decoder.bitWindow, position)",
    "decoder.compressed -> takeOutput",
    "decoder -> streamPosition(cursor)",
    "decoder -> streamCompressed(input, cursor)",
    "windowBytes => decoder.windowBytes",
    "self.metaBlocks + blocks <= self.maxMetaBlocks",
    "errors.Kind.InvalidPadding",
    "output -> appendFinalEmpty(not self.started)"
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli implementation is missing: $required"
    }
}
foreach ($forbidden in @("UnsupportedCompressedMetaBlock", "CompressedHeaderPrelude", "headerPrelude")) {
    if ($source.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "Brotli Decoder retains obsolete compressed-stream boundary: $forbidden"
    }
}
foreach ($forbidden in @("public encoder expected", "public compress input", "public decompress input")) {
    if ($source -cmatch "(?m)^$([regex]::Escape($forbidden))") {
        throw "Brotli stateful operation escaped its natural instance: $forbidden"
    }
}
$encoderDeclaration = [regex]::Match($source, '(?ms)^public struct Encoder \{(?<body>.*?)^\}')
if (-not $encoderDeclaration.Success) {
    throw "Brotli encoder declaration is missing"
}
if ($encoderDeclaration.Groups['body'].Value.Contains('input:', [System.StringComparison]::Ordinal)) {
    throw "Brotli encoder must not retain complete caller input"
}
$decoderDeclaration = [regex]::Match($source, '(?ms)^public struct Decoder \{(?<body>.*?)^\}')
if (-not $decoderDeclaration.Success) {
    throw "Brotli decoder declaration is missing"
}
if ($decoderDeclaration.Groups['body'].Value.Contains('encodedInput:', [System.StringComparison]::Ordinal)) {
    throw "Brotli decoder must not retain complete encoded input"
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "expectedEncoding",
    "decodeBytewise",
    "decoder! -> write([input[index!]])",
    "metadataThenRaw",
    '"streaming",',
    '"meta-block-limit",',
    '"truncated-transactional",',
    '"padding-transactional",',
    '"trailing-transactional",',
    "limitedEncoder! -> write",
    "failsIntWith(4)"
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli fixture no longer proves: $required"
    }
}

$prefixFixture = [System.IO.File]::ReadAllText($prefixFixturePath)
foreach ($required in @(
    "[1, 2, 3, 3]",
    "[1, 3, 3, 3, 3]",
    '"subtable-read",',
    '"truncated",',
    '"invalid-space",',
    '"table-limit",'
)) {
    if (-not $prefixFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli prefix fixture no longer proves: $required"
    }
}

$prefixCodeFixture = [System.IO.File]::ReadAllText($prefixCodeFixturePath)
foreach ($required in @(
    "[UInt8(77), 14, 27]",
    "[UInt8(220), 61, 54]",
    "[UInt8(192), 1, 112, 14]",
    "[UInt8(28), 0, 103, 1]",
    '"simple",',
    '"complex",',
    '"repeat-16",',
    '"repeat-17",',
    '"duplicate",',
    '"truncated",',
    '[49]',
    '"invalid-symbol",',
    "checksStreamFixed",
    '"stream-fixed",'
)) {
    if (-not $prefixCodeFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli prefix-code fixture no longer proves: $required"
    }
}

$prefixDescriptionFixture = [System.IO.File]::ReadAllText($prefixDescriptionFixturePath)
foreach ($required in @(
    "descriptionReader(8, 5)",
    "isNeedMore(2)",
    "isNeedMore(1)",
    "intoTable",
    '"simple-prefix-stream=$(checked)"'
)) {
    if (-not $prefixDescriptionFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli prefix-description fixture no longer proves: $required"
    }
}
$prefixDescriptionExpected = [System.IO.File]::ReadAllText($prefixDescriptionExpectedPath).Trim()
if ($prefixDescriptionExpected -ne "simple-prefix-stream=true") {
    throw "Brotli prefix-description expected output drifted: $prefixDescriptionExpected"
}

$complexPrefixDescriptionFixture = [System.IO.File]::ReadAllText($complexPrefixDescriptionFixturePath)
foreach ($required in @(
    "descriptionReader(4, 5)",
    "[112]",
    "isNeedMore(2)",
    "intoTable",
    '"complex-prefix-stream=$(checked)"'
)) {
    if (-not $complexPrefixDescriptionFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli complex prefix-description fixture no longer proves: $required"
    }
}
$complexPrefixDescriptionExpected = [System.IO.File]::ReadAllText($complexPrefixDescriptionExpectedPath).Trim()
if ($complexPrefixDescriptionExpected -ne "complex-prefix-stream=true") {
    throw "Brotli complex prefix-description expected output drifted: $complexPrefixDescriptionExpected"
}

$complexPrefixRepeatFixture = [System.IO.File]::ReadAllText($complexPrefixRepeatFixturePath)
foreach ($required in @(
    "[192, 1, 112, 14]",
    "[28, 0, 103, 1]",
    "checksRepeat",
    "isWaiting",
    '"complex-prefix-repeat-stream=$(repeatPrevious and repeatZero)"'
)) {
    if (-not $complexPrefixRepeatFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli complex prefix-repeat fixture no longer proves: $required"
    }
}
$complexPrefixRepeatExpected = [System.IO.File]::ReadAllText($complexPrefixRepeatExpectedPath).Trim()
if ($complexPrefixRepeatExpected -ne "complex-prefix-repeat-stream=true") {
    throw "Brotli complex prefix-repeat expected output drifted: $complexPrefixRepeatExpected"
}

$contextMapFixture = [System.IO.File]::ReadAllText($contextMapFixturePath)
foreach ($required in @(
    "[161, 52]",
    "[161, 236]",
    "[17, 146, 204, 0]",
    '"single",',
    '"plain",',
    '"move-to-front",',
    '"zero-run",',
    '"run-overflow",',
    '"truncated",'
)) {
    if (-not $contextMapFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli context-map fixture no longer proves: $required"
    }
}

$contextMapStreamFixture = [System.IO.File]::ReadAllText($contextMapStreamFixturePath)
foreach ($required in @(
    "parser -> reader(4)",
    "reader! -> prefixDescription",
    "reader! -> installPrefix(table)",
    "reader! -> read(window)",
    "reader! -> finish",
    "[161]",
    "[52]",
    '"context-map-stream=$(checked)"'
)) {
    if (-not $contextMapStreamFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli context-map stream fixture no longer proves: $required"
    }
}
$contextMapStreamExpected = [System.IO.File]::ReadAllText($contextMapStreamExpectedPath).Trim()
if ($contextMapStreamExpected -ne "context-map-stream=true") {
    throw "Brotli context-map stream expected output drifted: $contextMapStreamExpected"
}

$treeGroupFixture = [System.IO.File]::ReadAllText($treeGroupFixturePath)
foreach ($required in @(
    "[UInt8(77), 174, 201, 1]",
    '"two-trees",',
    '"tree-limit",',
    '"truncated",',
    '"total-limit",'
)) {
    if (-not $treeGroupFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli tree-group fixture no longer proves: $required"
    }
}

$treeGroupStreamFixture = [System.IO.File]::ReadAllText($treeGroupStreamFixturePath)
foreach ($required in @(
    "parser -> reader(4, 2, 2)",
    "reader -> prefixDescription",
    "reader -> installTree(table)",
    "reader! -> feedNextTree",
    "reader! -> finish",
    "[UInt8(77), 174, 201, 1]",
    '"tree-group-stream=$(checked)"'
)) {
    if (-not $treeGroupStreamFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli tree-group stream fixture no longer proves: $required"
    }
}
$treeGroupStreamExpected = [System.IO.File]::ReadAllText($treeGroupStreamExpectedPath).Trim()
if ($treeGroupStreamExpected -ne "tree-group-stream=true") {
    throw "Brotli tree-group stream expected output drifted: $treeGroupStreamExpected"
}

$compressedHeaderFixture = [System.IO.File]::ReadAllText($compressedHeaderFixturePath)
foreach ($required in @(
    "[UInt8(27), 99, 0, 248, 37, 194, 2, 177, 64, 160, 3]",
    "prefix.Position { byteIndex: 3, bitIndex: 0 }",
    '"blocks=',
    '"lengths=',
    '"distance=',
    '"sizes=',
    '"trees=',
    '"position=',
    '"truncated",'
)) {
    if (-not $compressedHeaderFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli compressed-header fixture no longer proves: $required"
    }
}

$compressedPreludeFixture = [System.IO.File]::ReadAllText($compressedPreludeFixturePath)
foreach ($required in @(
    "parser -> preludeReader",
    "window -> fill([248]",
    "window -> fill([37]",
    '"prelude-chunks"',
    '"decoder-progress"',
    "TruncatedInput",
    "output! -> push(7)",
    "(output! -> len) == 1 and output![0] == 7"
)) {
    if (-not $compressedPreludeFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli compressed-prelude fixture no longer proves: $required"
    }
}

$literalContextFixture = [System.IO.File]::ReadAllText($literalContextFixturePath)
foreach ($required in @(
    "2_391_928_759",
    "3_491_377_908",
    "232_235_222",
    '"lut0",',
    '"lut1",',
    '"lut2",',
    '"lsb",',
    '"msb",'
)) {
    if (-not $literalContextFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli literal-context fixture no longer proves: $required"
    }
}

$commandFixture = [System.IO.File]::ReadAllText($commandFixturePath)
foreach ($required in @(
    "[UInt8(27), 99, 0, 248, 37, 194, 2, 177, 64, 160, 3]",
    "executor(header, 100)",
    "decoded.output -> len) == 100",
    "decoded.output -> allByte(97)",
    '"output=',
    '"position=',
    '"truncated='
)) {
    if (-not $commandFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli command fixture no longer proves: $required"
    }
}

$commandStreamFixture = [System.IO.File]::ReadAllText($commandStreamFixturePath)
foreach ($required in @(
    "executor -> reader([UInt8; ~])",
    "reader! -> read(window)",
    "reader! -> finish",
    "[160]",
    "[3]",
    "window -> available) == 6",
    '"command-stream=$(checked)"'
)) {
    if (-not $commandStreamFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli command stream fixture no longer proves: $required"
    }
}
$commandStreamExpected = [System.IO.File]::ReadAllText($commandStreamExpectedPath).Trim()
if ($commandStreamExpected -ne "command-stream=true") {
    throw "Brotli command stream expected output drifted: $commandStreamExpected"
}

$commandBlockSwitchFixture = [System.IO.File]::ReadAllText($commandBlockSwitchFixturePath)
foreach ($required in @(
    "initialLength: 0",
    "typeCount: 2",
    "(window! -> available) + 1 => required",
    "stalls! + 1 => stalls!",
    "read.stalls == 3",
    "read.stalls == 4",
    "dictionaryOk!",
    "read.output[0] == 116",
    "read.output[3] == 101",
    '"block-switch=$(literalOk!):$(distanceOk!):$(dictionaryOk!)"'
)) {
    if (-not $commandBlockSwitchFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli command block-switch fixture no longer proves: $required"
    }
}
$commandBlockSwitchExpected = [System.IO.File]::ReadAllText($commandBlockSwitchExpectedPath).Trim()
if ($commandBlockSwitchExpected -ne "block-switch=true:true:true") {
    throw "Brotli command block-switch expected output drifted: $commandBlockSwitchExpected"
}

function Read-SlgIntegerArray {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Name
    )

    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Source, "(?ms)^(?:public\s+)?${escaped}:\s*->[^\r\n]*=>\s*\[(?<body>.*?)^\]")
    if (-not $match.Success) {
        throw "Brotli static dictionary array is missing: $Name"
    }
    @([regex]::Matches($match.Groups['body'].Value, '(?<![A-Za-z0-9_])\d[\d_]*') |
        ForEach-Object { $_.Value.Replace('_', '') })
}

$staticDictionarySource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\static_dictionary.slg"))
$staticDictionaryDataSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\compress\brotli\static_dictionary_data.slg"))
$dataWords = @(Read-SlgIntegerArray -Source $staticDictionaryDataSource -Name "dataWords")
if ($dataWords.Count -ne 15348) {
    throw "Brotli static dictionary packed word count drifted: $($dataWords.Count)"
}
$dictionaryBytes = [System.Collections.Generic.List[byte]]::new(122784)
foreach ($textWord in $dataWords) {
    $word = [Convert]::ToUInt64($textWord, [System.Globalization.CultureInfo]::InvariantCulture)
    for ($byteIndex = 0; $byteIndex -lt 8; $byteIndex++) {
        $dictionaryBytes.Add([byte](($word -shr (8 * $byteIndex)) -band 0xff))
    }
}
Add-Type -TypeDefinition @'
public static class SollangBrotliContractCrc32
{
    public static uint Compute(byte[] values)
    {
        uint crc = 0xffffffffu;
        foreach (byte value in values)
        {
            crc ^= value;
            for (int bit = 0; bit < 8; bit++)
                crc = (crc >> 1) ^ ((crc & 1) == 0 ? 0u : 0xedb88320u);
        }
        return crc ^ 0xffffffffu;
    }
}
'@
$crc = [SollangBrotliContractCrc32]::Compute($dictionaryBytes.ToArray())
$crcText = $crc.ToString('x8', [System.Globalization.CultureInfo]::InvariantCulture)
if (($dataWords.Count * 8) -ne 122784 -or $crcText -ne '5136cb04') {
    throw "Brotli static dictionary identity drifted: bytes=$($dataWords.Count * 8), crc32=$crcText"
}
foreach ($arrayContract in @(
    @{ Name = 'prefixIndexes'; Count = 121 },
    @{ Name = 'operationCodes'; Count = 121 },
    @{ Name = 'suffixIndexes'; Count = 121 },
    @{ Name = 'affixData'; Count = 217 },
    @{ Name = 'affixOffsets'; Count = 50 }
)) {
    $values = @(Read-SlgIntegerArray -Source $staticDictionarySource -Name $arrayContract.Name)
    if ($values.Count -ne $arrayContract.Count) {
        throw "Brotli static dictionary $($arrayContract.Name) count drifted: $($values.Count)"
    }
}
foreach ($required in @(
    "public struct Limits",
    "public struct Resolver",
    "public resolver: self -> Result<Resolver, Error>",
    "public append: self, wordLength: Int, distance: Int, maximumBackwardDistance: Int",
    "transformId >= 0 and transformId < 121",
    "and appended <= self.maxOutputBytes - (output -> len)"
)) {
    if (-not $staticDictionarySource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli static dictionary implementation is missing: $required"
    }
}
$staticDictionaryFixture = [System.IO.File]::ReadAllText($staticDictionaryFixturePath)
foreach ($required in @(
    "resolver -> resolves(1, [116, 105, 109, 101])",
    "resolver -> resolves(70_316, [75, 77, 194, 146, 32])",
    "resolver -> resolves(70_160, [226, 128, 156, 83, 32])",
    "dictionary.Limits { maxOutputBytes: 3 }",
    '"static-dictionary=$passed"'
)) {
    if (-not $staticDictionaryFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli static dictionary fixture no longer proves: $required"
    }
}
$staticDictionaryExpected = [System.IO.File]::ReadAllText($staticDictionaryExpectedPath).Trim()
if ($staticDictionaryExpected -ne "static-dictionary=true") {
    throw "Brotli static dictionary expected output drifted: $staticDictionaryExpected"
}

$blockStreamFixture = [System.IO.File]::ReadAllText($blockStreamFixturePath)
foreach ($required in @(
    "parser -> blockStreamReader => reader!",
    "reader! -> prefixDescription",
    "reader! -> installPrefix(table)",
    "bits == 3",
    "bits == 2",
    "bits == 1",
    "blockStream.initialLength == 268_435_456",
    "blockStream.initialLength == 2",
    "maxBlockTypes: 1",
    "limited -> rejectSecondType",
    '"block-stream-reader=$(parser -> singleType):$(parser -> multipleTypes):$(limited -> rejectSecondType)"'
)) {
    if (-not $blockStreamFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli block-stream Reader fixture no longer proves: $required"
    }
}
$blockStreamExpected = [System.IO.File]::ReadAllText($blockStreamExpectedPath).Trim()
if ($blockStreamExpected -ne "block-stream-reader=true:true:true") {
    throw "Brotli block-stream Reader expected output drifted: $blockStreamExpected"
}

$headerReaderFixture = [System.IO.File]::ReadAllText($headerReaderFixturePath)
foreach ($required in @(
    "parser -> headerReader => reader!",
    "reader! -> finishBlock",
    "finishedBlocks! == 3",
    "fedBits! == 11",
    "prelude.distancePostfixBits == 3",
    "prelude.directDistanceCodes == 136",
    "prelude.distanceCodeCount == 520",
    "prelude.literalContextEntryCount == 64",
    '"header-reader=$(parser -> check)"'
)) {
    if (-not $headerReaderFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli HeaderReader fixture no longer proves: $required"
    }
}
$headerReaderExpected = [System.IO.File]::ReadAllText($headerReaderExpectedPath).Trim()
if ($headerReaderExpected -ne "header-reader=true") {
    throw "Brotli HeaderReader expected output drifted: $headerReaderExpected"
}

$contextReaderFixture = [System.IO.File]::ReadAllText($contextReaderFixturePath)
foreach ($required in @(
    "context -> checkContext",
    "context! -> read(window!)",
    "NeedPrefix(_) { false -> return }",
    "context! -> finish",
    "fedBits! == 2",
    "position!.byteIndex == 1",
    "position!.bitIndex == 5",
    "result.literalContextMap -> allZero",
    "result.distanceContextMap -> allZero",
    '"context-reader=$(parser -> check)"'
)) {
    if (-not $contextReaderFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli ContextReader fixture no longer proves: $required"
    }
}
$contextReaderExpected = [System.IO.File]::ReadAllText($contextReaderExpectedPath).Trim()
if ($contextReaderExpected -ne "context-reader=true") {
    throw "Brotli ContextReader expected output drifted: $contextReaderExpected"
}

$treeReaderFixture = [System.IO.File]::ReadAllText($treeReaderFixturePath)
foreach ($required in @(
    "context -> treeReader(parser)",
    "tree! -> prefixDescription",
    "tree -> installTree(table)",
    "tree! -> finish(position!)",
    "commands.Limits {",
    "executor(parsed, 100)",
    "executor -> reader([UInt8; ~])",
    "reader! -> read(window!)",
    "output -> allByte(97)",
    "position!.byteIndex == 6",
    "position!.bitIndex == 5",
    "position!.byteIndex == 7",
    "position!.bitIndex == 2",
    '"tree-reader=$(parser -> check)"'
)) {
    if (-not $treeReaderFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli TreeReader fixture no longer proves: $required"
    }
}
$treeReaderExpected = [System.IO.File]::ReadAllText($treeReaderExpectedPath).Trim()
if ($treeReaderExpected -ne "tree-reader=true") {
    throw "Brotli TreeReader expected output drifted: $treeReaderExpected"
}

$commandHistoryFixture = [System.IO.File]::ReadAllText($commandHistoryFixturePath)
foreach ($required in @(
    "decodeWithHistory(input, [122])",
    "decoded.output[0] == 122",
    "decoded.output -> allByte(1, 97)",
    '"history=$(historyOk)"'
)) {
    if (-not $commandHistoryFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli command-history fixture no longer proves: $required"
    }
}

$bulkCompressedFixture = [System.IO.File]::ReadAllText($bulkCompressedFixturePath)
foreach ($required in @(
    "codec -> decompress([27, 99, 0, 248, 37, 194, 2, 177, 64, 160, 3])",
    "output -> allByte(97)",
    '"compressed=$((output -> len) == 100 and bytesOk)"'
)) {
    if (-not $bulkCompressedFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli bulk-compressed fixture no longer proves: $required"
    }
}

$decoderCompressedStreamFixture = [System.IO.File]::ReadAllText($decoderCompressedStreamFixturePath)
foreach ($required in @(
    "decoder! -> write([input[index!]])",
    "written == 100",
    "output! -> allByte(97)",
    "decoder! -> write([27, 99, 0, 248, 37])",
    "TruncatedInput",
    "output! -> push(7)",
    '"decoder-compressed-stream=$(valid and truncationOk)"'
)) {
    if (-not $decoderCompressedStreamFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Brotli public compressed-stream fixture no longer proves: $required"
    }
}
$decoderCompressedStreamExpected = [System.IO.File]::ReadAllText($decoderCompressedStreamExpectedPath).Trim()
if ($decoderCompressedStreamExpected -ne "decoder-compressed-stream=true") {
    throw "Brotli public compressed-stream expected output drifted: $decoderCompressedStreamExpected"
}

$nativeBatch = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"))
foreach ($fixtureName in @($contract.fixture, $contract.prefixFixture, $contract.prefixCodeFixture, $contract.prefixDescriptionFixture, $contract.complexPrefixDescriptionFixture, $contract.complexPrefixRepeatFixture, $contract.contextMapFixture, $contract.contextMapStreamFixture, $contract.treeGroupFixture, $contract.treeGroupStreamFixture, $contract.compressedHeaderFixture, $contract.compressedPreludeFixture, $contract.literalContextFixture, $contract.commandFixture, $contract.commandStreamFixture, $contract.commandBlockSwitchFixture, $contract.staticDictionaryFixture, $contract.blockStreamFixture, $contract.headerReaderFixture, $contract.contextReaderFixture, $contract.treeReaderFixture, $contract.commandHistoryFixture, $contract.bulkCompressedFixture, $contract.decoderCompressedStreamFixture)) {
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
    if (-not $gate.Contains("verify-brotli-foundation-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the Brotli contract preflight"
    }
}

Write-Host "[Brotli foundation contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixtures through $($contract.decoderCompressedStreamFixture), plus command-link, history, and public compressed-stream coverage."
