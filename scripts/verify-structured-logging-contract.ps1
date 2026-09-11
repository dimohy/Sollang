[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\structured-logging.json"
$schemaPath = Join-Path $root "scripts\contracts\structured-logging.schema.json"
$sourcePath = Join-Path $root "stdlib\std\log.slg"
$fixturePath = Join-Path $root "examples\regression\1696-structured-logger-explicit-sink.slg"
$expectedPath = Join-Path $root "examples\regression\expected\1696-structured-logger-explicit-sink.stdout.txt"
foreach ($path in @($contractPath, $schemaPath, $sourcePath, $fixturePath, $expectedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "structured logging contract input is missing: $path"
    }
}

$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "structured logging contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
if ($contract.surfaces.Count -ne 9 -or $contract.invariants.Count -ne 6) {
    throw "structured logging contract dimensions drifted"
}

$source = [System.IO.File]::ReadAllText($sourcePath)
foreach ($required in @(
    "namespace std.log",
    "public enum Level",
    "public struct Field",
    "public struct Error",
    "public struct Record",
    "public trait Sink",
    "write: mut self, level: Level, message: Text, fields: [Field] -> Result<Unit, Error>",
    "public struct Logger",
    "public enabled: self, level: Level -> Bool",
    "public record: self, level: Level, message: Text -> Option<Record>",
    "Option<Record>.Some(Record { level: level, message: message })")) {
    if (-not $source.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "structured logging implementation is missing: $required"
    }
}
foreach ($forbidden in @("globalLogger", "defaultSink", "fallback", "uses Console")) {
    if ($source.Contains($forbidden, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "structured logging implementation retained forbidden ambient behavior: $forbidden"
    }
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    'record(log.Level.Debug, "filtered")',
    'record(log.Level.Info, "accepted")',
    'record(log.Level.Error, "fail")',
    "sink! -> log.Sink.write(record.level, record.message, fields)",
    '"calls=$(sink!.calls),fields=$(sink!.fields)"')) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "structured logging fixture is missing: $required"
    }
}
$expected = [System.IO.File]::ReadAllText($expectedPath)
if (-not $expected.Contains("calls=2,fields=2", [System.StringComparison]::Ordinal)) {
    throw "structured logging fixture does not prove the filtered sink path"
}

Write-Host "[structured logging contract] PASS 9 surfaces, 6 invariants, explicit sink, typed failure, and filtered-call control."
