#requires -Version 7.5
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$AsJson,
    [switch]$IncludeHistory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Assert-ProjectCurrentWorkStepLabels {
    param([object]$Work)
    if ($null -eq $Work -or $null -eq $Work.PSObject.Properties['steps']) {
        throw 'PROJECT_CURRENT_WORK_STEPS_REQUIRED'
    }
    foreach ($step in @($Work.steps)) {
        if ($null -eq $step.PSObject.Properties['label'] -or $step.label -isnot [string] -or
            [string]::IsNullOrWhiteSpace($step.label)) {
            throw 'PROJECT_CURRENT_STEP_LABEL_REQUIRED'
        }
    }
}

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = Join-Path $RepositoryRoot 'scripts\contracts\compiler-defects.json'
$stdlibPath = Join-Path $RepositoryRoot 'scripts\contracts\stdlib-evolution-progress.json'
$stabilizationPath = Join-Path $RepositoryRoot 'scripts\contracts\stabilization-progress.json'
$activeGoalPath = Join-Path $RepositoryRoot 'scripts\contracts\active-goal-progress.json'

$compiler = Get-Content -LiteralPath $compilerPath -Raw | ConvertFrom-Json
$stdlib = Get-Content -LiteralPath $stdlibPath -Raw | ConvertFrom-Json
$stabilization = Get-Content -LiteralPath $stabilizationPath -Raw | ConvertFrom-Json
$activeGoal = if (Test-Path -LiteralPath $activeGoalPath -PathType Leaf) {
    $activeGoalJson = Get-Content -LiteralPath $activeGoalPath -Raw
    $activeGoalDocument = [System.Text.Json.JsonDocument]::Parse($activeGoalJson)
    try {
        $rootKeys = @($activeGoalDocument.RootElement.EnumerateObject() | ForEach-Object Name)
        if (@($rootKeys | Sort-Object -Unique).Count -ne $rootKeys.Count) {
            throw 'active goal progress has duplicate root keys'
        }
    } finally {
        $activeGoalDocument.Dispose()
    }
    $activeGoalJson | ConvertFrom-Json -DateKind String
} else {
    $null
}
if ($null -ne $activeGoal) { Assert-ProjectCurrentWorkStepLabels -Work $activeGoal.currentWork }
. (Join-Path $PSScriptRoot 'collaboration-evidence.ps1')
Assert-CollaborationEvidence -RepositoryRoot $RepositoryRoot -Gates @($stabilization.collaborationGates)

$compilerTotal = @($compiler.defects).Count
$compilerClosed = @($compiler.defects | Where-Object state -ceq 'closed').Count
$compilerCandidate = @($compiler.defects | Where-Object state -ceq 'candidate-fixed').Count
$compilerOpen = @($compiler.defects | Where-Object state -ceq 'open').Count
if ($compilerClosed + $compilerCandidate + $compilerOpen -ne $compilerTotal) {
    throw 'compiler progress contains an unsupported defect state'
}

$stdlibTotal = @($stdlib.contracts).Count
$stdlibComplete = @($stdlib.contracts | Where-Object status -ceq 'complete').Count
$stdlibInProgress = @($stdlib.contracts | Where-Object status -ceq 'in-progress').Count
$stdlibBlocked = @($stdlib.contracts | Where-Object status -ceq 'blocked').Count
if ($stdlibComplete + $stdlibInProgress + $stdlibBlocked -ne $stdlibTotal) {
    throw 'stdlib progress contains an unsupported contract status'
}

function Get-Percent {
    param(
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$Total
    )

    if ($Total -eq 0) { return 0.0 }
    [Math]::Round(100.0 * $Count / $Total, 2)
}

function Get-FocusedGateOutcome {
    param([Parameter(Mandatory)][object]$Gate)

    if ($Gate.total -le 0 -or $Gate.completed -lt 0 -or $Gate.completed -gt $Gate.total) {
        throw "invalid active focused gate count: $($Gate.name)"
    }
    if ($Gate.status -cnotin @('pending', 'active', 'complete', 'blocked', 'failed', 'stale-failed', 'stale-passed',
            'focused-paired-passed-production-abi-failure')) {
        throw "unsupported active focused gate status '$($Gate.status)': $($Gate.name)"
    }
    $productionFailed = $Gate.status -ceq 'focused-paired-passed-production-abi-failure'
    if (($Gate.status -ceq 'complete' -or $productionFailed) -and $Gate.completed -ne $Gate.total) {
        throw "passed focused cases require completed equals total: $($Gate.name)"
    }
    [ordered]@{
        aggregateComplete = $Gate.status -ceq 'complete'
        completionScope = if ($productionFailed) { 'focused-cases-only' } else { 'declared-gate' }
        productionStatus = if ($productionFailed) { 'failed-abi' } else { 'not-reported' }
    }
}

