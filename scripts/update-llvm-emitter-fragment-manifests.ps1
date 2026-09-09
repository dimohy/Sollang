[CmdletBinding()]
param(
    [ValidateSet("Inventory", "Check", "Write", "RefreshCounts")]
    [string]$Mode = "Inventory"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $PSScriptRoot "contracts/selfhost-fragments.json"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1) {
    throw "Unsupported selfhost fragment contract schema '$($contract.schemaVersion)'."
}
$insertions = @($contract.fragments | ForEach-Object {
    [pscustomobject]@{
        Owner = [string]$_.owner
        Fragment = [string]$_.fragment
        ExpectedManifests = [int]$_.expectedManifests
    }
})
if ($insertions.Count -eq 0) {
    throw "Selfhost fragment contract contains no owner-to-fragment insertion."
}

function Get-ExactCount {
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Value
    )

    @($Lines | Where-Object { $_ -ceq $Value }).Count
}

function Get-UpdatedManifestLines {
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$ManifestName,
        [Parameter(Mandatory)][bool]$AllowInsert
    )

    $updated = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        $updated.Add($line)
    }

    foreach ($insertion in $insertions) {
        $ownerCount = Get-ExactCount -Lines $updated.ToArray() -Value $insertion.Owner
        $fragmentCount = Get-ExactCount -Lines $updated.ToArray() -Value $insertion.Fragment
        if ($ownerCount -gt 1) {
            throw "$ManifestName contains owner '$($insertion.Owner)' $ownerCount times; expected at most once."
        }
        if ($fragmentCount -gt 1) {
            throw "$ManifestName contains fragment '$($insertion.Fragment)' $fragmentCount times; expected at most once."
        }
        if ($ownerCount -eq 0) {
            if ($fragmentCount -ne 0) {
                throw "$ManifestName contains orphan fragment '$($insertion.Fragment)' without '$($insertion.Owner)'."
            }
            continue
        }
        if ($fragmentCount -eq 0) {
            if (-not $AllowInsert) {
                throw "$ManifestName is missing '$($insertion.Fragment)' after '$($insertion.Owner)'."
            }
            $ownerIndex = $updated.IndexOf($insertion.Owner)
            $updated.Insert($ownerIndex + 1, $insertion.Fragment)
            continue
        }

        $ownerIndex = $updated.IndexOf($insertion.Owner)
        $fragmentIndex = $updated.IndexOf($insertion.Fragment)
        if ($fragmentIndex -ne $ownerIndex + 1) {
            throw "$ManifestName must place '$($insertion.Fragment)' immediately after '$($insertion.Owner)'."
        }
    }

    $updated.ToArray()
}

# Pure in-memory controls keep the updater contract independent of repository
# state. They prove insertion, idempotence, duplicate rejection, and orphan
# rejection before any manifest path is opened for writing.
$positive = Get-UpdatedManifestLines `
    -Lines @($insertions[0].Owner, $insertions[1].Owner) `
    -ManifestName "positive control" `
    -AllowInsert $true
$positiveAgain = Get-UpdatedManifestLines `
    -Lines $positive `
    -ManifestName "idempotence control" `
    -AllowInsert $true
if (($positive -join "`n") -cne ($positiveAgain -join "`n")) {
    throw "manifest updater idempotence control changed a complete manifest"
}

