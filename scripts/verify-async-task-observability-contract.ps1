[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/async-task-observability-static-' + [Guid]::NewGuid().ToString('N'))
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null

$contractPath = Join-Path $root 'scripts/contracts/async-task-observability.json'
$schemaPath = Join-Path $root 'scripts/contracts/async-task-observability.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/async-task-observability-static-result.schema.json'
$resultPath = Join-Path $output 'result.json'

function Read-Text([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "missing async observability input: $Path" }
    [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
}

function Get-HashMap([string[]]$Paths) {
    $hashes = [ordered]@{}
    foreach ($path in $Paths) {
        $full = [IO.Path]::GetFullPath($path)
        $hashes[$full] = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash
    }
    $hashes
}

function Test-MapsEqual($Left, $Right) {
    $leftJson = $Left | ConvertTo-Json -Compress
    $rightJson = $Right | ConvertTo-Json -Compress
    $leftJson -ceq $rightJson
}

function Assert-Contains([string]$Text, [string]$Needle, [string]$Label) {
    if (-not $Text.Contains($Needle, [StringComparison]::Ordinal)) { throw "$Label missing: $Needle" }
}

function Assert-Set([object[]]$Actual, [string[]]$Expected, [string]$Label) {
    $actualValues = @($Actual | ForEach-Object { [string]$_ } | Sort-Object)
    $expectedValues = @($Expected | Sort-Object)
    if (($actualValues -join '|') -cne ($expectedValues -join '|')) { throw "$Label drifted" }
}

$contract = Read-Text $contractPath | ConvertFrom-Json
$authorityPaths = @($contract.authority.psobject.Properties.Value | ForEach-Object {
    $relative = [string]$_
    if ($relative.Contains('#')) { $relative = $relative.Substring(0, $relative.IndexOf('#')) }
    Join-Path $root $relative
})
$probePaths = @($contract.probeMatrix.source | Sort-Object -Unique | ForEach-Object { Join-Path $root $_ })
$focusedExpectedPaths = @($contract.focusedInitialGate.cases.expectedOutput | Sort-Object -Unique | ForEach-Object { Join-Path $root $_ })
$inputs = @($contractPath, $schemaPath, $resultSchemaPath, $PSCommandPath) + $authorityPaths + $probePaths + $focusedExpectedPaths
$startHashes = Get-HashMap $inputs
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'async-task-observability-contract-freeze'
    completed = 0
    total = 14
    checks = @()
    failureIds = @()
    inputHashesStart = $startHashes
    inputHashesEnd = $startHashes
    inputDrift = $false
    matrix = $contract.denominators
}

function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Complete([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}

Save-Result
try {
    $contractJson = Read-Text $contractPath
    if (-not ($contractJson | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
        throw 'contract does not satisfy async observability schema'
    }
    Complete 'schema-positive'

    foreach ($negative in @(
        $contractJson.Replace('"ambientRegistry": false', '"ambientRegistry": true'),
        $contractJson.Replace('"maximumTrackedTasks": 65535', '"maximumTrackedTasks": 0'),
        $contractJson.Replace('"implementationStatus": "contract-frozen"', '"implementationStatus": "complete"'),
        $contractJson.Replace('"total": 4', '"total": 5'),
        $contractJson.Replace('"utf8ByteOffset": 2897', '"utf8ByteOffset": 0'),
        $contractJson.Replace('"genericUserAdtRequired": false', '"genericUserAdtRequired": true'),
        $contractJson.Replace('"trackFailureType": "(T, TrackFailureKind) where T is Task<U>"', '"trackFailureType": "TrackFailure<T>"')
    )) {
        if ($negative | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue) {
            throw 'schema accepted an authority-expanding negative control'
        }
    }
    Complete 'schema-negative-controls'

    if ($contract.activation.kind -cne 'explicit-affine-instance' -or
        $contract.activation.default -cne 'off' -or $contract.activation.ambientRegistry -ne $false -or
        $contract.activation.schedulerSemanticChanges -ne $false -or
        $contract.activation.attachment -notmatch 'Result<T, \(T, TrackFailureKind\)> where the compiler requires T to be Task<U>') {
        throw 'explicit affine opt-in activation contract drifted'
    }
    Assert-Set $contract.forbidden @(
        'ambient process-global mutable task registry', 'production-on default',
        'unbounded record or snapshot allocation', 'scheduler queue reordering or extra scheduler progress',
        'task cancellation, resume, wake, or priority control through diagnostics',
        'raw context, function pointer, queue link, or native handle exposure',
        'cross-session task lookup', 'snapshot buffer retention'
    ) 'forbidden authority set'
    Assert-Contains $contract.activation.propagation 'structured child inherit the same session' 'structured task propagation'
    Assert-Contains $contract.activation.validation 'returns its owner' 'tracking failure ownership'
    Assert-Contains $contract.activation.capacityOutcome 'scheduling remain unchanged' 'capacity scheduling isolation'
    Complete 'explicit-opt-in-and-authority-boundary'

    Assert-Set $contract.publicSurface.types @(
        'Lifecycle', 'WaitState', 'DiagnosticError', 'TrackFailureKind', 'DiagnosticCloseFailureKind',
        'DiagnosticLimits', 'SuspensionLocator', 'TaskSnapshot', 'SnapshotResult', 'DiagnosticSummary',
        'DiagnosticSession', 'DiagnosticCloseFailure'
    ) 'public diagnostics types'
    Assert-Set $contract.publicSurface.signatures @(
        'startDiagnosticSession(DiagnosticLimits) -> Result<DiagnosticSession, DiagnosticError>',
        'DiagnosticSession.track<T>(mut self, move T) -> Result<T, (T, TrackFailureKind)> where T is Task<U>',
        'DiagnosticSession.snapshot(self, mut [TaskSnapshot; ~]) -> SnapshotResult',
        'DiagnosticSession.close(move self) -> Result<DiagnosticSummary, DiagnosticCloseFailure>'
    ) 'public diagnostics signatures'
    if ($contract.publicSurface.trackFailureType -cne '(T, TrackFailureKind) where T is Task<U>' -or
        $contract.publicSurface.genericUserAdtRequired -ne $false -or
        $contract.publicSurface.probeCanonicalFormatterPublic -ne $false -or
        $contractJson.Contains('TrackFailure<T>', [StringComparison]::Ordinal)) {
        throw 'track failure surface requires unsupported generic user ADT or exposes probe formatter'
    }

    Assert-Contains $contract.identity.sessionId 'never reused' 'session identity rule'
    Assert-Contains $contract.identity.taskId 'stable within one session' 'task identity rule'
    Assert-Contains $contract.identity.reuseAfterClose 'restart at 1 only in a later session' 'post-close reuse rule'
    Assert-Contains $contract.close.activeTaskRule 'same session owner' 'busy close ownership rule'
    Assert-Contains $contract.close.successRule 'released exactly once' 'successful close ownership rule'
    Complete 'identity-close-and-reuse'

    Assert-Set $contract.stateModel.lifecycle @('Pending', 'Running', 'Completed', 'Cancelled') 'lifecycle states'
    Assert-Set $contract.stateModel.waitState @('None', 'Ready', 'Timer', 'AwaitBlocked') 'wait states'
    $expectedMapping = @('0=Pending/Ready', '1=Running/None', '2=Completed/None', '3=Cancelled/None', '4=Pending/Timer', '5=Pending/AwaitBlocked')
    $actualMapping = @($contract.stateModel.runtimeStatusMapping.psobject.Properties | ForEach-Object { $_.Name + '=' + [string]$_.Value })
    Assert-Set $actualMapping $expectedMapping 'runtime status mapping'
    Complete 'public-state-model'

    if ($contract.bounds.minimumTrackedTasks -ne 1 -or $contract.bounds.maximumTrackedTasks -ne 65535 -or
        $contract.bounds.unboundedAllocation -ne $false -or $contract.snapshot.allocation -cne 'zero allocations per snapshot' -or
        $contract.snapshot.ordering -cne 'ascending TaskId') {
        throw 'bounded caller-owned snapshot contract drifted'
    }
    Assert-Contains $contract.snapshot.consistency 'neither pumps ready work nor wakes timers' 'snapshot scheduling isolation'
    Assert-Contains $contract.snapshot.terminalRetention 'until successful session close' 'terminal record retention'
    Assert-Contains $contract.snapshot.locatorPresence 'intrinsic suspension call-site' 'suspension locator presence'
    Assert-Set $contract.snapshot.recordFields @('taskId', 'parentTaskId', 'lifecycle', 'waitState', 'awaitedTaskId', 'timerDeadlineMillis', 'suspension') 'snapshot fields'
    Assert-Set $contract.snapshot.suspensionLocator @('sourceModule', 'functionSymbol', 'resumeState', 'byteOffset', 'line', 'column') 'suspension locator'
    Complete 'bounded-caller-owned-snapshot'

    $spec = Read-Text (Join-Path $root 'docs/SPEC.md')
    $managedLayout = Read-Text (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.cs')
    $managedAsync = Read-Text (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Async.cs')
    $selfhostRuntime = Read-Text (Join-Path $root 'selfhost/llvm/emitter/async_runtime.slg')
    $selfhostLayout = Read-Text (Join-Path $root 'selfhost/llvm/text/core_prepare.slg')
    $selfhostTyped = Read-Text (Join-Path $root 'selfhost/ir/typed.slg')
    foreach ($needle in @('Tasks are structured resources, not detached handles.', 'ready-queue link, lifecycle status, and resume state.', 'assign stable one-based states per async function')) {
        Assert-Contains $spec $needle 'structured async authority'
    }
    foreach ($text in @($managedLayout, $selfhostLayout)) {
        Assert-Contains $text '%sollang.task_control = type { ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, i64, ptr, ptr, i32, i32, i64, i64, i32, ptr, i64, i64, i32, i32 }' 'task-control layout authority'
    }
    foreach ($text in @($managedAsync, $selfhostRuntime)) {
        foreach ($needle in @('getelementptr %sollang.task_control, ptr %control, i32 0, i32 5', 'sollang_task_cancel')) {
            Assert-Contains $text $needle 'async state/cancel authority'
        }
    }
    foreach ($needle in @('store i32 0, ptr %status_slot', 'store i32 5, ptr %parent_status_slot', 'store i32 4, ptr %status_slot')) {
        Assert-Contains $selfhostRuntime $needle 'selfhost scheduler state authority'
    }
    foreach ($needle in @('public struct CoroutineSuspendPoint', 'public awaitAst: Int', 'public state: Int', 'public kind: Int')) {
        Assert-Contains $selfhostTyped $needle 'selfhost suspension metadata authority'
    }
    $managedSemantics = Read-Text (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs')
    foreach ($needle in @(
        'if (function.IsAsync) mismatches.Add("async")',
        '|| function.IsAsync)',
        'DiagnosticSession.track<T> requires T to be Task<U>',
        '!_types.IsTask(actualType)',
        'Result<T, (T, TrackFailureKind)>'
    )) { Assert-Contains $managedSemantics $needle 'managed diagnostics signature authority' }
    $managedLocator = Read-Text (Join-Path $root 'src/Sollang.Compiler/Semantics/AsyncSuspensionLocator.cs')
    foreach ($needle in @(
        'case FlowExpression value:',
        'case CallExpression value:',
        'case IfExpression conditional:',
        'case WhenExpression selection:',
        'case EnumMatchExpression selection:',
        'case FoldExpression value:',
        'async suspension locator for'
    )) { Assert-Contains $managedLocator $needle 'managed nested suspension locator authority' }
    Complete 'managed-selfhost-authority-anchors'

    $ids = @($contract.probeMatrix.id)
    if ($ids.Count -ne 13 -or (@($ids | Sort-Object -Unique)).Count -ne 13) { throw 'focused probe IDs must be unique 13/13' }
    foreach ($path in $probePaths) { [void](Read-Text $path) }
    foreach ($probe in $contract.probeMatrix) {
        if ($probe.class -ceq 'authority-negative' -and $probe.expectation -cne 'compiler-rejected') {
            throw "authority negative probe is not compiler-rejected: $($probe.id)"
        }
    }
    $off = Read-Text (Join-Path $root 'scripts/probes/async-task-observability/production-off.slg')
    if ($off.Contains('std.async.diagnostics', [StringComparison]::Ordinal) -or $off.Contains('DiagnosticSession', [StringComparison]::Ordinal)) {
        throw 'production-off probe activates observability'
    }
    Complete 'focused-probe-inventory-and-off-control'

    $focusedIds = @($contract.focusedInitialGate.cases.id)
    Assert-Set $focusedIds @(
        'normal-parent-child-states',
        'normal-stable-id-transitions',
        'normal-suspension-locator',
        'production-off-zero-overhead'
    ) 'initial focused case IDs'
    if ($contract.focusedInitialGate.total -ne 4 -or (@($focusedIds | Sort-Object -Unique)).Count -ne 4) {
        throw 'initial focused gate denominator drifted'
    }
    foreach ($focused in $contract.focusedInitialGate.cases) {
        $matrix = @($contract.probeMatrix | Where-Object id -CEQ $focused.id)
        if ($matrix.Count -ne 1 -or $matrix[0].source -cne $focused.source) {
            throw "initial focused source is not the probe-matrix authority: $($focused.id)"
        }
    }
    Complete 'initial-focused-matrix'

    foreach ($expectedPath in $focusedExpectedPaths) {
        $expected = Read-Text $expectedPath
        if ([string]::IsNullOrWhiteSpace($expected) -or -not $expected.EndsWith("`n", [StringComparison]::Ordinal)) {
            throw "focused expected output must be nonempty LF-terminated text: $expectedPath"
        }
    }
    $parentExpected = Read-Text (Join-Path $root 'scripts/probes/async-task-observability/parent-child-states.expected.txt')
    foreach ($needle in @(
        'taskId=1 parentTaskId=None lifecycle=Pending waitState=Ready',
        'taskId=1 parentTaskId=None lifecycle=Pending waitState=AwaitBlocked awaitedTaskId=Some(2)',
        'taskId=2 parentTaskId=Some(1) lifecycle=Pending waitState=AwaitBlocked awaitedTaskId=Some(3)',
        'taskId=3 parentTaskId=Some(2) lifecycle=Pending waitState=Timer',
        'taskId=3 parentTaskId=Some(2) lifecycle=Completed waitState=None'
    )) { Assert-Contains $parentExpected $needle 'parent-child canonical output' }
    $stableExpected = Read-Text (Join-Path $root 'scripts/probes/async-task-observability/stable-id-transitions.expected.txt')
    foreach ($needle in @(
        'taskId=1 parentTaskId=None lifecycle=Pending waitState=Ready',
        'taskId=2 parentTaskId=None lifecycle=Pending waitState=Ready',
        'taskId=1 parentTaskId=None lifecycle=Completed waitState=None',
        'taskId=2 parentTaskId=None lifecycle=Completed waitState=None'
    )) { Assert-Contains $stableExpected $needle 'stable-id canonical output' }
    Complete 'canonical-exact-output-contracts'

    $unicodeSourcePath = Join-Path $root 'scripts/probes/async-task-observability/unicode-suspension-locator.slg'
    $unicodeSource = Read-Text $unicodeSourcePath
    $awaitNeedle = 'await'
    $awaitMatch = [regex]::Match($unicodeSource, '\bawait\b')
    $awaitCharacterOffset = if ($awaitMatch.Success) { $awaitMatch.Index } else { -1 }
    if ($awaitCharacterOffset -lt 0) { throw 'Unicode locator probe has no await token' }
    $awaitPrefix = $unicodeSource.Substring(0, $awaitCharacterOffset)
    $awaitByteOffset = [Text.Encoding]::UTF8.GetByteCount($awaitPrefix)
    $awaitLine = 1 + [regex]::Matches($awaitPrefix, "`n").Count
    $lastNewLine = $awaitPrefix.LastIndexOf("`n", [StringComparison]::Ordinal)
    $awaitColumn = $awaitCharacterOffset - $lastNewLine
    if ($awaitByteOffset -ne 2897 -or $awaitLine -ne 78 -or $awaitColumn -ne 39 -or
        $awaitByteOffset -le $awaitCharacterOffset -or -not $awaitPrefix.Contains('한글😀', [StringComparison]::Ordinal)) {
        throw "Unicode await locator drifted: byteOffset=$awaitByteOffset line=$awaitLine column=$awaitColumn"
    }
    $unicodeExpected = Read-Text (Join-Path $root 'scripts/probes/async-task-observability/unicode-suspension-locator.expected.txt')
    $locatorContract = @($contract.focusedInitialGate.cases | Where-Object id -CEQ 'normal-suspension-locator')[0].locatorExpectation
    if ($locatorContract.token -cne 'await' -or $locatorContract.utf8ByteOffset -ne $awaitByteOffset -or
        $locatorContract.line -ne $awaitLine -or $locatorContract.column -ne $awaitColumn) {
        throw 'Unicode source locator and structured expectation disagree'
    }
    Assert-Contains $unicodeExpected 'byteOffset=2897;line=78;column=39)' 'Unicode await canonical locator'
    $sleepMatch = [regex]::Match($unicodeSource, '\bsleep\b')
    $sleepCharacterOffset = if ($sleepMatch.Success) { $sleepMatch.Index } else { -1 }
    if ($sleepCharacterOffset -lt 0) { throw 'Unicode locator probe has no sleep token' }
    $sleepPrefix = $unicodeSource.Substring(0, $sleepCharacterOffset)
    $sleepByteOffset = [Text.Encoding]::UTF8.GetByteCount($sleepPrefix)
    $sleepLine = 1 + [regex]::Matches($sleepPrefix, "`n").Count
    $sleepLastNewLine = $sleepPrefix.LastIndexOf("`n", [StringComparison]::Ordinal)
    $sleepColumn = $sleepCharacterOffset - $sleepLastNewLine
    if ($sleepByteOffset -ne 2888 -or $sleepLine -ne 78 -or $sleepColumn -ne 30) {
        throw "Unicode sleep locator drifted: byteOffset=$sleepByteOffset line=$sleepLine column=$sleepColumn"
    }
    Assert-Contains $unicodeExpected 'byteOffset=2888;line=78;column=30)' 'Unicode sleep canonical locator'
    if ($unicodeExpected.Contains('byteOffset=0', [StringComparison]::Ordinal) -or
        $unicodeExpected.Contains('byteOffset=-1', [StringComparison]::Ordinal)) {
        throw 'Unicode locator accepted a zero or sentinel byte offset'
    }
    Complete 'authoritative-utf8-byte-locator'

    $managedRuntime = Read-Text (Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmRuntimePlatform.cs')
    foreach ($needle in @(
        'store i32 5, ptr %parent_status_slot',
        'call i1 %worker(ptr %ready)',
        'br i1 %worker_complete, label %complete, label %requeue',
        'br i1 %waiting, label %poll, label %requeue_ready',
        'store ptr %ready, ptr @sollang_task_ready_tail'
    )) { Assert-Contains $managedRuntime $needle 'FIFO observation harness authority' }
    $parseTokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$parseTokens, [ref]$parseErrors)
    if (@($parseErrors).Count -ne 0) { throw 'async observability verifier does not parse cleanly' }
    Complete 'fifo-harness-and-verifier-parser'

    $classCounts = @{}
    foreach ($group in $contract.probeMatrix | Group-Object class) { $classCounts[$group.Name] = $group.Count }
    foreach ($name in @('normal', 'boundary', 'authority-negative', 'production-off')) {
        if ($classCounts[$name] -ne $contract.denominators.classes.$name) { throw "class denominator drifted: $name" }
    }
    $managedCount = @($contract.probeMatrix | Where-Object managed).Count
    $selfhostCount = @($contract.probeMatrix | Where-Object selfhost).Count
    $windowsCount = @($contract.probeMatrix | Where-Object { $_.platforms -contains 'windows-x64' }).Count
    $linuxCount = @($contract.probeMatrix | Where-Object { $_.platforms -contains 'linux-x64' }).Count
    $browserCount = @($contract.probeMatrix | Where-Object { $_.platforms -contains 'wasm32-browser' }).Count
    if ($managedCount -ne 13 -or $selfhostCount -ne 13 -or $windowsCount -ne 8 -or $linuxCount -ne 8 -or $browserCount -ne 1 -or
        ($windowsCount + $linuxCount + $browserCount) -ne 17) {
        throw 'managed/selfhost/platform denominator drifted'
    }
    Complete 'fixed-matrix-denominators'

    if ($contract.productionOffGate.taskControlBytes -ne 152 -or
        $contract.productionOffGate.allocationCount -ne 2 -or
        $contract.productionOffGate.releaseCount -ne 2 -or
        $contract.productionOffGate.invalidReleaseCount -ne 0 -or
        $contract.productionOffGate.required.Count -ne 4) {
        throw 'production-off exact overhead gate drifted'
    }
    if (-not $managedLayout.Contains('@sollang_diagnostic_next_session_id = internal global i64 1', [StringComparison]::Ordinal) -or
        $selfhostLayout.Contains('@sollang_diagnostic_', [StringComparison]::Ordinal)) {
        throw 'managed-only diagnostics implementation boundary drifted'
    }
    Complete 'production-off-layout-and-symbol-baseline'

    $record.inputHashesEnd = Get-HashMap $inputs
    $record.inputDrift = -not (Test-MapsEqual $record.inputHashesStart $record.inputHashesEnd)
    if ($record.inputDrift) { throw 'async observability static inputs drifted during verification' }
    $record.status = 'passed'
    Save-Result
    if (-not ((Read-Text $resultPath) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue)) {
        throw 'async observability result does not satisfy its schema'
    }
    Write-Host "[async task observability contract] PASS 14/14; focused-initial 4/4 frozen; managed 0/13; selfhost 0/13; platform 0/17; $resultPath"
} catch {
    $record.status = 'failed'
    $record.failureIds = @('ASYNC_TASK_OBSERVABILITY_STATIC_CONTRACT_FAILED')
    $record.failure = $_.Exception.Message
    $record.inputHashesEnd = Get-HashMap $inputs
    $record.inputDrift = -not (Test-MapsEqual $record.inputHashesStart $record.inputHashesEnd)
    Save-Result
    throw
}
