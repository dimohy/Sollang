[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FocusedReceipt,
    [Parameter(Mandatory)][string]$LinkerReceipt,
    [Parameter(Mandatory)][string]$ConcurrencyReceipt,
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
function Assert-Names([string]$Directory, [string[]]$Expected) {
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { throw "OUTPUT_STAGE_CASE_MISSING: $Directory" }
    $actual = @([IO.Directory]::GetFileSystemEntries($Directory) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
    $sorted = @($Expected | Sort-Object)
    if (($actual -join '|') -cne ($sorted -join '|')) { throw "OUTPUT_STAGE_RESIDUE: $Directory actual=$($actual -join ',') expected=$($sorted -join ',')" }
    foreach ($name in $actual) {
        $path = Join-Path $Directory $name
        if ((Get-Item -LiteralPath $path).Length -eq 0) { throw "OUTPUT_STAGE_EMPTY_FINAL: $path" }
    }
    return $actual
}

$focusedPath = Resolve-Input $FocusedReceipt
$linkerPath = Resolve-Input $LinkerReceipt
$concurrencyPath = Resolve-Input $ConcurrencyReceipt
$contractPath = Resolve-Input 'scripts/contracts/c476-output-transaction.json'
$focused = Get-Content -LiteralPath $focusedPath -Raw | ConvertFrom-Json
$linker = Get-Content -LiteralPath $linkerPath -Raw | ConvertFrom-Json
$concurrency = Get-Content -LiteralPath $concurrencyPath -Raw | ConvertFrom-Json
$compilerSha = $focused.compilerSha256
$contractSha = Get-Sha $contractPath
if ($focused.state -cne 'focused-passed' -or $focused.focusedPassed -ne 4 -or -not $focused.inputsStable -or
    $linker.state -cne 'passed' -or $linker.passed -ne 2 -or -not $linker.inputStable -or
    $concurrency.state -cne 'passed' -or $concurrency.passed -ne 2 -or -not $concurrency.inputsStable -or
    $compilerSha -cne $linker.compilerSha256 -or $compilerSha -cne $concurrency.compilerSha256 -or
    $contractSha -cne $focused.contractSha256 -or $contractSha -cne $linker.inputHashesStart.contract -or
    $contractSha -cne $concurrency.inputHashesStart.contract -or
    $linker.inputHashesStart.commonNativeInput -cne $concurrency.inputHashesStart.commonNativeInput) {
    throw 'OUTPUT_STAGE_INPUT_OR_GATE_MISMATCH'
}
$outputPath = if ([IO.Path]::IsPathRooted($OutputFile)) { [IO.Path]::GetFullPath($OutputFile) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputFile)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_STAGE_RESULT_PATH_INVALID' }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_STAGE_RESULT_EXISTS: $outputPath" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)) { throw 'OUTPUT_STAGE_RESULT_PARENT_MISSING' }

$surfaces = [ordered]@{}
$focusedRoot = Split-Path -Parent $focusedPath
foreach ($case in @(
    @{ Name = 'semanticFailureFresh'; Expected = @() },
    @{ Name = 'existingSentinelSemanticFailure'; Expected = @('probe.exe', 'probe.exe.ll') },
    @{ Name = 'successKeepTempsOn'; Expected = @('probe.exe', 'probe.exe.ll') },
    @{ Name = 'successKeepTempsOff'; Expected = @('probe.exe') }
)) {
    $dir = Join-Path (Join-Path $focusedRoot $case.Name) 'artifacts'
    $surfaces[$case.Name] = @(Assert-Names $dir $case.Expected)
}
$linkerRoot = Split-Path -Parent $linkerPath
foreach ($case in @(
    @{ Name = 'linkerFailureFresh'; Expected = @() },
    @{ Name = 'existingSentinelLinkerFailure'; Expected = @('probe.exe', 'probe.exe.ll') }
)) {
    $dir = Join-Path (Join-Path $linkerRoot $case.Name) 'artifacts'
    $surfaces[$case.Name] = @(Assert-Names $dir $case.Expected)
}
$concurrencyRoot = Split-Path -Parent $concurrencyPath
$surfaces.sameOutputParallel = @(Assert-Names (Join-Path $concurrencyRoot 'sameOutputParallel/artifacts') @('probe.exe', 'probe.exe.ll'))
$surfaces.differentOutputParallel = @(Assert-Names (Join-Path $concurrencyRoot 'differentOutputParallel/artifacts') @('a.exe', 'a.exe.ll', 'b.exe', 'b.exe.ll'))
$differentDir = Join-Path $concurrencyRoot 'differentOutputParallel'
if ([IO.File]::ReadAllText((Join-Path $differentDir 'a.native.stdout.txt')) -cne "C476-A`n" -or
    [IO.File]::ReadAllText((Join-Path $differentDir 'b.native.stdout.txt')) -cne "C476-B`n" -or
    -not $concurrency.cases.differentOutputParallel.overlapObserved) {
    throw 'OUTPUT_STAGE_CROSS_INVOCATION_FAILURE'
}
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-stage-cleanup'; state = 'passed'
    compilerSha256 = $compilerSha; contractSha256 = $contractSha; verifierSha256 = Get-Sha $PSCommandPath
    focusedReceiptSha256 = Get-Sha $focusedPath; linkerReceiptSha256 = Get-Sha $linkerPath
    concurrencyReceiptSha256 = Get-Sha $concurrencyPath
    nativeCommonInputFingerprint = $linker.inputHashesStart.commonNativeInput
    scenariosAudited = 8; stageResidueCount = 0; differentOutputBothCompleted = $true
    passed = 1; total = 1; surfaces = $surfaces
}
[IO.File]::WriteAllText($outputPath, ($result | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
Write-Host "[C476 stage cleanup] 1/1 passed; $outputPath"
