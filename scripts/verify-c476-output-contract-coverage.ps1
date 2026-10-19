[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FocusedReceipt,
    [Parameter(Mandatory)][string]$LinkerReceipt,
    [Parameter(Mandatory)][string]$ConcurrencyReceipt,
    [Parameter(Mandatory)][string]$StageCleanupReceipt,
    [Parameter(Mandatory)][string]$PublicationReceipt,
    [Parameter(Mandatory)][string]$EmitterReceipt,
    [Parameter(Mandatory)][string]$SpawnReceipt,
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
function Assert-Case([bool]$Condition, [string]$Name) { if (-not $Condition) { throw "OUTPUT_COVERAGE_CASE_INVALID: $Name" } }

$contractPath = Resolve-Input 'scripts/contracts/c476-output-transaction.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$contractNames = @($contract.scenarios.PSObject.Properties.Name)
if ($contractNames.Count -ne 13) { throw 'OUTPUT_COVERAGE_CONTRACT_INVALID' }
$paths = [ordered]@{
    focused = Resolve-Input $FocusedReceipt
    linker = Resolve-Input $LinkerReceipt
    concurrency = Resolve-Input $ConcurrencyReceipt
    stageCleanup = Resolve-Input $StageCleanupReceipt
    publication = Resolve-Input $PublicationReceipt
    emitter = Resolve-Input $EmitterReceipt
    spawn = Resolve-Input $SpawnReceipt
}
$receipts = [ordered]@{}
foreach ($key in $paths.Keys) { $receipts[$key] = Get-Content -LiteralPath $paths[$key] -Raw | ConvertFrom-Json }
$focused = $receipts.focused
$linker = $receipts.linker
$concurrency = $receipts.concurrency
$cleanup = $receipts.stageCleanup
$publication = $receipts.publication
$emitter = $receipts.emitter
$spawn = $receipts.spawn
$compilerSha = $focused.compilerSha256
$contractSha = Get-Sha $contractPath
Assert-Case ($focused.state -ceq 'focused-passed' -and $focused.focusedPassed -eq 4 -and $focused.inputsStable -and $focused.contractSha256 -ceq $contractSha) 'focused'
$commonNativeInput = $linker.inputHashesStart.commonNativeInput
foreach ($key in @('linker', 'concurrency', 'publication', 'emitter', 'spawn')) {
    $receipt = $receipts[$key]
    $inputsStable = if ($key -ceq 'linker') { $receipt.inputStable } else { $receipt.inputsStable }
    Assert-Case ($receipt.state -ceq 'passed' -and $inputsStable -and
        $receipt.compilerSha256 -ceq $compilerSha -and $receipt.inputHashesStart.contract -ceq $contractSha -and
        $receipt.inputHashesStart.commonNativeInput -ceq $commonNativeInput) $key
}
Assert-Case ($cleanup.state -ceq 'passed' -and $cleanup.passed -eq 1 -and $cleanup.total -eq 1 -and
    $cleanup.compilerSha256 -ceq $compilerSha -and $cleanup.contractSha256 -ceq $contractSha -and
    $cleanup.nativeCommonInputFingerprint -ceq $commonNativeInput -and $cleanup.stageResidueCount -eq 0 -and
    $cleanup.scenariosAudited -eq 8 -and $cleanup.differentOutputBothCompleted) 'stageCleanup'
foreach ($pair in @(
    @{ Key = 'focusedReceiptSha256'; Path = $paths.focused },
    @{ Key = 'linkerReceiptSha256'; Path = $paths.linker },
    @{ Key = 'concurrencyReceiptSha256'; Path = $paths.concurrency }
)) { Assert-Case ($cleanup.($pair.Key) -ceq (Get-Sha $pair.Path)) "stageCleanup.$($pair.Key)" }

$caseEvidence = [ordered]@{}
foreach ($name in @('semanticFailureFresh', 'existingSentinelSemanticFailure', 'successKeepTempsOn', 'successKeepTempsOff')) {
    $case = $focused.scenarios.$name
    Assert-Case ($case.state -ceq 'passed' -and $case.assertionsPassed) $name
    $caseEvidence[$name] = 'focused'
}
foreach ($name in @('linkerFailureFresh', 'existingSentinelLinkerFailure')) {
    $case = $linker.cases.$name
    Assert-Case ($case.state -ceq 'passed' -and $case.exitCode -ne 0 -and $case.existingFilesPreserved -and $case.diagnosticPresent) $name
    $caseEvidence[$name] = 'linker'
}
foreach ($name in @('sameOutputParallel', 'differentOutputParallel')) {
    $case = $concurrency.cases.$name
    Assert-Case ($case.state -ceq 'passed' -and $case.overlapObserved) $name
    $caseEvidence[$name] = 'concurrency'
}
Assert-Case ($publication.passed -eq 1 -and $publication.total -eq 1 -and $publication.case.state -ceq 'passed' -and
    $publication.case.exitCode -ne 0 -and $publication.case.existingExecutablePreserved -and
    $publication.case.existingLlvmPreserved -and $publication.case.diagnosticPresent) 'publicationFailure'
$caseEvidence.publicationFailure = 'publication'
foreach ($name in @('emitterFailureFresh', 'existingSentinelEmitterFailure')) {
    $case = $emitter.cases.$name
    Assert-Case ($case.state -ceq 'passed' -and $case.exitCode -ne 0 -and $case.existingFilesPreserved -and $case.diagnosticPresent) $name
    $caseEvidence[$name] = 'emitter'
}
Assert-Case ($spawn.passed -eq 1 -and $spawn.total -eq 1 -and $spawn.case.state -ceq 'passed' -and
    $spawn.case.exitCode -ne 0 -and $spawn.case.diagnosticPresent -and @($spawn.case.artifactNames).Count -eq 0) 'spawnFailure'
$caseEvidence.spawnFailure = 'spawn'
Assert-Case ($caseEvidence.Count -eq 12) 'twelve-direct-scenarios'
$caseEvidence.stageCleanup = 'stageCleanup'
Assert-Case ($caseEvidence.Count -eq 13 -and @($caseEvidence.Keys | Where-Object { $contractNames -cnotcontains $_ }).Count -eq 0 -and
    @($contractNames | Where-Object { -not $caseEvidence.Contains($_) }).Count -eq 0) 'thirteen-exact-contract-scenarios'

$outputPath = if ([IO.Path]::IsPathRooted($OutputFile)) { [IO.Path]::GetFullPath($OutputFile) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputFile)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_COVERAGE_PATH_INVALID' }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_COVERAGE_RESULT_EXISTS: $outputPath" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)) { throw 'OUTPUT_COVERAGE_PARENT_MISSING' }
$receiptHashes = [ordered]@{}
foreach ($key in $paths.Keys) { $receiptHashes[$key] = Get-Sha $paths[$key] }
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-contract-coverage'; state = 'passed'
    scope = 'seven stable receipts on one selfhost compiler and one frozen contract; unified execution runner remains pending'
    compilerSha256 = $compilerSha; contractSha256 = $contractSha; nativeCommonInputFingerprint = $commonNativeInput
    verifierSha256 = Get-Sha $PSCommandPath; receiptHashes = $receiptHashes
    passed = 13; total = 13; cases = $caseEvidence
}
[IO.File]::WriteAllText($outputPath, ($result | ConvertTo-Json -Depth 7), [Text.UTF8Encoding]::new($false))
Write-Host "[C476 contract coverage] 13/13 passed; $outputPath"
