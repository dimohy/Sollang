param([ValidateSet('managed','native')][string]$Backend='managed')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. scripts/ArtifactLifecycle.ps1
. scripts/verification-process.ps1
. scripts/verification-compiler-build.ps1
$root=(Get-Location).Path
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$compiler=if($Backend -eq 'managed'){Join-Path $b 'managed12499/compiler/Sollang.Compiler.exe'}else{Join-Path $b 'v12536/compiler-build01/compiler.exe'}
$identity=if($Backend -eq 'managed'){[IO.Path]::ChangeExtension($compiler,'dll')}else{$compiler}
$expectedHash=if($Backend -eq 'managed'){'3C5518BB1763BDB5D4B046B57376FF07E4F5056EA08B0CF9A63AB633EF88B1D5'}else{'E06B17AF04DE65B36A50FFA4C28B732687B31BD95A26CD06CA8F46F7CAAD8D4A'}
if((Get-FileHash -LiteralPath $identity -Algorithm SHA256).Hash -cne $expectedHash){throw 'COMPILER_DRIFT'}
if($Backend -eq 'native'){
 $prior=Get-Content -LiteralPath (Join-Path $b 'index12548-managed/result.json') -Raw|ConvertFrom-Json
 if($prior.status -cne 'passed' -or $prior.completed -ne 3 -or -not $prior.inputsStable -or -not $prior.processesStopped){throw 'CSHARP_FIRST_NOT_QUALIFIED'}
}
$o=Join-Path $b ('index12548-'+$Backend)
Initialize-ArtifactOutput -OutputDirectory $o -ReusableCompilerDirectories @((Join-Path $b 'v12432/compiler-build01'),(Join-Path $b 'v12536/compiler-build01'),(Join-Path $b 'v12515/compiler-build01'))
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$cases=@(@{id='interpolation-array-index';stdout="20,50,80`n30,60,90`n"},@{id='interpolation-reference-index';stdout="fixed=22`ngrowable=33`n"},@{id='interpolation-index-order';stdout="index=0`n5`nindex=1`n7`nloop=5`nloop=7`nlogical=true`n"})
$inputs=@($PSCommandPath,$compiler,$identity,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $root 'scripts/verification-compiler-build.ps1'))
$inputs+=@($cases|ForEach-Object{Join-Path $root ('scripts/probes/source-review-boundaries/'+$_.id+'.slg')})
$inputs+=@([IO.Directory]::GetFiles((Join-Path $root 'stdlib'),'*.slg',[IO.SearchOption]::AllDirectories))
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='Three normal valid-index programs, including storage shapes, readonly references, evaluation order, loop and logical expression. Runtime3000ms each. Missing guard is judged from actual LLVM, no invalid index execution.';backend=$Backend;compilerSha256=$expectedHash;inputHashes=$hashes;completed=0;total=3;failed=0;cases=@();builds=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
Save
try{
 foreach($case in $cases){
  if(-not(Stable)){throw 'INPUT_DRIFT'}
  $source=Join-Path $root ('scripts/probes/source-review-boundaries/'+$case.id+'.slg');$exe=Join-Path $o ($case.id+'.exe')
  $a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source $source -Output $exe -Target windows-x64 -WorkingDirectory $root -Description ($Backend+' review '+$case.id) -TimeoutMilliseconds 120000
  $r.builds+=@{id=$case.id;buildRecord=($exe+'.compiler-build.json')};Save
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('BUILD_FAILED '+$case.id+': '+$a.Stderr)}
  $record=Join-Path $o ($case.id+'.execution.json');$r.steps+=@{id=$case.id;executionRecord=$record};Save
  try{
   $a=Invoke-VerificationProcessCapture -FilePath $exe -WorkingDirectory $root -Description ($Backend+' review normal run '+$case.id) -TimeoutMilliseconds 3000 -ExecutionRecordPath $record
   $ok=$a.ExitCode -eq 0 -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and -not $a.Stderr
   $row=@{id=$case.id;passed=$ok;buildExit=0;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;expectedStdout=$case.stdout;expectedRunExit=0}
  }catch{
   if(-not(Test-Path -LiteralPath $record)){throw}
   $stopped=Get-Content -LiteralPath $record -Raw|ConvertFrom-Json
   if($stopped.status -cne 'timed-out' -or -not $stopped.processesStopped){throw}
   $ok=$false;$row=@{id=$case.id;passed=$false;buildExit=0;timedOut=$true;executionRecord=$record;expectedStdout=$case.stdout;expectedRunExit=0;failure=$_.Exception.Message}
  }
  $r.cases+=@($row);if($ok){$r.completed++}else{$r.failed++};Save
  if($Backend -eq 'managed' -and -not $ok){throw ('CSHARP_ORACLE_FAILED '+$case.id)}
 }
 $r.status=if($r.failed -eq 0){'passed'}else{'failed'}
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.inputsStable=Stable;$r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0 -and @($r.builds|Where-Object{(Get-Content -LiteralPath $_.buildRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0;Save}
[pscustomobject]$r|Select-Object status,completed,total,failed,inputsStable,processesStopped|ConvertTo-Json -Compress


