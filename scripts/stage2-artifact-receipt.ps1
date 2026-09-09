function Get-CandidateArtifactPath {
    param([Parameter(Mandatory)][string]$Path)

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [System.IO.Path]::GetExtension($Path)
    return Join-Path $directory "$fileName.candidate$extension"
}

function Get-Stage2ArtifactReceiptText {
    param(
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [System.Collections.IDictionary]$AdditionalArtifacts = @{}
    )

    $artifacts = [System.Collections.Generic.List[object]]::new()
    $artifacts.Add([pscustomobject]@{ Name = "llvm"; Path = $LlvmPath })
    $artifacts.Add([pscustomobject]@{ Name = "bitcode"; Path = $BitcodePath })
    $artifacts.Add([pscustomobject]@{ Name = "executable"; Path = $ExecutablePath })
    $additionalNames = [string[]]@($AdditionalArtifacts.Keys | ForEach-Object { [string]$_ })
    [System.Array]::Sort($additionalNames, [System.StringComparer]::Ordinal)
    foreach ($name in $additionalNames) {
        if ([string]::IsNullOrWhiteSpace([string]$name) -or $name -notmatch '^[a-z][a-z0-9-]*$') {
            throw "Artifact receipt name must be a lowercase identifier: '$name'"
        }
        if ($name -in @("llvm", "bitcode", "executable")) {
            throw "Artifact receipt name is reserved: '$name'"
        }
        $artifacts.Add([pscustomobject]@{ Name = [string]$name; Path = [string]$AdditionalArtifacts[$name] })
    }

    foreach ($artifact in $artifacts) {
        if (-not (Test-Path -LiteralPath $artifact.Path) -or (Get-Item -LiteralPath $artifact.Path).Length -eq 0) {
            throw "Verified artifact is missing or empty: $($artifact.Path)"
        }
    }

    return @($artifacts | ForEach-Object {
        "$($_.Name) $((Get-FileHash -LiteralPath $_.Path -Algorithm SHA256).Hash)"
    }) -join "`n"
}

function Test-Stage2ArtifactReceipt {
    param(
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$ReceiptPath,
        [System.Collections.IDictionary]$AdditionalArtifacts = @{}
    )

    if (-not (Test-Path -LiteralPath $ReceiptPath)) {
        return $false
    }

    foreach ($path in @($LlvmPath, $BitcodePath, $ExecutablePath) + @($AdditionalArtifacts.Values)) {
        if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) {
            return $false
        }
    }

    $expected = Get-Stage2ArtifactReceiptText `
        -LlvmPath $LlvmPath `
        -BitcodePath $BitcodePath `
        -ExecutablePath $ExecutablePath `
        -AdditionalArtifacts $AdditionalArtifacts
    return [System.IO.File]::ReadAllText($ReceiptPath).Trim() -ceq $expected
}

function Write-Stage2ArtifactReceipt {
    param(
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$ReceiptPath,
        [System.Collections.IDictionary]$AdditionalArtifacts = @{}
    )

    $text = Get-Stage2ArtifactReceiptText `
        -LlvmPath $LlvmPath `
        -BitcodePath $BitcodePath `
        -ExecutablePath $ExecutablePath `
        -AdditionalArtifacts $AdditionalArtifacts
    $candidatePath = Get-CandidateArtifactPath $ReceiptPath
    [System.IO.File]::WriteAllText($candidatePath, $text)
    Move-Item -LiteralPath $candidatePath -Destination $ReceiptPath -Force
}
