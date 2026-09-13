[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$fixtureRoot = Join-Path $root 'tests/Sollang.PrimitiveMethodModuleFixtures'
$probeProject = Join-Path $root 'tests/Sollang.PrimitiveMethodModuleProbe/Sollang.PrimitiveMethodModuleProbe.csproj'
foreach ($required in @(
    (Join-Path $fixtureRoot 'Sollang.slnx'),
    (Join-Path $fixtureRoot 'stdlib/std/alpha.slg'),
    (Join-Path $fixtureRoot 'stdlib/std/beta.slg'),
    (Join-Path $fixtureRoot 'stdlib/std/gamma.slg'),
    (Join-Path $fixtureRoot 'main.slg'),
    $probeProject)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "module-qualified primitive-method prerequisite is missing: $required"
    }
}

& dotnet run --project $probeProject -c Release -- `
    (Join-Path $fixtureRoot 'stdlib/std/alpha.slg') `
    (Join-Path $fixtureRoot 'stdlib/std/beta.slg') `
    (Join-Path $fixtureRoot 'stdlib/std/gamma.slg')
if ($LASTEXITCODE -ne 0) {
    throw "module-qualified primitive-method parser probe failed with exit code $LASTEXITCODE"
}

$generator = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler.Generators/ParserSourceGenerator.cs'))
$semantic = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'))
if (-not $generator.Contains('QualifyMethodOwner(methodOwner)', [StringComparison]::Ordinal)) {
    throw 'module-qualified primitive-method generator invariant is missing'
}
if (-not $semantic.Contains('_currentModuleName + "." + inherentName', [StringComparison]::Ordinal)) {
    throw 'current-module bare primitive-method resolution invariant is missing'
}
$hasReceiverOwnerCandidates = $semantic.Contains(
    'var receiverOwners = InherentReceiverOwners(receiverType);',
    [StringComparison]::Ordinal)
$hasCanonicalExactOwner = $semantic.Contains(
    'Name: FormatType(receiverType)',
    [StringComparison]::Ordinal)
if (-not $hasReceiverOwnerCandidates -or -not $hasCanonicalExactOwner) {
    throw 'canonical exact receiver-owner resolution invariant is missing'
}
if (-not $generator.Contains("ownerType.StartsWith('[', StringComparison.Ordinal)", [StringComparison]::Ordinal)) {
    throw 'module-qualified structural array-owner identity invariant is missing'
}

Write-Host '[module-qualified builtin methods] PASS 6/6 (three parser identities + module qualification + exact receiver identity + structural array identity)'
