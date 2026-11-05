[CmdletBinding()]
param(
    [string]$SelfhostCompiler = '',
    [string]$ManagedCompilerAssembly = '',
    [string]$LlvmHome = '',
    [string]$Fixture = '',
    [string]$ExpectedPath = '',
    [string]$ArtifactDirectory = '',
    [ValidateRange(1, 1000)][int]$CaseCount = 3,
    [string]$CompilerLinkBridgeProof = '',
    [string[]]$ReusableCompilerDirectories = @(),
    [switch]$KeepProducts
)
$Compiler = $SelfhostCompiler
$CompilerAssembly = $ManagedCompilerAssembly
$Label = 'differential'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$verificationArguments = @('--mode', 'differential', '--label', $Label)
if ($CompilerAssembly) { $verificationArguments += @('--managed-compiler', $CompilerAssembly) }
if ($Compiler) { $verificationArguments += @('--selfhost-compiler', $Compiler) }
if ($LlvmHome) { $verificationArguments += @('--llvm', $LlvmHome) }
if ($ArtifactDirectory) { $verificationArguments += @('--output', $ArtifactDirectory) }
if ($CompilerLinkBridgeProof) { $verificationArguments += @('--bridge-proof', $CompilerLinkBridgeProof) }
foreach ($directory in $ReusableCompilerDirectories) { $verificationArguments += @('--reusable-directory', $directory) }
if (-not $Compiler) { $verificationArguments += @('--selfhost-compiler', (Join-Path $repoRoot 'artifacts/example-tests/selfhost-sollangc-driver.exe')) }
if ($Fixture) { $verificationArguments += @('--fixture', $Fixture) }
if ($ExpectedPath) { $verificationArguments += @('--expected', $ExpectedPath) }
$verificationArguments += @('--case-count', [string]$CaseCount)
if ($KeepProducts) { $verificationArguments += '--keep-products' }
& $python (Join-Path $PSScriptRoot 'verify-cpu-aes-dispatch.py') @verificationArguments
if ($LASTEXITCODE -ne 0) { throw 'CPU_AES_DIFFERENTIAL_VERIFICATION_FAILED' }
