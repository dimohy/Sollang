$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath 'W:\MyWorks\Sollang'
$taskBase = [IO.Path]::GetFullPath('artifacts/scratch/resume-20261006-owner-continuation22')
$nativeBuildArguments = @{
    SeedCompiler = Join-Path $taskBase 'managed18577/compiler/Sollang.Compiler.exe'
    OutputDirectory = Join-Path $taskBase 'v18915/compiler-build01'
    Optimization = 'O2'
    Jobs = 24
    FormatCompiler = Join-Path $taskBase 'v12432/compiler-build01/compiler.exe'
    ReusableCompilerDirectories = @((Join-Path $taskBase 'v12432/compiler-build01'), (Join-Path $taskBase 'v18309/compiler-build01'))
    ManagedProofRecord = @((Join-Path $taskBase 'receiver18894-managed6/result.json'), (Join-Path $taskBase 'receiver18903-semantic/result.json'))
    StdlibSourceProofRecord = Join-Path $taskBase 'receiver18904-stdlib/result.json'
}
& ./scripts/build-focused-selfhost-compiler.ps1 @nativeBuildArguments
