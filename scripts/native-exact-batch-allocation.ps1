Set-StrictMode -Version Latest

function Get-NativeExactFixtureCost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Fixture,
        [Parameter(Mandatory)][string]$ExpectedSourcesRoot
    )

    $manifestPath = Join-Path $ExpectedSourcesRoot "$Fixture.sources.txt"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        return [pscustomobject]@{ SourceCount = 1L; SourceBytes = 0L }
    }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "native exact batch source manifest is not a file: $manifestPath"
    }

    $sources = @(Get-Content -LiteralPath $manifestPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($sources.Count -eq 0) {
        throw "native exact batch source manifest is empty: $manifestPath"
    }

    $expectedRootSource = "examples/regression/$Fixture.slg"
    $normalizedSources = @($sources | ForEach-Object { $_.Replace("\", "/") })
    if (-not $normalizedSources.Contains($expectedRootSource)) {
        throw "native exact batch source manifest must contain its executable root '$expectedRootSource': $manifestPath"
    }
    if (@($normalizedSources | Sort-Object -Unique).Count -ne $normalizedSources.Count) {
        throw "native exact batch source manifest contains duplicate paths: $manifestPath"
    }

    $repositoryRoot = Split-Path (Split-Path (Split-Path ([System.IO.Path]::GetFullPath($ExpectedSourcesRoot)) -Parent) -Parent) -Parent
    [long]$sourceBytes = 0
    foreach ($source in $sources) {
        $sourcePath = Join-Path $repositoryRoot $source
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "native exact batch source manifest entry is missing: $sourcePath"
        }
        $sourceBytes += (Get-Item -LiteralPath $sourcePath).Length
    }

    return [pscustomobject]@{ SourceCount = [long]$sources.Count; SourceBytes = $sourceBytes }
}

function Get-NativeExactBatchAllocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Fixture,
        [Parameter(Mandatory)][ValidateRange(1, 64)][int]$Jobs,
        [ValidateRange(1, 64)][int]$MinimumCompilerJobs = 1,
        [string]$ExpectedSourcesRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) "examples\regression\expected"),
        [System.Collections.IDictionary]$EstimatedCostByFixture,
        [ValidateRange(2, 2147483647)][int]$HeavySourceThreshold = 42
    )

    if ($Fixture.Count -eq 0) {
        throw "native exact batch allocation requires at least one fixture"
    }
    if ($MinimumCompilerJobs -gt $Jobs) {
        throw "native exact batch minimum compiler jobs $MinimumCompilerJobs exceeds the shared $Jobs-job budget; increase -Jobs or lower -MinimumCompilerJobs"
    }

    if ($null -ne $EstimatedCostByFixture) {
        foreach ($key in $EstimatedCostByFixture.Keys) {
            if (-not $Fixture.Contains([string]$key)) {
                throw "native exact batch cost metadata contains an unknown fixture: $key"
            }
        }
    } elseif (-not (Test-Path -LiteralPath $ExpectedSourcesRoot -PathType Container)) {
        throw "native exact batch expected source root is missing: $ExpectedSourcesRoot"
    }

    $scheduled = for ($index = 0; $index -lt $Fixture.Count; $index++) {
        $fixtureName = $Fixture[$index]
        $cost = if ($null -ne $EstimatedCostByFixture) {
            if (-not $EstimatedCostByFixture.Contains($fixtureName)) {
                throw "native exact batch cost metadata is missing fixture: $fixtureName"
            }
            $value = $EstimatedCostByFixture[$fixtureName]
            if ($value -isnot [byte] -and $value -isnot [int16] -and
                $value -isnot [int32] -and $value -isnot [int64]) {
                throw "native exact batch cost metadata for '$fixtureName' must be a positive integer"
            }
            [pscustomobject]@{ SourceCount = [long]$value; SourceBytes = 0L }
        } else {
            Get-NativeExactFixtureCost -Fixture $fixtureName -ExpectedSourcesRoot $ExpectedSourcesRoot
        }
        if ($cost.SourceCount -lt 1) {
            throw "native exact batch cost metadata for '$fixtureName' must be a positive integer"
        }
        [pscustomobject]@{
            Fixture = $fixtureName
            OriginalIndex = $index
            EstimatedCost = $cost.SourceCount
            EstimatedSourceBytes = $cost.SourceBytes
            IsHeavy = $cost.SourceCount -ge $HeavySourceThreshold
        }
    }

    # Longest-processing-time-first keeps large compiler import closures out of
    # the final scheduling wave. OriginalIndex makes equal-cost order stable.
    $scheduled = @($scheduled | Sort-Object `
        @{ Expression = "EstimatedCost"; Descending = $true }, `
        @{ Expression = "EstimatedSourceBytes"; Descending = $true }, `
        @{ Expression = "OriginalIndex"; Descending = $false })

    # A heavy compiler closure gets one additional inner worker. Choose
    # the largest initial prefix that fits; costs and allocations are both
    # non-increasing, so every later completion/replacement can only preserve
    # or reduce the active shared-job sum.
    $parallelism = 0
    $minimumPrefixJobs = 0
    foreach ($scheduledItem in $scheduled) {
        $heavyExtra = if ($scheduledItem.IsHeavy -and $Jobs -gt $MinimumCompilerJobs) { 1 } else { 0 }
        if ($minimumPrefixJobs + $MinimumCompilerJobs + $heavyExtra -gt $Jobs) {
            break
        }
        $minimumPrefixJobs += $MinimumCompilerJobs + $heavyExtra
        $parallelism += 1
    }
    if ($parallelism -eq 0) {
        $parallelism = 1
    }
    $initialHeavyCount = @($scheduled[0..($parallelism - 1)] | Where-Object IsHeavy).Count
    if ($Jobs -le $MinimumCompilerJobs) {
        $initialHeavyCount = 0
    }
    $baseJobs = [int][Math]::Floor(($Jobs - $initialHeavyCount) / $parallelism)
    $remainder = $Jobs - ($baseJobs * $parallelism) - $initialHeavyCount
    $items = for ($scheduleIndex = 0; $scheduleIndex -lt $scheduled.Count; $scheduleIndex++) {
        $heavyExtra = if ($scheduled[$scheduleIndex].IsHeavy -and $Jobs -gt $MinimumCompilerJobs) { 1 } else { 0 }
        [pscustomobject]@{
            Fixture = $scheduled[$scheduleIndex].Fixture
            Index = $scheduled[$scheduleIndex].OriginalIndex
            ScheduleIndex = $scheduleIndex
            EstimatedCost = $scheduled[$scheduleIndex].EstimatedCost
            EstimatedSourceBytes = $scheduled[$scheduleIndex].EstimatedSourceBytes
            CostClass = if ($scheduled[$scheduleIndex].IsHeavy) { "heavy" } else { "regular" }
            CompilerWorkerJobs = $baseJobs + $heavyExtra + $(if ($scheduleIndex -lt $remainder) { 1 } else { 0 })
        }
    }

    [pscustomobject]@{
        WorkerJobBudget = $Jobs
        Parallelism = $parallelism
        Items = @($items)
    }
}
