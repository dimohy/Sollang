$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath 'W:\MyWorks\Sollang'
$taskBase = [IO.Path]::GetFullPath('artifacts/scratch/resume-20261006-owner-continuation22')
& ./scripts/verify-native-cli-format.ps1 `
    -Compiler (Join-Path $taskBase 'v17599/compiler-build01/compiler.exe') `
    -Target windows-x64 -OutputDirectory (Join-Path $taskBase 'format17615-fixtures17') `
    -ReusableCompilerDirectories @((Join-Path $taskBase 'v12432/compiler-build01'), (Join-Path $taskBase 'v16382/compiler-build01'), (Join-Path $taskBase 'v17599/compiler-build01'))
