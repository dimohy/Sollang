[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "native-exact-batch-allocation.ps1")

function Assert-Allocation {
    param(
        [Parameter(Mandatory)][string[]]$Fixture,
        [Parameter(Mandatory)][int]$Jobs,
        [int]$MinimumCompilerJobs = 1,
        [Parameter(Mandatory)][int]$Parallelism,
        [Parameter(Mandatory)][int[]]$ExpectedJobs
    )

    $costs = [ordered]@{}
    foreach ($fixtureName in $Fixture) { $costs[$fixtureName] = 1 }
    $actual = Get-NativeExactBatchAllocation `
        -Fixture $Fixture `
        -Jobs $Jobs `
        -MinimumCompilerJobs $MinimumCompilerJobs `
        -EstimatedCostByFixture $costs
    if ($actual.Parallelism -ne $Parallelism) {
        throw "parallelism mismatch: expected $Parallelism, got $($actual.Parallelism)"
    }
    if ($actual.Items.Count -ne $Fixture.Count) {
        throw "allocation lost fixtures: expected $($Fixture.Count), got $($actual.Items.Count)"
    }
    for ($index = 0; $index -lt $Fixture.Count; $index++) {
        if ($actual.Items[$index].Fixture -cne $Fixture[$index] -or
            $actual.Items[$index].Index -ne $index -or
            $actual.Items[$index].CompilerWorkerJobs -ne $ExpectedJobs[$index]) {
            throw "allocation mismatch at index $index"
        }
    }
    for ($start = 0; $start -lt $actual.Items.Count; $start += $Parallelism) {
        $count = [Math]::Min($Parallelism, $actual.Items.Count - $start)
        $activeJobs = ($actual.Items[$start..($start + $count - 1)].CompilerWorkerJobs | Measure-Object -Sum).Sum
        if ($activeJobs -gt $Jobs) {
            throw "allocation exceeds $Jobs jobs at work window $start`: $activeJobs"
        }
    }
}

function Assert-DynamicScheduleBudget {
    param(
        [Parameter(Mandatory)]$Allocation,
        [Parameter(Mandatory)][int]$Jobs
    )

    $workerJobs = @($Allocation.Items.CompilerWorkerJobs)
    for ($index = 1; $index -lt $workerJobs.Count; $index++) {
        if ($workerJobs[$index] -gt $workerJobs[$index - 1]) {
            throw "dynamic allocation increased at schedule index $index"
        }
    }
    $largestPossibleActiveSum = ($workerJobs | Select-Object -First $Allocation.Parallelism | Measure-Object -Sum).Sum
    if ($largestPossibleActiveSum -gt $Jobs) {
        throw "dynamic allocation can exceed $Jobs shared jobs: $largestPossibleActiveSum"
    }
}

Assert-Allocation -Fixture @("a", "b", "c") -Jobs 8 -Parallelism 3 -ExpectedJobs @(3, 3, 2)
Assert-Allocation -Fixture @("a") -Jobs 8 -Parallelism 1 -ExpectedJobs @(8)
Assert-Allocation -Fixture @("a", "b", "c", "d") -Jobs 4 -Parallelism 4 -ExpectedJobs @(1, 1, 1, 1)
Assert-Allocation -Fixture @("a", "b", "c", "d", "e") -Jobs 3 -Parallelism 3 -ExpectedJobs @(1, 1, 1, 1, 1)
Assert-Allocation -Fixture @("a", "b", "c", "d") -Jobs 16 -MinimumCompilerJobs 8 -Parallelism 2 -ExpectedJobs @(8, 8, 8, 8)
Assert-Allocation -Fixture @("a", "b") -Jobs 16 -MinimumCompilerJobs 16 -Parallelism 1 -ExpectedJobs @(16, 16)

$ownedInput = [string[]]@("first", "second", "third")
$inputSnapshot = [string[]]$ownedInput.Clone()
$ownedCosts = [ordered]@{ first = 1; second = 1; third = 1 }
$firstAllocation = Get-NativeExactBatchAllocation -Fixture $ownedInput -Jobs 8 -EstimatedCostByFixture $ownedCosts
$secondAllocation = Get-NativeExactBatchAllocation -Fixture $ownedInput -Jobs 8 -EstimatedCostByFixture $ownedCosts
if (($ownedInput -join "|") -cne ($inputSnapshot -join "|") -or
    (($firstAllocation.Items.CompilerWorkerJobs) -join ",") -cne (($secondAllocation.Items.CompilerWorkerJobs) -join ",")) {
    throw "allocation mutated its input or returned a nondeterministic result"
}

