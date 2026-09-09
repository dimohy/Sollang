Set-StrictMode -Version Latest

function Get-Stage3SeedProvenancePath {
    param([Parameter(Mandatory)][string]$SeedPath)

    return [System.IO.Path]::ChangeExtension($SeedPath, ".stage3-seed.json")
}

function Get-NormalizedStage3SeedLlvmFingerprint {
    param([Parameter(Mandatory)][string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($content)))
}

function Get-Stage3SeedRelativePath {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Path
    )

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $relative = [System.IO.Path]::GetRelativePath($root, $fullPath).Replace("\", "/")
    if ($relative -eq ".." -or $relative.StartsWith("../", [System.StringComparison]::Ordinal)) {
        throw "Stage3 seed provenance path escapes the repository: $fullPath"
    }
    return $relative
}

function Resolve-Stage3SeedProvenancePath {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Stage3 seed provenance paths must be repository-relative: $RelativePath"
    }
    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    $resolved = [System.IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    $rootPrefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Stage3 seed provenance path escapes the repository: $RelativePath"
    }
    return $resolved
}

function Get-Stage3SeedGenerationRecord {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$OutputReceiptPath
    )

    foreach ($path in @($ExecutablePath, $LlvmPath, $BitcodePath, $OutputReceiptPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
            throw "Stage3 seed provenance input is missing or empty: $path"
        }
    }
    return [ordered]@{
        executablePath = Get-Stage3SeedRelativePath $RepositoryRoot $ExecutablePath
        executableFingerprint = (Get-FileHash -LiteralPath $ExecutablePath -Algorithm SHA256).Hash
        llvmPath = Get-Stage3SeedRelativePath $RepositoryRoot $LlvmPath
        llvmFingerprint = (Get-FileHash -LiteralPath $LlvmPath -Algorithm SHA256).Hash
        bitcodePath = Get-Stage3SeedRelativePath $RepositoryRoot $BitcodePath
        bitcodeFingerprint = (Get-FileHash -LiteralPath $BitcodePath -Algorithm SHA256).Hash
        outputReceiptPath = Get-Stage3SeedRelativePath $RepositoryRoot $OutputReceiptPath
        outputReceiptFingerprint = (Get-FileHash -LiteralPath $OutputReceiptPath -Algorithm SHA256).Hash
    }
}

function Write-VerifiedStage3SeedProvenance {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][ValidateSet("windows", "linux")][string]$Target,
        [Parameter(Mandatory)][ValidateSet("verify-selfhost-stage3.ps1", "verify-selfhost-stage3-linux.ps1")][string]$Producer,
        [Parameter(Mandatory)][ValidateSet("O1")][string]$Optimization,
        [Parameter(Mandatory)][string]$SeedPath,
        [Parameter(Mandatory)][string]$Stage2ExecutablePath,
        [Parameter(Mandatory)][string]$Stage2LlvmPath,
        [Parameter(Mandatory)][string]$Stage2BitcodePath,
        [Parameter(Mandatory)][string]$Stage2OutputReceiptPath,
        [Parameter(Mandatory)][string]$Stage3ExecutablePath,
        [Parameter(Mandatory)][string]$Stage3LlvmPath,
        [Parameter(Mandatory)][string]$Stage3BitcodePath,
        [Parameter(Mandatory)][string]$Stage3InputReceiptPath,
        [Parameter(Mandatory)][string]$Stage3OutputReceiptPath
    )

    if (-not (Get-Command Test-Stage2ArtifactReceipt -ErrorAction SilentlyContinue)) {
        throw "Stage3 seed provenance requires stage2-artifact-receipt.ps1"
    }
    if (-not (Test-Stage2ArtifactReceipt -LlvmPath $Stage2LlvmPath -BitcodePath $Stage2BitcodePath -ExecutablePath $Stage2ExecutablePath -ReceiptPath $Stage2OutputReceiptPath)) {
        throw "Stage2 artifacts differ from their completion receipt"
    }
    if (-not (Test-Stage2ArtifactReceipt -LlvmPath $Stage3LlvmPath -BitcodePath $Stage3BitcodePath -ExecutablePath $Stage3ExecutablePath -ReceiptPath $Stage3OutputReceiptPath)) {
        throw "Stage3 artifacts differ from their completion receipt"
    }
    $stage2 = Get-Stage3SeedGenerationRecord $RepositoryRoot $Stage2ExecutablePath $Stage2LlvmPath $Stage2BitcodePath $Stage2OutputReceiptPath
    $stage3 = Get-Stage3SeedGenerationRecord $RepositoryRoot $Stage3ExecutablePath $Stage3LlvmPath $Stage3BitcodePath $Stage3OutputReceiptPath
    if (-not (Test-Path -LiteralPath $Stage3InputReceiptPath -PathType Leaf)) {
        throw "Stage3 seed input receipt is missing: $Stage3InputReceiptPath"
    }
    $stage3.inputReceiptPath = Get-Stage3SeedRelativePath $RepositoryRoot $Stage3InputReceiptPath
    $stage3.inputFingerprint = [System.IO.File]::ReadAllText($Stage3InputReceiptPath).Trim()
    $fixedPoint = Get-NormalizedStage3SeedLlvmFingerprint $Stage2LlvmPath
    if ($fixedPoint -cne (Get-NormalizedStage3SeedLlvmFingerprint $Stage3LlvmPath)) {
        throw "Stage2 and Stage3 LLVM do not form a fixed point"
    }
    $seedFingerprint = (Get-FileHash -LiteralPath $SeedPath -Algorithm SHA256).Hash
    if ($seedFingerprint -cne $stage3.executableFingerprint) {
        throw "Published SLG seed does not match the verified Stage3 executable"
    }
    $receipt = [ordered]@{
        schemaVersion = 1
        mode = "verified-selfhost-stage3-seed"
        producer = $Producer
        optimization = $Optimization
        target = $Target
        seedPath = Get-Stage3SeedRelativePath $RepositoryRoot $SeedPath
        seedFingerprint = $seedFingerprint
        stage2 = $stage2
        stage3 = $stage3
        fixedPointLlvmFingerprint = $fixedPoint
        publishedByStage3Gate = $true
    }
    $json = ($receipt | ConvertTo-Json -Depth 6) + "`n"
    $schemaPath = Join-Path $RepositoryRoot "scripts/contracts/selfhost-stage3-seed.schema.json"
    if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "Stage3 seed provenance does not match $schemaPath"
    }
    $receiptPath = Get-Stage3SeedProvenancePath $SeedPath
    $candidatePath = "$receiptPath.candidate"
    [System.IO.File]::WriteAllText($candidatePath, $json)
    Move-Item -LiteralPath $candidatePath -Destination $receiptPath -Force
    return $receiptPath
}

