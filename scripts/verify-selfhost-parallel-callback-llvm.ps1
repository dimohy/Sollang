[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LlvmPath,
    [ValidateRange(1, 1024)][int]$MinimumCallbackCount = 1,
    [switch]$RequireNominalTransfer,
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolvedPath = (Resolve-Path -LiteralPath $LlvmPath).Path
$llvm = [System.IO.File]::ReadAllText($resolvedPath)
$callbackPattern = '(?ms)^define internal void @sollang_parallel_callback_[0-9]+\(ptr %group, i64 %index\)(?: #[0-9]+)? \{\r?\n.*?^\}\r?$'
$callbacks = @([regex]::Matches($llvm, $callbackPattern))
if ($callbacks.Count -lt $MinimumCallbackCount) {
    throw "self-host LLVM contains $($callbacks.Count) parallel callback(s), but at least $MinimumCallbackCount are required: $resolvedPath. Verify that the source parallel region is reachable and parallelUsesComputePool accepts its worker-transfer input and output types."
}

$nominalTransferCount = 0
foreach ($callback in $callbacks) {
    $body = $callback.Value
    $hasNominalInputAddress = $body -match '%input_address = getelementptr %sollang\.struct\.[^,\r\n]+, ptr %input, i64 %index'
    $hasNominalInputLoad = $body -match '%item = load %sollang\.struct\.[^,\r\n]+'
    $hasNominalResultCall = $body -match '%mapped = call %sollang\.struct\.[^ @\r\n]+ @sollang_m[0-9]+_s[0-9]+'
    $hasNominalResultStore = $body -match 'store %sollang\.struct\.[^ ]+ %mapped, ptr %output_address'
    if ($hasNominalInputAddress -and $hasNominalInputLoad -and
        $hasNominalResultCall -and $hasNominalResultStore) {
        $nominalTransferCount += 1
    }
}

if ($RequireNominalTransfer -and $nominalTransferCount -lt 1) {
    throw "self-host LLVM contains no nominal-record input/result worker callback: $resolvedPath. Do not benchmark or promote this compiler; it silently serialized a recursively transferable parallel region."
}

$result = [pscustomobject]@{
    LlvmPath = $resolvedPath
    CallbackCount = $callbacks.Count
    NominalTransferCallbackCount = $nominalTransferCount
}
if ($PassThru) {
    $result
} else {
    Write-Host "[selfhost parallel callbacks] PASS callbacks=$($callbacks.Count) nominal-transfer=$nominalTransferCount $resolvedPath"
}
