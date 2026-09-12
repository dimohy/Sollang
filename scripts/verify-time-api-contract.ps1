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
$boundProgramPath = Join-Path $root "src\Sollang.Compiler\Semantics\BoundProgram.cs"
$semanticCompilerPath = Join-Path $root "src\Sollang.Compiler\Semantics\SemanticCompiler.cs"
$runtimeIntrinsicsPath = Join-Path $root "src\Sollang.Compiler\CodeGen\LlvmEmitter.RuntimeIntrinsics.cs"
$functionCallsPath = Join-Path $root "src\Sollang.Compiler\CodeGen\LlvmEmitter.FunctionCalls.cs"
$selfhostRuntimePath = Join-Path $root "selfhost\llvm\runtime.slg"
$selfhostRuntimeResolutionPath = Join-Path $root "selfhost\llvm\text\runtime_resolution.slg"
$fixturePath = Join-Path $root "examples\regression\1694-time-source-deadline-clocks.slg"
$timerFixturePath = Join-Path $root "examples\regression\1695-time-affine-periodic-timer.slg"
$timerOwnershipDiagnosticPath = Join-Path $root "examples\regression\diagnostics\1695-time-timer-use-after-wait.slg"
$calendarFixturePath = Join-Path $root "examples\regression\1711-time-rfc3339-calendar-format.slg"
$calendarExpectedPath = Join-Path $root "examples\regression\expected\1711-time-rfc3339-calendar-format.stdout.txt"
$nativeExactBatchPath = Join-Path $root "scripts\verify-native-exact-fixture-batch.ps1"
foreach ($path in @($contractPath, $schemaPath, $publicPath, $runtimeTimePath, $runtimeClockPath, $boundProgramPath, $semanticCompilerPath, $runtimeIntrinsicsPath, $functionCallsPath, $selfhostRuntimePath, $selfhostRuntimeResolutionPath, $fixturePath, $timerFixturePath, $timerOwnershipDiagnosticPath, $calendarFixturePath, $calendarExpectedPath, $nativeExactBatchPath)) {
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
    $contract.officialReferences.Count -ne 5 -or
    $contract.implementedSurfaces.Count -ne 34 -or
    $contract.invariants.Count -ne 11 -or
    $contract.orderedSlices.Count -ne 6) {
    throw "time API contract dimensions drifted"
}
if ($contract.calendarFormatting.status -cne "in-progress" -or
    $contract.calendarFormatting.surface -cne "UtcInstant.formatRfc3339" -or
    $contract.calendarFormatting.format -cne "YYYY-MM-DDTHH:mm:ss.SSSZ" -or
    $contract.calendarFormatting.outputBytes -ne 24 -or
    $contract.calendarFormatting.outputOwnership -cne "caller-owned mutable byte array" -or
    $contract.calendarFormatting.minimumUnixMillis -ne -62135596800000 -or
    $contract.calendarFormatting.maximumUnixMillis -ne 253402300799999 -or
    $contract.calendarFormatting.errorKinds.Count -ne 2 -or
    $contract.calendarFormatting.errorKinds[0] -cne "CalendarOutOfRange" -or
    $contract.calendarFormatting.errorKinds[1] -cne "InsufficientOutput" -or
    $contract.calendarFormatting.fixture -cne "1711-time-rfc3339-calendar-format") {
    throw "time calendar formatting contract drifted"
}

