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
    (Join-Path $fixtureRoot 'main.slg'),
    $probeProject)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "module-qualified primitive-method prerequisite is missing: $required"
    }
}

& dotnet run --project $probeProject -c Release -- `
    (Join-Path $fixtureRoot 'stdlib/std/alpha.slg') `
    (Join-Path $fixtureRoot 'stdlib/std/beta.slg')
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

Write-Host '[module-qualified primitive methods] PASS 3/3 (two parser identities + current-module resolution guard)'
