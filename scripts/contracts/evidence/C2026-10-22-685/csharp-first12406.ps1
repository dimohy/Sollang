$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. (Join-Path $root 'scripts/verification-process.ps1')
. (Join-Path $root 'scripts/verification-compiler-build.ps1')
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$o=Join-Path $b 'parallel12406-managed'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$compiler=Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe'
$source=Join-Path $root 'examples/regression/c385-builtin-parallel-role-interpolation.slg'
$binary=Join-Path $o 'probe'
$linux='/mnt/w/'+$binary.Substring(3).Replace('\','/')
if($linux.Contains("'") -or $linux.Contains("`n")){throw 'UNSAFE_LINUX_PATH'}
$scriptPath=Join-Path $o 'full.sh'
[IO.File]::WriteAllText($scriptPath,"test -c /dev/full || exit 125`nexec '$linux' > /dev/full`n",[Text.UTF8Encoding]::new($false))
$inputs=@($PSCommandPath,$compiler,($compiler -replace '\.exe$','.dll'),$source,$scriptPath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $root 'scripts/verification-compiler-build.ps1'))
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='CSharp first: original parallel output source, real Linux normal output and ENOSPC';completed=0;total=2;inputHashes=$hashes;cases=@();steps=@()}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 10)+"`n",[Text.UTF8Encoding]::new($false))}
Save
try{
 $a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source $source -Output $binary -Target linux-x64 -WorkingDirectory $root -Description 'C684 CSharp parallel output' -TimeoutMilliseconds 120000
 if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw 'MANAGED_PARALLEL_BUILD_FAILED'}
 foreach($case in @(@{id='normal';args=@('-d','Ubuntu','--exec',$linux);exit=0;stdout="1`n2`n3`n3`n2`n4`n6`n"},@{id='full';args=@('-d','Ubuntu','--exec','/bin/sh',('/mnt/w/'+$scriptPath.Substring(3).Replace('\','/')));exit=1;stdout=''})){
  $record=Join-Path $o ($case.id+'.execution.json')
  $a=Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList $case.args -WorkingDirectory $root -Description ('CSharp parallel '+$case.id) -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  $r.steps+=@{id=$case.id;executionRecord=$record}
  $passed=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and -not $a.Stderr.Trim()
  $r.cases+=@{id=$case.id;expectedRuntimeExit=$case.exit;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;passed=$passed};Save
  if(-not $passed){throw ('MANAGED_PARALLEL_ORACLE_FAILED '+$case.id)}
  $r.completed++
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{
 $r.inputsStable=@($hashes.GetEnumerator()|Where-Object{(Get-FileHash -LiteralPath $_.Key -Algorithm SHA256).Hash -cne $_.Value}).Count -eq 0
 $r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0
 Save
}
[pscustomobject]$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
