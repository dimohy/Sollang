[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Contract,
    [Parameter(Mandatory)][ValidateSet('managed','selfhost')][string]$CompilerSide,
    [switch]$RequirePaired
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
$contractPath=[IO.Path]::GetFullPath($Contract,$repositoryRoot)
$definition=Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$compilerPath=[IO.Path]::GetFullPath($definition.compilerBinaries.$CompilerSide.path,$repositoryRoot)
$runnerPath=Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1'
$context=Get-NativeExactPhaseContext $repositoryRoot $contractPath $CompilerSide $compilerPath $runnerPath
$evidence=[IO.Path]::GetFullPath($definition.evidenceDirectory,$repositoryRoot)
$recordPath=Join-Path $evidence "$CompilerSide-phase-execution.json"
$python=(Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$reader=Join-Path $PSScriptRoot 'verify-native-exact-phase-record.py'
$readerArguments=@($reader,'--record',$recordPath)
if($RequirePaired){
    if($CompilerSide -cne 'selfhost'){throw 'READONLY_PHASE_PAIRED_SIDE'}
    $readerArguments+=@('--paired-record',(Join-Path $evidence 'paired-phase-execution.json'))
}
$context | ConvertTo-Json -Depth 50 -EscapeHandling EscapeNonAscii | & $python @readerArguments
if($LASTEXITCODE -ne 0){throw 'READONLY_PHASE_VERIFICATION_FAILED'}