function Get-CurrentSourceHashMatches {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][object]$Closure
    )
    $rootPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $auditPath = [IO.Path]::GetFullPath((Join-Path $Root $Closure.audit))
    if ([IO.Path]::IsPathRooted($Closure.audit) -or
        -not $auditPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'source hash audit must stay inside the repository'
    }
    $claims = @(Get-Content -LiteralPath $auditPath -Raw | ConvertFrom-Json)
    if ($claims.Count -ne $Closure.total -or @($claims.source | Sort-Object -Unique).Count -ne $claims.Count) {
        throw 'source hash audit must enumerate every unique declared source'
    }
    $rows = @(
        foreach ($claim in $claims) {
            $path = [IO.Path]::GetFullPath((Join-Path $Root $claim.source))
            if ([IO.Path]::IsPathRooted($claim.source) -or
                -not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or
                $claim.currentSha -cnotmatch '^[A-Fa-f0-9]{64}$') {
                throw "invalid source hash audit claim: $($claim.source)"
            }
            $scope = if ($claim.source.StartsWith('selfhost/', [StringComparison]::Ordinal)) { 'compiler' }
                elseif ($claim.source.StartsWith('examples/regression/', [StringComparison]::Ordinal)) { 'fixture' }
                else { throw "unrecognized source hash audit scope: $($claim.source)" }
            $actual = if (Test-Path -LiteralPath $path -PathType Leaf) {
                (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            } else { $null }
            [ordered]@{
                source = $claim.source
                scope = $scope
                recordedSha256 = $claim.currentSha
                currentSha256 = $actual
                matchesRecorded = $null -ne $actual -and $actual -ieq $claim.currentSha
            }
        }
    )
    $compilerRows = @($rows | Where-Object scope -ceq 'compiler')
    $fixtureRows = @($rows | Where-Object scope -ceq 'fixture')
    if ($compilerRows.Count -ne $Closure.compilerSourcesTotal -or $fixtureRows.Count -ne $Closure.fixtureTotal) {
        throw 'source hash audit scope totals disagree with the historical contract'
    }
    [ordered]@{
        metric = 'raw-source-hash-match-only'
        establishesBehaviorClosure = $false
        completed = @($rows | Where-Object matchesRecorded -eq $true).Count
        total = $rows.Count
        compiler = [ordered]@{ completed = @($compilerRows | Where-Object matchesRecorded -eq $true).Count; total = $compilerRows.Count }
        fixtures = [ordered]@{ completed = @($fixtureRows | Where-Object matchesRecorded -eq $true).Count; total = $fixtureRows.Count }
        claims = $rows
        audit = $Closure.audit
    }
}

# Freeze a cohort without hiding subsequently discovered release blockers.
$baselineIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($id in $stabilization.compilerBaseline.defectIds) {
    if (-not $baselineIds.Add([string]$id)) { throw "Duplicate baseline defect: $id" }
}
$baselineDefects = @($compiler.defects | Where-Object { $baselineIds.Contains($_.id) })
if ($baselineIds.Count -eq 0 -or $baselineDefects.Count -ne $baselineIds.Count) {
    throw 'Frozen compiler scope contains missing defects or has no baseline'
}
$baselineClosed = @($baselineDefects | Where-Object state -ceq 'closed').Count
$additionalDefects = @($compiler.defects | Where-Object { -not $baselineIds.Contains($_.id) })
$additionalClosed = @($additionalDefects | Where-Object state -ceq 'closed').Count

$stdlibStarted = $stdlibComplete + $stdlibInProgress
$compilerKnownResolved = $compilerClosed + $compilerCandidate
$focusedTotal = @($stabilization.focusedFixtures).Count
$focusedPassed = @($stabilization.focusedFixtures | Where-Object status -ceq 'passed').Count
$focusedTimeout = @($stabilization.focusedFixtures | Where-Object status -ceq 'timeout').Count
if ($focusedPassed + $focusedTimeout -ne $focusedTotal) {
    throw 'focused progress contains an unsupported fixture status'
}
$stageTotal = @($stabilization.stageGates).Count
$stageComplete = @($stabilization.stageGates | Where-Object status -ceq 'complete').Count
$stagePending = @($stabilization.stageGates | Where-Object status -ceq 'pending').Count
if ($stageComplete + $stagePending -ne $stageTotal) {
    throw 'stage progress contains an unsupported gate status'
}
$collaborationTotal = @($stabilization.collaborationGates).Count
$collaborationComplete = @($stabilization.collaborationGates | Where-Object status -ceq 'complete').Count
$collaborationPending = @($stabilization.collaborationGates | Where-Object status -ceq 'pending').Count
if ($collaborationComplete + $collaborationPending -ne $collaborationTotal) {
    throw 'collaboration progress contains an unsupported gate status'
}
$progress = [ordered]@{
    schemaVersion = 1
    compiler = [ordered]@{
        metric = 'registered-defect-closure'
        overallCompletionPercent = $null
        denominatorPolicy = 'grows-with-discovery'
        baseline = [ordered]@{
            id = $stabilization.compilerBaseline.id
            total = $baselineIds.Count
            closed = $baselineClosed
            closedPercent = Get-Percent $baselineClosed $baselineIds.Count
        }
        additionalDiscoveries = [ordered]@{
            total = $additionalDefects.Count
            closed = $additionalClosed
            unclosed = $additionalDefects.Count - $additionalClosed
        }
        total = $compilerTotal
        closed = $compilerClosed
        closedPercent = Get-Percent $compilerClosed $compilerTotal
        candidateFixed = $compilerCandidate
        candidateFixedPercent = Get-Percent $compilerCandidate $compilerTotal
        open = $compilerOpen
        openPercent = Get-Percent $compilerOpen $compilerTotal
        knownUnclosed = $compilerCandidate + $compilerOpen
        releaseRequiresKnownUnclosed = 0
    }
    focused = [ordered]@{
        total = $focusedTotal
        passed = $focusedPassed
        passedPercent = Get-Percent $focusedPassed $focusedTotal
        timeout = $focusedTimeout
        timeoutPercent = Get-Percent $focusedTimeout $focusedTotal
    }
    stages = [ordered]@{
        scope = 'historical-stabilization'
        evidenceReference = 'scripts/contracts/stabilization-progress.json#/stageGates'
        total = $stageTotal
        complete = $stageComplete
        completePercent = Get-Percent $stageComplete $stageTotal
        pending = $stagePending
    }
    stdlib = [ordered]@{
        total = $stdlibTotal
        complete = $stdlibComplete
        completePercent = Get-Percent $stdlibComplete $stdlibTotal
        inProgress = $stdlibInProgress
        blocked = $stdlibBlocked
        started = $stdlibStarted
        startedPercent = Get-Percent $stdlibStarted $stdlibTotal
    }
    collaboration = [ordered]@{
        total = $collaborationTotal
        complete = $collaborationComplete
        completePercent = Get-Percent $collaborationComplete $collaborationTotal
        pending = $collaborationPending
    }
}

