param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$runId = "detached-contract-$PID-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$scratchRoot = Join-Path $RepositoryRoot "artifacts\scratch"
$logPath = Join-Path $scratchRoot "$runId.log"
$completionRecordPath = Join-Path $scratchRoot "$runId.result.json"
$observerOutputPath = Join-Path $scratchRoot "$runId.observer.json"
$launcherPath = Join-Path $RepositoryRoot "scripts\invoke-detached-selfhost-verification.ps1"
$cancellationRequesterPath = Join-Path $RepositoryRoot "scripts\request-detached-selfhost-cancellation.ps1"
$progressReaderPath = Join-Path $RepositoryRoot "scripts\read-detached-selfhost-progress.ps1"
$resultSchemaPath = Join-Path $RepositoryRoot "scripts\contracts\detached-selfhost-verification-result.schema.json"

$outsideArtifactPath = Join-Path $RepositoryRoot "$runId.outside.log"
try {
    & $launcherPath -Verification Probe -RunId "$runId-path" -LogPath $outsideArtifactPath | Out-Null
    throw "path outside artifacts unexpectedly launched"
}
catch {
    if ($_.Exception.Message -notlike "*must be under*") { throw }
}
$aliasedPath = Join-Path $scratchRoot "$runId-aliased.json"
try {
    & $launcherPath `
        -Verification Probe `
        -RunId "$runId-aliased" `
        -LogPath $aliasedPath `
        -CompletionRecordPath $aliasedPath | Out-Null
    throw "aliased log and completion paths unexpectedly launched"
}
catch {
    if ($_.Exception.Message -notlike "*must be distinct*") { throw }
}

$invalidRunId = "$runId-invalid-stage3-seed"
$invalidCompletionRecordPath = Join-Path $scratchRoot "$invalidRunId.result.json"
try {
    & $launcherPath `
        -Verification Stage3 `
        -SeedMode Stage2Bridge `
        -RunId $invalidRunId `
        -LogPath (Join-Path $scratchRoot "$invalidRunId.log") `
        -CompletionRecordPath $invalidCompletionRecordPath | Out-Null
    throw "invalid Stage3 seed mode unexpectedly launched"
}
catch {
    if ($_.Exception.Message -notlike "*does not accept SeedMode Stage2Bridge*") { throw }
}
if (Test-Path -LiteralPath "$invalidCompletionRecordPath.launch.json") {
    throw "invalid Stage3 seed mode created launch evidence"
}

$interruptedRunId = "$runId-interrupted"
$interruptedLogPath = Join-Path $scratchRoot "$interruptedRunId.log"
$interruptedCompletionRecordPath = Join-Path $scratchRoot "$interruptedRunId.result.json"
New-Item -ItemType File -Path $interruptedLogPath -Force | Out-Null
([ordered]@{
    schemaVersion = 1
    runId = $interruptedRunId
    verification = "Stage2"
    executionMode = "detached-supervisor"
    supervisorPid = 2147483647
    observerPid = $PID
    survivesObserverDisconnect = $true
    logPath = $interruptedLogPath
    completionRecordPath = $interruptedCompletionRecordPath
    launchedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
} | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath "$interruptedCompletionRecordPath.launch.json" -Encoding utf8
$interruptedProgress = & $progressReaderPath -CompletionRecordPath $interruptedCompletionRecordPath | ConvertFrom-Json
if ($interruptedProgress.status -cne "interrupted-without-result") {
    throw "missing completion record was not classified as an interruption"
}

foreach ($linuxProgressCase in @(
    [ordered]@{ Verification = "Stage2Linux"; Stage = "linux-stage2"; Current = 3; Completed = 2; Total = 6; Percent = 33.3 },
    [ordered]@{ Verification = "Stage3Linux"; Stage = "linux-stage3"; Current = 2; Completed = 1; Total = 3; Percent = 33.3 }
)) {
    $linuxRunId = "$runId-$($linuxProgressCase.Verification.ToLowerInvariant())"
    $linuxLogPath = Join-Path $scratchRoot "$linuxRunId.log"
    $linuxCompletionRecordPath = Join-Path $scratchRoot "$linuxRunId.result.json"
    "[$($linuxProgressCase.Stage) $($linuxProgressCase.Current)/$($linuxProgressCase.Total)] active" |
        Set-Content -LiteralPath $linuxLogPath -Encoding utf8
    ([ordered]@{
        schemaVersion = 1
        runId = $linuxRunId
        verification = $linuxProgressCase.Verification
        executionMode = "detached-supervisor"
        supervisorPid = 2147483647
        observerPid = $PID
        survivesObserverDisconnect = $true
        logPath = $linuxLogPath
        completionRecordPath = $linuxCompletionRecordPath
        launchedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    } | ConvertTo-Json -Depth 5) |
        Set-Content -LiteralPath "$linuxCompletionRecordPath.launch.json" -Encoding utf8
    $linuxProgress = & $progressReaderPath -CompletionRecordPath $linuxCompletionRecordPath | ConvertFrom-Json
    if ($linuxProgress.status -cne "interrupted-without-result" -or
        $linuxProgress.completed -ne $linuxProgressCase.Completed -or
        $linuxProgress.total -ne $linuxProgressCase.Total -or
        $linuxProgress.percent -ne $linuxProgressCase.Percent) {
        throw "$($linuxProgressCase.Verification) progress mapping is incorrect"
    }
}

Write-Host "[detached selfhost verification] PASS Linux Stage2/Stage3 progress mappings."

$observer = Start-Process `
    -FilePath (Get-Process -Id $PID).Path `
    -ArgumentList @(
        "-NoProfile",
        "-File", ('"' + $launcherPath + '"'),
        "-Verification", "Probe",
        "-RunId", $runId,
        "-LogPath", ('"' + $logPath + '"'),
        "-CompletionRecordPath", ('"' + $completionRecordPath + '"')
    ) `
    -WorkingDirectory $RepositoryRoot `
    -RedirectStandardOutput $observerOutputPath `
    -WindowStyle Hidden `
    -Wait `
    -PassThru
if ($observer.ExitCode -ne 0) {
    throw "detached launcher observer failed with exit code $($observer.ExitCode)"
}

$deadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $completionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $deadline) {
        throw "detached supervisor did not publish its structured completion record"
    }
    Start-Sleep -Milliseconds 100
}

