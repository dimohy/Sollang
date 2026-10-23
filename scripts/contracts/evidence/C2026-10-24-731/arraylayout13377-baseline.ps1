$ErrorActionPreference = 'Stop'
$taskRoot = (Get-Location).Path
$taskBase = Join-Path $taskRoot 'artifacts/scratch/resume-20261006-owner-continuation22'
& scripts/record-compiler-defect-shaping-receipt.ps1 `
 -DefectId C2026-10-24-731 -Phase baseline -InputFingerprint 712D3C4D77ACC5A82551FB0D2550B53DCCC0DF3C896CF6ADA65363FE52552080 `
 -FilePath (Get-Command python).Source `
 -ArgumentList @('artifacts/scratch/resume-20261006-owner-continuation22/arraylayout13377-baseline-oracle.py','--compiler',(Join-Path $taskBase 'v13347/compiler-build01/compiler.exe'),'--output',(Join-Path $taskBase 'arraylayout13377-baseline')) `
 -TimeoutMilliseconds 180000 -ExpectedExitCode 1
