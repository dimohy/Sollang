[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$tokens = $null
$errors = $null
$verifier = Join-Path $RepositoryRoot 'scripts/verify-project-progress.ps1'
$tree = [Management.Automation.Language.Parser]::ParseFile($verifier, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw 'Project progress verifier has syntax errors' }
$functions = @($tree.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -ceq 'Assert-ProjectFocusedGateProjection'
}, $false))
if ($functions.Count -ne 1) { throw 'Focused gate projection authority is missing' }
. ([scriptblock]::Create($functions[0].Extent.Text))
$ledger = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'scripts/contracts/active-goal-progress.json') -Raw | ConvertFrom-Json
$history = Get-Content -LiteralPath (Join-Path $RepositoryRoot $ledger.focusedGateHistory) -Raw | ConvertFrom-Json
$selected = @($ledger.focusedGates | Where-Object name -ceq $ledger.currentFocusedGate)
if ($selected.Count -ne 1) { throw 'Current fixture has no selected gate' }
$goal = [pscustomobject]@{ focusedGates = $ledger.focusedGates; currentFocusedGate = $selected[0] }
$snapshot = @{ goal = $goal; ledger = $ledger; history = $history } | ConvertTo-Json -Depth 100
function New-Control { $snapshot | ConvertFrom-Json }
function Assert-Rejected([scriptblock]$Action, [string]$Expected) {
    try { & $Action; throw 'EXPECTED_FOCUSED_GATE_REJECTION' }
    catch { if ($_.Exception.Message -cne $Expected) { throw } }
}
Assert-ProjectFocusedGateProjection $goal $ledger $history
$control = New-Control
$control.goal.currentFocusedGate.name = 'missing-selected-gate'
Assert-Rejected { Assert-ProjectFocusedGateProjection $control.goal $control.ledger $control.history } 'PROJECT_CURRENT_FOCUSED_GATE_INVALID'
$control = New-Control
$control.history.focusedGates = @($control.history.focusedGates | Where-Object name -cne 'C385 13-family wrapper static')
Assert-Rejected { Assert-ProjectFocusedGateProjection $control.goal $control.ledger $control.history } 'PROJECT_C385_HISTORICAL_FOCUS_MISSING'
$control = New-Control
($control.history.focusedGates | Where-Object name -ceq 'C385 13-family paired actual').completed = 0
Assert-Rejected { Assert-ProjectFocusedGateProjection $control.goal $control.ledger $control.history } 'PROJECT_C385_HISTORICAL_FOCUS_CHANGED'
$control = New-Control
$control.history.focusedGates += @($control.history.focusedGates | Where-Object name -ceq 'C385 13-family paired actual')[0]
Assert-Rejected { Assert-ProjectFocusedGateProjection $control.goal $control.ledger $control.history } 'PROJECT_C385_HISTORICAL_FOCUS_AMBIGUOUS'
$control = New-Control
$control.goal.currentFocusedGate.completed = 0
Assert-Rejected { Assert-ProjectFocusedGateProjection $control.goal $control.ledger $control.history } 'PROJECT_CURRENT_FOCUSED_GATE_INVALID'
$showPath = Join-Path $RepositoryRoot 'scripts/show-project-progress.ps1'
$showAst = [Management.Automation.Language.Parser]::ParseFile($showPath, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Project progress renderer has syntax errors' }
$labelFunctions = @($showAst.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Assert-ProjectCurrentWorkStepLabels'}, $false))
if ($labelFunctions.Count -ne 1) { throw 'Current step label authority is missing' }
. ([scriptblock]::Create($labelFunctions[0].Extent.Text))
Assert-ProjectCurrentWorkStepLabels $ledger.currentWork
foreach ($kind in @('missing', 'blank', 'non-string')) {
    $work = $ledger.currentWork | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    if ($kind -ceq 'missing') { $work.steps[0].PSObject.Properties.Remove('label') }
    elseif ($kind -ceq 'blank') { $work.steps[0].label = ' ' }
    else { $work.steps[0].label = 42 }
    Assert-Rejected { Assert-ProjectCurrentWorkStepLabels $work } 'PROJECT_CURRENT_STEP_LABEL_REQUIRED'
}
@{ status = 'passed'; completed = 10; total = 10; currentAndHistoricalScopesPreserved = $true; currentWorkLabelsChecked = $true } | ConvertTo-Json
