$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-profile.schema.json"
$historicalSchemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-profile-v2.schema.json"
$fingerprint = "0" * 64
$sample = [ordered]@{
    schemaVersion = 3
    mode = "expression-types"
    measurement = "single-process-wall-clock-cpu-peak-working-set"
    semanticBaseline = "prepare-only"
    sampleCount = 1
    seedMode = "Slg"
    target = "windows"
    optimization = "O1"
    environment = [ordered]@{
        osDescription = "Windows"
        processArchitecture = "X64"
        processorCount = 1
    }
    fixtureRoots = @("probe.slg")
    expandedSourceCount = 1
    compilerFingerprint = $fingerprint
    fixtureFingerprint = $fingerprint
    semanticPreparationMs = 1
    semanticPreparationCpuMs = 1
    semanticPreparationPeakWorkingSetBytes = 1024
    expressionTypeIdsTotalMs = 2
    expressionTypeIdsDeltaMs = 1
    expressionTypeIdsTotalCpuMs = 2
    expressionTypeIdsPeakWorkingSetBytes = 2048
    typedIrTotalMs = $null
    typedIrDeltaMs = $null
    postExpressionTypeTypedIrDeltaMs = $null
    typedIrTotalCpuMs = $null
    typedIrPeakWorkingSetBytes = $null
    artifactTotalMs = $null
    artifactEncodeDeltaMs = $null
    artifactTotalCpuMs = $null
    artifactPeakWorkingSetBytes = $null
}

