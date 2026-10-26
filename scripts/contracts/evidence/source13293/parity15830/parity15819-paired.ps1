$ErrorActionPreference = 'Stop'
$base = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
$proof = Get-Content -LiteralPath (Join-Path $base 'parity15818-managed-topology1/result.json') -Raw | ConvertFrom-Json
if ($proof.status -cne 'passed' -or -not $proof.inputStable -or -not $proof.processesStopped) { throw 'Topology managed proof incomplete' }
$additional = @((Get-Content -LiteralPath (Join-Path $base 'parity15818-build-inputs.json') -Raw | ConvertFrom-Json))
$additional += @((Join-Path $base 'parity15818-managed-topology1/result.json'), (Join-Path $base 'parity15818-build-inputs.json'))
& ./scripts/verify-compiler-paired-native-fixtures.ps1 -ManagedCompiler (Join-Path $base 'managed15734/compiler/Sollang.Compiler.exe') -SelfhostCompiler (Join-Path $base 'v15778/compiler-build01/compiler.exe') -Fixture @('1824-c527-indexed-member-interpolation-topology') -OutputDirectory (Join-Path $base 'parity15819-paired-topology1') -TimeoutMilliseconds 180000 -AdditionalInput $additional -ReusableCompilerDirectories @((Join-Path $base 'v12432/compiler-build01'), (Join-Path $base 'v14775/compiler-build01'), (Join-Path $base 'v15778/compiler-build01')) -Jobs 1
if (-not $?) { throw 'Current topology paired check failed' }
