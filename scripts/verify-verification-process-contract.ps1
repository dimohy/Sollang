[CmdletBinding()]
param(
    [switch]$IncludeWsl,
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "verification-process.ps1")

$powerShellPath = (Get-Process -Id $PID).Path
$completed = Start-Process `
    -FilePath $powerShellPath `
    -ArgumentList @("-NoProfile", "-Command", "exit 0") `
    -PassThru `
    -WindowStyle Hidden
Wait-VerificationProcess $completed "completed positive control" 5000
if ($completed.ExitCode -ne 0) {
    throw "completed process positive control returned exit code $($completed.ExitCode)"
}
Wait-VerificationProcess `
    -Process $completed `
    -Description "completed deadline-race positive control" `
    -TimeoutMilliseconds 3600000 `
    -TimeoutStartedAt ([DateTimeOffset]::Now.AddHours(-2))

$captureProbePath = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-verification-capture-probe-" + [Guid]::NewGuid().ToString("N") + ".ps1")
try {
    [System.IO.File]::WriteAllText(
        $captureProbePath,
        "`$buffer = [byte[]]::new(8MB); `$buffer[0] = 1; Start-Sleep -Milliseconds 50; [Console]::Out.Write('capture-out'); [Console]::Error.Write('capture-err'); exit 7")
    $captured = Invoke-VerificationProcessCapture `
        -FilePath $powerShellPath `
        -ArgumentList @("-NoProfile", "-File", $captureProbePath) `
        -Description "captured-process positive control" `
        -CapturePeakWorkingSet `
        -TimeoutMilliseconds 5000
    if ($captured.ExitCode -ne 7 -or
        $captured.Stdout -cne "capture-out" -or
        $captured.Stderr -cne "capture-err") {
        throw "captured-process positive control did not preserve exit/stdout/stderr"
    }
    if ($captured.PeakWorkingSet64 -le 0) {
        throw "captured-process positive control did not report a live peak working set"
    }
    $verificationHelperPath = Join-Path $PSScriptRoot "verification-process.ps1"
    $concurrentCaptures = @(1..8 | ForEach-Object -ThrottleLimit 8 -Parallel {
        . $using:verificationHelperPath
        Invoke-VerificationProcessCapture `
            -FilePath $using:powerShellPath `
            -ArgumentList @("-NoProfile", "-File", $using:captureProbePath) `
            -Description "concurrent captured-process positive control $_" `
            -CapturePeakWorkingSet `
            -TimeoutMilliseconds 5000
    })
    if ($concurrentCaptures.Count -ne 8) {
        throw "concurrent capture control returned $($concurrentCaptures.Count) results instead of 8"
    }
    foreach ($concurrentCapture in $concurrentCaptures) {
        if ($concurrentCapture.ExitCode -ne 7 -or
            $concurrentCapture.Stdout -cne "capture-out" -or
            $concurrentCapture.Stderr -cne "capture-err") {
            throw "concurrent capture control did not preserve exit/stdout/stderr"
        }
        if ($concurrentCapture.PeakWorkingSet64 -le 0) {
            throw "concurrent capture control did not report a live peak working set"
        }
    }
    $failureObserved = $false
    try {
        Invoke-VerificationProcess `
            -FilePath $powerShellPath `
            -ArgumentList @("-NoProfile", "-File", $captureProbePath) `
            -Description "checked-process negative control" `
            -TimeoutMilliseconds 5000 | Out-Null
    } catch {
        if ($_.Exception.Message -notlike "checked-process negative control failed with exit code 7*capture-out*capture-err*") {
            throw
        }
        $failureObserved = $true
    }
    if (-not $failureObserved) {
        throw "checked-process negative control did not reject a nonzero exit code"
    }
}
finally {
    Remove-Item -LiteralPath $captureProbePath -ErrorAction SilentlyContinue
}

if ($IncludeWsl) {
    $verificationHelperPath = Join-Path $PSScriptRoot "verification-process.ps1"
    $wslCaptures = @(1..8 | ForEach-Object -ThrottleLimit 8 -Parallel {
        . $using:verificationHelperPath
        Invoke-VerificationProcessCapture `
            -FilePath "wsl.exe" `
            -ArgumentList @(
                "-d", $using:Distribution, "--", "sh", "-c",
                "printf pipe-out; printf pipe-err >&2; exit 7") `
            -Description "concurrent WSL pipe capture $_" `
            -TimeoutMilliseconds 10000
    })
    if ($wslCaptures.Count -ne 8) {
        throw "concurrent WSL capture control returned $($wslCaptures.Count) results instead of 8"
    }
    foreach ($wslCapture in $wslCaptures) {
        if ($wslCapture.ExitCode -ne 7 -or
            $wslCapture.Stdout -cne "pipe-out" -or
            $wslCapture.Stderr -cne "pipe-err") {
            throw "concurrent WSL capture control did not preserve exit/stdout/stderr"
        }
    }
}

$contractDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-verification-process-" + [Guid]::NewGuid().ToString("N"))
$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$contractDirectory = [System.IO.Path]::GetFullPath($contractDirectory)
if (-not $contractDirectory.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "verification process contract directory escaped the temporary root: $contractDirectory"
}
New-Item -ItemType Directory -Path $contractDirectory | Out-Null
$failureOutput = Join-Path $contractDirectory "compiler.stdout.tmp"
$failureError = Join-Path $contractDirectory "compiler.stderr.tmp"
$partialOutput = Join-Path $contractDirectory "compiler.ll.partial"
$publishedError = Join-Path $contractDirectory "compiler.err"
[System.IO.File]::WriteAllText($failureOutput, "partial-llvm")
[System.IO.File]::WriteAllText($failureError, "timeout-detail")
Publish-VerificationFailureArtifacts `
    -TemporaryOutputPath $failureOutput `
    -TemporaryErrorPath $failureError `
    -PartialOutputPath $partialOutput `
    -ErrorOutputPath $publishedError
if ((Test-Path -LiteralPath $failureOutput) -or
    (Test-Path -LiteralPath $failureError) -or
    [System.IO.File]::ReadAllText($partialOutput) -cne "partial-llvm" -or
    [System.IO.File]::ReadAllText($publishedError) -cne "timeout-detail") {
    throw "verification failure artifacts were not atomically published"
}
$emptyOutput = Join-Path $contractDirectory "empty.stdout.tmp"
$emptyError = Join-Path $contractDirectory "empty.stderr.tmp"
$emptyPartial = Join-Path $contractDirectory "empty.ll.partial"
$emptyPublishedError = Join-Path $contractDirectory "empty.err"
[System.IO.File]::WriteAllText($emptyOutput, "")
[System.IO.File]::WriteAllText($emptyError, "empty-output-detail")
Publish-VerificationFailureArtifacts `
    -TemporaryOutputPath $emptyOutput `
    -TemporaryErrorPath $emptyError `
    -PartialOutputPath $emptyPartial `
    -ErrorOutputPath $emptyPublishedError
if (Test-Path -LiteralPath $emptyPartial) {
    throw "verification failure artifacts published an empty partial output"
}
$timeoutProbePath = Join-Path $contractDirectory "timeout-probe.ps1"
$timeoutOutput = Join-Path $contractDirectory "timeout.ll"
$timeoutError = Join-Path $contractDirectory "timeout.err"
[System.IO.File]::WriteAllText(
    $timeoutProbePath,
    "[Console]::Out.Write('timeout-partial'); [Console]::Out.Flush(); [Console]::Error.Write('timeout-detail'); [Console]::Error.Flush(); Start-Sleep -Seconds 30")
$captureTimeoutObserved = $false
try {
    Invoke-VerificationProcessCapture `
        -FilePath $powerShellPath `
        -ArgumentList @("-NoProfile", "-File", $timeoutProbePath) `
        -Description "in-memory capture timeout negative control" `
        -TimeoutMilliseconds 5000 | Out-Null
} catch {
    if ($_.Exception.Message -notlike "in-memory capture timeout negative control exceeded*timeout-detailtimeout-partial*") {
        throw
    }
    $captureTimeoutObserved = $true
}
if (-not $captureTimeoutObserved) {
    throw "timed-out in-memory capture did not preserve flushed stdout and stderr"
}
$fileTimeoutObserved = $false
try {
    Invoke-VerificationProcessToFile `
        -FilePath $powerShellPath `
        -ArgumentList @("-NoProfile", "-File", $timeoutProbePath) `
        -Description "file-capture timeout negative control" `
        -OutputPath $timeoutOutput `
        -ErrorPath $timeoutError `
        -TimeoutMilliseconds 5000
} catch {
    if ($_.Exception.Message -notlike "file-capture timeout negative control exceeded*") {
        throw
    }
    $fileTimeoutObserved = $true
}
if (-not $fileTimeoutObserved -or
    (Test-Path -LiteralPath $timeoutOutput) -or
    [System.IO.File]::ReadAllText("$timeoutOutput.partial") -cne "timeout-partial" -or
    [System.IO.File]::ReadAllText($timeoutError) -cne "timeout-detail") {
    throw "timed-out file capture did not preserve exact partial stdout and stderr"
}
$childPidPath = Join-Path $contractDirectory "child.pid"
$telemetryProbe = Start-Process `
    -FilePath $powerShellPath `
    -ArgumentList @("-NoProfile", "-Command", "Start-Sleep -Milliseconds 700") `
    -PassThru `
    -WindowStyle Hidden
