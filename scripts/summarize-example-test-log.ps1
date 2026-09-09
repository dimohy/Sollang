[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LogPath,
    [string]$OutputPath = '',
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$resolvedLog = (Resolve-Path -LiteralPath $LogPath).Path
$logStream = [IO.File]::Open($resolvedLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
$reader = [IO.StreamReader]::new($logStream)
try { $logText = $reader.ReadToEnd() } finally { $reader.Dispose() }
$catalog = [regex]::Match($logText, '(?m)^\[catalog\].*total-fixtures=(\d+)\r?$')
if (-not $catalog.Success) { throw 'Example log has no authoritative fixture catalog.' }
$catalogTotal = [int]$catalog.Groups[1].Value
$selection = [regex]::Match($logText, '(?m)^\[0/(\d+)\] Running .+\r?$')
if (-not $selection.Success) { throw 'Example log has no selected fixture denominator.' }
$total = [int]$selection.Groups[1].Value
if ($total -le 0 -or $total -gt $catalogTotal) { throw 'Selected fixture denominator is outside the catalog.' }
$results = @([regex]::Matches($logText, '(?m)^\[(\d+)/(\d+)\] (PASS|FAIL) (.+?)\r?$') | ForEach-Object {
    if ([int]$_.Groups[2].Value -ne $total) { throw 'Result denominator disagrees with selection.' }
    if ([int]$_.Groups[1].Value -lt 1 -or [int]$_.Groups[1].Value -gt $total) { throw 'Result ordinal is outside the selection.' }
    [pscustomobject]@{ ordinal = [int]$_.Groups[1].Value; status = $_.Groups[3].Value; detail = $_.Groups[4].Value }
})
if (@($results | Group-Object ordinal | Where-Object Count -gt 1).Count -gt 0) {
    throw 'Duplicate result ordinals: use one runner execution per log.'
}
$failures = @([regex]::Matches($logText, '(?m)^FAIL ([^:\r\n]+): ([^\r\n]+)\r?$') | ForEach-Object {
    [pscustomobject]@{ fixture = $_.Groups[1].Value; reason = $_.Groups[2].Value }
})
$passed = @($results | Where-Object status -eq 'PASS').Count
$failed = @($results | Where-Object status -eq 'FAIL').Count
$failureKinds = @($failures | Group-Object reason | Sort-Object Count -Descending | ForEach-Object {
    [pscustomobject]@{ reason = $_.Name; count = $_.Count }
})
$report = [ordered]@{
    schemaVersion = 1
    sourceLog = $resolvedLog
    observedAtUtc = [DateTime]::UtcNow.ToString('O')
    logTextSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($logText)))
    total = $total
    catalogTotal = $catalogTotal
    processed = $results.Count
    passed = $passed
    failed = $failed
    passPercent = [Math]::Round(100.0 * $passed / $total, 1)
    processedPercent = [Math]::Round(100.0 * $results.Count / $total, 1)
    observedResultsComplete = $results.Count -eq $total
    failureKinds = $failureKinds
    failures = $failures
}
$json = $report | ConvertTo-Json -Depth 5
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $reportPath = [IO.Path]::GetFullPath($OutputPath)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($reportPath)) | Out-Null
    [IO.File]::WriteAllText($reportPath, $json + "`n", [Text.UTF8Encoding]::new($false))
}
if ($AsJson) { $json } else {
    Write-Output "[examples] passed=$passed/$total ($($report.passPercent)%); failed=$failed; processed=$($results.Count)/$total ($($report.processedPercent)%)."
    foreach ($kind in $failureKinds) { Write-Output "[failure kind] $($kind.count): $($kind.reason)" }
}
