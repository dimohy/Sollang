$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. scripts/verification-process.ps1
$root=(Get-Location).Path
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$o=Join-Path $b 'classifier12509'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$source=Join-Path $root 'scripts/probes/parallel-source-text-contract/blocking-classifier.slg'
$manifest=Get-Content tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt
$sources=@($source)+@($manifest|Select-Object -Skip 1|ForEach-Object{Join-Path $root $_})
$compiler=Join-Path $b 'managed12499/compiler/Sollang.Compiler.exe'
$exe=Join-Path $o 'probe.exe'
$a=Invoke-VerificationProcessCapture -FilePath $compiler -ArgumentList (@('build')+$sources+@('-o',$exe,'--target','windows-x64','--keep-temps','--llvm',(Join-Path $root '.tools/llvm-22.1.8'))) -WorkingDirectory $root -Description 'Actual production blocking classifier focused compile' -TimeoutMilliseconds 120000 -ExecutionRecordPath (Join-Path $o 'build.execution.json')
if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('BUILD_FAILED '+$a.Stderr)}
$a=Invoke-VerificationProcessCapture -FilePath $exe -WorkingDirectory $root -Description 'Actual production blocking classifier normal run' -TimeoutMilliseconds 30000 -ExecutionRecordPath (Join-Path $o 'run.execution.json')
if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw 'RUN_FAILED'}
$a.Stdout