$telemetrySamples = [System.Collections.Generic.List[long]]::new()
$telemetryStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$telemetryOutput = @(& {
    Wait-VerificationProcess `
        -Process $telemetryProbe `
        -Description "telemetry cadence control" `
        -TimeoutMilliseconds 3000 `
        -PeakWorkingSetSamples $telemetrySamples `
        -TelemetryIntervalMilliseconds 100
} 6>&1)
$telemetryStopwatch.Stop()
$telemetryLines = @($telemetryOutput | Where-Object { ("$_").StartsWith("[verification wait]") })
$telemetryCount = $telemetryLines.Count
$maximumTelemetryCount = [int][Math]::Ceiling($telemetryStopwatch.Elapsed.TotalMilliseconds / 100.0) + 1
if ($telemetryCount -lt 1 -or $telemetryCount -gt $maximumTelemetryCount) {
    throw "verification telemetry cadence was not bounded: $telemetryCount messages in $([int]$telemetryStopwatch.Elapsed.TotalMilliseconds) ms (maximum $maximumTelemetryCount)"
}
foreach ($telemetryLine in $telemetryLines) {
    if (("$telemetryLine") -notmatch '(host-visible interval \+[0-9.,]+s CPU \([0-9.,]+ effective cores\)|process tree changed; interval CPU baseline reset)') {
        throw "verification telemetry did not report interval activity: $telemetryLine"
    }
    if (("$telemetryLine") -notmatch 'host-visible total [0-9.,]+s CPU') {
        throw "verification telemetry did not identify the host-visible CPU scope: $telemetryLine"
    }
}
$escapedPowerShellPath = $powerShellPath.Replace("'", "''")
$escapedChildPidPath = $childPidPath.Replace("'", "''")
$parentScript = @"
`$child = Start-Process -FilePath '$escapedPowerShellPath' -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 30') -PassThru -WindowStyle Hidden
[System.IO.File]::WriteAllText('$escapedChildPidPath', `$child.Id.ToString([System.Globalization.CultureInfo]::InvariantCulture))
`$child.WaitForExit()
"@
$encodedParentScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($parentScript))
$stalled = $null
$childId = 0
try {
    $stalled = Start-Process `
        -FilePath $powerShellPath `
        -ArgumentList @("-NoProfile", "-EncodedCommand", $encodedParentScript) `
        -PassThru `
        -WindowStyle Hidden
    $pidDeadline = [DateTimeOffset]::Now.AddSeconds(5)
    while (-not (Test-Path -LiteralPath $childPidPath) -and [DateTimeOffset]::Now -lt $pidDeadline) {
        [Threading.Thread]::Sleep(25)
    }
    if (-not (Test-Path -LiteralPath $childPidPath)) {
        throw "timed-out process-tree negative control did not publish its child PID"
    }
    $childId = [int][System.IO.File]::ReadAllText($childPidPath)
    $treeSnapshot = Get-VerificationProcessTreeSnapshot -RootProcessId $stalled.Id
    if ($treeSnapshot.ProcessCount -lt 2 -or
        $treeSnapshot.CpuSeconds -lt 0 -or
        $treeSnapshot.WorkingMiB -le 0) {
        throw "process-tree telemetry did not include the live parent and child"
    }
    $timeoutObserved = $false
    $expiredTimeoutStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Wait-VerificationProcess `
            -Process $stalled `
            -Description "stalled negative control" `
            -TimeoutMilliseconds 3600000 `
            -TimeoutStartedAt ([DateTimeOffset]::Now.AddHours(-1))
    } catch {
        $timeoutMessage = $_.Exception.Message
        if ($timeoutMessage -notlike "stalled negative control exceeded*" -or
            $timeoutMessage -notlike "*01:00:00 (3600000 ms)*actual elapsed*" -or
            $timeoutMessage -like "*1 millisecond*") {
            throw
        }
        $timeoutObserved = $true
    } finally {
        $expiredTimeoutStopwatch.Stop()
    }
    if (-not $timeoutObserved) {
        throw "stalled process negative control did not report a timeout"
    }
    if ($expiredTimeoutStopwatch.Elapsed.TotalSeconds -gt 5) {
        throw "expired verification deadline was not enforced promptly"
    }
    $stalled.Refresh()
    if (-not $stalled.HasExited) {
        throw "stalled parent negative control survived process-tree termination"
    }
    $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
    if ($child -and -not $child.HasExited) {
        throw "stalled child negative control survived process-tree termination"
    }
} finally {
    if ($stalled -and -not $stalled.HasExited) {
        try { $stalled.Kill($true) } catch { }
    }
    if ($childId -gt 0) {
        $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
        if ($child -and -not $child.HasExited) {
            try { $child.Kill() } catch { }
        }
    }
    if (Test-Path -LiteralPath $contractDirectory) {
        Remove-Item -LiteralPath $contractDirectory -Recurse -Force
    }
}

$wslStatus = if ($IncludeWsl) { ", concurrent-WSL-capture" } else { "" }
Write-Host "[verification process contract] PASS completed, async-pipe capture, concurrent-capture$wslStatus, interval CPU telemetry, live peak-memory telemetry, failure-artifact preservation, timed-out in-memory/file capture, process-tree telemetry, checked nonzero, and timed-out parent/child controls."