$exhaustiveShapes = 0
for ($jobs = 1; $jobs -le 64; $jobs++) {
    for ($fixtureCount = 1; $fixtureCount -le 80; $fixtureCount++) {
        $fixtures = @(0..($fixtureCount - 1) | ForEach-Object { "fixture-$_" })
        $costs = [ordered]@{}
        foreach ($fixtureName in $fixtures) { $costs[$fixtureName] = 1 }
        $actual = Get-NativeExactBatchAllocation -Fixture $fixtures -Jobs $jobs -EstimatedCostByFixture $costs
        $expectedParallelism = [Math]::Min($fixtureCount, $jobs)
        $baseJobs = [Math]::Floor($jobs / $expectedParallelism)
        $remainder = $jobs % $expectedParallelism
        if ($actual.Parallelism -ne $expectedParallelism -or $actual.Items.Count -ne $fixtureCount) {
            throw "exhaustive allocation dimensions drifted for jobs=$jobs fixtures=$fixtureCount"
        }
        for ($index = 0; $index -lt $fixtureCount; $index++) {
            $expected = $baseJobs + $(if (($index % $expectedParallelism) -lt $remainder) { 1 } else { 0 })
            if ($actual.Items[$index].CompilerWorkerJobs -ne $expected -or $actual.Items[$index].CompilerWorkerJobs -lt 1) {
                throw "exhaustive allocation mismatch for jobs=$jobs fixtures=$fixtureCount index=$index"
            }
        }
        for ($start = 0; $start -lt $fixtureCount; $start += $expectedParallelism) {
            $count = [Math]::Min($expectedParallelism, $fixtureCount - $start)
            $activeJobs = ($actual.Items[$start..($start + $count - 1)].CompilerWorkerJobs | Measure-Object -Sum).Sum
            if ($activeJobs -gt $jobs) {
                throw "exhaustive allocation exceeds jobs=$jobs for fixtures=$fixtureCount window=$start"
            }
        }
        $exhaustiveShapes++
    }
}

$emptyRejected = $false
try {
    Get-NativeExactBatchAllocation -Fixture @() -Jobs 1 -EstimatedCostByFixture @{} | Out-Null
} catch {
    $emptyRejected = $_.Exception.Message -ceq "native exact batch allocation requires at least one fixture"
}
if (-not $emptyRejected) {
    throw "empty fixture allocation was not rejected with repair guidance"
}

$impossibleMinimumRejected = $false
try {
    Get-NativeExactBatchAllocation -Fixture @("a") -Jobs 4 -MinimumCompilerJobs 8 -EstimatedCostByFixture @{ a = 1 } | Out-Null
} catch {
    $impossibleMinimumRejected = $_.Exception.Message -eq "native exact batch minimum compiler jobs 8 exceeds the shared 4-job budget; increase -Jobs or lower -MinimumCompilerJobs"
}
if (-not $impossibleMinimumRejected) {
    throw "an impossible minimum compiler allocation was not rejected with repair guidance"
}

$costOrdered = Get-NativeExactBatchAllocation `
    -Fixture @("light-a", "medium", "heavy", "light-b") `
    -Jobs 5 `
    -EstimatedCostByFixture ([ordered]@{ "light-a" = 1; medium = 42; heavy = 96; "light-b" = 1 })
if (($costOrdered.Items.Fixture -join ",") -cne "heavy,medium,light-a,light-b" -or
    ($costOrdered.Items.Index -join ",") -cne "2,1,0,3" -or
    ($costOrdered.Items.EstimatedCost -join ",") -cne "96,42,1,1" -or
    $costOrdered.Parallelism -ne 3 -or
    ($costOrdered.Items.CompilerWorkerJobs -join ",") -cne "2,2,1,1") {
    throw "cost-aware allocation did not start expensive closures first or preserve stable identities"
}
Assert-DynamicScheduleBudget -Allocation $costOrdered -Jobs 5

$measuredNineCaseShape = Get-NativeExactBatchAllocation `
    -Fixture @("96-source", "42-source-a", "42-source-b", "light-a", "light-b", "light-c", "light-d", "light-e", "light-f") `
    -Jobs 9 `
    -EstimatedCostByFixture ([ordered]@{
        "96-source" = 96; "42-source-a" = 42; "42-source-b" = 42
        "light-a" = 1; "light-b" = 1; "light-c" = 1
        "light-d" = 1; "light-e" = 1; "light-f" = 1
    })