function Assert-VerifiedStage3SeedProvenance {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$SeedPath,
        [Parameter(Mandatory)][ValidateSet("windows", "linux")][string]$Target
    )

    $receiptPath = Get-Stage3SeedProvenancePath $SeedPath
    $schemaPath = Join-Path $RepositoryRoot "scripts/contracts/selfhost-stage3-seed.schema.json"
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        throw "Formal Stage2 SLG seed has no Stage3 provenance receipt: $receiptPath"
    }
    $json = [System.IO.File]::ReadAllText($receiptPath)
    if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "Formal Stage2 SLG seed provenance does not match $schemaPath"
    }
    $receipt = $json | ConvertFrom-Json
    if ($receipt.target -cne $Target) {
        throw "Formal Stage2 SLG seed target is $($receipt.target), expected $Target"
    }
    $resolvedSeed = Resolve-Stage3SeedProvenancePath $RepositoryRoot $receipt.seedPath
    if ([System.IO.Path]::GetFullPath($SeedPath) -cne $resolvedSeed) {
        throw "Formal Stage2 SLG seed path differs from its Stage3 provenance"
    }
    $actualSeedHash = (Get-FileHash -LiteralPath $SeedPath -Algorithm SHA256).Hash
    if ($actualSeedHash -cne $receipt.seedFingerprint) {
        throw "Formal Stage2 SLG seed differs from its Stage3 provenance"
    }
    foreach ($generationName in @("stage2", "stage3")) {
        $generation = $receipt.$generationName
        foreach ($artifactName in @("executable", "llvm", "bitcode", "outputReceipt")) {
            $pathProperty = "${artifactName}Path"
            $fingerprintProperty = "${artifactName}Fingerprint"
            $artifactPath = Resolve-Stage3SeedProvenancePath $RepositoryRoot $generation.$pathProperty
            if ((Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash -cne $generation.$fingerprintProperty) {
                throw "Formal Stage2 SLG seed $generationName $artifactName differs from its Stage3 provenance"
            }
        }
    }
    if (-not (Get-Command Test-Stage2ArtifactReceipt -ErrorAction SilentlyContinue)) {
        throw "Formal Stage2 SLG seed provenance requires stage2-artifact-receipt.ps1"
    }
    foreach ($generationName in @("stage2", "stage3")) {
        $generation = $receipt.$generationName
        if (-not (Test-Stage2ArtifactReceipt `
                -LlvmPath (Resolve-Stage3SeedProvenancePath $RepositoryRoot $generation.llvmPath) `
                -BitcodePath (Resolve-Stage3SeedProvenancePath $RepositoryRoot $generation.bitcodePath) `
                -ExecutablePath (Resolve-Stage3SeedProvenancePath $RepositoryRoot $generation.executablePath) `
                -ReceiptPath (Resolve-Stage3SeedProvenancePath $RepositoryRoot $generation.outputReceiptPath))) {
            throw "Formal Stage2 SLG seed $generationName artifacts differ from their completion receipt"
        }
    }
    $stage3InputPath = Resolve-Stage3SeedProvenancePath $RepositoryRoot $receipt.stage3.inputReceiptPath
    if ([System.IO.File]::ReadAllText($stage3InputPath).Trim() -cne $receipt.stage3.inputFingerprint) {
        throw "Formal Stage2 SLG seed Stage3 input receipt differs from its provenance"
    }
    $stage2LlvmPath = Resolve-Stage3SeedProvenancePath $RepositoryRoot $receipt.stage2.llvmPath
    $stage3LlvmPath = Resolve-Stage3SeedProvenancePath $RepositoryRoot $receipt.stage3.llvmPath
    $stage2FixedPoint = Get-NormalizedStage3SeedLlvmFingerprint $stage2LlvmPath
    $stage3FixedPoint = Get-NormalizedStage3SeedLlvmFingerprint $stage3LlvmPath
    if ($stage2FixedPoint -cne $stage3FixedPoint -or $stage2FixedPoint -cne $receipt.fixedPointLlvmFingerprint) {
        throw "Formal Stage2 SLG seed no longer proves the recorded Stage2/Stage3 fixed point"
    }
    $sourceStage3Hash = (Get-FileHash -LiteralPath (Resolve-Stage3SeedProvenancePath $RepositoryRoot $receipt.stage3.executablePath) -Algorithm SHA256).Hash
    if ($sourceStage3Hash -cne $actualSeedHash) {
        throw "Formal Stage2 SLG seed is not the recorded verified Stage3 executable"
    }
    return $receipt
}
