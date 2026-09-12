[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$contractPath = Join-Path $root 'scripts\contracts\gzip-stream-api.json'
$schemaPath = Join-Path $root 'scripts\contracts\gzip-stream-api.schema.json'
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) { throw 'GZIP stream API contract does not satisfy its schema' }
$contract = $contractText | ConvertFrom-Json

$positiveAuthority = @(
    'stored-roundtrip|examples/regression/1049-gzip-stored-roundtrip.slg',
    'fixed-dynamic-decode|examples/regression/1050-gzip-fixed-dynamic-decode.slg',
    'rejection-limits|examples/regression/1051-gzip-deflate-rejection-limits.slg',
    'fixed-writer|examples/regression/1053-gzip-fixed-compression.slg',
    'stored-streaming-encoder|examples/regression/1055-gzip-streaming-encoder.slg',
    'crc-parity|examples/regression/1090-gzip-public-crc32-parity.slg',
    'transactional-concatenated|examples/regression/1214-gzip-transactional-streaming-decoder.slg',
    'one-byte-boundaries|examples/regression/1215-gzip-incremental-byte-boundaries.slg',
    'error-offsets|scripts/probes/gzip-stream-api/error-offsets.slg',
    'dynamic-writer|scripts/probes/gzip-stream-api/dynamic-writer.slg'
)
$negativeAuthority = @(
    'private-codec-state|scripts/probes/gzip-stream-api/private-codec-state.slg',
    'private-encoder-state|scripts/probes/gzip-stream-api/private-encoder-state.slg',
    'private-decoder-state|scripts/probes/gzip-stream-api/private-decoder-state.slg'
)
$actualPositive = @($contract.positiveCases | ForEach-Object { "$($_.id)|$($_.source)" })
$actualNegative = @($contract.negativeCases | ForEach-Object { "$($_.id)|$($_.source)" })
if (($actualPositive -join "`n") -cne ($positiveAuthority -join "`n")) { throw 'positive case authority drift' }
if (($actualNegative -join "`n") -cne ($negativeAuthority -join "`n")) { throw 'negative case authority drift' }
$errorAuthority = @('InvalidLimit','InputLimitExceeded','OutputLimitExceeded','ExpansionRatioExceeded','MemberLimitExceeded','TruncatedInput','InvalidHeader','InvalidHeaderChecksum','UnsupportedCompressionMethod','UnsupportedDeflateBlock','InvalidHuffmanTree','InvalidDeflateCode','InvalidDistance','InvalidStoredLength','ChecksumMismatch','SizeMismatch','TrailingData')
if ((@($contract.errorKinds) -join "`n") -cne ($errorAuthority -join "`n")) { throw 'typed error authority drift' }

function Resolve-Contained([string]$Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $root $Relative))
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "path escapes repository: $Relative" }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing evidence: $Relative" }
    $path
}
$evidencePaths = @($contract.sources) + @($contract.positiveCases.source) + @($contract.negativeCases.source)
foreach ($case in $contract.positiveCases) {
    if ($case.PSObject.Properties.Name -contains 'expected') { $evidencePaths += $case.expected }
}
foreach ($relative in $evidencePaths) { Resolve-Contained $relative | Out-Null }

$source = [IO.File]::ReadAllText((Resolve-Contained $contract.sources[0]))
$errorSource = [IO.File]::ReadAllText((Resolve-Contained $contract.sources[1]))
foreach ($kind in $errorAuthority) { if (-not $errorSource.Contains("    $kind", [StringComparison]::Ordinal)) { throw "typed error kind missing: $kind" } }
foreach ($name in 'Codec','Encoder','Decoder') {
    $declaration = [regex]::Match($source, "(?ms)^public struct $name \{(?<body>.*?)^\}")
    if (-not $declaration.Success -or $declaration.Groups['body'].Value -cmatch '(?m)^\s+public ') { throw "$name state must remain private" }
}
foreach ($required in @(
    'public dynamicEncoder: self -> Result<Encoder, Error>',
    'public planCompressDynamic: self, inputLength: Int -> Result<EncodePlan, Error>',
    'public compressDynamic: self, input: [UInt8] -> Result<[UInt8; ~], Error>',
    'writeDynamicHeader writer: mut BitWriter',
    'writeLz77Payload writer: mut BitWriter',
    'dynamicBlockMaximumBytes inputLength: Int',
    'decodeMembers(self, input, maxMembers)',
    'self.bits => bits!',
    'errors.Kind.InputLimitExceeded',
    'errors.Kind.MemberLimitExceeded',
    'errors.Kind.ChecksumMismatch',
    'errors.Kind.SizeMismatch'
)) { if (-not $source.Contains($required, [StringComparison]::Ordinal)) { throw "implementation evidence missing: $required" } }
if ($source.Contains('input: [UInt8; ~]', [StringComparison]::Ordinal)) { throw 'streaming owner must not retain complete input' }
if (-not $source.Contains('[-1; 4_096] => heads!', [StringComparison]::Ordinal) -or $source.Contains('[Int; ~] => heads!', [StringComparison]::Ordinal)) { throw 'LZ77 writer must use its bounded fixed hash table without a growable table copy' }
if (-not $source.Contains('output -> reserve(before + headerLength + blockMaximum)', [StringComparison]::Ordinal)) { throw 'dynamic streaming writer must reserve only its bounded caller-owned output extent' }
if (-not $source.Contains('checksum -> crc32Update(input)', [StringComparison]::Ordinal)) { throw 'private streaming CRC path was removed without parity proof' }

Write-Host "[GZIP stream API contract] PASS $($contract.surfaces.Count)/$($contract.surfaces.Count) surfaces, $($contract.invariants.Count)/$($contract.invariants.Count) invariants, $($contract.positiveCases.Count)+$($contract.negativeCases.Count) fixed cases."
