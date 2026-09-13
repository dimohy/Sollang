[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $PSScriptRoot 'contracts/process-child-try-wait.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -cne 'sys.process.Child.tryWait') {
    throw 'unsupported process Child.tryWait contract'
}
if ($contract.runtimeStates.running -ne 0 -or $contract.runtimeStates.exited -ne 1 -or $contract.runtimeStates.osFailure -ne 2 -or $contract.runtimeStates.terminalSignal -ne 3) {
    throw 'process Child.tryWait runtime state values drifted'
}

function Assert-Contains([string]$RelativePath, [string]$Expected, [string]$Label) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing $Label authority: $RelativePath" }
    $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $normalizedExpected = $Expected.Replace("`r`n", "`n")
    if (-not $source.Contains($normalizedExpected)) { throw "$Label drifted in $RelativePath" }
}

function Assert-NotContains([string]$RelativePath, [string]$Forbidden, [string]$Label) {
    $path = Join-Path $root $RelativePath
    $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $normalizedForbidden = $Forbidden.Replace("`r`n", "`n")
    if ($source.Contains($normalizedForbidden)) { throw "$Label drifted in $RelativePath" }
}

Assert-Contains 'stdlib/sys/process.slg' 'completionState: Int' 'Child cached completion discriminator'
Assert-Contains 'stdlib/sys/process.slg' 'exitCode: Int' 'Child cached exit code'
Assert-Contains 'stdlib/sys/process.slg' 'public struct SignalStatus {' 'typed signal status'
Assert-Contains 'stdlib/sys/process.slg' 'public enum TerminationStatus {' 'typed terminal status'
Assert-NotContains 'stdlib/sys/process.slg' 'public token: UInt64' 'opaque Child token'
Assert-NotContains 'stdlib/sys/process.slg' 'public processId: ProcessId' 'opaque Child process identifier storage'
Assert-NotContains 'stdlib/sys/process.slg' 'public completionState: Int' 'opaque Child completion cache'
Assert-NotContains 'stdlib/sys/process.slg' 'public exitCode: Int' 'opaque Child exit cache'
Assert-Contains 'stdlib/sys/runtime/process.slg' $contract.api 'public tryWait signature'
Assert-Contains 'stdlib/sys/runtime/process.slg' $contract.typedApi 'public typed tryWait signature'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'self -> tryWaitTermination -> when {' 'legacy projection delegates to typed authority'
Assert-Contains 'stdlib/sys/runtime/process.slg' '0 => self.token' 'completed owner token clear'
Assert-Contains 'stdlib/sys/runtime/process.slg' '1 => self.completionState' 'completed owner cache commit'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'polled.state -> when {' 'exclusive poll-state dispatch'
Assert-Contains 'stdlib/sys/runtime/process.slg' '== 3 {' 'terminal signal cache path'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'polled.exitCode => self.exitCode' 'terminal detail cache'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'else { Result<Option<TerminationStatus>, Text>.Err("wait") }' 'unknown poll state fail closed'
Assert-Contains 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs' '"sys.process.pollChild" => RequireProcessPollChildIntrinsicSignature(' 'managed poll intrinsic binding'
Assert-Contains 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Process.cs' 'EmitRuntimePollChildProcessIntrinsic' 'managed poll lowering'
Assert-Contains 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Process.cs' 'process_wait_cached_result' 'managed cached wait lowering'
Assert-Contains 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs' '%running = icmp eq i32 %waited, 258' 'Windows timeout classification'
Assert-Contains 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs' 'br i1 %exited, label %read_exit, label %classify_pending' 'Windows exit-before-code classification'
Assert-Contains 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs' '@waitpid(i32 %pid, ptr %status_slot, i32 1)' 'Linux WNOHANG poll'
Assert-Contains 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs' '%interrupted = icmp eq i32 %errno, 4' 'Linux EINTR retry'
Assert-Contains 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs' '%signal0 = insertvalue %sollang.process_poll_result poison, i32 %term_bits, 0' 'managed Linux exact signal result'
Assert-Contains 'selfhost/ir/typed.slg' 'opcode == -308' 'selfhost process poll opcode'
Assert-Contains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' 'resolvedProcessRuntimeOpcode call: ref TypedIrNode, prepared: ref semanticContext.SemanticSnapshot -> Int {' 'selfhost exact process-runtime resolver'
Assert-Contains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' "targetSource -> sourceMatches(targetName.span.start, targetName.span.length, `"pollChild`")`n                                    -> if { -308 => opcode! }" 'selfhost poll binding'
Assert-Contains 'selfhost/llvm/text/platform_io.slg' '@sollang_poll_process' 'selfhost poll lowering'
Assert-Contains 'selfhost/llvm/emitter/process_runtime.slg' '%signal0 = insertvalue %sollang.process_poll_result poison, i32 %signal_bits, 0' 'selfhost Linux exact signal result'

foreach ($fixture in $contract.fixtures) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $fixture) -PathType Leaf)) { throw "missing tryWait fixture: $fixture" }
}
Write-Host "[process Child.tryWait contract] PASS 37/37 source and fixture authorities"
