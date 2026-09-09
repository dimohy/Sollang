[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Output,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$StdlibRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 64)][int]$Jobs = 16,
    [ValidateRange(1, 64)][int]$MinimumCompilerJobs = 1,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 3600000,
    [ValidateRange(1000, 86400000)][int]$OverallTimeoutMilliseconds = 21600000,
    [ValidateRange(100, 60000)][int]$SampleIntervalMilliseconds = 1000,
    [string[]]$Fixture = @(),
    [string]$BatchScript = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $IsWindows) {
    throw "native exact batch profiling is Windows-only"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot "native-exact-process-sample.ps1")
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmPath = (Resolve-Path -LiteralPath $LlvmRoot).Path
$stdlibPath = (Resolve-Path -LiteralPath $StdlibRoot).Path
$batchPath = if ([string]::IsNullOrWhiteSpace($BatchScript)) {
    Join-Path $scriptRoot "verify-native-exact-fixture-batch.ps1"
} else {
    (Resolve-Path -LiteralPath $BatchScript).Path
}
$exactVerifierPath = Join-Path $scriptRoot "verify-native-exact-fixture.ps1"
$schemaPath = Join-Path $scriptRoot "contracts\native-exact-batch-profile.schema.json"
$profilePath = [System.IO.Path]::GetFullPath($Output)
$stdoutLogPath = "$profilePath.stdout.log"
$stderrLogPath = "$profilePath.stderr.log"
$artifactRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
foreach ($required in @($compilerPath, $batchPath, $exactVerifierPath, $schemaPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "native exact batch profile input is missing: $required"
    }
}
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($profilePath)) | Out-Null
[System.IO.Directory]::CreateDirectory($artifactRoot) | Out-Null

