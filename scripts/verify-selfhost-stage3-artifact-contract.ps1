$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("sollang-stage3-artifact-contract-" + [guid]::NewGuid().ToString("N"))))
$systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
if (-not $temporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Stage3 artifact contract temp path escaped the system temp directory: $temporaryRoot"
}

function Get-ProbeInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][string]$Stage2Path,
        [Parameter(Mandatory)][string[]]$SourcePaths
    )

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    foreach ($path in $SourcePaths) {
        $relative = [System.IO.Path]::GetRelativePath($temporaryRoot, $path).Replace("\", "/")
        $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$relative`0"))
        $hash.AppendData([System.IO.File]::ReadAllBytes($path))
    }
    $sourceFingerprint = [Convert]::ToHexString($hash.GetHashAndReset())
    $stage2Hash = (Get-FileHash -LiteralPath $Stage2Path -Algorithm SHA256).Hash
    $text = "$Platform`0$stage2Hash`0$sourceFingerprint"
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes($text)))
}

try {
    $fixtureDirectory = Join-Path $temporaryRoot "tests\Sollang.ExampleTests\Fixtures"
    $sourceDirectory = Join-Path $temporaryRoot "compiler"
    $artifactDirectory = Join-Path $temporaryRoot "artifacts"
    New-Item -ItemType Directory -Force -Path $fixtureDirectory, $sourceDirectory, $artifactDirectory | Out-Null
    $compilerSource = Join-Path $sourceDirectory "main.slg"
    $runtimeSource = Join-Path $sourceDirectory "runtime.slg"
    [System.IO.File]::WriteAllText($compilerSource, "compiler")
    [System.IO.File]::WriteAllText($runtimeSource, "runtime")
    [System.IO.File]::WriteAllText(
        (Join-Path $fixtureDirectory "selfhost-sollangc-driver.sources.txt"),
        "compiler/main.slg`n")
    [System.IO.File]::WriteAllText(
        (Join-Path $fixtureDirectory "selfhost-compiler-runtime.sources.txt"),
        "compiler/runtime.slg`n")
    $sourcePaths = @($compilerSource, $runtimeSource)

    $stage2Path = Join-Path $artifactDirectory "selfhost-stage2-linux"
    $stage2LlvmPath = Join-Path $artifactDirectory "selfhost-stage2-linux.ll"
    $stage2BitcodePath = Join-Path $artifactDirectory "selfhost-stage2-linux.bc"
    $stage2ObjectPath = Join-Path $artifactDirectory "selfhost-stage2-linux.o"
    $stage2OutputReceiptPath = Join-Path $artifactDirectory "selfhost-stage2-linux.outputs.sha256"
    $stage3Path = Join-Path $artifactDirectory "selfhost-stage3-linux"
    $stage3LlvmPath = Join-Path $artifactDirectory "selfhost-stage3-linux.ll"
    $stage3BitcodePath = Join-Path $artifactDirectory "selfhost-stage3-linux.bc"
    $stage3ObjectPath = Join-Path $artifactDirectory "selfhost-stage3-linux.o"
    $stage3InputReceiptPath = Join-Path $artifactDirectory "selfhost-stage3-linux.inputs.sha256"
    $stage3OutputReceiptPath = Join-Path $artifactDirectory "selfhost-stage3-linux.outputs.sha256"
    [System.IO.File]::WriteAllText($stage2Path, "stage2")
    [System.IO.File]::WriteAllText($stage2LlvmPath, "llvm")
    [System.IO.File]::WriteAllText($stage2BitcodePath, "stage2-bitcode")
    [System.IO.File]::WriteAllText($stage2ObjectPath, "stage2-object")
    [System.IO.File]::WriteAllText($stage3Path, "stage3")
    [System.IO.File]::WriteAllText($stage3LlvmPath, "llvm")
    [System.IO.File]::WriteAllText($stage3BitcodePath, "bitcode")
    [System.IO.File]::WriteAllText($stage3ObjectPath, "object")
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -AdditionalArtifacts @{ object = $stage2ObjectPath } `
        -ReceiptPath $stage2OutputReceiptPath
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage3LlvmPath `
        -BitcodePath $stage3BitcodePath `
        -ExecutablePath $stage3Path `
        -AdditionalArtifacts @{ object = $stage3ObjectPath } `
        -ReceiptPath $stage3OutputReceiptPath
    [System.IO.File]::WriteAllText(
        $stage3InputReceiptPath,
        (Get-ProbeInputFingerprint linux $stage2Path $sourcePaths))

    & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
        -Platform linux `
        -Stage3Path $stage3Path `
        -RepositoryRoot $temporaryRoot

    [System.IO.File]::AppendAllText($stage3ObjectPath, "-changed")
    $objectMutationRejected = $false
    try {
        & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
            -Platform linux `
            -Stage3Path $stage3Path `
            -RepositoryRoot $temporaryRoot
    } catch {
        $objectMutationRejected = $true
    }
    if (-not $objectMutationRejected) {
        throw "published Stage3 verifier accepted a mutated Linux object"
    }

    [System.IO.File]::WriteAllText($stage3ObjectPath, "object")
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage3LlvmPath `
        -BitcodePath $stage3BitcodePath `
        -ExecutablePath $stage3Path `
        -AdditionalArtifacts @{ object = $stage3ObjectPath } `
        -ReceiptPath $stage3OutputReceiptPath
    [System.IO.File]::AppendAllText($stage2LlvmPath, "-changed")
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -AdditionalArtifacts @{ object = $stage2ObjectPath } `
        -ReceiptPath $stage2OutputReceiptPath
    $fixedPointMismatchRejected = $false
    try {
        & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
            -Platform linux `
            -Stage3Path $stage3Path `
            -RepositoryRoot $temporaryRoot
    } catch {
        $fixedPointMismatchRejected = $true
    }
    if (-not $fixedPointMismatchRejected) {
        throw "published Stage3 verifier accepted differing Stage2/Stage3 LLVM"
    }

    [System.IO.File]::WriteAllText($stage2LlvmPath, "llvm")
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -AdditionalArtifacts @{ object = $stage2ObjectPath } `
        -ReceiptPath $stage2OutputReceiptPath
    [System.IO.File]::AppendAllText($runtimeSource, "-changed")
    $sourceMutationRejected = $false
    try {
        & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
            -Platform linux `
            -Stage3Path $stage3Path `
            -RepositoryRoot $temporaryRoot
    } catch {
        $sourceMutationRejected = $true
    }
    if (-not $sourceMutationRejected) {
        throw "published Stage3 verifier accepted a stale ordered-source fingerprint"
    }

    [System.IO.File]::WriteAllText($runtimeSource, "runtime")
    $windowsStage2Path = Join-Path $artifactDirectory "selfhost-stage2.exe"
    $windowsStage2LlvmPath = Join-Path $artifactDirectory "selfhost-stage2.ll"
    $windowsStage2BitcodePath = Join-Path $artifactDirectory "selfhost-stage2.bc"
    $windowsStage2OutputReceiptPath = Join-Path $artifactDirectory "selfhost-stage2.outputs.sha256"
    $windowsStage3Path = Join-Path $artifactDirectory "selfhost-stage3.exe"
    $windowsStage3LlvmPath = Join-Path $artifactDirectory "selfhost-stage3.ll"
    $windowsStage3BitcodePath = Join-Path $artifactDirectory "selfhost-stage3.bc"
    $windowsInputReceiptPath = Join-Path $artifactDirectory "selfhost-stage3.inputs.sha256"
    $windowsOutputReceiptPath = Join-Path $artifactDirectory "selfhost-stage3.outputs.sha256"
    [System.IO.File]::WriteAllText($windowsStage2Path, "windows-stage2")
    [System.IO.File]::WriteAllText($windowsStage2LlvmPath, "windows-llvm")
    [System.IO.File]::WriteAllText($windowsStage2BitcodePath, "windows-stage2-bitcode")
    [System.IO.File]::WriteAllText($windowsStage3Path, "windows-stage3")
    [System.IO.File]::WriteAllText($windowsStage3LlvmPath, "windows-llvm")
    [System.IO.File]::WriteAllText($windowsStage3BitcodePath, "windows-bitcode")
    Write-Stage2ArtifactReceipt `
        -LlvmPath $windowsStage2LlvmPath `
        -BitcodePath $windowsStage2BitcodePath `
        -ExecutablePath $windowsStage2Path `
        -ReceiptPath $windowsStage2OutputReceiptPath
    Write-Stage2ArtifactReceipt `
        -LlvmPath $windowsStage3LlvmPath `
        -BitcodePath $windowsStage3BitcodePath `
        -ExecutablePath $windowsStage3Path `
        -ReceiptPath $windowsOutputReceiptPath
    [System.IO.File]::WriteAllText(
        $windowsInputReceiptPath,
        (Get-ProbeInputFingerprint windows $windowsStage2Path $sourcePaths))
    & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
        -Platform windows `
        -Stage3Path $windowsStage3Path `
        -RepositoryRoot $temporaryRoot

    [System.IO.File]::AppendAllText($windowsStage2Path, "-changed")
    $stage2MutationRejected = $false
    try {
        & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
            -Platform windows `
            -Stage3Path $windowsStage3Path `
            -RepositoryRoot $temporaryRoot
    } catch {
        $stage2MutationRejected = $true
    }
    if (-not $stage2MutationRejected) {
        throw "published Stage3 verifier accepted a stale Stage2 executable fingerprint"
    }

    Write-Host "[stage3 artifact contract] PASS Windows/Linux provenance plus output/fixed-point/source/Stage2 mutation negative controls."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