if ($null -ne $activeGoal) {
    if ($activeGoal.schemaVersion -ne 1) { throw 'active goal progress schemaVersion must be 1' }
    $work = $activeGoal.currentWork
    if ($null -eq $work -or [string]::IsNullOrWhiteSpace($work.id) -or
        [string]::IsNullOrWhiteSpace($work.focus) -or [string]::IsNullOrWhiteSpace($work.next)) {
        throw 'current work must identify its task, present focus, and next action'
    }
    $completedUnits = if ($activeGoal.PSObject.Properties['completedUnits']) { @($activeGoal.completedUnits) } else { @() }
    $queuedUnits = @(if ($activeGoal.PSObject.Properties['queuedUnits']) { $activeGoal.queuedUnits })
    if (@($completedUnits.id | Sort-Object -Unique).Count -ne $completedUnits.Count -or
        @($completedUnits | Where-Object status -cne 'complete').Count -gt 0 -or
        @($completedUnits | Where-Object id -ceq $work.id).Count -gt 0) {
        throw 'completed implementation units must be unique, complete, and distinct from current work'
    }
    if (@($queuedUnits | ForEach-Object id | Sort-Object -Unique).Count -ne $queuedUnits.Count -or
        @($queuedUnits | Where-Object status -cne 'pending').Count -gt 0 -or
        @($queuedUnits | Where-Object { $_.id -ceq $work.id -or $completedUnits.id -ccontains $_.id }).Count -gt 0) {
        throw 'queued implementation units must be unique, pending, and distinct from current and completed work'
    }
    $unitComplete = $completedUnits.Count
    $unitTotal = $completedUnits.Count + $queuedUnits.Count
    $unitRemaining = $unitTotal - $unitComplete
    $completedUnitIds = @($completedUnits | ForEach-Object id)
    $steps = @($work.steps)
    $cases = @($work.focusedCases)
    $retainedPositiveCases = @()
    if ($work.PSObject.Properties['retainedPositiveCases']) {
        $retainedPositiveCases = @($work.retainedPositiveCases)
    }
    if ($steps.Count -eq 0 -or $cases.Count -eq 0 -or
        @($steps.id | Sort-Object -Unique).Count -ne $steps.Count -or
        @($cases.id | Sort-Object -Unique).Count -ne $cases.Count -or
        ($retainedPositiveCases.Count -gt 0 -and
            @($retainedPositiveCases | ForEach-Object id | Sort-Object -Unique).Count -ne $retainedPositiveCases.Count)) {
        throw 'current work steps and case sets must be nonempty and unique'
    }
    foreach ($item in @($steps) + @($cases) + @($retainedPositiveCases)) {
        if ($item.status -cnotin @('pending', 'running', 'complete', 'failed', 'stale-passed', 'stale-failed')) {
            throw "unsupported current work status '$($item.status)': $($item.id)"
        }
    }
    foreach ($item in @($steps) + @($cases) | Where-Object status -ceq 'complete') {
        if ([string]::IsNullOrWhiteSpace($item.evidence) -or
            -not (Test-Path -LiteralPath (Join-Path $RepositoryRoot $item.evidence) -PathType Leaf)) {
            throw "completed current work item has no readable evidence: $($item.id)"
        }
    }
    if ($activeGoal.verificationSequence.managedFirstRequired -eq $true -and
        $work.id -match '^(C\d+|P\d+)-') {
        $stepIds = @($steps | ForEach-Object id)
        $managedIndex = [Array]::IndexOf($stepIds, 'managed-first')
        $comparisonIndex = [Array]::IndexOf($stepIds, 'source-comparison')
        $buildIndex = [Array]::IndexOf($stepIds, 'selfhost-build')
        if ($managedIndex -ne 0 -or $comparisonIndex -le $managedIndex -or
            $buildIndex -le $comparisonIndex) {
            throw 'current compiler unit must order managed-first, source-comparison, then selfhost-build'
        }
        if ($steps[$buildIndex].status -ceq 'complete') {
            if ($steps[$managedIndex].status -cne 'complete' -or
                $steps[$comparisonIndex].status -cne 'complete') {
                throw 'selfhost build cannot be complete before C# proof and source comparison'
            }
            $managedReceipt = Get-Content -LiteralPath (Join-Path $RepositoryRoot $steps[$managedIndex].evidence) -Raw | ConvertFrom-Json
            $comparisonReceipt = Get-Content -LiteralPath (Join-Path $RepositoryRoot $steps[$comparisonIndex].evidence) -Raw | ConvertFrom-Json
            if ($managedReceipt.status -cne 'passed' -or $managedReceipt.inputsStable -ne $true -or
                @($managedReceipt.cases).Count -eq 0 -or
                @($managedReceipt.cases | Where-Object passed -ne $true).Count -gt 0 -or
                $comparisonReceipt.status -cnotlike 'source-reviewed-before-*' -or
                $comparisonReceipt.managedFirst -cne $steps[$managedIndex].evidence) {
                throw 'selfhost build requires stable passed C# evidence and its completed source comparison'
            }
        }
    }
    $retainedCases = @()
    $retainedPlan = $null
    if ($work.PSObject.Properties['retainedPlan'] -and -not [string]::IsNullOrWhiteSpace($work.retainedPlan)) {
        $retainedPlanPath = Join-Path $RepositoryRoot $work.retainedPlan
        if (-not (Test-Path -LiteralPath $retainedPlanPath -PathType Leaf)) {
            throw 'current work retained-case plan is missing'
        }
        $retainedPlan = Get-Content -LiteralPath $retainedPlanPath -Raw | ConvertFrom-Json
        $retainedCases = @($retainedPlan.cases)
        if ($retainedCases.Count -eq 0 -or @($retainedCases.id | Sort-Object -Unique).Count -ne $retainedCases.Count) {
            throw 'current work retained cases must be nonempty and unique'
        }
    }
    $retainedRows = @(
        foreach ($case in $retainedCases) {
            $receiptPath = Join-Path $RepositoryRoot $case.receipt
            $state = 'pending'
            if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
                try {
                    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
                    $state = if ($receipt.state -ceq 'running') { 'running-unconfirmed' } elseif (
                        $receipt.state -ceq 'passed' -and $receipt.inputsStable -eq $true -and
                        $receipt.managedCompilerSha256 -ceq $retainedPlan.managedSha256 -and
                        $receipt.selfhostCompilerSha256 -ceq $retainedPlan.selfhostSha256) {
                        'complete'
                    } else { 'failed' }
                } catch { $state = 'failed' }
            }
            [ordered]@{ id = $case.id; status = $state; receipt = $case.receipt }
        }
    )
    $retainedComplete = @($retainedRows | Where-Object status -ceq 'complete').Count
    $retainedFailed = @($retainedRows | Where-Object status -ceq 'failed').Count
    $retainedRunningUnconfirmed = @($retainedRows | Where-Object status -ceq 'running-unconfirmed').Count
    $parityPath = Join-Path $RepositoryRoot $activeGoal.implementationParity.contract
    if (-not (Test-Path -LiteralPath $parityPath -PathType Leaf)) {
        throw "implementation parity contract is missing: $parityPath"
    }
    $parity = Get-Content -LiteralPath $parityPath -Raw | ConvertFrom-Json
    $phases = @($parity.phaseMapping)
    if ($phases.Count -ne 7 -or @($phases.phase | Sort-Object -Unique).Count -ne 7) {
        throw 'implementation parity must contain seven unique phases'
    }
    $detailPath = Join-Path $RepositoryRoot $activeGoal.implementationParity.detailContract
    if (-not (Test-Path -LiteralPath $detailPath -PathType Leaf)) {
        throw "structural parity detail contract is missing: $detailPath"
    }
    $detail = Get-Content -LiteralPath $detailPath -Raw | ConvertFrom-Json
    $currentSourceHashMatches = Get-CurrentSourceHashMatches -Root $RepositoryRoot -Closure $detail.measuredSubscopes.sourceHashClosure
    $detailPhases = @($detail.phaseProgress)
    if ($detail.phaseClosure.total -ne $phases.Count -or
        $detail.phaseClosure.completed -ne @($phases | Where-Object aligned -ceq 'complete').Count -or
        $detailPhases.Count -ne $phases.Count) {
        throw 'structural parity detail disagrees with the phase contract'
    }
    for ($phaseIndex = 0; $phaseIndex -lt $phases.Count; $phaseIndex++) {
        if ($detailPhases[$phaseIndex].phase -cne $phases[$phaseIndex].phase) {
            throw "structural parity detail phase order disagrees at index $phaseIndex"
        }
    }
    $latestUnitByPhase = @{}
    foreach ($unit in $completedUnits) {
        $unitPath = Join-Path $RepositoryRoot $unit.evidence
        if (-not (Test-Path -LiteralPath $unitPath -PathType Leaf)) {
            throw "completed implementation unit evidence is missing: $($unit.id)"
        }
        $receipt = Get-Content -LiteralPath $unitPath -Raw | ConvertFrom-Json
        if (-not $receipt.PSObject.Properties['affectedPhases']) { continue }
        if ($receipt.unit -cne $unit.id -or $receipt.status -cne 'passed') {
            throw "phase-bearing implementation unit receipt is invalid: $($unit.id)"
        }
        $affectedPhases = @($receipt.affectedPhases)
        if ($affectedPhases.Count -eq 0 -or
            @($affectedPhases | Sort-Object -Unique).Count -ne $affectedPhases.Count) {
            throw "implementation unit has no unique affected phases: $($unit.id)"
        }
        foreach ($phaseName in $affectedPhases) {
            if (@($phases | Where-Object phase -ceq $phaseName).Count -ne 1) {
                throw "implementation unit names an unknown phase: $($unit.id) $phaseName"
            }
            $latestUnitByPhase[$phaseName] = $unit
        }
    }
    foreach ($phaseName in $latestUnitByPhase.Keys) {
        $phase = $phases | Where-Object phase -ceq $phaseName
        $unit = $latestUnitByPhase[$phaseName]
        if ($phase.latestUnit -cne $unit.id -or
            @($phase.evidence) -cnotcontains $unit.evidence) {
            throw "implementation parity phase does not reflect the latest unit: $phaseName $($unit.id)"
        }
    }
    $semanticPhase = $phases | Where-Object phase -ceq 'semantic-analysis'
    if ($semanticPhase.aligned -ceq 'complete' -and
        $semanticPhase.sourceDecisionOwner -cne 'semantic') {
        throw 'semantic phase cannot be complete while interpolation index decisions belong to the emitter'
    }
    $alignedPhases = @($phases | Where-Object aligned -ceq 'complete').Count
    $activeStages = @($activeGoal.stageGates)
    if ($activeStages.Count -ne 2 -or
        (@($activeStages.name | Sort-Object -Unique) -join ',') -cne 'stage2,stage3') {
        throw 'active goal must contain exactly stage2 and stage3'
    }
    foreach ($stage in $activeStages) {
        if ($stage.status -cnotin @('pending', 'running', 'complete')) {
            throw "unsupported active stage status '$($stage.status)': $($stage.name)"
        }
    }
    $activeFocused = @($activeGoal.focusedGates)
    if (@($activeFocused.name | Sort-Object -Unique).Count -ne $activeFocused.Count) {
        throw 'active goal contains duplicate focused gate names'
    }
    foreach ($gate in $activeFocused) {
        $gate | Add-Member -NotePropertyName progressOutcome -NotePropertyValue (Get-FocusedGateOutcome $gate)
        if ($gate.PSObject.Properties['evidence']) {
            $gateEvidencePath = Join-Path $RepositoryRoot $gate.evidence
            if (-not (Test-Path -LiteralPath $gateEvidencePath -PathType Leaf)) {
                throw "active focused gate evidence is missing: $($gate.name)"
            }
            $gateEvidence = Get-Content -LiteralPath $gateEvidencePath -Raw | ConvertFrom-Json
            if ($gateEvidence.completed -ne $gate.completed -or $gateEvidence.total -ne $gate.total -or
                @($gateEvidence.steps).Count -ne $gate.total -or
                @($gateEvidence.steps | Where-Object status -ceq 'complete').Count -ne $gate.completed) {
                throw "active focused gate evidence count disagrees: $($gate.name)"
            }
        }
    }
    $selectedFocusedGates = @($activeFocused | Where-Object name -ceq $activeGoal.currentFocusedGate)
    if ($selectedFocusedGates.Count -ne 1 -or $selectedFocusedGates[0].status -cnotin @('active', 'complete')) {
        throw 'current focused gate must identify exactly one active or completed measured gate'
    }
    $currentFocusedGate = $selectedFocusedGates[0]
    $activeStageComplete = @($activeStages | Where-Object status -ceq 'complete').Count
    $baselineCompiler = $activeGoal.baseline.compiler
    $baselineStdlib = $activeGoal.baseline.stdlib
    $baselineInstant = [DateTimeOffset]$activeGoal.baseline.observedLocal
    if ($baselineInstant.ToOffset([TimeSpan]::FromHours(9)).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture) -cne
        '2026-09-13T08:28:00+09:00') {
        throw 'active goal baseline must remain the 2026-09-13 08:28 KST checkpoint'
    }
    $baselineDisplay = $baselineInstant.ToOffset([TimeSpan]::FromHours(9)).ToString(
        'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture) + ' KST'
    if ($baselineCompiler.total -lt 0 -or $baselineCompiler.stabilized -lt 0 -or
        $baselineCompiler.stabilized -gt $baselineCompiler.total -or $baselineCompiler.open -lt 0) {
        throw 'active goal compiler baseline counts are invalid'
    }
    if ($baselineStdlib.total -le 0 -or $baselineStdlib.complete -lt 0 -or
        $baselineStdlib.complete -gt $baselineStdlib.total) {
        throw 'active goal stdlib baseline counts are invalid'
    }
    $progress.currentGoal = [ordered]@{
        id = $activeGoal.goalId
        currentWork = [ordered]@{
            id = $work.id
            title = $work.title
            status = $work.status
            focus = $work.focus
            stepsComplete = @($steps | Where-Object status -ceq 'complete').Count
            stepsTotal = $steps.Count
            stepsPercent = Get-Percent @($steps | Where-Object status -ceq 'complete').Count $steps.Count
            steps = $steps
            focusedComplete = @($cases | Where-Object status -ceq 'complete').Count
            focusedTotal = $cases.Count
            focusedPercent = Get-Percent @($cases | Where-Object status -ceq 'complete').Count $cases.Count
            focusedCases = $cases
            retained = [ordered]@{
                complete = $retainedComplete
                total = $retainedRows.Count
                completePercent = Get-Percent $retainedComplete $retainedRows.Count
                failed = $retainedFailed
                runningUnconfirmed = $retainedRunningUnconfirmed
                cases = $retainedRows
                plan = if ($retainedPlan) { $work.retainedPlan } else { $null }
            }
            retainedPositive = [ordered]@{
                complete = @($retainedPositiveCases | Where-Object status -ceq 'complete').Count
                total = $retainedPositiveCases.Count
                cases = $retainedPositiveCases
            }
            next = $work.next
        }
        implementationParity = [ordered]@{
            complete = $alignedPhases
            total = $phases.Count
            completePercent = Get-Percent $alignedPhases $phases.Count
            phases = $phases
            contract = $activeGoal.implementationParity.contract
            detail = $detail
            detailContract = $activeGoal.implementationParity.detailContract
            currentSourceHashMatches = $currentSourceHashMatches
        }
        verificationSequence = $activeGoal.verificationSequence
        completedUnits = $completedUnits
        queuedUnits = $queuedUnits
        identifiedImplementationUnits = [ordered]@{
            complete = $unitComplete
            total = $unitTotal
            completePercent = Get-Percent $unitComplete $unitTotal
            remaining = $unitRemaining
            currentId = $work.id
            currentStatus = $work.status
            completedIds = $completedUnitIds
            queuedIds = @($queuedUnits | ForEach-Object id)
            scope = 'durable completed and queued units only; current workflow task is excluded; future units are not enumerated'
        }
        baseline = $activeGoal.baseline
        baselineDisplay = $baselineDisplay
        compiler = [ordered]@{
            stabilized = $compilerClosed
            total = $compilerTotal
            stabilizedPercent = Get-Percent $compilerClosed $compilerTotal
            knownResolved = $compilerKnownResolved
            knownResolvedDelta = $compilerKnownResolved - $baselineCompiler.stabilized
            candidateFixed = $compilerCandidate
            candidateFixedPercent = Get-Percent $compilerCandidate $compilerTotal
            totalDelta = $compilerTotal - $baselineCompiler.total
            open = $compilerOpen
            openDelta = $compilerOpen - $baselineCompiler.open
        }
        stages = [ordered]@{
            scope = 'current-goal'
            evidenceReference = 'scripts/contracts/active-goal-progress.json#/stageGates'
            complete = $activeStageComplete
            total = $activeStages.Count
            completePercent = Get-Percent $activeStageComplete $activeStages.Count
            gates = $activeStages
        }
        stdlib = [ordered]@{
            complete = $stdlibComplete
            total = $stdlibTotal
            completePercent = Get-Percent $stdlibComplete $stdlibTotal
            completeDelta = $stdlibComplete - $baselineStdlib.complete
            inProgress = $stdlibInProgress
            blocked = $stdlibBlocked
        }
        focusedGates = $activeFocused
        currentFocusedGate = $currentFocusedGate
    }
}

