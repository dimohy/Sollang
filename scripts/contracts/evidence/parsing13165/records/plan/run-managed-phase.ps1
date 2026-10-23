param([switch]$ValidateInputsOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root='W:\MyWorks\Sollang';Set-Location -LiteralPath $root
. "$root/scripts/native-exact-fixture-receipt.ps1"
$base="$root/artifacts/scratch/resume-20261006-owner-continuation22"
$run="$base/parsing13160"
$contract="$run/execution-contract.json"
$d=Get-Content -LiteralPath $contract -Raw | ConvertFrom-Json
$managed=[IO.Path]::GetFullPath($d.compilerBinaries.managed.path,$root)
$native=[IO.Path]::GetFullPath($d.compilerBinaries.selfhost.path,$root)
$batch="$root/scripts/verify-native-exact-fixture-batch.ps1"
$negative="$root/scripts/verify-compiler-parity-negative-fixture.ps1"
$llvm="$root/.tools/llvm-22.1.8";$stdlib="$root/stdlib"
$ctx=Get-NativeExactPhaseContext $root $contract managed $managed $batch
if($ValidateInputsOnly){
 & $batch -Compiler $managed -Label managed-current -LlvmRoot $llvm -StdlibRoot $stdlib -RepositoryRoot $root -OutputDirectory "$base/parsing13160/managed-whole" -Jobs 2 -MinimumCompilerJobs 1 -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -CompilerSide managed -ValidateInputsOnly
 exit 0
}
$focused=Get-Content -LiteralPath "$base/literal13153-native/result.json" -Raw | ConvertFrom-Json
if($focused.status -cne 'passed' -or $focused.completed -ne 17 -or $focused.total -ne 17 -or -not $focused.inputsStable -or -not $focused.processesStopped){throw 'CURRENT_NATIVE17_REQUIRED_BEFORE_WHOLE405'}
$original=Get-Content -LiteralPath "$base/literal13161-original487-native/controller.execution.json" -Raw | ConvertFrom-Json
if($original.status -cne 'passed' -or $original.exit -ne 0 -or -not $original.processesStopped){throw 'CURRENT_NATIVE_ORIGINAL487_REQUIRED_BEFORE_WHOLE405'}
foreach($c in $d.cases | Where-Object id -CLike 'negative-*') {
 $source=[IO.Path]::GetFullPath($c.fixture.path,$root)
 $expected=[IO.Path]::ChangeExtension($source,'.stderr.contains.txt')
 & $negative -ManagedCompiler $managed -SelfhostCompiler $native -ManagedCompilerSha256 $d.compilerBinaries.managed.sha256 -SelfhostCompilerSha256 $d.compilerBinaries.selfhost.sha256 -Source $source -Expected $expected -OutputDirectory "$run/negative-managed/$($c.id)" -RepositoryRoot $root -LlvmRoot $llvm -StdlibRoot $stdlib -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -PhaseCompilerSide managed
}
& $batch -Compiler $managed -Label managed-current -LlvmRoot $llvm -StdlibRoot $stdlib -RepositoryRoot $root -OutputDirectory "$base/parsing13160/managed-whole" -Jobs 2 -MinimumCompilerJobs 1 -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -CompilerSide managed -CancellationRequestPath "$run/cancel-managed-request.json" -CancellationRunId 'parsing13160-managed-20261023' -CancellationAcknowledgementPath "$run/cancel-managed-ack.json"
if(-not (Test-Path -LiteralPath "$run/evidence/managed-phase-execution.json")){throw 'MANAGED_PARSING_PHASE_RECORD_MISSING'}
