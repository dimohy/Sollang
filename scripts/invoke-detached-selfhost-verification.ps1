param(
    [Parameter(Mandatory)]
    [ValidateSet("Stage2", "Stage3", "Stage2Linux", "Stage3Linux", "BrowserStage2", "Incremental", "ExpressionBatch", "ManagedHost", "Probe")]
    [string]$Verification,
    [ValidateSet("Slg", "Stage2Bridge", "ManagedRecovery")]
    [string]$SeedMode = "Slg",
    [ValidateRange(1, 64)]
    [int]$Jobs = 8,
    [string]$Distribution = "Ubuntu",
    [switch]$ResumeCandidate,
    [string]$RunId = "",
    [string]$LogPath = "",
    [string]$CompletionRecordPath = "",
    [string]$CancellationRequestPath = "",
    [string]$BrowserCandidateCompiler = "",
    [string]$BrowserFocusedFixture = "",
    [string]$IncrementalFixture = "",
    [string]$ExpressionBatchCompiler = "",
    [string[]]$ExpressionBatchFixture = @(),
    [string]$ExpressionBatchManifest = "",
    [string]$ExpressionBatchManifestSha256 = "",
    [switch]$ValidateInputsOnly,
    [ValidateSet("windows", "linux")]
    [string]$IncrementalTarget = "windows",
    [ValidateSet("Pass", "Fail", "Wait", "ChildPass", "ChildOrphan")]
    [string]$ProbeOutcome = "Fail",
    [switch]$Supervisor
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scratchRoot = Join-Path $repositoryRoot "artifacts\scratch"
if ($Verification -eq "Stage3" -and $SeedMode -eq "Stage2Bridge") {
    throw "Stage3 does not accept SeedMode Stage2Bridge"
}
if (($BrowserCandidateCompiler -eq "") -ne ($BrowserFocusedFixture -eq "")) {
    throw "BrowserCandidateCompiler and BrowserFocusedFixture must be supplied together"
}
if ($Verification -ne "BrowserStage2" -and $BrowserCandidateCompiler -ne "") {
    throw "focused browser inputs require Verification BrowserStage2"
}
if (($Verification -eq "Incremental") -ne (-not [string]::IsNullOrWhiteSpace($IncrementalFixture))) {
    throw "IncrementalFixture is required only for Verification Incremental"
}
if (($Verification -eq "ExpressionBatch") -ne (-not [string]::IsNullOrWhiteSpace($ExpressionBatchCompiler))) {
    throw "ExpressionBatchCompiler is required only for Verification ExpressionBatch"
}
if ($Verification -ne "ExpressionBatch" -and
    ($ExpressionBatchFixture.Count -gt 0 -or $ExpressionBatchManifest -ne "" -or
        $ExpressionBatchManifestSha256 -ne "" -or $ValidateInputsOnly)) {
    throw "Expression batch selection and input validation require Verification ExpressionBatch"
}
$selectedFixtures = @()
if ($Verification -eq "ExpressionBatch") {
    . (Join-Path $PSScriptRoot 'expression-batch-selection.ps1')
    $defaults = @( (Get-Content (Join-Path $PSScriptRoot 'contracts/expression-lowering-parity.json') -Raw | ConvertFrom-Json).representativeFixtures )
    $selectedFixtures = @(Get-ExpressionBatchFixtureSelection -Fixture $ExpressionBatchFixture `
        -ManifestPath $ExpressionBatchManifest -ManifestSha256 $ExpressionBatchManifestSha256 `
        -DefaultFixture $defaults)
    if ($selectedFixtures.Count -eq 0) { throw 'Expression batch fixture selection is empty' }
}
if ($Verification -eq "Incremental") {
    $incrementalFixturePath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $IncrementalFixture))
    if (-not $incrementalFixturePath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "IncrementalFixture must be under $repositoryRoot"
    }
    if (-not (Test-Path -LiteralPath $incrementalFixturePath -PathType Leaf)) {
        throw "IncrementalFixture does not exist: $incrementalFixturePath"
    }
    $IncrementalFixture = [IO.Path]::GetRelativePath($repositoryRoot, $incrementalFixturePath)
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory)][string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Assert-ArtifactPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $fullPath = [IO.Path]::GetFullPath($Path)
    $artifactRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts"))
    if (-not $fullPath.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name must be under $artifactRoot"
    }
    return $fullPath
}

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    $temporaryPath = "$Path.tmp-$PID"
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $scratchRoot "$($Verification.ToLowerInvariant())-$RunId.log"
}
if ([string]::IsNullOrWhiteSpace($CompletionRecordPath)) {
    $CompletionRecordPath = Join-Path $scratchRoot "$($Verification.ToLowerInvariant())-$RunId.result.json"
}
if ([string]::IsNullOrWhiteSpace($CancellationRequestPath)) {
    $CancellationRequestPath = "$CompletionRecordPath.cancel.json"
}

