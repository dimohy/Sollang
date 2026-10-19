[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Stage2Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$launcherPath = Join-Path $PSScriptRoot 'invoke-detached-selfhost-verification.ps1'
$requesterPath = Join-Path $PSScriptRoot 'request-detached-selfhost-cancellation.ps1'
$stage2Path = Join-Path $PSScriptRoot 'verify-selfhost-stage2.ps1'
$batchPath = Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1'
$exactPath = Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1'
$processPath = Join-Path $PSScriptRoot 'verification-process.ps1'
$targetPath = Join-Path $PSScriptRoot 'contracts\fixtures\c465-native-exact-cancellation-target.ps1'
$compiler = (Resolve-Path -LiteralPath $Stage2Compiler).Path
$completed = 0
$total = 3
$failureIds = [Collections.Generic.List[string]]::new()
$observedActiveCompilerPid = $null
$detachedResult = $null
$activeAcknowledgement = $null
$activeBatchReport = $null

function Save-Result([string]$Status, [int]$ExitCode) {
    $inputs = @($launcherPath, $requesterPath, $stage2Path, $batchPath, $exactPath, $processPath, $targetPath, $compiler)
    $inputHashes = [ordered]@{}
    $fingerprintLines = foreach ($path in $inputs) {
        $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $inputHashes[$relative] = $hash
        "$relative=$hash"
    }
    $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes(($fingerprintLines -join "`n"))))
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-23-465'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        inputFingerprint = $fingerprint
        inputHashes = $inputHashes
        stage2CompilerSha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        detachedCancellation = $detachedResult
        activeNativeExactCompilerPid = $observedActiveCompilerPid
        activeNativeExactAcknowledgement = $activeAcknowledgement
        activeNativeExactBatch = $activeBatchReport
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-DescendantProcesses([int]$RootProcessId) {
    $records = @(Get-CimInstance Win32_Process)
    $known = [Collections.Generic.HashSet[int]]::new()
    [void]$known.Add($RootProcessId)
    $frontier = @($RootProcessId)
    while ($frontier.Count -gt 0) {
        $children = @($records | Where-Object { $frontier -contains [int]$_.ParentProcessId })
        $frontier = @()
        foreach ($child in $children) {
            if ($known.Add([int]$child.ProcessId)) {
                $frontier += [int]$child.ProcessId
            }
        }
    }
    @($records | Where-Object { [int]$_.ProcessId -ne $RootProcessId -and $known.Contains([int]$_.ProcessId) })
}

