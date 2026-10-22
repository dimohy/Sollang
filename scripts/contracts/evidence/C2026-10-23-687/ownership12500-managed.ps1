$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. scripts/ArtifactLifecycle.ps1
. scripts/verification-process.ps1
. scripts/verification-compiler-build.ps1
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$o=Join-Path $b 'ownership12500-managed'
$reuse=@((Join-Path $b 'v12405/compiler-build01'),(Join-Path $b 'v12432/compiler-build01'),(Join-Path $b 'v12443/compiler-build01'))
Initialize-ArtifactOutput -OutputDirectory $o -ReusableCompilerDirectories $reuse
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$cpath=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22/ownership12500-contract.json'
$c=Get-Content -LiteralPath $cpath -Raw|ConvertFrom-Json
$compiler=Join-Path $b 'managed12499/compiler/Sollang.Compiler.exe'
if((Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($compiler,'dll')) -Algorithm SHA256).Hash -cne $c.expectedManagedDllSha256){throw 'MANAGED_COMPILER_DRIFT'}
$inputs=@($PSCommandPath,$cpath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $root 'scripts/verification-compiler-build.ps1'))
$inputs+=@([IO.Directory]::GetFiles((Join-Path $root 'stdlib'),'*.slg',[IO.SearchOption]::AllDirectories))
$inputs+=@($c.cases|ForEach-Object{Join-Path $root $_.source})
$inputs+=@([IO.Directory]::GetFiles([IO.Path]::GetDirectoryName($compiler),'Sollang.Compiler.*'))
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope=$c.scope;inputHashes=$hashes;completed=0;total=$c.cases.Count;cases=@();builds=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
Save
try{
 foreach($case in $c.cases){
  if(-not(Stable)){throw 'INPUT_DRIFT'}
  $binary=Join-Path $o ($case.id+'.exe')
  $a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source (Join-Path $root $case.source) -Output $binary -Target windows-x64 -WorkingDirectory $root -Description ('CSharp ownership '+$case.id) -TimeoutMilliseconds 120000
  $r.builds+=@{id=$case.id;buildRecord=($binary+'.compiler-build.json');buildExit=$a.ExitCode};Save
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('CSHARP_BUILD_FAILED '+$case.id+': '+$a.Stderr)}
  $record=Join-Path $o ($case.id+'.execution.json')
  $a=Invoke-VerificationProcessCapture -FilePath $binary -WorkingDirectory $root -Description ('CSharp ownership '+$case.id) -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  $r.steps+=@{id=$case.id;executionRecord=$record}
  $ok=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and $a.Stderr.Replace("`r`n","`n") -ceq $case.stderr
  $r.cases+=@{id=$case.id;passed=$ok;runExit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;expectedRuntimeExit=$case.exit};Save
  if(-not $ok){throw ('CSHARP_RUNTIME_ORACLE_FAILED '+$case.id)}
  $r.completed++;Save
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.inputsStable=Stable;$r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0 -and @($r.builds|Where-Object{(Get-Content -LiteralPath $_.buildRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0;Save}
[pscustomobject]$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
