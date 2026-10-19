[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$PlanPath = 'scripts/contracts/context-fixture-pair-plan.json',
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$planFile = (Resolve-Path -LiteralPath (Join-Path $root $PlanPath)).Path
$plan = Get-Content -LiteralPath $planFile -Raw | ConvertFrom-Json
if ($plan.schemaVersion -ne 1 -or $plan.fixtures.Count -ne 1 -or
    $plan.fixtures[0] -cne '1999-selfhost-context-fixture-suite' -or
    $plan.caseCount -ne 4 -or
    $plan.timeoutMillisecondsPerCompilerBuild -ne 1200000 -or
    $plan.managedFirstFormat -cne 'focused-runner-v1') {
    throw 'Context fixture pair plan is invalid'
}
if ($plan.performancePreflightStatus -cne 'suite-bounded-ready') {
    throw 'CONTEXT_PERFORMANCE_PREFLIGHT_PENDING: four-case suite was not preflighted'
}
& python (Join-Path $PSScriptRoot 'generate-context-fixture-suite.py') --check
if ($LASTEXITCODE -ne 0) { throw 'CONTEXT_SUITE_DRIFT: regenerate and verify the derived fixture suite' }
$suiteSource = Join-Path $root 'examples/regression/1999-selfhost-context-fixture-suite.slg'
$suiteManifest = Join-Path $root 'examples/regression/expected/1999-selfhost-context-fixture-suite.sources.txt'
$managedFirst = Get-Content -LiteralPath $plan.managedFirstResult -Raw | ConvertFrom-Json
if ($managedFirst.status -cne 'passed' -or $managedFirst.mode -cne 'managed' -or
    $managedFirst.completed -ne 1 -or $managedFirst.total -ne 1 -or
    -not $managedFirst.inputsStable -or -not $managedFirst.processesStopped -or
    $managedFirst.cases.Count -ne 1 -or -not $managedFirst.cases[0].passed -or
    $managedFirst.cases[0].id -cne $plan.fixtures[0] -or
    $managedFirst.cases[0].runStdout -cne ([IO.File]::ReadAllText(
        (Join-Path $root 'examples/regression/expected/1999-selfhost-context-fixture-suite.stdout.txt')).Trim())) {
    throw 'CONTEXT_MANAGED_FIRST_INVALID: exact current suite did not pass C# native execution'
}
foreach ($pin in $managedFirst.inputHashes.PSObject.Properties) {
    if (-not (Test-Path -LiteralPath $pin.Name -PathType Leaf) -or
        (Get-FileHash -LiteralPath $pin.Name -Algorithm SHA256).Hash -cne $pin.Value) {
        throw "CONTEXT_MANAGED_FIRST_INPUT_DRIFT: $($pin.Name)"
    }
}
foreach ($required in @($suiteSource, (Resolve-Path -LiteralPath $plan.managedCompiler).Path)) {
    if ($managedFirst.inputHashes.PSObject.Properties.Name -notcontains $required) {
        throw "CONTEXT_MANAGED_FIRST_INPUT_MISSING: $required"
    }
}
foreach ($compiler in @(
    @{ Path = $plan.managedCompiler; Hash = $plan.managedCompilerSha256 },
    @{ Path = $plan.selfhostCompiler; Hash = $plan.selfhostCompilerSha256 }
)) {
    if (-not (Test-Path -LiteralPath $compiler.Path -PathType Leaf) -or
        (Get-FileHash -LiteralPath $compiler.Path -Algorithm SHA256).Hash -cne $compiler.Hash) {
        throw "Context fixture compiler input changed: $($compiler.Path)"
    }
}
& python -c "import json,sys; from pathlib import Path; sys.path.insert(0,str(Path(sys.argv[1])/'scripts')); from verification_source_proof import current_build_inputs; current_build_inputs(Path(sys.argv[1]),json.load(open(sys.argv[2],encoding='utf-8-sig')))" $root $plan.nativeBuildResult
if ($LASTEXITCODE -ne 0) { throw 'CONTEXT_NATIVE_BUILD_SOURCE_DRIFT' }
$nativeBuild = Get-Content -LiteralPath $plan.nativeBuildResult -Raw | ConvertFrom-Json
if ($nativeBuild.compilerSha256 -cne $plan.selfhostCompilerSha256) {
    throw 'CONTEXT_NATIVE_BUILD_COMPILER_MISMATCH'
}
foreach ($fixture in $plan.fixtures) {
    $manifest = Join-Path $root "examples/regression/expected/$fixture.sources.txt"
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf) -or
        @(Get-Content -LiteralPath $manifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -ne $plan.expectedSourcesPerFixture) {
        throw "Context fixture source manifest changed: $fixture"
    }
}
if ($Check) { Write-Output 'CONTEXT_PAIR_PLAN_VALIDATED'; return }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { throw 'Context fixture output directory is required' }
if (Test-Path -LiteralPath $OutputDirectory) { throw "Context fixture output already exists: $OutputDirectory" }
$additionalInputs = @($planFile, $PSCommandPath, $plan.managedFirstResult, $plan.nativeBuildResult) + @(
    $plan.additionalInputs | ForEach-Object {
        if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $root $_ }
    })
$reusableCompilers = if ($plan.PSObject.Properties.Name -contains 'reusableCompilerDirectories') {
    @($plan.reusableCompilerDirectories)
} else { @() }
& (Join-Path $PSScriptRoot 'verify-compiler-paired-native-fixtures.ps1') `
    -ManagedCompiler $plan.managedCompiler -SelfhostCompiler $plan.selfhostCompiler `
    -Fixture @($plan.fixtures) -OutputDirectory $OutputDirectory `
    -TimeoutMilliseconds $plan.timeoutMillisecondsPerCompilerBuild `
    -AdditionalInput $additionalInputs -ReusableCompilerDirectories $reusableCompilers
