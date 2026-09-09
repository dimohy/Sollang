$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "release-output-scope.ps1")

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("sollang-release-scope-contract-" + [guid]::NewGuid().ToString("N"))))
$systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
if (-not $temporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Release scope contract temp path escaped the system temp directory: $temporaryRoot"
}

try {
    $repositoryRoot = Join-Path $temporaryRoot "repo"
    $outputRoot = Join-Path $repositoryRoot "artifacts\release\0.4.0"
    $ownedPath = Join-Path $outputRoot "staging"
    $siblingPath = Join-Path $repositoryRoot "source"
    New-Item -ItemType Directory -Force -Path $ownedPath, $siblingPath | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $ownedPath "owned.txt"), "owned")
    [System.IO.File]::WriteAllText((Join-Path $siblingPath "keep.txt"), "keep")

    $validatedOutputRoot = Assert-SafeReleaseOutputRoot $outputRoot $repositoryRoot
    Remove-OwnedReleasePath $validatedOutputRoot $ownedPath
    if (Test-Path -LiteralPath $ownedPath) {
        throw "owned release child was not removed"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $siblingPath "keep.txt"))) {
        throw "release cleanup removed a sibling path"
    }

    $outputRootRejected = $false
    try { Remove-OwnedReleasePath $validatedOutputRoot $validatedOutputRoot } catch { $outputRootRejected = $true }
    if (-not $outputRootRejected) { throw "release cleanup accepted the output root itself" }

    $siblingRejected = $false
    try { Remove-OwnedReleasePath $validatedOutputRoot $siblingPath } catch { $siblingRejected = $true }
    if (-not $siblingRejected) { throw "release cleanup accepted a sibling path" }

    $volumeRootRejected = $false
    try {
        Assert-SafeReleaseOutputRoot ([System.IO.Path]::GetPathRoot($temporaryRoot)) $repositoryRoot | Out-Null
    } catch {
        $volumeRootRejected = $true
    }
    if (-not $volumeRootRejected) { throw "release output accepted a volume root" }

    $repositoryRootRejected = $false
    try { Assert-SafeReleaseOutputRoot $repositoryRoot $repositoryRoot | Out-Null } catch { $repositoryRootRejected = $true }
    if (-not $repositoryRootRejected) { throw "release output accepted the repository root" }

    Write-Host "[release output scope] PASS owned-child cleanup and root/repository/sibling negative controls."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
