param([Parameter(Mandatory)][string]$OutputDirectory,[Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$EvaluationContract)
$ErrorActionPreference='Stop'
if(Test-Path $OutputDirectory){throw 'Evaluation output must be fresh'}
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
$lane=(Resolve-Path $OutputDirectory).Path
$repo=Join-Path $lane 'test-repository'
& git clone --shared --no-checkout --quiet $RepositoryRoot $repo
if($LASTEXITCODE -ne 0){throw 'Unable to create isolated evaluation repository'}
$pwsh=(Get-Command pwsh).Source
$node=(Get-Command node).Source
$evaluator=Join-Path (Split-Path $RepositoryRoot) 'AgenticShaping/evals/unstructured-to-structured.mjs'
$helper=Join-Path $RepositoryRoot 'scripts/verification-process.ps1'
$runner=Join-Path $PSScriptRoot 'invoke-scoped-shaping-trace.ps1'
. $helper
$consumer=Join-Path $repo 'consume.ps1'
@'
param([string]$InputFile,[switch]$Drift,[switch]$Fail,[switch]$HarnessFailure)
if($HarnessFailure){[Console]::Error.WriteLine('baseline wrapper failed');exit 1}
if($Drift){[IO.File]::WriteAllText($InputFile,'changed-during-command');exit 0}
if($Fail){Write-Output 'actual unexpected failure';exit 9}
$value=[IO.File]::ReadAllText($InputFile)
Write-Output ('observed='+$value)
if($value -cne 'fixed'){exit 1}
'@ | Set-Content $consumer -Encoding utf8
$measurement=Join-Path $repo 'measure.ps1'
@'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'consume.ps1') -InputFile (Join-Path $PSScriptRoot 'before.txt') | Out-Null
$before=[int]($LASTEXITCODE -ne 0)
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'consume.ps1') -InputFile (Join-Path $PSScriptRoot 'current.txt') | Out-Null
$after=[int]($LASTEXITCODE -ne 0)
@{metric='lateFailures';before=$before;after=$after}|ConvertTo-Json -Compress
exit 0
'@ | Set-Content $measurement -Encoding utf8
$results=@()
foreach($id in @('actual-success','unexpected-exit','input-drift-before','input-drift-during','forged-authority','baseline-wrapper-failure')){
    $case=Join-Path $lane $id
    [IO.Directory]::CreateDirectory($case)|Out-Null
    $baseline=Join-Path $repo 'before.txt'
    $asset=Join-Path $repo 'current.txt'
    [IO.File]::WriteAllText($baseline,'broken')
    [IO.File]::WriteAllText($asset,'fixed')
    $revision=(& git -C $repo rev-parse HEAD).Trim()
    $commands=@(foreach($purpose in @('baseline','validator','consumer','candidate')){
        $inputFile=if($purpose -eq 'baseline'){$baseline}else{$asset}
        $arguments=@('-NoProfile','-File',$consumer,'-InputFile',$inputFile)
        if($id -eq 'unexpected-exit' -and $purpose -eq 'validator'){$arguments+='-Fail'}
        if($id -eq 'input-drift-during' -and $purpose -eq 'validator'){$arguments+='-Drift'}
        if($id -eq 'baseline-wrapper-failure' -and $purpose -eq 'baseline'){$arguments+='-HarnessFailure'}
        $command=@{purpose=$purpose;filePath=$pwsh;arguments=$arguments;expectedExitCode=$(if($purpose -eq 'baseline'){1}else{0})}
        if($purpose -eq 'baseline'){$command.expectedStdout="observed=broken`n";$command.expectedStderr=''}
        $command
    })
    $plan=[ordered]@{schemaVersion=1;defectId='C2026-09-07-999';repository=$repo;revision=$revision
        scope=@{kind='defect-focused';description='Isolated runner fixture behavior; not a compiler repair';completionCriterion='all-declared-commands-match-expected-exit-with-frozen-inputs'}
        asset=@{kind='fixture';path='current.txt';beforePath=$baseline;reason='The actual consumer rejects broken fixture data and accepts corrected fixture data.'}
        inputs=@(@($baseline,$asset,$consumer,$measurement,$evaluator,$helper,$pwsh,$node,$runner)|ForEach-Object {@{path=$_;sha256=(Get-FileHash $_).Hash}})
        commands=$commands;evaluator=$evaluator;captureHelper=$helper
        measurementPlan=@{metric='lateFailures';command=('pwsh -NoProfile -File "'+$measurement+'"')}}
    if($id -eq 'forged-authority'){$plan.traceAuthority='orchestrator'}
    $planPath=Join-Path $case 'plan.json'
    $plan|ConvertTo-Json -Depth 10|Set-Content $planPath -Encoding utf8
    if($id -eq 'input-drift-before'){[IO.File]::WriteAllText($asset,'changed-before-command')}
    $output=Join-Path $case 'output'
    $run=Invoke-VerificationProcessCapture -FilePath $pwsh -ArgumentList @('-NoProfile','-File',$runner,'-PlanPath',$planPath,'-OutputDirectory',$output) -Description $id -WorkingDirectory $repo -TimeoutMilliseconds 20000
    [IO.File]::WriteAllText((Join-Path $case 'run.txt'),$run.Stdout+$run.Stderr)
    $traceExists=Test-Path (Join-Path $output 'trace.json')
    $pass=if($id -eq 'actual-success'){$run.ExitCode -eq 0 -and $traceExists}else{$run.ExitCode -ne 0 -and -not $traceExists}
    $actualHashes=$true
    if($traceExists){
        $trace=Get-Content (Join-Path $output 'trace.json') -Raw|ConvertFrom-Json
        $executed=Get-Content (Join-Path $output 'executed-commands.json') -Raw|ConvertFrom-Json
        foreach($record in $executed){if((Get-FileHash $record.outputPath).Hash -cne $record.outputSha256){$actualHashes=$false}}
        $scope=Get-Content (Join-Path $output 'scope-and-producer.json') -Raw|ConvertFrom-Json
        $pass=$pass -and $actualHashes -and $scope.overallGoalComplete -eq $false -and $scope.taskScope.kind -ceq 'defect-focused'
    }
    $results+=@{id=$id;exitCode=$run.ExitCode;tracePublished=$traceExists;outputHashesVerified=$actualHashes;passed=$pass;diagnostic=$run.Stderr}
}
$report=@{contractSha256=(Get-FileHash $EvaluationContract).Hash;runnerSha256=(Get-FileHash $runner).Hash;passed=@($results|Where-Object passed).Count;total=$results.Count;cases=$results}
$report|ConvertTo-Json -Depth 8|Set-Content (Join-Path $lane 'evaluation-results.json') -Encoding utf8
$results|Select-Object id,passed,exitCode,tracePublished|Format-Table
if($report.passed -ne $report.total){throw 'Behavior contract failed'}
