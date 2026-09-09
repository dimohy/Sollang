[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompletionRecordPath,
    [ValidateRange(1, 120)][int]$TimeoutSeconds = 30
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
if (-not $cancellationRequestPath.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'launch record cancellation path is outside artifacts'
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

$result = Get-Content -LiteralPath $completionRecordPath -Raw | ConvertFrom-Json
if ($result.status -cne 'cancelled' -or $result.exitCode -eq 0) {
    throw 'Detached cancellation did not preserve cancelled status and a non-zero exit code'
}
if (@($result.failureIds).Count -ne 1 -or $result.failureIds[0] -cne 'CANCELLATION_REQUESTED') {
    throw 'Detached cancellation did not preserve the exact cancellation failure ID'
}
if (@($result.orphanProcessIds).Count -ne 0) {
    throw 'Detached cancellation left an orphan process'
}

$supervisorDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
while ($null -ne (Get-Process -Id ([int]$launch.supervisorPid) -ErrorAction SilentlyContinue)) {
    if ([DateTimeOffset]::UtcNow -ge $supervisorDeadline) {
        throw 'Detached supervisor remained alive after publishing cancellation'
    }
    Start-Sleep -Milliseconds 50
}

$result | ConvertTo-Json -Depth 8
