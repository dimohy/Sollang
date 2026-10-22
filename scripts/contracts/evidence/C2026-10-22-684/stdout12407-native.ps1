$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. (Join-Path $root 'scripts/verification-process.ps1')
. (Join-Path $root 'scripts/verification-compiler-build.ps1')
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$compiler=Join-Path $b 'v12405/compiler-build01/compiler.exe'
$buildProof=Join-Path $b 'v12405/compiler-build01/result.json'
$proof=Get-Content -LiteralPath $buildProof -Raw|ConvertFrom-Json
if($proof.status -ne 'passed' -or -not $proof.inputsStable -or $proof.compilerSha256 -cne (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash){throw 'NATIVE_BUILD_NOT_VERIFIED'}
$o=Join-Path $b 'stdout12407-native'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
function LinuxPath([string]$p){
 if($p -notmatch '^W:\\' -or $p.Contains("'") -or $p.Contains("`n")){throw 'UNSAFE_LINUX_PATH'}
 return '/mnt/w/'+$p.Substring(3).Replace('\','/')
}
$programs=@(
 @{id='output-linux';target='linux-x64';source=(Join-Path $b 'stdout12389-inputs/output.slg')},
 @{id='prior-linux';target='linux-x64';source=(Join-Path $b 'stdout12389-inputs/prior.slg')},
 @{id='read-linux';target='linux-x64';source=(Join-Path $b 'stdout12389-inputs/read.slg')},
 @{id='parallel-linux';target='linux-x64';source=(Join-Path $root 'examples/regression/c385-builtin-parallel-role-interpolation.slg')},
 @{id='output-windows.exe';target='windows-x64';source=(Join-Path $b 'stdout12389-inputs/output.slg')}
)
$cases=@(
 @{id='output-normal';program='output-linux';exit=0;stdout="buffered-output`n";stderr='';redirect=''},
 @{id='output-full';program='output-linux';exit=1;stdout='';stderr='';redirect=' > /dev/full'},
 @{id='prior-normal';program='prior-linux';exit=0;stdout="after`n";stderr="error-output`n";redirect=''},
 @{id='prior-full';program='prior-linux';exit=1;stdout="after`n";stderr='';redirect=' 2> /dev/full'},
 @{id='read-normal';program='read-linux';exit=0;stdout="number?42`n";stderr='';redirect=''},
 @{id='read-full';program='read-linux';exit=1;stdout='';stderr='';redirect=' > /dev/full'},
 @{id='parallel-normal';program='parallel-linux';exit=0;stdout="1`n2`n3`n3`n2`n4`n6`n";stderr='';redirect=''},
 @{id='parallel-full';program='parallel-linux';exit=1;stdout='';stderr='';redirect=' > /dev/full'},
 @{id='windows-normal';program='output-windows.exe';exit=0;stdout="buffered-output`n";stderr='';redirect=''}
)
$inputPath=Join-Path $o 'input.txt';[IO.File]::WriteAllText($inputPath,"42`n",[Text.UTF8Encoding]::new($false))
$inputs=@($PSCommandPath,$compiler,$buildProof,$inputPath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $root 'scripts/verification-compiler-build.ps1'),(Join-Path $root 'scripts/contracts/verification-compiler-build.json'))
$inputs+=@($programs|ForEach-Object{$_.source})
$inputs+=@([IO.Directory]::GetFiles((Join-Path $root 'stdlib'),'*.slg',[IO.SearchOption]::AllDirectories))
foreach($c in $cases){
 if($c.program -notlike '*.exe'){
  $scriptPath=Join-Path $o ($c.id+'.sh');$program=LinuxPath (Join-Path $o $c.program)
  [IO.File]::WriteAllText($scriptPath,"test -c /dev/full || exit 125`nexec '$program'$($c.redirect)`n",[Text.UTF8Encoding]::new($false));$inputs+=$scriptPath
 }
}
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='Fresh V12405 native compiler C684 real OS verification: Linux normal/failing stdout, stderr, input and parallel replay; Windows normal output';compilerSha256=$proof.compilerSha256;inputHashes=$hashes;completed=0;total=9;cases=@();builds=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
Save
try{
 foreach($program in $programs){
  if(-not(Stable)){throw 'INPUT_DRIFT_BEFORE_BUILD'}
  $binary=Join-Path $o $program.id
  $a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source $program.source -Output $binary -Target $program.target -WorkingDirectory $root -Description ('C684 native '+$program.id) -TimeoutMilliseconds 120000
  $r.builds+=@{id=$program.id;buildRecord=($binary+'.compiler-build.json');buildExit=$a.ExitCode;emittedLlvmSha256=(Get-FileHash -LiteralPath ($binary+'.ll') -Algorithm SHA256).Hash};Save
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('NATIVE_BUILD_FAILED '+$program.id+': '+$a.Stderr)}
 }
 foreach($case in $cases){
  if(-not(Stable)){throw 'INPUT_DRIFT_BEFORE_RUN'}
  $record=Join-Path $o ($case.id+'.execution.json')
  if($case.program -like '*.exe'){
   $a=Invoke-VerificationProcessCapture -FilePath (Join-Path $o $case.program) -WorkingDirectory $root -Description $case.id -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  }else{
   $a=Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d','Ubuntu','--exec','/bin/sh',(LinuxPath (Join-Path $o ($case.id+'.sh')))) -StandardInputPath $inputPath -WorkingDirectory $root -Description $case.id -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  }
  $r.steps+=@{id=$case.id;executionRecord=$record}
  $passed=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and $a.Stderr.Replace("`r`n","`n") -ceq $case.stderr
  $r.cases+=@{id=$case.id;expectedRuntimeExit=$case.exit;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;passed=$passed};Save
  if(-not $passed){throw ('NATIVE_RUNTIME_ORACLE_FAILED '+$case.id)}
  $r.completed++;Save
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{
 $r.inputsStable=Stable
 $r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0 -and @($r.builds|Where-Object{(Get-Content -LiteralPath $_.buildRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0
 Save
}
[pscustomobject]$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
