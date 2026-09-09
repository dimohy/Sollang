[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 100000)][int]$ExpectedPerGeneration = 357
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($OutputDirectory)

function Read-GenerationProgress([string]$Label) {
    $path = Join-Path $root "$Label-batch-results.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [pscustomobject]@{ label = $Label; state = 'pending'; completed = 0; passed = 0; failed = 0; missing = $ExpectedPerGeneration; total = $ExpectedPerGeneration }
    }
    $report = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    if ($report.schemaVersion -ne 1 -or $report.label -cne $Label -or $report.platform -cne 'windows' -or
        $report.total -ne $ExpectedPerGeneration -or $report.completed -lt 0 -or $report.completed -gt $report.total -or
        $report.passed -lt 0 -or $report.failed -lt 0 -or $report.missing -lt 0 -or
        $report.completed -ne ($report.passed + $report.failed) -or $report.missing -ne ($report.total - $report.completed) -or
        @($report.results).Count -ne $report.completed) {
        throw "invalid native-exact progress report: $path"
    }
    [pscustomobject]@{ label = $Label; state = $report.state; completed = [int]$report.completed; passed = [int]$report.passed; failed = [int]$report.failed; missing = [int]$report.missing; total = [int]$report.total }
}

$generations = @((Read-GenerationProgress 'stage2'), (Read-GenerationProgress 'stage3'))
$completed = [int](($generations | Measure-Object completed -Sum).Sum)
$total = $ExpectedPerGeneration * 2
[pscustomobject]@{
    schemaVersion = 1
    completed = $completed
    total = $total
    percent = [Math]::Round(($completed * 100.0) / $total, 1)
    failed = [int](($generations | Measure-Object failed -Sum).Sum)
    generations = $generations
} | ConvertTo-Json -Depth 5

