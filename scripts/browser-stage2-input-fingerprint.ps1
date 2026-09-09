function Get-BrowserStage2InputFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Stage2Path,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$BuildScriptPath,
        [Parameter(Mandatory)][string]$LlvmAsPath,
        [Parameter(Mandatory)][string]$ClangPath,
        [Parameter(Mandatory)][string]$WasmLdPath
    )

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $orderedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($path in @(
        $Stage2Path,
        $ManifestPath,
        $BuildScriptPath,
        $LlvmAsPath,
        $ClangPath,
        $WasmLdPath
    )) {
        [void]$orderedPaths.Add([System.IO.Path]::GetFullPath($path))
    }

    foreach ($entry in Get-Content -LiteralPath $ManifestPath) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            [void]$orderedPaths.Add((Resolve-Path (Join-Path $root $entry.Trim())).Path)
        }
    }

    $buildScript = [System.IO.File]::ReadAllText($BuildScriptPath)
    $fixtureReferences = @(
        [regex]::Matches(
            $buildScript,
            '"(?<path>(?:examples|tests)\\[^"\r\n]+\.(?:slg|txt))"') |
            ForEach-Object { Join-Path $root $_.Groups["path"].Value } |
            Sort-Object -Unique
    )
    foreach ($path in $fixtureReferences) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "browser Stage2 referenced fixture contract is missing: $path"
        }
    }
    $referencedContracts = @($fixtureReferences)
    $scriptReferences = @(
        [regex]::Matches(
            $buildScript,
            '"(?<path>[^"\\/\r\n]+\.(?:ps1|mjs))"') |
            ForEach-Object { Join-Path $PSScriptRoot $_.Groups["path"].Value } |
            Sort-Object -Unique
    )
    foreach ($path in $scriptReferences) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "browser Stage2 referenced verifier is missing: $path"
        }
    }
    $referencedContracts += $scriptReferences
    $referencedContracts += @(
        Join-Path $PSScriptRoot "browser-stage2-input-fingerprint.ps1"
        Join-Path $PSScriptRoot "verify-browser-stage2-artifacts.ps1"
    )
    $referencedContracts = @(
        $referencedContracts |
            ForEach-Object { [System.IO.Path]::GetFullPath($_) } |
            Sort-Object { [System.IO.Path]::GetRelativePath($root, $_) } -Unique
    )
    foreach ($path in $referencedContracts) {
        [void]$orderedPaths.Add($path)
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    foreach ($path in $orderedPaths) {
        if (-not $seen.Add($path)) {
            continue
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "browser Stage2 fingerprint input is missing: $path"
        }
        $relative = [System.IO.Path]::GetRelativePath($root, $path).Replace("\", "/")
        $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$relative`0"))
        $hash.AppendData([System.IO.File]::ReadAllBytes($path))
    }
    return [Convert]::ToHexString($hash.GetHashAndReset())
}
