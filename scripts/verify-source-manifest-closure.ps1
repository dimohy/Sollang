[CmdletBinding()]
param(
    [string[]]$Manifest = @(),
    [string[]]$SourcePath = @(),
    [string]$RepositoryRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'source-module-header.ps1')

$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    Split-Path -Parent $PSScriptRoot
} else {
    [IO.Path]::GetFullPath($RepositoryRoot)
}
$manifestPaths = @($Manifest | ForEach-Object {
    $candidate = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $repoRoot $_ }
    (Resolve-Path -LiteralPath $candidate).Path
})

$sourcePaths = [Collections.Generic.List[string]]::new()
$seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if ($Manifest.Count -eq 0 -and $SourcePath.Count -eq 0) {
    throw 'source closure requires a manifest or explicit source paths'
}
foreach ($entry in $SourcePath) {
    $candidate = if ([IO.Path]::IsPathRooted($entry)) { $entry } else { Join-Path $repoRoot $entry }
    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    if (-not $seenPaths.Add($resolved)) {
        throw "duplicate explicit source entry: $entry"
    }
    $sourcePaths.Add($resolved)
}
foreach ($manifestPath in $manifestPaths) {
    $manifestSeenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in [IO.File]::ReadAllLines($manifestPath)) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $sourcePath = (Resolve-Path -LiteralPath (Join-Path $repoRoot $entry.Trim())).Path
        if (-not $manifestSeenPaths.Add($sourcePath)) {
            $relative = [IO.Path]::GetRelativePath($repoRoot, $sourcePath).Replace('\', '/')
            throw "duplicate source entry in $([IO.Path]::GetFileName($manifestPath)): $relative"
        }
        if ($seenPaths.Add($sourcePath)) {
            $sourcePaths.Add($sourcePath)
        }
    }
}

$moduleNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$sourceHeaders = [Collections.Generic.Dictionary[string, psobject]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($moduleSourcePath in $sourcePaths) {
    $source = [IO.File]::ReadAllText($moduleSourcePath)
    $header = Get-SollangModuleHeader -Source $source
    $sourceHeaders.Add($moduleSourcePath, $header)
    if ($header.Namespace.Length -gt 0) {
        $moduleNames.Add($header.Namespace) | Out-Null
    }
}

$missing = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
foreach ($moduleSourcePath in $sourcePaths) {
    foreach ($moduleName in $sourceHeaders[$moduleSourcePath].Imports) {
        if (-not $moduleNames.Contains($moduleName)) {
            $relative = [IO.Path]::GetRelativePath($repoRoot, $moduleSourcePath).Replace('\', '/')
            $missing.Add("$moduleName imported by $relative") | Out-Null
        }
    }
}

if ($missing.Count -gt 0) {
    throw "source manifest closure is incomplete:`n$($missing -join "`n")"
}

Write-Host "[source manifest] PASS $($sourcePaths.Count) sources, $($moduleNames.Count) modules, $($manifestPaths.Count) manifest(s)."
