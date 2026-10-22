$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. (Join-Path $root 'scripts/verification-process.ps1')
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$source=Join-Path $b 'stdout12396-source'
$proof=Get-Content (Join-Path $source 'result.json') -Raw | ConvertFrom-Json
if ($proof.status -ne 'passed' -or -not $proof.inputsStable -or -not $proof.processesStopped) {throw 'SOURCE_PROOF_NOT_PASSED'}
$o=Join-Path $b 'stdout12391-runtime'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
function LinuxPath([string]$p){
 if($p -notmatch '^W:\\' -or $p.Contains("'") -or $p.Contains("`n")){throw 'UNSAFE_LINUX_PATH'}
 return '/mnt/w/'+$p.Substring(3).Replace('\','/')
}
$inputs=@($PSCommandPath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $source 'result.json'))
foreach($case in $proof.cases){$inputs+=Join-Path $source ($case.id+'/emitted.ll')}
$managedRead=Join-Path $b 'stdout12385-read-control/read'
$inputs+=@($managedRead,($managedRead+'.ll'))
$inputPath=Join-Path $o 'input.txt';[IO.File]::WriteAllText($inputPath,"42`n",[Text.UTF8Encoding]::new($false));$inputs+=$inputPath
$cases=@(
 @{id='output-normal';program='output-linux';exit=0;stdout="buffered-output`n";stderr='';redirect=''},
 @{id='output-full';program='output-linux';exit=1;stdout='';stderr='';redirect=' > /dev/full'},
 @{id='prior-normal';program='prior-linux';exit=0;stdout="after`n";stderr="error-output`n";redirect=''},
 @{id='prior-full';program='prior-linux';exit=1;stdout="after`n";stderr='';redirect=' 2> /dev/full'},
 @{id='read-normal';program='read-linux';exit=0;stdout="number?42`n";stderr='';redirect=''},
 @{id='read-full';program='read-linux';exit=1;stdout='';stderr='';redirect=' > /dev/full'},
 @{id='managed-read-full';program='managed-read-linux';exit=1;stdout='';stderr='';redirect=' > /dev/full'},
 @{id='windows-normal';program='output-windows';exit=0;stdout="buffered-output`n";stderr='';redirect=''}
)
foreach($c in $cases){
 if($c.program -notlike '*windows'){
  $scriptPath=Join-Path $o ($c.id+'.sh');$program=if($c.id -eq 'managed-read-full'){LinuxPath $managedRead}else{LinuxPath (Join-Path $o $c.program)}
  [IO.File]::WriteAllText($scriptPath,"test -c /dev/full || exit 125`nexec '$program'$($c.redirect)`n",[Text.UTF8Encoding]::new($false));$inputs+=$scriptPath
 }
}
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='Real emitted SLG programs: Linux output, stderr failure preservation and prompt/input; Windows normal output';inputHashes=$hashes;completed=0;total=8;cases=@();steps=@();claimsGoalComplete=$false}
function Save { [IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false)) }
function Stable {foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
function Run([string]$id,[string]$file,[string[]]$argv,[string]$stdin=''){
 if(-not(Stable)){throw 'INPUT_DRIFT'}
 $record=Join-Path $o ($id+'.execution.json')
 $a=Invoke-VerificationProcessCapture -FilePath $file -ArgumentList $argv -WorkingDirectory $root -Description $id -StandardInputPath $stdin -TimeoutMilliseconds 120000 -ExecutionRecordPath $record
 $r.steps+=@{id=$id;executionRecord=$record;exit=$a.ExitCode};Save;return $a
}
Save
try{
 $a=Run 'clang-hash' 'wsl.exe' @('-d','Ubuntu','--exec','/usr/bin/sha256sum','/usr/lib/llvm-18/bin/clang')
 if($a.ExitCode -ne 0 -or -not $a.Stdout.StartsWith('8ef402d453d1ba4902e4ee0f0f847f6cfa01400c95aa43c24e97818b9c0e3f45')){throw 'CLANG_PIN_MISMATCH'}
 foreach($case in $proof.cases){
  $llvm=Join-Path $source ($case.id+'/emitted.ll');$binary=Join-Path $o $case.id
  if($case.target -eq 'linux'){
   $a=Run ($case.id+'-link') 'wsl.exe' @('-d','Ubuntu','--exec','/usr/bin/timeout','90','/usr/bin/clang','-Wno-override-module',(LinuxPath $llvm),'-O0','-pthread','-o',(LinuxPath $binary))
  }else{
   $a=Run ($case.id+'-link') (Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe') @('-Wno-override-module',$llvm,'-O0','-o',($binary+'.exe'),'-lws2_32','-lshell32','-lbcrypt','-lole32')
  }
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('LINK_FAILED '+$case.id+': '+$a.Stderr)}
 }
 foreach($case in $cases){
  if($case.program -like '*windows'){$a=Run $case.id (Join-Path $o ($case.program+'.exe')) @()}
  else{$a=Run $case.id 'wsl.exe' @('-d','Ubuntu','--exec','/bin/sh',(LinuxPath (Join-Path $o ($case.id+'.sh')))) $inputPath}
  $passed=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and $a.Stderr.Replace("`r`n","`n") -ceq $case.stderr
  $r.cases+=@{id=$case.id;expectedRuntimeExit=$case.exit;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;passed=$passed};Save
  if(-not $passed){throw ('ORACLE_FAILED '+$case.id)}
  $r.completed++;Save
 }
 $r.slgProgramChecks=@{completed=7;total=7};$r.additionalManagedProgramChecks=@{completed=1;total=1};$r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{
 $r.inputsStable=Stable
 $r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0
 Save
}
$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
