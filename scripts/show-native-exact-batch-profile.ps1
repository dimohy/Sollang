[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Profile,
    [ValidateRange(1, 50)][int]$Top = 10
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$schemaPath = Join-Path $scriptRoot "contracts\native-exact-batch-profile.schema.json"
$profilePath = (Resolve-Path -LiteralPath $Profile).Path
$json = [System.IO.File]::ReadAllText($profilePath)
if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "native exact batch profile does not match its schema: $profilePath"
}
$data = $json | ConvertFrom-Json
$effectiveCores = if ($data.wallMilliseconds -eq 0) {
    0.0
} else {
    [double]$data.hostVisibleCpuMilliseconds / [double]$data.wallMilliseconds
}
Write-Host ("[native exact profile] success={0} completed={1}/{2} wall={3:N0}ms host-visible CPU={4:N0}ms ({5:N2} effective cores) peak={6:N1}MiB processes={7} cache={8}." -f `
    $data.success,
    $data.completedFixtures,
    $data.totalFixtures,
    $data.wallMilliseconds,
    $data.hostVisibleCpuMilliseconds,
    $effectiveCores,
    ($data.peakAggregateWorkingSetBytes / 1MB),
    $data.maximumObservedProcessCount,
    $data.cacheHitCount)
if ($data.PSObject.Properties.Name -contains 'unavailableCpuSamples') {
    Write-Host "[native exact profile] unavailable CPU samples=$($data.unavailableCpuSamples); excluded from observed CPU totals."
}

$previousElapsed = 0L
$gaps = foreach ($event in $data.progress) {
    $gap = [long]$event.elapsedMilliseconds - $previousElapsed
    $previousElapsed = [long]$event.elapsedMilliseconds
    [pscustomobject]@{
        Fixture = $event.fixture
        Status = $event.status
        Completed = $event.completed
        Total = $event.total
        CompletionGapMilliseconds = $gap
        ElapsedMilliseconds = [long]$event.elapsedMilliseconds
    }
}
if ($gaps.Count -gt 0) {
    Write-Host "[native exact profile] Largest no-completion intervals follow; these identify long-tail windows, not isolated fixture durations."
    $gaps |
        Sort-Object CompletionGapMilliseconds -Descending |
        Select-Object -First $Top |
        ForEach-Object {
            Write-Host ("  {0:N0}ms ending at {1}/{2} {3} {4} (elapsed {5:N0}ms)" -f `
                $_.CompletionGapMilliseconds,
                $_.Completed,
                $_.Total,
                $_.Status,
                $_.Fixture,
                $_.ElapsedMilliseconds)
        }
}
