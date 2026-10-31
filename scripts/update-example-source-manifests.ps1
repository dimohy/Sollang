[CmdletBinding()]
param(
    [ValidateSet('Check', 'Plan', 'Write')][string]$Mode = 'Check',
    [string[]]$Manifest = @(),
    [string]$SelectionFile = '',
    [Parameter(Mandatory)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'source-module-header.ps1')
$repo = Split-Path -Parent $PSScriptRoot
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $repo 'examples/regression/expected')) + [IO.Path]::DirectorySeparatorChar
$canonical = Join-Path $repo 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$compilerEntryManifests = @{
    (Join-Path $repo 'tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt') = 'tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.slg'
    (Join-Path $repo 'selfhost/browser_driver.sources.txt') = 'selfhost/browser_driver.slg'
}
$headers = @{}
$hashes = @{}
function Repository-Path([string]$entry) {
    if ([IO.Path]::IsPathRooted($entry)) { return [IO.Path]::GetFullPath($entry) }
    return [IO.Path]::GetFullPath((Join-Path $repo $entry))
}
function Read-Header([string]$entry) {
    $path = Repository-Path $entry
    if (-not $path.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($path)) {
        throw "SOURCE_MANIFEST_INPUT_INVALID: $entry"
    }
    if (-not $headers.ContainsKey($path)) {
        $headers[$path] = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText($path))
        $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    return $headers[$path]
}
$hashes[$canonical] = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash
$hashes[$PSCommandPath] = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$headerTool = Join-Path $PSScriptRoot 'source-module-header.ps1'
$hashes[$headerTool] = (Get-FileHash -LiteralPath $headerTool -Algorithm SHA256).Hash