if ($AsJson) {
    $progress | ConvertTo-Json -Depth 100
    return
}

if ($null -ne $progress.currentGoal) {
    $current = $progress.currentGoal.currentWork
    Write-Host ("[NOW] {0}: {1}; steps {2}/{3} ({4:N2}%); focused cases {5}/{6} ({7:N2}%)." -f `
        $current.title, $current.focus, $current.stepsComplete, $current.stepsTotal, $current.stepsPercent, `
        $current.focusedComplete, $current.focusedTotal, $current.focusedPercent)
    if ($current.retained.total -gt 0) {
        Write-Host ("[retained local cases] {0}/{1} ({2:N2}%) complete; failed {3}; in-flight receipt {4} (process unconfirmed); pending {5}." -f `
            $current.retained.complete, $current.retained.total, $current.retained.completePercent, `
            $current.retained.failed, $current.retained.runningUnconfirmed,
            ($current.retained.total - $current.retained.complete - $current.retained.failed - $current.retained.runningUnconfirmed))
    }
    if ($current.retainedPositive.total -gt 0) {
        Write-Host ("[retained native positives] {0}/{1} ({2:N2}%); remaining {3}." -f `
            $current.retainedPositive.complete, $current.retainedPositive.total,
            (Get-Percent $current.retainedPositive.complete $current.retainedPositive.total),
            ($current.retainedPositive.total - $current.retainedPositive.complete))
    }
    $units = $progress.currentGoal.identifiedImplementationUnits
    Write-Host ("[identified implementation units] complete {0}/{1} ({2:N2}%); remaining {3}/{1}; current {4} ({5}). Future units are not enumerated." -f `
        $units.complete, $units.total, $units.completePercent, $units.remaining, $units.currentId, $units.currentStatus)
    if ($IncludeHistory) {
        Write-Host ("[completed unit IDs] {0}." -f ($units.completedIds -join ', '))
        if ($units.queuedIds.Count -gt 0) {
            Write-Host ("[queued unit IDs] {0}." -f ($units.queuedIds -join ', '))
        }
    }
    foreach ($step in $current.steps | Where-Object status -cne 'complete') {
        Write-Host ("[remaining] {0}: {1}." -f $step.status, $step.label)
    }
    Write-Host ("[next] {0}." -f $current.next)
    Write-Host ("[sequence] unit compare and focused execution first; final C# versus SLG sweep {0}." -f `
        $progress.currentGoal.verificationSequence.finalSweepStatus)
    Write-Host ("[four axes + parity] compiler {0}/{1} ({2:N2}%); focused {3}/{4} ({5:N2}%); Stage2/Stage3 {6}/{7} ({8:N2}%); stdlib/runtime {9}/{10} ({11:N2}%); structural parity {12}/{13} ({14:N2}%)." -f `
        $progress.currentGoal.compiler.stabilized, $progress.currentGoal.compiler.total, $progress.currentGoal.compiler.stabilizedPercent, `
        $progress.currentGoal.currentFocusedGate.completed, $progress.currentGoal.currentFocusedGate.total,
        (Get-Percent $progress.currentGoal.currentFocusedGate.completed $progress.currentGoal.currentFocusedGate.total), `
        $progress.currentGoal.stages.complete, $progress.currentGoal.stages.total, $progress.currentGoal.stages.completePercent, `
        $progress.currentGoal.stdlib.complete, $progress.currentGoal.stdlib.total, $progress.currentGoal.stdlib.completePercent, `
        $progress.currentGoal.implementationParity.complete, $progress.currentGoal.implementationParity.total, `
        $progress.currentGoal.implementationParity.completePercent)
    Write-Host ("[compiler defect states] closed {0}, candidate-fixed {1}, open {2}; candidate-fixed is not closed." -f `
        $progress.currentGoal.compiler.stabilized, $progress.currentGoal.compiler.candidateFixed, `
        $progress.currentGoal.compiler.open)
    $phaseStates = @($progress.currentGoal.implementationParity.phases |
        ForEach-Object { "$($_.phase)=$($_.aligned)" })
    Write-Host ("[structural parity phases] {0}." -f ($phaseStates -join '; '))
    $structuralDetail = $progress.currentGoal.implementationParity.detail
    $subscopes = $structuralDetail.measuredSubscopes
    Write-Host ("[remaining structural work] phase closures {0}/{1}; interpolation semantic owners {2}/{3}; current-source evidence closures {4}/{5}. Focused case completion does not close a phase." -f `
        ($structuralDetail.phaseClosure.total - $structuralDetail.phaseClosure.completed), $structuralDetail.phaseClosure.total,
        ($subscopes.interpolationSemanticOwnedKinds.total - $subscopes.interpolationSemanticOwnedKinds.completed), $subscopes.interpolationSemanticOwnedKinds.total,
        ($subscopes.sourceHashClosure.total - $subscopes.sourceHashClosure.closed), $subscopes.sourceHashClosure.total)
    Write-Host ("[structural detail] interpolation semantic decisions {0}/{1} ({2:N2}%); recent focused units C{3}-C{4} {5}/{6} ({7:N2}%); {8} focused cases {9}/{10} ({11:N2}%); final exhaustive sweep {12}/{13} ({14:N2}%)." -f `
        $subscopes.interpolationSemanticOwnedKinds.completed, $subscopes.interpolationSemanticOwnedKinds.total,
        (Get-Percent $subscopes.interpolationSemanticOwnedKinds.completed $subscopes.interpolationSemanticOwnedKinds.total),
        $subscopes.recentFocusedUnits.firstUnit, $subscopes.recentFocusedUnits.lastUnit,
        $subscopes.recentFocusedUnits.completed, $subscopes.recentFocusedUnits.total,
        (Get-Percent $subscopes.recentFocusedUnits.completed $subscopes.recentFocusedUnits.total),
        $subscopes.currentFocusedCases.unit, $subscopes.currentFocusedCases.completed,
        $subscopes.currentFocusedCases.total,
        (Get-Percent $subscopes.currentFocusedCases.completed $subscopes.currentFocusedCases.total),
        $subscopes.finalExhaustiveSweep.completed, $subscopes.finalExhaustiveSweep.total,
        (Get-Percent $subscopes.finalExhaustiveSweep.completed $subscopes.finalExhaustiveSweep.total))
    $indexContract = Get-Content -LiteralPath (Join-Path $RepositoryRoot $subscopes.indexPreIrBranches.source) -Raw | ConvertFrom-Json
    Write-Host ("[index pre-IR branches] complete {0}/{1} ({2:N2}%); remaining {3}/{1}; kind-7 final semantic promotion {4}." -f `
        $subscopes.indexPreIrBranches.completed, $subscopes.indexPreIrBranches.total,
        (Get-Percent $subscopes.indexPreIrBranches.completed $subscopes.indexPreIrBranches.total),
        ($subscopes.indexPreIrBranches.total - $subscopes.indexPreIrBranches.completed),
        $indexContract.finalSemanticOwnerPromotion)
    foreach ($gate in $progress.currentGoal.focusedGates | Where-Object {
        $_.name -ceq $progress.currentGoal.currentFocusedGate.name -or $_.PSObject.Properties['evidence']
    }) {
        Write-Host ("[active focused gate] {0}: {1}/{2} ({3:N2}%); remaining {4}." -f `
            $gate.name, $gate.completed, $gate.total,
            (Get-Percent $gate.completed $gate.total), ($gate.total - $gate.completed))
    }
    foreach ($gate in $progress.currentGoal.focusedGates | Where-Object { $_.progressOutcome.productionStatus -ceq 'failed-abi' }) {
        Write-Host ("[partial focused gate] {0}: focused paired cases {1}/{2} ({3:N2}%); production ABI failed; aggregate complete=false." -f `
            $gate.name, $gate.completed, $gate.total, (Get-Percent $gate.completed $gate.total))
    }
    $sourceClosure = $subscopes.sourceHashClosure
    $currentSourceHashes = $progress.currentGoal.implementationParity.currentSourceHashMatches
    Write-Host ("[current raw source hashes] matches {0}/{1} ({2:N2}%); compiler {3}/{4}; fixtures {5}/{6}. Hash matches alone do not establish behavior closure." -f `
        $currentSourceHashes.completed, $currentSourceHashes.total,
        (Get-Percent $currentSourceHashes.completed $currentSourceHashes.total),
        $currentSourceHashes.compiler.completed, $currentSourceHashes.compiler.total,
        $currentSourceHashes.fixtures.completed, $currentSourceHashes.fixtures.total)
    Write-Host ("[historical structural source proof] recorded hashes {0}/{1} ({2:N2}%); fixture initializer shapes {3}/{4} ({5:N2}%); recorded paired fixtures {6}/{4} ({7:N2}%), prior-candidate passes {12}, semantic mismatches {11}, concurrent timeouts {13}, current timeouts {15}, canceled unverified {14}; recorded compiler sources {8}/{9} ({10:N2}%)." -f `
        $sourceClosure.closed, $sourceClosure.total,
        (Get-Percent $sourceClosure.closed $sourceClosure.total),
        $sourceClosure.fixtureInitializersVerified, $sourceClosure.fixtureTotal,
        (Get-Percent $sourceClosure.fixtureInitializersVerified $sourceClosure.fixtureTotal),
        $sourceClosure.fixturePairedClosed,
        (Get-Percent $sourceClosure.fixturePairedClosed $sourceClosure.fixtureTotal),
        $sourceClosure.compilerSourcesClosed, $sourceClosure.compilerSourcesTotal,
        (Get-Percent $sourceClosure.compilerSourcesClosed $sourceClosure.compilerSourcesTotal),
        $sourceClosure.fixturePairedFailed, $sourceClosure.fixturePriorCandidatePassed,
        $sourceClosure.fixturePairedTimeout, $sourceClosure.fixtureCanceledUnverified,
        $sourceClosure.fixtureCurrentTimeout)
    Write-Host ("[context initializer shape] producer {0}/{1} ({2:N2}%); direct fixtures {3}/{4} ({5:N2}%); shared source manifests {6}/{4} ({7:N2}%)." -f `
        $sourceClosure.producerInitializerVerified, $sourceClosure.producerInitializerTotal,
        (Get-Percent $sourceClosure.producerInitializerVerified $sourceClosure.producerInitializerTotal),
        $sourceClosure.fixtureInitializersVerified, $sourceClosure.fixtureTotal,
        (Get-Percent $sourceClosure.fixtureInitializersVerified $sourceClosure.fixtureTotal),
        $sourceClosure.fixtureManifestsVerified,
        (Get-Percent $sourceClosure.fixtureManifestsVerified $sourceClosure.fixtureTotal))
    foreach ($phase in $structuralDetail.phaseProgress) {
        Write-Host ("[structural phase] {0}: {1}; latest focused unit {2}; remaining: {3}." -f `
            $phase.phase, $phase.status,
            $(if ($null -eq $phase.latestFocusedUnit) { 'none' } else { $phase.latestFocusedUnit }),
            $phase.remaining)
    }
}

