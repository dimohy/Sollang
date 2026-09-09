[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Read-Authority([string]$Path) {
    [IO.File]::ReadAllText((Join-Path $RepositoryRoot $Path))
}

function Require([string]$Text, [string]$Needle, [string]$Description) {
    if (-not $Text.Contains($Needle)) {
        throw "$Description is missing: $Needle"
    }
}

$runtimeSocket = Read-Authority "stdlib/sys/runtime/socket.slg"
$semantic = Read-Authority "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
$managedEmitter = Read-Authority "src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs"
$windowsRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs"
$linuxRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs"
$selfhostNormalize = (Read-Authority "selfhost/ir/typed/resolved_context_normalize.slg") + "`n" + (Read-Authority "selfhost/ir/typed/resolved_context_normalize_phases.slg")
$selfhostFinalize = Read-Authority "selfhost/ir/typed/resolved_context_finalize.slg"
$selfhostEmitter = Read-Authority "selfhost/llvm/text/platform_io.slg"
$selfhostRuntime = Read-Authority "selfhost/llvm/emitter/socket_runtime.slg"
$linker = Read-Authority "src/Sollang.Compiler/Tooling/WindowsLinker.cs"
$fixture = Read-Authority "examples/regression/1376-socket-try-clone.slg"

$cloneSignature = "public tryClone: self -> Result<"
if ([regex]::Matches($runtimeSocket, [regex]::Escape($cloneSignature)).Count -ne 3) {
    throw "TcpListener, TcpStream, and UdpSocket must each expose one non-consuming tryClone instance intrinsic"
}
Require $semantic '"std.net.socket.TcpListener.tryClone"' "listener clone intrinsic"
Require $semantic '"std.net.socket.TcpStream.tryClone"' "stream clone intrinsic"
Require $semantic '"std.net.socket.UdpSocket.tryClone"' "datagram clone intrinsic"
Require $semantic "RequireSocketTryCloneSignature" "typed clone signature validator"
Require $managedEmitter "sollang_platform_socket_try_clone" "managed direct clone lowering"
Require $windowsRuntime "@WSADuplicateSocketW" "Windows socket duplication primitive"
Require $windowsRuntime "@GetCurrentProcessId" "Windows same-process duplication target"
Require $linuxRuntime "call i32 @dup(i32 %descriptor)" "Linux descriptor duplication primitive"
Require $selfhostNormalize 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "tryClone")' "self-host early clone classification"
Require $selfhostFinalize 'sourceMatches(finalSocketIntrinsicNameToken.span.start, finalSocketIntrinsicNameToken.span.length, "tryClone")' "self-host final clone classification"
Require $selfhostEmitter "call.opcode == -300" "self-host clone emission"
Require $selfhostEmitter "@sollang_platform_socket_try_clone" "self-host direct clone call"
Require $selfhostRuntime "declare i32 @dup(i32)" "self-host Linux clone declaration closure"
if ([regex]::Matches($selfhostRuntime, 'define internal %sollang\.socket_result @sollang_platform_socket_try_clone').Count -ne 2) {
    throw "self-host Windows and Linux runtimes must each define socket try_clone exactly once"
}
Require $linker "            WSADuplicateSocketW" "Windows socket duplication linker export"
Require $linker "            GetCurrentProcessId" "Windows process-id linker export"
Require $fixture "listener -> close" "independent listener close proof"
Require $fixture "client -> close" "independent stream close proof"
Require $fixture "datagram -> close" "independent datagram close proof"

Write-Host "[socket tryClone] PASS explicit fallible instance ownership, direct Windows/Linux duplication, independent close fixture, and self-host parity."
