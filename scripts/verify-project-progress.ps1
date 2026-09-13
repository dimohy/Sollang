[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
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
if ($progress.currentGoal.stages.total -ne 2 -or $progress.currentGoal.stages.complete -ne 0) {
    throw 'current goal Stage2/Stage3 state must remain independently pending'
}
$authoritativeCompilerTotal = @($compilerLedger.defects).Count
$authoritativeCompilerStabilized = @($compilerLedger.defects | Where-Object state -in @('closed', 'candidate-fixed')).Count
$authoritativeCompilerOpen = @($compilerLedger.defects | Where-Object state -ceq 'open').Count
if ($progress.currentGoal.compiler.total -ne $authoritativeCompilerTotal -or
    $progress.currentGoal.compiler.stabilized -ne $authoritativeCompilerStabilized -or
    $progress.currentGoal.compiler.open -ne $authoritativeCompilerOpen -or
    $progress.currentGoal.compiler.stabilized -ne $progress.compiler.closed + $progress.compiler.candidateFixed) {
    throw 'current goal compiler stabilization must equal closed plus candidate-fixed'
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
if ($progress.currentGoal.compiler.stabilizedDelta -ne ($authoritativeCompilerStabilized - 405) -or
    $progress.currentGoal.compiler.totalDelta -ne ($authoritativeCompilerTotal - 418) -or
    $progress.currentGoal.compiler.openDelta -ne ($authoritativeCompilerOpen - 13) -or
    $progress.currentGoal.stdlib.completeDelta -ne ($authoritativeStdlibComplete - 5)) {
    throw 'current goal delta is not derived from the frozen 08:28 baseline'
}
$focusedByName = @{}; foreach ($gate in @($progress.currentGoal.focusedGates)) { $focusedByName[[string]$gate.name] = $gate }
foreach ($requiredName in @('C385 13-family wrapper static', 'C385 13-family paired actual')) {
    if (-not $focusedByName.ContainsKey($requiredName)) { throw "missing current focused gate: $requiredName" }
}
if ($focusedByName['C385 13-family wrapper static'].completed -ne 5 -or
    $focusedByName['C385 13-family wrapper static'].total -ne 5 -or
    $focusedByName['C385 13-family wrapper static'].status -cne 'complete' -or
    $focusedByName['C385 13-family paired actual'].completed -ne 0 -or
    $focusedByName['C385 13-family paired actual'].total -ne 1 -or
    $focusedByName['C385 13-family paired actual'].status -cne 'pending') {
    throw 'C385 static completion and paired actual pending state must remain separate'
}
foreach ($gate in @($progress.currentGoal.focusedGates)) {
    if ($gate.total -le 0 -or $gate.completed -lt 0 -or $gate.completed -gt $gate.total) {
        throw "invalid current focused gate progress: $($gate.name)"
    }
    if (($gate.status -ceq 'complete') -ne ($gate.completed -eq $gate.total)) {
        throw "current focused gate completion status disagrees with its count: $($gate.name)"
    }
}

Write-Host ("[project progress contract] PASS historical-focused {0}/33, timeout {1}/33, historical-stages {2}/2, current-stages {3}/2, collaboration {4}/3." -f `
    $progress.focused.passed,
    $progress.focused.timeout,
    $progress.stages.complete,
    $progress.currentGoal.stages.complete,
    $progress.collaboration.complete)
