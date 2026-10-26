[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
& (Join-Path $PSScriptRoot 'verify-interpolation-semantic-parity.ps1') -RepositoryRoot $RepositoryRoot
if (-not $?) { throw 'interpolation semantic parity mapping is invalid' }
$ledgerPath = Join-Path $RepositoryRoot 'scripts\contracts\stabilization-progress.json'
$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
$compilerLedger = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'scripts\contracts\compiler-defects.json') -Raw | ConvertFrom-Json
$stdlibLedger = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'scripts\contracts\stdlib-evolution-progress.json') -Raw | ConvertFrom-Json

$fixtures = @($ledger.focusedFixtures)
if ($fixtures.Count -ne 33) {
    throw "focused progress denominator changed: expected 33, actual $($fixtures.Count)"
}
$uniqueFixtures = @($fixtures.name | Sort-Object -Unique)
if ($uniqueFixtures.Count -ne $fixtures.Count) {
    throw 'focused progress contains duplicate fixture names'
}
foreach ($fixture in $fixtures) {
    if ($fixture.status -cnotin @('passed', 'timeout')) {
        throw "unsupported focused fixture status '$($fixture.status)': $($fixture.name)"
    }
    $source = Join-Path $RepositoryRoot "examples\regression\$($fixture.name).slg"
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "focused progress fixture source is missing: $($fixture.name)"
    }
}

$stages = @($ledger.stageGates)
if ($stages.Count -ne 2 -or
    (@($stages.name | Sort-Object -Unique) -join ',') -cne 'stage2,stage3') {
    throw 'stage progress must contain exactly stage2 and stage3'
}
$collaboration = @($ledger.collaborationGates)
. (Join-Path $PSScriptRoot 'collaboration-evidence.ps1')
Assert-CollaborationEvidence -RepositoryRoot $RepositoryRoot -Gates $collaboration
if ($collaboration.Count -ne 3 -or
    @($collaboration.name | Sort-Object -Unique).Count -ne 3) {
    throw 'collaboration progress must contain three unique gates'
}

