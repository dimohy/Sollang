function Test-VerifiedInstallPathWithin {
    param(
        [Parameter(Mandatory)][string]$Candidate,
        [Parameter(Mandatory)][string]$Root
    )

    $absoluteCandidate = [System.IO.Path]::GetFullPath($Candidate).TrimEnd('\', '/')
    $absoluteRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    if ($absoluteCandidate.Equals($absoluteRoot, $comparison)) {
        return $true
    }
    $relative = [System.IO.Path]::GetRelativePath($absoluteRoot, $absoluteCandidate)
    return -not [System.IO.Path]::IsPathRooted($relative) -and
        $relative -ne ".." -and
        -not $relative.StartsWith("..\", [System.StringComparison]::Ordinal) -and
        -not $relative.StartsWith("../", [System.StringComparison]::Ordinal)
}

function Assert-SafeVerifiedInstallRoot {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    $absoluteInstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
    $absoluteRepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $volumeRoot = [System.IO.Path]::GetPathRoot($absoluteInstallRoot)
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    if ($absoluteInstallRoot.TrimEnd('\', '/').Equals($volumeRoot.TrimEnd('\', '/'), $comparison)) {
        throw "Verified install root cannot be a volume root: $absoluteInstallRoot"
    }
    if (Test-VerifiedInstallPathWithin $absoluteInstallRoot $absoluteRepositoryRoot) {
        throw "Verified install root cannot be the repository or one of its children: $absoluteInstallRoot"
    }
    $parent = [System.IO.Path]::GetDirectoryName($absoluteInstallRoot)
    if ([string]::IsNullOrWhiteSpace($parent) -or
        $parent.TrimEnd('\', '/').Equals($absoluteInstallRoot.TrimEnd('\', '/'), $comparison)) {
        throw "Verified install root must have a distinct parent directory: $absoluteInstallRoot"
    }
    return $absoluteInstallRoot
}

function New-VerifiedInstallSiblingPath {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][ValidateSet("install", "backup")][string]$Kind,
        [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9]+$')][string]$Nonce
    )

    $absoluteInstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
    $parent = [System.IO.Path]::GetDirectoryName($absoluteInstallRoot)
    $leaf = [System.IO.Path]::GetFileName($absoluteInstallRoot)
    return [System.IO.Path]::GetFullPath((Join-Path $parent ".$leaf.$Kind-$Nonce"))
}

function Remove-VerifiedInstallSibling {
    param(
        [Parameter(Mandatory)][string]$InstallRoot,
        [Parameter(Mandatory)][string]$Path
    )

    $absoluteInstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
    $absolutePath = [System.IO.Path]::GetFullPath($Path)
    $installParent = [System.IO.Path]::GetDirectoryName($absoluteInstallRoot)
    $pathParent = [System.IO.Path]::GetDirectoryName($absolutePath)
    $leaf = [System.IO.Path]::GetFileName($absoluteInstallRoot)
    $candidateLeaf = [System.IO.Path]::GetFileName($absolutePath)
    $isOwnedName = $candidateLeaf.StartsWith(".$leaf.install-", [System.StringComparison]::Ordinal) -or
        $candidateLeaf.StartsWith(".$leaf.backup-", [System.StringComparison]::Ordinal)
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }
    if (-not $pathParent.Equals($installParent, $comparison) -or -not $isOwnedName) {
        throw "Install cleanup path is not an owned sibling of '$absoluteInstallRoot': $absolutePath"
    }
    if (Test-Path -LiteralPath $absolutePath) {
        Remove-Item -LiteralPath $absolutePath -Recurse -Force
    }
}
