[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$socketModel = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "stdlib/std/net/socket.slg"))
$runtimeApi = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "stdlib/sys/runtime/socket.slg"))
$managedWindows = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs"))
$managedLinux = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs"))
$selfhost = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost/llvm/emitter/socket_runtime.slg"))
$selfhostTyped = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost/ir/typed.slg"))
$selfhostNormalize = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_normalize.slg")) + "`n" + [IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_normalize_phases.slg"))
$selfhostFinalize = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost/ir/typed/resolved_context_finalize.slg"))
$selfhostEmitter = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost/llvm/text/platform_io.slg"))
$windowsLinker = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "src/Sollang.Compiler/Tooling/WindowsLinker.cs"))

if ($socketModel -notmatch '(?s)Other\s+WriteZero\s+WouldBlock\s*}') {
    throw "WouldBlock must append after the existing SocketErrorKind ABI variants"
}
if (-not $managedWindows.Contains('i32 10035, label %would_block') -or
    -not $managedLinux.Contains('i32 11, label %would_block')) {
    throw "managed socket runtimes must map Windows 10035 and Linux 11"
}
if ([regex]::Matches($selfhost, 'i32 (10035|11), label %would_block').Count -ne 2) {
    throw "self-host socket runtimes must map both WouldBlock platform codes"
}
foreach ($runtime in @($managedWindows, $managedLinux, $selfhost)) {
    if (-not $runtime.Contains("would_block:`n          ret i32 10") -and
        -not $runtime.Contains("would_block:`r`n          ret i32 10")) {
        throw "WouldBlock must preserve the appended ABI tag 10"
    }
}

if ([regex]::Matches($runtimeApi, 'public setNonblocking: self, enabled: Bool -> Result<Unit, SocketError> uses Network = intrinsic').Count -ne 3) {
    throw "TcpListener, TcpStream, and UdpSocket must expose the same instance setNonblocking contract"
}
if ([regex]::Matches($managedWindows + $managedLinux, 'define internal %sollang\.socket_result @sollang_platform_socket_set_nonblocking').Count -ne 2 -or
    [regex]::Matches($selfhost, 'define internal %sollang\.socket_result @sollang_platform_socket_set_nonblocking').Count -ne 2) {
    throw "managed and self-host runtimes must define Windows and Linux setNonblocking lowerings"
}
foreach ($runtime in @($managedWindows, $managedLinux, $selfhost)) {
    if (-not $runtime.Contains('@sollang_socket_result(i64 -1, i32 %kind, i32 %error)') -or
        -not $runtime.Contains('@sollang_socket_result(i64 0, i32 -1, i32 0)')) {
        throw "setNonblocking must preserve the established Socket Result<Unit> ABI"
    }
}
if ([regex]::Matches($selfhostNormalize + $selfhostFinalize, '"setNonblocking"\)\s*\r?\n\s*-> if \{ -297 =>').Count -ne 2 -or
    [regex]::Matches($selfhostTyped, 'opcode <= -297 and opcode >= -298').Count -ne 2) {
    throw "self-host normalization, finalization, and opcode classifiers must agree on setNonblocking opcode -297"
}
if (-not $selfhostEmitter.Contains('call.opcode == -297 -> if {') -or
    -not $selfhostEmitter.Contains('@sollang_platform_socket_set_nonblocking(i64 %v$(request.callIndex)_socket_handle, i1 ')) {
    throw "self-host codegen must lower opcode -297 directly to the platform runtime"
}
if (-not $windowsLinker.Contains("            ioctlsocket")) {
    throw "the generated ws2_32 import library must export ioctlsocket"
}

if ($socketModel -notmatch '(?s)public enum PollMode\s*\{\s*Read\s+Write\s+Error\s*\}' -or
    [regex]::Matches($runtimeApi, 'public poll: self, mode: PollMode, timeout: Option<std\.time\.Duration> -> Result<Bool, SocketError> uses Network = intrinsic').Count -ne 3) {
    throw "readiness must use one typed PollMode and the same instance poll contract on all socket owners"
}
if ([regex]::Matches($managedWindows + $managedLinux, 'define internal %sollang\.socket_result @sollang_platform_socket_poll').Count -ne 2 -or
    [regex]::Matches($selfhost, 'define internal %sollang\.socket_result @sollang_platform_socket_poll').Count -ne 2) {
    throw "managed and self-host runtimes must define Windows and Linux poll lowerings"
}
if ([regex]::Matches($selfhostNormalize + $selfhostFinalize, '"poll"\)\s*\r?\n\s*-> if \{ -298 =>').Count -ne 2 -or
    -not $selfhostEmitter.Contains('call.opcode == -298 -> if {') -or
    -not $selfhostEmitter.Contains('@sollang_platform_socket_poll(i64 %v$(request.callIndex)_socket_handle')) {
    throw "self-host normalization, finalization, and codegen must agree on poll opcode -298"
}
if (-not $windowsLinker.Contains("            WSAPoll")) {
    throw "the generated ws2_32 import library must export WSAPoll"
}

Write-Host "[socket readiness] PASS WouldBlock, three nonblocking and poll instance APIs, direct Windows/Linux lowerings, stable ABI, self-host opcodes -297/-298, and linker exports."