$result = Get-Content -LiteralPath $completionRecordPath -Raw | ConvertFrom-Json
$resultJson = Get-Content -LiteralPath $completionRecordPath -Raw
if (-not ($resultJson | Test-Json -SchemaFile $resultSchemaPath)) { throw "failed result does not match its schema" }
if ($result.executionMode -cne "detached-supervisor") { throw "unexpected execution mode" }
if ($result.exitCode -ne 7) { throw "probe exit code was not preserved" }
if ($result.status -cne "failed") { throw "probe status was not preserved" }
if (@($result.failureIds) -notcontains "E999") { throw "diagnostic failure id E999 was not preserved" }
if (@($result.failureIds) -notcontains "S015") { throw "self-host diagnostic failure id S015 was not preserved" }
if (@($result.failureIds) -notcontains "9999-detached-supervisor-probe") { throw "fixture failure id was not preserved" }
if (@($result.failureIds) -contains "1411-borrowed-receiver-error-reuse") { throw "passing fixture name containing error was misclassified as a failure identifier" }
if (@($result.failureIds).Count -ne 3) { throw "failed probe reported unexpected failure identifiers" }
if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { throw "durable log is missing" }
if ($observer.Id -eq $result.supervisorPid) { throw "observer and supervisor must be distinct processes" }
$failedProgress = & $progressReaderPath -CompletionRecordPath $completionRecordPath | ConvertFrom-Json
if ($failedProgress.status -cne "failed" -or $failedProgress.exitCode -ne 7) {
    throw "failed detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS observer exited independently; exit code 7 and 3/3 failure IDs preserved."

$passRunId = "$runId-pass"
$passLogPath = Join-Path $scratchRoot "$passRunId.log"
$passCompletionRecordPath = Join-Path $scratchRoot "$passRunId.result.json"
& $launcherPath `
    -Verification Probe `
    -ProbeOutcome Pass `
    -RunId $passRunId `
    -LogPath $passLogPath `
    -CompletionRecordPath $passCompletionRecordPath | Out-Null
$passDeadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $passCompletionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $passDeadline) {
        throw "successful detached probe did not publish its structured completion record"
    }
    Start-Sleep -Milliseconds 100
}
$passResult = Get-Content -LiteralPath $passCompletionRecordPath -Raw | ConvertFrom-Json
$passResultJson = Get-Content -LiteralPath $passCompletionRecordPath -Raw
if (-not ($passResultJson | Test-Json -SchemaFile $resultSchemaPath)) { throw "successful result does not match its schema" }
$incrementalSuccess = $passResultJson | ConvertFrom-Json
$incrementalSuccess.verification = "Incremental"
if (-not (($incrementalSuccess | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath)) {
    throw "incremental result does not match its schema"
}
$unknownVerification = $passResultJson | ConvertFrom-Json
$unknownVerification.verification = "Unknown"
if (($unknownVerification | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted an unknown verification kind"
}
if ($passResult.exitCode -ne 0 -or $passResult.status -cne "passed") {
    throw "successful detached probe outcome was not preserved"
}
if (@($passResult.failureIds).Count -ne 0) {
    throw "successful detached probe reported failure identifiers"
}
if (@($passResult.orphanProcessIds).Count -ne 0) {
    throw "successful detached probe reported orphan processes"
}
$invalidSuccess = $passResultJson | ConvertFrom-Json
$invalidSuccess.failureIds = @("E1")
if (($invalidSuccess | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted a failure identifier on success"
}
$invalidSuccess = $passResultJson | ConvertFrom-Json
$invalidSuccess.orphanProcessIds = @(4242)
if (($invalidSuccess | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted an orphan process on success"
}
$invalidFailure = $resultJson | ConvertFrom-Json
$invalidFailure.exitCode = 0
if (($invalidFailure | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted a zero exit code on failure"
}
$passedProgress = & $progressReaderPath -CompletionRecordPath $passCompletionRecordPath | ConvertFrom-Json
if ($passedProgress.status -cne "passed" -or $passedProgress.completed -ne 1 -or $passedProgress.total -ne 1) {
    throw "successful detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS successful termination, Incremental schema coverage, exit code 0, 0 failure IDs, and 0 orphans."

$spacedRoot = Join-Path $scratchRoot "$runId path with spaces"
$spacedLogPath = Join-Path $spacedRoot "probe output.log"
$spacedCompletionRecordPath = Join-Path $spacedRoot "probe result.json"
& $launcherPath `
    -Verification Probe `
    -ProbeOutcome Pass `
    -RunId "$runId-spaced" `
    -LogPath $spacedLogPath `
    -CompletionRecordPath $spacedCompletionRecordPath | Out-Null
$spacedDeadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $spacedCompletionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $spacedDeadline) {
        throw "detached probe with spaced paths did not publish its structured completion record"
    }
    Start-Sleep -Milliseconds 100
}
$spacedResult = Get-Content -LiteralPath $spacedCompletionRecordPath -Raw | ConvertFrom-Json
if ($spacedResult.exitCode -ne 0 -or $spacedResult.logPath -cne $spacedLogPath) {
    throw "detached probe did not preserve spaced paths"
}

