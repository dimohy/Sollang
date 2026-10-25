$ErrorActionPreference = 'Stop'
$taskRoot = (Get-Location).Path
$taskBase = Join-Path $taskRoot 'artifacts/scratch/resume-20261006-owner-continuation22'
$taskSources = @(& rg --files selfhost -g '*.slg' | ForEach-Object { Join-Path $taskRoot $_ })
& scripts/verify-compiler-paired-native-fixtures.ps1 `
 -ManagedCompiler (Join-Path $taskBase 'managed14487/compiler/Sollang.Compiler.exe') `
 -SelfhostCompiler (Join-Path $taskBase 'v14775/compiler-build01/compiler.exe') `
 -Fixture @('2511-type-substitution-replacement-identity','283-selfhost-recursive-type-terms') `
 -OutputDirectory (Join-Path $taskBase 'substitution15088-paired2') `
 -TimeoutMilliseconds 120000 -Jobs 1 `
 -AdditionalInput (@((Join-Path $taskBase 'substitution15087-source-comparison.json'),(Join-Path $taskBase 'substitution15069-managed5/result.json'),(Join-Path $taskBase 'substitution15070-reference-supervised/result.json'),(Join-Path $taskBase 'v14775/compiler-build01/result.json')) + $taskSources) `
 -ReusableCompilerDirectories @((Join-Path $taskBase 'v12432/compiler-build01'),(Join-Path $taskBase 'v14562/compiler-build01'),(Join-Path $taskBase 'v14775/compiler-build01'))
