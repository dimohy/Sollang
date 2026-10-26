[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$regressionRoot = Join-Path $repoRoot 'examples/regression'
$fixtures = @(Get-ChildItem -LiteralPath $regressionRoot -File -Filter '*.slg')
$identityPath = Join-Path $repoRoot 'scripts/contracts/regression-fixture-identities.json'
if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf)) {
    throw 'REGRESSION_FIXTURE_IDENTITY_CONTRACT_MISSING'
}
$identity = Get-Content -LiteralPath $identityPath -Raw -ErrorAction Stop | ConvertFrom-Json
if ($identity.schemaVersion -ne 1 -or $identity.identityPolicy -cne 'numeric-new-with-retained-legacy' -or
    $identity.legacyRevision -cnotmatch '^[a-f0-9]{40}$' -or $identity.legacyFixtureNames -isnot [Array]) {
    throw 'REGRESSION_FIXTURE_IDENTITY_CONTRACT_INVALID'
}
$legacy = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($name in @($identity.legacyFixtureNames)) {
    if ($name -isnot [string] -or $name -cnotmatch '^[a-z][a-z0-9-]*(?:\.[a-z0-9-]+)?\.slg$' -or
        -not $legacy.Add($name)) {
        throw 'REGRESSION_FIXTURE_LEGACY_ID_INVALID'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $regressionRoot $name) -PathType Leaf)) {
        throw "REGRESSION_FIXTURE_LEGACY_ID_MISSING: $name"
    }
}
$unnumbered = @($fixtures | Where-Object {
    $_.Name -cnotmatch '^[0-9]+-[a-z0-9-]+(?:\.[a-z0-9-]+)?\.slg$' -and -not $legacy.Contains($_.Name)
})
if ($unnumbered.Count -gt 0) {
    throw "REGRESSION_FIXTURE_ID_UNREGISTERED: new regression fixtures need numeric prefixes: $(($unnumbered.Name | Sort-Object) -join ', ')"
}

Write-Output "[regression fixture names] PASS $($fixtures.Count)/$($fixtures.Count); retained legacy identities $($legacy.Count)"
