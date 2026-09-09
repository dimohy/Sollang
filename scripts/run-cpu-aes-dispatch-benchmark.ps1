[CmdletBinding()]
param(
    [string]$SelfhostCompiler = "",
    [string]$ManagedCompilerAssembly = "",
    [string]$LlvmHome = "",
    [ValidateRange(3, 21)]
    [int]$Samples = 7
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SelfhostCompiler)) {
    $SelfhostCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
}
if ([string]::IsNullOrWhiteSpace($ManagedCompilerAssembly)) {
    $ManagedCompilerAssembly = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$fixture = Join-Path $repoRoot "benchmarks\cpu-aes\runner.slg"
$expectedPath = Join-Path $repoRoot "benchmarks\cpu-aes\expected.txt"
$artifacts = Join-Path $repoRoot "artifacts\cpu-aes-benchmark"
$differential = Join-Path $PSScriptRoot "verify-cpu-aes-dispatch-differential.ps1"

& $differential `
    -SelfhostCompiler $SelfhostCompiler `
    -ManagedCompilerAssembly $ManagedCompilerAssembly `
    -LlvmHome $LlvmHome `
    -Fixture $fixture `
    -ExpectedPath $expectedPath `
    -ArtifactDirectory $artifacts `
    -CaseCount 1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not [System.Runtime.Intrinsics.X86.Aes]::IsSupported) {
    throw "CPU AES benchmark requires AES-NI to execute the forced x64 AES-NI path"
}

$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
$maximumX86ToPortableRatio = 0.90
$maximumX86ToPortablePeakMemoryRatio = 1.05
$maximumX86PeakWorkingSetBytes = 16MB
$results = [ordered]@{}
foreach ($backend in @("managed", "selfhost")) {
    $executables = [ordered]@{
        portable = Join-Path $artifacts "$backend-portable.exe"
        x86 = Join-Path $artifacts "$backend-x86.exe"
    }
    foreach ($mode in $executables.Keys) {
        if (-not (Test-Path -LiteralPath $executables[$mode] -PathType Leaf)) {
            throw "CPU AES benchmark executable is missing: $($executables[$mode])"
        }
        $warmup = Invoke-VerificationProcessCapture `
            -FilePath $executables[$mode] `
            -Description "$backend CPU AES $mode benchmark warmup"
        if ($warmup.ExitCode -ne 0 -or $warmup.Stdout.Replace("`r`n", "`n").TrimEnd("`n") -ne $expected) {
            throw "$backend CPU AES $mode benchmark warmup failed"
        }
    }

    $timings = [ordered]@{
        portable = [Collections.Generic.List[double]]::new()
        x86 = [Collections.Generic.List[double]]::new()
    }
    $peakWorkingSets = [ordered]@{
        portable = [Collections.Generic.List[long]]::new()
        x86 = [Collections.Generic.List[long]]::new()
    }
    for ($sample = 0; $sample -lt $Samples; $sample++) {
        $order = if ($sample % 2 -eq 0) { @("portable", "x86") } else { @("x86", "portable") }
        foreach ($mode in $order) {
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $run = Invoke-VerificationProcessCapture `
                -FilePath $executables[$mode] `
                -Description "$backend CPU AES $mode benchmark sample $($sample + 1)" `
                -CapturePeakWorkingSet
            $watch.Stop()
            $actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
            if ($run.ExitCode -ne 0 -or $actual -ne $expected) {
                throw "$backend CPU AES $mode benchmark sample $($sample + 1) failed"
            }
            $timings[$mode].Add($watch.Elapsed.TotalMilliseconds)
            $peakWorkingSets[$mode].Add($run.PeakWorkingSet64)
        }
    }

    $portableSorted = @($timings.portable | Sort-Object)
    $x86Sorted = @($timings.x86 | Sort-Object)
    $middle = [int][Math]::Floor($Samples / 2)
    $portableMedian = $portableSorted[$middle]
    $x86Median = $x86Sorted[$middle]
    $ratio = $x86Median / $portableMedian
    $portablePeak = ($peakWorkingSets.portable | Measure-Object -Maximum).Maximum
    $x86Peak = ($peakWorkingSets.x86 | Measure-Object -Maximum).Maximum
    $peakMemoryRatio = $x86Peak / $portablePeak
    $results[$backend] = [ordered]@{
        portableMs = @($timings.portable)
        x86Ms = @($timings.x86)
        portableMedianMs = $portableMedian
        x86MedianMs = $x86Median
        x86ToPortableRatio = $ratio
        maximumAcceptedRatio = $maximumX86ToPortableRatio
        portablePeakWorkingSetBytes = @($peakWorkingSets.portable)
        x86PeakWorkingSetBytes = @($peakWorkingSets.x86)
        portableMaximumPeakWorkingSetBytes = $portablePeak
        x86MaximumPeakWorkingSetBytes = $x86Peak
        x86ToPortablePeakMemoryRatio = $peakMemoryRatio
        maximumAcceptedPeakMemoryRatio = $maximumX86ToPortablePeakMemoryRatio
        maximumAcceptedX86PeakWorkingSetBytes = $maximumX86PeakWorkingSetBytes
        passed = $ratio -le $maximumX86ToPortableRatio `
            -and $peakMemoryRatio -le $maximumX86ToPortablePeakMemoryRatio `
            -and $x86Peak -le $maximumX86PeakWorkingSetBytes
        portableSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $executables.portable).Hash
        x86Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $executables.x86).Hash
    }
}

$report = [ordered]@{
    schemaVersion = 2
    generatedAtUtc = [DateTime]::UtcNow.ToString("O", [Globalization.CultureInfo]::InvariantCulture)
    target = [ordered]@{
        requested = "windows-x64"
        llvmTriple = "x86_64-pc-windows-msvc"
        executableFormat = "PE32+"
        machine = "AMD64"
        acceleratedPath = "x64 AES-NI"
        internalSymbolSuffix = "x86"
    }
    workload = "200000 prepared-key AES-128 block encryptions"
    samplesPerMode = $Samples
    ordering = "alternating portable/x86"
    output = $expected
    results = $results
}
$reportPath = Join-Path $artifacts "report.json"
[System.IO.File]::WriteAllText(
    $reportPath,
    ($report | ConvertTo-Json -Depth 8) + [Environment]::NewLine)

$failed = @($results.GetEnumerator() | Where-Object { -not $_.Value.passed })
foreach ($backend in $results.Keys) {
    $result = $results[$backend]
    Write-Host ("[CPU AES benchmark] {0} windows-x64: portable={1:N3} ms, x64-AES-NI={2:N3} ms, time-ratio={3:N3}, peak-memory-ratio={4:N3}" -f `
        $backend,
        $result.portableMedianMs,
        $result.x86MedianMs,
        $result.x86ToPortableRatio,
        $result.x86ToPortablePeakMemoryRatio)
}
if ($failed.Count -gt 0) {
    throw "CPU AES x64 AES-NI path exceeded the frozen 0.90 time ratio, 1.05 peak-memory ratio, or 16 MiB absolute peak; see $reportPath"
}

Write-Host "[CPU AES benchmark] PASS windows-x64 PE32+ on both backends under frozen AES-NI/portable time 0.90, peak-memory 1.05, and AES-NI absolute 16 MiB limits; report $reportPath"
