param([switch]$ValidateInputsOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root='W:\MyWorks\Sollang';Set-Location -LiteralPath $root
. "$root/scripts/native-exact-fixture-receipt.ps1"
$run="$root/artifacts/scratch/resume-20261006-owner-continuation22/parsing13085"
$contract="$run/execution-contract.json"
$d=Get-Content -LiteralPath $contract -Raw | ConvertFrom-Json
$managed=[IO.Path]::GetFullPath($d.compilerBinaries.managed.path,$root)
$native=[IO.Path]::GetFullPath($d.compilerBinaries.selfhost.path,$root)
$batch="$root/scripts/verify-native-exact-fixture-batch.ps1"
$negative="$root/scripts/verify-compiler-parity-negative-fixture.ps1"
$llvm="$root/.tools/llvm-22.1.8";$stdlib="$root/stdlib"
$ctx=Get-NativeExactPhaseContext $root $contract selfhost $native $batch
foreach($c in $d.cases | Where-Object id -CLike 'negative-*') {
 $source=[IO.Path]::GetFullPath($c.fixture.path,$root)
 $expected=[IO.Path]::ChangeExtension($source,'.stderr.contains.txt')
 & $negative -ManagedCompiler $managed -SelfhostCompiler $native -ManagedCompilerSha256 $d.compilerBinaries.managed.sha256 -SelfhostCompilerSha256 $d.compilerBinaries.selfhost.sha256 -Source $source -Expected $expected -OutputDirectory "$run/negative-native/$($c.id)" -RepositoryRoot $root -LlvmRoot $llvm -StdlibRoot $stdlib -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -PhaseCompilerSide selfhost -ValidateInputsOnly | Out-Null
}
& $batch -Compiler $native -Label native-current -LlvmRoot $llvm -StdlibRoot $stdlib -RepositoryRoot $root -OutputDirectory "$root/artifacts/scratch/resume-20261006-owner-continuation22/slice13084-original487-native" -Jobs 2 -MinimumCompilerJobs 1 -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -CompilerSide selfhost -ValidateInputsOnly
if($ValidateInputsOnly){Write-Output 'PASS native original405/22 admission after actual managed phase and current source comparison';exit 0}
# Capture negatives while the native whole batch is still absent, so the
# canonical batch runner remains the sole authority that closes the phase.
foreach($c in $d.cases | Where-Object id -CLike 'negative-*') {
 $source=[IO.Path]::GetFullPath($c.fixture.path,$root)
 $expected=[IO.Path]::ChangeExtension($source,'.stderr.contains.txt')
 & $negative -ManagedCompiler $managed -SelfhostCompiler $native -ManagedCompilerSha256 $d.compilerBinaries.managed.sha256 -SelfhostCompilerSha256 $d.compilerBinaries.selfhost.sha256 -Source $source -Expected $expected -OutputDirectory "$run/negative-native/$($c.id)" -RepositoryRoot $root -LlvmRoot $llvm -StdlibRoot $stdlib -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -PhaseCompilerSide selfhost
}
& $batch -Compiler $native -Label native-current -LlvmRoot $llvm -StdlibRoot $stdlib -RepositoryRoot $root -OutputDirectory "$root/artifacts/scratch/resume-20261006-owner-continuation22/slice13084-original487-native" -Jobs 2 -MinimumCompilerJobs 1 -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -CompilerSide selfhost -CancellationRequestPath "$run/cancel-selfhost-request.json" -CancellationRunId 'parsing13085-selfhost-20261023' -CancellationAcknowledgementPath "$run/cancel-selfhost-ack.json"
if(-not (Test-Path -LiteralPath "$run/evidence/paired-phase-execution.json")){throw 'NATIVE_PAIRED_PHASE_RECORD_MISSING'}
