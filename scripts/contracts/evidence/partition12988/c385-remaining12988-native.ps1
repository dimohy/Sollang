$ErrorActionPreference='Stop'
$r=(Get-Location).Path
$b=Join-Path $r 'artifacts/scratch/resume-20261006-owner-continuation22'
$p=Get-Content (Join-Path $b 'c385-remaining12988-plan.json') -Raw | ConvertFrom-Json
$f=@($p.cases.fixture | Select-Object -Unique)
& (Join-Path $r 'scripts/verify-native-exact-fixture-batch.ps1') -Compiler (Join-Path $r $p.selfhostCompiler.path) -Label native-results -Fixture $f -Platform windows -LlvmRoot (Join-Path $r '.tools/llvm-22.1.8') -StdlibRoot (Join-Path $r 'stdlib') -RepositoryRoot $r -OutputDirectory (Join-Path $b 'c385-remaining12988/native-results') -Jobs 4 -TimeoutMilliseconds 120000
