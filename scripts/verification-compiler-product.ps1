# Compiler inputs may live outside the repository only with current build proof.
function Resolve-VerificationCompilerProduct {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedSha256
    )
    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $absolute = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf) -or (Get-Item -LiteralPath $absolute).Length -eq 0) {
        throw 'VERIFICATION_COMPILER_PRODUCT_MISSING'
    }
    if ((Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash -cne $ExpectedSha256.ToUpperInvariant()) {
        throw 'VERIFICATION_COMPILER_PRODUCT_SHA_MISMATCH'
    }
    $pins = [ordered]@{}
    if (-not $absolute.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $validator = Join-Path $root 'scripts/verify-current-compiler-product.py'
        $proofText = & python $validator --build (Split-Path -Parent $absolute) --stdout
        if ($LASTEXITCODE -ne 0) { throw 'VERIFICATION_EXTERNAL_COMPILER_BUILD_PROOF_INVALID' }
        $proof = ($proofText -join "`n") | ConvertFrom-Json -ErrorAction Stop
        if ($proof.status -cne 'passed' -or $proof.compiler -ine $absolute) {
            throw 'VERIFICATION_EXTERNAL_COMPILER_IDENTITY_MISMATCH'
        }
        foreach ($entry in $proof.inputHashes.PSObject.Properties) { $pins[$entry.Name] = $entry.Value }
    }
    [pscustomobject]@{ Path = $absolute; InputHashes = $pins }
}
