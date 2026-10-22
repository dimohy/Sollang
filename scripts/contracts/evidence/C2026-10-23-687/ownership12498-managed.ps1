$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. scripts/verification-process.ps1
. scripts/verification-compiler-build.ps1
$root=(Get-Location).Path
$b=Join-Path $root 'artifacts/scratch/resume-20261006-owner-continuation22'
$out=Join-Path $b 'ownership12498-managed'
if(Test-Path -LiteralPath $out){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($out)
$source=Join-Path $root 'scripts/probes/ownership-review/callback-try-local.slg'
$compiler=Join-Path $b 'managed12488/compiler/Sollang.Compiler.exe'
$exe=Join-Path $out 'probe.exe'
$a=Invoke-VerificationCompilerBuild -Compiler $compiler -Source $source -Output $exe -Target windows-x64 -WorkingDirectory $root -Description 'Named tryParallel result ownership review' -TimeoutMilliseconds 120000
$r=[ordered]@{schemaVersion=1;status='observed';scope='One normal program for directly read tryParallel callback terminal named result cleanup question; no repeated execution';source=$source;sourceSha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;compilerDllSha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($compiler,'dll')) -Algorithm SHA256).Hash;buildExit=$a.ExitCode;buildStdout=$a.Stdout;buildStderr=$a.Stderr;claimsGoalComplete=$false}
if($a.ExitCode -eq 0 -and -not $a.Stderr.Trim()){
 $a=Invoke-VerificationProcessCapture -FilePath $exe -WorkingDirectory $root -Description 'Named tryParallel normal program' -TimeoutMilliseconds 30000 -ExecutionRecordPath (Join-Path $out 'run.execution.json')
 $r.runExit=$a.ExitCode;$r.stdout=$a.Stdout;$r.stderr=$a.Stderr
}
[IO.File]::WriteAllText((Join-Path $out 'result.json'),($r|ConvertTo-Json -Depth 8)+"`n",[Text.UTF8Encoding]::new($false))
[pscustomobject]$r|Select-Object buildExit,runExit,stdout,stderr|ConvertTo-Json -Compress