function Get-TextSha256 {
    param([AllowEmptyString()][string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

$arguments = [System.Collections.Generic.List[string]]::new()
foreach ($argument in @(
    "-NoProfile", "-File", $batchPath,
    "-Compiler", $compilerPath,
    "-Label", $Label,
    "-Platform", "windows",
    "-LlvmRoot", $llvmPath,
    "-StdlibRoot", $stdlibPath,
    "-RepositoryRoot", $repoRoot,
    "-OutputDirectory", $artifactRoot,
    "-Jobs", [string]$Jobs,
    "-MinimumCompilerJobs", [string]$MinimumCompilerJobs,
    "-TimeoutMilliseconds", [string]$TimeoutMilliseconds)) {
    $arguments.Add($argument)
}
if ($Fixture.Count -gt 0) {
    $arguments.Add("-Fixture")
    foreach ($fixtureName in $Fixture) { $arguments.Add($fixtureName) }
}

$invocationIdentity = @(
    "profile-v1",
    "platform=windows",
    "label=$Label",
    "jobs=$Jobs",
    "minimumCompilerJobs=$MinimumCompilerJobs",
    "timeoutMilliseconds=$TimeoutMilliseconds",
    "overallTimeoutMilliseconds=$OverallTimeoutMilliseconds",
    "profiler=$((Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash)",
    "sampler=$((Get-FileHash -LiteralPath (Join-Path $scriptRoot 'native-exact-process-sample.ps1') -Algorithm SHA256).Hash)",
    "compiler=$((Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash)",
    "batch=$((Get-FileHash -LiteralPath $batchPath -Algorithm SHA256).Hash)",
    "verifier=$((Get-FileHash -LiteralPath $exactVerifierPath -Algorithm SHA256).Hash)",
    "fixtures=$($Fixture -join ',')") -join "`n"

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = (Get-Process -Id $PID).Path
$startInfo.WorkingDirectory = $repoRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in $arguments) { [void]$startInfo.ArgumentList.Add($argument) }

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$startedUtc = [DateTimeOffset]::UtcNow
[long]$peakAggregateWorkingSetBytes = 0
[int]$maximumObservedProcessCount = 0
$cpuMillisecondsByProcess = [System.Collections.Generic.Dictionary[int, long]]::new()
$stdoutRead = $null
$stderrRead = $null
$stdoutClosed = $false
$stderrClosed = $false
$stdoutLines = [System.Collections.Generic.List[string]]::new()
$stderrLines = [System.Collections.Generic.List[string]]::new()
$progress = [System.Collections.Generic.List[object]]::new()
$timedOut = $false
$processStarted = $false
$unavailableCpuSamples = 0
$profilePublished = $false
[System.IO.File]::WriteAllText($stdoutLogPath, "", [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($stderrLogPath, "", [System.Text.UTF8Encoding]::new($false))
try {
    if (-not $process.Start()) { throw "native exact batch profile could not start" }
    $processStarted = $true
    $stdoutRead = $process.StandardOutput.ReadLineAsync()
    $stderrRead = $process.StandardError.ReadLineAsync()
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($OverallTimeoutMilliseconds)
    $nextSample = [DateTimeOffset]::UtcNow
    do {
        if (-not $stdoutClosed -and $stdoutRead.IsCompleted) {
            $line = $stdoutRead.GetAwaiter().GetResult()
            if ($null -eq $line) {
                $stdoutClosed = $true
            } else {
                $stdoutLines.Add($line)
                [System.IO.File]::AppendAllText($stdoutLogPath, "$line`n", [System.Text.UTF8Encoding]::new($false))
                # Preserve the batch's live completion stream for the operator;
                # the same line is also retained below in the durable profile.
                Write-Host $line
                $match = [regex]::Match($line, '^\[native exact batch (?<completed>\d+)/(?<total>\d+)\] (?<status>PASS|FAIL) (?<fixture>[^.\r\n]+)\.$')
                if ($match.Success) {
                    $progress.Add([ordered]@{
                        completed = [int]$match.Groups['completed'].Value
                        total = [int]$match.Groups['total'].Value
                        status = $match.Groups['status'].Value
                        fixture = $match.Groups['fixture'].Value
                        elapsedMilliseconds = [long]$stopwatch.ElapsedMilliseconds
                    })
                }
                $stdoutRead = $process.StandardOutput.ReadLineAsync()
            }
        }
        if (-not $stderrClosed -and $stderrRead.IsCompleted) {
            $line = $stderrRead.GetAwaiter().GetResult()
            if ($null -eq $line) {
                $stderrClosed = $true
            } else {
                $stderrLines.Add($line)
                [System.IO.File]::AppendAllText($stderrLogPath, "$line`n", [System.Text.UTF8Encoding]::new($false))
                $stderrRead = $process.StandardError.ReadLineAsync()
            }
        }
        if ([DateTimeOffset]::UtcNow -ge $nextSample) {
            $records = @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId)
            $processIds = [System.Collections.Generic.HashSet[int]]::new()
            [void]$processIds.Add($process.Id)
            $frontier = @($process.Id)
            while ($frontier.Count -gt 0) {
                $children = @($records | Where-Object { $frontier -contains [int]$_.ParentProcessId })
                $frontier = @()
                foreach ($child in $children) {
                    $childId = [int]$child.ProcessId
                    if ($processIds.Add($childId)) { $frontier += $childId }
                }
            }
            [long]$aggregateWorkingSetBytes = 0
            foreach ($processId in $processIds) {
                $observed = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if ($null -eq $observed) { continue }
                try {
                    $sample = Get-NativeExactProcessSample -Process $observed
                    $aggregateWorkingSetBytes += [long]$sample.WorkingSetBytes
                    if (-not $sample.CpuAvailable) {
                        $unavailableCpuSamples += 1
                        continue
                    }
                    $cpuMilliseconds = $sample.CpuMilliseconds
                    if (-not $cpuMillisecondsByProcess.ContainsKey($processId) -or
                        $cpuMilliseconds -gt $cpuMillisecondsByProcess[$processId]) {
                        $cpuMillisecondsByProcess[$processId] = $cpuMilliseconds
                    }
                } finally {
                    $observed.Dispose()
                }
            }
            $peakAggregateWorkingSetBytes = [Math]::Max($peakAggregateWorkingSetBytes, $aggregateWorkingSetBytes)
            $maximumObservedProcessCount = [Math]::Max($maximumObservedProcessCount, $processIds.Count)
            $nextSample = [DateTimeOffset]::UtcNow.AddMilliseconds($SampleIntervalMilliseconds)
        }
        $processExited = $process.HasExited
        if ($processExited -and $stdoutClosed -and $stderrClosed) { break }
        if ([DateTimeOffset]::UtcNow -ge $deadline) {
            $timedOut = $true
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
            $deadline = [DateTimeOffset]::MaxValue
        }
        Start-Sleep -Milliseconds 10
    } while ($true)
    $process.WaitForExit()
    $stopwatch.Stop()
    $stdout = if ($stdoutLines.Count -eq 0) { "" } else { ($stdoutLines -join "`n") + "`n" }
    $stderr = if ($stderrLines.Count -eq 0) { "" } else { ($stderrLines -join "`n") + "`n" }
    [System.IO.File]::WriteAllText($stdoutLogPath, $stdout, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($stderrLogPath, $stderr, [System.Text.UTF8Encoding]::new($false))
    [long]$hostVisibleCpuMilliseconds = 0
    foreach ($value in $cpuMillisecondsByProcess.Values) { $hostVisibleCpuMilliseconds += $value }
    if ($peakAggregateWorkingSetBytes -le 0 -or $maximumObservedProcessCount -le 0) {
        throw "native exact batch profile completed without observable process-tree memory evidence"
    }

    $completedFixtures = if ($progress.Count -eq 0) { 0 } else { $progress[$progress.Count - 1].completed }
    $totalFixtures = if ($progress.Count -eq 0) { 0 } else { $progress[$progress.Count - 1].total }
    $cacheHitCount = ([regex]::Matches($stdout, 'cached artifacts authenticated and exact execution revalidated\.')).Count
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    $profile = [ordered]@{
        schemaVersion = 1
        measurement = "windows-host-visible-process-tree-and-completion-timeline"
        platform = "windows"
        label = $Label
        startedUtc = $startedUtc.ToString("O")
        endedUtc = [DateTimeOffset]::UtcNow.ToString("O")
        wallMilliseconds = [long]$stopwatch.ElapsedMilliseconds
        sampleIntervalMilliseconds = $SampleIntervalMilliseconds
        perFixtureTimeoutMilliseconds = $TimeoutMilliseconds
        overallTimeoutMilliseconds = $OverallTimeoutMilliseconds
        hostVisibleCpuMilliseconds = $hostVisibleCpuMilliseconds
        unavailableCpuSamples = $unavailableCpuSamples
        peakAggregateWorkingSetBytes = $peakAggregateWorkingSetBytes
        maximumObservedProcessCount = $maximumObservedProcessCount
        workerBudget = $Jobs
        minimumCompilerJobs = $MinimumCompilerJobs
        compilerFingerprint = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
        batchScriptFingerprint = (Get-FileHash -LiteralPath $batchPath -Algorithm SHA256).Hash
        exactVerifierFingerprint = (Get-FileHash -LiteralPath $exactVerifierPath -Algorithm SHA256).Hash
        invocationFingerprint = Get-TextSha256 $invocationIdentity
        exitCode = $exitCode
        success = (-not $timedOut -and $exitCode -eq 0)
        completedFixtures = $completedFixtures
        totalFixtures = $totalFixtures
        cacheHitCount = $cacheHitCount
        progress = $progress.ToArray()
        stdoutFingerprint = Get-TextSha256 $stdout
        stderrFingerprint = Get-TextSha256 $stderr
        stdoutLogFile = [System.IO.Path]::GetFileName($stdoutLogPath)
        stderrLogFile = [System.IO.Path]::GetFileName($stderrLogPath)
    }
    $json = ($profile | ConvertTo-Json -Depth 8) + "`n"
    if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "native exact batch profile does not match its schema"
    }
    $temporaryProfile = "$profilePath.tmp-$([Guid]::NewGuid().ToString('N'))"
    [System.IO.File]::WriteAllText($temporaryProfile, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryProfile -Destination $profilePath -Force
    $profilePublished = $true
    Write-Host $json.TrimEnd()
    if ($timedOut) { throw "native exact batch profile exceeded $OverallTimeoutMilliseconds milliseconds; partial profile written to $profilePath" }
    if ($exitCode -ne 0) { throw "native exact batch failed with exit code $exitCode; profile written to $profilePath`n$stderr" }
    Write-Host "[native exact batch profile] PASS Windows profile written to $profilePath."
} catch {
    $failure = $_
    if ($processStarted -and -not $process.HasExited) {
        $process.Kill($true)
        if (-not $process.WaitForExit(5000)) { throw "Profiler failed and its batch did not stop: $($process.Id)" }
    }
    $stopwatch.Stop()
    if (-not $profilePublished) {
        [System.IO.File]::WriteAllText($stdoutLogPath, ($stdoutLines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($stderrLogPath, ($stderrLines -join "`n") + "`n$($failure.Exception.Message)`n", [System.Text.UTF8Encoding]::new($false))
        $checkpoint = [ordered]@{
            schemaVersion = 1
            failureKind = "profiler"
            message = $failure.Exception.Message
            batchProcessId = if ($processStarted) { $process.Id } else { $null }
            batchStopped = -not $processStarted -or $process.HasExited
            wallMilliseconds = [long]$stopwatch.ElapsedMilliseconds
            completedFixtures = if ($progress.Count) { $progress[$progress.Count - 1].completed } else { 0 }
            totalFixtures = if ($progress.Count) { $progress[$progress.Count - 1].total } else { 0 }
            unavailableCpuSamples = $unavailableCpuSamples
            progress = $progress.ToArray()
        }
        [System.IO.File]::WriteAllText("$profilePath.failure.json", ($checkpoint | ConvertTo-Json -Depth 8) + "`n", [System.Text.UTF8Encoding]::new($false))
    }
    throw $failure
} finally {
    $process.Dispose()
}
