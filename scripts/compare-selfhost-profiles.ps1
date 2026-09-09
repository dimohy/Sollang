[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Baseline,
    [Parameter(Mandatory)][string[]]$Candidate,
    [ValidateRange(3, 99)][int]$MinimumSamples = 3,
    [Parameter(Mandatory)][ValidateRange(-100.0, 100.0)][double]$MinimumWallImprovementPercent,
    [Parameter(Mandatory)][ValidateRange(0.0, 1000.0)][double]$MaximumCpuRegressionPercent,
    [Parameter(Mandatory)][ValidateRange(0.0, 1000.0)][double]$MaximumPeakMemoryRegressionPercent,
    [string]$Output = "",
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-profile.schema.json"

function Read-ProfileGroup {
    param(
        [Parameter(Mandatory)][string[]]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Path.Count -lt $MinimumSamples) {
        throw "$Name profile group has $($Path.Count) samples; at least $MinimumSamples are required"
    }
    $resolvedPaths = @($Path | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
    if (($resolvedPaths | Select-Object -Unique).Count -ne $resolvedPaths.Count) {
        throw "$Name profile group repeats a sample path"
    }
    $profiles = @($resolvedPaths | ForEach-Object {
        $json = [System.IO.File]::ReadAllText($_)
        if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
            throw "$Name profile does not match schema v3: $_"
        }
        $json | ConvertFrom-Json
    })

    $authority = $profiles[0]
    $authorityRoots = $authority.fixtureRoots | ConvertTo-Json -Compress
    $authorityEnvironment = $authority.environment | ConvertTo-Json -Compress
    foreach ($profile in $profiles) {
        if ($profile.mode -cne $authority.mode -or
            $profile.measurement -cne $authority.measurement -or
            $profile.seedMode -cne $authority.seedMode -or
            $profile.target -cne $authority.target -or
            $profile.optimization -cne $authority.optimization -or
            $profile.expandedSourceCount -ne $authority.expandedSourceCount -or
            $profile.compilerFingerprint -cne $authority.compilerFingerprint -or
            $profile.fixtureFingerprint -cne $authority.fixtureFingerprint -or
            ($profile.fixtureRoots | ConvertTo-Json -Compress) -cne $authorityRoots -or
            ($profile.environment | ConvertTo-Json -Compress) -cne $authorityEnvironment) {
            throw "$Name profile group mixes workloads, environments, or fingerprints"
        }
    }

    [pscustomobject]@{
        Name = $Name
        Paths = $resolvedPaths
        Profiles = $profiles
        Authority = $authority
        Roots = $authorityRoots
        Environment = $authorityEnvironment
    }
}

function Get-Median {
    param([Parameter(Mandatory)][double[]]$Value)

    $ordered = @($Value | Sort-Object)
    $middle = [Math]::Floor($ordered.Count / 2)
    if ($ordered.Count % 2 -eq 1) {
        return [double]$ordered[$middle]
    }
    ([double]$ordered[$middle - 1] + [double]$ordered[$middle]) / 2.0
}

function Get-ProfileMetrics {
    param([Parameter(Mandatory)]$Group)

    $mode = $Group.Authority.mode
    $wall = [System.Collections.Generic.List[double]]::new()
    $cpu = [System.Collections.Generic.List[double]]::new()
    $peak = [System.Collections.Generic.List[double]]::new()
    foreach ($profile in $Group.Profiles) {
        if ($mode -ceq "expression-types") {
            $wall.Add([double]$profile.expressionTypeIdsDeltaMs)
            $cpu.Add([double]($profile.expressionTypeIdsTotalCpuMs - $profile.semanticPreparationCpuMs))
            $peak.Add([double]$profile.expressionTypeIdsPeakWorkingSetBytes)
        } elseif ($mode -ceq "typed-ir") {
            $wall.Add([double]$profile.postExpressionTypeTypedIrDeltaMs)
            $cpu.Add([double]($profile.typedIrTotalCpuMs - $profile.expressionTypeIdsTotalCpuMs))
            $peak.Add([double]$profile.typedIrPeakWorkingSetBytes)
        } else {
            $wall.Add([double]$profile.artifactEncodeDeltaMs)
            $cpu.Add([double]($profile.artifactTotalCpuMs - $profile.typedIrTotalCpuMs))
            $peak.Add([double]$profile.artifactPeakWorkingSetBytes)
        }
    }
    [pscustomobject]@{
        WallMilliseconds = Get-Median $wall.ToArray()
        CpuMilliseconds = Get-Median $cpu.ToArray()
        PeakWorkingSetBytes = Get-Median $peak.ToArray()
    }
}

function Get-PercentChange {
    param([double]$BaselineValue, [double]$CandidateValue)
    (($CandidateValue - $BaselineValue) / [Math]::Max(1.0, $BaselineValue)) * 100.0
}

$baselineGroup = Read-ProfileGroup $Baseline "baseline"
$candidateGroup = Read-ProfileGroup $Candidate "candidate"
$baselineAuthority = $baselineGroup.Authority
$candidateAuthority = $candidateGroup.Authority
if ($candidateAuthority.mode -cne $baselineAuthority.mode -or
    $candidateAuthority.measurement -cne $baselineAuthority.measurement -or
    $candidateAuthority.seedMode -cne $baselineAuthority.seedMode -or
    $candidateAuthority.target -cne $baselineAuthority.target -or
    $candidateAuthority.optimization -cne $baselineAuthority.optimization -or
    $candidateAuthority.expandedSourceCount -ne $baselineAuthority.expandedSourceCount -or
    $candidateGroup.Roots -cne $baselineGroup.Roots -or
    $candidateGroup.Environment -cne $baselineGroup.Environment) {
    throw "baseline and candidate profiles do not describe the same mode, workload shape, target, or environment"
}
if ($candidateAuthority.compilerFingerprint -ceq $baselineAuthority.compilerFingerprint -and
    $candidateAuthority.fixtureFingerprint -ceq $baselineAuthority.fixtureFingerprint) {
    throw "candidate profiles have the same compiler and fixture fingerprints as the baseline"
}

$baselineMetrics = Get-ProfileMetrics $baselineGroup
$candidateMetrics = Get-ProfileMetrics $candidateGroup
$wallImprovementPercent = -1.0 * (Get-PercentChange $baselineMetrics.WallMilliseconds $candidateMetrics.WallMilliseconds)
$cpuRegressionPercent = Get-PercentChange $baselineMetrics.CpuMilliseconds $candidateMetrics.CpuMilliseconds
$peakMemoryRegressionPercent = Get-PercentChange $baselineMetrics.PeakWorkingSetBytes $candidateMetrics.PeakWorkingSetBytes
$wallPassed = $wallImprovementPercent -ge $MinimumWallImprovementPercent
$cpuPassed = $cpuRegressionPercent -le $MaximumCpuRegressionPercent
$memoryPassed = $peakMemoryRegressionPercent -le $MaximumPeakMemoryRegressionPercent
$passed = $wallPassed -and $cpuPassed -and $memoryPassed

$report = [ordered]@{
    schemaVersion = 1
    mode = $baselineAuthority.mode
    sampleCountPerGroup = $baselineGroup.Profiles.Count
    thresholds = [ordered]@{
        minimumWallImprovementPercent = $MinimumWallImprovementPercent
        maximumCpuRegressionPercent = $MaximumCpuRegressionPercent
        maximumPeakMemoryRegressionPercent = $MaximumPeakMemoryRegressionPercent
    }
    baseline = [ordered]@{
        compilerFingerprint = $baselineAuthority.compilerFingerprint
        fixtureFingerprint = $baselineAuthority.fixtureFingerprint
        wallMillisecondsMedian = $baselineMetrics.WallMilliseconds
        cpuMillisecondsMedian = $baselineMetrics.CpuMilliseconds
        peakWorkingSetBytesMedian = $baselineMetrics.PeakWorkingSetBytes
    }
    candidate = [ordered]@{
        compilerFingerprint = $candidateAuthority.compilerFingerprint
        fixtureFingerprint = $candidateAuthority.fixtureFingerprint
        wallMillisecondsMedian = $candidateMetrics.WallMilliseconds
        cpuMillisecondsMedian = $candidateMetrics.CpuMilliseconds
        peakWorkingSetBytesMedian = $candidateMetrics.PeakWorkingSetBytes
    }
    comparison = [ordered]@{
        wallImprovementPercent = $wallImprovementPercent
        cpuRegressionPercent = $cpuRegressionPercent
        peakMemoryRegressionPercent = $peakMemoryRegressionPercent
        wallPassed = $wallPassed
        cpuPassed = $cpuPassed
        memoryPassed = $memoryPassed
        passed = $passed
    }
}
$reportJson = ($report | ConvertTo-Json -Depth 6) + "`n"
if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outputPath)) | Out-Null
    [System.IO.File]::WriteAllText($outputPath, $reportJson, [System.Text.UTF8Encoding]::new($false))
}
if (-not $Quiet) {
    Write-Host $reportJson.TrimEnd()
}
if (-not $passed) {
    throw "self-host profile candidate did not satisfy the predeclared wall, CPU, and peak-memory thresholds"
}
if (-not $Quiet) {
    Write-Host "[selfhost profile comparison] PASS repeated schema-v3 fingerprints, medians, and predeclared thresholds."
}
