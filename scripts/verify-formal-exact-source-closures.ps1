[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$RefreshManifestClosure,
    [string[]]$AdditionalManifest = @()
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$stage2VerifierPath = Join-Path $PSScriptRoot "verify-selfhost-stage2.ps1"
$stage3VerifierPath = Join-Path $PSScriptRoot "verify-selfhost-stage3.ps1"
$runtimeManifestPath = Join-Path $RepositoryRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt"
$closureVerifierPath = Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1"
if ($AdditionalManifest.Count -gt 0 -and -not $RefreshManifestClosure) {
    throw 'FORMAL_CLOSURE_ADDITIONAL_REQUIRES_REFRESH: additional manifests are write-mode inputs'
}

if ($RefreshManifestClosure) {
    . (Join-Path $PSScriptRoot 'source-module-header.ps1')
    $compilerManifestPath = Join-Path $RepositoryRoot 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
    $catalog = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $ambiguous = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in ([IO.File]::ReadAllLines($compilerManifestPath) + [IO.File]::ReadAllLines($runtimeManifestPath))) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $relative = $entry.Trim().Replace('\', '/')
        $header = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText((Join-Path $RepositoryRoot $relative)))
        if ([string]::IsNullOrEmpty($header.Namespace)) { continue }
        if ($catalog.ContainsKey($header.Namespace) -and $catalog[$header.Namespace] -cne $relative) {
            $ambiguous.Add($header.Namespace) | Out-Null
        } else {
            $catalog[$header.Namespace] = $relative
        }
    }
}

function Refresh-ExactClosure([string]$ManifestPath) {
    $existing = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $sources = [Collections.Generic.List[string]]::new()
    foreach ($entry in ([IO.File]::ReadAllLines($ManifestPath) + [IO.File]::ReadAllLines($runtimeManifestPath))) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $relative = $entry.Trim().Replace('\', '/')
        if ($existing.Add($relative)) { $sources.Add($relative) }
    }
    $added = [Collections.Generic.List[string]]::new()
    while ($true) {
        $modules = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $headers = [Collections.Generic.List[object]]::new()
        foreach ($relative in $sources) {
            $header = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText((Join-Path $RepositoryRoot $relative)))
            $headers.Add($header)
            if (-not [string]::IsNullOrEmpty($header.Namespace)) { $modules.Add($header.Namespace) | Out-Null }
        }
        $missing = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
        foreach ($header in $headers) {
            foreach ($import in $header.Imports) {
                if (-not $modules.Contains($import)) { $missing.Add($import) | Out-Null }
            }
        }
        if ($missing.Count -eq 0) { break }
        foreach ($import in $missing) {
            if ($ambiguous.Contains($import) -or -not $catalog.ContainsKey($import)) {
                throw "FORMAL_CLOSURE_IMPORT_UNRESOLVED: $ManifestPath imports $import"
            }
            $relative = $catalog[$import]
            if ($existing.Add($relative)) {
                $sources.Add($relative)
                $added.Add($relative)
            }
        }
    }
    if ($added.Count -gt 0) {
        $original = [IO.File]::ReadAllText($ManifestPath)
        $newline = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
        $prefix = if ($original.EndsWith("`n")) { '' } else { $newline }
        [IO.File]::AppendAllText($ManifestPath, $prefix + ($added -join $newline) + $newline, [Text.UTF8Encoding]::new($false))
        Write-Host "[formal exact source closure] refreshed $([IO.Path]::GetFileName($ManifestPath)): $($added -join ', ')"
    }
}

$verifierText = "{0}`n{1}" -f (
    [IO.File]::ReadAllText($stage2VerifierPath)), (
    [IO.File]::ReadAllText($stage3VerifierPath))
$fixtureNames = [regex]::Matches(
    $verifierText,
    '--exact\s+(?<name>[a-zA-Z0-9_/-]+)') |
    ForEach-Object { $_.Groups['name'].Value } |
    Sort-Object -Unique

$verifiedCount = 0
foreach ($fixtureName in $fixtureNames) {
    $isDiagnostic = $fixtureName.StartsWith('diagnostic/', [StringComparison]::Ordinal)
    $fixtureLeaf = if ($isDiagnostic) { $fixtureName.Substring('diagnostic/'.Length) } else { $fixtureName }
    $fixtureRelativePath = if ($isDiagnostic) {
        "examples/regression/diagnostics/$fixtureLeaf.slg"
    } else {
        "examples/regression/$fixtureLeaf.slg"
    }
    $fixturePath = Join-Path $RepositoryRoot $fixtureRelativePath
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
        throw "Formal exact compiler fixture source is missing: $fixtureName"
    }
    if (-not [IO.File]::ReadAllText($fixturePath).Contains("import sollang.compiler.")) {
        continue
    }

    $manifestRelativePath = if ($isDiagnostic) {
        "examples/regression/diagnostics/$fixtureLeaf.sources.txt"
    } else {
        "examples/regression/expected/$fixtureLeaf.sources.txt"
    }
    $manifestPath = Join-Path $RepositoryRoot $manifestRelativePath
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Formal exact compiler fixture is missing its source closure: $fixtureName"
    }
    $fixtureSources = [IO.File]::ReadAllLines($manifestPath)
    if ($fixtureSources.Count -eq 0 -or $fixtureSources[0] -cne $fixtureRelativePath) {
        throw "Formal exact compiler fixture source closure must start with '$fixtureRelativePath'"
    }
    if ($RefreshManifestClosure) { Refresh-ExactClosure $manifestPath }
    try {
        & $closureVerifierPath `
            -Manifest @($manifestPath, $runtimeManifestPath) `
            -RepositoryRoot $RepositoryRoot | Out-Null
        if (-not $?) { throw 'source closure verifier returned failure' }
    } catch {
        throw "Formal exact compiler fixture source closure failed: $fixtureName; $($_.Exception.Message)"
    }
    $verifiedCount++
}

foreach ($entry in $AdditionalManifest) {
    $manifestPath = [IO.Path]::GetFullPath($entry, $RepositoryRoot)
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot 'examples/regression/expected')) + [IO.Path]::DirectorySeparatorChar
    if (-not $manifestPath.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $manifestPath.EndsWith('.sources.txt', [StringComparison]::Ordinal) -or
        -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "FORMAL_CLOSURE_ADDITIONAL_INVALID: $entry"
    }
    Refresh-ExactClosure $manifestPath
    & $closureVerifierPath -Manifest @($manifestPath, $runtimeManifestPath) -RepositoryRoot $RepositoryRoot | Out-Null
}

Write-Host "[formal exact source closure] PASS $verifiedCount compiler fixtures before expensive contracts."