$sources = @([IO.File]::ReadAllLines($canonical) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().Replace('\', '/') })
$providers = @{}
foreach ($entry in $sources) {
    $header = Read-Header $entry
    if ($header.Namespace.Length -gt 0) {
        if (-not $providers.ContainsKey($header.Namespace)) { $providers[$header.Namespace] = [Collections.Generic.List[string]]::new() }
        $providers[$header.Namespace].Add($entry)
    }
}
$stdlibModules = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'stdlib') -Recurse -Filter *.slg -File) {
    $entry = [IO.Path]::GetRelativePath($repo, $file.FullName)
    $header = Read-Header $entry
    if ($header.Namespace.Length -gt 0) { [void]$stdlibModules.Add($header.Namespace) }
}
if ($SelectionFile.Length -gt 0) {
    if ($Manifest.Count -gt 0) { throw 'SOURCE_MANIFEST_SELECTION_CONFLICT' }
    $selection = Get-Content -LiteralPath $SelectionFile -Raw | ConvertFrom-Json
    $Manifest = @($selection.sourceManifests)
}
if ($Manifest.Count -eq 0) { throw 'SOURCE_MANIFEST_SELECTION_EMPTY' }
$plans = [Collections.Generic.List[object]]::new()
foreach ($entry in $Manifest) {
    $path = Repository-Path $entry
    $isCompilerEntry = $compilerEntryManifests.ContainsKey($path)
    if ((-not $path.StartsWith($expectedRoot, [StringComparison]::OrdinalIgnoreCase) -and -not $isCompilerEntry) -or -not $path.EndsWith('.sources.txt', [StringComparison]::Ordinal) -or -not [IO.File]::Exists($path)) {
        throw "SOURCE_MANIFEST_OUTPUT_INVALID: $entry"
    }
    $original = @([IO.File]::ReadAllLines($path) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($isCompilerEntry -and ($original.Count -eq 0 -or $original[0].Replace('\', '/') -cne $compilerEntryManifests[$path])) {
        throw "SOURCE_MANIFEST_ENTRY_ROOT_INVALID: $entry"
    }
    $selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $modules = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $required = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $outsideScope = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $spelling = @{}
    $queue = [Collections.Generic.List[string]]::new()
    foreach ($source in $original) {
        $normalized = $source.Trim().Replace('\', '/')
        if (-not $selected.Add($normalized)) { throw "SOURCE_MANIFEST_DUPLICATE: $entry $source" }
        $spelling[$normalized] = $source
        $header = Read-Header $source
        if ($providers.ContainsKey($header.Namespace) -and $normalized -cnotin $sources) {
            throw "SOURCE_MANIFEST_PROVIDER_OVERRIDE: $entry $source"
        }
        $queue.Add($normalized)
    }
    for ($index = 0; $index -lt $queue.Count; $index++) {
        $header = Read-Header $queue[$index]
        if ($header.Namespace.Length -gt 0) { [void]$modules.Add($header.Namespace) }
        foreach ($module in @($header.Namespace) + @($header.Imports)) {
            if ($module.Length -eq 0 -or $stdlibModules.Contains($module)) { continue }
            # The compiler already resolves ordinary relative module imports.
            # This tool repairs canonical compiler providers, not that loader.
            if (-not $providers.ContainsKey($module) -and -not $module.StartsWith('sollang.compiler.', [StringComparison]::Ordinal)) {
                [void]$outsideScope.Add($module)
                continue
            }
            [void]$required.Add($module)
            if ($providers.ContainsKey($module)) {
                foreach ($provider in $providers[$module]) {
                    if ($selected.Add($provider)) { $queue.Add($provider) }
                }
            }
        }
    }
    foreach ($module in $required) {
        if (-not $modules.Contains($module)) { throw "SOURCE_MANIFEST_PROVIDER_UNKNOWN: $entry $module" }
    }
    $updated = [Collections.Generic.List[string]]::new()
    foreach ($source in $original) { $updated.Add($source) }
    # Keep existing entries in order; insert new canonical providers after their
    # nearest existing canonical predecessor. The fixture root stays first.
    $previous = ''
    foreach ($source in $sources) {
        if (-not $selected.Contains($source)) { continue }
        if (-not $spelling.ContainsKey($source)) {
            $position = if ($previous.Length -gt 0) { $updated.IndexOf($previous) + 1 } else { 1 }
            $updated.Insert($position, $source)
            $spelling[$source] = $source
        }
        $previous = $spelling[$source]
    }
    if ($updated.Count -ne $selected.Count -or $updated[0] -cne $original[0]) { throw 'SOURCE_MANIFEST_PROJECTION_INVALID' }
    $plans.Add([ordered]@{path=$path;beforeHash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;original=$original;updated=@($updated);added=@($updated | Where-Object { $_ -cnotin $original });outsideCompilerProviderScope=@($outsideScope);changed=($original -join "`n") -cne ($updated -join "`n")})
}
$result = [ordered]@{schemaVersion=1;mode=$Mode;scope='canonical-compiler-provider-closure';status='planned';manifestCount=$plans.Count;changedCount=@($plans | Where-Object changed).Count;canonicalManifest=$canonical;canonicalManifestHash=(Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash;inputHashes=$hashes;plans=@($plans);claimsRuntimeValidation=$false;claimsOrdinaryImportLoaderValidation=$false}
$destination = Repository-Path $ResultPath
if (-not $destination.StartsWith((Join-Path $repo 'artifacts') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or [IO.File]::Exists($destination)) { throw 'SOURCE_MANIFEST_RESULT_INVALID' }
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
$encoding = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($destination, ($result | ConvertTo-Json -Depth 8), $encoding)
if ($Mode -eq 'Write') {
    # Validate every input again before the first write. No partially planned
    # closure or guessed provider is accepted for mutation.
    foreach ($source in $hashes.Keys) { if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $hashes[$source]) { throw 'SOURCE_MANIFEST_SOURCE_DRIFT' } }
    foreach ($plan in $plans) { if ((Get-FileHash -LiteralPath $plan.path -Algorithm SHA256).Hash -cne $plan.beforeHash) { throw 'SOURCE_MANIFEST_PLAN_DRIFT' } }
    foreach ($plan in $plans) { if ($plan.changed) { [IO.File]::WriteAllLines($plan.path, [string[]]$plan.updated, $encoding) } }
    $result.status = 'written'
} elseif ($Mode -eq 'Check') { $result.status = if ($result.changedCount -eq 0) { 'passed' } else { 'failed' } }
[IO.File]::WriteAllText($destination, ($result | ConvertTo-Json -Depth 8), $encoding)
Write-Output "SOURCE_MANIFEST_CLOSURE mode=$Mode manifests=$($result.manifestCount) changes=$($result.changedCount) status=$($result.status)"
if ($Mode -eq 'Check' -and $result.changedCount -gt 0) { exit 1 }
