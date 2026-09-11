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
    if (-not $Text.Contains($Needle, [StringComparison]::Ordinal)) {
        throw "$Description is missing: $Needle"
    }
}

$publicSocket = Read-Authority "stdlib/std/net/socket.slg"
$runtimeSocket = Read-Authority "stdlib/sys/runtime/socket.slg"
$semantic = Read-Authority "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
$emitter = Read-Authority "src/Sollang.Compiler/CodeGen/LlvmEmitter.Socket.cs"
$windowsRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs"
$linuxRuntime = Read-Authority "src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs"
$selfhostTyped = Read-Authority "selfhost/ir/typed.slg"
$selfhostNormalize = (Read-Authority "selfhost/ir/typed/resolved_context_normalize.slg") + "`n" + (Read-Authority "selfhost/ir/typed/resolved_context_normalize_phases.slg")
$selfhostFinalize = Read-Authority "selfhost/ir/typed/resolved_context_finalize.slg"
$selfhostEmitter = Read-Authority "selfhost/llvm/text/platform_io.slg"
$selfhostRuntime = Read-Authority "selfhost/llvm/emitter/socket_runtime.slg"
$nativeExactBatch = Read-Authority "scripts/verify-native-exact-fixture-batch.ps1"
$fixture = Read-Authority "examples/regression/1378-socket-reactor-wait-into.slg"
$completionSlotFixture = Read-Authority "examples/regression/1693-socket-completion-slot-contract.slg"
$completionContractText = Read-Authority "scripts/contracts/socket-completion-reactor.json"
$completionContractSchema = Join-Path $RepositoryRoot "scripts/contracts/socket-completion-reactor.schema.json"
if (-not (Test-Json -Json $completionContractText -SchemaFile $completionContractSchema)) {
    throw "socket completion reactor contract does not satisfy its schema"
}
$completionContract = $completionContractText | ConvertFrom-Json

Require $publicSocket "public struct Reactor {" "instance reactor owner"
Require $publicSocket "interests: [Interest; ~]" "reactor registration storage"
Require $publicSocket "public registerStream: mut self, connection: ref TcpStream" "borrowed stream registration"
Require $publicSocket "public clear: mut self -> Unit" "explicit borrow release"
Require $runtimeSocket "public waitInto: self, events: mut [ReadyEvent; ~], timeout: Option<std.time.Duration> -> Result<UIntSize, SocketError> uses Network = intrinsic" "caller-buffer wait"
Require $semantic "RequireSocketReactorWaitSignature" "typed intrinsic signature"
Require $emitter "sollang_platform_socket_reactor_wait" "managed direct reactor call"
Require $windowsRuntime "call i32 @WSAPoll(ptr %descriptors" "single Windows readiness primitive"
Require $linuxRuntime "call i32 @poll(ptr %descriptors" "single Linux readiness primitive"
Require $selfhostTyped "opcode <= -297 and opcode >= -302" "self-host socket opcode range"
Require $selfhostNormalize 'sourceMatches(socketCallNameToken.span.start, socketCallNameToken.span.length, "waitInto")' "self-host early classification"
Require $selfhostFinalize 'sourceMatches(finalSocketIntrinsicNameToken.span.start, finalSocketIntrinsicNameToken.span.length, "waitInto")' "self-host final classification"
Require $selfhostEmitter "call.opcode == -302" "self-host reactor emission"
Require $fixture "reactor! -> registerStream(firstServer, 101, socket.InterestMode.Read)?" "first keyed registration"
Require $fixture "reactor! -> registerStream(secondServer, 202, socket.InterestMode.Read)?" "second keyed registration"
Require $fixture "reactor! -> clear" "registered-borrow release before close"
Require $nativeExactBatch '"1378-socket-reactor-wait-into"' "Stage2/Stage3 native promotion fixture"
Require $nativeExactBatch '"1693-socket-completion-slot-contract"' "completion slot native promotion fixture"
Require $publicSocket "public struct CompletionReactorOptions {" "bounded completion reactor options"
Require $publicSocket "public struct OperationSlot {" "affine operation slot owner"
Require $publicSocket "public operationSlot bytes: move [UInt8; ~], key: UInt64, direction: OperationDirection -> OperationSlot" "owned-buffer operation slot factory"
Require $publicSocket "public validate: self -> Result<CompletionReactorOptions, SocketError>" "pre-effect capacity validation"
Require $publicSocket "public intoBytes: move self -> [UInt8; ~]" "consuming caller-buffer recovery"
Require $completionSlotFixture "-> socket.operationSlot(77, socket.OperationDirection.Receive)" "natural operation-slot construction"
Require $completionSlotFixture "slot -> intoBytes => bytes" "affine buffer recovery"

