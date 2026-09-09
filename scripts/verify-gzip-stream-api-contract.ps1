[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\gzip-stream-api.json"
$schemaPath = Join-Path $root "scripts\contracts\gzip-stream-api.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "GZIP stream API contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
$sourcePath = Join-Path $root $contract.source
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
$boundaryFixturePath = Join-Path $root "examples\regression\$($contract.boundaryFixture).slg"
$boundaryExpectedPath = Join-Path $root "examples\regression\expected\$($contract.boundaryFixture).stdout.txt"
foreach ($path in @($sourcePath, $fixturePath, $expectedPath, $boundaryFixturePath, $boundaryExpectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "GZIP stream API evidence is missing: $path"
    }
}

$source = [System.IO.File]::ReadAllText($sourcePath)
foreach ($required in @(
    "public struct DecoderLimits",
    "maxInputBytes: Int",
    "maxMembers: Int",
    "public struct Decoder",
    "public decoder: self, limits: DecoderLimits",
    "public decompressMembers: self",
    "public write: mut self, input: [UInt8]",
    "public finish: move self, output: mut [UInt8; ~]",
    "inflatePayload input:",
    "inflateRange input:",
    "decodeMember codec:",
    "decodeMembers codec:",
    "streamReadBits decoder:",
    "streamDecodeSymbol decoder:",
    "streamDynamic decoder:",
    "streamCompressed decoder:",
    "streamCommitMember decoder:",
    "errors.Kind.InputLimitExceeded",
    "errors.Kind.MemberLimitExceeded"
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "GZIP stream API implementation is missing: $required"
    }
}
$memberMethod = [regex]::Match(
    $source,
    '(?ms)public decompressMembers: self, input: \[UInt8\], maxMembers: Int -> Result<\[UInt8; ~\], Error> \{(?<body>.*?)^    \}')
if (-not $memberMethod.Success -or
    -not $memberMethod.Groups['body'].Value.Contains('decodeMembers(self, input, maxMembers)', [System.StringComparison]::Ordinal)) {
    throw "GZIP decompressMembers must retain the measured bulk member decoder"
}
if ($source -cmatch '(?m)^public decoder:') {
    throw "GZIP decoder must be an instance factory, not a public global"
}
$decoderDeclaration = [regex]::Match(
    $source,
    '(?ms)^public struct Decoder \{(?<body>.*?)^\}')
if (-not $decoderDeclaration.Success) {
    throw "GZIP decoder declaration is missing"
}
if ($decoderDeclaration.Groups['body'].Value.Contains('input: [UInt8; ~]', [System.StringComparison]::Ordinal)) {
    throw "GZIP decoder must not retain the complete compressed input"
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "rejectsMemberLimit",
    "rejectsChecksum",
    "rejectsTruncated",
    "retainsAcceptedInput",
    "decompressMembers(combined!, 2)",
    "gzip.DecoderLimits",
    "decoder! -> finish(output!)"
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "GZIP stream fixture no longer proves: $required"
    }
}

$boundaryFixture = [System.IO.File]::ReadAllText($boundaryFixturePath)
foreach ($required in @(
    "decodeBytewise",
    "decoder! -> write(chunk)",
    "dynamicGzip",
    'printResult("stored"',
    'printResult("fixed"',
    'printResult("dynamic"',
    'printResult("combined"'
)) {
    if (-not $boundaryFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "GZIP byte-boundary fixture no longer proves: $required"
    }
}

foreach ($gateName in @(
    "verify-native-exact-fixture-batch.ps1",
    "verify-selfhost-stage2.ps1",
    "verify-selfhost-stage3.ps1",
    "verify-selfhost-stage2-linux.ps1",
    "verify-selfhost-stage3-linux.ps1"
)) {
    $gate = [System.IO.File]::ReadAllText((Join-Path $root "scripts\$gateName"))
    foreach ($requiredFixture in @($contract.fixture, $contract.boundaryFixture)) {
        if ($gate.Contains($requiredFixture, [System.StringComparison]::Ordinal)) {
            continue
        }
        $nativeBatch = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"))
        if (-not $gate.Contains("verify-native-exact-fixture-batch.ps1", [System.StringComparison]::Ordinal) -or
            -not $nativeBatch.Contains($requiredFixture, [System.StringComparison]::Ordinal)) {
            throw "$gateName does not retain $requiredFixture"
        }
    }
    if ($gateName -ne "verify-native-exact-fixture-batch.ps1" -and
        -not $gate.Contains("verify-gzip-stream-api-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the GZIP stream API preflight"
    }
}

$binaryCodecGate = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-binary-codecs.ps1"))
foreach ($requiredSource in @(
    'stdlib\std\compress\gzip.slg',
    'stdlib\std\compress\gzip\error.slg',
    'stdlib\std\compress\gzip\decoder_phase.slg'
)) {
    if (-not $binaryCodecGate.Contains($requiredSource, [System.StringComparison]::Ordinal)) {
        throw "native GZIP CRC32 parity manifest is missing transitive source $requiredSource"
    }
}

Write-Host "[GZIP stream API contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixtures $($contract.fixture), $($contract.boundaryFixture)."
