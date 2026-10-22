# Public runtime checks compare instructions, independent of basic-block order.
function Test-VerificationSocketWaiterScratch {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Body,
          [Parameter(Mandatory)][ValidateSet('windows', 'linux')][string]$Platform)
    $slots = @(if ($Platform -ceq 'windows') {
        @('%removed = alloca i32, align 4', '%completion_flags = alloca i32, align 4')
    } else { @('%wakeup_value = alloca i64, align 8') })
    $entry = [regex]::Match($Body,
        '(?ms)^entry:\r?\n(?<body>.*?)(?=^[A-Za-z$._][A-Za-z0-9$._-]*:|\z)')
    if (-not $entry.Success) { return $false }
    # One fixed allocation per waiter, rather than once per completion/wakeup.
    if ([regex]::Matches($Body, '\balloca\b').Count -ne $slots.Count) { return $false }
    foreach ($slot in $slots) {
        if ([regex]::Matches($Body, [regex]::Escape($slot)).Count -ne 1 -or
            -not $entry.Groups['body'].Value.Contains($slot, [StringComparison]::Ordinal)) { return $false }
    }
    return $true
}

function Get-VerificationSocketCancelBlock {
    param([Parameter(Mandatory)][string]$Body)
    $match = [regex]::Match($Body,
        '(?ms)^cancel_socket_completion:\r?\n(?<body>.*?)(?=^[A-Za-z$._][A-Za-z0-9$._-]*:|\z)')
    if (-not $match.Success) { throw 'SOCKET_CANCEL_BLOCK_MISSING' }
    return $match.Groups['body'].Value
}

function Get-VerificationSocketReleaseCall {
    param([Parameter(Mandatory)][ValidateSet('managed', 'native')][string]$CompilerKind,
          [Parameter(Mandatory)][ValidatePattern('^%[A-Za-z_][A-Za-z0-9_]*$')][string]$Operand)
    # The managed emitter owns the instrumentable allocation wrapper; the
    # separate SLG emitter calls the platform C allocator directly.
    $symbol = if ($CompilerKind -ceq 'managed') { 'sollang_free' } else { 'free' }
    return "call void @$symbol(ptr $Operand)"
}

function Test-VerificationSocketCancelRequest {
    param([Parameter(Mandatory)][string]$Body)
    $block = Get-VerificationSocketCancelBlock -Body $Body
    $phase = $block.IndexOf('store atomic i32 1, ptr %socket_cancel_phase_slot release', [StringComparison]::Ordinal)
    $callback = $block.IndexOf('call void %socket_cancel_fn(ptr %handle)', [StringComparison]::Ordinal)
    return $phase -ge 0 -and $callback -gt $phase -and
        $block -notmatch 'call void @(?:sollang_free|free)\(ptr %handle\)'
}
