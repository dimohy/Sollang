[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "stage3-seed-provenance.ps1")

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$temporaryRoot = Join-Path $RepositoryRoot "artifacts\stage3-seed-provenance-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null

function Write-TestText {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text)
}

function Assert-Rejected {
    param([scriptblock]$Action, [string]$Expected)
    $rejected = $false
    try {
        & $Action
    }
    catch {
        if (-not $_.Exception.Message.Contains($Expected, [System.StringComparison]::Ordinal)) {
            throw
        }
        $rejected = $true
    }
    if (-not $rejected) {
        throw "Expected Stage3 seed provenance rejection containing '$Expected'"
    }
}

try {
    $stage2Executable = Join-Path $temporaryRoot "selfhost-stage2.exe"
    $stage2Llvm = Join-Path $temporaryRoot "selfhost-stage2.ll"
    $stage2Bitcode = Join-Path $temporaryRoot "selfhost-stage2.bc"
    $stage2OutputReceipt = Join-Path $temporaryRoot "selfhost-stage2.outputs.sha256"
    $stage3Executable = Join-Path $temporaryRoot "selfhost-stage3.exe"
    $stage3Llvm = Join-Path $temporaryRoot "selfhost-stage3.ll"
    $stage3Bitcode = Join-Path $temporaryRoot "selfhost-stage3.bc"
    $stage3InputReceipt = Join-Path $temporaryRoot "selfhost-stage3.inputs.sha256"
    $stage3OutputReceipt = Join-Path $temporaryRoot "selfhost-stage3.outputs.sha256"
    $seed = Join-Path $temporaryRoot "selfhost-slg-seed.exe"

    Write-TestText $stage2Executable "fixed-point compiler"
    Write-TestText $stage3Executable "fixed-point compiler"
    Write-TestText $stage2Llvm "define i32 @main() { ret i32 0 }`n"
    Write-TestText $stage3Llvm "define i32 @main() { ret i32 0 }`r`n"
    Write-TestText $stage2Bitcode "stage2 bitcode"
    Write-TestText $stage3Bitcode "stage3 bitcode"
    Write-TestText $stage3InputReceipt ("A" * 64)
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage2Llvm `
        -BitcodePath $stage2Bitcode `
        -ExecutablePath $stage2Executable `
        -ReceiptPath $stage2OutputReceipt
    Write-Stage2ArtifactReceipt `
        -LlvmPath $stage3Llvm `
        -BitcodePath $stage3Bitcode `
        -ExecutablePath $stage3Executable `
        -ReceiptPath $stage3OutputReceipt
    Copy-Item -LiteralPath $stage3Executable -Destination $seed

    $provenancePath = Write-VerifiedStage3SeedProvenance `
        -RepositoryRoot $RepositoryRoot `
        -Target windows `
        -Producer "verify-selfhost-stage3.ps1" `
        -Optimization O1 `
        -SeedPath $seed `
        -Stage2ExecutablePath $stage2Executable `
        -Stage2LlvmPath $stage2Llvm `
        -Stage2BitcodePath $stage2Bitcode `
        -Stage2OutputReceiptPath $stage2OutputReceipt `
        -Stage3ExecutablePath $stage3Executable `
        -Stage3LlvmPath $stage3Llvm `
        -Stage3BitcodePath $stage3Bitcode `
        -Stage3InputReceiptPath $stage3InputReceipt `
        -Stage3OutputReceiptPath $stage3OutputReceipt
    Assert-VerifiedStage3SeedProvenance `
        -RepositoryRoot $RepositoryRoot `
        -SeedPath $seed `
        -Target windows | Out-Null

    $fakeStage1 = Join-Path $temporaryRoot "incremental-stage1.exe"
    Write-TestText $fakeStage1 "incremental stage1"
    Write-TestText ([System.IO.Path]::ChangeExtension($fakeStage1, ".sha256")) `
        ((Get-FileHash -LiteralPath $fakeStage1 -Algorithm SHA256).Hash)
    Assert-Rejected {
        Assert-VerifiedStage3SeedProvenance -RepositoryRoot $RepositoryRoot -SeedPath $fakeStage1 -Target windows
    } "has no Stage3 provenance receipt"

    $stage2LlvmText = [System.IO.File]::ReadAllText($stage2Llvm)
    Write-TestText $stage2Llvm "$stage2LlvmText; tampered"
    Assert-Rejected {
        Assert-VerifiedStage3SeedProvenance -RepositoryRoot $RepositoryRoot -SeedPath $seed -Target windows
    } "stage2 llvm differs"
    Write-TestText $stage2Llvm $stage2LlvmText

    Write-TestText $stage3InputReceipt ("B" * 64)
    Assert-Rejected {
        Assert-VerifiedStage3SeedProvenance -RepositoryRoot $RepositoryRoot -SeedPath $seed -Target windows
    } "input receipt differs"
    Write-TestText $stage3InputReceipt ("A" * 64)

    $seedText = [System.IO.File]::ReadAllText($seed)
    Write-TestText $seed "$seedText tampered"
    Write-TestText ([System.IO.Path]::ChangeExtension($seed, ".sha256")) `
        ((Get-FileHash -LiteralPath $seed -Algorithm SHA256).Hash)
    Assert-Rejected {
        Assert-VerifiedStage3SeedProvenance -RepositoryRoot $RepositoryRoot -SeedPath $seed -Target windows
    } "differs from its Stage3 provenance"
    Write-TestText $seed $seedText

    $originalProvenance = [System.IO.File]::ReadAllText($provenancePath)
    $escaped = $originalProvenance | ConvertFrom-Json
    $escaped.stage2.executablePath = "../outside.exe"
    Write-TestText $provenancePath (($escaped | ConvertTo-Json -Depth 6) + "`n")
    Assert-Rejected {
        Assert-VerifiedStage3SeedProvenance -RepositoryRoot $RepositoryRoot -SeedPath $seed -Target windows
    } "path escapes the repository"
    Write-TestText $provenancePath $originalProvenance

    Write-Host "[stage3 seed provenance] PASS verified fixed point and rejected Stage1-only, artifact drift, input drift, seed drift, and path escape."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
