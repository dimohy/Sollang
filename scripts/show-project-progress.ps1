[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = Join-Path $RepositoryRoot 'scripts\contracts\compiler-defects.json'
$stdlibPath = Join-Path $RepositoryRoot 'scripts\contracts\stdlib-evolution-progress.json'
$stabilizationPath = Join-Path $RepositoryRoot 'scripts\contracts\stabilization-progress.json'
$activeGoalPath = Join-Path $RepositoryRoot 'scripts\contracts\active-goal-progress.json'

$compiler = Get-Content -LiteralPath $compilerPath -Raw | ConvertFrom-Json
$stdlib = Get-Content -LiteralPath $stdlibPath -Raw | ConvertFrom-Json
$stabilization = Get-Content -LiteralPath $stabilizationPath -Raw | ConvertFrom-Json
$activeGoal = if (Test-Path -LiteralPath $activeGoalPath -PathType Leaf) {
    Get-Content -LiteralPath $activeGoalPath -Raw | ConvertFrom-Json
} else {
    $null
}
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
    [Math]::Round(100.0 * $Count / $Total, 1)
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
$compilerStabilized = $compilerClosed + $compilerCandidate
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
        if ($gate.total -le 0 -or $gate.completed -lt 0 -or $gate.completed -gt $gate.total) {
            throw "invalid active focused gate count: $($gate.name)"
        }
        if ($gate.status -cnotin @('pending', 'active', 'complete', 'blocked', 'stale-failed')) {
            throw "unsupported active focused gate status '$($gate.status)': $($gate.name)"
        }
    }
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
        baseline = $activeGoal.baseline
        baselineDisplay = $baselineDisplay
        compiler = [ordered]@{
            stabilized = $compilerStabilized
            total = $compilerTotal
            stabilizedPercent = Get-Percent $compilerStabilized $compilerTotal
            stabilizedDelta = $compilerStabilized - $baselineCompiler.stabilized
            totalDelta = $compilerTotal - $baselineCompiler.total
            open = $compilerOpen
            openDelta = $compilerOpen - $baselineCompiler.open
        }
        stages = [ordered]@{
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
    }
}

if ($AsJson) {
    $progress | ConvertTo-Json -Depth 5
    return
}

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
    Write-Host ("[current goal compiler; baseline {0}] stabilized {1}/{2} ({3:N1}%); delta {4:+0;-0;0} stabilized, {5:+0;-0;0} denominator; open {6} ({7:+0;-0;0})." -f `
        $progress.currentGoal.baselineDisplay,
        $progress.currentGoal.compiler.stabilized,
        $progress.currentGoal.compiler.total,
        $progress.currentGoal.compiler.stabilizedPercent,
        $progress.currentGoal.compiler.stabilizedDelta,
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
    foreach ($gate in $progress.currentGoal.focusedGates) {
        Write-Host ("[current focused gate] {0}: {1}/{2} ({3:N1}%); {4}." -f `
            $gate.name,
            $gate.completed,
            $gate.total,
            (Get-Percent $gate.completed $gate.total),
            $gate.status)
    }
}
