$ErrorActionPreference = 'Stop'
$taskBase = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/build-focused-selfhost-compiler.ps1 `
    -SeedCompiler (Join-Path $taskBase 'managed13239/compiler/Sollang.Compiler.exe') `
    -OutputDirectory (Join-Path $taskBase 'v13347/compiler-build01') `
    -Optimization O2 -Jobs 4 `
    -FormatCompiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    -ReusableCompilerDirectories @(
        (Join-Path $taskBase 'v12432/compiler-build01'),
        (Join-Path $taskBase 'v13312/compiler-build01')) `
    -ManagedProofRecord @(
        (Join-Path $taskBase 'character13340-managed/result.json'),
        (Join-Path $taskBase 'type-array13335-managed/result.json'),
        (Join-Path $taskBase 'character13341-semantic/result.json')) `
    -SlgEmissionProofRecord @((Join-Path $taskBase 'character13346-source-positive5.json')) `
    -StdlibSourceProofRecord (Join-Path $taskBase 'character13342-stdlib/result.json')
