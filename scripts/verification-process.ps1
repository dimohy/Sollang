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
                [TimeSpan]$processorTime = $process.TotalProcessorTime
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
        $maximumWaitSlice = if ($null -ne $PeakWorkingSetSamples) {
            [Math]::Min(5, $TelemetryIntervalMilliseconds)
        } else {
            [Math]::Min(60000, $TelemetryIntervalMilliseconds)
        }
        $waitSlice = [Math]::Min($maximumWaitSlice, $remaining)
        if ($Process.WaitForExit($waitSlice)) {
            return
        }
        $observedAt = [DateTimeOffset]::Now
        $elapsed = $observedAt - $startedAt
        if ($observedAt -ge $nextTelemetryAt) {
            $tree = Get-VerificationProcessTreeSnapshot -RootProcessId $Process.Id
            [TimeSpan]$telemetryInterval = $observedAt.Subtract($previousTelemetryAt)
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

function Invoke-VerificationProcessCapture {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$Description,
        [string]$WorkingDirectory = "",
        [string]$StandardInputPath = "",
        [int]$TimeoutMilliseconds = 3600000,
        [switch]$CapturePeakWorkingSet
    )

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
