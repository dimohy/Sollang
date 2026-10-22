$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. scripts/verification-process.ps1
. scripts/verification-compiler-build.ps1
$root=(Get-Location).Path
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$compiler=Join-Path $b 'v12515/compiler-build01/compiler.exe'
$buildPath=Join-Path $b 'v12515/compiler-build01/result.json'
$build=Get-Content -LiteralPath $buildPath -Raw|ConvertFrom-Json
$expected='A923B33CEB78B59C2C796D7D847BCF9F6CB26EB9B615CC458E18BA89EC172A98'
if($build.status -cne 'passed' -or -not $build.inputsStable -or $build.compilerSha256 -cne $expected -or (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -cne $expected){throw 'NATIVE_BUILD_NOT_QUALIFIED'}
$contractPath=Join-Path $b 'source12511-contract.json'
$c=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json
$negative=@($c.cases|Where-Object{$_.PSObject.Properties['admitted'] -and -not $_.admitted})
$positive=@($c.cases|Where-Object{-not $_.PSObject.Properties['admitted'] -or $_.admitted})
if($negative.Count -ne 6 -or $positive.Count -ne 23){throw 'COHORT_SCOPE_INVALID'}
$o=Join-Path $b 'native12518-qualification'
if(Test-Path -LiteralPath $o){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($o)
$inputs=@($PSCommandPath,$compiler,$buildPath,$contractPath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $root 'scripts/verification-compiler-build.ps1'))
$inputs+=@($c.cases|ForEach-Object{Join-Path $root $_.source})
$inputs+=@([IO.Directory]::GetFiles((Join-Path $root 'stdlib'),'*.slg',[IO.SearchOption]::AllDirectories))
$hashes=[ordered]@{};foreach($p in $inputs){$hashes[$p]=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
$r=[ordered]@{schemaVersion=1;status='running';scope='Fresh canonical native C687..C692 ownership21 plus SourceText8. Reject six unsupported carriers before building/running23 normal programs. Exact unchanged sources and expected outputs; no runtime allocator accounting or final acceptance.';compilerSha256=$expected;inputHashes=$hashes;completed=0;total=29;cases=@();builds=@();steps=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $o 'result.json'),($r|ConvertTo-Json -Depth 12)+"`n",[Text.UTF8Encoding]::new($false))}
function Stable{foreach($p in $hashes.Keys){if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $hashes[$p]){return $false}};return $true}
Save
try{
 foreach($case in ($negative+$positive)){
  if(-not(Stable)){throw 'INPUT_DRIFT'}
  $binary=Join-Path $o ($case.id+'.exe')
  $a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source (Join-Path $root $case.source) -Output $binary -Target windows-x64 -WorkingDirectory $root -Description ('Fresh native ownership '+$case.id) -TimeoutMilliseconds 120000
  $reject=$case.PSObject.Properties['admitted'] -and -not $case.admitted
  $expectedBuildExit=if($reject){1}else{0}
  $r.builds+=@{id=$case.id;buildRecord=($binary+'.compiler-build.json');buildExit=$a.ExitCode;expectedBuildExit=$expectedBuildExit};Save
  if($reject){
   $message='parallel callback SourceText is supported only as a direct top-level tryParallel Result payload'
   $text=$a.Stdout+$a.Stderr
   if($a.ExitCode -ne 1 -or ([regex]::Matches($text,[regex]::Escape($message))).Count -ne 1 -or (Test-Path -LiteralPath $binary)){throw ('NATIVE_NEGATIVE_FAILED '+$case.id+': '+$text)}
   $r.cases+=@{id=$case.id;status='passed';passed=$true;admissionRejected=$true;buildExit=$a.ExitCode;expectedBuildExit=1;stdout=$a.Stdout;stderr=$a.Stderr};$r.completed++;Save;continue
  }
  if($a.ExitCode -ne 0 -or $a.Stderr.Trim()){throw ('NATIVE_BUILD_FAILED '+$case.id+': '+$a.Stderr)}
  $record=Join-Path $o ($case.id+'.execution.json')
  $a=Invoke-VerificationProcessCapture -FilePath $binary -WorkingDirectory $root -Description ('Fresh native ownership '+$case.id) -TimeoutMilliseconds 30000 -ExecutionRecordPath $record
  $r.steps+=@{id=$case.id;executionRecord=$record}
  $ok=$a.ExitCode -eq $case.exit -and $a.Stdout.Replace("`r`n","`n") -ceq $case.stdout -and $a.Stderr.Replace("`r`n","`n") -ceq $case.stderr
  $r.cases+=@{id=$case.id;status=if($ok){'passed'}else{'failed'};passed=$ok;buildExit=0;expectedBuildExit=0;runExit=$a.ExitCode;expectedRuntimeExit=$case.exit;stdout=$a.Stdout;stderr=$a.Stderr};Save
  if(-not $ok){throw ('NATIVE_RUNTIME_ORACLE_FAILED '+$case.id)}
  $r.completed++;Save
 }
 $r.status='passed'
}catch{$r.status='failed';$r.failure=$_.Exception.Message;throw}finally{$r.inputsStable=Stable;$r.processesStopped=@($r.steps|Where-Object{(Get-Content -LiteralPath $_.executionRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0 -and @($r.builds|Where-Object{(Get-Content -LiteralPath $_.buildRecord -Raw|ConvertFrom-Json).processesStopped -ne $true}).Count -eq 0;Save}
[pscustomobject]$r|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