$expectedSliceIds = @("T1", "T2", "T3", "T4", "T5", "T6")
$expectedSliceStatuses = @("complete", "complete", "complete", "in-progress", "complete", "pending")
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
    "public enum SuspendPolicy",
    "public struct ClockCapabilities",
    "public enum MissedTickPolicy",
    "public struct Timer",
    "public struct TimerTick",
    "CalendarOutOfRange",
    "InsufficientOutput",
    "public checkedAdd: self",
    "public checkedSub: self",
    "public checkedMultiply: self",
    "public checkedDivide: self",
    "public absoluteDifference: self",
    "public durationSince: self",
    "public formatRfc3339: self, output: mut [UInt8; ~] -> Result<Int, Error>",
    "public sourceIdentity: self -> UInt64",
    "public sameSource: self, other: MonotonicInstant -> Bool",
    "public deadlineAfter: self, duration: Duration -> Result<Deadline, Error>",
    "public capabilities: self -> ClockCapabilities",
    "public timer: self, period: Duration, policy: MissedTickPolicy -> Result<Timer, Error> uses Clock",
    "public wait: move self -> async Result<TimerTick, Error> uses Clock",
    "public cancel: move self -> Unit",
    "public close: move self -> Unit",
    "public intoTimer: move self -> Timer",
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
$selfhostRuntime = [System.IO.File]::ReadAllText($selfhostRuntimePath)
$selfhostRuntimeResolution = [System.IO.File]::ReadAllText($selfhostRuntimeResolutionPath)
foreach ($required in @(
    "public monotonicSuspendPolicyRef: RuntimeFunctionRef",
    "ret i8 0",
    "ret i8 1")) {
    if (-not $selfhostRuntime.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "self-host time capability lowering is missing: $required"
    }
}
foreach ($required in @(
    'monotonicSuspendPolicyRef: runtimeModule -> runtimeFunctionRef("monotonicSuspendPolicy", context)',
    'if { "monotonicSuspendPolicy" -> return }')) {
    if (-not $selfhostRuntimeResolution.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "self-host time capability resolution is missing: $required"
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
    "public utcNowMillis: -> Long = intrinsic",
    "public monotonicSuspendPolicy: -> UInt8 = intrinsic")) {
    if (-not $runtimeClock.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time runtime boundary is missing: $required"
    }
}
$boundProgram = [System.IO.File]::ReadAllText($boundProgramPath)
$semanticCompiler = [System.IO.File]::ReadAllText($semanticCompilerPath)
$runtimeIntrinsics = [System.IO.File]::ReadAllText($runtimeIntrinsicsPath)
$functionCalls = [System.IO.File]::ReadAllText($functionCallsPath)
if ($semanticCompiler.Contains("(function.IsStandardLibrary && !isAsyncRuntimeIntrinsic)", [System.StringComparison]::Ordinal)) {
    throw "managed compiler still rejects non-intrinsic standard-library async functions"
}
if (-not $semanticCompiler.Contains("or BoundFunctionKind.RuntimeNowMillis", [System.StringComparison]::Ordinal)) {
    throw "managed compiler async monotonic observation support is missing"
}
foreach ($required in @(
    "RuntimeMonotonicSuspendPolicy")) {
    if (-not $boundProgram.Contains($required, [System.StringComparison]::Ordinal) -or
        -not $semanticCompiler.Contains($required, [System.StringComparison]::Ordinal) -or
        -not $functionCalls.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "managed compiler time intrinsic identity is missing: $required"
    }
}
foreach ($required in @(
    '"sys.runtime.monotonicSuspendPolicy"',
    "BoundType.UInt8")) {
    if (-not $semanticCompiler.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "managed compiler time intrinsic signature is missing: $required"
    }
}
foreach ($required in @(
    "EmitRuntimeMonotonicSuspendPolicyIntrinsic",
    'WindowsLlvmRuntimePlatform => "0"',
    'LinuxLlvmRuntimePlatform => "1"',
    '_ => "2"')) {
    if (-not $runtimeIntrinsics.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "managed compiler time capability lowering is missing: $required"
    }
}
if (Test-Path -LiteralPath (Join-Path $root "stdlib\sys\time.slg")) {
    throw "deprecated public time compatibility surface returned"
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
$nativeExactBatch = [System.IO.File]::ReadAllText($nativeExactBatchPath)
foreach ($required in @(
    "time.monotonicClock() -> capabilities",
    "time.wallClock() -> capabilities",
    "IncludesSystemSuspend",
    "ExcludesSystemSuspend",
    "Unspecified",
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
$calendarFixture = [System.IO.File]::ReadAllText($calendarFixturePath)
$calendarExpected = [System.IO.File]::ReadAllText($calendarExpectedPath).Replace("`r`n", "`n")
foreach ($required in @(
    "-62_135_596_800_000",
    "-2_203_891_200_000",
    "951_827_696_789",
    "1_709_186_828_009",
    "253_402_300_799_999",
    "CalendarOutOfRange",
    "InsufficientOutput",
    "preservesSentinel(0)",
    "preservesSentinel(24)",
    "preservesStorage()?")) {
    if (-not $calendarFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time calendar fixture is missing: $required"
    }
}
foreach ($required in @(
    "0001-01-01T00:00:00.000Z",
    "1969-12-31T23:59:59.999Z",
    "1900-03-01T00:00:00.000Z",
    "2000-02-29T12:34:56.789Z",
    "2024-02-29T06:07:08.009Z",
    "9999-12-31T23:59:59.999Z",
    "range=true,short=true")) {
    if (-not $calendarExpected.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time calendar expected output is missing: $required"
    }
}
$timerFixture = [System.IO.File]::ReadAllText($timerFixturePath)
foreach ($required in @(
    "timer -> wait -> await",
    "tick -> intoTimer",
    "nextTimer -> close",
    "time.MissedTickPolicy.Delay",
    '"zero=rejected"')) {
    if (-not $timerFixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time affine timer fixture is missing: $required"
    }
}
$timerOwnershipDiagnostic = [System.IO.File]::ReadAllText($timerOwnershipDiagnosticPath)
foreach ($required in @(
    "timer -> wait => pending",
    "timer -> close",
    "pending -> cancel")) {
    if (-not $timerOwnershipDiagnostic.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "time affine timer ownership diagnostic is missing: $required"
    }
}

Write-Host "[time API contract] PASS $($contract.implementedSurfaces.Count) implemented surfaces, $($contract.invariants.Count) invariants, T1/T2/T3/T5 complete, T4 and calendar formatting in progress, and 3 target policies."
