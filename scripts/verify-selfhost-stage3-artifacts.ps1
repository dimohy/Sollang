[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("windows", "linux")]
    [string]$Platform,
    [Parameter(Mandatory)]
    [string]$Stage3Path,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$Stage3Path = [System.IO.Path]::GetFullPath($Stage3Path)
$artifactDirectory = [System.IO.Path]::GetDirectoryName($Stage3Path)
$extension = [System.IO.Path]::GetExtension($Stage3Path)
$stage3Name = [System.IO.Path]::GetFileNameWithoutExtension($Stage3Path)
if (-not $stage3Name.Contains("stage3", [System.StringComparison]::Ordinal)) {
    throw "Stage3 compiler name must contain 'stage3': $Stage3Path"
}
$stage2Name = $stage3Name.Replace("stage3", "stage2", [System.StringComparison]::Ordinal)
$stage2Path = Join-Path $artifactDirectory ($stage2Name + $extension)
$stage2LlvmPath = Join-Path $artifactDirectory ($stage2Name + ".ll")
$stage2BitcodePath = Join-Path $artifactDirectory ($stage2Name + ".bc")
$stage2OutputReceiptPath = Join-Path $artifactDirectory ($stage2Name + ".outputs.sha256")
$llvmPath = Join-Path $artifactDirectory ($stage3Name + ".ll")
$bitcodePath = Join-Path $artifactDirectory ($stage3Name + ".bc")
$inputReceiptPath = Join-Path $artifactDirectory ($stage3Name + ".inputs.sha256")
$outputReceiptPath = Join-Path $artifactDirectory ($stage3Name + ".outputs.sha256")
$additionalArtifacts = @{}
$stage2AdditionalArtifacts = @{}
if ($Platform -ceq "linux") {
    $additionalArtifacts.object = Join-Path $artifactDirectory ($stage3Name + ".o")
    $stage2AdditionalArtifacts.object = Join-Path $artifactDirectory ($stage2Name + ".o")
}

if (-not (Test-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -AdditionalArtifacts $stage2AdditionalArtifacts `
        -ReceiptPath $stage2OutputReceiptPath)) {
    throw "$Platform Stage2 artifacts are missing, empty, or differ from their published output receipt"
}
if (-not (Test-Stage2ArtifactReceipt `
        -LlvmPath $llvmPath `
        -BitcodePath $bitcodePath `
        -ExecutablePath $Stage3Path `
        -AdditionalArtifacts $additionalArtifacts `
        -ReceiptPath $outputReceiptPath)) {
    throw "$Platform Stage3 artifacts are missing, empty, or differ from their published output receipt"
}
if (-not (Test-Path -LiteralPath $inputReceiptPath -PathType Leaf)) {
    throw "$Platform Stage3 published input receipt is missing: $inputReceiptPath"
}

$manifestPaths = @(
    (Join-Path $RepositoryRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"),
    (Join-Path $RepositoryRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt")
)
$sourcePaths = foreach ($manifestPath in $manifestPaths) {
    Get-Content -LiteralPath $manifestPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path (Join-Path $RepositoryRoot $_.Trim())).Path }
}
$hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
    [System.Security.Cryptography.HashAlgorithmName]::SHA256)
foreach ($path in $sourcePaths) {
    $relative = [System.IO.Path]::GetRelativePath($RepositoryRoot, $path).Replace("\", "/")
    $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$relative`0"))
    $hash.AppendData([System.IO.File]::ReadAllBytes($path))
}
$sourceFingerprint = [Convert]::ToHexString($hash.GetHashAndReset())
$stage2Hash = (Get-FileHash -LiteralPath $stage2Path -Algorithm SHA256).Hash
$fingerprintText = "$Platform`0$stage2Hash`0$sourceFingerprint"
$expectedInputFingerprint = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes($fingerprintText)))
$actualInputFingerprint = [System.IO.File]::ReadAllText($inputReceiptPath).Trim()
if ($actualInputFingerprint -cne $expectedInputFingerprint) {
    throw "$Platform Stage3 input receipt does not match the current Stage2 compiler and ordered source contents"
}

function Get-NormalizedLlvmHash {
    param([Parameter(Mandatory)][string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes($content)))
}
$stage2LlvmHash = Get-NormalizedLlvmHash $stage2LlvmPath
$stage3LlvmHash = Get-NormalizedLlvmHash $llvmPath
if ($stage2LlvmHash -cne $stage3LlvmHash) {
    throw "$Platform published Stage2 and Stage3 LLVM do not form an exact fixed point"
}

Write-Host "[stage3 artifacts] PASS $Platform Stage2/Stage3 receipts, fixed point $stage3LlvmHash, and current input fingerprint $expectedInputFingerprint."
