[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$SelfhostCompiler,
    [Parameter(Mandatory)][string]$StreamReceipt,
    [Parameter(Mandatory)][string]$EventStreamReceipt,
    [Parameter(Mandatory)][string]$StructReceipt,
    [Parameter(Mandatory)][string]$AdditionalMoveReceipt,
    [Parameter(Mandatory)][string]$ArrayPushReceipt,
    [Parameter(Mandatory)][string]$DictionaryPutReceipt,
    [Parameter(Mandatory)][string]$AwaitReceipt,
    [Parameter(Mandatory)][string]$ControlReceipt,
    [Parameter(Mandatory)][string]$OutputFile,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-Input([string]$Path) {
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$contractPath = Resolve-Input 'scripts/contracts/c385-affine-name-visibility.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or @($contract.cases).Count -ne 8) { throw 'AFFINE_VISIBILITY_CONTRACT_INVALID' }
$managedPath = Resolve-Input $ManagedCompiler
$selfhostPath = Resolve-Input $SelfhostCompiler
$managedSha = Get-Sha $managedPath
$selfhostSha = Get-Sha $selfhostPath
$receiptPaths = @(
    (Resolve-Input $StreamReceipt),
    (Resolve-Input $EventStreamReceipt),
    (Resolve-Input $StructReceipt),
    (Resolve-Input $AdditionalMoveReceipt),
    (Resolve-Input $ArrayPushReceipt),
    (Resolve-Input $DictionaryPutReceipt),
    (Resolve-Input $AwaitReceipt),
    (Resolve-Input $ControlReceipt)
)
$outputPath = if ([IO.Path]::IsPathRooted($OutputFile)) { [IO.Path]::GetFullPath($OutputFile) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputFile)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "AFFINE_VISIBILITY_OUTPUT_PATH_INVALID: $outputPath"
}
if (Test-Path -LiteralPath $outputPath) { throw "AFFINE_VISIBILITY_RESULT_EXISTS: $outputPath" }
$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "AFFINE_VISIBILITY_OUTPUT_PARENT_MISSING: $parent" }

$cases = [ordered]@{}
$passed = 0
for ($index = 0; $index -lt 8; $index++) {
    $item = $contract.cases[$index]
    $receiptPath = $receiptPaths[$index]
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $sourcePath = Resolve-Input $item.source
    $expectedPath = Resolve-Input $item.expected
    if ($receipt.source -cne $sourcePath -or $receipt.expected -cne $expectedPath -or
        $receipt.sourceSha256 -cne (Get-Sha $sourcePath) -or $receipt.expectedSha256 -cne (Get-Sha $expectedPath) -or
        $receipt.managedCompilerSha256 -cne $managedSha -or $receipt.selfhostCompilerSha256 -cne $selfhostSha) {
        throw "AFFINE_VISIBILITY_INPUT_MISMATCH: $($item.id)"
    }
    $stable = $receipt.inputsStable -and $receipt.inputFingerprintStart -ceq $receipt.inputFingerprintEnd
    $managedRejected = $receipt.managed.nonzeroExit -and $receipt.managed.expectedInStderr -and $receipt.managed.noEmittedProducts
    $selfhostRejected = $receipt.selfhost.nonzeroExit -and $receipt.selfhost.expectedInStderr -and $receipt.selfhost.noEmittedProducts
    $semanticPhase = $true
    if ($item.kind -like 'affine-*') {
        $managedStderr = Get-Content -LiteralPath (Resolve-Input $receipt.logs.managedStderr) -Raw
        $selfhostStderr = Get-Content -LiteralPath (Resolve-Input $receipt.logs.selfhostStderr) -Raw
        $semanticPhase = $managedStderr.Contains('semantic error') -and
            $selfhostStderr.Contains('semantic error') -and
            -not $selfhostStderr.Contains('error[E24]')
    }
    $casePassed = $stable -and $managedRejected -and $selfhostRejected -and $semanticPhase -and $receipt.state -ceq 'passed'
    if ($casePassed) { $passed++ }
    $cases[$item.id] = [ordered]@{
        kind = $item.kind; passed = [bool]$casePassed; inputsStable = [bool]$stable
        managedExpectedDiagnostic = [bool]$receipt.managed.expectedInStderr
        selfhostExpectedDiagnostic = [bool]$receipt.selfhost.expectedInStderr
        managedNoProducts = [bool]$receipt.managed.noEmittedProducts
        selfhostNoProducts = [bool]$receipt.selfhost.noEmittedProducts
        semanticPhase = [bool]$semanticPhase
        receipt = $receiptPath; receiptSha256 = Get-Sha $receiptPath
    }
}
$result = [ordered]@{
    schemaVersion = 1; gate = 'c385-affine-name-visibility'; state = if ($passed -eq 8) { 'passed' } else { 'failed' }
    contract = $contractPath; contractSha256 = Get-Sha $contractPath; verifierSha256 = Get-Sha $PSCommandPath
    managedCompilerSha256 = $managedSha; selfhostCompilerSha256 = $selfhostSha
    passed = $passed; total = 8; cases = $cases
}
[IO.File]::WriteAllText($outputPath, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host "[C385 affine name visibility] $passed/8; result=$outputPath"
if ($passed -ne 8) { throw 'AFFINE_VISIBILITY_DIAGNOSTIC_MISMATCH' }
