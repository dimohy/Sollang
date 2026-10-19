[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AbiResultPath,
    [Parameter(Mandatory)][string]$AbiResultSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Resolve-UnderRoot([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path, $root)
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "BOUNDED_OWNERSHIP_PATH_OUTSIDE_REPOSITORY: $full"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "BOUNDED_OWNERSHIP_INPUT_MISSING: $full"
    }
    return $full
}
function Assert-Match([string]$InputText, [string]$Pattern, [string]$FailureId) {
    $match = [regex]::Match($InputText, $Pattern)
    if (-not $match.Success) { throw $FailureId }
    return $match
}
function Function-Body([string]$Llvm, [string]$HeaderPattern, [string]$FailureId) {
    (Assert-Match $Llvm "(?ms)^define [^`r`n]*$HeaderPattern[^`r`n]*\{\r?\n.*?^\}" $FailureId).Value
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path.TrimEnd('\', '/')
$abiPath = Resolve-UnderRoot $AbiResultPath
if ((Sha $abiPath) -cne $AbiResultSha256) { throw 'BOUNDED_OWNERSHIP_ABI_SHA_MISMATCH' }
$abi = Get-Content -LiteralPath $abiPath -Raw | ConvertFrom-Json
if ($abi.state -cne 'passed' -or $abi.passed -ne 18 -or $abi.total -ne 18 -or
    $abi.inputsStable -ne $true -or $abi.inputFingerprintStart -cne $abi.inputFingerprintEnd -or
    @($abi.orphanProcessIds).Count -ne 0 -or $abi.historicalBaselineReexecuted -ne $false) {
    throw 'BOUNDED_OWNERSHIP_ABI_NOT_PROVEN'
}
$selfhostCase = @($abi.cases | Where-Object { $_.compiler -ceq 'selfhost' -and $_.fixture -ceq 'direct-populated' })
$managedCase = @($abi.cases | Where-Object { $_.compiler -ceq 'managed' -and $_.fixture -ceq 'readonly-parameter-baseline' })
if ($selfhostCase.Count -ne 1 -or $managedCase.Count -ne 1 -or
    $selfhostCase[0].state -cne 'passed' -or $managedCase[0].state -cne 'passed') {
    throw 'BOUNDED_OWNERSHIP_CASE_MISSING'
}
$selfhostLl = Resolve-UnderRoot (Join-Path $selfhostCase[0].caseDirectory 'probe.exe.ll')
$managedLl = Resolve-UnderRoot (Join-Path $managedCase[0].caseDirectory 'probe.ll')
if ((Sha $selfhostLl) -cne $selfhostCase[0].llvmSha256 -or
    (Sha $managedLl) -cne $managedCase[0].llvmSha256) {
    throw 'BOUNDED_OWNERSHIP_LLVM_SHA_MISMATCH'
}
$inputs = @($PSCommandPath, $abiPath, $selfhostLl, $managedLl)
$inputStart = (@($inputs | ForEach-Object { "$_|$(Sha $_)" }) -join "`n")
$fingerprintStart = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
    [Text.Encoding]::UTF8.GetBytes($inputStart)))

$selfhostText = [IO.File]::ReadAllText($selfhostLl)
$managedText = [IO.File]::ReadAllText($managedLl)
$returnBody = Function-Body $selfhostText '%sollang\.bounded_dictionary\.[A-Za-z0-9_]+ @[A-Za-z0-9_]+\(\)' 'BOUNDED_OWNERSHIP_RETURN_FUNCTION_MISSING'
$owner = (Assert-Match $returnBody '(?m)^\s*(?<owner>%[A-Za-z0-9_]+) = alloca %sollang\.bounded_dictionary\.[A-Za-z0-9_]+' 'BOUNDED_OWNERSHIP_RETURN_OWNER_MISSING').Groups['owner'].Value
$escapedOwner = [regex]::Escape($owner)
[void](Assert-Match $returnBody "(?m)^\s*%[A-Za-z0-9_]+ = getelementptr [^`r`n]*ptr $escapedOwner," 'BOUNDED_OWNERSHIP_INLINE_STORAGE_MISSING')
$returned = (Assert-Match $returnBody "(?m)^\s*(?<value>%[A-Za-z0-9_]+) = load %sollang\.bounded_dictionary\.[A-Za-z0-9_]+, ptr $escapedOwner," 'BOUNDED_OWNERSHIP_AGGREGATE_LOAD_MISSING').Groups['value'].Value
[void](Assert-Match $returnBody "(?m)^\s*ret %sollang\.bounded_dictionary\.[A-Za-z0-9_]+ $([regex]::Escape($returned))\s*$" 'BOUNDED_OWNERSHIP_RETURN_VALUE_MISMATCH')
$selfhostMain = Function-Body $selfhostText 'i32 @main\(\)' 'BOUNDED_OWNERSHIP_SELFHOST_CALLER_MISSING'
[void](Assert-Match $selfhostMain '(?m)^\s*%[A-Za-z0-9_]+ = call %sollang\.bounded_dictionary\.[A-Za-z0-9_]+ @' 'BOUNDED_OWNERSHIP_RETURN_CALL_MISSING')
[void](Assert-Match $selfhostMain '(?m)^\s*store %sollang\.bounded_dictionary\.[A-Za-z0-9_]+ %[A-Za-z0-9_]+, ptr %[A-Za-z0-9_]+' 'BOUNDED_OWNERSHIP_CALLER_STORE_MISSING')

