# Public runtime checks compare instructions, independent of basic-block order.
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
