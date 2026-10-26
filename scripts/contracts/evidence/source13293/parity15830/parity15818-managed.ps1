$ErrorActionPreference = 'Stop'
$base = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& ./scripts/verify-c527-indexed-member-topology.ps1 -ManagedCompiler (Join-Path $base 'managed15734/compiler/Sollang.Compiler.exe') -OutputDirectory (Join-Path $base 'parity15818-managed-topology1')
if (-not $?) { throw 'Current topology managed check failed' }
