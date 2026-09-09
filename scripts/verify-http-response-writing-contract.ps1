[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\http-response-writing.json"
$schemaPath = Join-Path $root "scripts\contracts\http-response-writing.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "HTTP response writing contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
foreach ($relativePath in $contract.sources) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "HTTP response writing source is missing: $relativePath"
    }
}
$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
foreach ($path in @($fixturePath, $expectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "HTTP response writing evidence is missing: $path"
    }
}

$source = [System.IO.File]::ReadAllText((Join-Path $root "stdlib\std\net\http\response.slg"))
foreach ($required in @(
    "namespace std.net.http.response",
    "public struct ResponseLimits",
    "public struct ResponsePolicy",
    "public enum ConnectionMode",
    "public enum BodyDisposition",
    "public struct ResponseWriter",
    "public struct ResponseHead",
    "public policy: self",
    "public response: self, method: Text",
    "public field: mut self, name: Text, value: Text",
    "public finish: move self",
    "public intoBytes: move self",
    "errors.Kind.ReservedResponseField",
    "errors.Kind.ResponseBodyNotAllowed",
    'appendField(bytes!, "Connection", "close")'
)) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP response writing implementation is missing: $required"
    }
}
foreach ($forbidden in @(
    "public field writer",
    "public finish writer",
    "Transfer-Encoding: chunked",
    "socket.",
    "dns."
)) {
    if ($source.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "HTTP response writing violates its instance or pure-layer contract: $forbidden"
    }
}
$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    'field("Content-Type", "text/plain")',
    'field("Content-Length", "0")',
    'field("X-Test", "safe\r\nInjected: yes")',
    "ResponseBodyNotAllowed",
    "ResponseHeadLimitExceeded",
    "maxHeadBytes: 15",
    "head.bodyDisposition",
    "ConnectionMode.Close"
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "HTTP response writing fixture no longer proves: $required"
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
    if (-not $gate.Contains("verify-http-response-writing-contract.ps1", [System.StringComparison]::Ordinal)) {
        throw "$gateName does not run the HTTP response writing contract preflight"
    }
}

Write-Host "[HTTP response writing contract] PASS $($contract.surfaces.Count) surfaces, $($contract.invariants.Count) invariants, fixture $($contract.fixture)."
