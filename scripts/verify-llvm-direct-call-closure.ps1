[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LlvmPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$LlvmPath = [System.IO.Path]::GetFullPath($LlvmPath)
if (-not (Test-Path -LiteralPath $LlvmPath -PathType Leaf)) {
    throw "LLVM direct-call closure input is missing: $LlvmPath"
}

$llvm = [System.IO.File]::ReadAllText($LlvmPath)
$functionRecords = [regex]::Matches(
    $llvm,
    '(?m)^(?<kind>define|declare)\s+[^\r\n]*?@(?<symbol>[-a-zA-Z$._0-9]+)\(')
$duplicateFunctions = @($functionRecords |
    Group-Object { $_.Groups['symbol'].Value } |
    Where-Object Count -gt 1 |
    ForEach-Object Name |
    Sort-Object)
if ($duplicateFunctions.Count -gt 0) {
    throw "sollang compiler verification failure V005: emitted LLVM repeats function declarations or definitions: $($duplicateFunctions -join ', '). Emit each target-runtime symbol from one canonical declaration owner; do not wait for llvm-as to report a late redefinition."
}

$defined = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$declaredOrDefined = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$functionRecords |
    ForEach-Object { [void]$declaredOrDefined.Add($_.Groups['symbol'].Value) }
$functionRecords |
    Where-Object {
        $_.Groups['kind'].Value -eq 'define' -and
        $_.Groups['symbol'].Value -match '^sollang_m\d+_s\d+$'
    } |
    ForEach-Object { [void]$defined.Add($_.Groups['symbol'].Value) }

$unresolved = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
[regex]::Matches(
    $llvm,
    '(?m)^\s*(?:%[-a-zA-Z$._0-9]+\s*=\s*)?(?:(?:musttail|tail|notail)\s+)?(?:call|invoke)\s+[^\r\n]*?@(?<symbol>(?:sollang_m-?\d+_s-?\d+|sollang_runtime_[-a-zA-Z$._0-9]+))\(') |
    ForEach-Object {
        $symbol = $_.Groups['symbol'].Value
        $isResolved = if ($symbol.StartsWith('sollang_runtime_', [System.StringComparison]::Ordinal)) {
            $declaredOrDefined.Contains($symbol)
        } else {
            $defined.Contains($symbol)
        }
        if (-not $isResolved) {
            [void]$unresolved.Add($symbol)
        }
    }

if ($unresolved.Count -gt 0) {
    throw "sollang compiler verification failure V004: emitted LLVM contains internal Sollang calls without definitions or runtime calls without declarations: $($unresolved -join ', '). A bodyless runtime intrinsic must lower to its canonical runtime opcode instead of surviving as declare @sollang_m*_s*; keep derived callbacks and user-function emission on the same executable reachability closure, and emit each used sollang_runtime_* helper from its target capability owner."
}

$nativeGlobalPattern = 'sollang_native_(?:function_m\d+_s\d+|library_m\d+_a\d+)'
$definedNativeGlobals = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
[regex]::Matches($llvm, "(?m)^@(?<symbol>$nativeGlobalPattern)\s*=") |
    ForEach-Object { [void]$definedNativeGlobals.Add($_.Groups['symbol'].Value) }
$unresolvedNativeGlobals = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($line in [System.IO.File]::ReadLines($LlvmPath)) {
    $trimmed = $line.TrimStart()
    if ($trimmed.StartsWith(';', [System.StringComparison]::Ordinal) -or
        $line.Contains(' c"', [System.StringComparison]::Ordinal)) {
        continue
    }
    [regex]::Matches($line, "@(?<symbol>$nativeGlobalPattern)") |
        ForEach-Object {
            $symbol = $_.Groups['symbol'].Value
            if (-not $definedNativeGlobals.Contains($symbol)) {
                [void]$unresolvedNativeGlobals.Add($symbol)
            }
        }
}
if ($unresolvedNativeGlobals.Count -gt 0) {
    throw "sollang compiler verification failure V007: emitted LLVM uses native-library state globals without definitions: $($unresolvedNativeGlobals -join ', '). Classify call targets by the exact NativeFunctionDeclaration CST identity, not by the shared bodyless intrinsic flag, and emit every reachable native library/function global before use."
}

Write-Host "[LLVM direct-call closure] PASS $LlvmPath"
