function Get-CompilerEmissionInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$Path
    )

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        foreach ($sourcePath in $Path) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepositoryRoot, $sourcePath).Replace('\', '/')
            $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes($relativePath))
            $hash.AppendData([byte[]]@(0))
            $hash.AppendData([System.IO.File]::ReadAllBytes($sourcePath))
            $hash.AppendData([byte[]]@(0))
        }
        [Convert]::ToHexString($hash.GetHashAndReset())
    } finally {
        $hash.Dispose()
    }
}
