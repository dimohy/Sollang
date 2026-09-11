function Assert-BrowserCompilerOutputRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CandidatePath,
        [Parameter(Mandatory)][string]$ArtifactRoot
    )

    $candidate = [System.IO.Path]::GetFullPath($CandidatePath)
    $root = [System.IO.Path]::GetFullPath($ArtifactRoot)
    $isRoot = $candidate.Equals($root, [System.StringComparison]::OrdinalIgnoreCase)
    $isDescendant = $candidate.StartsWith(
        $root + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $isRoot -and -not $isDescendant) {
        throw "browser compiler output must remain under $root"
    }
    return $candidate
}
