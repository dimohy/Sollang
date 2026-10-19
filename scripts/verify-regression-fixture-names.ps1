[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$regressionRoot = Join-Path (Resolve-Path -LiteralPath $RepositoryRoot).Path 'examples/regression'
$fixtures = @(Get-ChildItem -LiteralPath $regressionRoot -File -Filter '*.slg')
$unnumbered = @($fixtures | Where-Object { $_.Name -cnotmatch '^[0-9]+-[a-z0-9-]+(?:\.[a-z0-9-]+)?\.slg$' })
if ($unnumbered.Count -gt 0) {
    throw "Regression fixtures need numeric prefixes: $(($unnumbered.Name | Sort-Object) -join ', ')"
}

Write-Output "[regression fixture names] PASS $($fixtures.Count)/$($fixtures.Count)"
