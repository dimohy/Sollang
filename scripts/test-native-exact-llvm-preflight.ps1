[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$root = Join-Path $temporaryRoot ('sollang-llvm-preflight-' + [Guid]::NewGuid().ToString('N'))
if (-not ([IO.Path]::GetFullPath($root)).StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'LLVM_PREFLIGHT_TEST_BOUNDARY'
}
function Write-Input([string]$Name, [string]$Value) {
    $path = Join-Path $root $Name
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
    [IO.File]::WriteAllText($path, $Value, [Text.UTF8Encoding]::new($false))
}
try {
    Write-Input 'compiler.exe' 'must never execute'
    Write-Input 'compiler.dll' 'must never execute'
    Write-Input 'llvm/placeholder' ''
    Write-Input 'stdlib/placeholder' ''
    Write-Input 'examples/regression/oracle.slg' 'main {}'
    Write-Input 'examples/regression/expected/oracle.stdout.txt' ''
    $arguments = @{
        Compiler = Join-Path $root 'compiler.exe'; Label = 'managed'; Platform = 'windows'
        LlvmRoot = Join-Path $root 'llvm'; StdlibRoot = Join-Path $root 'stdlib'
        RepositoryRoot = $root; OutputDirectory = Join-Path $root 'must-not-build'
        Fixture = @('oracle'); Jobs = 1; ValidateInputsOnly = $true
    }
    $counts = 'examples/regression/expected/oracle.selfhost.llvm.regex-counts.txt'
    $stale = @(
        '@sollang_m[0-9]+_s[0-9]+', '@sollang_m([0-9]+)_s[0-9]+',
        '@sollang_m(?:[0-9]+)_s0', '@sollang_m\d+_s\d+', '@sollang_m42_s0',
        '%sollang\.struct\.m([0-9]+)_s0', '(x)%sollang\.struct\.m\1_s0'
    )
    foreach ($pattern in $stale) {
        Write-Input $counts ("0`t" + $pattern)
        $failure = $null
        try { & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments }
        catch { $failure = $_.Exception.Message }
        if ($failure -notmatch 'EXACT_LLVM_STALE_SOURCE_COORDINATE' -or (Test-Path -LiteralPath $arguments.OutputDirectory)) {
            throw "LEGACY_ORACLE_NOT_REJECTED_BEFORE_COMPILER: $pattern : $failure"
        }
    }
    foreach ($pattern in @('@sollang_x000107010372756E', '%sollang\.struct\.x000103010341626300',
            '@sollang_mapped_flush', '@sollang_mouse_event_stream_next')) {
        Write-Input $counts ("0`t" + $pattern)
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments
        if (Test-Path -LiteralPath $arguments.OutputDirectory) { throw 'PREFLIGHT_CREATED_BUILD_OUTPUT' }
    }
    foreach ($invalid in @("-1`tvalid", "bad`tvalid", "0`t(", "0`t")) {
        Write-Input $counts $invalid
        $failure = $null
        try { & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments }
        catch { $failure = $_.Exception.Message }
        if ($failure -notmatch 'EXACT_LLVM_INVALID_REGEX' -or (Test-Path -LiteralPath $arguments.OutputDirectory)) {
            throw "INVALID_ORACLE_NOT_REJECTED_BEFORE_COMPILER: $failure"
        }
    }
    Write-Input $counts ("0`t@sollang_x00")
    $ordered = 'examples/regression/expected/oracle.selfhost.llvm.ordered-regex.txt'
    Write-Input $ordered '@sollang_m([0-9]+)_s0'
    $failure = $null
    try { & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments }
    catch { $failure = $_.Exception.Message }
    if ($failure -notmatch 'EXACT_LLVM_STALE_SOURCE_COORDINATE' -or (Test-Path -LiteralPath $arguments.OutputDirectory)) {
        throw "ORDERED_LEGACY_ORACLE_NOT_REJECTED_BEFORE_COMPILER: $failure"
    }
    Write-Input $counts ("0`t@sollang_m([0-9]+)_s0")
    $arguments.Compiler = Join-Path $root 'compiler.dll'
    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') @arguments
    Write-Host '[LLVM oracle preflight] PASS 7 stale forms, 4 valid names, 4 malformed inputs, ordered oracle, producer-side selection; no compiler or output creation.'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
