$script:VerificationCancellationRequestPath = ''
$script:VerificationCancellationRunId = ''
$script:VerificationCancellationAcknowledgementPath = ''

function Initialize-VerificationCancellation {
    param(
        [Parameter(Mandatory)][string]$RequestPath,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$AcknowledgementPath
    )
    $script:VerificationCancellationRequestPath = [IO.Path]::GetFullPath($RequestPath)
    $script:VerificationCancellationRunId = $RunId
    $script:VerificationCancellationAcknowledgementPath = [IO.Path]::GetFullPath($AcknowledgementPath)
}

function Test-VerificationCancellationRequested {
    if ([string]::IsNullOrWhiteSpace([string]$script:VerificationCancellationRequestPath) -or
        -not (Test-Path -LiteralPath $script:VerificationCancellationRequestPath -PathType Leaf)) {
        return $false
    }
    $request = Get-Content -LiteralPath $script:VerificationCancellationRequestPath -Raw | ConvertFrom-Json
    if ($request.schemaVersion -ne 1 -or $request.runId -cne $script:VerificationCancellationRunId -or
        [string]::IsNullOrWhiteSpace([string]$request.requestedAtUtc)) {
        throw 'Cancellation request does not match the active verification target'
    }
    if (-not (Test-Path -LiteralPath $script:VerificationCancellationAcknowledgementPath -PathType Leaf)) {
        $identity = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
            [Text.Encoding]::UTF8.GetBytes($script:VerificationCancellationAcknowledgementPath.ToUpperInvariant())))
        $publicationLock = [Threading.Mutex]::new($false, "SollangVerificationAcknowledgement-$identity")
        $lockOwned = $false
        try {
            try { $lockOwned = $publicationLock.WaitOne(5000) }
            catch [Threading.AbandonedMutexException] { $lockOwned = $true }
            if (-not $lockOwned) { throw 'Cancellation acknowledgement publication timed out' }
            # Recheck under the shared lock: another worker may have published first.
            if (-not (Test-Path -LiteralPath $script:VerificationCancellationAcknowledgementPath -PathType Leaf)) {
                $acknowledgement = [ordered]@{
                    schemaVersion = 1
                    runId = $script:VerificationCancellationRunId
                    targetProcessId = $PID
                    observedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
                }
                $temporaryPath = "$($script:VerificationCancellationAcknowledgementPath).tmp-$PID-$([guid]::NewGuid().ToString('N'))"
                $acknowledgement | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
                [IO.File]::Move($temporaryPath, $script:VerificationCancellationAcknowledgementPath)
            }
        } finally {
            if ($lockOwned) { $publicationLock.ReleaseMutex() }
            $publicationLock.Dispose()
        }
    }
    return $true
}

function Assert-VerificationCancellationNotRequested {
    if (Test-VerificationCancellationRequested) {
        throw [OperationCanceledException]::new('CANCELLATION_REQUESTED')
    }
}

function Get-VerificationProcessTreeSnapshot {
    param([Parameter(Mandatory)][int]$RootProcessId)

    $processIds = [System.Collections.Generic.HashSet[int]]::new()
    [void]$processIds.Add($RootProcessId)
    if ($IsWindows) {
        $processRecords = @(Get-CimInstance Win32_Process)
        $frontier = @($RootProcessId)
        while ($frontier.Count -gt 0) {
            $children = @($processRecords | Where-Object { $frontier -contains [int]$_.ParentProcessId })
            $frontier = @()
            foreach ($child in $children) {
                $childId = [int]$child.ProcessId
                if ($processIds.Add($childId)) {
                    $frontier += $childId
                }
            }
        }
    }

    [double]$cpuSeconds = 0
    [long]$workingBytes = 0
    [int]$observedProcesses = 0
    foreach ($processId in $processIds) {
        $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($null -eq $process) {
            continue
        }
        try {
            try {
                $observedProcessorTime = $process.TotalProcessorTime
                if ($null -eq $observedProcessorTime) {
                    # An exiting Windows process may no longer expose a CPU
                    # counter even while its process record is still visible.
                    continue
                }
                [TimeSpan]$processorTime = $observedProcessorTime
                $cpuSeconds += [double]$processorTime.Ticks / [TimeSpan]::TicksPerSecond
                $workingBytes += $process.WorkingSet64
                $observedProcesses += 1
            } catch [InvalidOperationException] {
                # A process may exit after Get-Process succeeds and before its
                # counters are read. Exited members contribute no live sample.
                continue
            } catch [System.ComponentModel.Win32Exception] {
                continue
            }
        } finally {
            $process.Dispose()
        }
    }
    [pscustomobject]@{
        CpuSeconds = [double]$cpuSeconds
        WorkingMiB = [int]($workingBytes / 1MB)
        ProcessCount = $observedProcesses
    }
}

