[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompletionRecordPath,
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts'))
$completionRecordPath = [IO.Path]::GetFullPath($CompletionRecordPath)
if (-not $completionRecordPath.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "CompletionRecordPath must be under $artifactRoot"
}

$launchRecordPath = "$completionRecordPath.launch.json"
if (-not (Test-Path -LiteralPath $launchRecordPath -PathType Leaf)) {
    throw "launch record is missing: $launchRecordPath"
}
if (Test-Path -LiteralPath $completionRecordPath -PathType Leaf) {
    throw 'The detached verification is already terminal'
}

$launch = Get-Content -LiteralPath $launchRecordPath -Raw | ConvertFrom-Json
$cancellationRequestPath = [IO.Path]::GetFullPath($launch.cancellationRequestPath)
$cancellationAcknowledgementPath = [IO.Path]::GetFullPath($launch.cancellationAcknowledgementPath)
if (-not $cancellationRequestPath.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'launch record cancellation path is outside artifacts'
}
if (-not $cancellationAcknowledgementPath.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    $cancellationAcknowledgementPath -ceq $cancellationRequestPath) {
    throw 'launch record cancellation acknowledgement path is invalid'
}

$supervisor = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$launch.supervisorPid)" -ErrorAction SilentlyContinue
if ($null -eq $supervisor) {
    throw 'The detached supervisor is not running'
}
$expectedLauncher = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'invoke-detached-selfhost-verification.ps1'))
if (-not $supervisor.CommandLine.Contains($expectedLauncher, [StringComparison]::OrdinalIgnoreCase) -or
    -not $supervisor.CommandLine.Contains($launch.runId, [StringComparison]::Ordinal)) {
    throw 'The recorded supervisor PID does not identify the expected run'
}

$request = [ordered]@{
    schemaVersion = 1
    runId = $launch.runId
    requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    requestedByPid = $PID
}
$temporaryPath = "$cancellationRequestPath.tmp-$PID"
$request | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
Move-Item -LiteralPath $temporaryPath -Destination $cancellationRequestPath -Force

$deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
while (-not (Test-Path -LiteralPath $completionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $deadline) {
        throw 'Detached cancellation did not publish a terminal result before the timeout'
    }
    Start-Sleep -Milliseconds 100
}

function Assert-Stage3LateCancellation {
    param(
        [Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][object]$Launch,
        [Parameter(Mandatory)][string]$RequestPath
    )

    if ($Result.verification -cne 'Stage3' -or $Launch.verification -cne 'Stage3' -or
        $Result.cancellationDisposition -cne 'afterCommit' -or
        $Result.status -cne 'passed' -or $Result.exitCode -ne 0 -or $Result.targetExitCode -ne 0 -or
        @($Result.failureIds).Count -ne 0 -or $null -ne $Result.cancellationAcknowledgement -or
        $Result.publicationMayBePartial -ne $false) {
        throw 'Stage3 late cancellation did not complete its publication successfully'
    }
    $commitPath = "$RequestPath.commit.json"
    $publishedPath = "$RequestPath.published.json"
    if (-not (Test-Path -LiteralPath $commitPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $publishedPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $commitPath -Algorithm SHA256).Hash -cne $Result.stage3PublicationCommitSha256 -or
        (Get-FileHash -LiteralPath $publishedPath -Algorithm SHA256).Hash -cne $Result.stage3PublicationCompleteSha256) {
        throw 'Stage3 publication records differ from the supervisor-validated hashes'
    }
    $commit = Get-Content -LiteralPath $commitPath -Raw | ConvertFrom-Json
    $published = Get-Content -LiteralPath $publishedPath -Raw | ConvertFrom-Json
    if ($commit.runId -cne $Launch.runId -or $published.runId -cne $Launch.runId -or
        [int]$commit.targetProcessId -ne [int]$Result.targetProcessId -or
        [int]$published.targetProcessId -ne [int]$Result.targetProcessId -or
        $published.inputFingerprint -cne $commit.inputFingerprint) {
        throw 'Stage3 publication records do not identify the completed run'
    }
}

function Add-Stage3LateCancellationOutcome {
    param([Parameter(Mandatory)][object]$Result)

    $Result | Add-Member -NotePropertyName cancellationRequestOutcome `
        -NotePropertyValue 'accepted-after-publication-commit-not-stopped'
    $Result | Add-Member -NotePropertyName cancellationRequestMessage `
        -NotePropertyValue 'Cancellation was requested after the Stage3 publication commit; verification completed and was not stopped.'
}

$resultText = Get-Content -LiteralPath $completionRecordPath -Raw
$resultSchemaPath = Join-Path $PSScriptRoot 'contracts/detached-selfhost-verification-result.schema.json'
if (-not ($resultText | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw 'Detached completion record does not match its schema'
}
$result = $resultText | ConvertFrom-Json
if ($result.runId -cne $launch.runId -or $result.verification -cne $launch.verification -or
    [int]$result.supervisorPid -ne [int]$launch.supervisorPid -or
    $result.cancellationRequestPath -cne $cancellationRequestPath -or
    $result.cancellationAcknowledgementPath -cne $cancellationAcknowledgementPath -or
    [int]$result.targetProcessId -le 0 -or
    -not $result.processAudit.completed -or @($result.orphanProcessIds).Count -ne 0) {
    throw 'Detached completion record does not identify the active run and completed process tree'
}
$requestOnDisk = Get-Content -LiteralPath $cancellationRequestPath -Raw | ConvertFrom-Json
if ($requestOnDisk.schemaVersion -ne 1 -or $requestOnDisk.runId -cne $launch.runId) {
    throw 'Cancellation request no longer identifies the active run'
}
$afterCommit = $result.verification -ceq 'Stage3' -and
    $result.cancellationDisposition -ceq 'afterCommit'
if ($afterCommit) {
    Assert-Stage3LateCancellation -Result $result -Launch $launch -RequestPath $cancellationRequestPath
    Add-Stage3LateCancellationOutcome -Result $result
} else {
    if ($result.status -cne 'cancelled' -or $result.exitCode -eq 0) {
        throw 'Detached cancellation did not preserve cancelled status and a non-zero exit code'
    }
    if (@($result.failureIds).Count -ne 1 -or $result.failureIds[0] -cne 'CANCELLATION_REQUESTED') {
        throw 'Detached cancellation did not preserve the exact cancellation failure ID'
    }
    if ($result.targetExitCode -ne 130 -or $null -eq $result.cancellationAcknowledgement -or
        $result.cancellationAcknowledgement.runId -cne $launch.runId -or
        [int]$result.cancellationAcknowledgement.targetProcessId -ne [int]$result.targetProcessId) {
        throw 'Detached cancellation did not preserve exact cooperative target acknowledgement'
    }
}

$supervisorDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
while ($null -ne (Get-Process -Id ([int]$launch.supervisorPid) -ErrorAction SilentlyContinue)) {
    if ([DateTimeOffset]::UtcNow -ge $supervisorDeadline) {
        throw 'Detached supervisor remained alive after publishing cancellation'
    }
    Start-Sleep -Milliseconds 50
}

$result | ConvertTo-Json -Depth 8
