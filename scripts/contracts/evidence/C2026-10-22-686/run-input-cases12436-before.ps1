param([Parameter(Mandatory)][string]$Program,[Parameter(Mandatory)][string]$OutputDirectory,[string]$Label='candidate')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. (Join-Path $root 'scripts/verification-process.ps1')
$programPath=(Resolve-Path -LiteralPath $Program).Path
$o=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
if($programPath -notmatch '^W:\\' -or $programPath.Contains("'")){throw 'UNSAFE_PATH'}
$planPath=Join-Path $root 'scripts/contracts/evidence/C2026-10-22-686/input-contract.json'
$plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
$inputs=@($PSCommandPath,$planPath,$programPath,($programPath+'.ll'),(Join-Path $root 'scripts/verification-process.ps1'))
foreach($case in $plan.cases){
 $p=Join-Path $o ($case.id+'.txt');[IO.File]::WriteAllText($p,$case.stdin,[Text.UTF8Encoding]::new($false));$inputs+=$p
 $s=Join-Path $o ($case.id+'.sh');[IO.File]::WriteAllText($s,"test -c /dev/full || exit 125`nexec '/mnt/w/"+$programPath.Substring(3).Replace('\','/')+"'$($case.redirect)`n",[Text.UTF8Encoding]::new($false));$inputs+=$s
}
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';label=$Label;inputHashes=$hashes;completed=0;total=$plan.cases.Count;passed=0;cases=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
Save
try{
 foreach($case in $plan.cases){
  if(-not(Stable)){throw 'INPUT_DRIFT'}
  $id=$case.id;$record=Join-Path $o ($id+'.execution.json');$script='/mnt/w/'+(Join-Path $o ($id+'.sh')).Substring(3).Replace('\','/')
  $a=Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d','Ubuntu','--exec','/bin/sh',$script) -WorkingDirectory $root -Description ($Label+' '+$id) -StandardInputPath (Join-Path $o ($id+'.txt')) -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  $r.steps+=@{id=$id;executionRecord=$record};$ok=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and $a.Stderr.Replace("`r`n","`n") -ceq $case.stderr
  $r.cases+=@{id=$id;expectedRuntimeExit=$case.exit;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;passed=$ok};$r.completed++;if($ok){$r.passed++};Save
 }
 $r.status=if($r.passed -eq $r.total){'passed'}else{'mismatch-observed'}
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.inputsStable=Stable;$r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0;Save}
[pscustomobject]$r|Select-Object status,label,completed,total,passed,inputsStable,processesStopped|ConvertTo-Json -Compress
