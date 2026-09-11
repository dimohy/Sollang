param(
    [Parameter(Mandatory)]
    [ValidateSet("Stage2", "Stage3", "Stage2Linux", "Stage3Linux", "BrowserStage2", "Incremental", "Probe")]
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
    [ValidateSet("Pass", "Fail", "Wait")]
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
            "-IncrementalFixture", (ConvertTo-ProcessArgument $IncrementalFixture)
        )
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
$orphanProcessIds = [Collections.Generic.List[int]]::new()
$standardErrorPath = "$LogPath.stderr"

function Get-DescendantProcessIds {
    param(
        [Parameter(Mandatory)][int]$RootProcessId,
        [Parameter(Mandatory)][datetime]$CreatedAfter
    )
    $records = @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, CreationDate)
    $pending = [Collections.Generic.Queue[int]]::new()
    $found = [Collections.Generic.HashSet[int]]::new()
    $pending.Enqueue($RootProcessId)
    while ($pending.Count -gt 0) {
        $parent = $pending.Dequeue()
        foreach ($record in $records) {
            if ([int]$record.ParentProcessId -ne $parent) { continue }
            if ([datetime]$record.CreationDate -lt $CreatedAfter) { continue }
            $child = [int]$record.ProcessId
            if ($found.Add($child)) { $pending.Enqueue($child) }
        }
    }
    return @($found)
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
                "-SeedMode", $SeedMode,
                "-CompareStage2:`$false"
            )
        }
        "Probe" { $targetArguments += @("-Outcome", $ProbeOutcome) }
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
    while (-not $targetProcess.WaitForExit(1000)) {
        $request = Read-CancellationRequest
        if ($null -eq $request) { continue }

        $capturedProcessIds = @($targetProcess.Id) + @(Get-DescendantProcessIds `
            -RootProcessId $targetProcess.Id `
            -CreatedAfter $targetProcess.StartTime)
        try {
            $targetProcess.Kill($true)
        }
        catch [InvalidOperationException] {
            # The exact target may have become terminal after the wait interval.
        }
        if (-not $targetProcess.WaitForExit(10000)) {
            throw "Cancellation did not stop the supervised process within 10 seconds"
        }
        Start-Sleep -Milliseconds 100
        foreach ($processId in $capturedProcessIds | Select-Object -Unique) {
            if ($null -ne (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
                $orphanProcessIds.Add($processId)
            }
        }
        if ($orphanProcessIds.Count -ne 0) {
            throw "Cancellation left $($orphanProcessIds.Count) captured process(es) running"
        }
        $cancelled = $true
        $exitCode = 130
        $failureIds.Add("CANCELLATION_REQUESTED")
        break
    }
    if (-not $cancelled) {
        $exitCode = $targetProcess.ExitCode
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
            foreach ($match in [regex]::Matches($line, '(?i)\b(?:E\d+|\d{3,4}-[a-z0-9][a-z0-9-]*|AS-[A-Z]+-\d+(?:-[A-Z0-9-]+)?|SUPERVISOR_EXECUTION_FAILURE)\b')) {
                if (-not $failureIds.Contains($match.Value)) {
                    $failureIds.Add($match.Value)
                }
            }
        }
    }

    $completedAt = [DateTimeOffset]::UtcNow
    Write-JsonAtomically -Path $CompletionRecordPath -Value ([ordered]@{
        schemaVersion = 1
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
        orphanProcessIds = @($orphanProcessIds)
    })
}

exit $exitCode