$progress = & (Join-Path $RepositoryRoot 'scripts\show-project-progress.ps1') `
    -RepositoryRoot $RepositoryRoot -AsJson | ConvertFrom-Json
if ($progress.focused.total -ne 33 -or
    $progress.focused.passed + $progress.focused.timeout -ne 33) {
    throw 'reported focused progress does not preserve the frozen denominator'
}
if ($progress.stages.total -ne 2 -or $progress.collaboration.total -ne 3) {
    throw 'reported stage or collaboration denominator drifted'
}
if ($null -eq $progress.currentGoal) {
    throw 'current goal progress is missing'
}
if ($progress.currentGoal.currentWork.stepsTotal -ne @($progress.currentGoal.currentWork.steps).Count -or
    $progress.currentGoal.currentWork.stepsComplete -ne @($progress.currentGoal.currentWork.steps | Where-Object status -ceq 'complete').Count -or
    $progress.currentGoal.currentWork.focusedTotal -ne @($progress.currentGoal.currentWork.focusedCases).Count -or
    $progress.currentGoal.currentWork.focusedComplete -ne @($progress.currentGoal.currentWork.focusedCases | Where-Object status -ceq 'complete').Count) {
    throw 'current work progress must be derived from individual step and case statuses'
}
$completedUnits = @($progress.currentGoal.completedUnits)
if (@($completedUnits | ForEach-Object id | Sort-Object -Unique).Count -ne $completedUnits.Count -or
    $completedUnits.id -ccontains $progress.currentGoal.currentWork.id) {
    throw 'completed implementation units must be unique and separate from current work'
}
foreach ($unit in $completedUnits) {
    $unknownSteps = $null -eq $unit.stepsComplete -and $null -eq $unit.stepsTotal
    $validSteps = if ($unknownSteps) {
        $unit.PSObject.Properties['stepsEvidenceState'] -and
            $unit.stepsEvidenceState -ceq 'unknown' -and
            $unit.PSObject.Properties['stepsEvidenceReason'] -and
            -not [string]::IsNullOrWhiteSpace($unit.stepsEvidenceReason)
    } else {
        ($unit.stepsComplete -is [int] -or $unit.stepsComplete -is [long]) -and
            ($unit.stepsTotal -is [int] -or $unit.stepsTotal -is [long]) -and
            $unit.stepsComplete -eq $unit.stepsTotal -and $unit.stepsTotal -gt 0
    }
    if ($unit.status -cne 'complete' -or -not $validSteps -or
        -not ($unit.focusedComplete -is [int] -or $unit.focusedComplete -is [long]) -or
        -not ($unit.focusedTotal -is [int] -or $unit.focusedTotal -is [long]) -or
        $unit.focusedComplete -ne $unit.focusedTotal -or
        $unit.focusedTotal -le 0 -or
        [string]::IsNullOrWhiteSpace($unit.evidence) -or
        -not (Test-Path -LiteralPath (Join-Path $RepositoryRoot $unit.evidence) -PathType Leaf)) {
        throw "completed implementation unit lacks exact counts or evidence: $($unit.id)"
    }
}
$unitProgress = $progress.currentGoal.identifiedImplementationUnits
$expectedUnitComplete = $completedUnits.Count
$queuedUnits = @($progress.currentGoal.queuedUnits)
$expectedUnitTotal = $completedUnits.Count + $queuedUnits.Count
if ($unitProgress.complete -ne $expectedUnitComplete -or
    $unitProgress.total -ne $expectedUnitTotal -or
    $unitProgress.remaining -ne ($expectedUnitTotal - $expectedUnitComplete) -or
    $unitProgress.completePercent -ne [Math]::Round(100.0 * $expectedUnitComplete / $expectedUnitTotal, 2) -or
    $unitProgress.currentId -cne $progress.currentGoal.currentWork.id -or
    @($unitProgress.completedIds).Count -ne $expectedUnitComplete -or
    @($unitProgress.completedIds | Select-Object -Unique).Count -ne $expectedUnitComplete -or
    @($unitProgress.queuedIds).Count -ne $queuedUnits.Count -or
    @($unitProgress.queuedIds | Select-Object -Unique).Count -ne $queuedUnits.Count) {
    throw 'identified implementation unit progress must match completed units and current work'
}
if ($progress.currentGoal.verificationSequence.finalSweepStatus -cne 'pending' -and
    $progress.currentGoal.implementationParity.complete -lt $progress.currentGoal.implementationParity.total) {
    throw 'complete C# and SLG comparison cannot start before unit alignment is complete'
}
if ($progress.currentGoal.implementationParity.total -ne 7 -or
    $progress.currentGoal.implementationParity.complete -ne @($progress.currentGoal.implementationParity.phases | Where-Object aligned -ceq 'complete').Count) {
    throw 'structural parity progress must be derived from the seven implementation phases'
}
if ($progress.currentGoal.stages.total -ne 2 -or $progress.currentGoal.stages.complete -ne 0) {
    throw 'current goal Stage2/Stage3 state must remain independently pending'
}
$authoritativeCompilerTotal = @($compilerLedger.defects).Count
$authoritativeCompilerClosed = @($compilerLedger.defects | Where-Object state -ceq 'closed').Count
$authoritativeCompilerCandidate = @($compilerLedger.defects | Where-Object state -ceq 'candidate-fixed').Count
$authoritativeCompilerStabilized = @($compilerLedger.defects | Where-Object state -in @('closed', 'candidate-fixed')).Count
$authoritativeCompilerOpen = @($compilerLedger.defects | Where-Object state -ceq 'open').Count
if ($progress.currentGoal.compiler.total -ne $authoritativeCompilerTotal -or
    $progress.currentGoal.compiler.stabilized -ne $authoritativeCompilerClosed -or
    $progress.currentGoal.compiler.candidateFixed -ne $authoritativeCompilerCandidate -or
    $progress.currentGoal.compiler.knownResolved -ne $authoritativeCompilerStabilized -or
    $progress.currentGoal.compiler.open -ne $authoritativeCompilerOpen -or
    $progress.currentGoal.compiler.stabilized -ne $progress.compiler.closed) {
    throw 'current goal compiler closure must exclude candidate-fixed defects'
}
$authoritativeStdlibTotal = @($stdlibLedger.contracts).Count
$authoritativeStdlibComplete = @($stdlibLedger.contracts | Where-Object status -ceq 'complete').Count
$authoritativeStdlibInProgress = @($stdlibLedger.contracts | Where-Object status -ceq 'in-progress').Count
$authoritativeStdlibBlocked = @($stdlibLedger.contracts | Where-Object status -ceq 'blocked').Count
if ($progress.currentGoal.stdlib.complete -ne $authoritativeStdlibComplete -or
    $progress.currentGoal.stdlib.total -ne $authoritativeStdlibTotal -or
    $progress.currentGoal.stdlib.inProgress -ne $authoritativeStdlibInProgress -or
    $progress.currentGoal.stdlib.blocked -ne $authoritativeStdlibBlocked) {
    throw 'current goal stdlib progress must be derived from the authoritative backlog'
}
$baselineInstant = [DateTimeOffset]$progress.currentGoal.baseline.observedLocal
if ($baselineInstant.ToOffset([TimeSpan]::FromHours(9)).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture) -cne '2026-09-13T08:28:00+09:00' -or
    $progress.currentGoal.baselineDisplay -cne '2026-09-13 08:28 KST') {
    throw 'current goal baseline display must be culture-independent KST'
}
if ($progress.currentGoal.baseline.compiler.total -ne 418 -or
    $progress.currentGoal.baseline.compiler.stabilized -ne 405 -or
    $progress.currentGoal.baseline.compiler.open -ne 13 -or
    $progress.currentGoal.baseline.stdlib.total -ne 22 -or
    $progress.currentGoal.baseline.stdlib.complete -ne 5) {
    throw '08:28 baseline counts drifted'
}
if ($progress.currentGoal.compiler.knownResolvedDelta -ne ($authoritativeCompilerStabilized - 405) -or
    $progress.currentGoal.compiler.totalDelta -ne ($authoritativeCompilerTotal - 418) -or
    $progress.currentGoal.compiler.openDelta -ne ($authoritativeCompilerOpen - 13) -or
    $progress.currentGoal.stdlib.completeDelta -ne ($authoritativeStdlibComplete - 5)) {
    throw 'current goal delta is not derived from the frozen 08:28 baseline'
}
function Assert-ProjectFocusedGateProjection {
    param([object]$CurrentGoal, [object]$Ledger, [object]$History)
    $selectedName = [string]$Ledger.currentFocusedGate
    $selected = @($CurrentGoal.focusedGates | Where-Object name -ceq $selectedName)
    $declared = @($Ledger.focusedGates | Where-Object name -ceq $selectedName)
    if ($selected.Count -ne 1 -or $declared.Count -ne 1 -or
        $CurrentGoal.currentFocusedGate.name -cne $selectedName) {
        throw 'PROJECT_CURRENT_FOCUSED_GATE_INVALID'
    }
    foreach ($field in @('status', 'completed', 'total', 'evidence')) {
        if ($selected[0].$field -cne $declared[0].$field -or
            $CurrentGoal.currentFocusedGate.$field -cne $declared[0].$field) {
            throw 'PROJECT_CURRENT_FOCUSED_GATE_INVALID'
        }
    }
    $historical = @($History.focusedGates)
    foreach ($expected in @(
        @{ name = 'C385 13-family wrapper static'; count = 5 },
        @{ name = 'C385 13-family paired actual'; count = 1 }
    )) {
        $record = @($historical | Where-Object name -ceq $expected.name)
        if ($record.Count -eq 0) { throw 'PROJECT_C385_HISTORICAL_FOCUS_MISSING' }
        if ($record.Count -ne 1) { throw 'PROJECT_C385_HISTORICAL_FOCUS_AMBIGUOUS' }
        if ($record[0].status -cne 'complete' -or
            $record[0].completed -ne $expected.count -or $record[0].total -ne $expected.count) {
            throw 'PROJECT_C385_HISTORICAL_FOCUS_CHANGED'
        }
    }
}
$activeGoalLedger = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'scripts/contracts/active-goal-progress.json') -Raw | ConvertFrom-Json
$focusedHistoryPath = [IO.Path]::GetFullPath($activeGoalLedger.focusedGateHistory, $RepositoryRoot)
$focusedHistoryPrefix = [IO.Path]::TrimEndingDirectorySeparator($RepositoryRoot) + [IO.Path]::DirectorySeparatorChar
if (-not $focusedHistoryPath.StartsWith($focusedHistoryPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath $focusedHistoryPath -PathType Leaf)) {
    throw 'PROJECT_FOCUSED_HISTORY_MISSING'
}
$focusedHistory = Get-Content -LiteralPath $focusedHistoryPath -Raw | ConvertFrom-Json
Assert-ProjectFocusedGateProjection -CurrentGoal $progress.currentGoal -Ledger $activeGoalLedger -History $focusedHistory
foreach ($gate in @($progress.currentGoal.focusedGates)) {
    if ($gate.total -le 0 -or $gate.completed -lt 0 -or $gate.completed -gt $gate.total) {
        throw "invalid current focused gate progress: $($gate.name)"
    }
    if ($gate.status -cnotin @('complete', 'stale-passed', 'active', 'pending', 'failed', 'stale-failed', 'blocked')) {
        throw "unsupported current focused gate status: $($gate.name)"
    }
    if (($gate.status -cin @('complete', 'stale-passed')) -ne ($gate.completed -eq $gate.total)) {
        throw "current focused gate completion status disagrees with its count: $($gate.name)"
    }
}

Write-Host ("[project progress contract] PASS historical-focused {0}/33, timeout {1}/33, historical-stages {2}/2, current-stages {3}/2, collaboration {4}/3." -f `
    $progress.focused.passed,
    $progress.focused.timeout,
    $progress.stages.complete,
    $progress.currentGoal.stages.complete,
    $progress.collaboration.complete)
