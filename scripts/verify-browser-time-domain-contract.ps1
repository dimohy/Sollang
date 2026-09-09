[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\browser-time-domain.json"
$schemaPath = Join-Path $root "scripts\contracts\browser-time-domain.schema.json"
$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "browser time-domain contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
if ($contract.version -ne 1 -or
    $contract.defect -cne "C2026-09-03-248" -or
    $contract.hosts.Count -ne 4 -or
    $contract.officialReferences.Count -ne 2 -or
    $contract.invariants.Count -ne 5) {
    throw "browser time-domain contract dimensions drifted"
}

$managed = [System.IO.File]::ReadAllText((Join-Path $root $contract.managedRuntime))
foreach ($required in @(
    "declare i64 @$($contract.monotonicImport)()",
    "declare i64 @$($contract.wallImport)()",
    "%millis = call i64 @$($contract.monotonicImport)()",
    "%millis = call i64 @$($contract.wallImport)()")) {
    if (-not $managed.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "managed browser time runtime is missing: $required"
    }
}

$selfhost = [System.IO.File]::ReadAllText((Join-Path $root $contract.selfhostRuntime))
foreach ($required in @(
    "declare i64 @$($contract.monotonicImport)()",
    "declare i64 @$($contract.wallImport)()",
    "define internal i64 @sollang_now_millis()",
    "%value = call i64 @$($contract.monotonicImport)()",
    "define internal i64 @sollang_utc_now_millis()",
    "%value = call i64 @$($contract.wallImport)()")) {
    if (-not $selfhost.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "self-host browser time runtime is missing: $required"
    }
}

foreach ($relativePath in $contract.hosts) {
    $hostSource = [System.IO.File]::ReadAllText((Join-Path $root $relativePath))
    if (-not $hostSource.Contains($contract.monotonicImport, [System.StringComparison]::Ordinal) -or
        -not $hostSource.Contains($contract.wallImport, [System.StringComparison]::Ordinal) -or
        -not $hostSource.Contains("performance.now()", [System.StringComparison]::Ordinal) -or
        -not $hostSource.Contains("Date.now()", [System.StringComparison]::Ordinal)) {
        throw "browser time host does not expose both domains: $relativePath"
    }
    if ($hostSource -match 'sollang_browser_now_millis[^\r\n]*Date\.now\(\)') {
        throw "browser monotonic host aliases UTC time: $relativePath"
    }
    if ($hostSource -match 'sollang_browser_utc_now_millis[^\r\n]*performance\.now\(\)') {
        throw "browser UTC host aliases monotonic time: $relativePath"
    }
}

$fixturePath = Join-Path $root "examples\regression\$($contract.fixture).slg"
$expectedPath = Join-Path $root "examples\regression\expected\$($contract.fixture).stdout.txt"
$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "time.monotonicClock()",
    "after -> durationSince(before)?",
    "time.wallClock()",
    "current -> asUnixMilliseconds",
    "browser-time-domains=ok")) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "browser time-domain fixture is missing: $required"
    }
}
if ([System.IO.File]::ReadAllText($expectedPath).Trim() -cne "browser-time-domains=ok") {
    throw "browser time-domain expected output drifted"
}

Write-Host "[browser time domain] PASS distinct managed/self-host runtime imports, 4 hosts, and epoch/monotonic fixture."
