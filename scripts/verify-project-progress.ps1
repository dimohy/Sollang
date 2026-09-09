[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$ledgerPath = Join-Path $RepositoryRoot 'scripts\contracts\stabilization-progress.json'
$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json

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

Write-Host ("[project progress contract] PASS focused {0}/33, timeout {1}/33, stages {2}/2, collaboration {3}/3." -f `
    $progress.focused.passed,
    $progress.focused.timeout,
    $progress.stages.complete,
    $progress.collaboration.complete)
