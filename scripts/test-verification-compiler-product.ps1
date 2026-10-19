[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$NativeBuild,
    [Parameter(Mandatory)][string]$ExpectedNativeSha256,
    [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'verification-compiler-product.ps1')
if (Test-Path -LiteralPath $OutputPath) { throw 'COMPILER_PRODUCT_TEST_FRESH_OUTPUT_REQUIRED' }
$rows = [Collections.Generic.List[object]]::new()
function Check([string]$Name, [scriptblock]$Action, [string]$ExpectedFailure = '') {
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    if ($ExpectedFailure) {
        if ($caught -cne $ExpectedFailure) { throw "${Name}: expected=$ExpectedFailure actual=$caught" }
    } elseif ($null -ne $caught) { throw "${Name}: $caught" }
    $rows.Add([ordered]@{ name=$Name; passed=$true; expectedFailure=$ExpectedFailure })
}
$native = Join-Path $NativeBuild 'compiler.exe'
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
Check 'repository-managed-product' { Resolve-VerificationCompilerProduct $root $managed (Get-FileHash $managed).Hash }
Check 'current-external-native-build' {
    $product = Resolve-VerificationCompilerProduct $root $native $ExpectedNativeSha256
    if ($product.InputHashes.Count -eq 0) { throw 'EXTERNAL_PROOF_NOT_PINNED' }
}
Check 'changed-expected-compiler-hash' { Resolve-VerificationCompilerProduct $root $native ('0' * 64) } 'VERIFICATION_COMPILER_PRODUCT_SHA_MISMATCH'
$llvm = Join-Path $NativeBuild 'compiler.exe.ll'
Check 'external-llvm-cannot-impersonate-compiler' { Resolve-VerificationCompilerProduct $root $llvm (Get-FileHash $llvm).Hash } 'VERIFICATION_EXTERNAL_COMPILER_IDENTITY_MISMATCH'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('sollang-compiler-proof-test-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($temporary) | Out-Null
$fake = Join-Path $temporary 'compiler.exe'
try {
    [IO.File]::WriteAllText($fake, 'unverified product')
    Check 'external-product-without-build-proof' { Resolve-VerificationCompilerProduct $root $fake (Get-FileHash $fake).Hash 2>$null } 'VERIFICATION_EXTERNAL_COMPILER_BUILD_PROOF_INVALID'
} finally {
    Remove-Item -LiteralPath $fake
    Remove-Item -LiteralPath $temporary
}
$record = [ordered]@{ schemaVersion=1; status='passed'; scope='compiler-input-contract-only-no-native-execution'; completed=$rows.Count; total=5; checks=@($rows) }
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), ($record | ConvertTo-Json -Depth 5) + "`n")
Write-Host "Compiler product contract tests: $($rows.Count)/5"
