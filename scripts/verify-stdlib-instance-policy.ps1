[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot "verify-sys-process-instance-policy.ps1") -RepositoryRoot $RepositoryRoot

$contractPath = Join-Path $PSScriptRoot "contracts\stdlib-global-api.json"
$stdlibRoot = Join-Path $RepositoryRoot "stdlib\std"
$allowedCategories = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("constant", "factory", "parser", "flow-adapter", "migration-debt"),
    [System.StringComparer]::Ordinal)

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "stdlib global API contract is missing: $contractPath"
}
if (-not (Test-Path -LiteralPath $stdlibRoot -PathType Container)) {
    throw "stdlib source root is missing: $stdlibRoot"
}

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -ne "stdlib/std") {
    throw "unsupported stdlib global API contract schema or scope"
}

$declared = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($entry in $contract.entries) {
    $api = [string]$entry.api
    $category = [string]$entry.category
    if (-not $allowedCategories.Contains($category)) {
        throw "unsupported category '$category' for '$api'"
    }
    if (-not $declared.TryAdd($api, $category)) {
        throw "duplicate stdlib global API contract entry: $api"
    }
}

$discovered = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
$declarationByApi = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
$declarationPattern = '^public\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)(?:<[^>]+>)?(?:\s+[^:]*)?:'
foreach ($file in Get-ChildItem -LiteralPath $stdlibRoot -Recurse -File -Filter "*.slg") {
    $lines = Get-Content -LiteralPath $file.FullName
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
                throw "unrecognized top-level public declaration at $($file.FullName):$($index + 1)"
            }
            continue
        }
        if ([string]::IsNullOrWhiteSpace($namespace)) {
            throw "public global function has no namespace at $($file.FullName):$($index + 1)"
        }
        $api = "$namespace.$($Matches.name)"
        $location = "$($file.FullName):$($index + 1)"
        if (-not $discovered.TryAdd($api, $location)) {
            throw "duplicate public global function '$api' at $location and $($discovered[$api])"
        }
        $declarationByApi.Add($api, $line.Trim())
    }
}

$unclassified = @($discovered.Keys | Where-Object { -not $declared.ContainsKey($_) } | Sort-Object)
$stale = @($declared.Keys | Where-Object { -not $discovered.ContainsKey($_) } | Sort-Object)
if ($unclassified.Count -gt 0 -or $stale.Count -gt 0) {
    if ($unclassified.Count -gt 0) {
        Write-Error "Unclassified public global APIs:`n$($unclassified -join "`n")" -ErrorAction Continue
    }
    if ($stale.Count -gt 0) {
        Write-Error "Stale public global API contract entries:`n$($stale -join "`n")" -ErrorAction Continue
    }
    throw "stdlib instance-first API contract drifted"
}

foreach ($entry in $declared.GetEnumerator()) {
    $api = $entry.Key
    $category = $entry.Value
    $declaration = $declarationByApi[$api]
    if ($category -eq "constant" -and
        ($declaration -notmatch '^public\s+[A-Za-z_][A-Za-z0-9_]*(?:<[^>]+>)?\s*:\s*->\s*.+=>' -or
         $declaration -match '\suses\s')) {
        throw "constant '$api' must be a parameterless effect-free expression declaration, found: $declaration"
    }
    if ($category -eq "parser") {
        $name = ($api -split '\.')[-1]
        if ($name -notmatch '^(?:parse|decode)') {
            throw "parser '$api' must use a parse*/decode* boundary name"
        }
    }
}

$categoryCounts = $declared.GetEnumerator() |
    Group-Object -Property Value |
    Sort-Object -Property Name
foreach ($group in $categoryCounts) {
    Write-Host "[stdlib instance policy] $($group.Name): $($group.Count) reviewed global APIs"
}
$stdlibDebt = @($declared.GetEnumerator() |
    Where-Object { $_.Value -eq "migration-debt" }).Count
