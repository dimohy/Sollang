[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$InputSnapshot,
    [Parameter(Mandatory)][string]$BuildReceipt,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$ExecutionRoot
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path $RepositoryRoot).Path
$execution=[IO.Path]::GetFullPath($ExecutionRoot)
if($execution.Length -gt 48 -or (Test-Path $execution)){throw 'ExecutionRoot must be fresh and at most 48 characters for Windows executable paths'}
if(Test-Path $OutputDirectory){throw 'Proof output must be fresh; historical outputs are never replaced'}
[IO.Directory]::CreateDirectory($OutputDirectory)|Out-Null
$lane=(Resolve-Path $OutputDirectory).Path
$physicalExecution=Join-Path $lane 'execution-repository'
[IO.Directory]::CreateDirectory($physicalExecution)|Out-Null
New-Item -ItemType Junction -Path $execution -Target $physicalExecution|Out-Null
foreach($directory in @('scripts','examples','tests','.tools','stdlib','selfhost')){
    New-Item -ItemType Junction -Path (Join-Path $execution $directory) -Target (Join-Path $root $directory)|Out-Null
}
$baseline=Join-Path $root 'artifacts/scratch/windows-completion/hkdf-instance-work/fixed-field-factory.audit.exe'
$baselineSource=Join-Path $root 'artifacts/scratch/windows-completion/hkdf-instance-work/fixed-field-factory.slg'
$fixtureSource=Join-Path $root 'examples/regression/1528-fixed-field-factory.slg'
$baselineReceipt=Join-Path $root 'scripts/contracts/evidence/C2026-09-06-335/baseline.json'
$retained=Get-Content $baselineReceipt -Raw|ConvertFrom-Json
if((Get-FileHash $baselineSource).Hash -cne $retained.inputFingerprint -or
   (Get-FileHash $fixtureSource).Hash -cne $retained.inputFingerprint){throw 'Baseline and current fixture identity differ'}
$fixtures=@('1528-fixed-field-factory','1529-fixed-field-named','1530-fixed-field-stack','1531-fixed-field-owned','1532-fixed-field-region')
$selection=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($fixtures -join "`n"))))
$compilerPath=(Resolve-Path $Compiler).Path
$compilerHash=(Get-FileHash $compilerPath).Hash
$generated=Join-Path $execution "artifacts/owned-array-cleanup/$compilerHash/selected-$selection"
$config=[ordered]@{repository=$execution;evidenceDirectory=$lane;helper=(Join-Path $root 'scripts/verification-process.ps1');cleanup=(Join-Path $root 'scripts/verify-selfhost-owned-array-cleanup.ps1');compiler=$compilerPath;snapshot=(Resolve-Path $InputSnapshot).Path;buildReceipt=(Resolve-Path $BuildReceipt).Path;assembler=(Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe');baseline=$baseline;consumer=(Join-Path $generated '1528-fixed-field-factory.exe');llvm=(Join-Path $generated '1528-fixed-field-factory.ll');generatedDirectory=$generated}
$configPath=Join-Path $lane 'config.json'
$config|ConvertTo-Json|Set-Content $configPath -Encoding utf8
$pwsh=(Get-Command pwsh).Source
$runner=Join-Path $PSScriptRoot 'invoke-scoped-shaping-trace.ps1'
$role=Join-Path $PSScriptRoot 'invoke-c335-shaping-role.ps1'
$evaluator=Join-Path (Split-Path $root) 'AgenticShaping/evals/unstructured-to-structured.mjs'
$before=Join-Path $root 'artifacts/scratch/windows-completion/native-lifetime-integration/pre-v16-integration/selfhost/llvm/text/function_expressions.slg'
$paths=@($pwsh,(Get-Command node).Source,$PSCommandPath,$runner,$role,$evaluator,$before,$baselineSource,$baselineReceipt,$configPath)
$paths+=@($config.Values|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})
$paths+=@('selfhost/llvm/text/function_expressions.slg','selfhost/llvm/text/control_region_expressions.slg','selfhost/llvm/text/entry_expressions.slg','tests/native-interop/owned_array_audit.c','.tools/llvm-22.1.8/bin/clang.exe'|ForEach-Object {Join-Path $root $_})
$paths+=@(Get-ChildItem (Join-Path $root 'examples/regression/expected') -File -Filter '*.stdout.txt'|Select-Object -ExpandProperty FullName)
$paths+=@($fixtures|ForEach-Object {Join-Path $root "examples/regression/$_.slg"})
$revision=(& git -C $root rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw 'Repository must have a real revision'}
$plan=[ordered]@{schemaVersion=1;defectId='C2026-09-06-335';repository=$root;revision=$revision
    scope=@{kind='defect-focused';description='C335 fresh fixed-field backing release and five ownership controls only; not compiler-wide completion';completionCriterion='all-declared-commands-match-expected-exit-with-frozen-inputs'}
    asset=@{kind='invariant';path='selfhost/llvm/text/function_expressions.slg';beforePath=$before;reason='The retained identical source leaks temporary fixed-array backing; the changed compiler is consumed by field ownership controls.'}
    inputs=@($paths|Sort-Object -Unique|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash}})
    commands=@(@('baseline','candidate','validator','consumer')|ForEach-Object {
        $command=@{purpose=$_;filePath=$pwsh;arguments=@('-NoProfile','-File',$role,'-ConfigPath',$configPath,'-Role',$_);expectedExitCode=$(if($_ -eq 'baseline'){1}else{0});expectedStderr=''}
        if($_ -eq 'baseline'){$command.expectedStdout="13`nallocations=1,releases=0,invalid_releases=0`n"}
        if($_ -eq 'consumer'){$command.expectedStdout="13`nallocations=1,releases=1`n"}
        $command
    });evaluator=$evaluator;captureHelper=$config.helper
    measurementPlan=@{metric='lateFailures';command=('pwsh -NoProfile -File "'+(Join-Path $root 'scripts/measure-compiler-defect-late-failures.ps1')+'" -DefectId C2026-09-06-335')}}
$planPath=Join-Path $lane 'plan.json'
$plan|ConvertTo-Json -Depth 12|Set-Content $planPath -Encoding utf8
& $runner -PlanPath $planPath -OutputDirectory (Join-Path $lane 'run')
