[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root "scripts\contracts\time-api.json"
$schemaPath = Join-Path $root "scripts\contracts\time-api.schema.json"
$publicPath = Join-Path $root "stdlib\std\time.slg"
$runtimeTimePath = Join-Path $root "stdlib\sys\runtime\time.slg"
$runtimeClockPath = Join-Path $root "stdlib\sys\runtime\clock.slg"
$fixturePath = Join-Path $root "examples\regression\1694-time-source-deadline-clocks.slg"
$nativeExactBatchPath = Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"
foreach ($path in @($contractPath, $schemaPath, $publicPath, $runtimeTimePath, $runtimeClockPath, $fixturePath, $nativeExactBatchPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "time API contract input is missing: $path"
    }
}

$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "time API contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
if ($contract.version -ne 1 -or
    $contract.module -cne "std.time" -or
    $contract.runtimeModule -cne "sys.runtime" -or
    $contract.officialReferences.Count -ne 4 -or
    $contract.implementedSurfaces.Count -ne 23 -or
    $contract.invariants.Count -ne 10 -or
    $contract.orderedSlices.Count -ne 6) {
    throw "time API contract dimensions drifted"
}

$expectedSliceIds = @("T1", "T2", "T3", "T4", "T5", "T6")
$expectedSliceStatuses = @("pending", "in-progress", "in-progress", "pending", "in-progress", "pending")
for ($index = 0; $index -lt $expectedSliceIds.Count; $index += 1) {
    $slice = $contract.orderedSlices[$index]
    if ($slice.id -cne $expectedSliceIds[$index] -or $slice.status -cne $expectedSliceStatuses[$index]) {
        throw "time API slice order or status drifted at $($expectedSliceIds[$index])"
    }
}
if (@($contract.targetPolicy.psobject.Properties).Count -ne 3 -or
    $contract.targetPolicy.'wasm32-browser' -cnotmatch 'capability|diagnostic') {
    throw "time API target policy is incomplete"
}

$publicSource = [System.IO.File]::ReadAllText($publicPath)
foreach ($required in @(
    "namespace std.time",
    "public struct Duration",
    "public struct MonotonicInstant",
    "public struct UtcInstant",
    "public struct MonotonicClock",
    "public struct WallClock",
    "public struct ManualClock",
    "public struct ManualWallClock",
    "public struct Deadline",
    "public struct FixedClock",
    "public struct OffsetClock",
    "public checkedAdd: self",
    "public checkedSub: self",
    "public checkedMultiply: self",
    "public checkedDivide: self",
    "public absoluteDifference: self",
    "public durationSince: self",
    "public sourceIdentity: self -> UInt64",
    "public sameSource: self, other: MonotonicInstant -> Bool",
    "public deadlineAfter: self, duration: Duration -> Result<Deadline, Error>",
    "public remaining: self, now: MonotonicInstant -> Result<Duration, Error>",
    "public isDue: self, now: MonotonicInstant -> Result<Bool, Error>",
    "public now: self -> Result<UtcInstant, Error> uses Clock",
    "public now: self -> MonotonicInstant uses Clock",
    "public now: self -> UtcInstant uses Clock",
    "public advance: mut self",
    "public set: mut self")) {
    if (-not $publicSource.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time API implementation is missing: $required"
    }
}
foreach ($forbidden in @(
    "public sleep duration",
    "public nowMillis",
    "public utcNowMillis")) {
    if ($publicSource.Contains($forbidden, [System.StringComparison]::Ordinal)) {
        throw "time API exposes a forbidden public global operation: $forbidden"
    }
}

$runtimeTime = [System.IO.File]::ReadAllText($runtimeTimePath)
if (-not $runtimeTime.Contains("public sleep: move self -> async Unit uses Clock = intrinsic", [System.StringComparison]::Ordinal)) {
    throw "Duration.sleep is not a consuming instance intrinsic"
}
$runtimeClock = [System.IO.File]::ReadAllText($runtimeClockPath)
foreach ($required in @(
    "namespace sys.runtime",
    "public nowMillis: -> Long = intrinsic",
    "public utcNowMillis: -> Long = intrinsic")) {
    if (-not $runtimeClock.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time runtime boundary is missing: $required"
    }
}
if (Test-Path -LiteralPath (Join-Path $root "stdlib\sys\time.slg")) {
    throw "deprecated public time compatibility surface returned"
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
$nativeExactBatch = [System.IO.File]::ReadAllText($nativeExactBatchPath)
foreach ($required in @(
    "time.manualClock(7, 1_000)",
    "deadline -> remaining(start)",
    "deadline -> isDue(clock! -> now)",
    "time.fixedClock",
    "time.offsetClock(9_223_372_036_854_775_807)")) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time source/deadline fixture is missing: $required"
    }
}
if (-not $nativeExactBatch.Contains('"1694-time-source-deadline-clocks"', [System.StringComparison]::Ordinal)) {
    throw "time source/deadline fixture is missing from native exact promotion"
}

Write-Host "[time API contract] PASS $($contract.implementedSurfaces.Count) implemented surfaces, $($contract.invariants.Count) invariants, 3/6 active slices, and 3 target policies."
