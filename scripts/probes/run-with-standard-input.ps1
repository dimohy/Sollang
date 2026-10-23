param([Parameter(Mandatory)][string]$Executable,[Parameter(Mandatory)][string]$InputFile,[Parameter(Mandatory)][string]$ExecutionRecord)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../verification-process.ps1')
$result=Invoke-VerificationProcessCapture -FilePath (Resolve-Path -LiteralPath $Executable).Path -StandardInputPath (Resolve-Path -LiteralPath $InputFile).Path -WorkingDirectory (Get-Location).Path -Description 'Declared standard input control' -TimeoutMilliseconds 5000 -ExecutionRecordPath $ExecutionRecord
[Console]::Out.Write($result.Stdout)
[Console]::Error.Write($result.Stderr)
exit $result.ExitCode
