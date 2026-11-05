[CmdletBinding()]
param(
    [string]$CompilerAssembly = '',
    [ValidatePattern('^[a-z0-9-]+$')][string]$Label = 'managed',
    [string]$LlvmHome = '',
    [string]$ArtifactDirectory = '',
    [string[]]$ReusableCompilerDirectories = @()
)
$Compiler = ''
$CompilerLinkBridgeProof = ''
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$verificationArguments = @('--mode', 'managed', '--label', $Label)
if ($CompilerAssembly) { $verificationArguments += @('--managed-compiler', $CompilerAssembly) }
if ($Compiler) { $verificationArguments += @('--selfhost-compiler', $Compiler) }
if ($LlvmHome) { $verificationArguments += @('--llvm', $LlvmHome) }
if ($ArtifactDirectory) { $verificationArguments += @('--output', $ArtifactDirectory) }
if ($CompilerLinkBridgeProof) { $verificationArguments += @('--bridge-proof', $CompilerLinkBridgeProof) }
foreach ($directory in $ReusableCompilerDirectories) { $verificationArguments += @('--reusable-directory', $directory) }
& $python (Join-Path $PSScriptRoot 'verify-cpu-aes-dispatch.py') @verificationArguments
if ($LASTEXITCODE -ne 0) { throw 'MANAGED_CPU_AES_VERIFICATION_FAILED' }
