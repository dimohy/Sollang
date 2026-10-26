# Public runtime checks inspect only the selected runtime function bodies.
function Test-VerificationSocketRegisterPreEffect {
    param([Parameter(Mandatory)][string]$Source)
    $extract = {
        param([string]$Name)
        $pattern = 'define internal %sollang\.socket_result @' + [regex]::Escape($Name) + '\([^\r\n]+\) #0 \{(?<body>.*?)\r?\n        \}'
        $definitions = [regex]::Matches($Source, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
        if ($definitions.Count -ne 1) { return '' }
        return $definitions[0].Groups['body'].Value
    }
    $name = 'sollang_platform_socket_completion_register_stream'
    $entry = & $extract $name
    if ([string]::IsNullOrEmpty($entry)) { return $false }
    $body = $entry
    if ($entry.Contains("@$($name)_locked", [StringComparison]::Ordinal)) {
        $call = '%result = call %sollang.socket_result @' + $name + '_locked(i64 %identity, i64 %socket, i64 %key)'
        $lock = $entry.IndexOf('call void @sollang_socket_completion_lock(ptr %state)', [StringComparison]::Ordinal)
        $invoke = $entry.IndexOf($call, [StringComparison]::Ordinal)
        $unlock = $entry.IndexOf('call void @sollang_socket_completion_unlock(ptr %state)', [StringComparison]::Ordinal)
        $returned = $entry.IndexOf('ret %sollang.socket_result %result', [StringComparison]::Ordinal)
        if ($lock -lt 0 -or $invoke -le $lock -or $unlock -le $invoke -or $returned -le $unlock) { return $false }
        $body = & $extract ($name + '_locked')
        if ([string]::IsNullOrEmpty($body)) { return $false }
    }
    foreach ($candidate in @($entry, $body)) {
        foreach ($effect in @('CreateIoCompletionPort', '@epoll_ctl', '@fcntl')) {
            if ($candidate.Contains($effect, [StringComparison]::Ordinal)) { return $false }
        }
    }
    $duplicate = [regex]::Match($body, '(?m)^[ \t]*duplicate_loop:\r?$')
    $capacity = [regex]::Match($body, '(?m)^[ \t]*free_loop:\r?$')
    $count = [regex]::Match($body, '(?m)^[ \t]*store i64 %next_count, ptr %count_slot, align 8[ \t]*\r?$')
    $active = [regex]::Match($body, '(?m)^[ \t]*store i64 1, ptr %free_entry, align 8[ \t]*\r?$')
    return $duplicate.Success -and $capacity.Success -and $capacity.Index -gt $duplicate.Index -and
        $count.Success -and $active.Success -and $active.Index -gt $count.Index
}

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
