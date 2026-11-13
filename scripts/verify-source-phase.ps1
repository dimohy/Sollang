[CmdletBinding(DefaultParameterSetName='Contract')]
param(
    [Parameter(Mandatory,ParameterSetName='Scope')][ValidateSet('semantic-analysis','type-commit','expression-lowering','control-flow','ownership','llvm-generation')][string]$Phase,
    [Parameter(Mandatory,ParameterSetName='Scope')][string]$BuildView,
    [Parameter(Mandatory,ParameterSetName='Contract')][string]$Contract,
    [Parameter(Mandatory)][ValidateSet('managed','selfhost')][string]$CompilerSide,
    [Parameter(ParameterSetName='Contract')][string]$CaseId,
    [Parameter(ParameterSetName='Contract')][switch]$VerifyOnly,
    [Parameter(ParameterSetName='Contract')][switch]$RequirePaired,
    [Parameter(ParameterSetName='Contract')][switch]$Complete,
    [ValidateRange(1,64)][int]$Jobs=1
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$clock=[Diagnostics.Stopwatch]::StartNew()
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$selectedStdlib=Join-Path $repositoryRoot 'stdlib'
$selectedStdlibSources=@(Get-ChildItem -LiteralPath $selectedStdlib -Recurse -File -Filter '*.slg' | ForEach-Object FullName)
$adapter=Join-Path $PSScriptRoot 'source_phase_context.py'
$python=(Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
if($PSCmdlet.ParameterSetName -ceq 'Scope') {
    # The pending canonical inventory is sufficient for input audit, never for
    # granting execution or completion credit.
    $detail=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contracts/structural-parity-detail.json') -Raw | ConvertFrom-Json
    $inventory=@($detail.phaseProgress | Where-Object phase -CEQ $Phase)[0].decisionInventory
    $inventory | ConvertTo-Json -Depth 60 -EscapeHandling EscapeNonAscii |
        & $python $adapter --root $repositoryRoot --phase $Phase --inventory - --build-view $BuildView --side $CompilerSide
    if($LASTEXITCODE -ne 0){throw 'SOURCE_PHASE_SCOPE_PREFLIGHT_FAILED'}
    return
}
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'native-exact-source-closure.ps1')
$script:LegacyPhaseContext=(Get-Command Get-NativeExactPhaseContext).ScriptBlock
$script:SourcePhaseRunner=$PSCommandPath
function Get-NativeExactPhaseContext {
    param($RepositoryRoot,$ContractPath,$CompilerSide,$CompilerPath,$RunnerPath,$WholeFixturePlan=@())
    $base=& $script:LegacyPhaseContext @PSBoundParameters
    $json=$base | ConvertTo-Json -Depth 60 -EscapeHandling EscapeNonAscii |
        & $python $adapter --root $RepositoryRoot --enrich --runner $script:SourcePhaseRunner
    if($LASTEXITCODE -ne 0){throw 'SOURCE_PHASE_CONTEXT_PREFLIGHT_FAILED'}
    $expanded=$json | ConvertFrom-Json -AsHashtable
    foreach($field in @('SourceHashes','SideSourceHashes','InputHashes','RunnerReference')){
        $base.$field=$expanded[$field]
    }
    return $base
}
$contractPath=[IO.Path]::GetFullPath($Contract,$repositoryRoot)
$definition=Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$compilerPath=[IO.Path]::GetFullPath($definition.compilerBinaries.$CompilerSide.path,$repositoryRoot)
$context=Get-NativeExactPhaseContext $repositoryRoot $contractPath $CompilerSide $compilerPath $PSCommandPath
if($VerifyOnly){
    if($CaseId -or $Complete){throw 'SOURCE_PHASE_READONLY_MODE_CONFLICT'}
    $evidence=[IO.Path]::GetFullPath($definition.evidenceDirectory,$repositoryRoot)
    $arguments=@((Join-Path $PSScriptRoot 'verify-native-exact-phase-record.py'),'--record',(Join-Path $evidence "$CompilerSide-phase-execution.json"))
    if($RequirePaired){
        if($CompilerSide -cne 'selfhost'){throw 'READONLY_PHASE_PAIRED_SIDE'}
        $arguments+=@('--paired-record',(Join-Path $evidence 'paired-phase-execution.json'))
    }
    $context | ConvertTo-Json -Depth 60 -EscapeHandling EscapeNonAscii | & $python @arguments
    if($LASTEXITCODE -ne 0){throw 'SOURCE_PHASE_READONLY_FAILED'}
    return
}
if($RequirePaired){throw 'SOURCE_PHASE_PAIRED_REQUIRES_READONLY'}
if(-not $CaseId){
    if($Complete){
        if(-not (Complete-NativeExactPhaseExecution $context)){throw 'SOURCE_PHASE_OUTCOMES_INCOMPLETE'}
        Write-Output 'SOURCE_PHASE_EXECUTION_RECORDED_PENDING_STRICT_CLOSURE'
    }
    else{
        foreach($plannedCase in $definition.cases){
            if('grammarCommand' -cin @($plannedCase.PSObject.Properties.Name)){continue}
            $plannedCompile=Get-NativeExactPhaseExpectedStage $plannedCase compile $CompilerSide
            if($plannedCompile.exitCode -eq 0){
                $plannedFixture=[IO.Path]::GetFileNameWithoutExtension($plannedCase.fixture.path)
                Assert-NativeExactCompilerSourceClosure -RepositoryRoot $repositoryRoot -Fixture $plannedFixture -SourcePath $selectedStdlibSources
                [void](Get-NativeExactLlvmContracts -ExpectedRoot (Join-Path $repositoryRoot 'examples/regression/expected') `
                    -Fixture $plannedFixture -CompilerIsManagedDll ($CompilerSide -ceq 'managed') `
                    -CompilerSide $CompilerSide -PhaseContractProvided $true)
            }
        }
        [void](Get-NativeExactPhaseCommandInputs $context)
        Write-Output 'SOURCE_PHASE_INPUTS_VALIDATED_NO_EXECUTION_CREDIT'
    }
    return
}
if($Complete){throw 'SOURCE_PHASE_CASE_AND_COMPLETE_MUST_BE_SEPARATE'}
$cases=@($definition.cases | Where-Object id -CEQ $CaseId)
if($cases.Count -ne 1){throw 'SOURCE_PHASE_CASE_ID_UNKNOWN'}
$case=$cases[0]
if('grammarCommand' -cin @($case.PSObject.Properties.Name)){
    Invoke-NativeExactPhaseGrammarCase $context $case
    return
}
function Get-RemainingMilliseconds {
    $remaining=180000-$clock.ElapsedMilliseconds
    if($remaining -le 0){throw 'SOURCE_PHASE_CASE_BUDGET_EXHAUSTED'}
    [int]$remaining
}
$prefix=Get-NativeExactPhaseOutcomePrefix $context $case
$output="$prefix.products"
if(Test-Path -LiteralPath $output){throw 'SOURCE_PHASE_EXISTING_PRODUCTS_PROTECTED'}
foreach($stage in @('compile','run')){
    if(Test-Path -LiteralPath "$prefix.$stage.json"){throw 'SOURCE_PHASE_EXISTING_OUTCOME_PROTECTED'}
}
$source=Get-NativeExactPhaseFile $repositoryRoot $case.fixture.path
$fixture=[IO.Path]::GetFileNameWithoutExtension($source)
$expectedRoot=Join-Path $repositoryRoot 'examples/regression/expected'
$manifest=Join-Path $expectedRoot "$fixture.sources.txt"
$sources=@($source)
if(Test-Path -LiteralPath $manifest){
    $sources=@([IO.File]::ReadAllLines($manifest) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Get-NativeExactPhaseFile $repositoryRoot $_.Trim() })
    if($source -cnotin $sources){throw 'SOURCE_PHASE_MANIFEST_MISSING_ROOT'}
}
$expected=Get-NativeExactPhaseExpectedStage $case compile $CompilerSide
$positive=$expected.exitCode -eq 0
$contracts=$null
$diagnostics=''
$runArguments=@()
if($positive){
    $closureSources=@(($sources+$selectedStdlibSources) | Select-Object -Unique)
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $repositoryRoot -Fixture $fixture -SourcePath $closureSources
    $contracts=Get-NativeExactLlvmContracts -ExpectedRoot $expectedRoot -Fixture $fixture `
        -CompilerIsManagedDll ($CompilerSide -ceq 'managed') -CompilerSide $CompilerSide -PhaseContractProvided $true
    $diagnosticPath=Join-Path $expectedRoot "$fixture.compiler.stderr.exact.txt"
    if(Test-Path -LiteralPath $diagnosticPath){
        if(Test-Path -LiteralPath (Join-Path $expectedRoot "$fixture.compiler.stderr.contains.txt")){throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_AMBIGUOUS'}
        $diagnostics=$diagnosticPath
        Assert-NativeExactCompilerDiagnostics -Stdout '' -Stderr ([IO.File]::ReadAllText($diagnostics)) -ExpectedExactPath $diagnostics
    }
    $argsPath=Join-Path $expectedRoot "$fixture.args.txt"
    if(Test-Path -LiteralPath $argsPath){$runArguments=[IO.File]::ReadAllLines($argsPath)}
}
$llvm=Join-Path $repositoryRoot '.tools/llvm-22.1.8'
$assembler=Join-Path $llvm 'bin/llvm-as.exe'
$clang=Join-Path $llvm 'bin/clang.exe'
$stdlib=Join-Path $repositoryRoot 'stdlib'
$pins=@($sources)+@($assembler,$clang,$PSCommandPath,(Join-Path $PSScriptRoot 'native-exact-source-closure.ps1'),
    (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'))+
    @(Get-ChildItem -LiteralPath $stdlib -Recurse -File -Filter '*.slg' | ForEach-Object FullName)
if(Test-Path -LiteralPath $manifest){$pins+=@($manifest)}
if($positive){$pins+=@($contracts.InputPaths); if($diagnostics){$pins+=@($diagnostics)}; if(Test-Path -LiteralPath $argsPath){$pins+=@($argsPath)}}
$start=Get-NativeExactPhaseCommandInputs $context $pins
[void][IO.Directory]::CreateDirectory($output)
$binary=Join-Path $output 'program.exe'
$command=$compilerPath; $arguments=@()
if($CompilerSide -ceq 'managed'){
    $command=(Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $arguments=@($compilerPath)
}
$arguments+=@('build')+$sources+@('-o',$binary,'--target','windows-x64','--llvm',$llvm)
if($CompilerSide -ceq 'selfhost'){$arguments+=@('--stdlib',$selectedStdlib)}
$arguments+=@('--jobs',([string]$Jobs),'-O1','--keep-temps')
$buildRecord="$prefix.compile.execution.json"
$build=Invoke-VerificationProcessCapture -FilePath $command -ArgumentList $arguments -WorkingDirectory $repositoryRoot `
    -Description "$CompilerSide $CaseId compile" -TimeoutMilliseconds (Get-RemainingMilliseconds) -ExecutionRecordPath $buildRecord
if($positive){
    if($build.ExitCode -ne 0){throw 'SOURCE_PHASE_POSITIVE_BUILD_FAILED'}
    Assert-NativeExactCompilerDiagnostics -Stdout $build.Stdout -Stderr $build.Stderr -ExpectedExactPath $diagnostics
    Assert-NativeExactLlvmContracts -LlvmPath "$binary.ll" -Contracts $contracts
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath "$binary.ll"
    if(-not $?){throw 'SOURCE_PHASE_LLVM_CLOSURE_FAILED'}
    $assembly=Invoke-VerificationProcessCapture -FilePath $assembler -ArgumentList @("$binary.ll",'-o',"$binary.bc") `
        -WorkingDirectory $repositoryRoot -Description "$CompilerSide $CaseId LLVM assembly" `
        -TimeoutMilliseconds (Get-RemainingMilliseconds) -ExecutionRecordPath "$prefix.assemble.execution.json"
    if($assembly.ExitCode -ne 0){throw 'SOURCE_PHASE_LLVM_ASSEMBLY_FAILED'}
} elseif(@(Get-ChildItem -LiteralPath $output -Recurse -Force).Count -ne 0){throw 'SOURCE_PHASE_NEGATIVE_EMITTED_PRODUCTS'}
[void](Write-NativeExactPhaseOutcome -Context $context -Case $case -Stage compile -ProcessRecordPath $buildRecord `
    -OutputPath $prefix -BinaryPath $binary -InputHashesStart $start)
if($positive){
    $runStart=Get-NativeExactPhaseCommandInputs $context (@($start.Keys)+@($binary))
    $runRecord="$prefix.run.execution.json"
    [void](Invoke-VerificationProcessCapture -FilePath $binary -ArgumentList $runArguments -WorkingDirectory $repositoryRoot `
        -Description "$CompilerSide $CaseId run" -TimeoutMilliseconds (Get-RemainingMilliseconds) -ExecutionRecordPath $runRecord)
    [void](Write-NativeExactPhaseOutcome -Context $context -Case $case -Stage run -ProcessRecordPath $runRecord `
        -OutputPath $prefix -BinaryPath $binary -InputHashesStart $runStart)
}
[void](Get-RemainingMilliseconds)
[void](Get-NativeExactPhaseCommandInputs $context $pins)
Write-Output "SOURCE_PHASE_CASE_CAPTURED $CompilerSide $CaseId; phase closure remains a separate operation"
