[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $Root,

    [Parameter(Mandatory)]
    [datetime] $NotModifiedSince,

    [switch] $Execute
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$artifactRoot = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'artifacts')).Path
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$artifactPrefix = $artifactRoot + [IO.Path]::DirectorySeparatorChar

if (-not $resolvedRoot.StartsWith($artifactPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Cleanup root must be inside the repository artifacts directory: $resolvedRoot"
}

$runningReferences = @(
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ProcessId -ne $PID -and
            $_.CommandLine -and
            $_.CommandLine.Contains($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)
        }
)
if ($runningReferences.Count -ne 0) {
    throw "Cleanup root is referenced by running process IDs: $($runningReferences.ProcessId -join ', ')"
}

$targets = @(
    Get-ChildItem -LiteralPath $resolvedRoot -Directory -Recurse -Force |
        Where-Object Name -eq '.sollang-cache'
)
$validatedTargets = foreach ($target in $targets) {
    $resolvedTarget = [IO.Path]::GetFullPath($target.FullName)
    $rootPrefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTarget.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Cleanup target escaped the selected root: $resolvedTarget"
    }
    if ((Split-Path -Leaf $resolvedTarget) -ne '.sollang-cache') {
        throw "Cleanup target is not a cache directory: $resolvedTarget"
    }
    if ($target.LastWriteTime -ge $NotModifiedSince) {
        throw "Cleanup target is newer than the cutoff: $resolvedTarget"
    }

    $reparsePoints = @(
        @($target) + @(Get-ChildItem -LiteralPath $resolvedTarget -Directory -Recurse -Force) |
            Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
    )
    if ($reparsePoints.Count -ne 0) {
        throw "Cleanup target contains a reparse point: $resolvedTarget"
    }

    $files = @(Get-ChildItem -LiteralPath $resolvedTarget -File -Recurse -Force)
    [pscustomobject]@{
        Path = $resolvedTarget
        Files = $files.Count
        Bytes = [int64](($files | Measure-Object Length -Sum).Sum)
    }
}

$summary = [pscustomobject]@{
    Root = $resolvedRoot
    Execute = [bool]$Execute
    Targets = $validatedTargets.Count
    Files = [int64](($validatedTargets | Measure-Object Files -Sum).Sum)
    Bytes = [int64](($validatedTargets | Measure-Object Bytes -Sum).Sum)
}

if ($Execute) {
    foreach ($target in @($validatedTargets | Sort-Object { $_.Path.Length } -Descending)) {
        if ($PSCmdlet.ShouldProcess($target.Path, 'Remove stale Sollang artifact cache')) {
            Remove-Item -LiteralPath $target.Path -Recurse -Force
        }
    }

    $remainingTargets = @($validatedTargets | Where-Object { Test-Path -LiteralPath $_.Path })
    if ($remainingTargets.Count -ne 0) {
        throw "Some validated cache directories remain after cleanup: $($remainingTargets.Path -join ', ')"
    }
}

$summary | ConvertTo-Json
