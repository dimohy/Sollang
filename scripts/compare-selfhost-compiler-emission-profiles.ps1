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
$schemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-compiler-emission-profile.schema.json"

function Get-Median {
    param([Parameter(Mandatory)][double[]]$Value)
    $ordered = @($Value | Sort-Object)
    $middle = [Math]::Floor($ordered.Count / 2)
    if ($ordered.Count % 2 -eq 1) { return [double]$ordered[$middle] }
    ([double]$ordered[$middle - 1] + [double]$ordered[$middle]) / 2.0
}

function Read-Group {
    param([Parameter(Mandatory)][string[]]$Path, [Parameter(Mandatory)][string]$Name)
    if ($Path.Count -lt $MinimumSamples) {
        throw "$Name profile group has $($Path.Count) samples; at least $MinimumSamples are required"
    }
    $resolved = @($Path | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
    if (($resolved | Select-Object -Unique).Count -ne $resolved.Count) {
        throw "$Name profile group repeats a sample path"
    }
    $profiles = @($resolved | ForEach-Object {
        $json = [System.IO.File]::ReadAllText($_)
        if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
            throw "$Name compiler emission profile does not match its schema: $_"
        }
        $json | ConvertFrom-Json
    })
    $authority = $profiles[0]
    $environment = $authority.environment | ConvertTo-Json -Compress
    $manifests = $authority.sourceManifests | ConvertTo-Json -Compress
    foreach ($profile in $profiles) {
        if ($profile.mode -cne $authority.mode -or
            $profile.measurement -cne $authority.measurement -or
            $profile.target -cne $authority.target -or
            $profile.workerLimit -ne $authority.workerLimit -or
            $profile.sourceCount -ne $authority.sourceCount -or
            $profile.compilerFingerprint -cne $authority.compilerFingerprint -or
            $profile.inputFingerprint -cne $authority.inputFingerprint -or
            $profile.outputFingerprint -cne $authority.outputFingerprint -or
            $profile.outputBytes -ne $authority.outputBytes -or
            ($profile.environment | ConvertTo-Json -Compress) -cne $environment -or
            ($profile.sourceManifests | ConvertTo-Json -Compress) -cne $manifests) {
            throw "$Name profiles mix compilers, workloads, environments, or LLVM outputs"
        }
    }
    [pscustomobject]@{
        Authority = $authority
        Profiles = $profiles
        Environment = $environment
        Manifests = $manifests
        Wall = Get-Median @($profiles.wallMilliseconds)
        Cpu = Get-Median @($profiles.cpuMilliseconds)
        Peak = Get-Median @($profiles.peakWorkingSetBytes)
    }
}

function Get-PercentChange {
    param([double]$BaselineValue, [double]$CandidateValue)
    (($CandidateValue - $BaselineValue) / [Math]::Max(1.0, $BaselineValue)) * 100.0
}

$baselineGroup = Read-Group $Baseline "baseline"
$candidateGroup = Read-Group $Candidate "candidate"
$baselineAuthority = $baselineGroup.Authority
$candidateAuthority = $candidateGroup.Authority
if ($candidateAuthority.target -cne $baselineAuthority.target -or
    $candidateAuthority.workerLimit -ne $baselineAuthority.workerLimit -or
    $candidateAuthority.sourceCount -ne $baselineAuthority.sourceCount -or
    $candidateAuthority.inputFingerprint -cne $baselineAuthority.inputFingerprint -or
    $candidateAuthority.outputFingerprint -cne $baselineAuthority.outputFingerprint -or
    $candidateAuthority.outputBytes -ne $baselineAuthority.outputBytes -or
    $candidateGroup.Environment -cne $baselineGroup.Environment -or
    $candidateGroup.Manifests -cne $baselineGroup.Manifests) {
    throw "baseline and candidate do not describe the same native workload or deterministic LLVM output"
}
if ($candidateAuthority.compilerFingerprint -ceq $baselineAuthority.compilerFingerprint) {
    throw "candidate compiler fingerprint is identical to the baseline"
}

$wallImprovementPercent = -1.0 * (Get-PercentChange $baselineGroup.Wall $candidateGroup.Wall)
$cpuRegressionPercent = Get-PercentChange $baselineGroup.Cpu $candidateGroup.Cpu
$peakMemoryRegressionPercent = Get-PercentChange $baselineGroup.Peak $candidateGroup.Peak
$wallPassed = $wallImprovementPercent -ge $MinimumWallImprovementPercent
$cpuPassed = $cpuRegressionPercent -le $MaximumCpuRegressionPercent
$memoryPassed = $peakMemoryRegressionPercent -le $MaximumPeakMemoryRegressionPercent
$passed = $wallPassed -and $cpuPassed -and $memoryPassed

$report = [ordered]@{
    schemaVersion = 1
    mode = "compiler-emission"
    sampleCountPerGroup = $baselineGroup.Profiles.Count
    thresholds = [ordered]@{
        minimumWallImprovementPercent = $MinimumWallImprovementPercent
        maximumCpuRegressionPercent = $MaximumCpuRegressionPercent
        maximumPeakMemoryRegressionPercent = $MaximumPeakMemoryRegressionPercent
    }
    workload = [ordered]@{
        target = $baselineAuthority.target
        workerLimit = $baselineAuthority.workerLimit
        sourceCount = $baselineAuthority.sourceCount
        inputFingerprint = $baselineAuthority.inputFingerprint
        outputFingerprint = $baselineAuthority.outputFingerprint
        outputBytes = $baselineAuthority.outputBytes
    }
    baseline = [ordered]@{
        compilerFingerprint = $baselineAuthority.compilerFingerprint
        wallMillisecondsMedian = $baselineGroup.Wall
        cpuMillisecondsMedian = $baselineGroup.Cpu
        peakWorkingSetBytesMedian = $baselineGroup.Peak
    }
    candidate = [ordered]@{
        compilerFingerprint = $candidateAuthority.compilerFingerprint
        wallMillisecondsMedian = $candidateGroup.Wall
        cpuMillisecondsMedian = $candidateGroup.Cpu
        peakWorkingSetBytesMedian = $candidateGroup.Peak
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
$json = ($report | ConvertTo-Json -Depth 6) + "`n"
if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outputPath)) | Out-Null
    [System.IO.File]::WriteAllText($outputPath, $json, [System.Text.UTF8Encoding]::new($false))
}
if (-not $Quiet) { Write-Host $json.TrimEnd() }
if (-not $passed) {
    throw "native compiler emission candidate did not satisfy the predeclared wall, CPU, and peak-memory thresholds"
}
if (-not $Quiet) {
    Write-Host "[compiler emission comparison] PASS identical inputs and LLVM outputs with repeated predeclared thresholds."
}
