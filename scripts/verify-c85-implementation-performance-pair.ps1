$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$producer = Join-Path $PSScriptRoot "new-c85-implementation-performance-pair.ps1"
$controlSchema = Join-Path $PSScriptRoot "contracts/c85-per-source-performance-control.schema.json"
$candidateSchema = Join-Path $PSScriptRoot "contracts/selfhost-stage1-generation.schema.json"
$pairSchema = Join-Path $PSScriptRoot "contracts/selfhost-implementation-performance-pair.schema.json"
. (Join-Path $PSScriptRoot "compiler-emission-fingerprint.ps1")

function Resolve-Manifest([string]$Path) {
    @(Get-Content -LiteralPath $Path |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path })
}

$currentSources = @(
    Resolve-Manifest (Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    Resolve-Manifest (Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt")
)
$sourceFingerprint = Get-CompilerEmissionInputFingerprint -RepositoryRoot $repoRoot -Path $currentSources
$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) (
    "sollang-c85-pair-contract-" + [Guid]::NewGuid().ToString("N"))
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$temporaryDirectory = [IO.Path]::GetFullPath($temporaryDirectory)
if (-not $temporaryDirectory.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not [IO.Path]::GetFileName($temporaryDirectory).StartsWith("sollang-c85-pair-contract-", [StringComparison]::Ordinal)) {
    throw "C85 pair contract escaped its owned temporary scope: $temporaryDirectory"
}

try {
    [IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
    $seed = Join-Path $temporaryDirectory "seed.exe"
    $baselineCompiler = Join-Path $temporaryDirectory "baseline.exe"
    $candidateCompiler = Join-Path $temporaryDirectory "candidate.exe"
    $baselineLlvm = Join-Path $temporaryDirectory "baseline.ll"
    $candidateLlvm = Join-Path $temporaryDirectory "candidate.ll"
    $overlay = Join-Path $temporaryDirectory "typed.per-source-control.slg"
    [IO.File]::WriteAllText($seed, "seed")
    [IO.File]::WriteAllText($baselineCompiler, "baseline")
    [IO.File]::WriteAllText($candidateCompiler, "candidate")
    [IO.File]::WriteAllText($overlay, "control")
    $validLlvm = Join-Path $repoRoot "scripts/contracts/fixtures/selfhost-parallel-callback-valid.ll"
    Copy-Item -LiteralPath $validLlvm -Destination $baselineLlvm
    Copy-Item -LiteralPath $validLlvm -Destination $candidateLlvm

    $seedHash = (Get-FileHash -LiteralPath $seed -Algorithm SHA256).Hash
    [IO.File]::WriteAllText([IO.Path]::ChangeExtension($seed, ".sha256"), $seedHash)
    $baselineReceipt = [ordered]@{
        schemaVersion = 1
        mode = "c85-per-source-performance-control"
        seedCompilerFingerprint = $seedHash
        currentSourceFingerprint = $sourceFingerprint
        overlaySourceFingerprint = "A" * 64
        overlayPath = $overlay
        compilerPath = $baselineCompiler
        compilerFingerprint = (Get-FileHash -LiteralPath $baselineCompiler -Algorithm SHA256).Hash
        llvmPath = $baselineLlvm
        llvmFingerprint = (Get-FileHash -LiteralPath $baselineLlvm -Algorithm SHA256).Hash
        dispatch = "per-source"
    }
    $candidateReceipt = [ordered]@{
        schemaVersion = 1
        mode = "verified-selfhost-stage1-generation"
        hostTarget = "windows"
        verificationTarget = "windows"
        optimization = "O1"
        seedMode = "Slg"
        generatedByCompilerFingerprint = $seedHash
        sourceFingerprint = $sourceFingerprint
        compilerPath = $candidateCompiler
        compilerFingerprint = (Get-FileHash -LiteralPath $candidateCompiler -Algorithm SHA256).Hash
        llvmPath = $candidateLlvm
        llvmFingerprint = (Get-FileHash -LiteralPath $candidateLlvm -Algorithm SHA256).Hash
        focusedExecutionVerified = $true
        managedDifferential = $true
    }
    $baselineReceiptPath = Join-Path $temporaryDirectory "baseline.json"
    $candidateReceiptPath = Join-Path $temporaryDirectory "candidate.json"
    $pairPath = Join-Path $temporaryDirectory "pair.json"
    [IO.File]::WriteAllText($baselineReceiptPath, ($baselineReceipt | ConvertTo-Json -Depth 5))
    [IO.File]::WriteAllText($candidateReceiptPath, ($candidateReceipt | ConvertTo-Json -Depth 5))
    if (-not ((Get-Content -Raw $baselineReceiptPath) | Test-Json -SchemaFile $controlSchema) -or
        -not ((Get-Content -Raw $candidateReceiptPath) | Test-Json -SchemaFile $candidateSchema)) {
        throw "C85 pair contract fixture receipt does not match its schema"
    }

    & $producer -BaselineReceipt $baselineReceiptPath -CandidateReceipt $candidateReceiptPath -SeedCompiler $seed -OutputPath $pairPath
    $pairJson = [IO.File]::ReadAllText($pairPath)
    if (-not ($pairJson | Test-Json -SchemaFile $pairSchema -ErrorAction Stop)) {
        throw "C85 pair producer wrote an invalid pair"
    }
    $pair = $pairJson | ConvertFrom-Json
    if ($pair.baseline.dispatch -cne "per-source" -or
        $pair.candidate.dispatch -cne "compiler-wide" -or
        $pair.baseline.generatedByCompilerFingerprint -cne $seedHash -or
        $pair.candidate.generatedByCompilerFingerprint -cne $seedHash) {
        throw "C85 pair producer lost controlled implementation provenance"
    }

    $candidateReceipt.generatedByCompilerFingerprint = "B" * 64
    [IO.File]::WriteAllText($candidateReceiptPath, ($candidateReceipt | ConvertTo-Json -Depth 5))
    $generatorRejected = $false
    try {
        & $producer -BaselineReceipt $baselineReceiptPath -CandidateReceipt $candidateReceiptPath -SeedCompiler $seed -OutputPath $pairPath | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("must share the same receipt-bound seed")) { throw }
        $generatorRejected = $true
    }
    if (-not $generatorRejected) { throw "C85 pair producer accepted a forged candidate generator" }

    $candidateReceipt.generatedByCompilerFingerprint = $seedHash
    $candidateReceipt.sourceFingerprint = "B" * 64
    [IO.File]::WriteAllText($candidateReceiptPath, ($candidateReceipt | ConvertTo-Json -Depth 5))
    $sourceRejected = $false
    try {
        & $producer -BaselineReceipt $baselineReceiptPath -CandidateReceipt $candidateReceiptPath -SeedCompiler $seed -OutputPath $pairPath | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("candidate receipt belongs to another current compiler source set")) { throw }
        $sourceRejected = $true
    }
    if (-not $sourceRejected) { throw "C85 pair producer accepted stale candidate sources" }

    $candidateReceipt.sourceFingerprint = $sourceFingerprint
    $candidateReceipt.managedDifferential = $false
    [IO.File]::WriteAllText($candidateReceiptPath, ($candidateReceipt | ConvertTo-Json -Depth 5))
    $differentialRejected = $false
    try {
        & $producer -BaselineReceipt $baselineReceiptPath -CandidateReceipt $candidateReceiptPath -SeedCompiler $seed -OutputPath $pairPath | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains("does not prove a verified Windows O1 SLG-seed generation")) { throw }
        $differentialRejected = $true
    }
    if (-not $differentialRejected) { throw "C85 pair producer accepted a candidate without managed differential evidence" }
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

Write-Host "[C85 implementation pair contract] PASS same-seed/current-source positive and forged-generator/stale-source/missing-differential negative controls."