if (@($completionContract.states) -join ',' -cne 'Vacant,Pending,Completed,Cancelled') {
    throw "socket completion reactor states must retain their exact affine order"
}
$expectedTransitions = @(
    'Vacant>Pending',
    'Vacant>Completed',
    'Pending>Completed',
    'Pending>Cancelled',
    'Completed>Vacant',
    'Cancelled>Vacant'
)
$actualTransitions = @($completionContract.transitions | ForEach-Object { "$($_.from)>$($_.to)" })
if ($actualTransitions.Count -ne $expectedTransitions.Count -or
    @(Compare-Object $expectedTransitions $actualTransitions).Count -ne 0) {
    throw "socket completion reactor transition set is incomplete or ambiguous"
}
if (@($completionContract.capacity.fields) -join ',' -cne 'registrations,pendingOperations,completionBatch' -or
    @($completionContract.capacity.relations) -join ',' -cne 'completionBatch <= pendingOperations,pendingOperations <= registrations') {
    throw "socket completion reactor bounded-capacity relations are incomplete"
}
if ($completionContract.platforms.'windows-x64'.primitive -cne 'IOCP with GetQueuedCompletionStatusEx' -or
    $completionContract.platforms.'linux-x64'.primitive -cne 'epoll with nonblocking sockets' -or
    $completionContract.platforms.'wasm32-browser'.capability -cne 'unsupported') {
    throw "socket completion reactor platform specialization is incomplete"
}
$milestones = @($completionContract.milestones)
if ($milestones.Count -ne 6 -or @($milestones.id | Sort-Object -Unique).Count -ne 6) {
    throw "socket completion reactor must track six distinct implementation milestones"
}
$implementedMilestones = @($milestones | Where-Object status -In @('implemented', 'verified')).id
if (@($implementedMilestones) -join ',' -cne 'configuration,slot') {
    throw "socket completion reactor implemented milestone set is stale"
}
foreach ($forbidden in @(
    'blocking worker thread presented as socket async',
    'busy-loop or repeated zero-timeout polling',
    'per-operation payload allocation or copy',
    'global mutable callback registry'
)) {
    if ($completionContract.forbidden -cnotcontains $forbidden) {
        throw "socket completion reactor contract lost forbidden shortcut: $forbidden"
    }
}

if ([regex]::Matches($windowsRuntime, 'define internal %sollang\.socket_result @sollang_platform_socket_reactor_wait').Count -ne 1) {
    throw "managed Windows runtime must define reactor_wait exactly once"
}
if ([regex]::Matches($linuxRuntime, 'define internal %sollang\.socket_result @sollang_platform_socket_reactor_wait').Count -ne 1) {
    throw "managed Linux runtime must define reactor_wait exactly once"
}
if ([regex]::Matches($windowsRuntime, 'call i32 @WSAPoll\(ptr %descriptors').Count -ne 1) {
    throw "Windows reactor wait must issue exactly one WSAPoll"
}
if ([regex]::Matches($linuxRuntime, 'call i32 @poll\(ptr %descriptors').Count -ne 1) {
    throw "Linux reactor wait must issue exactly one poll"
}
if ([regex]::Matches($selfhostRuntime, 'define internal %sollang\.socket_result @sollang_platform_socket_reactor_wait').Count -ne 2) {
    throw "self-host Windows and Linux runtimes must each define reactor_wait exactly once"
}
if ([regex]::Matches($selfhostRuntime, 'call i32 @WSAPoll\(ptr %descriptors').Count -ne 1) {
    throw "self-host Windows reactor wait must issue exactly one WSAPoll"
}
if ([regex]::Matches($selfhostRuntime, 'call i32 @poll\(ptr %descriptors').Count -ne 1) {
    throw "self-host Linux reactor wait must issue exactly one poll"
}

Write-Host "socket reactor contract verification passed"