if ($IncludeHistory) {
Write-Host ("[fixed compiler verification scope] closed {0}/{1} ({2:N1}%); additional registered defects {3}, unclosed {4}." -f `
    $progress.compiler.baseline.closed, $progress.compiler.baseline.total, $progress.compiler.baseline.closedPercent, `
    $progress.compiler.additionalDiscoveries.total, $progress.compiler.additionalDiscoveries.unclosed)
Write-Host ("[compiler defect ledger; not overall completion] verified closed {0}/{1} ({2:N1}%); candidate-fixed {3}/{1} ({4:N1}%); open {5}/{1} ({6:N1}%); release-unclosed {7}/{1}." -f `
    $progress.compiler.closed,
    $progress.compiler.total,
    $progress.compiler.closedPercent,
    $progress.compiler.candidateFixed,
    $progress.compiler.candidateFixedPercent,
    $progress.compiler.open,
    $progress.compiler.openPercent,
    $progress.compiler.knownUnclosed)
Write-Host ("[focused progress] passed {0}/{1} ({2:N1}%); timeout {3}/{1} ({4:N1}%)." -f `
    $progress.focused.passed,
    $progress.focused.total,
    $progress.focused.passedPercent,
    $progress.focused.timeout,
    $progress.focused.timeoutPercent)
Write-Host ("[historical cohort stages] complete {0}/{1} ({2:N1}%); pending {3}/{1}." -f `
    $progress.stages.complete,
    $progress.stages.total,
    $progress.stages.completePercent,
    $progress.stages.pending)
Write-Host ("[stdlib progress] fully accepted {0}/{1} ({2:N1}%); in progress {3}/{1}; blocked {4}/{1}; started {5}/{1} ({6:N1}%)." -f `
    $progress.stdlib.complete,
    $progress.stdlib.total,
    $progress.stdlib.completePercent,
    $progress.stdlib.inProgress,
    $progress.stdlib.blocked,
    $progress.stdlib.started,
    $progress.stdlib.startedPercent)
Write-Host ("[collaboration progress] complete {0}/{1} ({2:N1}%); pending {3}/{1}." -f `
    $progress.collaboration.complete,
    $progress.collaboration.total,
    $progress.collaboration.completePercent,
    $progress.collaboration.pending)
if ($null -ne $progress.currentGoal) {
    Write-Host ("[current goal compiler; baseline {0}] closed {1}/{2} ({3:N1}%); candidate-fixed {4}; historically comparable closed+candidate delta {5:+0;-0;0}, denominator delta {6:+0;-0;0}; open {7} ({8:+0;-0;0})." -f `
        $progress.currentGoal.baselineDisplay,
        $progress.currentGoal.compiler.stabilized,
        $progress.currentGoal.compiler.total,
        $progress.currentGoal.compiler.stabilizedPercent,
        $progress.currentGoal.compiler.candidateFixed,
        $progress.currentGoal.compiler.knownResolvedDelta,
        $progress.currentGoal.compiler.totalDelta,
        $progress.currentGoal.compiler.open,
        $progress.currentGoal.compiler.openDelta)
    Write-Host ("[current goal stages] complete {0}/{1} ({2:N1}%)." -f `
        $progress.currentGoal.stages.complete,
        $progress.currentGoal.stages.total,
        $progress.currentGoal.stages.completePercent)
    Write-Host ("[current goal stdlib; baseline {0}] fully accepted {1}/{2} ({3:N1}%); delta {4:+0;-0;0}; in progress {5}/{2}; blocked {6}/{2}." -f `
        $progress.currentGoal.baselineDisplay,
        $progress.currentGoal.stdlib.complete,
        $progress.currentGoal.stdlib.total,
        $progress.currentGoal.stdlib.completePercent,
        $progress.currentGoal.stdlib.completeDelta,
        $progress.currentGoal.stdlib.inProgress,
        $progress.currentGoal.stdlib.blocked)
    Write-Host ("[current goal structural parity] fully aligned {0}/{1} ({2:N1}%)." -f `
        $progress.currentGoal.implementationParity.complete,
        $progress.currentGoal.implementationParity.total,
        $progress.currentGoal.implementationParity.completePercent)
    foreach ($gate in $progress.currentGoal.focusedGates) {
        Write-Host ("[historical focused gate] {0}: {1}/{2} ({3:N2}%); {4}." -f `
            $gate.name,
            $gate.completed,
            $gate.total,
            (Get-Percent $gate.completed $gate.total),
            $gate.status)
    }
}
}
