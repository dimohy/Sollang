$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$measurePath = Join-Path $PSScriptRoot "measure-native-exact-batch-profile.ps1"
$showPath = Join-Path $PSScriptRoot "show-native-exact-batch-profile.ps1"
$schemaPath = Join-Path $PSScriptRoot "contracts\native-exact-batch-profile.schema.json"
. (Join-Path $PSScriptRoot "native-exact-process-sample.ps1")
$endedSample = Get-NativeExactProcessSample -Process ([pscustomobject]@{ WorkingSet64 = 42L; TotalProcessorTime = $null })
if ($endedSample.CpuAvailable -or $null -ne $endedSample.CpuMilliseconds -or $endedSample.WorkingSetBytes -ne 42) {
    throw "Unavailable CPU sample was converted into measured CPU"
}
$liveSample = Get-NativeExactProcessSample -Process ([pscustomobject]@{ WorkingSet64 = 42L; TotalProcessorTime = [TimeSpan]::FromMilliseconds(125) })
if (-not $liveSample.CpuAvailable -or $liveSample.CpuMilliseconds -ne 125) { throw "Live CPU sample changed" }
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-native-exact-profile-" + [Guid]::NewGuid().ToString("N"))
$temporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
$ownedTempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $temporaryRoot.StartsWith($ownedTempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [System.IO.Path]::GetFileName($temporaryRoot).StartsWith("sollang-native-exact-profile-", [System.StringComparison]::Ordinal)) {
    throw "native exact profile contract escaped its owned temporary directory"
}
try {
    $llvmRoot = Join-Path $temporaryRoot "llvm"
    $stdlibRoot = Join-Path $temporaryRoot "stdlib"
    $outputRoot = Join-Path $temporaryRoot "output"
    [System.IO.Directory]::CreateDirectory($llvmRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($stdlibRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $compiler = Join-Path $temporaryRoot "compiler.exe"
    [System.IO.File]::WriteAllBytes($compiler, [byte[]](1, 2, 3))
    $successBatch = Join-Path $temporaryRoot "success-batch.ps1"
    $failureBatch = Join-Path $temporaryRoot "failure-batch.ps1"
    $successSource = @'
Start-Sleep -Milliseconds 250
Write-Output "[native exact batch 1/2] PASS alpha."
Write-Output "[native exact] PASS profile windows alpha cached artifacts authenticated and exact execution revalidated."
Write-Output "[native exact batch 2/2] PASS beta."
'@
    $failureSource = @'
Start-Sleep -Milliseconds 250
Write-Output "[native exact batch 1/2] PASS alpha."
Write-Output "[native exact batch 2/2] FAIL beta."
Write-Error "synthetic exact failure"
exit 7
'@
    [System.IO.File]::WriteAllText($successBatch, $successSource, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($failureBatch, $failureSource, [System.Text.UTF8Encoding]::new($false))

    $successProfile = Join-Path $temporaryRoot "success.json"
    & $measurePath `
        -Compiler $compiler `
        -Output $successProfile `
        -Label profile `
        -LlvmRoot $llvmRoot `
        -StdlibRoot $stdlibRoot `
        -RepositoryRoot $repoRoot `
        -OutputDirectory $outputRoot `
        -Jobs 2 `
        -OverallTimeoutMilliseconds 5000 `
        -SampleIntervalMilliseconds 100 `
        -Fixture alpha, beta `
        -BatchScript $successBatch | Out-Null
    $success = Get-Content -LiteralPath $successProfile -Raw | ConvertFrom-Json
    if (-not $success.success -or $success.completedFixtures -ne 2 -or
        $success.totalFixtures -ne 2 -or $success.cacheHitCount -ne 1 -or
        $success.progress.Count -ne 2 -or $success.peakAggregateWorkingSetBytes -le 0) {
        throw "native exact batch success profile lost progress, cache, or process evidence"
    }
    if (-not (Test-Path -LiteralPath "$successProfile.stdout.log" -PathType Leaf) -or
        -not (Test-Path -LiteralPath "$successProfile.stderr.log" -PathType Leaf)) {
        throw "native exact batch success profile did not retain its hashed output logs"
    }
    if (-not ((Get-Content -LiteralPath $successProfile -Raw) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "native exact batch success profile failed schema validation"
    }
    $summary = (& $showPath -Profile $successProfile -Top 1 6>&1 | Out-String)
    if ($summary -notmatch 'completed=2/2' -or
        $summary -notmatch 'Largest no-completion intervals' -or
        $summary -notmatch 'not isolated fixture durations') {
        throw "native exact batch profile summary lost completion or interpretation guidance"
    }

    $failureProfile = Join-Path $temporaryRoot "failure.json"
    $failureObserved = $false
    try {
        & $measurePath `
            -Compiler $compiler `
            -Output $failureProfile `
            -Label profile `
            -LlvmRoot $llvmRoot `
            -StdlibRoot $stdlibRoot `
            -RepositoryRoot $repoRoot `
            -OutputDirectory $outputRoot `
            -Jobs 2 `
            -OverallTimeoutMilliseconds 5000 `
            -SampleIntervalMilliseconds 100 `
            -Fixture alpha, beta `
            -BatchScript $failureBatch | Out-Null
    } catch {
        if ($_.Exception.Message -notmatch 'failed with exit code 7') { throw }
        $failureObserved = $true
    }
    $failure = Get-Content -LiteralPath $failureProfile -Raw | ConvertFrom-Json
    if (-not $failureObserved -or $failure.success -or $failure.exitCode -ne 7 -or
        $failure.completedFixtures -ne 2 -or $failure.progress[1].status -cne "FAIL") {
        throw "native exact batch failure profile was not preserved fail-closed"
    }
    if ((Get-FileHash -LiteralPath "$failureProfile.stderr.log").Hash -cne $failure.stderrFingerprint) {
        throw "Batch failure handling changed its published log hash"
    }

    $faultBatch = Join-Path $temporaryRoot "fault-batch.ps1"
    $faultProfile = Join-Path $temporaryRoot "fault.json"
    [IO.File]::WriteAllText($faultBatch, @'
$start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
foreach ($argument in @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30')) { $start.ArgumentList.Add($argument) }
$child = [Diagnostics.Process]::Start($start)
Write-Output "descendant=$($child.Id)"
Write-Output '[native exact batch 1/2] PASS alpha.'
Start-Sleep -Seconds 30
'@, [Text.UTF8Encoding]::new($false))
    function Get-CimInstance {
        param([string]$ClassName)
        if ([IO.File]::ReadAllText("$faultProfile.stdout.log").Contains('[native exact batch 1/2]')) {
            throw "synthetic sampler failure"
        }
        CimCmdlets\Get-CimInstance -ClassName $ClassName
    }
    $samplerFailureObserved = $false
    try {
        & $measurePath -Compiler $compiler -Output $faultProfile -Label profile `
            -LlvmRoot $llvmRoot -StdlibRoot $stdlibRoot -RepositoryRoot $repoRoot `
            -OutputDirectory $outputRoot -Jobs 2 -OverallTimeoutMilliseconds 5000 `
            -SampleIntervalMilliseconds 100 -Fixture alpha,beta -BatchScript $faultBatch | Out-Null
    } catch {
        if ($_.Exception.Message -notmatch 'synthetic sampler failure') { throw }
        $samplerFailureObserved = $true
    } finally {
        Remove-Item Function:Get-CimInstance
    }
    $checkpoint = Get-Content -LiteralPath "$faultProfile.failure.json" -Raw | ConvertFrom-Json
    $faultLog = [IO.File]::ReadAllText("$faultProfile.stdout.log")
    $childId = [int][regex]::Match($faultLog, 'descendant=(\d+)').Groups[1].Value
    if (-not $samplerFailureObserved -or -not $checkpoint.batchStopped -or
        $checkpoint.completedFixtures -ne 1 -or $childId -le 0 -or
        $null -ne (Get-Process -Id $checkpoint.batchProcessId,$childId -ErrorAction SilentlyContinue)) {
        throw "Sampler failure lost progress or left batch descendants running"
    }
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Host "[native exact batch profile contract] PASS schema, progress, cache, nullable CPU samples, log hashes, and sampler-failure descendant cleanup/checkpoint."