foreach ($negative in @(
    [pscustomobject]@{
        Name = "duplicate owner control"
        Lines = @($insertions[0].Owner, $insertions[0].Owner)
    }
    [pscustomobject]@{
        Name = "duplicate fragment control"
        Lines = @($insertions[0].Owner, $insertions[0].Fragment, $insertions[0].Fragment)
    }
    [pscustomobject]@{
        Name = "orphan fragment control"
        Lines = @($insertions[0].Fragment)
    }
)) {
    $rejected = $false
    try {
        Get-UpdatedManifestLines `
            -Lines $negative.Lines `
            -ManifestName $negative.Name `
            -AllowInsert $true | Out-Null
    } catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw "$($negative.Name) was accepted"
    }
}

$manifestPaths = @(
    Get-ChildItem (Join-Path $repositoryRoot "examples/regression/expected") -Filter "*.sources.txt"
    Get-Item (Join-Path $repositoryRoot "selfhost/browser_driver.sources.txt")
    Get-Item (Join-Path $repositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    Get-Item (Join-Path $repositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt")
)

if ($Mode -in @("Write", "RefreshCounts")) {
    foreach ($insertion in $insertions) {
        $fragmentPath = Join-Path $repositoryRoot $insertion.Fragment
        if (-not (Test-Path -LiteralPath $fragmentPath -PathType Leaf)) {
            throw "planned selfhost fragment is missing: $($insertion.Fragment)"
        }
    }
}

$plans = [System.Collections.Generic.List[object]]::new()
$affected = 0
$affectedByFragment = [System.Collections.Generic.Dictionary[string, int]]::new(
    [System.StringComparer]::Ordinal)
foreach ($insertion in $insertions) {
    $affectedByFragment.Add($insertion.Fragment, 0)
}
foreach ($manifestPath in $manifestPaths) {
    $lines = [IO.File]::ReadAllLines($manifestPath.FullName)
    # Inventory the complete projected chain, not only owners already present
    # in the original manifest. A newly inserted fragment may itself own the
    # next fragment in the same deterministic split.
    $projected = Get-UpdatedManifestLines `
        -Lines $lines `
        -ManifestName $manifestPath.Name `
        -AllowInsert $true
    $hasOwner = $false
    foreach ($insertion in $insertions) {
        if ((Get-ExactCount -Lines $projected -Value $insertion.Fragment) -gt 0) {
            $hasOwner = $true
            $affectedByFragment[$insertion.Fragment] += 1
        }
    }
    if (-not $hasOwner) {
        continue
    }

    $affected += 1
    if ($Mode -eq "Inventory") {
        continue
    }

    $updated = Get-UpdatedManifestLines `
        -Lines $lines `
        -ManifestName $manifestPath.Name `
        -AllowInsert ($Mode -eq "Write")
    $plans.Add([pscustomobject]@{
        Path = $manifestPath.FullName
        Lines = $updated
        Changed = ($lines -join "`n") -cne ($updated -join "`n")
    })
}

foreach ($insertion in $insertions) {
    $actual = $affectedByFragment[$insertion.Fragment]
    if ($actual -ne $insertion.ExpectedManifests -and $Mode -ne "RefreshCounts") {
        throw "Selfhost fragment '$($insertion.Fragment)' manifest inventory changed: expected $($insertion.ExpectedManifests), actual $actual"
    }
}

if ($Mode -eq "RefreshCounts") {
    # All existing manifests have passed the non-inserting validation above.
    # Refresh only the inventory counts after adding or removing fixtures.
    $contractText = [IO.File]::ReadAllText($contractPath)
    $contractText = [regex]::Replace(
        $contractText,
        '("fragment"\s*:\s*"([^"]+)"\s*,\s*"expectedManifests"\s*:\s*)[0-9]+',
        { param($match) $match.Groups[1].Value + $affectedByFragment[$match.Groups[2].Value] })
    [IO.File]::WriteAllText($contractPath, $contractText, [Text.UTF8Encoding]::new($false))
}

if ($Mode -eq "Write") {
    $encoding = [Text.UTF8Encoding]::new($false)
    foreach ($plan in $plans) {
        if ($plan.Changed) {
            [IO.File]::WriteAllLines($plan.Path, $plan.Lines, $encoding)
        }
    }
}

$changedCount = @($plans | Where-Object Changed).Count
Write-Host "[selfhost fragment manifest updater] PASS mode=$Mode fragments=$($insertions.Count) affected=$affected changed=$changedCount."
