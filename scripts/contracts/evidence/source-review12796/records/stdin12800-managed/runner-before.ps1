param([Parameter(Mandatory)][string]$Compiler,[Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Get-Location).Path
. scripts/managed-reference-snapshot.ps1
. scripts/verification-compiler-build.ps1
. scripts/verification-process.ps1
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'OUTPUT_NOT_FRESH'}
[void][IO.Directory]::CreateDirectory($output)
$compilerPath=(Resolve-Path -LiteralPath $Compiler).Path
$cases=@(
 @{id='chunks';source='examples/regression/706-standard-input-chunks.slg';expected='examples/regression/expected/706-standard-input-chunks.stdout.txt'},
 @{id='whole';source='scripts/probes/standard-input-eof.slg';expected=$null}
)
$inputPath=Join-Path $root 'examples/regression/expected/706-standard-input-chunks.stdin.txt'
$required=@($compilerPath,$PSCommandPath,$inputPath,(Join-Path $root 'scripts/verification-process.ps1'),(Join-Path $root 'scripts/verification-compiler-build.ps1'))
$required+=@($cases|ForEach-Object{Join-Path $root $_.source})
$required+=@($cases|Where-Object{$_.expected}|ForEach-Object{Join-Path $root $_.expected})
$roots=@((Join-Path $root 'stdlib'),(Split-Path -Parent $compilerPath))
$before=Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command @($PSCommandPath,$compilerPath,$output)
$before|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $output 'inputs-before.json') -Encoding utf8
$result=[ordered]@{schemaVersion=1;status='running';completed=0;total=2;inputFingerprint=$before.fingerprint;cases=@();claimsGoalComplete=$false}
function Save{[IO.File]::WriteAllText((Join-Path $output 'result.json'),($result|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))}
Save
try{
 foreach($case in $cases){
  $exe=Join-Path $output ($case.id+'.exe')
  $build=Invoke-VerificationCompilerBuild -Compiler $compilerPath -Source (Join-Path $root $case.source) -Output $exe -Target windows-x64 -WorkingDirectory $root -Description ('stdin '+$case.id) -TimeoutMilliseconds 120000
  if($build.ExitCode -ne 0 -or $build.Stderr.Trim()){throw 'STDIN_CONTROL_BUILD_FAILED'}
  $run=Invoke-VerificationProcessCapture -FilePath $exe -StandardInputPath $inputPath -WorkingDirectory $root -Description ('stdin '+$case.id) -TimeoutMilliseconds 5000 -ExecutionRecordPath (Join-Path $output ($case.id+'.execution.json'))
  $expected=if($case.expected){[IO.File]::ReadAllText((Join-Path $root $case.expected))}else{[string]([IO.File]::ReadAllBytes($inputPath).Length)+"`n"}
  $row=@{id=$case.id;exitCode=$run.ExitCode;stdout=$run.Stdout;stderr=$run.Stderr;expected=$expected;passed=$false}
  $result.cases+=@($row);Save
  if($run.ExitCode -ne 0 -or $run.Stderr.Trim() -or $run.Stdout.Replace("`r`n","`n") -cne $expected.Replace("`r`n","`n")){throw 'STDIN_CONTROL_ORACLE_FAILED'}
  $row.passed=$true;$result.completed++;Save
 }
 $after=Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command @($PSCommandPath,$compilerPath,$output)
 Assert-InputFingerprintStable -ExpectedFingerprint $before.fingerprint -CurrentFingerprint $after.fingerprint -Phase 'stdin normal controls'
 $result.inputsStable=$true;$result.finalInputFingerprint=$after.fingerprint;$result.status='passed'
}catch{$result.status='failed';$result.failure=$_.Exception.Message;throw}finally{
 $records=@(Get-ChildItem -LiteralPath $output -Filter '*.execution.json'|ForEach-Object{Get-Content -LiteralPath $_.FullName -Raw|ConvertFrom-Json})
 $result.processesStopped=($records.Count -eq 2 -and @($records|Where-Object{-not $_.processesStopped}).Count -eq 0)
 Save
}
[pscustomobject]$result|Select-Object status,completed,total,inputsStable,processesStopped|ConvertTo-Json -Compress
