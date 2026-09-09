param(
    [string]$ArtifactsDirectory = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "verification-process.ps1")

$ownsArtifactsDirectory = [string]::IsNullOrWhiteSpace($ArtifactsDirectory)
if ($ownsArtifactsDirectory) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $runId = [Guid]::NewGuid().ToString("N")
    $ArtifactsDirectory = Join-Path $repoRoot "artifacts\stage2-artifact-receipt-test-$runId"
}
$ArtifactsDirectory = [System.IO.Path]::GetFullPath($ArtifactsDirectory)
New-Item -ItemType Directory -Force -Path $ArtifactsDirectory | Out-Null

$llvmPath = Join-Path $ArtifactsDirectory "probe.ll"
$bitcodePath = Join-Path $ArtifactsDirectory "probe.bc"
$metadataPath = Join-Path $ArtifactsDirectory "probe.meta"
$objectPath = Join-Path $ArtifactsDirectory "probe.o"
$executablePath = Join-Path $ArtifactsDirectory "probe.exe"
$receiptPath = Join-Path $ArtifactsDirectory "probe.outputs.sha256"

try {
    $candidateExecutablePath = Get-CandidateArtifactPath $executablePath
    if ([System.IO.Path]::GetFileName($candidateExecutablePath) -cne "probe.candidate.exe") {
        throw "candidate executable path does not preserve the .exe extension: $candidateExecutablePath"
    }
    Copy-Item -LiteralPath (Join-Path $env:WINDIR "System32\whoami.exe") -Destination $candidateExecutablePath
    $null = & $candidateExecutablePath
    if ($LASTEXITCODE -ne 0) {
        throw "candidate executable failed through direct invocation"
    }
    $candidateProcess = Start-Process -FilePath $candidateExecutablePath -WindowStyle Hidden -PassThru
    Wait-VerificationProcess $candidateProcess "candidate executable receipt control" 5000
    if ($candidateProcess.ExitCode -ne 0) {
        throw "candidate executable failed through Start-Process"
    }
    Remove-Item -LiteralPath $candidateExecutablePath

    [System.IO.File]::WriteAllText($llvmPath, "llvm")
    [System.IO.File]::WriteAllText($bitcodePath, "bitcode")
    [System.IO.File]::WriteAllText($metadataPath, "metadata")
    [System.IO.File]::WriteAllText($objectPath, "object")
    [System.IO.File]::WriteAllText($executablePath, "executable")
    Write-Stage2ArtifactReceipt `
        -LlvmPath $llvmPath `
        -BitcodePath $bitcodePath `
        -ExecutablePath $executablePath `
        -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
        -ReceiptPath $receiptPath

    $receiptLines = [System.IO.File]::ReadAllLines($receiptPath)
    if ($receiptLines.Count -ne 5 -or
        -not $receiptLines[3].StartsWith("metadata ", [System.StringComparison]::Ordinal) -or
        -not $receiptLines[4].StartsWith("object ", [System.StringComparison]::Ordinal)) {
        throw "additional artifact receipt names are not in ordinal order"
    }

    if (-not (Test-Stage2ArtifactReceipt `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
            -ReceiptPath $receiptPath)) {
        throw "fresh Stage2 artifact receipt was rejected"
    }

    [System.IO.File]::AppendAllText($llvmPath, "-changed")
    if (Test-Stage2ArtifactReceipt `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
            -ReceiptPath $receiptPath) {
        throw "mutated Stage2 LLVM was accepted"
    }

    [System.IO.File]::WriteAllText($llvmPath, "llvm")
    [System.IO.File]::WriteAllText($bitcodePath, "")
    if (Test-Stage2ArtifactReceipt `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
            -ReceiptPath $receiptPath) {
        throw "empty Stage2 bitcode was accepted"
    }

    [System.IO.File]::WriteAllText($bitcodePath, "bitcode")
    Remove-Item -LiteralPath $executablePath
    if (Test-Stage2ArtifactReceipt `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
            -ReceiptPath $receiptPath) {
        throw "missing Stage2 executable was accepted"
    }

    [System.IO.File]::WriteAllText($executablePath, "executable")
    [System.IO.File]::AppendAllText($objectPath, "-changed")
    if (Test-Stage2ArtifactReceipt `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
            -ReceiptPath $receiptPath) {
        throw "mutated additional artifact was accepted"
    }

    [System.IO.File]::WriteAllText($objectPath, "object")
    [System.IO.File]::WriteAllText($receiptPath, "invalid")
    if (Test-Stage2ArtifactReceipt `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -AdditionalArtifacts ([ordered]@{ object = $objectPath; metadata = $metadataPath }) `
            -ReceiptPath $receiptPath) {
        throw "tampered Stage2 output receipt was accepted"
    }

    Write-Host "[stage2 receipt] PASS candidate execution, ordinal additional-artifact order, mutation, missing/empty-artifact, and tampered-receipt contracts."
}
finally {
    $receiptCandidatePath = Get-CandidateArtifactPath $receiptPath
    Remove-Item -LiteralPath $llvmPath, $bitcodePath, $metadataPath, $objectPath, $executablePath, $candidateExecutablePath, $receiptPath, $receiptCandidatePath -ErrorAction SilentlyContinue
    if ($ownsArtifactsDirectory -and (Test-Path -LiteralPath $ArtifactsDirectory)) {
        Remove-Item -LiteralPath $ArtifactsDirectory -Force
    }
}
