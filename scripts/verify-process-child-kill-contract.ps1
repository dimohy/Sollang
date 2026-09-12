[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $PSScriptRoot 'contracts/process-child-kill.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -cne 'sys.process.Child.kill') {
    throw 'unsupported process Child.kill contract'
}

function Read-Source([string]$RelativePath) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing authority: $RelativePath" }
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}

function Assert-Contains([string]$RelativePath, [string]$Expected, [string]$Label) {
    if (-not (Read-Source $RelativePath).Contains($Expected.Replace("`r`n", "`n"))) {
        throw "$Label drifted in $RelativePath"
    }
}

function Assert-NotContains([string]$RelativePath, [string]$Forbidden, [string]$Label) {
    if ((Read-Source $RelativePath).Contains($Forbidden.Replace("`r`n", "`n"))) {
        throw "$Label drifted in $RelativePath"
    }
}

function Select-KillFunctions([string]$RelativePath) {
    $source = Read-Source $RelativePath
    return @([regex]::Matches($source, '(?ms)^\s*define internal i1 @sollang_kill_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}'))
}

Assert-Contains 'stdlib/sys/runtime/process.slg' $contract.api 'public kill signature'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'killChild token: UInt64 -> Bool uses Process = intrinsic' 'private kill boundary'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'self.completionState -> when {' 'cached-state dispatch'
Assert-Contains 'stdlib/sys/runtime/process.slg' 'else { Result<Unit, Text>.Ok }' 'cached terminal idempotence'
Assert-Contains 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs' '"sys.process.killChild" => RequireProcessKillChildIntrinsicSignature(' 'managed intrinsic binding'
Assert-Contains 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Process.cs' 'EmitRuntimeKillChildProcessIntrinsic' 'managed intrinsic lowering'
Assert-Contains 'selfhost/ir/typed.slg' 'opcode == -309' 'selfhost kill opcode'
Assert-Contains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' 'call.targetModule >= 0' 'selfhost exact target-fragment guard'
Assert-Contains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' 'targetSource -> sourceMatches(targetIdentity.pathStart, targetIdentity.pathLength, "sys.process")' 'selfhost process namespace identity'
Assert-Contains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' 'targetSource -> sourceMatches(targetName.span.start, targetName.span.length, "killChild")' 'selfhost kill declaration identity'
Assert-Contains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' '-309 => opcode!' 'selfhost kill binding'
Assert-NotContains 'selfhost/ir/typed/resolved_context_normalize_phases.slg' 'processCall!.symbol == processKillChildSymbol!' 'selfhost representative-source symbol cache removal'
Assert-Contains 'selfhost/ir/typed.slg' 'finalizeResolvedContext(prepared, recursiveTypes, frozenRecursiveSemanticTypes, recursiveTypeFlags, runtimeSymbols, finalWrappedValueByNode)' 'selfhost finalization boundary'
Assert-Contains 'selfhost/ir/typed.slg' 'results! -> normalizeResolvedProcessRuntime(prepared, recursiveTypes, inferred, frozenRecursiveSemanticTypes, frozenRecursiveTypeByAst, recursiveReferences!, recursiveTypeFlags)' 'selfhost post-finalize process sealing'
Assert-Contains 'selfhost/llvm/text/platform_io.slg' 'call i1 @sollang_kill_process' 'selfhost kill lowering'

$managedWindows = @(Select-KillFunctions 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs')
$managedLinux = @(Select-KillFunctions 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs')
$selfhost = @(Select-KillFunctions 'selfhost/llvm/emitter/process_runtime.slg')
if ($managedWindows.Count -ne 1 -or -not $managedWindows[0].Value.Contains('@TerminateProcess(')) {
    throw 'managed Windows kill authority drifted'
}
if ($managedLinux.Count -ne 1 -or -not $managedLinux[0].Value.Contains('@kill(i32 %pid, i32 9)')) {
    throw 'managed Linux kill authority drifted'
}
$selfhostWindows = @($selfhost | Where-Object { $_.Value.Contains('@TerminateProcess(') })
$selfhostLinux = @($selfhost | Where-Object { $_.Value.Contains('@kill(i32 %pid, i32 9)') })
if ($selfhost.Count -ne 2 -or $selfhostWindows.Count -ne 1 -or $selfhostLinux.Count -ne 1) {
    throw 'selfhost platform kill authorities drifted'
}
foreach ($function in @($managedWindows + $managedLinux + $selfhost)) {
    $waitsOnWindows = $function.Value.Contains('@WaitForSingleObject(')
    $waitsOnLinux = $function.Value.Contains('@waitpid(')
    $closesWindowsHandle = $function.Value.Contains('@CloseHandle(')
    if ($waitsOnWindows -or $waitsOnLinux -or $closesWindowsHandle) {
        throw 'kill must not wait, reap, or close the Child token'
    }
}

foreach ($fixture in $contract.fixtures) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $fixture) -PathType Leaf)) {
        throw "missing Child.kill fixture: $fixture"
    }
}
Write-Host '[process Child.kill contract] PASS 24/24 source and fixture authorities'
