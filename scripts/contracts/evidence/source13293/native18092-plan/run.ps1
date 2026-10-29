$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath 'W:\MyWorks\Sollang'
$taskBase = [IO.Path]::GetFullPath('artifacts/scratch/resume-20261006-owner-continuation22')
& ./scripts/build-focused-selfhost-compiler.ps1 `
    -SeedCompiler (Join-Path $taskBase 'managed18060/compiler/Sollang.Compiler.exe') `
    -OutputDirectory (Join-Path $taskBase 'v18092/compiler-build01') `
    -Optimization O1 -Jobs 24 `
    -FormatCompiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    -ReusableCompilerDirectories @((Join-Path $taskBase 'v12432/compiler-build01'), (Join-Path $taskBase 'v17599/compiler-build01')) `
    -ManagedProofRecord @((Join-Path $taskBase 'allocation18070-semantic/result.json'), (Join-Path $taskBase 'native18090-managed-value6/result.json'), (Join-Path $taskBase 'allocation18064-managed2/result.json')) `
    -SlgEmissionProofRecord @((Join-Path $taskBase 'allocation18075-source2/result.json')) `
    -StdlibSourceProofRecord (Join-Path $taskBase 'allocation18071-stdlib/result.json')
