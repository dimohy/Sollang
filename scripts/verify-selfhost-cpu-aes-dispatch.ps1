[CmdletBinding()]
param(
    [string]$Compiler = '',
    [ValidatePattern('^[a-z0-9-]+$')][string]$Label = 'stage2',
    [string]$LlvmHome = '',
    [string]$CompilerAssembly = '',
    [string]$CompilerLinkBridgeProof = '',
    [string]$ArtifactDirectory = '',
    [string[]]$ReusableCompilerDirectories = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$verificationArguments = @('--mode', 'selfhost', '--label', $Label)
if ($CompilerAssembly) { $verificationArguments += @('--managed-compiler', $CompilerAssembly) }
if ($Compiler) { $verificationArguments += @('--selfhost-compiler', $Compiler) }
if ($LlvmHome) { $verificationArguments += @('--llvm', $LlvmHome) }
if ($ArtifactDirectory) { $verificationArguments += @('--output', $ArtifactDirectory) }
if ($CompilerLinkBridgeProof) { $verificationArguments += @('--bridge-proof', $CompilerLinkBridgeProof) }
foreach ($directory in $ReusableCompilerDirectories) { $verificationArguments += @('--reusable-directory', $directory) }
if (-not $Compiler) { $verificationArguments += @('--selfhost-compiler', (Join-Path $repoRoot 'artifacts/example-tests/selfhost-sollangc-driver.exe')) }
& $python (Join-Path $PSScriptRoot 'verify-cpu-aes-dispatch.py') @verificationArguments
if ($LASTEXITCODE -ne 0) { throw 'SELFHOST_CPU_AES_VERIFICATION_FAILED' }
