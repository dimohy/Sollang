param(
    [Parameter(Mandatory)]
    [string]$CompletionRecordPath
)

$ErrorActionPreference = "Stop"

function Read-SharedText {
    param([Parameter(Mandatory)][string]$Path)
    $stream = [IO.FileStream]::new(
        $Path,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
    try {
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true, 4096, $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    finally {
        $stream.Dispose()
    }
}

$completionRecordPath = [IO.Path]::GetFullPath($CompletionRecordPath)
$launchRecordPath = "$completionRecordPath.launch.json"
if (-not (Test-Path -LiteralPath $launchRecordPath -PathType Leaf)) {
    throw "launch record is missing: $launchRecordPath"
}

$launch = Get-Content -LiteralPath $launchRecordPath -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $launch.logPath -PathType Leaf)) {
    throw "durable log is missing: $($launch.logPath)"
}

$logText = Read-SharedText -Path $launch.logPath
$stageName = $launch.verification.ToString().ToLowerInvariant()
$total = if ($stageName -eq "stage2") { 7 } elseif ($stageName -eq "stage3") { 3 } else { 1 }
$ordinals = [regex]::Matches($logText, "(?im)^\[$stageName (?<ordinal>\d+)/$total\]") |
    ForEach-Object { [int]$_.Groups["ordinal"].Value }
$current = if (@($ordinals).Count -gt 0) { [int](($ordinals | Measure-Object -Maximum).Maximum) } else { 0 }
$result = if (Test-Path -LiteralPath $completionRecordPath -PathType Leaf) {
    Get-Content -LiteralPath $completionRecordPath -Raw | ConvertFrom-Json
} else {
    $null
}
$supervisorRunning = $null -ne (Get-Process -Id ([int]$launch.supervisorPid) -ErrorAction SilentlyContinue)
$status = if ($null -ne $result) {
    $result.status
} elseif ($supervisorRunning) {
    "running"
} else {
    "interrupted-without-result"
}
$completed = if ($status -eq "passed") {
    $total
} elseif ($current -gt 0) {
    $current - 1
} else {
    0
}
$reportedFailureIds = [Collections.Generic.List[string]]::new()
if ($null -ne $result) {
    foreach ($failureId in @($result.failureIds)) {
        $reportedFailureIds.Add($failureId)
    }
}

[ordered]@{
    runId = $launch.runId
    verification = $launch.verification
    status = $status
    completed = $completed
    total = $total
    percent = [math]::Round(($completed * 100.0) / $total, 1)
    currentStage = $current
    supervisorPid = [int]$launch.supervisorPid
    supervisorRunning = $supervisorRunning
    exitCode = if ($null -ne $result) { $result.exitCode } else { $null }
    failureIds = $reportedFailureIds
    logLength = (Get-Item -LiteralPath $launch.logPath).Length
    logLastWriteTimeUtc = (Get-Item -LiteralPath $launch.logPath).LastWriteTimeUtc.ToString("O")
} | ConvertTo-Json -Depth 5
