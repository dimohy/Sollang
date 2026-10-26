$ErrorActionPreference = 'Stop'
$base = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& ./scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler (Join-Path $base 'managed15892/compiler/Sollang.Compiler.exe') -OutputDirectory (Join-Path $base 'v16203/compiler-build01') -Optimization O2 -Jobs 4 -FormatCompiler (Join-Path $base 'v12432/compiler-build01/compiler.exe') -ReusableCompilerDirectories @((Join-Path $base 'v12432/compiler-build01'), (Join-Path $base 'v16177/compiler-build01')) -ManagedProofRecord @((Join-Path $base 'epoch16200-semantic/result.json'), (Join-Path $base 'logical78016202-managed8/result.json')) -StdlibSourceProofRecord (Join-Path $base 'epoch16201-stdlib/result.json')
if (-not $?) { throw 'Current Native build failed' }
