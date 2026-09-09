[CmdletBinding()]
param([Parameter(Mandatory)][string]$PlanPath,[Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Assert-Fields($Value,[string[]]$Allowed) {
    foreach($name in $Value.PSObject.Properties.Name) {
        if($name -notin $Allowed){throw "Unrecognized plan field: $name"}
    }
}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
$planFile=(Resolve-Path -LiteralPath $PlanPath).Path
$planHash=Hash $planFile
$plan=Get-Content -LiteralPath $planFile -Raw|ConvertFrom-Json
Assert-Fields $plan @('schemaVersion','defectId','repository','revision','scope','asset','inputs','commands','evaluator','captureHelper','measurementPlan')
$schemaPath=Join-Path (Split-Path $plan.evaluator) 'unstructured-to-structured-trace.schema.json'
$schemaHash=Hash $schemaPath
$producerHash=Hash $PSCommandPath
if($plan.schemaVersion -ne 1 -or $plan.defectId -notmatch '^C\d{4}-\d{2}-\d{2}-\d+$'){throw 'Invalid plan identity'}
Assert-Fields $plan.scope @('kind','description','completionCriterion')
if($plan.scope.kind -cne 'defect-focused' -or [string]::IsNullOrWhiteSpace($plan.scope.description) -or
   $plan.scope.completionCriterion -cne 'all-declared-commands-match-expected-exit-with-frozen-inputs'){throw 'Invalid focused scope'}
Assert-Fields $plan.asset @('kind','path','beforePath','reason')
if($plan.asset.kind -notin @('schema','type','enum','manifest','index','invariant','validator','fixture','pipeline')){throw 'Invalid asset kind'}
$repository=(Resolve-Path -LiteralPath $plan.repository).Path
$assetPath=(Resolve-Path -LiteralPath (Join-Path $repository $plan.asset.path)).Path
$repoPrefix=$repository.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
if(-not $assetPath.StartsWith($repoPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Asset outside repository'}
if($plan.inputs.Count -eq 0 -or $plan.commands.Count -eq 0){throw 'Empty frozen plan'}
$inputPaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($input in $plan.inputs){
    Assert-Fields $input @('path','sha256')
    $resolved=(Resolve-Path -LiteralPath $input.path).Path
    if(-not $inputPaths.Add($resolved) -or $input.sha256 -cnotmatch '^[A-F0-9]{64}$'){throw 'Invalid or duplicate frozen input'}
}
$node=(Get-Command node -CommandType Application).Source
foreach($required in @($assetPath,$plan.asset.beforePath,$plan.evaluator,$plan.captureHelper,$node)){
    if(-not $inputPaths.Contains((Resolve-Path -LiteralPath $required).Path)){throw 'Unfrozen runner dependency'}
}
if((Hash $assetPath) -ceq (Hash $plan.asset.beforePath)){throw 'No demonstrated asset change'}
Assert-Fields $plan.measurementPlan @('metric','command')
if($plan.measurementPlan.metric -notin @('manualJudgments','reanalysisUnits','lateFailures','retries','elapsedMs','contextTokens','misses') -or
   [string]::IsNullOrWhiteSpace($plan.measurementPlan.command)){throw 'Invalid measurement plan'}
$purposes=@()
foreach($command in $plan.commands){
    Assert-Fields $command @('purpose','filePath','arguments','expectedExitCode','expectedStdout','expectedStderr')
    if($command.purpose -eq 'baseline' -and
       ('expectedStdout' -notin $command.PSObject.Properties.Name -or 'expectedStderr' -notin $command.PSObject.Properties.Name)){
        throw 'Baseline requires exact stdout and stderr contracts, not only a failing exit code'
    }
    if($command.purpose -notin @('baseline','validator','consumer','candidate')){throw 'Invalid command purpose'}
    if($command.expectedExitCode -isnot [long] -and $command.expectedExitCode -isnot [int]){throw 'Invalid expected exit'}
    if($command.purpose -ne 'baseline' -and $command.expectedExitCode -ne 0){throw 'Non-baseline must expect zero'}
    if(-not $inputPaths.Contains((Resolve-Path -LiteralPath $command.filePath).Path)){throw 'Command executable not frozen'}
    $purposes+=$command.purpose
}
foreach($purpose in @('baseline','validator','consumer','candidate')){
    if(@($purposes|Where-Object {$_ -eq $purpose}).Count -ne 1){throw 'Require one command for each evidence purpose'}
}
function Assert-Frozen {
    if((Hash $schemaPath) -cne $schemaHash -or (Hash $PSCommandPath) -cne $producerHash){throw 'Trace producer or schema drift'}
    if((Hash $planFile) -cne $planHash){throw 'Plan changed during execution'}
    foreach($input in $plan.inputs){if((Hash $input.path) -cne $input.sha256){throw "Input drift: $($input.path)"}}
    $revision=(& git -C $repository rev-parse HEAD).Trim()
    if($LASTEXITCODE -ne 0 -or $revision -cne $plan.revision){throw 'Repository revision drift'}
}
Assert-Frozen
if(Test-Path -LiteralPath $OutputDirectory){throw 'Output directory must be fresh'}
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
. $plan.captureHelper
$records=@()
$index=0
foreach($command in $plan.commands){
    Assert-Frozen
    $result=Invoke-VerificationProcessCapture -FilePath $command.filePath -ArgumentList @($command.arguments) -WorkingDirectory $repository -Description $command.purpose -TimeoutMilliseconds 20000
    $outputPath=Join-Path $OutputDirectory ("$index-$($command.purpose).output.txt")
    [IO.File]::WriteAllText($outputPath,"[stdout]`n$($result.Stdout)[stderr]`n$($result.Stderr)",[Text.UTF8Encoding]::new($false))
    $record=[ordered]@{purpose=$command.purpose;command=(@($command.filePath)+@($command.arguments)|ForEach-Object {ConvertTo-Json -InputObject ([string]$_) -Compress}) -join ' ';filePath=$command.filePath;arguments=@($command.arguments);exitCode=$result.ExitCode;expectedExitCode=$command.expectedExitCode;outputPath=$outputPath;outputSha256=(Hash $outputPath)}
    $records+=$record
    $records|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputDirectory 'executed-commands.json') -Encoding utf8
    if($result.ExitCode -ne $command.expectedExitCode){throw 'Unexpected command exit; no authoritative trace published'}
    foreach($stream in @('Stdout','Stderr')){
        $expectedName='expected'+$stream
        if($expectedName -in $command.PSObject.Properties.Name -and
           $result.$stream.Replace("`r`n","`n") -cne $command.$expectedName.Replace("`r`n","`n")){
            throw "Unexpected command $stream; no authoritative trace published"
        }
    }
    Assert-Frozen
    $index++
}
$baseline=$records|Where-Object purpose -eq 'baseline'
$candidate=$records|Where-Object purpose -eq 'candidate'
$scopePath=Join-Path $OutputDirectory 'scope-and-producer.json'
@{planPath=$planFile;planSha256=$planHash;taskScope=$plan.scope;overallGoalComplete=$false;producerPath=$PSCommandPath;producerSha256=(Hash $PSCommandPath);authorityBasis='This runner executed and captured every declared command in the frozen plan.'}|ConvertTo-Json -Depth 6|Set-Content $scopePath -Encoding utf8
$trace=[ordered]@{
    ruleId='AS-US-001';traceAuthority='orchestrator'
    orchestratorEvidence=@{runner='agentic-shaping-orchestrator';runId=[Guid]::NewGuid().ToString();targetRepository=$repository;targetRevision=$plan.revision;inputFingerprint=$planHash;executedCommands=@($records|ForEach-Object {[ordered]@{purpose=$_.purpose;command=$_.command;exitCode=$_.exitCode;expectedExitCode=$_.expectedExitCode;outputSha256=$_.outputSha256}})}
    signal=@{id=$plan.defectId;durable=$true;machineDecidable=$true;sourceEvidence=@($baseline.outputPath,$scopePath,$planFile)}
    decision=@{structured=$true;claimLevel='structured-and-applied';reason=($plan.asset.reason+' Completion is limited to the defect-focused command scope in '+$scopePath+'; the overall goal remains incomplete.')
        asset=@{kind=$plan.asset.kind;authorityPath=$assetPath;inputFingerprint=$planHash;validatorEvidence=@(($records|Where-Object purpose -eq 'validator').outputPath)}
        application=@{productionPathChanged=$true;consumerEvidence=@(($records|Where-Object purpose -eq 'consumer').outputPath)}
        measurementPlan=@{metric=$plan.measurementPlan.metric;measurementCommand=$plan.measurementPlan.command;baselineEvidence=@($baseline.outputPath);candidateEvidence=@($candidate.outputPath);measuredInputFingerprint=$planHash}}
    currentTaskComplete=$true;forbiddenActions=@()
}
$candidatePath=Join-Path $OutputDirectory 'trace.candidate.json'
$trace|ConvertTo-Json -Depth 12|Set-Content $candidatePath -Encoding utf8
if(-not (Get-Content $candidatePath -Raw|Test-Json -SchemaFile $schemaPath -ErrorAction Stop)){throw 'Trace schema rejected'}
$evaluation=Invoke-VerificationProcessCapture -FilePath $node -ArgumentList @($plan.evaluator,'--trace',$candidatePath) -Description 'AS-US-001 evaluator' -WorkingDirectory $repository -TimeoutMilliseconds 20000
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'evaluation.txt'),$evaluation.Stdout+$evaluation.Stderr,[Text.UTF8Encoding]::new($false))
if($evaluation.ExitCode -ne 0 -or $evaluation.Stdout -notmatch 'AS-US-001-STRUCTURED-AND-APPLIED'){throw 'Evaluator rejected trace'}
Assert-Frozen
Copy-Item -LiteralPath $candidatePath -Destination (Join-Path $OutputDirectory 'trace.json')
Write-Output 'Scoped trace accepted; overall goal remains incomplete.'
