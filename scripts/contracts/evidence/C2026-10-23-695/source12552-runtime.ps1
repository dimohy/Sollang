$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. scripts/verification-process.ps1
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$source=Join-Path $b 'source12551-source'
$proofPath=Join-Path $source 'result.json'
$proof=Get-Content -LiteralPath $proofPath -Raw|ConvertFrom-Json -AsHashtable
if($proof.status -cne 'passed' -or -not $proof.inputsStable -or -not $proof.processesStopped -or $proof.completed -ne 43){throw 'SOURCE43_NOT_QUALIFIED'}
$cpath=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22/source12551-contract.json';$c=Get-Content -LiteralPath $cpath -Raw|ConvertFrom-Json
$o=Join-Path $b 'source12552-runtime'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$producer=Join-Path $source 'producer.exe'
if((Get-FileHash -LiteralPath $producer -Algorithm SHA256).Hash -cne $proof.producerSha256){throw 'PRODUCER_DRIFT'}
$clang=Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$hashes=[ordered]@{}
foreach($p in $proof.inputHashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $proof.inputHashes[$p]){throw ('SOURCE_INPUT_DRIFT '+$p)};$hashes[$p]=$proof.inputHashes[$p]}
foreach($p in @($PSCommandPath,$cpath,$proofPath,$producer,$clang,(Join-Path $root 'scripts/verification-process.ps1'))){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
foreach($case in $proof.cases){if($case.ContainsKey('admissionRejected')){continue};$p=Join-Path $source ($case.id+'/emitted.ll');$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;if($hashes[$p] -cne $case.emittedLlvmSha256){throw 'EMITTED_LLVM_DRIFT'}}
$r=[ordered]@{schemaVersion=1;status='running';scope='C695 new3 and prior34 normal runtime programs. Required semantic rejection6 remains separate. Boundary14 preserve3000ms; prior23 preserve120000ms. No invalid index execution; fresh native qualification pending.';inputHashes=$hashes;completed=0;total=37;cases=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
function Run([string]$id,[string]$file,[string[]]$argv,[int]$timeout=120000){
 if(-not(Stable)){throw 'INPUT_DRIFT'}
 $record=Join-Path $o ($id+'.execution.json')
 $a=Invoke-VerificationProcessCapture -FilePath $file -ArgumentList $argv -WorkingDirectory $root -Description $id -TimeoutMilliseconds $timeout -ExecutionRecordPath $record
 $r.steps+=@{id=$id;executionRecord=$record;exit=$a.ExitCode};Save;return $a
}
Save
try{
 foreach($case in @($c.cases | Sort-Object -Stable @{Expression={if($_.source -like 'scripts/probes/source-review-boundaries/*'){0}else{1}}})){if($case.PSObject.Properties['admitted'] -and -not $case.admitted){continue};
  $llvm=Join-Path $source ($case.id+'/emitted.ll');$exe=Join-Path $o ($case.id+'.exe')
  $a=Run ($case.id+'-link') $clang @('-Wno-override-module',$llvm,'-O0','-o',$exe,'-lws2_32','-lshell32','-lbcrypt','-lole32')
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('LINK_FAILED '+$case.id+': '+$a.Stderr)}
  $timeout=if($case.source -like 'scripts/probes/source-review-boundaries/*'){3000}else{120000}
  $a=Run ($case.id+'-run') $exe @() $timeout
  $ok=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and $a.Stderr.Replace("`r`n","`n") -ceq $case.stderr
  $r.cases+=@{id=$case.id;passed=$ok;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr};Save
  if(-not $ok){throw ('RUNTIME_ORACLE_FAILED '+$case.id)}
  $r.completed++;Save
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.inputsStable=Stable;$r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0;Save}
[pscustomobject]$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