$readBody = Function-Body $managedText 'i32 @sollang_fn_readValue\(' 'BOUNDED_OWNERSHIP_READ_FUNCTION_MISSING'
[void](Assert-Match $readBody '(?m)^\s*%[A-Za-z0-9_]+ = extractvalue %sollang\.int_dictionary %it, 0' 'BOUNDED_OWNERSHIP_BORROWED_POINTER_MISSING')
[void](Assert-Match $readBody '(?m)^\s*%[A-Za-z0-9_]+ = load i32, ptr %[A-Za-z0-9_]+' 'BOUNDED_OWNERSHIP_READ_MISSING')
if ($readBody -match '@(?:sollang_free|sollang_drop_[A-Za-z0-9_]+)\(') {
    throw 'BOUNDED_OWNERSHIP_CALLEE_FREES_BORROW'
}
$managedMain = Function-Body $managedText 'i32 @sollang_start\(\)' 'BOUNDED_OWNERSHIP_MANAGED_CALLER_MISSING'
$callerOwner = (Assert-Match $managedMain '(?m)^\s*(?<owner>%[A-Za-z0-9_]+) = alloca %sollang\.bounded_dictionary\.[A-Za-z0-9_]+' 'BOUNDED_OWNERSHIP_CALLER_OWNER_MISSING').Groups['owner'].Value
$callerData = (Assert-Match $managedMain "(?m)^\s*(?<data>%[A-Za-z0-9_]+) = getelementptr [^`r`n]*ptr $([regex]::Escape($callerOwner))," 'BOUNDED_OWNERSHIP_CALLER_INLINE_DATA_MISSING').Groups['data'].Value
[void](Assert-Match $managedMain "(?m)^\s*%[A-Za-z0-9_]+ = insertvalue %sollang\.int_dictionary poison, ptr $([regex]::Escape($callerData)), 0" 'BOUNDED_OWNERSHIP_CALLER_BORROW_MISSING')
[void](Assert-Match $managedMain '(?m)^\s*%[A-Za-z0-9_]+ = call i32 @sollang_fn_readValue\(' 'BOUNDED_OWNERSHIP_READ_CALL_MISSING')
if ($managedMain -match '@(?:sollang_free|sollang_drop_[A-Za-z0-9_]+)\(') {
    throw 'BOUNDED_OWNERSHIP_CALLER_FREES_INLINE_STORAGE'
}

$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)) {
    throw 'BOUNDED_OWNERSHIP_OUTPUT_INVALID'
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$inputEnd = (@($inputs | ForEach-Object { "$_|$(Sha $_)" }) -join "`n")
$fingerprintEnd = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
    [Text.Encoding]::UTF8.GetBytes($inputEnd)))
if ($fingerprintStart -cne $fingerprintEnd) { throw 'BOUNDED_OWNERSHIP_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1
    gate = 'bounded-dictionary-llvm-ownership'
    state = 'passed'
    proofScope = 'focused current-source LLVM: selfhost aggregate return has caller-owned value storage; managed readonly callee and caller contain no direct free or drop of inline storage; transitive lifetime is not proven'
    abiResultPath = $abiPath
    abiResultSha256 = $AbiResultSha256
    selfhostLlvmPath = $selfhostLl
    selfhostLlvmSha256 = Sha $selfhostLl
    managedLlvmPath = $managedLl
    managedLlvmSha256 = Sha $managedLl
    inputFingerprintStart = $fingerprintStart
    inputFingerprintEnd = $fingerprintEnd
    inputsStable = $true
    checksPassed = 2
    checksTotal = 2
}
$json = $record | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $output 'result.json'), $json, [Text.UTF8Encoding]::new($false))
Write-Host "[bounded dictionary LLVM ownership] PASS 2/2 focused scopes; $output\result.json"
