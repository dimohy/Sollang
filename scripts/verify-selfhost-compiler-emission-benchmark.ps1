$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$runnerPath = Join-Path $PSScriptRoot "run-selfhost-compiler-emission-benchmark.ps1"
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) (
    "sollang-compiler-emission-benchmark-" + [Guid]::NewGuid().ToString("N"))
$temporaryDirectory = [System.IO.Path]::GetFullPath($temporaryDirectory)
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $temporaryDirectory.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [System.IO.Path]::GetFileName($temporaryDirectory).StartsWith(
        "sollang-compiler-emission-benchmark-",
        [System.StringComparison]::Ordinal)) {
    throw "compiler emission benchmark test escaped its owned temporary scope: $temporaryDirectory"
}

function Write-Profile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$CompilerFingerprint,
        [Parameter(Mandatory)][long]$WallMilliseconds,
        [Parameter(Mandatory)][long]$CpuMilliseconds,
        [Parameter(Mandatory)][long]$PeakWorkingSetBytes
    )
    $profile = [ordered]@{
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
        compilerFingerprint = $CompilerFingerprint
        inputFingerprint = "C" * 64
        outputFingerprint = "D" * 64
        outputBytes = 4096
        wallMilliseconds = $WallMilliseconds
        cpuMilliseconds = $CpuMilliseconds
        peakWorkingSetBytes = $PeakWorkingSetBytes
    }
    [System.IO.File]::WriteAllText(
        $Path,
        ($profile | ConvertTo-Json -Depth 8),
        [System.Text.UTF8Encoding]::new($false))
}

