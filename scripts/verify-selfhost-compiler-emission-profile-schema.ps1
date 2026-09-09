$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-compiler-emission-profile.schema.json"
$comparisonPath = Join-Path $repoRoot "scripts\compare-selfhost-compiler-emission-profiles.ps1"
$zeroFingerprint = "0" * 64
$outputFingerprint = "A" * 64
$sample = [ordered]@{
    schemaVersion = 1
    mode = "compiler-emission"
    measurement = "single-process-native-llvm-emission"
    target = "windows"
    workerLimit = 24
    environment = [ordered]@{
        osDescription = "Windows"
        processArchitecture = "X64"
        processorCount = 24
    }
    sourceManifests = @("compiler.sources.txt", "runtime.sources.txt")
    sourceCount = 113
    compilerFingerprint = $zeroFingerprint
    inputFingerprint = "B" * 64
    outputFingerprint = $outputFingerprint
    outputBytes = 1024
    wallMilliseconds = 1000
    cpuMilliseconds = 1000
    peakWorkingSetBytes = 1000
}

$validJson = $sample | ConvertTo-Json -Depth 8
if (-not ($validJson | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "valid self-host compiler emission profile was rejected"
}
$sample.peakWorkingSetBytes = 0
if ($sample | ConvertTo-Json -Depth 8 | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue) {
    throw "compiler emission profile schema accepted an unobserved zero peak working set"
}
$sample.peakWorkingSetBytes = 1000

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    "sollang-compiler-emission-profile-" + [Guid]::NewGuid().ToString("N"))
$temporaryDirectory = [System.IO.Path]::GetFullPath($temporaryDirectory)
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $temporaryDirectory.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [System.IO.Path]::GetFileName($temporaryDirectory).StartsWith(
        "sollang-compiler-emission-profile-",
        [System.StringComparison]::Ordinal)) {
    throw "compiler emission profile test escaped its owned temporary scope: $temporaryDirectory"
}
try {
    [System.IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
    $baselinePaths = [System.Collections.Generic.List[string]]::new()
    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($index in 1..3) {
        $baseline = $validJson | ConvertFrom-Json
        $baseline.wallMilliseconds = @(900, 1000, 1100)[$index - 1]
        $baseline.cpuMilliseconds = @(950, 1000, 1050)[$index - 1]
        $baseline.peakWorkingSetBytes = @(990, 1000, 1010)[$index - 1]
        $baselinePath = Join-Path $temporaryDirectory "baseline-$index.json"
        [System.IO.File]::WriteAllText($baselinePath, ($baseline | ConvertTo-Json -Depth 8))
        $baselinePaths.Add($baselinePath)

        $candidate = $validJson | ConvertFrom-Json
        $candidate.compilerFingerprint = "1" * 64
        $candidate.wallMilliseconds = @(780, 800, 820)[$index - 1]
        $candidate.cpuMilliseconds = @(970, 990, 1010)[$index - 1]
        $candidate.peakWorkingSetBytes = @(1010, 1020, 1030)[$index - 1]
        $candidatePath = Join-Path $temporaryDirectory "candidate-$index.json"
        [System.IO.File]::WriteAllText($candidatePath, ($candidate | ConvertTo-Json -Depth 8))
        $candidatePaths.Add($candidatePath)
    }

    & $comparisonPath `
        -Baseline $baselinePaths.ToArray() `
        -Candidate $candidatePaths.ToArray() `
        -MinimumWallImprovementPercent 20 `
        -MaximumCpuRegressionPercent 0 `
        -MaximumPeakMemoryRegressionPercent 2 `
        -Output (Join-Path $temporaryDirectory "passing-report.json") `
        -Quiet

    $thresholdFailureObserved = $false
    try {
        & $comparisonPath `
            -Baseline $baselinePaths.ToArray() `
            -Candidate $candidatePaths.ToArray() `
            -MinimumWallImprovementPercent 21 `
            -MaximumCpuRegressionPercent 0 `
            -MaximumPeakMemoryRegressionPercent 2 `
            -Output (Join-Path $temporaryDirectory "failing-report.json") `
            -Quiet
    } catch {
        if ($_.Exception.Message -cne "native compiler emission candidate did not satisfy the predeclared wall, CPU, and peak-memory thresholds") {
            throw
        }
        $thresholdFailureObserved = $true
    }
    if (-not $thresholdFailureObserved -or
        -not (Test-Path -LiteralPath (Join-Path $temporaryDirectory "failing-report.json"))) {
        throw "compiler emission comparison did not preserve and reject a failed threshold report"
    }

    $drifted = [System.IO.File]::ReadAllText($candidatePaths[2]) | ConvertFrom-Json
    $drifted.outputFingerprint = "C" * 64
    [System.IO.File]::WriteAllText($candidatePaths[2], ($drifted | ConvertTo-Json -Depth 8))
    $determinismFailureObserved = $false
    try {
        & $comparisonPath `
            -Baseline $baselinePaths.ToArray() `
            -Candidate $candidatePaths.ToArray() `
            -MinimumWallImprovementPercent 0 `
            -MaximumCpuRegressionPercent 100 `
            -MaximumPeakMemoryRegressionPercent 100 `
            -Quiet
    } catch {
        if ($_.Exception.Message -cne "candidate profiles mix compilers, workloads, environments, or LLVM outputs") {
            throw
        }
        $determinismFailureObserved = $true
    }
    if (-not $determinismFailureObserved) {
        throw "compiler emission comparison accepted nondeterministic candidate LLVM"
    }
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

Write-Host "[compiler emission profile schema] PASS schema, repeated medians, thresholds, failed report, and deterministic LLVM controls."
