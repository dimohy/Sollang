[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\http-client.json"
$schemaPath = Join-Path $root "scripts\contracts\http-client.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "HTTP client contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
foreach ($relativePath in $contract.sources) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "HTTP client source is missing: $relativePath"
    }
}
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
foreach ($path in @($fixturePath, $expectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "HTTP client evidence is missing: $path"
    }
}

$source = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http\client.slg"))
foreach ($required in @(
    "namespace std.net.http.client",
    "public struct ClientOptions",
    "public struct Client",
    "public struct Exchange",
    "public struct Response",
    "public struct ResponseBody",
    "public enum ResponseOutcome",
    "Reusable(Client)",
    "public connect: self",
    "public send: move self",
    "public close: move self",
    "public receive: move self",
    "public openBody: move self",
    "public readInto: mut self",
    "public finish: move self",
    "RequestBodyLengthMismatch",
    "BodyNotComplete",
    "UnexpectedResponseBytes",
    "responseAllowsPersistence",
    'fieldValueHasToken(index!, "close")',
    'fieldValueHasToken(index!, "keep-alive")',
    "not untilClose",
    "initialLeftover > 0 or receivedLeftover > 0"
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP client implementation is missing: $required"
    }
}
foreach ($forbidden in @(
    "public connect options",
    "public send client",
    "public receive exchange",
    "public openBody response",
    "public finish body",
    "import std.net.dns",
    "import std.net.tls",
    "import std.net.http.redirect",
    "import std.compress",
    "AutomaticFallback"
)) {
    if ($source.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "HTTP client violates its instance or explicit-policy contract: $forbidden"
    }
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    'requestHead("/one", request.ConnectionMode.Persistent)',
    'requestHead("/two", request.ConnectionMode.Close)',
    '"HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\none"',
    '"HTTP/1.1 200 OK\r\nContent-Length: 3\r\nConnection: close\r\n\r\ntwo"',
    "Reusable(value)",
    "closedOutcome",
    '"http-client-reuse=ok"'
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP client fixture no longer proves: $required"
    }
}

$nativeBatch = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"))
if (-not $nativeBatch.Contains($contract.fixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.fixture)"
}
foreach ($gateName in @(
    "verify-selfhost-stage2.ps1",
    "verify-selfhost-stage3.ps1",
    "verify-selfhost-stage2-linux.ps1",
    "verify-selfhost-stage3-linux.ps1"
)) {
    $gate = [System.IO.File]::ReadAllText((Join-Path $root "scripts\$gateName"))
    if (-not $gate.Contains("verify-http-client-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the HTTP client contract preflight"
    }
}

Write-Host "[HTTP client contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixture $($contract.fixture)."
