$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath 'W:\MyWorks\Sollang'
$taskBase = [IO.Path]::GetFullPath('artifacts/scratch/resume-20261006-owner-continuation22')
& ./scripts/build-focused-selfhost-compiler.ps1 `
    -SeedCompiler (Join-Path $taskBase 'managed17430/compiler/Sollang.Compiler.exe') `
    -OutputDirectory (Join-Path $taskBase 'v17599/compiler-build01') `
    -Optimization O1 -Jobs 24 `
    -FormatCompiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    -ReusableCompilerDirectories @((Join-Path $taskBase 'v12432/compiler-build01'), (Join-Path $taskBase 'v16382/compiler-build01')) `
    -ManagedProofRecord @((Join-Path $taskBase 'canonical17586-semantic/result.json'), (Join-Path $taskBase 'abi17511-managed2/result.json'), (Join-Path $taskBase 'canonical17588-context1/result.json')) `
    -SlgEmissionProofRecord @((Join-Path $taskBase 'canonical17592-source2/result.json')) `
    -StdlibSourceProofRecord (Join-Path $taskBase 'canonical17587-stdlib/result.json')
