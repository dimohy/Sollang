[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\http-server.json"
$schemaPath = Join-Path $root "scripts\contracts\http-server.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "HTTP server contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
foreach ($relativePath in $contract.sources) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "HTTP server source is missing: $relativePath"
    }
}
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
$endpointFixturePath = Join-Path $root "examples\regression\$($contract.endpointFixture).slg"
$endpointExpectedPath = Join-Path $root "examples\regression\expected\$($contract.endpointFixture).stdout.txt"
$bodyFixturePath = Join-Path $root "examples\regression\$($contract.bodyFixture).slg"
$bodyExpectedPath = Join-Path $root "examples\regression\expected\$($contract.bodyFixture).stdout.txt"
$emptyBodyFixturePath = Join-Path $root "examples\regression\$($contract.emptyBodyFixture).slg"
$emptyBodyExpectedPath = Join-Path $root "examples\regression\expected\$($contract.emptyBodyFixture).stdout.txt"
$persistentFixturePath = Join-Path $root "examples\regression\$($contract.persistentFixture).slg"
$persistentExpectedPath = Join-Path $root "examples\regression\expected\$($contract.persistentFixture).stdout.txt"
foreach ($path in @($fixturePath, $expectedPath, $endpointFixturePath, $endpointExpectedPath, $bodyFixturePath, $bodyExpectedPath, $emptyBodyFixturePath, $emptyBodyExpectedPath, $persistentFixturePath, $persistentExpectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "HTTP server evidence is missing: $path"
    }
}

$source = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http\server.slg"))
foreach ($required in @(
    "namespace std.net.http.server",
    "public struct ServerOptions",
    "public struct Server",
    "public struct Connection",
    "public enum ResponseOutcome",
    "public struct Request",
    "public struct RequestBody",
    "public listen: self",
    "public localEndpoint: self",
    "public accept: self",
    "public close: move self",
    "public readRequest: move self",
    "public localEndpoint: self",
    "public remoteEndpoint: self",
    "public openBody: move self",
    "public leftoverCount: self",
    "public readInto: mut self",
    "public finish: move self",
    "public respond: move self",
    "model.ResponseOutcome.Closed",
    "model.ResponseOutcome.Reusable",
    "state!.transport -> receiveInto(state!.bytes)",
    "parser -> parseRequestBytesRange(state.bytes, cursor, available)",
    "compact! -> reserve(maxHeadBytes)",
    "compacted -> readFresh",
    "request.bodyComplete -> unless",
    "request -> reuseRequest(received)",
    "state!.transport -> receiveAppend(state!.bytes)",
    "self.decoder -> writeRange(self.bytes, self.bodyCursor, available, output)",
    "self.transport -> receiveInto(self.input)",
    "self.decoder -> completion",
    "transport -> sendAll(headBytes)",
    "transport -> sendAll(body)",
    "transport -> close"
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP server implementation is missing: $required"
    }
}
$parserSource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http.slg"))
foreach ($required in @(
    "public parseRequestBytesRange: self",
    "source -> slice(start, length)",
    "parseRequestSource(self, rangedSource)"
)) {
    if (-not $parserSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP parser range implementation is missing: $required"
    }
}
if (-not $source.Contains("self.listener -> localEndpoint", [System.StringComparison]::Ordinal)) {
    throw "HTTP Server.localEndpoint must delegate directly to its owned listener instance"
}
foreach ($required in @(
    "self.transport -> localEndpoint",
    "self.transport -> remoteEndpoint"
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP Request endpoint observation must delegate directly to its retained transport: $required"
    }
}
foreach ($forbidden in @(
    "public listen options",
    "public accept server",
    "public close server",
    "public readRequest connection",
    "public respond request"
)) {
    if ($source.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "HTTP server retained a global stateful operation: $forbidden"
    }
}

$bodySource = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http\body.slg"))
if (-not $bodySource.Contains("public completion: self", [System.StringComparison]::Ordinal)) {
    throw "HTTP request-body orchestration requires non-consuming decoder completion validation"
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "service -> accept",
    "connection -> readRequest",
    "request -> localEndpoint",
    "request -> remoteEndpoint",
    "request -> respond",
    '"GET /ready HTTP/1.1\r\nHost: loopback\r\n\r\n"',
    "reply.status == 200",
    '"http-one-request-server=ok"'
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP server fixture no longer proves: $required"
    }
}
if ([System.IO.File]::ReadAllText($expectedPath).Trim() -cne "http-one-request-server=ok") {
    throw "HTTP server expected output drifted"
}

