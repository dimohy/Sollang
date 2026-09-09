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
foreach ($path in @($contractPath, $schemaPath, $publicPath, $runtimeTimePath, $runtimeClockPath)) {
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
    $contract.implementedSurfaces.Count -ne 14 -or
    $contract.invariants.Count -ne 10 -or
    $contract.orderedSlices.Count -ne 6) {
    throw "time API contract dimensions drifted"
}

$expectedSliceIds = @("T1", "T2", "T3", "T4", "T5", "T6")
for ($index = 0; $index -lt $expectedSliceIds.Count; $index += 1) {
    $slice = $contract.orderedSlices[$index]
    if ($slice.id -cne $expectedSliceIds[$index] -or $slice.status -cne "pending") {
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
    "public checkedAdd: self",
    "public checkedSub: self",
    "public checkedMultiply: self",
    "public checkedDivide: self",
    "public absoluteDifference: self",
    "public durationSince: self",
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

Write-Host "[time API contract] PASS $($contract.implementedSurfaces.Count) implemented surfaces, $($contract.invariants.Count) invariants, $($contract.orderedSlices.Count) ordered gaps, and 3 target policies."
