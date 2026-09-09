[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineReceipt,
    [Parameter(Mandatory)][string]$CandidateReceipt,
    [Parameter(Mandatory)][string]$SeedCompiler,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "compiler-emission-fingerprint.ps1")
$controlSchema = Join-Path $PSScriptRoot "contracts/c85-per-source-performance-control.schema.json"
$candidateSchema = Join-Path $PSScriptRoot "contracts/selfhost-stage1-generation.schema.json"
$pairSchema = Join-Path $PSScriptRoot "contracts/selfhost-implementation-performance-pair.schema.json"
$callbackVerifier = Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1"

function Resolve-ReceiptPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

$baselineReceiptPath = (Resolve-Path -LiteralPath $BaselineReceipt).Path
$baselineJson = [IO.File]::ReadAllText($baselineReceiptPath)
if (-not ($baselineJson | Test-Json -SchemaFile $controlSchema -ErrorAction Stop)) {
    throw "C85 baseline receipt does not match $controlSchema"
}
$baseline = $baselineJson | ConvertFrom-Json
$baselineCompilerPath = Resolve-ReceiptPath $baseline.compilerPath
$baselineLlvmPath = Resolve-ReceiptPath $baseline.llvmPath
$candidateReceiptPath = (Resolve-Path -LiteralPath $CandidateReceipt).Path
$candidateJson = [IO.File]::ReadAllText($candidateReceiptPath)
if (-not ($candidateJson | Test-Json -SchemaFile $candidateSchema -ErrorAction Stop)) {
    throw "C85 candidate receipt does not match $candidateSchema"
}
$candidate = $candidateJson | ConvertFrom-Json
$candidateCompilerPath = Resolve-ReceiptPath $candidate.compilerPath
$candidateLlvmPath = Resolve-ReceiptPath $candidate.llvmPath
$seedPath = (Resolve-Path -LiteralPath $SeedCompiler).Path
$seedReceiptPath = [IO.Path]::ChangeExtension($seedPath, ".sha256")
if (-not (Test-Path -LiteralPath $seedReceiptPath -PathType Leaf)) {
    throw "C85 pair seed receipt is missing: $seedReceiptPath"
}
$seedHash = (Get-FileHash -LiteralPath $seedPath -Algorithm SHA256).Hash
if ([IO.File]::ReadAllText($seedReceiptPath).Trim() -cne $seedHash -or
    $baseline.seedCompilerFingerprint -cne $seedHash -or
    $candidate.generatedByCompilerFingerprint -cne $seedHash) {
    throw "C85 pair baseline and candidate must share the same receipt-bound seed"
}
if ((Get-FileHash -LiteralPath $baselineCompilerPath -Algorithm SHA256).Hash -cne $baseline.compilerFingerprint -or
    (Get-FileHash -LiteralPath $baselineLlvmPath -Algorithm SHA256).Hash -cne $baseline.llvmFingerprint) {
    throw "C85 baseline compiler or LLVM drifted after its receipt"
}
$candidateCompilerHash = (Get-FileHash -LiteralPath $candidateCompilerPath -Algorithm SHA256).Hash
if ($candidate.hostTarget -cne "windows" -or
    $candidate.verificationTarget -cne "windows" -or
    $candidate.optimization -cne "O1" -or
    $candidate.seedMode -cne "Slg" -or
    -not $candidate.focusedExecutionVerified -or
    -not $candidate.managedDifferential -or
    $candidateCompilerHash -cne $candidate.compilerFingerprint -or
    (Get-FileHash -LiteralPath $candidateLlvmPath -Algorithm SHA256).Hash -cne $candidate.llvmFingerprint) {
    throw "C85 candidate receipt does not prove a verified Windows O1 SLG-seed generation"
}
if ($candidateCompilerHash -ceq $baseline.compilerFingerprint) {
    throw "C85 baseline and candidate compiler fingerprints are identical"
}

function Resolve-Manifest([string]$Path) {
    @(Get-Content -LiteralPath $Path |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path })
}
$currentSources = @(
    Resolve-Manifest (Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    Resolve-Manifest (Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt")
)
$currentSourceFingerprint = Get-CompilerEmissionInputFingerprint `
    -RepositoryRoot $repoRoot -Path $currentSources
if ($currentSourceFingerprint -cne $baseline.currentSourceFingerprint) {
    throw "C85 baseline receipt belongs to another current compiler source set"
}
if ($currentSourceFingerprint -cne $candidate.sourceFingerprint) {
    throw "C85 candidate receipt belongs to another current compiler source set"
}

$baselineCallbacks = & $callbackVerifier -LlvmPath $baselineLlvmPath -MinimumCallbackCount 4 -RequireNominalTransfer -PassThru
$candidateCallbacks = & $callbackVerifier -LlvmPath $candidateLlvmPath -MinimumCallbackCount 4 -RequireNominalTransfer -PassThru
$artifact = {
    param($compilerPath, $compilerHash, $llvmPath, $callbacks, $dispatch)
    [ordered]@{
        compilerPath = [IO.Path]::GetRelativePath($repoRoot, $compilerPath).Replace('\', '/')
        compilerFingerprint = $compilerHash
        llvmPath = [IO.Path]::GetRelativePath($repoRoot, $llvmPath).Replace('\', '/')
        llvmFingerprint = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
        generatedByCompilerFingerprint = $seedHash
        optimization = "O1"
        parallelCallbackCount = $callbacks.CallbackCount
        nominalTransferCallbackCount = $callbacks.NominalTransferCallbackCount
        dispatch = $dispatch
    }
}
$pair = [ordered]@{
    schemaVersion = 1
    mode = "controlled-implementation-performance-pair"
    target = "windows"
    sourceFingerprint = $currentSourceFingerprint
    baseline = & $artifact $baselineCompilerPath $baseline.compilerFingerprint $baselineLlvmPath $baselineCallbacks "per-source"
    candidate = & $artifact $candidateCompilerPath $candidateCompilerHash $candidateLlvmPath $candidateCallbacks "compiler-wide"
}
$pairJson = ($pair | ConvertTo-Json -Depth 5) + "`n"
if (-not ($pairJson | Test-Json -SchemaFile $pairSchema -ErrorAction Stop)) {
    throw "C85 implementation pair does not match $pairSchema"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "artifacts/c85-implementation-performance-pair.json"
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.Directory]::CreateDirectory((Split-Path -Parent $resolvedOutput)) | Out-Null
[IO.File]::WriteAllText($resolvedOutput, $pairJson, [Text.UTF8Encoding]::new($false))
Write-Host "[C85 implementation pair] PASS $resolvedOutput"
