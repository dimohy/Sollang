[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Read-Authority([string]$Path) {
    return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $Path))
}

function Require([string]$Text, [string]$Needle, [string]$Description) {
    if (-not $Text.Contains($Needle)) {
        throw "$Description is missing: $Needle"
    }
}

$publicSocket = Read-Authority "stdlib/std/net/socket.slg"
$runtimeSocket = Read-Authority "stdlib/sys/runtime/socket.slg"
$semantic = Read-Authority "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
$managedEmitter = Read-Authority "src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs"
$functionCalls = Read-Authority "src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs"
$windowsRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs"
$linuxRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs"
$selfhostTyped = Read-Authority "selfhost/ir/typed.slg"
$selfhostNormalize = (Read-Authority "selfhost/ir/typed/resolved_context_normalize.slg") + "`n" + (Read-Authority "selfhost/ir/typed/resolved_context_normalize_phases.slg")
$selfhostFinalize = Read-Authority "selfhost/ir/typed/resolved_context_finalize.slg"
$selfhostEmitter = Read-Authority "selfhost/llvm/text/platform_io.slg"
$selfhostFunctionReturns = Read-Authority "selfhost/llvm/text/function_returns.slg"
$selfhostContainerControl = Read-Authority "selfhost/llvm/text/container_control.slg"
$selfhostRuntime = Read-Authority "selfhost/llvm/emitter/socket_runtime.slg"
$linker = Read-Authority "src/Sollang.Compiler/Tooling/WindowsLinker.cs"
$sendFixture = Read-Authority "examples/regression/1375-socket-vectored-send.slg"
$receiveFixture = Read-Authority "examples/regression/1377-socket-vectored-receive.slg"

Require $publicSocket "public struct SendBuffer {" "public borrowed send descriptor"
Require $publicSocket "bytes: ref [UInt8; ~]" "caller-owned payload borrow"
Require $runtimeSocket "public sendVectored: self, buffers: [SendBuffer] -> Result<UIntSize, SocketError>" "instance vectored send"
Require $publicSocket "public struct ReceiveBuffer {" "public owned receive descriptor"
Require $runtimeSocket "public receiveVectored: self, buffers: mut [ReceiveBuffer; ~] -> Result<UIntSize, SocketError>" "instance vectored receive"
Require $semantic "RequireSocketSendVectoredSignature" "typed managed intrinsic signature"
Require $semantic "RequireSocketReceiveVectoredSignature" "typed managed receive signature"
Require $managedEmitter "sollang_platform_socket_send_vectored" "managed direct vectored platform call"
Require $managedEmitter "sollang_platform_socket_receive_vectored" "managed direct scatter platform call"
Require $managedEmitter "InlineSizeOf(buffers.ElementType)" "managed descriptor stride"
Require $functionCalls "EmitFlowAdditionalValue" "flow slice normalization"
Require $windowsRuntime "declare dllimport i32 @WSASend" "Windows gather primitive"
Require $windowsRuntime "declare dllimport i32 @WSARecv" "Windows scatter primitive"
Require $windowsRuntime "%count_valid = icmp ule i64 %buffer_count, 64" "bounded Windows descriptor stack"
Require $linuxRuntime "declare i64 @sendmsg" "Linux gather primitive"
Require $linuxRuntime "call i64 @sendmsg" "Linux one-call gather lowering"
Require $linuxRuntime "declare i64 @recvmsg" "Linux scatter primitive"
Require $linuxRuntime "call i64 @recvmsg" "Linux one-call scatter lowering"
Require $selfhostNormalize 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "sendVectored")' "self-host early opcode classification"
Require $selfhostFinalize 'sourceMatches(finalSocketIntrinsicNameToken.span.start, finalSocketIntrinsicNameToken.span.length, "sendVectored")' "self-host final opcode classification"
Require $selfhostNormalize 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "receiveVectored")' "self-host early receive opcode classification"
Require $selfhostFinalize 'sourceMatches(finalSocketIntrinsicNameToken.span.start, finalSocketIntrinsicNameToken.span.length, "receiveVectored")' "self-host final receive opcode classification"
Require $selfhostEmitter "call.opcode == -299" "self-host vectored emission"
Require $selfhostEmitter "call.opcode == -301" "self-host scatter emission"
Require $selfhostEmitter "or call.opcode == -299" "self-host vectored handle extraction"
Require $selfhostTyped "ir[aggregateOwner!].kind != 6" "self-host move scan call boundary"
Require $selfhostFunctionReturns "dropBindingNeedsInlineArrayReload" "self-host final-return inline-array cleanup ABI"
Require $selfhostContainerControl "ownedDropNeedsInlineArrayReload" "self-host early-return inline-array cleanup ABI"
Require $sendFixture "first -> sendBuffer(1, 2)" "first borrowed fixture range"
Require $sendFixture "second -> sendBuffer(0, 3)" "second borrowed fixture range"
Require $receiveFixture "server -> receiveVectored(buffers!)? => received" "mutable scatter fixture call"
Require $receiveFixture "received == 5" "scatter fixture total count"
if ([regex]::Matches($selfhostRuntime, 'define internal %sollang\.socket_result @sollang_platform_socket_send_vectored').Count -ne 2) {
    throw "self-host Windows and Linux runtimes must each define send_vectored exactly once"
}
if ([regex]::Matches($selfhostRuntime, 'define internal %sollang\.socket_result @sollang_platform_socket_receive_vectored').Count -ne 2) {
    throw "self-host Windows and Linux runtimes must each define receive_vectored exactly once"
}
Require $linker "            WSASend" "Windows WSASend linker export"
Require $linker "            WSARecv" "Windows WSARecv linker export"

Write-Host "[socket vectored] PASS borrowed gather views, owned reusable scatter buffers, bounded Windows/Linux one-call lowering, and self-host parity."
