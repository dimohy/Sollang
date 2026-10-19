[CmdletBinding()]
param(
    [ValidateSet('vulnerable', 'fixed')]
    [string]$ExpectedResolverState = 'fixed',
    [string[]]$CandidateLlvmPath = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resolverPath = Join-Path $root 'selfhost/semantic/call_resolution_sources.slg'
$resolver = [IO.File]::ReadAllText($resolverPath)
$requiredGuards = @(
    'moduleQualifiedTargetSymbol\.kind\s*==\s*27\s+and\s+moduleQualifiedTargetSymbol\.typeNode\s*>=\s*0',
    'importedTargetSymbol\.kind\s*==\s*27\s+and\s+importedTargetSymbol\.typeNode\s*>=\s*0',
    'siblingVariantSymbol\.kind\s*==\s*27\s+and\s+siblingVariantSymbol\.typeNode\s*>=\s*0'
)
$missingGuards = @($requiredGuards | Where-Object { -not [regex]::IsMatch($resolver, $_) })
if ($ExpectedResolverState -eq 'vulnerable') {
    if ($missingGuards.Count -ne $requiredGuards.Count) {
        throw 'C457 baseline resolver unexpectedly contains a payload-bearing-only enum call guard'
    }
} elseif ($missingGuards.Count -gt 0) {
    throw "C457 payloadless enum variants remain callable: $($missingGuards -join '; ')"
}

$baselineCases = [ordered]@{
    '787-selfhost-file-write-match-subject-ir' = @(
        'sollang_m190_s13', 'sollang_m191_s15', 'sollang_m192_s7', 'sollang_m192_s8')
    '1217-selfhost-late-indexed-array-type-contract' = @(
        'sollang_m171_s13', 'sollang_m172_s15', 'sollang_m173_s7', 'sollang_m173_s8')
    '1383-selfhost-inferred-receiver-method-owner' = @(
        'sollang_m171_s13', 'sollang_m172_s15', 'sollang_m173_s7', 'sollang_m173_s8')
}
foreach ($case in $baselineCases.GetEnumerator()) {
    $llvmPath = Join-Path $root "artifacts/example-tests/stage1-seed-heavy-exact/stage1-seed-heavy-exact-$($case.Key).exe.ll"
    if (-not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
        throw "C457 retained baseline LLVM is missing: $llvmPath"
    }
    $llvm = [IO.File]::ReadAllText($llvmPath)
    $unresolved = @([regex]::Matches($llvm, '(?m)^declare\s+[^\r\n]*?@(?<symbol>sollang_m\d+_s\d+)\(') |
        ForEach-Object { $_.Groups['symbol'].Value } |
        Where-Object { $llvm -match "(?m)\bcall\s+[^`r`n]*?@$([regex]::Escape($_))\(" } |
        Sort-Object -Unique)
    $expected = @($case.Value | Sort-Object)
    if (($unresolved -join ',') -cne ($expected -join ',')) {
        throw "C457 $($case.Key) baseline closure changed: expected=$($expected -join ',') actual=$($unresolved -join ',')"
    }
}

foreach ($llvmPath in $CandidateLlvmPath) {
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $llvmPath
    if ($LASTEXITCODE -ne 0) { throw "C457 candidate direct-call closure failed: $llvmPath" }
}

Write-Host "[C457 nullary enum call closure] PASS resolver=$ExpectedResolverState baseline=3/3 candidate=$($CandidateLlvmPath.Count)/$($CandidateLlvmPath.Count)"
