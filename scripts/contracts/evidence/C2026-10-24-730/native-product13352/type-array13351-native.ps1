$ErrorActionPreference = 'Stop'
$taskBase = Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22'
& python scripts/verify-c385-preir-call-numeric.py --mode paired `
    --output (Join-Path $taskBase 'type-array13351-native') `
    --build (Join-Path $taskBase 'v13347/compiler-build01') `
    --managed-proof (Join-Path $taskBase 'type-array13335-managed/result.json') `
    --managed-compiler (Join-Path $taskBase 'managed13239/compiler/Sollang.Compiler.exe') `
    --format-compiler (Join-Path $taskBase 'v12432/compiler-build01/compiler.exe') `
    --artifact-cleanup plan-only `
    --reusable-compiler-directory (Join-Path $taskBase 'v12432/compiler-build01') `
    --reusable-compiler-directory (Join-Path $taskBase 'v13312/compiler-build01') `
    --reusable-compiler-directory (Join-Path $taskBase 'v13347/compiler-build01') `
    --contract (Join-Path $taskBase 'type-array13335-contract.json') `
    --source-comparison (Join-Path (Get-Location).Path 'artifacts/scratch/resume-20261006-owner-continuation22/type-array13349-source-comparison.json')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
