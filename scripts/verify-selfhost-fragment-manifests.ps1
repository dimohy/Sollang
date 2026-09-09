[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $PSScriptRoot "contracts/selfhost-fragments.json"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1) {
    throw "Unsupported selfhost fragment contract schema '$($contract.schemaVersion)'."
}

function Assert-FragmentOrder {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Fragment,
        [Parameter(Mandatory)][string]$Identity
    )

    $ownerIndexes = @()
    $fragmentIndexes = @()
    for ($index = 0; $index -lt $Lines.Length; $index++) {
        if ($Lines[$index] -ceq $Owner) { $ownerIndexes += $index }
        if ($Lines[$index] -ceq $Fragment) { $fragmentIndexes += $index }
    }
    if ($ownerIndexes.Count -gt 1 -or $fragmentIndexes.Count -gt 1) {
        throw "$Identity duplicates owner '$Owner' or fragment '$Fragment'."
    }
    if ($ownerIndexes.Count -eq 0) {
        if ($fragmentIndexes.Count -ne 0) {
            throw "$Identity contains orphan fragment '$Fragment'."
        }
        return $false
    }
    if ($fragmentIndexes.Count -ne 1) {
        throw "$Identity is missing fragment '$Fragment' after '$Owner'."
    }
    if ($fragmentIndexes[0] -ne $ownerIndexes[0] + 1) {
        throw "$Identity must place '$Fragment' immediately after '$Owner'."
    }
    return $true
}

# Prove duplicate, orphan, missing, and non-adjacent manifests fail before
# repository manifests are inspected.
$controlOwner = "owner.slg"
$controlFragment = "fragment.slg"
if (-not (Assert-FragmentOrder -Lines @($controlOwner, $controlFragment) -Owner $controlOwner -Fragment $controlFragment -Identity "positive control")) {
    throw "Selfhost fragment positive control did not find its owner."
}
foreach ($control in @(
    @($controlOwner, $controlOwner, $controlFragment),
    @($controlFragment),
    @($controlOwner),
    @($controlOwner, "middle.slg", $controlFragment)
)) {
    $rejected = $false
    try {
        Assert-FragmentOrder -Lines $control -Owner $controlOwner -Fragment $controlFragment -Identity "negative control" | Out-Null
    } catch {
        $rejected = $true
    }
    if (-not $rejected) { throw "Selfhost fragment negative control was accepted." }
}

$manifestPaths = @(
    Get-ChildItem (Join-Path $repositoryRoot "examples/regression/expected") -Filter "*.sources.txt"
    Get-Item (Join-Path $repositoryRoot "selfhost/browser_driver.sources.txt")
    Get-Item (Join-Path $repositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    Get-Item (Join-Path $repositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt")
)

foreach ($entry in $contract.fragments) {
    if ([string]::IsNullOrWhiteSpace($entry.owner) -or [string]::IsNullOrWhiteSpace($entry.fragment) -or [string]::IsNullOrWhiteSpace($entry.defectId)) {
        throw "Every selfhost fragment contract requires owner, fragment, and defectId."
    }
    if ($entry.expectedManifests -lt 1) { throw "Invalid expected manifest count for '$($entry.fragment)'." }
    foreach ($source in @($entry.owner, $entry.fragment)) {
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $source) -PathType Leaf)) {
            throw "Selfhost fragment source is missing: $source"
        }
    }
    $affected = 0
    foreach ($manifestPath in $manifestPaths) {
        $lines = [IO.File]::ReadAllLines($manifestPath.FullName)
        if (Assert-FragmentOrder -Lines $lines -Owner $entry.owner -Fragment $entry.fragment -Identity $manifestPath.FullName) {
            $affected += 1
        }
    }
    if ($affected -ne $entry.expectedManifests) {
        throw "Selfhost fragment '$($entry.fragment)' expected $($entry.expectedManifests) manifests, actual $affected."
    }
}

Write-Host "PASS selfhost fragment manifests: fragments=$($contract.fragments.Count), manifests=$($manifestPaths.Count)"
