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
$browserRunnerPath = Join-Path $root "scripts\verify-uri-browser-program.mjs"
foreach ($path in @($contractPath, $schemaPath, $sourcePath, $fixturePath, $expectedPath, $boundaryFixturePath, $boundaryExpectedPath, $browserRunnerPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "URI normalization contract input is missing: $path"
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "URI normalization contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
if ($contract.surfaces.Count -ne 4 -or $contract.invariants.Count -ne 10 -or $contract.fixtures.Count -ne 4) {
    throw "URI normalization contract dimensions drifted"
}
$expectedFixtures = @(
    "1031-uri-percent-codec",
    "1032-uri-reference-authority",
    "1697-uri-normalization-policy",
    "1698-uri-resolution-boundaries"
)
if (@(Compare-Object $expectedFixtures @($contract.fixtures) -CaseSensitive).Count -ne 0) {
    throw "URI normalization fixture authority drifted"
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

foreach ($requiredInvariant in @(
    "All URI fixtures compile under the managed compiler and execute with exact output on Windows, Linux under WSL, and a Node-hosted wasm32-browser ABI harness",
    "Browser URI programs import only the allowlisted bounded allocator, reallocator, memset, memcpy, output, and panic host functions and no file, clock, random, DNS, or network effect")) {
    if ($contract.invariants -cnotcontains $requiredInvariant) {
        throw "URI normalization target invariant is missing: $requiredInvariant"
    }
}

$browserRunner = [IO.File]::ReadAllText($browserRunnerPath)
$allowlistMatch = [regex]::Match($browserRunner, '(?s)const allowedImports = new Set\(\[(.*?)\]\);')
if (-not $allowlistMatch.Success) { throw "URI browser import allowlist declaration is missing" }
$declaredImports = @([regex]::Matches($allowlistMatch.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$expectedImports = @(
    "env:sollang_browser_alloc",
    "env:sollang_browser_realloc",
    "env:memset",
    "env:memcpy",
    "env:sollang_browser_write",
    "env:sollang_browser_panic"
)
if (@(Compare-Object $expectedImports $declaredImports -CaseSensitive).Count -ne 0 -or
    @($declaredImports | Sort-Object -Unique).Count -ne $expectedImports.Count) {
    throw "URI browser import allowlist differs from the independent six-function authority"
}
foreach ($requiredLimit in @('MAX_WASM_BYTES', 'MAX_MEMORY_PAGES', 'MAX_ALLOCATION_BYTES', 'MAX_OUTPUT_BYTES')) {
    if (-not $browserRunner.Contains("const $requiredLimit =", [StringComparison]::Ordinal)) {
        throw "URI browser runner is missing fail-closed limit: $requiredLimit"
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

Write-Host "[URI normalization contract] PASS 4 surfaces, 10 invariants, 4 fixtures, bounded owned output, all 42 RFC resolution cases, 2 empty-delimiter probes, exact browser imports/limits, and the three-target managed execution contract."