try {
    [System.IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
    $baselineCompiler = Join-Path $temporaryDirectory "baseline.exe"
    $candidateCompiler = Join-Path $temporaryDirectory "candidate.exe"
    [System.IO.File]::WriteAllText($baselineCompiler, "baseline")
    [System.IO.File]::WriteAllText($candidateCompiler, "candidate")
    $baselineFingerprint = (Get-FileHash -LiteralPath $baselineCompiler -Algorithm SHA256).Hash
    $candidateFingerprint = (Get-FileHash -LiteralPath $candidateCompiler -Algorithm SHA256).Hash
    $baselineLlvm = Join-Path $temporaryDirectory "baseline.ll"
    $candidateLlvm = Join-Path $temporaryDirectory "candidate.ll"
    Copy-Item `
        -LiteralPath (Join-Path $repoRoot "scripts/contracts/fixtures/selfhost-parallel-callback-serial-fallback.ll") `
        -Destination $baselineLlvm
    Copy-Item `
        -LiteralPath (Join-Path $repoRoot "scripts/contracts/fixtures/selfhost-parallel-callback-valid.ll") `
        -Destination $candidateLlvm

    foreach ($index in 1..3) {
        Write-Profile `
            -Path (Join-Path $temporaryDirectory "contract-baseline-$index.json") `
            -CompilerFingerprint $baselineFingerprint `
            -WallMilliseconds @(900, 1000, 1100)[$index - 1] `
            -CpuMilliseconds @(950, 1000, 1050)[$index - 1] `
            -PeakWorkingSetBytes @(990, 1000, 1010)[$index - 1]
        Write-Profile `
            -Path (Join-Path $temporaryDirectory "contract-candidate-$index.json") `
            -CompilerFingerprint $candidateFingerprint `
            -WallMilliseconds @(780, 800, 820)[$index - 1] `
            -CpuMilliseconds @(970, 990, 1010)[$index - 1] `
            -PeakWorkingSetBytes @(1010, 1020, 1030)[$index - 1]
    }

    $output = (& $runnerPath `
        -BaselineCompiler $baselineCompiler `
        -CandidateCompiler $candidateCompiler `
        -OutputDirectory $temporaryDirectory `
        -Name "contract" `
        -Jobs 24 `
        -Resume 6>&1 | Out-String)
    $expectedOrder = @(
        "RESUME baseline-1",
        "RESUME candidate-1",
        "RESUME candidate-2",
        "RESUME baseline-2",
        "RESUME baseline-3",
        "RESUME candidate-3"
    )
    $searchOffset = 0
    foreach ($expected in $expectedOrder) {
        $nextOffset = $output.IndexOf($expected, $searchOffset, [System.StringComparison]::Ordinal)
        if ($nextOffset -lt 0) { throw "benchmark resume order is missing $expected" }
        $searchOffset = $nextOffset + $expected.Length
    }
    if (-not (Test-Path -LiteralPath (Join-Path $temporaryDirectory "contract-comparison.json"))) {
        throw "benchmark runner did not preserve the comparison report"
    }

    $pairPath = Join-Path $temporaryDirectory "bootstrap-pair.json"
    $pair = [ordered]@{
        schemaVersion = 1
        mode = "adjacent-bootstrap-performance-pair"
        target = "windows"
        sourceFingerprint = "C" * 64
        baseline = [ordered]@{
            compilerPath = $baselineCompiler
            compilerFingerprint = $baselineFingerprint
            llvmPath = $baselineLlvm
            llvmFingerprint = (Get-FileHash -LiteralPath $baselineLlvm -Algorithm SHA256).Hash
            generatedByCompilerFingerprint = "A" * 64
            optimization = "O1"
            parallelCallbackCount = 3
            nominalTransferCallbackCount = 0
        }
        candidate = [ordered]@{
            compilerPath = $candidateCompiler
            compilerFingerprint = $candidateFingerprint
            llvmPath = $candidateLlvm
            llvmFingerprint = (Get-FileHash -LiteralPath $candidateLlvm -Algorithm SHA256).Hash
            generatedByCompilerFingerprint = $baselineFingerprint
            optimization = "O1"
            parallelCallbackCount = 4
            nominalTransferCallbackCount = 1
        }
    }
    [System.IO.File]::WriteAllText($pairPath, ($pair | ConvertTo-Json -Depth 8))
    $pairOutput = (& $runnerPath `
        -BaselineCompiler $baselineCompiler `
        -CandidateCompiler $candidateCompiler `
        -BootstrapPairReceipt $pairPath `
        -OutputDirectory $temporaryDirectory `
        -Name "contract" `
        -Jobs 24 `
        -Resume 6>&1 | Out-String)
    if (-not $pairOutput.Contains("Performance pair receipt PASS")) {
        throw "benchmark runner did not authenticate the adjacent bootstrap pair"
    }

    $pair.candidate.generatedByCompilerFingerprint = "E" * 64
    [System.IO.File]::WriteAllText($pairPath, ($pair | ConvertTo-Json -Depth 8))
    $chainRejected = $false
    try {
        & $runnerPath `
            -BaselineCompiler $baselineCompiler `
            -CandidateCompiler $candidateCompiler `
            -BootstrapPairReceipt $pairPath `
            -OutputDirectory $temporaryDirectory `
            -Name "contract" `
            -Jobs 24 `
            -Resume | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("does not prove the requested target")) { throw }
        $chainRejected = $true
    }
    if (-not $chainRejected) { throw "benchmark runner accepted a broken bootstrap generation chain" }
    $pair.candidate.generatedByCompilerFingerprint = $baselineFingerprint
    [System.IO.File]::WriteAllText($pairPath, ($pair | ConvertTo-Json -Depth 8))

    $implementationPairPath = Join-Path $temporaryDirectory "implementation-pair.json"
    $implementationPair = [ordered]@{
        schemaVersion = 1
        mode = "controlled-implementation-performance-pair"
        target = "windows"
        sourceFingerprint = "C" * 64
        baseline = [ordered]@{
            compilerPath = $baselineCompiler
            compilerFingerprint = $baselineFingerprint
            llvmPath = $candidateLlvm
            llvmFingerprint = (Get-FileHash -LiteralPath $candidateLlvm -Algorithm SHA256).Hash
            generatedByCompilerFingerprint = "F" * 64
            optimization = "O1"
            parallelCallbackCount = 4
            nominalTransferCallbackCount = 1
            dispatch = "per-source"
        }
        candidate = [ordered]@{
            compilerPath = $candidateCompiler
            compilerFingerprint = $candidateFingerprint
            llvmPath = $candidateLlvm
            llvmFingerprint = (Get-FileHash -LiteralPath $candidateLlvm -Algorithm SHA256).Hash
            generatedByCompilerFingerprint = "F" * 64
            optimization = "O1"
            parallelCallbackCount = 4
            nominalTransferCallbackCount = 1
            dispatch = "compiler-wide"
        }
    }
    [System.IO.File]::WriteAllText(
        $implementationPairPath,
        ($implementationPair | ConvertTo-Json -Depth 8))
    $implementationPairOutput = (& $runnerPath `
        -BaselineCompiler $baselineCompiler `
        -CandidateCompiler $candidateCompiler `
        -ImplementationPairReceipt $implementationPairPath `
        -OutputDirectory $temporaryDirectory `
        -Name "contract" `
        -Jobs 24 `
        -Resume 6>&1 | Out-String)
    if (-not $implementationPairOutput.Contains("Performance pair receipt PASS")) {
        throw "benchmark runner did not authenticate the controlled implementation pair"
    }

    $relaxedThresholdRejected = $false
    try {
        & $runnerPath `
            -BaselineCompiler $baselineCompiler `
            -CandidateCompiler $candidateCompiler `
            -ImplementationPairReceipt $implementationPairPath `
            -OutputDirectory $temporaryDirectory `
            -Name "contract" `
            -Jobs 24 `
            -MinimumWallImprovementPercent 0 `
            -Resume | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("require the frozen")) { throw }
        $relaxedThresholdRejected = $true
    }
    if (-not $relaxedThresholdRejected) {
        throw "benchmark runner accepted relaxed authenticated-pair thresholds"
    }

    $implementationPair.candidate.generatedByCompilerFingerprint = "B" * 64
    [System.IO.File]::WriteAllText(
        $implementationPairPath,
        ($implementationPair | ConvertTo-Json -Depth 8))
    $implementationControlRejected = $false
    try {
        & $runnerPath `
            -BaselineCompiler $baselineCompiler `
            -CandidateCompiler $candidateCompiler `
            -ImplementationPairReceipt $implementationPairPath `
            -OutputDirectory $temporaryDirectory `
            -Name "contract" `
            -Jobs 24 `
            -Resume | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("does not prove same-seed")) { throw }
        $implementationControlRejected = $true
    }
    if (-not $implementationControlRejected) {
        throw "benchmark runner accepted a broken controlled implementation pair"
    }

    $overwriteRejected = $false
    try {
        & $runnerPath `
            -BaselineCompiler $baselineCompiler `
            -CandidateCompiler $candidateCompiler `
            -OutputDirectory $temporaryDirectory `
            -Name "contract" `
            -Jobs 24 | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("benchmark profile already exists; pass -Resume")) { throw }
        $overwriteRejected = $true
    }
    if (-not $overwriteRejected) { throw "benchmark runner overwrote an existing profile without -Resume" }

    $stalePath = Join-Path $temporaryDirectory "contract-candidate-2.json"
    $stale = [System.IO.File]::ReadAllText($stalePath) | ConvertFrom-Json
    $stale.compilerFingerprint = "E" * 64
    [System.IO.File]::WriteAllText($stalePath, ($stale | ConvertTo-Json -Depth 8))
    $staleRejected = $false
    try {
        & $runnerPath `
            -BaselineCompiler $baselineCompiler `
            -CandidateCompiler $candidateCompiler `
            -OutputDirectory $temporaryDirectory `
            -Name "contract" `
            -Jobs 24 `
            -Resume | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("existing benchmark profile belongs to another compiler")) { throw }
        $staleRejected = $true
    }
    if (-not $staleRejected) { throw "benchmark runner resumed a stale compiler profile" }
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

Write-Host "[compiler emission benchmark] PASS balanced resume order, frozen bootstrap and controlled implementation pairs, comparison, no-overwrite, and stale-compiler controls."
