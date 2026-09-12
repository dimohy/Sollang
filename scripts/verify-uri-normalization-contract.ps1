[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\uri-normalization.json"
$schemaPath = Join-Path $root "scripts\contracts\uri-normalization.schema.json"
$sourcePath = Join-Path $root "stdlib\std\uri.slg"
$fixturePath = Join-Path $root "examples\regression\1697-uri-normalization-policy.slg"
$expectedPath = Join-Path $root "examples\regression\expected\1697-uri-normalization-policy.stdout.txt"
$boundaryFixturePath = Join-Path $root "examples\regression\1698-uri-resolution-boundaries.slg"
$boundaryExpectedPath = Join-Path $root "examples\regression\expected\1698-uri-resolution-boundaries.stdout.txt"
foreach ($path in @($contractPath, $schemaPath, $sourcePath, $fixturePath, $expectedPath, $boundaryFixturePath, $boundaryExpectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "URI normalization contract input is missing: $path"
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "URI normalization contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
if ($contract.surfaces.Count -ne 4 -or $contract.invariants.Count -ne 8 -or $contract.fixtures.Count -ne 4) {
    throw "URI normalization contract dimensions drifted"
}
foreach ($fixtureName in $contract.fixtures) {
    foreach ($relative in @("examples/regression/$fixtureName.slg", "examples/regression/expected/$fixtureName.stdout.txt")) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
            throw "URI normalization fixture input is missing: $relative"
        }
    }
}

$source = [IO.File]::ReadAllText($sourcePath)
foreach ($required in @(
    "public struct NormalizationPolicy",
    "public canonicalNormalization: -> NormalizationPolicy",
    "public normalizeBytes: self, policy: NormalizationPolicy, maxOutputBytes: Int -> Result<[UInt8; ~], Error>",
    "public resolveBytes: self, reference: ref Reference, policy: NormalizationPolicy, maxOutputBytes: Int -> Result<[UInt8; ~], Error>",
    "policy.decodeUnreserved",
    "policy.uppercasePercentHex",
    "policy.removeDotSegments",
    "reference.scheme.present",
    "reference.authority")) {
    if (-not $source.Contains($required, [StringComparison]::Ordinal)) {
        throw "URI normalization implementation is missing: $required"
    }
}
foreach ($forbidden in @("uses Network", "uses File", "defaultBase", "globalBase")) {
    if ($source.Contains($forbidden, [StringComparison]::OrdinalIgnoreCase)) {
        throw "URI normalization implementation retained forbidden ambient behavior: $forbidden"
    }
}

$fixture = [IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    'normalizeBytes(policy, 128)',
    'resolveBytes(child, policy, 64)',
    'resolveBytes(parent, policy, 64)',
    'resolveBytes(query, policy, 64)',
    'resolveBytes(authority, policy, 64)',
    'normalizeBytes(policy, 4)')) {
    if (-not $fixture.Contains($required, [StringComparison]::Ordinal)) {
        throw "URI normalization fixture is missing: $required"
    }
}
$expected = [IO.File]::ReadAllText($expectedPath)
foreach ($required in @(
    "normalized=http://example.com/~user/b?x=%2F#~",
    "relative=c/",
    "child=http://a/b/c/g",
    "parent=http://a/b/g",
    "query=http://a/b/c/d;p?y",
    "authority=http://g/x",
    "bounded=4")) {
    if (-not $expected.Contains($required, [StringComparison]::Ordinal)) {
        throw "URI normalization expected output is missing: $required"
    }
}
$boundaryFixture = [IO.File]::ReadAllText($boundaryFixturePath)
$boundaryExpected = [IO.File]::ReadAllText($boundaryExpectedPath)
if ($boundaryFixture -notmatch 'base -> check\(' -or
    ([regex]::Matches($boundaryFixture, 'base -> check\(')).Count -ne 44 -or
    -not $boundaryExpected.Contains("boundaries=44", [StringComparison]::Ordinal)) {
    throw "URI resolution fixture must retain all 42 RFC cases and both empty-delimiter boundary probes"
}

Write-Host "[URI normalization contract] PASS 4 surfaces, 8 invariants, 4 fixtures, bounded owned output, all 42 RFC resolution cases, and 2 empty-delimiter probes."
