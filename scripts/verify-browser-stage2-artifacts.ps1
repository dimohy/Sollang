[CmdletBinding()]
param(
    [string]$Stage2Compiler = "artifacts\example-tests\selfhost-stage2.exe",
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "browser-stage2-input-fingerprint.ps1")

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$stage2InputPath = if ([System.IO.Path]::IsPathRooted($Stage2Compiler)) {
    $Stage2Compiler
} else {
    Join-Path $root $Stage2Compiler
}
$stage2Path = (Resolve-Path $stage2InputPath).Path
$manifestPath = Join-Path $root "selfhost\browser_driver.sources.txt"
$buildScriptPath = Join-Path $PSScriptRoot "build-stage2-browser.ps1"
$llvmRoot = Join-Path $root ".tools\llvm-22.1.8"
$llvmAsPath = Join-Path $llvmRoot "bin\llvm-as.exe"
$clangPath = Join-Path $llvmRoot "bin\clang.exe"
$wasmLdPath = Join-Path $llvmRoot "bin\wasm-ld.exe"
$compilerLlvmPath = Join-Path $root "artifacts\sollangc-browser-stage2.ll"
$compilerBitcodePath = Join-Path $root "artifacts\sollangc-browser-stage2.bc"
$compilerObjectPath = Join-Path $root "artifacts\sollangc-browser-stage2.o"
$compilerWasmPath = Join-Path $root "artifacts\sollangc-browser.wasm"
$inputFingerprintPath = Join-Path $root "artifacts\sollangc-browser.inputs.sha256"
$outputRecordPath = Join-Path $root "artifacts\sollangc-browser.outputs.sha256"
$publicCompilerPath = Join-Path $root "public\sollangc-stage2-0.4.260817.wasm"

$stage2FileName = [System.IO.Path]::GetFileNameWithoutExtension($stage2Path)
if (-not $stage2FileName.Contains("stage2", [System.StringComparison]::Ordinal)) {
    throw "browser compiler input must identify a verified Stage2 artifact: $stage2Path"
}
$stage3FileName = $stage2FileName.Replace("stage2", "stage3", [System.StringComparison]::Ordinal)
$stage3Path = Join-Path `
    ([System.IO.Path]::GetDirectoryName($stage2Path)) `
    ($stage3FileName + [System.IO.Path]::GetExtension($stage2Path))
& (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
    -Platform windows `
    -Stage3Path $stage3Path `
    -RepositoryRoot $root

if (-not (Test-Stage2ArtifactReceipt `
        -LlvmPath $compilerLlvmPath `
        -BitcodePath $compilerBitcodePath `
        -ExecutablePath $compilerWasmPath `
        -AdditionalArtifacts @{ object = $compilerObjectPath } `
        -ReceiptPath $outputRecordPath)) {
    throw "browser Stage2 artifacts are missing or differ from their integrity record"
}
if (-not (Test-Path -LiteralPath $inputFingerprintPath -PathType Leaf)) {
    throw "browser Stage2 input fingerprint record is missing: $inputFingerprintPath"
}
$currentInputFingerprint = Get-BrowserStage2InputFingerprint `
    -RepositoryRoot $root `
    -Stage2Path $stage2Path `
    -ManifestPath $manifestPath `
    -BuildScriptPath $buildScriptPath `
    -LlvmAsPath $llvmAsPath `
    -ClangPath $clangPath `
    -WasmLdPath $wasmLdPath
$recordedInputFingerprint = [System.IO.File]::ReadAllText($inputFingerprintPath).Trim()
if ($recordedInputFingerprint -cne $currentInputFingerprint) {
    throw "browser Stage2 input fingerprint is stale: expected $currentInputFingerprint, recorded $recordedInputFingerprint"
}
if (-not (Test-Path -LiteralPath $publicCompilerPath -PathType Leaf)) {
    throw "published browser compiler is missing: $publicCompilerPath"
}
$verifiedWasmHash = (Get-FileHash -LiteralPath $compilerWasmPath -Algorithm SHA256).Hash
$publicWasmHash = (Get-FileHash -LiteralPath $publicCompilerPath -Algorithm SHA256).Hash
if ($publicWasmHash -cne $verifiedWasmHash) {
    throw "published browser compiler differs from the verified Stage2 artifact"
}

Write-Host "[browser Stage2 artifacts] PASS input $currentInputFingerprint; WASM $verifiedWasmHash."
