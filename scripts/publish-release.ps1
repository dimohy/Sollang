[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [string]$OutputRoot,
    [string]$WindowsStage3Path,
    [string]$LinuxStage3Path
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

# Release authority remains unconditional and precedes all package filesystem work.
& (Join-Path $PSScriptRoot "verify-selfhost-compiler-contracts.ps1") `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-compiler-defects.ps1") `
    -RepositoryRoot $repoRoot `
    -RequireZeroKnownDefects

. (Join-Path $PSScriptRoot "native-release-package.ps1")

if ([string]::IsNullOrWhiteSpace($Version)) {
    $versionSource = [IO.File]::ReadAllText(
        (Join-Path $repoRoot "selfhost\compiler_version.slg"))
    $versionMatch = [regex]::Match(
        $versionSource,
        'public\s+current\s*:\s*->\s*Text\s*=>\s*"(?<version>\d+\.\d+\.\d+)"')
    if (-not $versionMatch.Success) {
        throw "canonical compiler version is missing from selfhost/compiler_version.slg"
    }
    $Version = $versionMatch.Groups["version"].Value
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot "artifacts\release\$Version"
}
if ([string]::IsNullOrWhiteSpace($WindowsStage3Path)) {
    $WindowsStage3Path = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
}
if ([string]::IsNullOrWhiteSpace($LinuxStage3Path)) {
    $LinuxStage3Path = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3-linux"
}

$result = Invoke-NativeReleasePackaging `
    -RepositoryRoot $repoRoot `
    -Version $Version `
    -OutputRoot $OutputRoot `
    -WindowsStage3Path $WindowsStage3Path `
    -LinuxStage3Path $LinuxStage3Path

Write-Host "[release complete] $($result.WindowsArchive)"
Write-Host "[release complete] $($result.LinuxArchive)"
Write-Host "[release complete] $($result.ChecksumPath)"