Write-Host "[detached selfhost verification] PASS paths containing spaces preserve execution and evidence identity."

$cancelRunId = "$runId-cancel"
$cancelLogPath = Join-Path $scratchRoot "$cancelRunId.log"
$cancelCompletionRecordPath = Join-Path $scratchRoot "$cancelRunId.result.json"
$cancelLaunch = & $launcherPath `
    -Verification Probe `
    -ProbeOutcome Wait `
    -RunId $cancelRunId `
    -LogPath $cancelLogPath `
    -CompletionRecordPath $cancelCompletionRecordPath | ConvertFrom-Json
$targetDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
do {
    $targetPid = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ParentProcessId -eq $cancelLaunch.supervisorPid } |
        Select-Object -First 1 -ExpandProperty ProcessId
    if ($null -ne $targetPid) { break }
    if ([DateTimeOffset]::UtcNow -ge $targetDeadline) {
        throw "cancellation probe did not start its supervised target"
    }
    Start-Sleep -Milliseconds 100
} while ($true)
$cancelResult = & $cancellationRequesterPath `
    -CompletionRecordPath $cancelCompletionRecordPath `
    -TimeoutSeconds 20 | ConvertFrom-Json
$cancelResultJson = Get-Content -LiteralPath $cancelCompletionRecordPath -Raw
if (-not ($cancelResultJson | Test-Json -SchemaFile $resultSchemaPath)) {
    throw "cancelled result does not match its schema"
}
if ($cancelResult.status -cne "cancelled" -or $cancelResult.exitCode -eq 0) {
    throw "cancelled result did not preserve terminal status and non-zero exit code"
}
if (@($cancelResult.failureIds).Count -ne 1 -or $cancelResult.failureIds[0] -cne "CANCELLATION_REQUESTED") {
    throw "cancelled result did not preserve the exact cancellation failure ID"
}
if (@($cancelResult.orphanProcessIds).Count -ne 0) {
    throw "cancelled result reported orphan processes"
}
if ($null -ne (Get-Process -Id ([int]$targetPid) -ErrorAction SilentlyContinue)) {
    throw "cancelled supervised target is still running"
}
$cancelProgress = & $progressReaderPath -CompletionRecordPath $cancelCompletionRecordPath | ConvertFrom-Json
if ($cancelProgress.status -cne "cancelled" -or $cancelProgress.exitCode -eq 0) {
    throw "cancelled detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS supported cancellation preserved cancelled, non-zero exit, CANCELLATION_REQUESTED, and zero orphans."
