[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/c435-terminal-control.json'
$schemaPath = Join-Path $root 'scripts/contracts/c435-terminal-control.schema.json'
$controlPath = Join-Path $root 'selfhost/llvm/text/control.slg'
$schedulingPath = Join-Path $root 'selfhost/llvm/text/function_scheduling.slg'

foreach ($path in @($contractPath, $schemaPath, $controlPath, $schedulingPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "C435 authority input missing: $path"
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw 'C435 contract schema rejected authority'
}
$contract = $contractText | ConvertFrom-Json
$control = [IO.File]::ReadAllText($controlPath)
$scheduling = [IO.File]::ReadAllText($schedulingPath)
$probePath = Join-Path $root ([string]$contract.probe)
if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
    throw "C435 focused probe missing: $probePath"
}
$probe = [IO.File]::ReadAllText($probePath)

function Test-C435Authority([string]$Control, [string]$Scheduling) {
    $directRegion = '(?s)regionReturns regionIndex:.*?regionIndex -> terminatingControlReturns\(context, state\)\s*-> if \{ true => returns! \}.*?context\.ir\[regionIndex\] => returnRegion'
    $sharedTerminal = '(?s)terminatingControlReturns controlIndex:.*?candidateIndex! -> controlReturns\(context, state\)\s*and \(candidateIndex! -> controlIsLastRegionChild\(context, state\)\)'
    $wrapper = '(?s)terminatingControlReturns controlIndex:.*?candidate\.kind == 9\s*and candidate\.opcode == -1\s*and candidate\.operand1 >= 0\s*and candidate\.operand1 < \(context\.ir -> len\)\s*and context\.ir\[candidate\.operand1\]\.parent == candidateIndex!'
    $subjectWhenMerge = '(?s)not \(whenHasArm! and whenHasElse!\) -> if \{ false => whenAllArmsReturn! \}.*?whenAllArmsReturn!\s*and not \(whenIndex -> controlIsLastRegionChild\(context, state\)\)\s*-> if \{ false => whenAllArmsReturn! \}.*?not whenAllArmsReturn! -> if \{'
    $scheduler = '(?s)reachableCandidate -> terminatingControlReturns\(context, state\).*?false => reachableExpressionOpen!'
    return $Control -match $directRegion -and
        $Control -match $sharedTerminal -and
        $Control -match $wrapper -and
        $Control -match $subjectWhenMerge -and
        $Scheduling -match $scheduler
}

if (-not (Test-C435Authority $control $scheduling)) {
    throw 'C435 production authority no longer preserves direct, wrapped, later-sibling, scheduling, and merge invariants'
}
if ($probe -notmatch '(?s)value -> when \{.*?== 0 \{ Result<Int, Text>\.Ok\(7\) -> return \}.*?== 1 \{ Result<Int, Text>\.Ok\(9\) -> return \}.*?else \{ Result<Int, Text>\.Err\("other"\) -> return \}.*?0 -> choose -> when') {
    throw 'C435 focused probe no longer contains a source-final exhaustive all-return subject when'
}

$fixturePaths = @($contract.focusedFixtures | Select-Object -Skip 1 | ForEach-Object {
    Join-Path $root "examples/regression/$_.slg"
})
foreach ($path in $fixturePaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        throw "C435 retained fixture missing or empty: $path"
    }
}

$mutations = [ordered]@{
    'remove-direct-region-classification' = @{
        control = $control.Replace('regionIndex -> terminatingControlReturns(context, state)', 'false')
        scheduling = $scheduling
    }
    'use-weaker-control-returns' = @{
        control = [regex]::Replace($control, 'candidateIndex! -> controlReturns\(context, state\)\r?\n\s*and \(candidateIndex! -> controlIsLastRegionChild\(context, state\)\)', 'candidateIndex! -> controlReturns(context, state)', 1)
        scheduling = $scheduling
    }
    'remove-later-sibling-guard' = @{
        control = $control.Replace('and (candidateIndex! -> controlIsLastRegionChild(context, state))', 'and true')
        scheduling = $scheduling
    }
    'remove-wrapper-opcode-guard' = @{
        control = $control.Replace('and candidate.opcode == -1', 'and true')
        scheduling = $scheduling
    }
    'remove-wrapper-parent-ownership' = @{
        control = $control.Replace('and context.ir[candidate.operand1].parent == candidateIndex!', 'and true')
        scheduling = $scheduling
    }
    'always-emit-subject-when-merge' = @{
        control = $control.Replace('not whenAllArmsReturn! -> if {', 'true -> if {')
        scheduling = $scheduling
    }
}

$expectedMutationIds = @($contract.mutationControls)
if (@($mutations.Keys).Count -ne $expectedMutationIds.Count -or
    @(Compare-Object -ReferenceObject $expectedMutationIds -DifferenceObject @($mutations.Keys)).Count -ne 0) {
    throw 'C435 mutation implementation differs from the contract'
}
$rejected = 0
foreach ($id in $expectedMutationIds) {
    $mutation = $mutations[$id]
    if ($mutation.control -ceq $control -and $mutation.scheduling -ceq $scheduling) {
        throw "C435 mutation did not alter its target: $id"
    }
    if (Test-C435Authority $mutation.control $mutation.scheduling) {
        throw "C435 mutation escaped the focused gate: $id"
    }
    $rejected++
}

Write-Output "C435 terminal control: PASS authority 5/5, probe 1/1, retained fixtures $($fixturePaths.Count)/$($fixturePaths.Count), mutations $rejected/$($expectedMutationIds.Count); rebuilt selfhost 0/1 pending."
