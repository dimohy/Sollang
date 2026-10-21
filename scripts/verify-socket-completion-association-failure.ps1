[CmdletBinding()]
param(
    [ValidateSet('preserved', 'baseline-failure')][string]$Expectation = 'preserved',
    [ValidateSet('managed', 'selfhost')][string]$Authority = 'managed'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')
$root = Split-Path -Parent $PSScriptRoot
$sourcePath = if ($Authority -eq 'managed') {
    Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'
} else { Join-Path $root 'selfhost/llvm/emitter/socket_runtime.slg' }
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/socket-completion-association-failure.c'
$inputs = @($sourcePath, $harness, $PSCommandPath, (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1'))
$hashes = [ordered]@{}
foreach ($path in $inputs) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$source = [IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n")
if ($Authority -eq 'selfhost') {
    $regions = @()
    foreach ($name in @('emitWindowsRuntime', 'emitWindowsCompletionRuntime')) {
        $region = [regex]::Matches($source, "(?ms)^public ${name}:.*?(?=^public |\z)")
        if ($region.Count -ne 1) { throw "Expected exactly one Windows emitter region: $name" }
        $regions += $region[0].Value
    }
    $source = $regions -join "`n"
}
$names = @('sollang_socket_result', 'sollang_socket_error_kind', 'sollang_platform_socket_completion_remove_stream', 'sollang_platform_socket_completion_submit')
$bodies = @()
foreach ($name in $names) {
    $matches = [regex]::Matches($source, "(?ms)^\s*define internal [^`n]+ @$name\([^`n]+\) #0 \{.*?^\s*\}")
    if ($matches.Count -ne 1) { throw "Expected exactly one production function: $name" }
    $bodies += $matches[0].Value.Replace(' #0 {', ' {')
}
$llvm = @'
%sollang.socket_result = type { i64, i32, i32 }
declare dllimport ptr @CreateIoCompletionPort(ptr, ptr, i64, i32)
declare dllimport ptr @CreateThread(ptr, i64, ptr, ptr, i32, ptr)
declare dllimport i32 @GetLastError()
declare dllimport i32 @WSAGetLastError()
declare dllimport i32 @WSARecv(i64, ptr, i32, ptr, ptr, ptr, ptr)
declare dllimport i32 @WSASend(i64, ptr, i32, ptr, i32, ptr, ptr)
declare i32 @socket_probe_notification_modes(ptr, i8)
declare i1 @sollang_platform_io_ensure_signal()
declare i32 @sollang_socket_completion_waiter(ptr)
declare void @llvm.memset.p0.i64(ptr, i8, i64, i1)
'@
$llvm += "`n" + (($bodies -join "`n").Replace('@SetFileCompletionNotificationModes(', '@socket_probe_notification_modes('))
$llvm += @'

define i32 @socket_probe_submit(ptr %state, ptr %code) {
  %identity = ptrtoint ptr %state to i64
  %buffer = alloca i8
  %r = call %sollang.socket_result @sollang_platform_socket_completion_submit(i64 %identity, i64 17, i64 31, i32 1, ptr %buffer, i64 1, i64 1, i64 0, i64 1, i32 0)
  %kind = extractvalue %sollang.socket_result %r, 1
  %error = extractvalue %sollang.socket_result %r, 2
  store i32 %error, ptr %code
  ret i32 %kind
}
define i32 @socket_probe_remove(ptr %state, ptr %socket) {
  %identity = ptrtoint ptr %state to i64
  %r = call %sollang.socket_result @sollang_platform_socket_completion_remove_stream(i64 %identity, i64 17)
  %kind = extractvalue %sollang.socket_result %r, 1
  %value = extractvalue %sollang.socket_result %r, 0
  store i64 %value, ptr %socket
  ret i32 %kind
}
'@
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name 'socket-association-failure' -Harness $harness
$record = [ordered]@{
    schemaVersion = 1; status = 'running'; expectation = $Expectation; authority = $Authority
    evidenceScope = 'Extracted production submit/remove; real Windows unconnected socket and IOCP; notification-mode failure injection; waiter lifetime excluded; not full compiler acceptance'
    completed = 0; total = 4
    inputHashes = $hashes; inputsStable = $false; processesStopped = $false
}
try {
    # Assertions live in the C harness; native error codes remain in stdout.
    # Baseline mode characterizes the defect and cannot qualify the repair.
    $ll = Join-Path $probe.Output 'managed.ll'
    [IO.File]::WriteAllText($ll, "$($probe.TargetHeader)`n$llvm`n", [Text.UTF8Encoding]::new($false))
    . (Join-Path $PSScriptRoot 'verification-process.ps1')
    foreach ($step in @(
        @{Name='assemble'; File=$probe.LlvmAs; Arguments=@($ll, '-o', (Join-Path $probe.Output 'managed.bc'))},
        @{Name='link'; File=$probe.Clang; Arguments=@('-Wall','-Wextra','-Werror',$probe.HarnessLlvm,(Join-Path $probe.Output 'managed.bc'),'-o',(Join-Path $probe.Output 'managed.exe'))},
        @{Name='execute'; File=(Join-Path $probe.Output 'managed.exe'); Arguments=@($Expectation)}
    )) {
        $result = Invoke-VerificationProcessCapture -FilePath $step.File -ArgumentList $step.Arguments -Description "socket association $($step.Name)" -TimeoutMilliseconds 20000 -ExecutionRecordPath (Join-Path $probe.Output "$($step.Name).execution.json")
        [IO.File]::WriteAllText((Join-Path $probe.Output "$($step.Name).stdout.txt"), $result.Stdout)
        [IO.File]::WriteAllText((Join-Path $probe.Output "$($step.Name).stderr.txt"), $result.Stderr)
        if ($result.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($result.Stderr)) { throw "Association $($step.Name) failed (exit $($result.ExitCode)): $($result.Stderr)" }
    }
    $record.status = 'passed'
    $record.completed = 4
} catch {
    $record.status = 'failed'; $record.failure = $_.Exception.Message
} finally {
    $record.inputsStable = $true
    foreach ($path in $inputs) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { $record.inputsStable = $false; $record.status = 'failed' }
    }
    $record.processesStopped = $true
    [IO.File]::WriteAllText((Join-Path $probe.Output 'result.json'), ($record | ConvertTo-Json -Depth 6))
}
Write-Host "$($record.status): $($probe.Output)"
if ($record.status -ne 'passed') { throw $record.failure }
