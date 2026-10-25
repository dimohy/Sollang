$ErrorActionPreference = 'Stop'
$base = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& ./scripts/build-focused-selfhost-compiler.ps1 -SeedCompiler (Join-Path $base 'managed15171/compiler/Sollang.Compiler.exe') -OutputDirectory (Join-Path $base 'v15202/compiler-build01') -Optimization O2 -Jobs 4 -FormatCompiler (Join-Path $base 'v12432/compiler-build01/compiler.exe') -ReusableCompilerDirectories @((Join-Path $base 'v12432/compiler-build01'), (Join-Path $base 'v14775/compiler-build01')) -ManagedProofRecord @((Join-Path $base 'async15197-semantic/result.json'), (Join-Path $base 'async15201-managed7/result.json')) -StdlibSourceProofRecord (Join-Path $base 'async15198-stdlib/result.json')
if (-not $?) { throw 'Current Native build failed' }
