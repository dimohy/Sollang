[CmdletBinding()]
param(
    [ValidateSet("Inventory", "Check", "Write")]
    [string]$Mode = "Inventory"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $PSScriptRoot "contracts/llvm-emitter-modules.json"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1) {
    throw "Unsupported LLVM emitter module contract schema '$($contract.schemaVersion)'."
}

$facade = [string]$contract.facade
$insertions = @($contract.insertions)
if ([string]::IsNullOrWhiteSpace($facade) -or $insertions.Count -eq 0) {
    throw "LLVM emitter module contract requires a facade and at least one insertion."
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
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$AllowInsert
    )

    $updated = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) { $updated.Add($line) }

    foreach ($insertion in $insertions) {
        $owner = [string]$insertion.owner
        $module = [string]$insertion.module
        $ownerCount = Get-ExactCount -Lines $updated.ToArray() -Value $owner
        $moduleCount = Get-ExactCount -Lines $updated.ToArray() -Value $module
        if ($ownerCount -ne 1) {
            throw "$Identity contains module owner '$owner' $ownerCount times; expected exactly once."
        }
        if ($moduleCount -gt 1) {
            throw "$Identity contains module '$module' $moduleCount times; expected at most once."
        }
        if ($moduleCount -eq 0) {
            if (-not $AllowInsert) {
                throw "$Identity is missing module '$module' after '$owner'."
            }
            $updated.Insert($updated.IndexOf($owner) + 1, $module)
        } elseif ($updated.IndexOf($module) -ne $updated.IndexOf($owner) + 1) {
            throw "$Identity must place module '$module' immediately after '$owner'."
        }
    }

    $updated.ToArray()
}

# The updater contract itself must prove insertion, idempotence, missing-entry
# rejection, duplicate rejection, and ordering before repository writes.
$controlOwner = [string]$insertions[0].owner
$controlModule = [string]$insertions[0].module
$inserted = Get-UpdatedManifestLines -Lines @($controlOwner) -Identity "insertion control" -AllowInsert $true
$insertedAgain = Get-UpdatedManifestLines -Lines $inserted -Identity "idempotence control" -AllowInsert $true
if (($inserted -join "`n") -cne ($insertedAgain -join "`n")) {
    throw "LLVM emitter module updater is not idempotent."
}
foreach ($negative in @(
    @($controlOwner, $controlOwner),
    @($controlOwner, $controlModule, $controlModule),
    @($controlOwner, "middle.slg", $controlModule)
)) {
    $rejected = $false
    try {
        Get-UpdatedManifestLines -Lines $negative -Identity "negative control" -AllowInsert $false | Out-Null
    } catch {
        $rejected = $true
    }
    if (-not $rejected) { throw "LLVM emitter module negative control was accepted." }
}

foreach ($path in @($facade) + @($contract.modules)) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $path) -PathType Leaf)) {
        throw "LLVM emitter module contract source is missing: $path"
    }
}

$manifestPaths = @(
    Get-ChildItem (Join-Path $repositoryRoot "examples/regression/expected") -Filter "*.sources.txt"
    Get-Item (Join-Path $repositoryRoot "selfhost/browser_driver.sources.txt")
    Get-Item (Join-Path $repositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    Get-Item (Join-Path $repositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt")
)

$plans = [System.Collections.Generic.List[object]]::new()
foreach ($manifestPath in $manifestPaths) {
    $lines = [IO.File]::ReadAllLines($manifestPath.FullName)
    if ((Get-ExactCount -Lines $lines -Value $facade) -eq 0) { continue }
    if ((Get-ExactCount -Lines $lines -Value $facade) -ne 1) {
        throw "$($manifestPath.FullName) must contain facade '$facade' exactly once."
    }
    $updated = Get-UpdatedManifestLines `
        -Lines $lines `
        -Identity $manifestPath.FullName `
        -AllowInsert ($Mode -ne "Check")
    $plans.Add([pscustomobject]@{
        Path = $manifestPath.FullName
        Lines = $updated
        Changed = ($lines -join "`n") -cne ($updated -join "`n")
    })
}

if ($plans.Count -ne [int]$contract.expectedManifests) {
    throw "LLVM emitter module manifest inventory changed: expected $($contract.expectedManifests), actual $($plans.Count)."
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
Write-Host "[LLVM emitter module manifest updater] PASS mode=$Mode manifests=$($plans.Count) changed=$changedCount."
