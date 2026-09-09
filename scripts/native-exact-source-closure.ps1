function Assert-NativeExactCompilerSourceClosure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Fixture,
        [string[]]$SourcePath = @()
    )

    $fixtureSource = Join-Path $RepositoryRoot "examples/regression/$Fixture.slg"
    $source = [IO.File]::ReadAllText($fixtureSource)
    # Match the existing formal compiler-fixture contract. Ordinary fixtures
    # retain their normal stdlib discovery and intentionally partial analyses.
    . (Join-Path $PSScriptRoot 'source-module-header.ps1')
    $header = Get-SollangModuleHeader -Source $source
    if (@($header.Imports | Where-Object { $_.StartsWith('sollang.compiler.', [StringComparison]::Ordinal) }).Count -eq 0) { return }

    $manifest = Join-Path $RepositoryRoot "examples/regression/expected/$Fixture.sources.txt"
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Compiler fixture is missing its source closure: $Fixture"
    }
    $entries = @([IO.File]::ReadAllLines($manifest) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $expectedRoot = "examples/regression/$Fixture.slg"
    if ($entries.Count -eq 0 -or $entries[0] -cne $expectedRoot) {
        throw "Compiler fixture source closure must start with '$expectedRoot'"
    }
    $runtimeManifest = Join-Path $RepositoryRoot 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
    $verifier = Join-Path $PSScriptRoot 'verify-source-manifest-closure.ps1'
    if ($SourcePath.Count -gt 0) {
        & $verifier -SourcePath $SourcePath -Manifest @($manifest, $runtimeManifest) -RepositoryRoot $RepositoryRoot
    } else {
        & $verifier -Manifest @($manifest, $runtimeManifest) -RepositoryRoot $RepositoryRoot
    }
}
