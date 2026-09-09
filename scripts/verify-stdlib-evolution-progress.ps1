[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$contractPath = Join-Path $PSScriptRoot "contracts\stdlib-evolution-progress.json"
$evolutionPath = Join-Path $RepositoryRoot "docs\STDLIB_EVOLUTION.md"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or
    $contract.scope -cne "docs/STDLIB_EVOLUTION.md#Prioritized contract backlog") {
    throw "unsupported stdlib evolution progress contract"
}

$allowedStatuses = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$contract.statuses,
    [System.StringComparer]::Ordinal)
if ($allowedStatuses.Count -ne 3 -or
    -not $allowedStatuses.Contains("complete") -or
    -not $allowedStatuses.Contains("in-progress") -or
    -not $allowedStatuses.Contains("blocked")) {
    throw "stdlib evolution progress statuses must be complete, in-progress, and blocked"
}

$declared = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($entry in $contract.contracts) {
    $name = [string]$entry.contract
    $status = [string]$entry.status
    if (-not $allowedStatuses.Contains($status)) {
        throw "unsupported stdlib progress status '$status' for '$name'"
    }
    if (-not $declared.TryAdd($name, $status)) {
        throw "duplicate stdlib progress contract '$name'"
    }
}

$rows = @(Get-Content -LiteralPath $evolutionPath |
    Where-Object { $_ -match '^\| P[0-9] \| (?<contract>[^|]+) \|' })
$documentContracts = @($rows | ForEach-Object {
    if ($_ -notmatch '^\| P[0-9] \| (?<contract>[^|]+) \|') {
        throw "unrecognized stdlib evolution backlog row: $_"
    }
    $Matches.contract.Trim()
})

$missing = @($documentContracts | Where-Object { -not $declared.ContainsKey($_) })
$stale = @($declared.Keys | Where-Object { $_ -notin $documentContracts })
if ($missing.Count -gt 0 -or $stale.Count -gt 0) {
    if ($missing.Count -gt 0) {
        Write-Error "Untracked stdlib evolution contracts:`n$($missing -join "`n")" -ErrorAction Continue
    }
    if ($stale.Count -gt 0) {
        Write-Error "Stale stdlib evolution progress entries:`n$($stale -join "`n")" -ErrorAction Continue
    }
    throw "stdlib evolution progress contract drifted"
}

$counts = @{}
foreach ($status in $allowedStatuses) {
    $counts[$status] = @($declared.Values | Where-Object { $_ -ceq $status }).Count
}
$total = $declared.Count
$completePercent = [Math]::Round(100.0 * $counts["complete"] / $total, 1)
$started = $counts["complete"] + $counts["in-progress"]
$startedPercent = [Math]::Round(100.0 * $started / $total, 1)
$summary = "fully accepted $($counts['complete'])/$total ($completePercent%); in progress $($counts['in-progress'])/$total; blocked $($counts['blocked'])/$total; started $started/$total ($startedPercent%)"

$evolutionText = [regex]::Replace(
    [System.IO.File]::ReadAllText($evolutionPath),
    '\s+',
    ' ')
$normalizedSummary = [regex]::Replace($summary, '\s+', ' ')
if (-not $evolutionText.Contains($normalizedSummary, [System.StringComparison]::Ordinal)) {
    throw "stdlib evolution progress summary drifted; expected '$summary'"
}

Write-Host "[stdlib evolution progress] PASS $summary."
