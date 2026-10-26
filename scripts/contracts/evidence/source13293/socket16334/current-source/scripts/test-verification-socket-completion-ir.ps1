$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-socket-completion-ir.ps1')
$request = @'
cancel_socket_completion:
  store atomic i32 1, ptr %socket_cancel_phase_slot release, align 4
  call void %socket_cancel_fn(ptr %handle)
  ret i1 true
'@
$other = "detach_child:`n  call void @free(ptr %handle)`n  ret i1 true`n"
foreach ($body in @("$request`n$other", "$other`n$request")) {
    if (-not (Test-VerificationSocketCancelRequest -Body $body)) { throw 'CANCEL_VALID_BLOCK_ORDER_REJECTED' }
}
foreach ($symbol in @('free', 'sollang_free')) {
    $invalid = $request.Replace('  ret i1 true', "  call void @$symbol(ptr %handle)`n  ret i1 true")
    if (Test-VerificationSocketCancelRequest -Body $invalid) { throw 'CANCEL_PREMATURE_FREE_ACCEPTED' }
}
$phase = '  store atomic i32 1, ptr %socket_cancel_phase_slot release, align 4'
foreach ($invalid in @($request.Replace($phase, ''),
    $request.Replace('  call void %socket_cancel_fn(ptr %handle)', ''),
    $request.Replace($phase, '').Replace('  ret i1 true', "$phase`n  ret i1 true"))) {
    if (Test-VerificationSocketCancelRequest -Body $invalid) { throw 'CANCEL_INCOMPLETE_OR_REORDERED_REQUEST_ACCEPTED' }
}
try { Get-VerificationSocketCancelBlock -Body $other | Out-Null; throw 'CANCEL_MISSING_BLOCK_ACCEPTED' }
catch { if ($_.Exception.Message -cne 'SOCKET_CANCEL_BLOCK_MISSING') { throw } }
if ((Get-VerificationSocketReleaseCall -CompilerKind managed -Operand '%descriptor') -cne 'call void @sollang_free(ptr %descriptor)' -or
    (Get-VerificationSocketReleaseCall -CompilerKind native -Operand '%descriptor') -cne 'call void @free(ptr %descriptor)') { throw 'CANCEL_ALLOCATOR_IDENTITY_CHANGED' }
foreach ($platform in @('windows', 'linux')) {
    $slots = if ($platform -ceq 'windows') {
        "  %removed = alloca i32, align 4`n  %completion_flags = alloca i32, align 4`n"
    } else { "  %wakeup_value = alloca i64, align 8`n" }
    $valid = "entry:`n$slots  br label %wait`nwait:`n  br label %wait`n"
    if (-not (Test-VerificationSocketWaiterScratch -Body $valid -Platform $platform)) { throw 'WAITER_FIXED_SCRATCH_REJECTED' }
    foreach ($invalid in @($valid.Replace($slots, '').Replace("wait:`n", "wait:`n$slots"),
        $valid.Replace($slots, ''), $valid.Replace($slots, "$slots$slots"))) {
        if (Test-VerificationSocketWaiterScratch -Body $invalid -Platform $platform) { throw 'WAITER_REPEATED_OR_MISSING_SCRATCH_ACCEPTED' }
    }
}
Write-Output 'Socket IR: cancellation controls and Windows/Linux fixed scratch, repeated allocation, missing and duplicate storage controls passed.'
$runtimeRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/Sollang.Compiler/CodeGen'
$windows = [IO.File]::ReadAllText((Join-Path $runtimeRoot 'WindowsLlvmRuntimePlatform.Socket.cs'))
$linux = [IO.File]::ReadAllText((Join-Path $runtimeRoot 'LinuxLlvmRuntimePlatform.Socket.cs'))
$registrationControls = 0
foreach ($source in @($windows, $linux)) {
    if (-not (Test-VerificationSocketRegisterPreEffect -Source $source)) { throw 'VALID_DIRECT_OR_LOCKED_REGISTRATION_REJECTED' }
    $registrationControls++
}
$active = 'store i64 1, ptr %free_entry, align 8'
$count = 'store i64 %next_count, ptr %count_slot, align 8'
$forward = '%result = call %sollang.socket_result @sollang_platform_socket_completion_register_stream_locked(i64 %identity, i64 %socket, i64 %key)'
$lockedDefinition = 'define internal %sollang\.socket_result @sollang_platform_socket_completion_register_stream_locked\([^\r\n]+\) #0 \{.*?\r?\n        \}'
$invalidRegistrations = @(
    $windows.Replace('@sollang_platform_socket_completion_register_stream(', '@missing_register_stream('),
    $windows.Replace('duplicate_loop:', 'missing_duplicate_loop:'),
    $windows.Replace('duplicate_loop:', '__swap_label__:').Replace('free_loop:', 'duplicate_loop:').Replace('__swap_label__:', 'free_loop:'),
    $windows.Replace($count, ''),
    $windows.Replace($active, '').Replace($count, "$active`n          $count"),
    $linux.Replace($forward, $forward.Replace('i64 %key)', 'i64 %socket)')),
    [regex]::Replace($linux, $lockedDefinition, '', [Text.RegularExpressions.RegexOptions]::Singleline),
    $linux.Replace('duplicate_loop:', "call void @epoll_ctl()`nduplicate_loop:"),
    $linux.Replace('call void @sollang_socket_completion_unlock(ptr %state)', '')
)
foreach ($source in $invalidRegistrations) {
    if (Test-VerificationSocketRegisterPreEffect -Source $source) { throw "INVALID_REGISTRATION_ACCEPTED:$registrationControls" }
    $registrationControls++
}
@{ status = 'passed'; registrationControlsCompleted = $registrationControls; registrationControlsTotal = 11 } | ConvertTo-Json
