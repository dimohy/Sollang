[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\http-body-framing.json"
$schemaPath = Join-Path $root "scripts\contracts\http-body-framing.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "HTTP body framing contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
foreach ($relativePath in $contract.sources) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "HTTP body framing source is missing: $relativePath"
    }
}
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
$rangeFixturePath = Join-Path $root "examples\regression\$($contract.rangeFixture).slg"
$rangeExpectedPath = Join-Path $root "examples\regression\expected\$($contract.rangeFixture).stdout.txt"
foreach ($path in @($fixturePath, $expectedPath, $rangeFixturePath, $rangeExpectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "HTTP body framing evidence is missing: $path"
    }
}

$source = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http\body.slg"))
foreach ($required in @(
    "namespace std.net.http.body",
    "public struct BodyLimits",
    "public struct BodyPolicy",
    "public struct ResponseBodyContext",
    "public enum BodyFraming",
    "public struct BodyPlan",
    "public struct BodyDecoder",
    "public policy: self",
    "public request: self, head: ref http.RequestHead",
    "public responseContext: self, verb: Text",
    "public plan: self, head: ref http.ResponseHead",
    "public decoder: self",
    "public write: mut self, input: [UInt8], output: mut [UInt8; ~]",
    "public writeRange: mut self, input: [UInt8], offset: UIntSize, length: UIntSize, output: mut [UInt8; ~]",
    "public completion: self",
    "public finish: move self",
    "errors.Kind.ConflictingBodyFraming",
    "errors.Kind.DuplicateContentLength",
    "errors.Kind.IndeterminateRequestBody",
    "errors.Kind.MissingChunkDataTerminator",
    "errors.Kind.InvalidBodyRange",
    'spanEqualIgnoreCase(value.start + tokenStart, tokenEnd - tokenStart, "chunked")'
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP body framing implementation is missing: $required"
    }
}
$headSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http.slg"))
foreach ($required in @(
    "public fieldValueHasToken: self",
    "listValueHasToken(self.fields[index].value, token)",
    "errors.Kind.InvalidFieldValue"
)) {
    if (-not $headSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP response-head token parsing is missing: $required"
    }
}
$rangeFixture = [System.IO.File]::ReadAllText($rangeFixturePath)
foreach ($required in @(
    "writeRange(buffer, 9, 1, output!)",
    "InvalidBodyRange",
    "writeRange(buffer, 2, 6, output!)",
    "progress.consumed == 3",
    "6 - progress.consumed == 3",
    "http-body-range-leftover=ok"
)) {
    if (-not $rangeFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP body range fixture no longer proves: $required"
    }
}
foreach ($forbidden in @("encodedInput:", "public request policy", "public write decoder")) {
    if ($source.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "HTTP body framing violates its instance or streaming contract: $forbidden"
    }
}
$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "progress.consumed == 3",
    "progress.consumed + 1 == UIntSize(encoded -> len)",
    'Transfer-Encoding: gzip \t, \tchunked',
    'Connection: upgrade \t, \tclose',
    'Connection: close,',
    "fieldValueHasToken",
    "ConflictingBodyFraming",
    'responseContext("CONNECT")',
    "UntilClose",
    "Tunnel"
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP body framing fixture no longer proves: $required"
    }
}
$spec = [System.IO.File]::ReadAllText((Join-Path $root "docs\SPEC.md"))
$evolution = [System.IO.File]::ReadAllText((Join-Path $root "docs\STDLIB_EVOLUTION.md"))
foreach ($required in @(
    "decoder! -> writeRange(input, offset, length, output!)",
    "offset + consumed"
)) {
    if (-not $spec.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "Sollang specification is missing HTTP body range contract: $required"
    }
}
if (-not $evolution.Contains("BodyDecoder.writeRange", [System.StringComparison]::Ordinal)) {
    throw "stdlib evolution backlog is missing BodyDecoder.writeRange"
}

$nativeBatch = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"))
if (-not $nativeBatch.Contains($contract.fixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.fixture)"
}
if (-not $nativeBatch.Contains($contract.rangeFixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.rangeFixture)"
}
foreach ($gateName in @(
    "verify-selfhost-stage2.ps1",
    "verify-selfhost-stage3.ps1",
    "verify-selfhost-stage2-linux.ps1",
    "verify-selfhost-stage3-linux.ps1"
)) {
    $gate = [System.IO.File]::ReadAllText((Join-Path $root "scripts\$gateName"))
    if (-not $gate.Contains("verify-http-body-framing-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the HTTP body framing contract preflight"
    }
}

Write-Host "[HTTP body framing contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixtures $($contract.fixture), $($contract.rangeFixture)."
