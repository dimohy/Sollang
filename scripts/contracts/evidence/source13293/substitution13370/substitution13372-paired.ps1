$ErrorActionPreference = 'Stop'
$taskRoot = (Get-Location).Path
$taskBase = Join-Path $taskRoot 'artifacts/scratch/resume-20261006-owner-continuation22'
$taskSources = @(& rg --files selfhost -g '*.slg' | ForEach-Object { Join-Path $taskRoot $_ })
& scripts/verify-compiler-paired-native-fixtures.ps1 `
 -ManagedCompiler (Join-Path $taskBase 'managed13239/compiler/Sollang.Compiler.exe') `
 -SelfhostCompiler (Join-Path $taskBase 'v13347/compiler-build01/compiler.exe') `
 -Fixture @('2511-type-substitution-replacement-identity','283-selfhost-recursive-type-terms','1748-generic-nested-product-substitution','1764-generic-readonly-slice-context','1765-generic-reference-context') `
 -OutputDirectory (Join-Path $taskBase 'substitution13372-paired') `
 -TimeoutMilliseconds 120000 -Jobs 1 `
 -AdditionalInput (@((Join-Path $taskBase 'substitution13371-source-comparison.json'),(Join-Path $taskBase 'substitution13368-managed/result.json'),(Join-Path $taskBase 'substitution13370-reference-supervised/result.json'),(Join-Path $taskBase 'v13347/compiler-build01/result.json')) + $taskSources) `
 -ReusableCompilerDirectories @((Join-Path $taskBase 'v12432/compiler-build01'),(Join-Path $taskBase 'v13312/compiler-build01'),(Join-Path $taskBase 'v13347/compiler-build01'))
