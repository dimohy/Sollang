function Assert-SafeReleaseOutputRoot {
    param(
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $absoluteOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    $absoluteRepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $volumeRoot = [System.IO.Path]::GetPathRoot($absoluteOutputRoot)
    if ($absoluteOutputRoot.TrimEnd('\', '/') -ceq $volumeRoot.TrimEnd('\', '/')) {
        throw "Release output root cannot be a volume root: $absoluteOutputRoot"
    }
    if ($absoluteOutputRoot.TrimEnd('\', '/') -ceq $absoluteRepositoryRoot.TrimEnd('\', '/')) {
        throw "Release output root cannot be the repository root: $absoluteOutputRoot"
    }
    return $absoluteOutputRoot
}

function Remove-OwnedReleasePath {
    param(
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][string]$Path
    )

    $absoluteOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    $absolutePath = [System.IO.Path]::GetFullPath($Path)
    $relative = [System.IO.Path]::GetRelativePath($absoluteOutputRoot, $absolutePath)
    if ([System.IO.Path]::IsPathRooted($relative) -or
        $relative -eq "." -or
        $relative -eq ".." -or
        $relative.StartsWith("..\", [System.StringComparison]::Ordinal) -or
        $relative.StartsWith("../", [System.StringComparison]::Ordinal)) {
        throw "Release cleanup path is not an owned child of '$absoluteOutputRoot': $absolutePath"
    }
    if (Test-Path -LiteralPath $absolutePath) {
        Remove-Item -LiteralPath $absolutePath -Recurse -Force
    }
}
