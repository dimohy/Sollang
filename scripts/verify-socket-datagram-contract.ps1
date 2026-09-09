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
$managedEmitter = Read-Authority "src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs"
$windowsRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs"
$linuxRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs"
$selfhostRuntime = Read-Authority "selfhost/llvm/emitter/socket_runtime.slg"
$selfhostEmitter = Read-Authority "selfhost/llvm/text/platform_io.slg"
$linker = Read-Authority "src/Sollang.Compiler/Tooling/WindowsLinker.cs"

Require $publicSocket "public struct Datagram {" "allocating datagram value"
Require $publicSocket "public struct DatagramReceipt {" "caller-buffer datagram receipt"
if ([regex]::Matches($publicSocket, '(?m)^    public truncated: Bool$').Count -ne 2) {
    throw "Datagram and DatagramReceipt must each expose one Bool truncation field"
}
Require $managedEmitter 'Datagram.truncated must be Bool' "managed allocated datagram truncation invariant"
Require $managedEmitter 'DatagramReceipt.truncated must be Bool' "managed receipt truncation invariant"
Require $managedEmitter 'ptr {truncatedAddress}' "managed platform truncation output"
Require $windowsRuntime 'declare dllimport i32 @WSARecvFrom' "Windows counted datagram receive"
Require $windowsRuntime '%message_too_large = icmp eq i32 %error, 10040' "Windows WSAEMSGSIZE partial-success classification"
Require $windowsRuntime 'store i8 1, ptr %truncated' "Windows explicit truncation output"
Require $linuxRuntime '%receive_flags = or i32 %flags, 32' "Linux MSG_TRUNC receive"
Require $linuxRuntime '%was_truncated = icmp ugt i64 %actual_count, %capacity' "Linux truncation comparison"
Require $linuxRuntime '%count = select i1 %was_truncated, i64 %capacity, i64 %actual_count' "Linux caller-buffer count clamp"
Require $selfhostRuntime 'declare dllimport i32 @WSARecvFrom' "self-host Windows counted datagram receive"
if ([regex]::Matches($selfhostRuntime, 'ptr %endpoint, ptr %truncated\) #0').Count -ne 2) {
    throw "self-host Windows and Linux receive_from ABI must expose truncation output"
}
Require $selfhostEmitter '_socket_datagram_truncated_address' "self-host truncation output storage"
Require $selfhostEmitter '_socket_datagram_receipt1, i1 %v$(request.callIndex)_socket_datagram_truncated, 2' "self-host receipt truncation field"
Require $linker "            WSARecvFrom" "Windows WSARecvFrom linker export"

Write-Host "[socket datagram] PASS explicit truncation on allocated and caller-buffer instance receives, Windows/Linux direct lowering, self-host parity, and linker export."