if ($measuredNineCaseShape.Parallelism -ne 6 -or
    ($measuredNineCaseShape.Items.CompilerWorkerJobs -join ",") -cne "2,2,2,1,1,1,1,1,1") {
    throw "measured nine-case shape did not reserve two compiler jobs for 96/42-source closures"
}
Assert-DynamicScheduleBudget -Allocation $measuredNineCaseShape -Jobs 9

$realClosureAllocation = Get-NativeExactBatchAllocation `
    -Fixture @(
        "1396-selfhost-binary-operand-topology",
        "1264-selfhost-late-numeric-payload-subject",
        "1393-selfhost-opaque-struct-diagnostics",
        "1222-selfhost-numeric-subject-when-binding",
        "1379-selfhost-nested-control-implicit-return") `
    -Jobs 5
if (($realClosureAllocation.Items.Fixture -join ",") -cne
    "1393-selfhost-opaque-struct-diagnostics,1222-selfhost-numeric-subject-when-binding,1264-selfhost-late-numeric-payload-subject,1396-selfhost-binary-operand-topology,1379-selfhost-nested-control-implicit-return" -or
    ($realClosureAllocation.Items.EstimatedCost -join ",") -cne "96,42,42,42,1" -or
    $realClosureAllocation.Items[0].EstimatedSourceBytes -le $realClosureAllocation.Items[1].EstimatedSourceBytes -or
    $realClosureAllocation.Items[1].EstimatedSourceBytes -le $realClosureAllocation.Items[2].EstimatedSourceBytes -or
    $realClosureAllocation.Items[2].EstimatedSourceBytes -le $realClosureAllocation.Items[3].EstimatedSourceBytes) {
    throw "authoritative 117-fixture plan costs did not prioritize its 96/42/42/42-source closures"
}
Assert-DynamicScheduleBudget -Allocation $realClosureAllocation -Jobs 5

$missingCostRejected = $false
try {
    Get-NativeExactBatchAllocation -Fixture @("a", "b") -Jobs 2 -EstimatedCostByFixture @{ a = 1 } | Out-Null
} catch {
    $missingCostRejected = $_.Exception.Message -ceq "native exact batch cost metadata is missing fixture: b"
}
if (-not $missingCostRejected) {
    throw "incomplete cost metadata was not rejected"
}

$unknownCostRejected = $false
try {
    Get-NativeExactBatchAllocation -Fixture @("a") -Jobs 1 -EstimatedCostByFixture @{ a = 1; b = 2 } | Out-Null
} catch {
    $unknownCostRejected = $_.Exception.Message -ceq "native exact batch cost metadata contains an unknown fixture: b"
}
if (-not $unknownCostRejected) {
    throw "unknown cost metadata was not rejected"
}

$invalidCostRejected = $false
try {
    Get-NativeExactBatchAllocation -Fixture @("a") -Jobs 1 -EstimatedCostByFixture @{ a = 0 } | Out-Null
} catch {
    $invalidCostRejected = $_.Exception.Message -ceq "native exact batch cost metadata for 'a' must be a positive integer"
}
if (-not $invalidCostRejected) {
    throw "non-positive cost metadata was not rejected"
}

$invalidManifestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-native-exact-allocation-" + [guid]::NewGuid().ToString("N"))
try {
    [System.IO.Directory]::CreateDirectory($invalidManifestRoot) | Out-Null
    Set-Content -LiteralPath (Join-Path $invalidManifestRoot "broken.sources.txt") -Value "examples/regression/not-broken.slg"
    $invalidManifestRejected = $false
    try {
        Get-NativeExactBatchAllocation -Fixture @("broken") -Jobs 1 -ExpectedSourcesRoot $invalidManifestRoot | Out-Null
    } catch {
        $invalidManifestRejected = $_.Exception.Message -like "native exact batch source manifest must contain its executable root*"
    }
    if (-not $invalidManifestRejected) {
        throw "source manifest without its executable root was not rejected"
    }
} finally {
    if (Test-Path -LiteralPath $invalidManifestRoot) {
        Remove-Item -LiteralPath $invalidManifestRoot -Recurse -Force
    }
}

Write-Host "[native exact batch allocation] PASS 6 named shapes, $exhaustiveShapes exhaustive shapes, deterministic source-count/source-byte LPT ordering, measured nine-case heavy allocation, dynamic shared-budget bounds, input immutability, and six fail-fast controls."
