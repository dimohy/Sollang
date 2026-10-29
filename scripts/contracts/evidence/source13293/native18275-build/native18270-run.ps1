$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath 'W:\MyWorks\Sollang'
$taskBase = [IO.Path]::GetFullPath('artifacts/scratch/resume-20261006-owner-continuation22')
$nativeBuildArguments = @{
    SeedCompiler = Join-Path $taskBase 'managed18060/compiler/Sollang.Compiler.exe'
    OutputDirectory = Join-Path $taskBase 'v18270/compiler-build01'
    Optimization = 'O1'
    Jobs = 24
    FormatCompiler = Join-Path $taskBase 'v12432/compiler-build01/compiler.exe'
    ReusableCompilerDirectories = @((Join-Path $taskBase 'v12432/compiler-build01'), (Join-Path $taskBase 'v18092/compiler-build01'))
    ManagedProofRecord = @((Join-Path $taskBase 'runtime18245-semantic/result.json'), (Join-Path $taskBase 'runtime18194-managed3/result.json'), (Join-Path $taskBase 'runtime18235-managed2/result.json'))
    SlgEmissionProofRecord = @((Join-Path $taskBase 'runtime18266-positive17.json'))
    StdlibSourceProofRecord = Join-Path $taskBase 'runtime18247-stdlib/result.json'
}
& ./scripts/build-focused-selfhost-compiler.ps1 @nativeBuildArguments
