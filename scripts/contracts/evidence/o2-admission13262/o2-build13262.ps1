$ErrorActionPreference = 'Stop'
$taskBase = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/build-focused-selfhost-compiler.ps1 `
    -SeedCompiler (Join-Path $taskBase 'managed13239/compiler/Sollang.Compiler.exe') `
    -OutputDirectory (Join-Path $taskBase 'v13262/compiler-build01') `
    -Optimization O2 -Jobs 4 `
    -FormatCompiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    -ReusableCompilerDirectories @(
        (Join-Path $taskBase 'v12432/compiler-build01'),
        (Join-Path $taskBase 'v13220/compiler-build01')) `
    -ManagedProofRecord @(
        (Join-Path $taskBase 'c726-managed13240/result.json'),
        (Join-Path $taskBase 'c727-managed13241/result.json'),
        (Join-Path $taskBase 'retained13255-managed/result.json')) `
    -SlgEmissionProofRecord @((Join-Path $taskBase 'runtime13244-source/result.json')) `
    -StdlibSourceProofRecord (Join-Path $taskBase 'pattern13214-stdlib/result.json')
