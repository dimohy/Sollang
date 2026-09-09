[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineCompiler,
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [string]$OutputDirectory = "artifacts/profiles",
    [ValidateSet("windows", "linux")][string]$Target = "windows",
    [ValidateRange(1, 1024)][int]$Jobs = [System.Environment]::ProcessorCount,
    [ValidateRange(3, 99)][int]$SampleCount = 3,
    [ValidateRange(1000, 7200000)][int]$TimeoutMilliseconds = 3600000,
    [ValidateRange(-100.0, 100.0)][double]$MinimumWallImprovementPercent = 1,
    [ValidateRange(0.0, 1000.0)][double]$MaximumCpuRegressionPercent = 0,
    [ValidateRange(0.0, 1000.0)][double]$MaximumPeakMemoryRegressionPercent = 2,
    [string]$Name = "c82-native",
    [string[]]$Manifest = @(
        "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt",
        "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt"
    ),
    [string]$BootstrapPairReceipt = "",
    [string]$ImplementationPairReceipt = "",
    [switch]$Resume,
    [switch]$KeepFirstLlvm
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$measurePath = Join-Path $PSScriptRoot "measure-selfhost-compiler-emission.ps1"
$comparePath = Join-Path $PSScriptRoot "compare-selfhost-compiler-emission-profiles.ps1"
$schemaPath = Join-Path $PSScriptRoot "contracts/selfhost-compiler-emission-profile.schema.json"
$baselinePath = (Resolve-Path -LiteralPath $BaselineCompiler).Path
$candidatePath = (Resolve-Path -LiteralPath $CandidateCompiler).Path
$outputRoot = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$compilerPaths = @{
    baseline = $baselinePath
    candidate = $candidatePath
}
$compilerFingerprints = @{
    baseline = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash
    candidate = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash
}
if ($compilerFingerprints.baseline -ceq $compilerFingerprints.candidate) {
    throw "baseline and candidate compiler fingerprints are identical"
}

$performancePair = $null
if (-not [string]::IsNullOrWhiteSpace($BootstrapPairReceipt) -and
    -not [string]::IsNullOrWhiteSpace($ImplementationPairReceipt)) {
    throw "select one performance pair receipt, not both bootstrap and implementation pairs"
}
$selectedPairReceipt = if (-not [string]::IsNullOrWhiteSpace($ImplementationPairReceipt)) {
    $ImplementationPairReceipt
} else {
    $BootstrapPairReceipt
}
if (-not [string]::IsNullOrWhiteSpace($selectedPairReceipt)) {
    if ($SampleCount -ne 3 -or
        $Jobs -ne 24 -or
        $MinimumWallImprovementPercent -ne 1 -or
        $MaximumCpuRegressionPercent -ne 0 -or
        $MaximumPeakMemoryRegressionPercent -ne 2) {
        throw "authenticated performance pairs require the frozen 3-sample, 24-worker, 1/0/2-percent acceptance contract"
    }
    $pairPath = (Resolve-Path -LiteralPath $selectedPairReceipt).Path
    $pairSchemaPath = if (-not [string]::IsNullOrWhiteSpace($ImplementationPairReceipt)) {
        Join-Path $PSScriptRoot "contracts/selfhost-implementation-performance-pair.schema.json"
    } else {
        Join-Path $PSScriptRoot "contracts/selfhost-bootstrap-performance-pair.schema.json"
    }
    $pairJson = [System.IO.File]::ReadAllText($pairPath)
    if (-not ($pairJson | Test-Json -SchemaFile $pairSchemaPath -ErrorAction Stop)) {
        throw "performance pair receipt does not match the schema: $pairPath"
    }
    $performancePair = $pairJson | ConvertFrom-Json
    $callbackVerifier = Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1"
    foreach ($variant in @("baseline", "candidate")) {
        $artifact = $performancePair.$variant
        $artifactCompilerPath = if ([System.IO.Path]::IsPathRooted($artifact.compilerPath)) {
            $artifact.compilerPath
        } else {
            Join-Path $repoRoot $artifact.compilerPath
        }
        $artifactLlvmPath = if ([System.IO.Path]::IsPathRooted($artifact.llvmPath)) {
            $artifact.llvmPath
        } else {
            Join-Path $repoRoot $artifact.llvmPath
        }
        $recordedCompilerPath = (Resolve-Path -LiteralPath $artifactCompilerPath).Path
        $recordedLlvmPath = (Resolve-Path -LiteralPath $artifactLlvmPath).Path
        if ($recordedCompilerPath -cne $compilerPaths[$variant] -or
            $artifact.compilerFingerprint -cne $compilerFingerprints[$variant] -or
            (Get-FileHash -LiteralPath $recordedCompilerPath -Algorithm SHA256).Hash -cne $artifact.compilerFingerprint -or
            (Get-FileHash -LiteralPath $recordedLlvmPath -Algorithm SHA256).Hash -cne $artifact.llvmFingerprint) {
            throw "performance pair $variant artifact identity drifted: $pairPath"
        }
        $callbackEvidence = & $callbackVerifier `
            -LlvmPath $recordedLlvmPath `
            -MinimumCallbackCount 1 `
            -PassThru
        if ($callbackEvidence.CallbackCount -ne $artifact.parallelCallbackCount -or
            $callbackEvidence.NominalTransferCallbackCount -ne $artifact.nominalTransferCallbackCount) {
            throw "performance pair $variant callback evidence drifted: $pairPath"
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ImplementationPairReceipt)) {
        if ($performancePair.target -cne $Target -or
            $performancePair.baseline.generatedByCompilerFingerprint -cne $performancePair.candidate.generatedByCompilerFingerprint -or
            $performancePair.baseline.dispatch -cne "per-source" -or
            $performancePair.candidate.dispatch -cne "compiler-wide" -or
            $performancePair.baseline.optimization -cne "O1" -or
            $performancePair.candidate.optimization -cne "O1" -or
            $performancePair.baseline.parallelCallbackCount -lt 4 -or
            $performancePair.candidate.parallelCallbackCount -lt 4 -or
            $performancePair.baseline.nominalTransferCallbackCount -lt 1 -or
            $performancePair.candidate.nominalTransferCallbackCount -lt 1) {
            throw "implementation performance pair does not prove same-seed per-source versus compiler-wide O1 controls"
        }
    } elseif ($performancePair.target -cne $Target -or
        $performancePair.candidate.generatedByCompilerFingerprint -cne $performancePair.baseline.compilerFingerprint -or
        -not (($performancePair.baseline.parallelCallbackCount -eq 3 -and
                $performancePair.baseline.nominalTransferCallbackCount -eq 0) -or
            ($performancePair.baseline.parallelCallbackCount -ge 4 -and
                $performancePair.baseline.nominalTransferCallbackCount -ge 1)) -or
        $performancePair.baseline.optimization -cne "O1" -or
        $performancePair.candidate.optimization -cne "O1" -or
        $performancePair.candidate.parallelCallbackCount -lt 4 -or
        $performancePair.candidate.nominalTransferCallbackCount -lt 1) {
        throw "bootstrap performance pair does not prove the requested target with an authenticated current Stage1 and nominal-worker Stage2 generation"
    }
    Write-Host "[compiler emission suite] Performance pair receipt PASS $pairPath."
}

function Get-ProfilePath {
    param([Parameter(Mandatory)][string]$Variant, [Parameter(Mandatory)][int]$Index)
    Join-Path $outputRoot "$Name-$Variant-$Index.json"
}

function Test-ResumableProfile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Variant
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $json = [System.IO.File]::ReadAllText($Path)
    if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "existing benchmark profile does not match the schema: $Path"
    }
    $profile = $json | ConvertFrom-Json
    if ($profile.compilerFingerprint -cne $compilerFingerprints[$Variant] -or
        $profile.target -cne $Target -or
        $profile.workerLimit -ne $Jobs) {
        throw "existing benchmark profile belongs to another compiler, target, or worker count: $Path"
    }
    if ($null -ne $performancePair -and $profile.inputFingerprint -cne $performancePair.sourceFingerprint) {
        throw "existing benchmark profile input does not match the performance pair: $Path"
    }
    return $true
}

function Assert-ProfileMatchesPerformancePair {
    param([Parameter(Mandatory)][string]$Path)
    if ($null -eq $performancePair) { return }
    $profile = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json
    if ($profile.inputFingerprint -cne $performancePair.sourceFingerprint) {
        throw "benchmark profile input does not match the performance pair: $Path"
    }
}

$plan = [System.Collections.Generic.List[object]]::new()
foreach ($index in 1..$SampleCount) {
    $variants = if ($index % 2 -eq 1) { @("baseline", "candidate") } else { @("candidate", "baseline") }
    foreach ($variant in $variants) {
        $plan.Add([pscustomobject]@{ Variant = $variant; Index = $index })
    }
}

$completed = 0
foreach ($step in $plan) {
    $profilePath = Get-ProfilePath $step.Variant $step.Index
    if ($Resume -and (Test-ResumableProfile $profilePath $step.Variant)) {
        Assert-ProfileMatchesPerformancePair $profilePath
        $completed += 1
        Write-Host "[compiler emission suite] sample $completed/$($plan.Count) RESUME $($step.Variant)-$($step.Index)."
        continue
    }
    if (Test-Path -LiteralPath $profilePath) {
        throw "benchmark profile already exists; pass -Resume to authenticate and reuse it: $profilePath"
    }

    $measureArguments = @{
        Compiler = $compilerPaths[$step.Variant]
        Output = $profilePath
        Target = $Target
        Jobs = $Jobs
        TimeoutMilliseconds = $TimeoutMilliseconds
        Manifest = $Manifest
    }
    if ($KeepFirstLlvm -and $step.Index -eq 1) {
        $measureArguments.KeepLlvm = $true
    }
    & $measurePath @measureArguments
    Assert-ProfileMatchesPerformancePair $profilePath
    $completed += 1
    Write-Host "[compiler emission suite] sample $completed/$($plan.Count) PASS $($step.Variant)-$($step.Index)."
}

$baselineProfiles = @(1..$SampleCount | ForEach-Object { Get-ProfilePath "baseline" $_ })
$candidateProfiles = @(1..$SampleCount | ForEach-Object { Get-ProfilePath "candidate" $_ })
$reportPath = Join-Path $outputRoot "$Name-comparison.json"
& $comparePath `
    -Baseline $baselineProfiles `
    -Candidate $candidateProfiles `
    -MinimumWallImprovementPercent $MinimumWallImprovementPercent `
    -MaximumCpuRegressionPercent $MaximumCpuRegressionPercent `
    -MaximumPeakMemoryRegressionPercent $MaximumPeakMemoryRegressionPercent `
    -Output $reportPath

Write-Host "[compiler emission suite] PASS $($plan.Count)/$($plan.Count) alternating samples and comparison report $reportPath."
