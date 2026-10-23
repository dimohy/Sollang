$ErrorActionPreference = 'Stop'
$taskRoot = (Get-Location).Path
$taskBase = Join-Path $taskRoot 'artifacts/scratch/resume-20261006-owner-continuation22'
$candidateOutput = Join-Path $taskBase 'readonly-elements13316-candidate'
if (Test-Path -LiteralPath $candidateOutput) { throw 'Candidate output must be fresh.' }
[IO.Directory]::CreateDirectory($candidateOutput) | Out-Null
& scripts/record-compiler-defect-shaping-receipt.ps1 `
    -DefectId C2026-10-24-728 -Phase candidate `
    -InputFingerprint 2D9F5B134C34663E3CC76702F1523210B7822AF1FBCD51320DB013CF4AE72A6A `
    -FilePath (Join-Path $taskBase 'v13312/compiler-build01/compiler.exe') `
    -ArgumentList @('build', 'examples/regression/1471-region-array-readonly-values.slg',
        '-o', (Join-Path $candidateOutput 'probe.exe'), '--stdlib', (Join-Path $taskRoot 'stdlib'),
        '--target', 'windows-x64', '--keep-temps', '-O1', '--jobs', '1',
        '--llvm', (Join-Path $taskRoot '.tools/llvm-22.1.8')) `
    -TimeoutMilliseconds 180000 -ExpectedExitCode 0
