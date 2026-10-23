$ErrorActionPreference = 'Stop'
$taskBase = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/build-focused-selfhost-compiler.ps1 `
    -SeedCompiler (Join-Path $taskBase 'managed13239/compiler/Sollang.Compiler.exe') `
    -OutputDirectory (Join-Path $taskBase 'v13312/compiler-build01') `
    -Optimization O2 -Jobs 4 `
    -FormatCompiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    -ReusableCompilerDirectories @(
        (Join-Path $taskBase 'v12432/compiler-build01'),
        (Join-Path $taskBase 'v13262/compiler-build01')) `
    -ManagedProofRecord @(
        (Join-Path $taskBase 'readonly-elements13265-managed/result.json'),
        (Join-Path $taskBase 'readonly-elements13278-managed/result.json'),
        (Join-Path $taskBase 'signed-interpolation13288-managed/result.json'),
        (Join-Path $taskBase 'unsigned-interpolation13290-managed/result.json'),
        (Join-Path $taskBase 'grouped13304-semantic/result.json')) `
    -SlgEmissionProofRecord @((Join-Path $taskBase 'grouped13311-source-positive7.json')) `
    -StdlibSourceProofRecord (Join-Path $taskBase 'grouped13305-stdlib/result.json')