function Wait-VerificationProcess {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$Description,
        [int]$TimeoutMilliseconds = 3600000,
        [System.Collections.Generic.List[long]]$PeakWorkingSetSamples = $null,
        [ValidateRange(10, 3600000)]
        [int]$TelemetryIntervalMilliseconds = 60000,
        [DateTimeOffset]$TimeoutStartedAt = [DateTimeOffset]::MinValue
    )

    if ($TimeoutMilliseconds -le 0) {
        throw "Verification timeout must be positive for '$Description'"
    }
    $startedAt = if ($TimeoutStartedAt -eq [DateTimeOffset]::MinValue) {
        [DateTimeOffset]::Now
    } else {
        $TimeoutStartedAt
    }
    $deadline = $startedAt.AddMilliseconds($TimeoutMilliseconds)
    $nextTelemetryAt = $startedAt.AddMilliseconds($TelemetryIntervalMilliseconds)
    $previousTelemetryAt = $startedAt
    $previousTree = $null
    while ([DateTimeOffset]::Now -lt $deadline) {
        $cancellationObserved = Test-VerificationCancellationRequested
        $remaining = [int][Math]::Max(1, ($deadline - [DateTimeOffset]::Now).TotalMilliseconds)
        # A completed Windows Process can report zero for PeakWorkingSet64.
        # Callers requesting memory evidence therefore sample the live process
        # at a bounded cadence instead of reading a stale post-exit property.
        if ($null -ne $PeakWorkingSetSamples) {
            $Process.Refresh()
            $observedPeak = [Math]::Max($Process.WorkingSet64, $Process.PeakWorkingSet64)
            if ($PeakWorkingSetSamples.Count -eq 0) {
                $PeakWorkingSetSamples.Add([long]$observedPeak)
            } elseif ($observedPeak -gt $PeakWorkingSetSamples[0]) {
                $PeakWorkingSetSamples[0] = [long]$observedPeak
            }
        }
        $maximumWaitSlice = if (-not [string]::IsNullOrWhiteSpace([string]$script:VerificationCancellationRequestPath)) {
            [Math]::Min(100, $TelemetryIntervalMilliseconds)
        } elseif ($null -ne $PeakWorkingSetSamples) {
            [Math]::Min(5, $TelemetryIntervalMilliseconds)
        } else {
            [Math]::Min(60000, $TelemetryIntervalMilliseconds)
        }
        $waitSlice = [Math]::Min($maximumWaitSlice, $remaining)
        if ($Process.WaitForExit($waitSlice)) {
            if ($cancellationObserved -or (Test-VerificationCancellationRequested)) {
                throw [OperationCanceledException]::new('CANCELLATION_REQUESTED')
            }
            return
        }
        if ($cancellationObserved) {
            # A cancellation request stops new work. The active child is allowed
            # to reach its own safe terminal boundary; cancellation never turns
            # into raw process termination here.
            while (-not $Process.WaitForExit([Math]::Min(1000, $waitSlice))) { }
            throw [OperationCanceledException]::new('CANCELLATION_REQUESTED')
        }
        $observedAt = [DateTimeOffset]::Now
        $elapsed = $observedAt - $startedAt
        if ($observedAt -ge $nextTelemetryAt) {
            $tree = Get-VerificationProcessTreeSnapshot -RootProcessId $Process.Id
            $telemetryInterval = if ($null -eq $previousTelemetryAt) {
                [TimeSpan]::Zero
            } else {
                $observedAt - [DateTimeOffset]$previousTelemetryAt
            }
            if ($null -eq $telemetryInterval) {
                $telemetryInterval = [TimeSpan]::Zero
            }
            $intervalSeconds = [Math]::Max(0.001, [double]$telemetryInterval.Ticks / [TimeSpan]::TicksPerSecond)
            $intervalActivity = if ($null -ne $previousTree -and
                ($tree.ProcessCount -ne $previousTree.ProcessCount -or $tree.CpuSeconds -lt $previousTree.CpuSeconds)) {
                "process tree changed; interval CPU baseline reset"
            } else {
                $previousCpuSeconds = if ($null -eq $previousTree) { 0.0 } else { $previousTree.CpuSeconds }
                $intervalCpuSeconds = [Math]::Max(0.0, $tree.CpuSeconds - $previousCpuSeconds)
                $effectiveCores = $intervalCpuSeconds / $intervalSeconds
                "host-visible interval +{0:N1}s CPU ({1:N1} effective cores)" -f $intervalCpuSeconds, $effectiveCores
            }
            Write-Host ("[verification wait] {0} active for {1:hh\:mm\:ss}; {2}; host-visible total {3:N0}s CPU; memory {4:N0} MiB; processes {5:N0}." -f `
                $Description, $elapsed, $intervalActivity, $tree.CpuSeconds, $tree.WorkingMiB, $tree.ProcessCount)
            $previousTelemetryAt = $observedAt
            $previousTree = $tree
            $nextTelemetryAt = $observedAt.AddMilliseconds($TelemetryIntervalMilliseconds)
        }
    }

    $Process.Refresh()
    if ($Process.WaitForExit(0)) {
        return
    }

    $actualElapsed = [DateTimeOffset]::Now - $startedAt
    $configuredLimit = [TimeSpan]::FromMilliseconds($TimeoutMilliseconds)
    $timeoutSummary = "configured verification limit {0:hh\:mm\:ss} ({1} ms) after {2:hh\:mm\:ss\.fff} actual elapsed" -f `
        $configuredLimit, $TimeoutMilliseconds, $actualElapsed
    $terminationFailure = $null
    try {
        $Process.Kill($true)
    } catch {
        $terminationFailure = $_.Exception.Message
        try {
            $Process.Kill()
        } catch {
            $terminationFailure += "; direct-process fallback failed: $($_.Exception.Message)"
        }
    }
    if (-not $Process.WaitForExit(5000)) {
        throw "$Description exceeded the $timeoutSummary and its process tree did not terminate within the 5000 ms termination grace period"
    }
    if ($terminationFailure) {
        throw "$Description exceeded the $timeoutSummary; tree termination required a direct-process fallback: $terminationFailure"
    }
    throw "$Description exceeded the $timeoutSummary; process tree terminated within the 5000 ms grace period"
}

function Publish-VerificationFailureArtifacts {
    param(
        [Parameter(Mandatory)][string]$TemporaryOutputPath,
        [Parameter(Mandatory)][string]$TemporaryErrorPath,
        [Parameter(Mandatory)][string]$PartialOutputPath,
        [Parameter(Mandatory)][string]$ErrorOutputPath
    )

    if (Test-Path -LiteralPath $TemporaryErrorPath) {
        Move-Item -LiteralPath $TemporaryErrorPath -Destination $ErrorOutputPath -Force
    }
    if ((Test-Path -LiteralPath $TemporaryOutputPath) -and
        (Get-Item -LiteralPath $TemporaryOutputPath).Length -gt 0) {
        Move-Item -LiteralPath $TemporaryOutputPath -Destination $PartialOutputPath -Force
    }
}

function Invoke-VerificationProcessToFile {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$ErrorPath,
        [int]$TimeoutMilliseconds = 3600000
    )

    $outputDirectory = Split-Path -Parent $OutputPath
    $temporaryOutput = Join-Path $outputDirectory ([System.IO.Path]::GetRandomFileName())
    $temporaryError = Join-Path $outputDirectory ([System.IO.Path]::GetRandomFileName())
    $partialOutput = "$OutputPath.partial"
    if (Test-Path -LiteralPath $partialOutput) {
        Remove-Item -LiteralPath $partialOutput -Force
    }

    $process = $null
    try {
        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $ArgumentList `
            -RedirectStandardOutput $temporaryOutput `
            -RedirectStandardError $temporaryError `
            -PassThru `
            -WindowStyle Hidden
        Wait-VerificationProcess `
            -Process $process `
            -Description $Description `
            -TimeoutMilliseconds $TimeoutMilliseconds
        # The bounded wait proves termination. This immediate wait lets the
        # redirected handles finish draining before files are promoted.
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            $standardOutput = if (Test-Path -LiteralPath $temporaryOutput) {
                [System.IO.File]::ReadAllText($temporaryOutput)
            } else { "" }
            $standardError = if (Test-Path -LiteralPath $temporaryError) {
                [System.IO.File]::ReadAllText($temporaryError)
            } else { "" }
            $details = ($standardError + $standardOutput).Trim()
            throw "$Description failed with exit code $($process.ExitCode).`n$details"
        }
        Move-Item -LiteralPath $temporaryOutput -Destination $OutputPath -Force
        Move-Item -LiteralPath $temporaryError -Destination $ErrorPath -Force
    } catch {
        $originalInvokeError = $_
        try {
            Publish-VerificationFailureArtifacts `
                -TemporaryOutputPath $temporaryOutput `
                -TemporaryErrorPath $temporaryError `
                -PartialOutputPath $partialOutput `
                -ErrorOutputPath $ErrorPath
        } catch {
            throw "$($originalInvokeError.Exception.Message)`nFailure artifact preservation also failed: $($_.Exception.Message)"
        }
        throw $originalInvokeError
    } finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
        if (Test-Path -LiteralPath $temporaryOutput) {
            Remove-Item -LiteralPath $temporaryOutput -Force
        }
        if (Test-Path -LiteralPath $temporaryError) {
            Remove-Item -LiteralPath $temporaryError -Force
        }
    }
}