$validJson = $sample | ConvertTo-Json -Depth 8
if (-not ($validJson | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "valid self-host profile schema v3 sample was rejected"
}

$sample.expressionTypeIdsPeakWorkingSetBytes = 0
$invalidPeakJson = $sample | ConvertTo-Json -Depth 8
$invalidPeakAccepted = $invalidPeakJson | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue
if ($invalidPeakAccepted) {
    throw "self-host profile schema accepted an unobserved zero peak working set"
}
$sample.expressionTypeIdsPeakWorkingSetBytes = 2048

$sample.semanticBaseline = "fingerprint"
$invalidJson = $sample | ConvertTo-Json -Depth 8
$invalidAccepted = $invalidJson | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue
if ($invalidAccepted) {
    throw "self-host profile schema accepted the mixed-cost fingerprint baseline"
}

$historicalSample = [ordered]@{
    schemaVersion = 2
    mode = "expression-types"
    measurement = "single-wall-clock"
    semanticBaseline = "prepare-only"
    sampleCount = 1
    seedMode = "Slg"
    target = "windows"
    optimization = "O1"
    environment = [ordered]@{
        osDescription = "Windows"
        processArchitecture = "X64"
        processorCount = 1
    }
    fixtureRoots = @("probe.slg")
    expandedSourceCount = 1
    compilerFingerprint = $fingerprint
    fixtureFingerprint = $fingerprint
    semanticPreparationMs = 1
    expressionTypeIdsTotalMs = 2
    expressionTypeIdsDeltaMs = 1
    typedIrTotalMs = $null
    typedIrDeltaMs = $null
    postExpressionTypeTypedIrDeltaMs = $null
    artifactTotalMs = $null
    artifactEncodeDeltaMs = $null
}
$historicalJson = $historicalSample | ConvertTo-Json -Depth 8
if (-not ($historicalJson | Test-Json -SchemaFile $historicalSchemaPath -ErrorAction Stop)) {
    throw "valid historical self-host profile schema v2 sample was rejected"
}

$comparisonPath = Join-Path $repoRoot "scripts\compare-selfhost-profiles.ps1"
$comparisonDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-selfhost-profile-comparison-" + [Guid]::NewGuid().ToString("N"))
$comparisonDirectory = [System.IO.Path]::GetFullPath($comparisonDirectory)
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $comparisonDirectory.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [System.IO.Path]::GetFileName($comparisonDirectory).StartsWith(
        "sollang-selfhost-profile-comparison-",
        [System.StringComparison]::Ordinal)) {
    throw "self-host profile comparison contract escaped its owned temporary scope: $comparisonDirectory"
}
try {
    [System.IO.Directory]::CreateDirectory($comparisonDirectory) | Out-Null
    $baselinePaths = [System.Collections.Generic.List[string]]::new()
    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    1..3 | ForEach-Object {
        $baseline = $validJson | ConvertFrom-Json
        $baseline.semanticPreparationMs = 50
        $baseline.semanticPreparationCpuMs = 50
        $baseline.expressionTypeIdsTotalMs = 150
        $baseline.expressionTypeIdsDeltaMs = 100
        $baseline.expressionTypeIdsTotalCpuMs = 150
        $baseline.expressionTypeIdsPeakWorkingSetBytes = 1000
        $baselinePath = Join-Path $comparisonDirectory "baseline-$_.json"
        [System.IO.File]::WriteAllText($baselinePath, ($baseline | ConvertTo-Json -Depth 8))
        $baselinePaths.Add($baselinePath)

        $candidate = $validJson | ConvertFrom-Json
        $candidate.compilerFingerprint = "1" * 64
        $candidate.fixtureFingerprint = "1" * 64
        $candidate.semanticPreparationMs = 50
        $candidate.semanticPreparationCpuMs = 50
        $candidate.expressionTypeIdsTotalMs = 130
        $candidate.expressionTypeIdsDeltaMs = 80
        $candidate.expressionTypeIdsTotalCpuMs = 140
        $candidate.expressionTypeIdsPeakWorkingSetBytes = 1050
        $candidatePath = Join-Path $comparisonDirectory "candidate-$_.json"
        [System.IO.File]::WriteAllText($candidatePath, ($candidate | ConvertTo-Json -Depth 8))
        $candidatePaths.Add($candidatePath)
    }
    & $comparisonPath `
        -Baseline $baselinePaths.ToArray() `
        -Candidate $candidatePaths.ToArray() `
        -MinimumWallImprovementPercent 20 `
        -MaximumCpuRegressionPercent 0 `
        -MaximumPeakMemoryRegressionPercent 5 `
        -Output (Join-Path $comparisonDirectory "passing-report.json") `
        -Quiet

    $thresholdFailureObserved = $false
    try {
        & $comparisonPath `
            -Baseline $baselinePaths.ToArray() `
            -Candidate $candidatePaths.ToArray() `
            -MinimumWallImprovementPercent 21 `
            -MaximumCpuRegressionPercent 0 `
            -MaximumPeakMemoryRegressionPercent 5 `
            -Output (Join-Path $comparisonDirectory "failing-report.json") `
            -Quiet
    } catch {
        if ($_.Exception.Message -cne "self-host profile candidate did not satisfy the predeclared wall, CPU, and peak-memory thresholds") {
            throw
        }
        $thresholdFailureObserved = $true
    }
    if (-not $thresholdFailureObserved -or
        -not (Test-Path -LiteralPath (Join-Path $comparisonDirectory "failing-report.json"))) {
        throw "self-host profile comparison did not preserve and reject a failed threshold report"
    }

    $drifted = Get-Content -Raw $candidatePaths[2] | ConvertFrom-Json
    $drifted.compilerFingerprint = "2" * 64
    [System.IO.File]::WriteAllText($candidatePaths[2], ($drifted | ConvertTo-Json -Depth 8))
    $fingerprintFailureObserved = $false
    try {
        & $comparisonPath `
            -Baseline $baselinePaths.ToArray() `
            -Candidate $candidatePaths.ToArray() `
            -MinimumWallImprovementPercent 0 `
            -MaximumCpuRegressionPercent 100 `
            -MaximumPeakMemoryRegressionPercent 100 `
            -Quiet
    } catch {
        if ($_.Exception.Message -cne "candidate profile group mixes workloads, environments, or fingerprints") {
            throw
        }
        $fingerprintFailureObserved = $true
    }
    if (-not $fingerprintFailureObserved) {
        throw "self-host profile comparison accepted mixed candidate fingerprints"
    }
} finally {
    if (Test-Path -LiteralPath $comparisonDirectory) {
        Remove-Item -LiteralPath $comparisonDirectory -Recurse -Force
    }
}

Write-Host "[selfhost profile schema] PASS historical v2, current v3, peak-memory, repeated-median threshold, failed-report, and fingerprint controls."
