$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. (Join-Path $root 'scripts/verification-process.ps1')
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$source=Join-Path $b 'parallel12425-source'
$proof=Get-Content -LiteralPath (Join-Path $source 'result.json') -Raw|ConvertFrom-Json
if($proof.status -ne 'passed' -or -not $proof.inputsStable -or -not $proof.processesStopped){throw 'SOURCE_EMISSION_NOT_QUALIFIED'}
$o=Join-Path $b 'parallel12422-runtime'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
function LinuxPath([string]$p){
 if($p -notmatch '^W:\\' -or $p.Contains("'") -or $p.Contains("`n")){throw 'UNSAFE_LINUX_PATH'}
 return '/mnt/w/'+$p.Substring(3).Replace('\','/')
}
$contract=Join-Path $root 'scripts/contracts/parallel-callback-body.json'
$plan=Get-Content -LiteralPath $contract -Raw|ConvertFrom-Json
$inputs=@($PSCommandPath,$contract,(Join-Path $source 'result.json'),(Join-Path $root 'scripts/verification-process.ps1'))
foreach($c in $proof.cases){$inputs+=Join-Path $source ($c.id+'/emitted.ll')}
$fullScript=Join-Path $o 'full.sh';$linuxBinary=LinuxPath (Join-Path $o 'original-linux')
[IO.File]::WriteAllText($fullScript,"test -c /dev/full || exit 125`nexec '$linuxBinary' > /dev/full`n",[Text.UTF8Encoding]::new($false));$inputs+=$fullScript
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='Current C685 SLG source execution: original Linux normal/failure and four related Windows callback shapes, with direct-pool and complete-body decisions checked';completed=0;total=6;inputHashes=$hashes;cases=@();steps=@();bodyDecisions=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
function Run([string]$id,[string]$file,[string[]]$argv){
 if(-not(Stable)){throw 'INPUT_DRIFT'}
 $record=Join-Path $o ($id+'.execution.json')
 $a=Invoke-VerificationProcessCapture -FilePath $file -ArgumentList $argv -WorkingDirectory $root -Description $id -TimeoutMilliseconds 120000 -ExecutionRecordPath $record
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
   $content=[IO.File]::ReadAllText($llvm)
   $main=[regex]::Match($content,'(?ms)^define i32 @main\([^\n]*\) \{\r?\n(.*?)^\}')
   if(-not $main.Success){throw 'MAIN_BODY_NOT_FOUND'}
   $usesPool=$main.Groups[1].Value.Contains('call void @sollang_compute_execute(')
   $expectedPool=$case.id -eq 'direct-windows'
   $r.bodyDecisions+=@{id=$case.id;usesComputePool=$usesPool;expectedComputePool=$expectedPool}
   if($usesPool -ne $expectedPool){throw ('CALLBACK_DIRECT_BODY_DECISION_MISMATCH '+$case.id)}
   $a=Run ($case.id+'-link') (Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe') @('-Wno-override-module',$llvm,'-O0','-o',($binary+'.exe'),'-lws2_32','-lshell32','-lbcrypt','-lole32')
  }
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('LINK_FAILED '+$case.id+': '+$a.Stderr)}
 }
 $cases=@(@{id='original-normal';exit=0;stdout="1`n2`n3`n3`n2`n4`n6`n";file='wsl.exe';argv=@('-d','Ubuntu','--exec',$linuxBinary)},@{id='original-full';exit=1;stdout='';file='wsl.exe';argv=@('-d','Ubuntu','--exec','/bin/sh',(LinuxPath $fullScript))})
 foreach($case in $plan.cases){$cases+=@{id=$case.id;exit=0;stdout=($case.stdout+"`n");file=(Join-Path $o ($case.id+'-windows.exe'));argv=@()}}
 foreach($case in $cases){
  $a=Run $case.id $case.file $case.argv
  $passed=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and -not $a.Stderr.Trim()
  $r.cases+=@{id=$case.id;expectedRuntimeExit=$case.exit;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;passed=$passed};Save
  if(-not $passed){throw ('RUNTIME_ORACLE_FAILED '+$case.id)}
  $r.completed++;Save
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{
 $r.inputsStable=Stable
 $r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0
 Save
}
[pscustomobject]$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