function Write-VerificationExecutionRecord {
    param([Parameter(Mandatory)][string]$Path,
          [Parameter(Mandatory)][System.Collections.IDictionary]$Record)
    $temporary = "$Path.tmp-$PID-$([Guid]::NewGuid().ToString('N'))"
    [IO.File]::WriteAllText($temporary, ($Record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    # Windows readers can briefly deny replacement even after the child exited.
    # Retry only publication, with a fixed budget; never rerun the child or lose
    # its complete terminal snapshot when replacement remains unavailable.
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            [IO.File]::Move($temporary, $Path, $true)
            break
        } catch {
            $cause = $_.Exception
            while ($null -ne $cause.InnerException) { $cause = $cause.InnerException }
            $code = $cause.HResult -band 0xFFFF
            $retryable = $code -in @(5, 32, 33) -and [IO.File]::Exists($temporary) -and
                [IO.File]::Exists($Path) -and
                (([IO.File]::GetAttributes($Path) -band [IO.FileAttributes]::ReadOnly) -eq 0)
            if (-not $retryable -or $attempt -ge 6) {
                throw [IO.IOException]::new("VERIFICATION_RECORD_PUBLISH_FAILED: path=$Path attempts=$attempt win32=$code pending=$temporary", $cause)
            }
            [Threading.Thread]::Sleep([int](10 * [Math]::Pow(2, $attempt - 1)))
        }
    }
    if ($attempt -gt 1) {
        $audit = [ordered]@{ schemaVersion = 1; status = 'published'; attempts = $attempt
            path = $Path; pendingSnapshot = $temporary; childRerun = $false }
        try {
            [IO.File]::WriteAllText("$temporary.publication.json", ($audit | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
        } catch {
            throw [IO.IOException]::new("VERIFICATION_RECORD_PUBLICATION_AUDIT_FAILED: published=$Path attempts=$attempt", $_.Exception)
        }
    }
}

function Invoke-VerificationProcessCapture {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$Description,
        [string]$WorkingDirectory = "",
        [string]$StandardInputPath = "",
        [int]$TimeoutMilliseconds = 3600000,
        [switch]$CapturePeakWorkingSet,
        [string]$ExecutionRecordPath = ""
    )

    $executionRecord = $null
    if (-not [string]::IsNullOrWhiteSpace($ExecutionRecordPath)) {
        $ExecutionRecordPath = [IO.Path]::GetFullPath($ExecutionRecordPath)
        if (-not [IO.Directory]::Exists([IO.Path]::GetDirectoryName($ExecutionRecordPath))) {
            throw 'VERIFICATION_EXECUTION_RECORD_PARENT_MISSING'
        }
        foreach ($path in @($ExecutionRecordPath, "$ExecutionRecordPath.stdout.log", "$ExecutionRecordPath.stderr.log")) {
            if ([IO.File]::Exists($path) -or [IO.Directory]::Exists($path)) {
                throw 'VERIFICATION_EXECUTION_RECORD_ALREADY_EXISTS'
            }
        }
        $executionRecord = [ordered]@{
            schemaVersion = 1; status = 'starting'; pid = $null
            command = @($FilePath) + @($ArgumentList); description = $Description
            startedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
            finishedAtUtc = $null; exit = $null; processesStopped = $false
            stdoutPath = "$ExecutionRecordPath.stdout.log"
            stderrPath = "$ExecutionRecordPath.stderr.log"; failure = $null
        }
        Write-VerificationExecutionRecord -Path $ExecutionRecordPath -Record $executionRecord
    }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    # Sollang and its verification toolchain emit UTF-8.  ProcessStartInfo
    # otherwise inherits the host console code page, which can decode the same
    # redirected bytes differently in a profile/no-profile child process.
    $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $startInfo.WorkingDirectory = $WorkingDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($StandardInputPath)) {
        $startInfo.RedirectStandardInput = $true
    }
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw "$Description could not start '$FilePath'"
        }
        if ($null -ne $executionRecord) {
            $executionRecord.pid = $process.Id
            $executionRecord.status = 'running'
            Write-VerificationExecutionRecord -Path $ExecutionRecordPath -Record $executionRecord
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not [string]::IsNullOrWhiteSpace($StandardInputPath)) {
            $input = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $StandardInputPath).Path)
            try {
                $input.CopyTo($process.StandardInput.BaseStream)
            } finally {
                $input.Dispose()
                $process.StandardInput.Close()
            }
        }
        $peakWorkingSetSamples = $null
        $waitFailure = $null
        try {
            if ($CapturePeakWorkingSet) {
                $peakWorkingSetSamples = [System.Collections.Generic.List[long]]::new()
                Wait-VerificationProcess `
                    -Process $process `
                    -Description $Description `
                    -TimeoutMilliseconds $TimeoutMilliseconds `
                    -PeakWorkingSetSamples $peakWorkingSetSamples
            } else {
                Wait-VerificationProcess `
                    -Process $process `
                    -Description $Description `
                    -TimeoutMilliseconds $TimeoutMilliseconds
            }
        } catch {
            $waitFailure = $_
        }
        # The bounded wait proves termination. The pipe readers started before
        # that wait prevent stdout/stderr backpressure, and the final immediate
        # wait plus task joins prove the complete streams have drained.
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($null -ne $executionRecord) {
            [IO.File]::WriteAllText($executionRecord.stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($executionRecord.stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
            $executionRecord.exit = $process.ExitCode
            $executionRecord.processesStopped = $true
            $executionRecord.finishedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
            $executionRecord.status = if ($null -ne $waitFailure) { 'failed' } elseif ($process.ExitCode -eq 0) { 'passed' } else { 'failed' }
            $executionRecord.failure = if ($null -ne $waitFailure) { $waitFailure.Exception.Message } else { $null }
            Write-VerificationExecutionRecord -Path $ExecutionRecordPath -Record $executionRecord
        }
        $peakWorkingSet64 = if ($null -ne $peakWorkingSetSamples -and $peakWorkingSetSamples.Count -gt 0) {
            $peakWorkingSetSamples[0]
        } else { 0 }
        if ($null -ne $waitFailure) {
            $details = ($stderr + $stdout).Trim()
            if (-not [string]::IsNullOrWhiteSpace($details)) {
                throw "$($waitFailure.Exception.Message)`n$details"
            }
            throw $waitFailure
        }
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
            PeakWorkingSet64 = $peakWorkingSet64
        }
    } catch {
        if ($null -ne $executionRecord -and $executionRecord.status -in @('starting', 'running')) {
            $executionRecord.failure = $_.Exception.Message
            $executionRecord.status = 'failed'
            # An unexpected exception is not evidence that a started child stopped.
            if ($null -eq $executionRecord.pid) {
                $executionRecord.processesStopped = $true
            } elseif ($process.HasExited) {
                $executionRecord.exit = $process.ExitCode
                $executionRecord.processesStopped = $true
            }
            $executionRecord.finishedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
            Write-VerificationExecutionRecord -Path $ExecutionRecordPath -Record $executionRecord
        }
        throw
    } finally {
        $process.Dispose()
    }
}

function Invoke-VerificationProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$Description,
        [string]$WorkingDirectory = "",
        [string]$StandardInputPath = "",
        [int]$TimeoutMilliseconds = 3600000
    )

    $result = Invoke-VerificationProcessCapture `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -Description $Description `
        -WorkingDirectory $WorkingDirectory `
        -StandardInputPath $StandardInputPath `
        -TimeoutMilliseconds $TimeoutMilliseconds
    if ($result.ExitCode -ne 0) {
        $details = @($result.Stdout.TrimEnd(), $result.Stderr.TrimEnd()) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $suffix = if ($details.Count -gt 0) { "`n" + ($details -join "`n") } else { "" }
        throw "$Description failed with exit code $($result.ExitCode)$suffix"
    }
    return $result
}