$LogPath = Assert-ArtifactPath -Path $LogPath -Name "LogPath"
$CompletionRecordPath = Assert-ArtifactPath -Path $CompletionRecordPath -Name "CompletionRecordPath"
$CancellationRequestPath = Assert-ArtifactPath -Path $CancellationRequestPath -Name "CancellationRequestPath"
$distinctPaths = @($LogPath, $CompletionRecordPath, $CancellationRequestPath) |
    ForEach-Object { $_.ToLowerInvariant() } |
    Select-Object -Unique
if (@($distinctPaths).Count -ne 3) {
    throw "LogPath, CompletionRecordPath, and CancellationRequestPath must be distinct"
}

New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($LogPath)) -Force | Out-Null
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($CompletionRecordPath)) -Force | Out-Null

if (-not $Supervisor) {
    if ((Test-Path -LiteralPath $LogPath) -or
        (Test-Path -LiteralPath $CompletionRecordPath) -or
        (Test-Path -LiteralPath $CancellationRequestPath)) {
        throw "The selected run paths already exist; choose a new RunId"
    }

    New-Item -ItemType File -Path $LogPath -Force | Out-Null
    $powerShellPath = (Get-Process -Id $PID).Path
    $argumentList = @(
        "-NoProfile",
        "-File", (ConvertTo-ProcessArgument $PSCommandPath),
        "-Supervisor",
        "-Verification", $Verification,
        "-SeedMode", $SeedMode,
        "-Jobs", $Jobs.ToString(),
        "-Distribution", (ConvertTo-ProcessArgument $Distribution),
        "-RunId", $RunId,
        "-LogPath", (ConvertTo-ProcessArgument $LogPath),
        "-CompletionRecordPath", (ConvertTo-ProcessArgument $CompletionRecordPath),
        "-CancellationRequestPath", (ConvertTo-ProcessArgument $CancellationRequestPath),
        "-ProbeOutcome", $ProbeOutcome
    )
    if ($BrowserCandidateCompiler -ne "") {
        $argumentList += @(
            "-BrowserCandidateCompiler", (ConvertTo-ProcessArgument $BrowserCandidateCompiler),
            "-BrowserFocusedFixture", (ConvertTo-ProcessArgument $BrowserFocusedFixture)
        )
    }
    if ($IncrementalFixture -ne "") {
        $argumentList += @(
            "-IncrementalFixture", (ConvertTo-ProcessArgument $IncrementalFixture),
            "-IncrementalTarget", $IncrementalTarget
        )
    }
    if ($ExpressionBatchCompiler -ne "") {
        $selectionPath = "$CompletionRecordPath.fixtures.json"
        if (Test-Path -LiteralPath $selectionPath) { throw "Fixture selection snapshot already exists: $selectionPath" }
        Write-JsonAtomically -Path $selectionPath -Value ([ordered]@{ schemaVersion = 1; fixtures = $selectedFixtures })
        $selectionHash = (Get-FileHash -LiteralPath $selectionPath -Algorithm SHA256).Hash
        $argumentList += @(
            "-ExpressionBatchCompiler", (ConvertTo-ProcessArgument $ExpressionBatchCompiler),
            "-ExpressionBatchManifest", (ConvertTo-ProcessArgument $selectionPath),
            "-ExpressionBatchManifestSha256", $selectionHash
        )
        if ($ValidateInputsOnly) { $argumentList += '-ValidateInputsOnly' }
    }
    if ($ResumeCandidate) {
        $argumentList += "-ResumeCandidate"
    }

    $supervisorProcess = Start-Process `
        -FilePath $powerShellPath `
        -ArgumentList $argumentList `
        -WorkingDirectory $repositoryRoot `
        -WindowStyle Hidden `
        -PassThru

    $launchRecordPath = "$CompletionRecordPath.launch.json"
    Write-JsonAtomically -Path $launchRecordPath -Value ([ordered]@{
        schemaVersion = 1
        runId = $RunId
        verification = $Verification
        executionMode = "detached-supervisor"
        supervisorPid = $supervisorProcess.Id
        observerPid = $PID
        survivesObserverDisconnect = $true
        selectedFixtures = $selectedFixtures
        logPath = $LogPath
        completionRecordPath = $CompletionRecordPath
        cancellationRequestPath = $CancellationRequestPath
        launchedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    [ordered]@{
        runId = $RunId
        verification = $Verification
        supervisorPid = $supervisorProcess.Id
        logPath = $LogPath
        completionRecordPath = $CompletionRecordPath
        cancellationRequestPath = $CancellationRequestPath
        launchRecordPath = $launchRecordPath
    } | ConvertTo-Json -Compress
    return
}

$startedAt = [DateTimeOffset]::UtcNow
$exitCode = 255
$failureIds = [Collections.Generic.List[string]]::new()
$cancelled = $false
$targetProcessId = $null
$targetExitCode = $null
$orphanProcessIds = [Collections.Generic.List[int]]::new()
$standardErrorPath = "$LogPath.stderr"
$observedProcesses = [Collections.Generic.Dictionary[string, object]]::new()
$processSnapshotCount = 0
$processAuditCompleted = $false

function Update-ObservedProcessTree {
    # CIM dates have microsecond precision. Match both PID and creation time;
    # a recycled PID never inherits the old process's completion obligation.
    $records = @(Get-CimInstance Win32_Process -ErrorAction Stop |
        Select-Object ProcessId, ParentProcessId, CreationDate)
    $script:processSnapshotCount++
    $byId = @{}
    foreach ($record in $records) { $byId[[int]$record.ProcessId] = $record }
    $pending = [Collections.Generic.Queue[string]]::new()
    $found = [Collections.Generic.HashSet[string]]::new()
    foreach ($identity in @($observedProcesses.Keys)) { $pending.Enqueue($identity) }
    while ($pending.Count -gt 0) {
        $identity = $pending.Dequeue()
        if (-not $found.Add($identity)) { continue }
        $parent = $observedProcesses[$identity].ProcessId
        $parentCreated = $observedProcesses[$identity].CreatedTicks
        # An absent parent is not an ancestry authority: its PID may have been
        # recycled by a process that was itself gone before this snapshot.
        # Already observed children keep their own completion obligations.
        if (-not $byId.ContainsKey($parent) -or
            $byId[$parent].CreationDate.ToUniversalTime().Ticks -ne $parentCreated) { continue }
        foreach ($record in $records) {
            if ([int]$record.ParentProcessId -ne $parent) { continue }
            $created = $record.CreationDate.ToUniversalTime().Ticks
            if ($created -lt $parentCreated) { continue }
            $child = [int]$record.ProcessId
            $childIdentity = "${child}:$created"
            if (-not $observedProcesses.ContainsKey($childIdentity)) {
                $observedProcesses.Add($childIdentity, [pscustomobject]@{ ProcessId = $child; CreatedTicks = $created })
                $pending.Enqueue($childIdentity)
            }
        }
    }
    foreach ($observed in @($observedProcesses.Values)) {
        $processId = $observed.ProcessId
        if ($byId.ContainsKey($processId) -and
            $byId[$processId].CreationDate.ToUniversalTime().Ticks -eq $observed.CreatedTicks) {
            $processId
        }
    }
}

function Complete-ObservedProcessAudit {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
    do {
        $remaining = @(Update-ObservedProcessTree)
        if ($remaining.Count -eq 0 -or [DateTimeOffset]::UtcNow -ge $deadline) { break }
        Start-Sleep -Milliseconds 100
    } while ($true)
    foreach ($processId in $remaining) { $orphanProcessIds.Add($processId) }
    $script:processAuditCompleted = $true
}

function Read-CancellationRequest {
    if (-not (Test-Path -LiteralPath $CancellationRequestPath -PathType Leaf)) { return $null }
    $request = Get-Content -LiteralPath $CancellationRequestPath -Raw | ConvertFrom-Json
    if ($request.schemaVersion -ne 1 -or $request.runId -cne $RunId -or
        [string]::IsNullOrWhiteSpace($request.requestedAtUtc)) {
        throw "Cancellation request does not match the active run"
    }
    return $request
}
try {
    $targetScript = switch ($Verification) {
        "Stage2" { Join-Path $PSScriptRoot "verify-selfhost-stage2.ps1" }
        "Stage3" { Join-Path $PSScriptRoot "verify-selfhost-stage3.ps1" }
        "Stage2Linux" { Join-Path $PSScriptRoot "verify-selfhost-stage2-linux.ps1" }
        "Stage3Linux" { Join-Path $PSScriptRoot "verify-selfhost-stage3-linux.ps1" }
        "BrowserStage2" { Join-Path $PSScriptRoot "build-stage2-browser.ps1" }
        "Incremental" { Join-Path $PSScriptRoot "verify-selfhost-incremental.ps1" }
        "ExpressionBatch" { Join-Path $PSScriptRoot "verify-expression-lowering-focused-batch.ps1" }
        "ManagedHost" { Join-Path $PSScriptRoot "build-managed-host.ps1" }
        "Probe" { Join-Path $PSScriptRoot "contracts\fixtures\detached-verification-probe.ps1" }
    }
    if (-not (Test-Path -LiteralPath $targetScript -PathType Leaf)) {
        throw "Verification script is missing: $targetScript"
    }

    $targetArguments = @("-NoProfile", "-File", (ConvertTo-ProcessArgument $targetScript))
    switch ($Verification) {
        "Stage2" {
            $targetArguments += @("-SeedMode", $SeedMode, "-Stage2BuildJobs", $Jobs.ToString())
            if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" }
        }
        "Stage3" {
            $targetArguments += @("-SeedMode", $SeedMode, "-Jobs", $Jobs.ToString())
            if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" }
        }
        "Stage2Linux" {
            $targetArguments += @("-Distribution", (ConvertTo-ProcessArgument $Distribution), "-Jobs", $Jobs.ToString())
            if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" } else { $targetArguments += "-Rebuild" }
        }
        "Stage3Linux" {
            $targetArguments += @("-Distribution", (ConvertTo-ProcessArgument $Distribution), "-Jobs", $Jobs.ToString())
        }
        "BrowserStage2" {
            if ($BrowserCandidateCompiler -ne "") {
                $targetArguments += @(
                    "-Stage2Compiler", (ConvertTo-ProcessArgument $BrowserCandidateCompiler),
                    "-FocusedFixture", (ConvertTo-ProcessArgument $BrowserFocusedFixture),
                    "-AllowUnpromotedCandidate",
                    "-CandidateOutputDirectory", (ConvertTo-ProcessArgument ("artifacts\scratch\browser-focused-" + $RunId))
                )
            }
        }
        "Incremental" {
            $targetArguments += @(
                "-Fixture", (ConvertTo-ProcessArgument $IncrementalFixture),
                "-Target", $IncrementalTarget,
                "-SeedMode", $SeedMode,
                "-CompareStage2:`$false"
            )
        }
        "ExpressionBatch" {
            $targetArguments += @(
                "-Compiler", (ConvertTo-ProcessArgument $ExpressionBatchCompiler),
                "-RunId", $RunId,
                "-Jobs", $Jobs.ToString()
            )
            if ($ExpressionBatchManifest -ne "") {
                $targetArguments += @(
                    "-FixtureManifest", (ConvertTo-ProcessArgument $ExpressionBatchManifest),
                    "-FixtureManifestSha256", $ExpressionBatchManifestSha256
                )
            }
            if ($ValidateInputsOnly) { $targetArguments += '-ValidateInputsOnly' }
        }
        "ManagedHost" { $targetArguments += @("-RunId", (ConvertTo-ProcessArgument $RunId)) }
        "Probe" { $targetArguments += @("-Outcome", $ProbeOutcome, '-EvidencePath', (ConvertTo-ProcessArgument "$CompletionRecordPath.probe-child.json")) }
    }

    $targetProcess = Start-Process `
        -FilePath (Get-Process -Id $PID).Path `
        -ArgumentList $targetArguments `
        -WorkingDirectory $repositoryRoot `
        -RedirectStandardOutput $LogPath `
        -RedirectStandardError $standardErrorPath `
        -WindowStyle Hidden `
        -PassThru
    $targetProcessId = $targetProcess.Id
    $startTicks = $targetProcess.StartTime.ToUniversalTime().Ticks
    $startTicks -= $startTicks % 10
    $observedProcesses.Add("$($targetProcess.Id):$startTicks", [pscustomobject]@{
        ProcessId = $targetProcess.Id; CreatedTicks = $startTicks
    })
    Update-ObservedProcessTree | Out-Null
    while (-not $targetProcess.WaitForExit(1000)) {
        Update-ObservedProcessTree | Out-Null
        $request = Read-CancellationRequest
        if ($null -eq $request) { continue }

        Update-ObservedProcessTree | Out-Null
        try {
            $targetProcess.Kill($true)
        }
        catch [InvalidOperationException] {
            # The exact target may have become terminal after the wait interval.
        }
        if (-not $targetProcess.WaitForExit(10000)) {
            throw "Cancellation did not stop the supervised process within 10 seconds"
        }
        $targetExitCode = $targetProcess.ExitCode
        Complete-ObservedProcessAudit
        if ($orphanProcessIds.Count -ne 0) {
            throw "Cancellation left $($orphanProcessIds.Count) captured process(es) running"
        }
        $cancelled = $true
        $exitCode = 130
        $failureIds.Add("CANCELLATION_REQUESTED")
        break
    }
    if (-not $cancelled) {
        $targetExitCode = $targetProcess.ExitCode
        $exitCode = $targetExitCode
        Complete-ObservedProcessAudit
        if ($orphanProcessIds.Count -ne 0) {
            if ($exitCode -eq 0) { $exitCode = 1 }
            $failureIds.Add('ORPHAN_PROCESSES_REMAIN')
        }
    }
}
catch {
    $failureIds.Add("SUPERVISOR_EXECUTION_FAILURE")
    "SUPERVISOR_EXECUTION_FAILURE: $($_.Exception.Message)" | Add-Content -LiteralPath $standardErrorPath -Encoding utf8
}
finally {
    if (Test-Path -LiteralPath $standardErrorPath) {
        $standardError = [IO.File]::ReadAllText($standardErrorPath)
        if (-not [string]::IsNullOrWhiteSpace($standardError)) {
            "`n--- standard error ---`n$standardError" | Add-Content -LiteralPath $LogPath -Encoding utf8
        }
    }

    if (-not $cancelled -and $exitCode -ne 0 -and (Test-Path -LiteralPath $LogPath)) {
        $logText = [IO.File]::ReadAllText($LogPath)
        foreach ($line in $logText -split '\r?\n') {
            if ($line -notmatch '(?i)(?<![a-z0-9-])(?:fail(?:ed|ure)?|error|exception|throw|fatal)(?![a-z0-9-])') {
                continue
            }
            foreach ($match in [regex]::Matches($line, '(?i)\b(?:[ES]\d+|(?:CS|MSB|NETSDK)\d+|\d{1,4}-[a-z0-9][a-z0-9-]*|AS-[A-Z]+-\d+(?:-[A-Z0-9-]+)?|MANAGED_HOST_BUILD_FAILED|SUPERVISOR_EXECUTION_FAILURE)\b')) {
                if (-not $failureIds.Contains($match.Value)) {
                    $failureIds.Add($match.Value)
                }
            }
        }
    }

    $completedAt = [DateTimeOffset]::UtcNow
    Write-JsonAtomically -Path $CompletionRecordPath -Value ([ordered]@{
        schemaVersion = 2
        runId = $RunId
        verification = $Verification
        executionMode = "detached-supervisor"
        supervisorPid = $PID
        startedAtUtc = $startedAt.ToString("O")
        completedAtUtc = $completedAt.ToString("O")
        durationMilliseconds = [math]::Round(($completedAt - $startedAt).TotalMilliseconds)
        exitCode = $exitCode
        status = if ($cancelled) { "cancelled" } elseif ($exitCode -eq 0) { "passed" } else { "failed" }
        failureIds = @($failureIds)
        logPath = $LogPath
        standardErrorPath = $standardErrorPath
        cancellationRequestPath = $CancellationRequestPath
        targetProcessId = $targetProcessId
        targetExitCode = $targetExitCode
        orphanProcessIds = @($orphanProcessIds)
        processAudit = [ordered]@{
            method = 'observed-pid-creation-time-snapshots'
            completed = $processAuditCompleted
            snapshotCount = $processSnapshotCount
            observedProcessIds = @($observedProcesses.Values | ForEach-Object { $_.ProcessId } | Sort-Object -Unique)
        }
    })
}

exit $exitCode
