Set-StrictMode -Version Latest

function Assert-LlvmNoAllocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$LlvmText,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RootSymbolPattern,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$AllowedExternalSymbols
    )

    # This checks the reachable call graph of assembled, compiler-emitted LLVM;
    # it is not an LLVM parser or a substitute for llvm-as. Unsupported function
    # or call syntax fails closed instead of disappearing from the graph.
    function Remove-LlvmLineComment([string]$Line) {
        $quoted = $false
        for ($index = 0; $index -lt $Line.Length; $index++) {
            if ($Line[$index] -eq '"') { $quoted = -not $quoted }
            if ($Line[$index] -eq ';' -and -not $quoted) { return $Line.Substring(0, $index) }
        }
        return $Line
    }

    function Get-DirectCallTarget([string]$Instruction, [string]$Owner) {
        $depth = 0
        $quoted = $false
        for ($index = 0; $index -lt $Instruction.Length; $index++) {
            $character = $Instruction[$index]
            if ($character -eq '"') { $quoted = -not $quoted; continue }
            if ($quoted) { continue }
            if ($character -eq '(') { $depth++; continue }
            if ($character -eq ')') { $depth--; continue }
            if ($depth -lt 0) { break }
            if ($depth -ne 0 -or $character -notin @('@', '%')) { continue }
            $target = [regex]::Match($Instruction.Substring($index), '^(?<sigil>[@%])(?<symbol>[-a-zA-Z$._0-9]+)\s*\(')
            if (-not $target.Success) { continue }
            if ($target.Groups['sigil'].Value -ceq '%') {
                throw "LLVM_NO_ALLOCATION_INDIRECT_CALL: ${Owner}: $Instruction"
            }
            return $target.Groups['symbol'].Value
        }
        throw "LLVM_NO_ALLOCATION_UNPARSED_CALL: ${Owner}: $Instruction"
    }

    $bodies = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    $symbols = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($symbol in $AllowedExternalSymbols) {
        if ([string]::IsNullOrWhiteSpace($symbol)) { throw 'LLVM_NO_ALLOCATION_INVALID_ALLOWLIST: empty symbol' }
        [void]$allowed.Add($symbol)
    }

    $owner = $null
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($rawLine in ($LlvmText -split "\r?\n")) {
        $line = (Remove-LlvmLineComment $rawLine).Trim()
        if ($line -match '^(define|declare)\b') {
            if ($null -ne $owner) { throw "LLVM_NO_ALLOCATION_UNPARSED_FUNCTION: unterminated $owner" }
            $header = [regex]::Match($line, '^(?<kind>define|declare)\s+[^@\r\n]+@(?<symbol>[-a-zA-Z$._0-9]+)\s*\(')
            if (-not $header.Success) { throw "LLVM_NO_ALLOCATION_UNPARSED_FUNCTION: $line" }
            $symbol = $header.Groups['symbol'].Value
            if (-not $symbols.Add($symbol)) { throw "LLVM_NO_ALLOCATION_DUPLICATE_SYMBOL: $symbol" }
            if ($header.Groups['kind'].Value -ceq 'declare') { [void]$declared.Add($symbol); continue }
            if (-not $line.EndsWith('{', [StringComparison]::Ordinal)) {
                throw "LLVM_NO_ALLOCATION_UNPARSED_FUNCTION: $symbol header/body boundary"
            }
            $owner = $symbol
            $lines = [Collections.Generic.List[string]]::new()
            continue
        }
        if ($null -eq $owner) { continue }
        if ($line -ceq '}') {
            $bodies.Add($owner, $lines.ToArray())
            $owner = $null
            continue
        }
        $lines.Add($line)
    }
    if ($null -ne $owner) { throw "LLVM_NO_ALLOCATION_UNPARSED_FUNCTION: unterminated $owner" }

    $rootPattern = [regex]::new($RootSymbolPattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant, [TimeSpan]::FromSeconds(1))
    $roots = @($bodies.Keys | Where-Object { $rootPattern.IsMatch($_) } | Sort-Object -CaseSensitive)
    if ($roots.Count -eq 0) { throw "LLVM_NO_ALLOCATION_NO_ROOTS: $RootSymbolPattern" }
    $allocators = '^(?:sollang_(?:alloc|realloc)(?:_.*)?|_*malloc|_*calloc|_*realloc|reallocarray|aligned_alloc|valloc|pvalloc|_aligned_(?:malloc|realloc|offset_malloc|offset_realloc)|HeapAlloc|HeapReAlloc|LocalAlloc|LocalReAlloc|GlobalAlloc|GlobalReAlloc|VirtualAlloc(?:Ex|2|2FromApp)?|CoTaskMemAlloc|CoTaskMemRealloc|RtlAllocateHeap|RtlReAllocateHeap)$'
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $externals = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $pending = [Collections.Generic.Queue[string]]::new()
    foreach ($symbol in $roots) { $pending.Enqueue($symbol) }
    $calls = 0
    while ($pending.Count -gt 0) {
        $owner = $pending.Dequeue()
        if (-not $visited.Add($owner)) { continue }
        foreach ($line in $bodies[$owner]) {
            # LLVM itself permits multiple instructions per line. Our emitted
            # surface is one instruction per line; reject other layouts rather
            # than silently retaining only the last assignment/call. Quoted
            # metadata and %call/@call/!call identifiers are not opcodes.
            $unquoted = [regex]::Replace($line, '"[^"\r\n]*"', '""')
            $callWords = [regex]::Matches($unquoted, '(?<![-a-zA-Z$._0-9%@!])(?:call|invoke|callbr)(?=\s|$)')
            if ($callWords.Count -eq 0) { continue }
            $call = [regex]::Match($line, '^(?:(?:%[-a-zA-Z$._0-9]+|%"[^"\r\n]+")\s*=\s*)?(?:(?:musttail|tail|notail)\s+)?(?<opcode>call|invoke|callbr)(?=\s|$)(?<instruction>.*)$')
            if ($callWords.Count -ne 1 -or -not $call.Success) {
                throw "LLVM_NO_ALLOCATION_UNPARSED_CALL: ${owner}: unsupported call instruction layout: $line"
            }
            if ($call.Groups['opcode'].Value -ceq 'callbr') {
                throw "LLVM_NO_ALLOCATION_UNPARSED_CALL: ${owner}: callbr is not supported"
            }
            $callee = Get-DirectCallTarget $call.Groups['instruction'].Value $owner
            $calls++
            if ($callee -cmatch $allocators) { throw "LLVM_NO_ALLOCATION_ALLOCATOR: $owner -> $callee" }
            if ($bodies.ContainsKey($callee)) { $pending.Enqueue($callee); continue }
            if (-not $declared.Contains($callee)) { throw "LLVM_NO_ALLOCATION_UNRESOLVED_CALL: $owner -> $callee" }
            if (-not $allowed.Contains($callee)) { throw "LLVM_NO_ALLOCATION_UNKNOWN_EXTERNAL: $owner -> $callee" }
            [void]$externals.Add($callee)
        }
    }
    # memcpy/lifetime/debug intrinsics are not allocation by name. Like other
    # external functions, they still require explicit caller authorization.
    return [pscustomobject]@{
        Scope = 'reachable-direct-call-graph-allocation-audit-not-llvm-validation'
        RootCount = $roots.Count
        BodyCount = $bodies.Count
        ReachableBodyCount = $visited.Count
        DirectCallCount = $calls
        RootSymbols = $roots
        ExternalSymbols = @($externals | Sort-Object -CaseSensitive)
    }
}