try {
    $launcherText = [IO.File]::ReadAllText($launcherPath)
    $stage2Text = [IO.File]::ReadAllText($stage2Path)
    $batchText = [IO.File]::ReadAllText($batchPath)
    $exactText = [IO.File]::ReadAllText($exactPath)
    $processText = [IO.File]::ReadAllText($processPath)
    foreach ($required in @(
        '[ValidateRange(1, 3600)]',
        "`$Verification -eq 'Stage2'",
        "`$CancellationTimeoutSeconds = 3600",
        '"-CancellationRunId", (ConvertTo-ProcessArgument $RunId)',
        '"-CancellationAcknowledgementPath", (ConvertTo-ProcessArgument $CancellationAcknowledgementPath)')) {
        if (-not $launcherText.Contains($required, [StringComparison]::Ordinal)) {
            throw "C465 launcher contract is missing: $required"
        }
    }
    foreach ($text in @($stage2Text, $batchText, $exactText)) {
        foreach ($required in @('$CancellationRequestPath', '$CancellationRunId', '$CancellationAcknowledgementPath')) {
            if (-not $text.Contains($required, [StringComparison]::Ordinal)) {
                throw "C465 cancellation propagation is missing: $required"
            }
        }
    }
    if (-not $processText.Contains("tmp-`$PID-`$([guid]::NewGuid().ToString('N'))", [StringComparison]::Ordinal)) {
        throw 'C465 acknowledgement temp path is not runspace-race-safe'
    }
    $completed++

    $detachedRunId = 'c465-detached-' + [guid]::NewGuid().ToString('N')
    $detachedLogPath = Join-Path $output "$detachedRunId.log"
    $detachedResultPath = Join-Path $output "$detachedRunId.result.json"
    $launch = & $launcherPath -Verification Stage2 -SeedMode ManagedRecovery -ResumeCandidate `
        -RunId $detachedRunId -LogPath $detachedLogPath -CompletionRecordPath $detachedResultPath `
        -CancellationTimeoutSeconds 60 | ConvertFrom-Json
    $detachedResult = & $requesterPath -CompletionRecordPath $detachedResultPath -TimeoutSeconds 90 | ConvertFrom-Json
    if ($detachedResult.status -cne 'cancelled' -or $detachedResult.exitCode -ne 130 -or
        $detachedResult.targetExitCode -ne 130 -or @($detachedResult.failureIds).Count -ne 1 -or
        $detachedResult.failureIds[0] -cne 'CANCELLATION_REQUESTED' -or
        @($detachedResult.orphanProcessIds).Count -ne 0 -or
        [int]$detachedResult.cancellationAcknowledgement.targetProcessId -ne [int]$detachedResult.targetProcessId) {
        throw 'C465 detached Stage2 cancellation did not terminate cooperatively with exact evidence'
    }
    $completed++

    $activeRunId = 'c465-active-' + [guid]::NewGuid().ToString('N')
    $activeRoot = Join-Path $output $activeRunId
    [IO.Directory]::CreateDirectory($activeRoot) | Out-Null
    $requestPath = Join-Path $activeRoot 'cancel.json'
    $acknowledgementPath = Join-Path $activeRoot 'cancel.ack.json'
    $stdoutPath = Join-Path $activeRoot 'target.stdout.txt'
    $stderrPath = Join-Path $activeRoot 'target.stderr.txt'
    $powerShellPath = (Get-Process -Id $PID).Path
    $target = Start-Process -FilePath $powerShellPath -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -ArgumentList @(
            '-NoProfile', '-File', ('"' + $targetPath + '"'),
            '-Compiler', ('"' + $compiler + '"'),
            '-OutputDirectory', ('"' + (Join-Path $activeRoot 'batch') + '"'),
            '-CancellationRequestPath', ('"' + $requestPath + '"'),
            '-CancellationRunId', $activeRunId,
            '-CancellationAcknowledgementPath', ('"' + $acknowledgementPath + '"'))
    $compilerDeadline = [DateTimeOffset]::UtcNow.AddMinutes(5)
    while ($true) {
        $compilerProcess = Get-DescendantProcesses -RootProcessId $target.Id |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
                [IO.Path]::GetFullPath([string]$_.ExecutablePath) -ceq $compiler } |
            Select-Object -First 1
        if ($null -ne $compilerProcess) {
            $observedActiveCompilerPid = [int]$compilerProcess.ProcessId
            break
        }
        if ($target.HasExited) {
            throw "C465 native-exact target exited before an active compiler was observed: $([IO.File]::ReadAllText($stderrPath))"
        }
        if ([DateTimeOffset]::UtcNow -ge $compilerDeadline) {
            throw 'C465 did not observe an active native-exact compiler before timeout'
        }
        Start-Sleep -Milliseconds 100
        $target.Refresh()
    }
    $request = [ordered]@{
        schemaVersion = 1
        runId = $activeRunId
        requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
        requestedByPid = $PID
    }
    $requestTemporaryPath = "$requestPath.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    $request | ConvertTo-Json | Set-Content -LiteralPath $requestTemporaryPath -Encoding utf8
    Move-Item -LiteralPath $requestTemporaryPath -Destination $requestPath -Force
    if (-not $target.WaitForExit(3600000)) {
        throw 'C465 active native-exact cancellation did not reach a safe terminal boundary within one hour'
    }
    $target.WaitForExit()
    if ($target.ExitCode -ne 130) {
        throw "C465 active native-exact target exited $($target.ExitCode): $([IO.File]::ReadAllText($stderrPath))"
    }
    if (-not (Test-Path -LiteralPath $acknowledgementPath -PathType Leaf)) {
        throw 'C465 active native-exact target did not publish cancellation acknowledgement'
    }
    $activeAcknowledgement = Get-Content -LiteralPath $acknowledgementPath -Raw | ConvertFrom-Json
    if ($activeAcknowledgement.runId -cne $activeRunId -or
        [int]$activeAcknowledgement.targetProcessId -ne $target.Id) {
        throw 'C465 active native-exact acknowledgement did not bind the target identity'
    }
    $activeBatchReportPath = Join-Path $activeRoot 'batch\c465-active-cancellation-batch-results.json'
    $activeBatchReport = Get-Content -LiteralPath $activeBatchReportPath -Raw | ConvertFrom-Json
    if ($activeBatchReport.state -cne 'cancelled' -or $activeBatchReport.completed -ne 2 -or
        $activeBatchReport.total -ne 2 -or @($activeBatchReport.results).Count -ne 2 -or
        @($activeBatchReport.results | Where-Object { $_.Error -notlike 'CANCELLATION_REQUESTED*' }).Count -ne 0) {
        throw 'C465 active native-exact batch did not publish exact cancelled terminal state'
    }
    $queuedFixtureArtifacts = @(Get-ChildItem (Join-Path $activeRoot 'batch') -File |
        Where-Object { $_.Name.Contains('1410-selfhost-constant-expression-plan', [StringComparison]::Ordinal) })
    if ($queuedFixtureArtifacts.Count -ne 0) {
        throw 'C465 started compiler artifacts for a fixture queued after cancellation'
    }
    $remainingDescendants = @(Get-DescendantProcesses -RootProcessId $target.Id |
        Where-Object { $null -ne (Get-Process -Id ([int]$_.ProcessId) -ErrorAction SilentlyContinue) })
    if ($remainingDescendants.Count -ne 0) {
        throw "C465 active native-exact cancellation left descendants: $(@($remainingDescendants.ProcessId) -join ',')"
    }
    $completed++

    Save-Result 'passed' 0
    Write-Host "[C465] PASS $completed/$total detached Stage2 and active native-exact cooperative cancellation."
} catch {
    $failureIds.Add('C465_GATE_FAILED')
    Save-Result 'failed' 1
    throw
}
