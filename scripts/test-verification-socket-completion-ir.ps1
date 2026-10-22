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
