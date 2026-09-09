[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$contractPath = Join-Path $PSScriptRoot "contracts\sys-process-global-api.json"
$allowedCategories = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("factory", "current-process", "environment-query"),
    [System.StringComparer]::Ordinal)
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -ne "sys.process") {
    throw "unsupported sys.process global API contract schema or scope"
}

$declared = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($entry in $contract.entries) {
    $api = [string]$entry.api
    $category = [string]$entry.category
    if (-not $allowedCategories.Contains($category)) {
        throw "unsupported sys.process category '$category' for '$api'"
    }
    if (-not $declared.TryAdd($api, $category)) {
        throw "duplicate sys.process global API contract entry: $api"
    }
}

$discovered = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
$declarationPattern = '^public\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)(?:<[^>]+>)?(?:\s+[^:]*)?:'
foreach ($relativeSource in $contract.sources) {
    $source = Join-Path $RepositoryRoot ([string]$relativeSource)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "sys.process contract source is missing: $source"
    }
    $lines = Get-Content -LiteralPath $source
    $namespace = $null
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^namespace\s+(?<namespace>[A-Za-z_][A-Za-z0-9_.]*)\s*$') {
            $namespace = $Matches.namespace
            continue
        }
        if ($line -notmatch $declarationPattern) {
            if (($line -match '^public\s+') -and
                ($line -notmatch '^public\s+(?:struct|enum|trait)\s+')) {
                throw "unrecognized sys.process public declaration at $($source):$($index + 1)"
            }
            continue
        }
        if ($namespace -ne "sys.process") {
            throw "sys.process contract source declared unexpected namespace '$namespace' at $($source):$($index + 1)"
        }
        $api = "$namespace.$($Matches.name)"
        $location = "$($source):$($index + 1)"
        if (-not $discovered.TryAdd($api, $location)) {
            throw "duplicate sys.process public global function '$api' at $location"
        }
    }
}

$unclassified = @($discovered.Keys |
    Where-Object { -not $declared.ContainsKey($_) } |
    Sort-Object)
$stale = @($declared.Keys |
    Where-Object { -not $discovered.ContainsKey($_) } |
    Sort-Object)
if ($unclassified.Count -gt 0 -or $stale.Count -gt 0) {
    if ($unclassified.Count -gt 0) {
        Write-Error "Unclassified sys.process global APIs:`n$($unclassified -join "`n")" -ErrorAction Continue
    }
    if ($stale.Count -gt 0) {
        Write-Error "Stale sys.process global API contract entries:`n$($stale -join "`n")" -ErrorAction Continue
    }
    throw "sys.process instance-first API contract drifted"
}

Write-Host "[sys.process instance policy] PASS $($discovered.Count) reviewed global boundaries; execution remains instance-owned."