$endpointFixture = [System.IO.File]::ReadAllText($endpointFixturePath)
foreach ($required in @(
    "net.loopback(0)",
    "service -> localEndpoint",
    "bound -> port",
    "service -> close",
    '"http-server-local-endpoint=ok"'
)) {
    if (-not $endpointFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP server local-endpoint fixture no longer proves: $required"
    }
}
if ([System.IO.File]::ReadAllText($endpointExpectedPath).Trim() -cne "http-server-local-endpoint=ok") {
    throw "HTTP server local-endpoint expected output drifted"
}

$bodyFixture = [System.IO.File]::ReadAllText($bodyFixturePath)
foreach ($required in @(
    "request -> openBody(policy, 16)?",
    "request -> decodeRequest(bodyPolicy, decodedBody!)",
    "reader! -> readInto(output)?",
    "reader! -> finish",
    "completedRequest -> leftoverCount == 38",
    '"POST /upload HTTP/1.1\r\nHost: loopback\r\nContent-Length: 3\r\n\r\nabcGET /next HTTP/1.1\r\nHost: loopback\r\n\r\n"',
    '"http-request-body-cursor=ok"'
)) {
    if (-not $bodyFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP request-body fixture no longer proves: $required"
    }
}
if ([System.IO.File]::ReadAllText($bodyExpectedPath).Trim() -cne "http-request-body-cursor=ok") {
    throw "HTTP request-body expected output drifted"
}

$emptyBodyFixture = [System.IO.File]::ReadAllText($emptyBodyFixturePath)
foreach ($required in @(
    '"GET /empty HTTP/1.1\r\nHost: loopback\r\n\r\n"',
    "request -> openBody(policy, 16)?",
    "request -> completeEmptyRequest(bodyPolicy, decoded!)",
    "reader! -> readInto(output)?",
    "progress.complete",
    "progress.consumed == 0",
    "progress.produced == 0",
    '"http-empty-request-body=ok"'
)) {
    if (-not $emptyBodyFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP empty-body fixture no longer proves: $required"
    }
}
if ([System.IO.File]::ReadAllText($emptyBodyExpectedPath).Trim() -cne "http-empty-request-body=ok") {
    throw "HTTP empty-body expected output drifted"
}

$persistentFixture = [System.IO.File]::ReadAllText($persistentFixturePath)
foreach ($required in @(
    '"GET /one HTTP/1.1\r\nHost: loopback\r\n\r\nGET /two HTTP/1.1\r\nHost: loopback\r\n\r\n"',
    "completedFirst -> respond(firstHead, firstBody)",
    "Reusable(next) => next -> readRequest",
    "completedSecond -> respond(secondHead, secondBody)",
    "Closed => client -> readAll",
    "received -> responseCount == 2",
    '"http-persistent-pipeline=ok"'
)) {
    if (-not $persistentFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP persistent fixture no longer proves: $required"
    }
}
if ([System.IO.File]::ReadAllText($persistentExpectedPath).Trim() -cne "http-persistent-pipeline=ok") {
    throw "HTTP persistent expected output drifted"
}

$nativeBatch = [System.IO.File]::ReadAllText((Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"))
if (-not $nativeBatch.Contains($contract.fixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.fixture)"
}
if (-not $nativeBatch.Contains($contract.endpointFixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.endpointFixture)"
}
if (-not $nativeBatch.Contains($contract.bodyFixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.bodyFixture)"
}
if (-not $nativeBatch.Contains($contract.emptyBodyFixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.emptyBodyFixture)"
}
if (-not $nativeBatch.Contains($contract.persistentFixture, [System.StringComparison]::Ordinal)) {
    throw "native exact batch does not retain $($contract.persistentFixture)"
}
foreach ($gateName in @(
    "verify-selfhost-stage2.ps1",
    "verify-selfhost-stage3.ps1",
    "verify-selfhost-stage2-linux.ps1",
    "verify-selfhost-stage3-linux.ps1"
)) {
    $gate = [System.IO.File]::ReadAllText((Join-Path $root "scripts\$gateName"))
    if (-not $gate.Contains("verify-http-server-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the HTTP server contract preflight"
    }
}

Write-Host "[HTTP server contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixtures $($contract.fixture), $($contract.endpointFixture), $($contract.bodyFixture), $($contract.emptyBodyFixture), $($contract.persistentFixture)."
