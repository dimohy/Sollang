[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$AuthorityPath = 'scripts/contracts/c527-historical-baseline-authority.json',
    [string]$OriginalEvidencePath = 'artifacts/scratch/c527-large-integer-float-slice-20260927-01.json'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-c527-historical-baseline.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$authority = Get-Content -LiteralPath ([IO.Path]::GetFullPath($AuthorityPath, $root)) -Raw | ConvertFrom-Json
$original = Get-Content -LiteralPath ([IO.Path]::GetFullPath($OriginalEvidencePath, $root)) -Raw | ConvertFrom-Json
$baseline = Get-C527HistoricalBaselineText -RepositoryRoot $root -OriginalEvidence $original -Authority $authority
Assert-C527Baseline ($baseline.Contains('sitofp i32 4294967296 to double', [StringComparison]::Ordinal)) 'C527_REPLAY_BAD_LLVM_NOT_OBSERVED'
[ordered]@{
    schemaVersion = 1; status = 'passed'; completed = 1; total = 1
    scope = 'C527 baseline authority and recorded behavior only'
    authority = $authority.mode; llvmCharacters = $baseline.Length
    claimsOriginalFileRecovery = $false; claimsWholeParityComplete = $false
} | ConvertTo-Json
