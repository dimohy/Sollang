$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. (Join-Path $root 'scripts/verification-process.ps1')
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$o=Join-Path $b 'input12435-observation'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$programs=@{managed=(Join-Path $b 'stdout12385-read-control/read');native=(Join-Path $b 'native12433-qualification/read-linux')}
$inputs=@($PSCommandPath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $b 'stdout12389-inputs/read.slg'))
$streams=@{normal="42`n";eof='';invalid="abc`n"}
foreach($k in $streams.Keys){$p=Join-Path $o ($k+'.txt');[IO.File]::WriteAllText($p,$streams[$k],[Text.UTF8Encoding]::new($false));$inputs+=$p}
foreach($k in $programs.Keys){$p=$programs[$k];if($p -notmatch '^W:\\' -or $p.Contains("'")){throw 'UNSAFE_PATH'};$s=Join-Path $o ($k+'.sh');[IO.File]::WriteAllText($s,"exec '/mnt/w/"+$p.Substring(3).Replace('\','/')+"'`n",[Text.UTF8Encoding]::new($false));$inputs+=@($p,($p+'.ll'),$s)}
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='Focused existing CSharp/native input parsing comparison; no new producer build';inputHashes=$hashes;completed=0;total=6;cases=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
Save
try{
 foreach($compiler in @('managed','native')){foreach($kind in @('normal','eof','invalid')){
  if(-not(Stable)){throw 'INPUT_DRIFT'}
  $id=$compiler+'-'+$kind;$record=Join-Path $o ($id+'.execution.json');$script='/mnt/w/'+(Join-Path $o ($compiler+'.sh')).Substring(3).Replace('\','/')
  $a=Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d','Ubuntu','--exec','/bin/sh',$script) -WorkingDirectory $root -Description $id -StandardInputPath (Join-Path $o ($kind+'.txt')) -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  $r.steps+=@{id=$id;executionRecord=$record};$r.cases+=@{id=$id;compiler=$compiler;input=$kind;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr};$r.completed++;Save
 }}
 $r.status='observed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.inputsStable=Stable;$r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0;Save}
$r|Select-Object status,completed,total,cases,inputsStable,processesStopped|ConvertTo-Json -Depth 4
