[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CsvLlvmPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$helper = Join-Path $root 'scripts/llvm-no-allocation-audit.ps1'
$contractPath = Join-Path $root 'scripts/contracts/llvm-no-allocation-audit.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.cases.Count -ne 14 -or
    $contract.additionalCallBoundaryCases.Count -ne 3 -or $contract.deniedEvenWhenAllowlisted.Count -ne 10) {
    throw 'LLVM no-allocation audit contract dimensions drifted'
}
$output = Join-Path $root ('artifacts/scratch/llvm-no-allocation-audit-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$result = [ordered]@{
    schemaVersion = 1; scope = $contract.scope; status = 'running'
    completed = 0; total = 27; checks = @()
    contractSha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash
    helperSha256 = (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash
    verifierSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
}
function Complete-Case([string]$Name) { $result.completed++; $result.checks += $Name }
try {
    . $helper
    foreach ($case in @($contract.cases) + @($contract.additionalCallBoundaryCases)) {
        $errorCode = if ($case.PSObject.Properties.Name -contains 'error') { $case.error } else { $null }
        $caught = $null
        $actual = $null
        try {
            $actual = Assert-LlvmNoAllocation -LlvmText $case.llvm -RootSymbolPattern $contract.rootSymbolPattern -AllowedExternalSymbols $case.allowed
        } catch { $caught = $_.Exception.Message }
        if ($null -ne $errorCode) {
            if ($null -eq $caught -or -not $caught.StartsWith($errorCode + ':', [StringComparison]::Ordinal)) {
                throw "audit negative $($case.name) expected $errorCode, observed $caught"
            }
        } elseif ($null -ne $caught -or $actual.ReachableBodyCount -ne $case.reachable -or $actual.DirectCallCount -ne $case.calls) {
            throw "audit positive $($case.name) failed: $caught"
        }
        Complete-Case $case.name
    }
    foreach ($name in $contract.deniedEvenWhenAllowlisted) {
        $llvm = "declare ptr @$name(i64)`ndefine void @root() {`n  %p = call ptr @$name(i64 8)`n  ret void`n}`n"
        $rejected = $false
        try { Assert-LlvmNoAllocation -LlvmText $llvm -RootSymbolPattern '^root$' -AllowedExternalSymbols @($name) | Out-Null }
        catch {
            if (-not $_.Exception.Message.StartsWith('LLVM_NO_ALLOCATION_ALLOCATOR:', [StringComparison]::Ordinal)) { throw }
            $rejected = $true
        }
        if (-not $rejected) { throw "allowlisted allocator accepted: $name" }
        Complete-Case "deny-allowlisted-$name"
    }
    if ($CsvLlvmPath) {
        $csvPath = [IO.Path]::GetFullPath($CsvLlvmPath, $root)
        $before = (Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash
        $result.csv = Assert-LlvmNoAllocation -LlvmText (Get-Content -LiteralPath $csvPath -Raw) -RootSymbolPattern '^sollang_fn_std_text_csv_' -AllowedExternalSymbols @('GetStdHandle', 'WriteFile', 'llvm.trap')
        $result.csvLlvmPath = $csvPath
        $result.csvLlvmSha256 = $before
        if ((Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash -cne $before) { throw 'CSV LLVM changed during read-only audit' }
    }
    if ($result.completed -ne $result.total) { throw 'LLVM no-allocation audit count drifted' }
    foreach ($taskInput in @(@($helper, $result.helperSha256), @($contractPath, $result.contractSha256), @($PSCommandPath, $result.verifierSha256))) {
        if ((Get-FileHash -LiteralPath $taskInput[0] -Algorithm SHA256).Hash -cne $taskInput[1]) { throw "audit input changed: $($taskInput[0])" }
    }
    $result.status = 'passed'
} catch {
    $result.status = 'failed'; $result.failure = $_.Exception.Message; throw
} finally {
    [IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 6) + "`n"))
}
Write-Host "[LLVM no-allocation audit] PASS $($result.completed)/$($result.total); $resultPath"
