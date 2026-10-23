param([switch]$ValidateInputsOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root='W:\MyWorks\Sollang'
Set-Location -LiteralPath $root
. "$root/scripts/verification-process.ps1"
. "$root/scripts/native-exact-fixture-receipt.ps1"
$base="$root/artifacts/scratch/resume-20261006-owner-continuation22"
$run="$base/parsing13028"
$contract="$run/execution-contract.json"
$d=Get-Content -LiteralPath $contract -Raw | ConvertFrom-Json
$managed=[IO.Path]::GetFullPath($d.compilerBinaries.managed.path,$root)
$native=[IO.Path]::GetFullPath($d.compilerBinaries.selfhost.path,$root)
$batch="$root/scripts/verify-native-exact-fixture-batch.ps1"
$negative="$root/scripts/verify-compiler-parity-negative-fixture.ps1"
$single="$root/scripts/verify-native-exact-fixture.ps1"
$llvm="$root/.tools/llvm-22.1.8"
$stdlib="$root/stdlib"
$ctx=Get-NativeExactPhaseContext $root $contract managed $managed $batch
# Validate retained actual outcomes against unchanged source, oracles, runners,
# runtime and products before reuse of the completed original whole405 batch.
foreach($p in Get-ChildItem -LiteralPath "$base/parsing13016/evidence" -Filter '*.json' -File) {
  $r=Get-Content -LiteralPath $p.FullName -Raw | ConvertFrom-Json
  if ('inputHashesStart' -cin @($r.PSObject.Properties.Name)) {
    $hashes=$r.inputHashesStart | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    Assert-NativeExactPhaseHashes $root $hashes
  }
}
$negatives=@($d.cases | Where-Object id -CLike 'negative-*')
foreach($c in $negatives) {
 $source=[IO.Path]::GetFullPath($c.fixture.path,$root)
 $expected=[IO.Path]::ChangeExtension($source,'.stderr.contains.txt')
 & $negative -ManagedCompiler $managed -SelfhostCompiler $native -ManagedCompilerSha256 $d.compilerBinaries.managed.sha256 -SelfhostCompilerSha256 $d.compilerBinaries.selfhost.sha256 -Source $source -Expected $expected -OutputDirectory "$run/negative/$($c.id)" -RepositoryRoot $root -LlvmRoot $llvm -StdlibRoot $stdlib -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -PhaseCompilerSide managed -ValidateInputsOnly | Out-Null
}
if($ValidateInputsOnly){Write-Output 'PASS current22 contract preflight; original whole405 hashes unchanged';exit 0}
foreach($c in $negatives) {
 $source=[IO.Path]::GetFullPath($c.fixture.path,$root)
 $expected=[IO.Path]::ChangeExtension($source,'.stderr.contains.txt')
 & $negative -ManagedCompiler $managed -SelfhostCompiler $native -ManagedCompilerSha256 $d.compilerBinaries.managed.sha256 -SelfhostCompilerSha256 $d.compilerBinaries.selfhost.sha256 -Source $source -Expected $expected -OutputDirectory "$run/negative/$($c.id)" -RepositoryRoot $root -LlvmRoot $llvm -StdlibRoot $stdlib -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -PhaseCompilerSide managed
}
foreach($c in $d.cases | Where-Object { 'grammarCommand' -cin @($_.PSObject.Properties.Name) }) {
 $null=Invoke-NativeExactPhaseGrammarCase $ctx $c
}
foreach($c in $d.cases | Where-Object { $_.id -cnotlike 'negative-*' -and 'grammarCommand' -cnotin @($_.PSObject.Properties.Name) }) {
 & $single -Compiler $managed -Label managed-current -Fixture $c.id -LlvmRoot $llvm -StdlibRoot $stdlib -RepositoryRoot $root -OutputDirectory "$run/managed-witness" -Jobs 2 -TimeoutMilliseconds 3600000 -PhaseExecutionContract $contract -CompilerSide managed
}
if(-not (Complete-NativeExactPhaseExecution $ctx)){throw 'CURRENT_PHASE_WITNESSES_INCOMPLETE'}
Write-Output 'PASS actual managed22 witnesses with original405 retained unchanged'
