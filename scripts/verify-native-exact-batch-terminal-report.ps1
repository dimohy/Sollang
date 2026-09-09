[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Stage2Report,
    [Parameter(Mandatory)][string]$Stage3Report,
    [Parameter(Mandatory)][string]$Stage2Compiler,
    [Parameter(Mandatory)][string]$Stage3Compiler,
    [ValidateRange(1, 100000)][int]$ExpectedTotal = 357
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-TerminalBatchReport {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedLabel,
        [Parameter(Mandatory)][string]$ExpectedCompilerHash
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $report = [IO.File]::ReadAllText($resolved) | ConvertFrom-Json
    if ($report.schemaVersion -ne 1 -or $report.label -cne $ExpectedLabel -or
        $report.platform -cne 'windows' -or $report.state -cne 'passed') {
        throw "$ExpectedLabel batch report is not a passed Windows schema-v1 result: $resolved"
    }
    if ($report.compilerSha256 -cne $ExpectedCompilerHash) {
        throw "$ExpectedLabel batch compiler hash does not match its executable"
    }
    if ($report.total -ne $ExpectedTotal -or $report.completed -ne $ExpectedTotal -or
        $report.passed -ne $ExpectedTotal -or $report.failed -ne 0 -or $report.missing -ne 0) {
        throw "$ExpectedLabel batch totals are incomplete or inconsistent"
    }

    $results = @($report.results)
    if ($results.Count -ne $ExpectedTotal) {
        throw "$ExpectedLabel batch result count differs from the declared total"
    }
    $names = @($results | ForEach-Object { $_.Fixture })
    if (@($names | Sort-Object -Unique).Count -ne $ExpectedTotal) {
        throw "$ExpectedLabel batch fixture names are not unique"
    }
    $failedResults = @($results | Where-Object { $_.Success -ne $true -or -not [string]::IsNullOrEmpty([string]$_.Error) })
    if ($failedResults.Count -ne 0) {
        throw "$ExpectedLabel batch contains failed or diagnostic-bearing results"
    }
    return [pscustomobject]@{ Label = $ExpectedLabel; Fixtures = @($names | Sort-Object) }
}

$stage2Hash = (Get-FileHash -LiteralPath (Resolve-Path -LiteralPath $Stage2Compiler).Path -Algorithm SHA256).Hash
$stage3Hash = (Get-FileHash -LiteralPath (Resolve-Path -LiteralPath $Stage3Compiler).Path -Algorithm SHA256).Hash
$stage2 = Read-TerminalBatchReport -Path $Stage2Report -ExpectedLabel 'stage2' -ExpectedCompilerHash $stage2Hash
$stage3 = Read-TerminalBatchReport -Path $Stage3Report -ExpectedLabel 'stage3' -ExpectedCompilerHash $stage3Hash
if (($stage2.Fixtures -join "`n") -cne ($stage3.Fixtures -join "`n")) {
    throw 'Stage2 and Stage3 native-exact fixture sets differ'
}

Write-Host "[native exact terminal report] PASS stage2 $ExpectedTotal/$ExpectedTotal and stage3 $ExpectedTotal/$ExpectedTotal."

