$ErrorActionPreference = 'Stop'
$taskRoot = (Get-Location).Path
$taskBase = Join-Path $taskRoot 'artifacts/scratch/resume-20261006-owner-continuation22'
& (Join-Path $taskRoot 'scripts/build-focused-selfhost-compiler.ps1') `
    -SeedCompiler (Join-Path $taskBase 'managed13056/compiler/Sollang.Compiler.exe') `
    -OutputDirectory (Join-Path $taskBase 'v13218/compiler-build01') `
    -Optimization O1 -Jobs 4 `
    -FormatCompiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    -ReusableCompilerDirectories @((Join-Path $taskBase 'v13149/compiler-build01')) `
    -ManagedProofRecord @(
        (Join-Path $taskBase 'literal13147-managed/result.json'),
        (Join-Path $taskBase 'pattern13217-managed/result.json'),
        (Join-Path $taskBase 'pattern13213-semantic/result.json'),
        (Join-Path $taskBase 'pattern13215-array-semantic/result.json'),
        (Join-Path $taskBase 'pattern13216-source/result.json')) `
    -SlgEmissionProofRecord @((Join-Path $taskBase 'pattern13216-source/positive-runtime-proof.json')) `
    -StdlibSourceProofRecord (Join-Path $taskBase 'pattern13214-stdlib/result.json')
