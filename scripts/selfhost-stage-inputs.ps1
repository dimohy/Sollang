Set-StrictMode -Version Latest

function Get-SelfhostStageCompilationInputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [ValidateRange(1, 64)][int]$Jobs = 8
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $compilerManifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
    $runtimeManifest = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
    $stdlibRoot = Join-Path $root 'stdlib'
    function Read-StageSourceManifest([string]$ManifestPath) {
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $paths = [Collections.Generic.List[string]]::new()
        foreach ($entry in [IO.File]::ReadAllLines($ManifestPath)) {
            if ([string]::IsNullOrWhiteSpace($entry)) { continue }
            $path = (Resolve-Path -LiteralPath (Join-Path $root $entry.Trim()) -ErrorAction Stop).Path
            if (-not $seen.Add($path)) { throw "duplicate Stage source: $entry" }
            $paths.Add($path)
        }
        if ($paths.Count -eq 0) { throw "empty Stage source manifest: $ManifestPath" }
        return $paths.ToArray()
    }
    $compilerSources = @(Read-StageSourceManifest $compilerManifest)
    $runtimeSources = @(Read-StageSourceManifest $runtimeManifest)
    [string[]]$stdlibSources = @(Get-ChildItem -LiteralPath $stdlibRoot -Recurse -File -Filter '*.slg' -ErrorAction Stop |
        ForEach-Object FullName)
    if ($stdlibSources.Count -eq 0) { throw "Stage standard library is empty: $stdlibRoot" }
    [Array]::Sort($stdlibSources, [StringComparer]::Ordinal)
    $fingerprintPaths = [Collections.Generic.List[string]]::new()
    $seenInputs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    # Runtime projections remain inputs of the compatibility controls. The
    # compiler itself uses the full, explicitly identified standard library.
    foreach ($path in @($MyInvocation.MyCommand.ScriptBlock.File, $compilerManifest, $runtimeManifest) +
            $compilerSources + $runtimeSources + $stdlibSources) {
        if ($seenInputs.Add($path)) { $fingerprintPaths.Add($path) }
    }
    [pscustomobject]@{
        CompilerSources = $compilerSources
        RuntimeSources = $runtimeSources
        StandardLibraryRoot = $stdlibRoot
        StandardLibrarySources = $stdlibSources
        EmissionArguments = @('windows-stdlib', $stdlibRoot, '--jobs',
            $Jobs.ToString([Globalization.CultureInfo]::InvariantCulture)) + $compilerSources
        FingerprintPaths = $fingerprintPaths.ToArray()
    }
}
