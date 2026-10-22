$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. scripts/verification-process.ps1
. scripts/verification-compiler-build.ps1
$root=(Get-Location).Path
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$out=Join-Path $b 'sourceboundary12489'
if(Test-Path -LiteralPath $out){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($out)
$compiler=Join-Path $b 'managed12488/compiler/Sollang.Compiler.exe'
$expected='7B4560A12CD77F417252A7583FA01B5E6201903E0546F990973B940D4EDC79E8'
if((Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($compiler,'dll')) -Algorithm SHA256).Hash -cne $expected){throw 'COMPILER_DRIFT'}
$r=[ordered]@{schemaVersion=1;scope='SPEC1909 CSharp admission6 negative and2 direct payload normal runtime controls';status='running';compilerDllSha256=$expected;cases=@();completed=0;total=8;claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $out 'result.json'),($r|ConvertTo-Json -Depth 10)+"`n",[Text.UTF8Encoding]::new($false))}
Save
try{
 foreach($id in @('direct-result','direct-error','plain','compound-plain','nested-array','nested-option','nested-result','nested-struct')){
  $source=Join-Path $root ('scripts/probes/parallel-source-text-contract/'+$id+'.slg')
  $exe=Join-Path $out ($id+'.exe')
  $a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source $source -Output $exe -Target windows-x64 -WorkingDirectory $root -Description ('SourceText admission '+$id) -TimeoutMilliseconds 120000
  $positive=$id -in @('direct-result','direct-error')
  $row=@{id=$id;source=$source;sourceSha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;exit=$a.ExitCode;stdout=$a.Stdout;stderr=$a.Stderr;expectedAdmission=$positive}
  $r.cases+=@($row);Save
  if($positive){
   if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('POSITIVE_BUILD_FAILED '+$id)}
   $z=Invoke-VerificationProcessCapture -FilePath $exe -WorkingDirectory $root -Description ('SourceText normal run '+$id) -TimeoutMilliseconds 30000 -ExecutionRecordPath ($exe+'.execution.json')
   $wanted=if($id -eq 'direct-result'){"1`n"}else{"6`n"}
   $row.runExit=$z.ExitCode;$row.runStdout=$z.Stdout;$row.runStderr=$z.Stderr
   if($z.ExitCode -ne 0 -or $z.Stderr.Trim() -or $z.Stdout.Replace("`r`n","`n") -cne $wanted){throw ('POSITIVE_RUNTIME_FAILED '+$id)}
  }elseif($a.ExitCode -eq 0 -or -not $a.Stderr.Contains('parallel callback SourceText is supported only as a direct top-level tryParallel Result payload')){throw ('NEGATIVE_ADMISSION_FAILED '+$id)}
  $row.passed=$true;$r.completed++;Save
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{Save}
$r|Select-Object status,completed,total,compilerDllSha256|ConvertTo-Json -Compress