Write-Host "[stdlib instance policy] PASS $($discovered.Count) reviewed globals; $stdlibDebt explicit migration-debt globals remain."
$reviewedExceptions = $discovered.Count - $stdlibDebt
$evolutionPath = Join-Path $RepositoryRoot "docs\STDLIB_EVOLUTION.md"
$evolutionText = [System.IO.File]::ReadAllText($evolutionPath)
$evolutionSummary = "$($discovered.Count) globals, $reviewedExceptions reviewed exceptions, $stdlibDebt migration candidates"
if (-not $evolutionText.Contains($evolutionSummary, [System.StringComparison]::Ordinal)) {
    throw "stdlib evolution instance-policy summary drifted; expected '$evolutionSummary'"
}
Write-Host "[stdlib instance policy] PASS evolution summary $evolutionSummary."

$pathContractPath = Join-Path $PSScriptRoot "contracts\sys-path-global-api.json"
$pathCategories = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("factory", "raw-boundary", "migration-debt"),
    [System.StringComparer]::Ordinal)
$pathContract = Get-Content -LiteralPath $pathContractPath -Raw | ConvertFrom-Json
if ($pathContract.schemaVersion -ne 2 -or $pathContract.scope -ne "sys.path") {
    throw "unsupported sys.path global API contract schema or scope"
}
$pathSources = @($pathContract.sources | ForEach-Object {
    $source = Join-Path $RepositoryRoot ([string]$_)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "sys.path contract source is missing: $source"
    }
    $source
})

$pathDeclared = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($entry in $pathContract.entries) {
    $api = [string]$entry.api
    $category = [string]$entry.category
    if (-not $pathCategories.Contains($category)) {
        throw "unsupported sys.path category '$category' for '$api'"
    }
    if (-not $pathDeclared.TryAdd($api, $category)) {
        throw "duplicate sys.path global API contract entry: $api"
    }
}

$pathDiscovered = [System.Collections.Generic.Dictionary[string, string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($pathSource in $pathSources) {
    $pathLines = Get-Content -LiteralPath $pathSource
    $pathNamespace = $null
    $implBraceDepth = 0
    for ($index = 0; $index -lt $pathLines.Count; $index++) {
        $line = $pathLines[$index]
        if ($implBraceDepth -gt 0) {
            $implBraceDepth += [regex]::Matches($line, '\{').Count
            $implBraceDepth -= [regex]::Matches($line, '\}').Count
            continue
        }
        if ($line -match '^namespace\s+(?<namespace>[A-Za-z_][A-Za-z0-9_.]*)\s*$') {
            $pathNamespace = $Matches.namespace
            continue
        }
        if ($line -match '^impl\s+[A-Za-z_][A-Za-z0-9_.]*\s*\{') {
            $implBraceDepth = [regex]::Matches($line, '\{').Count -
                [regex]::Matches($line, '\}').Count
            continue
        }
        if ($line -notmatch $declarationPattern) {
            if (($line -match '^public\s+') -and
                ($line -notmatch '^public\s+(?:struct|enum|trait)\s+')) {
                throw "unrecognized sys.path public declaration at $($pathSource):$($index + 1)"
            }
            continue
        }
        $api = "$pathNamespace.$($Matches.name)"
        $location = "$($pathSource):$($index + 1)"
        if (-not $pathDiscovered.TryAdd($api, $location)) {
            throw "duplicate sys.path public global function '$api' at $location"
        }
    }
}

$pathUnclassified = @($pathDiscovered.Keys |
    Where-Object { -not $pathDeclared.ContainsKey($_) } |
    Sort-Object)
$pathStale = @($pathDeclared.Keys |
    Where-Object { -not $pathDiscovered.ContainsKey($_) } |
    Sort-Object)
if ($pathUnclassified.Count -gt 0 -or $pathStale.Count -gt 0) {
    if ($pathUnclassified.Count -gt 0) {
        Write-Error "Unclassified sys.path global APIs:`n$($pathUnclassified -join "`n")" -ErrorAction Continue
    }
    if ($pathStale.Count -gt 0) {
        Write-Error "Stale sys.path global API contract entries:`n$($pathStale -join "`n")" -ErrorAction Continue
    }
    throw "sys.path shrinking migration contract drifted"
}

$pathDebt = @($pathDeclared.GetEnumerator() |
    Where-Object { $_.Value -eq "migration-debt" }).Count
Write-Host "[stdlib instance policy] sys.path: $pathDebt explicit migration-debt globals; no unreviewed additions."
