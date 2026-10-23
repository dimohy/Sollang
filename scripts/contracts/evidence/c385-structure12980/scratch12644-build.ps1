param([string]$Compiler,[string]$Source,[string]$Output)
$ErrorActionPreference='Stop'
. scripts/verification-process.ps1
. scripts/verification-compiler-build.ps1
[void](Get-Command Invoke-VerificationProcessCapture -ErrorAction Stop)
[void](Get-Command Invoke-VerificationCompilerBuild -ErrorAction Stop)
$a=Invoke-VerificationCompilerBuild -Compiler $Compiler -Source $Source -Output $Output -Target windows-x64 -WorkingDirectory (Get-Location).Path -Description 'Integer21 focused normal' -TimeoutMilliseconds 120000
[Console]::Out.Write($a.Stdout)
[Console]::Error.Write($a.Stderr)
exit $a.ExitCode
