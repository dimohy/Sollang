Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")

function Assert-NativeExactFixturePlan {
    param([Parameter(Mandatory)][string[]]$Fixture)

    if ($Fixture.Count -eq 0) {
        throw "Native exact fixture plan requires at least one fixture"
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Fixture) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Native exact fixture plan contains a blank fixture name"
        }
        if (-not $seen.Add($name)) {
            throw "Native exact fixture plan repeats fixture '$name'; each output and receipt must have exactly one writer"
        }
    }
}

function Get-NativeExactOrderedSourceClosure {
    param([Parameter(Mandatory)][string]$Root)

    $rootPath = (Resolve-Path -LiteralPath $Root).Path
    $paths = [string[]][System.IO.Directory]::GetFiles(
        $rootPath,
        "*.slg",
        [System.IO.SearchOption]::AllDirectories)
    [System.Array]::Sort($paths, [System.StringComparer]::Ordinal)
    if ($paths.Count -eq 0) {
        throw "Native exact source closure is empty: $rootPath"
    }
    return $paths
}

function Get-NativeExactWindowsCommonInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CompilerPath,
        [Parameter(Mandatory)][string]$StdlibRoot,
        [Parameter(Mandatory)][string]$LlvmRoot
    )

    $contractPath = Join-Path $PSScriptRoot "contracts\native-exact-fixture-receipt.json"
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $verificationPaths = @(
        (Join-Path $PSScriptRoot "verify-native-exact-fixture.ps1"),
        (Join-Path $PSScriptRoot "native-exact-fixture-receipt.ps1"),
        (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1"),
        (Join-Path $PSScriptRoot "verification-process.ps1"),
        (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1"),
        $contractPath
    )
    $toolPaths = @($contract.platformEnvironment.windows.contentHashedTools | ForEach-Object {
        Join-Path $LlvmRoot "bin\$_"
    })
    $settings = [ordered]@{
        nativeJobLimit = [string]$env:SOLLANG_NATIVE_JOBS
        platform = "windows"
        processorCount = [Environment]::ProcessorCount.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture)
    }
    $paths = @((Resolve-Path -LiteralPath $CompilerPath).Path)
    $paths += @(Get-NativeExactOrderedSourceClosure -Root $StdlibRoot)
    $paths += $verificationPaths
    $paths += $toolPaths
    return Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $RepositoryRoot `
        -Settings $settings `
        -InputPath $paths
}

function Get-NativeExactPerFixtureInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CommonFingerprint,
        [Parameter(Mandatory)][string]$Fixture,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][ValidateSet("windows", "linux")][string]$Platform,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Distribution,
        [Parameter(Mandatory)][ValidateRange(1, 64)][int]$Jobs,
        [Parameter(Mandatory)][ValidateRange(0, 2147483647)][long]$ExpectedStdoutLength,
        [Parameter(Mandatory)][string[]]$InputPath
    )

    if ($CommonFingerprint -cnotmatch '^[0-9A-F]{64}$') {
        throw "Native exact common fingerprint must be an uppercase SHA-256 value"
    }
    $settings = [ordered]@{
        commonFingerprint = $CommonFingerprint
        distribution = $Distribution
        expectedStdoutLength = $ExpectedStdoutLength.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture)
        fixture = $Fixture
        jobs = $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        label = $Label
        platform = $Platform
    }
    return Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $RepositoryRoot `
        -Settings $settings `
        -InputPath $InputPath
}

function Get-NativeExactFixtureInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Settings,
        [Parameter(Mandatory)][string[]]$InputPath
    )

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    if ($Settings.Count -eq 0) {
        throw "Native exact input fingerprint requires at least one setting"
    }
    if ($InputPath.Count -eq 0) {
        throw "Native exact input fingerprint requires at least one file"
    }

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        function Add-FingerprintText {
            param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

            $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes($Text))
            $hash.AppendData([byte[]]@(0))
        }

        Add-FingerprintText "native-exact-fixture-input-v1"

        $settingNames = [string[]]@($Settings.Keys | ForEach-Object { [string]$_ })
        [System.Array]::Sort($settingNames, [System.StringComparer]::Ordinal)
        foreach ($name in $settingNames) {
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw "Native exact input setting name must not be blank"
            }
            Add-FingerprintText "setting"
            Add-FingerprintText $name
            Add-FingerprintText ([string]$Settings[$name])
        }

        for ($index = 0; $index -lt $InputPath.Count; $index += 1) {
            $path = [System.IO.Path]::GetFullPath($InputPath[$index])
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Native exact input is missing: $path"
            }

            $relativePath = [System.IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
            Add-FingerprintText "input"
            Add-FingerprintText $index.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            Add-FingerprintText $relativePath
            $hash.AppendData([System.IO.File]::ReadAllBytes($path))
            $hash.AppendData([byte[]]@(0))
        }

        return [Convert]::ToHexString($hash.GetHashAndReset())
    } finally {
        $hash.Dispose()
    }
}

function Test-NativeExactFixtureInputReceipt {
    param(
        [Parameter(Mandatory)][string]$Fingerprint,
        [Parameter(Mandatory)][string]$ReceiptPath
    )

    if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) {
        return $false
    }

    $recorded = [System.IO.File]::ReadAllText($ReceiptPath).Trim()
    return $recorded -cmatch '^[0-9A-F]{64}$' -and $recorded -ceq $Fingerprint
}

function Write-NativeExactFixtureInputReceipt {
    param(
        [Parameter(Mandatory)][string]$Fingerprint,
        [Parameter(Mandatory)][string]$ReceiptPath
    )

    if ($Fingerprint -cnotmatch '^[0-9A-F]{64}$') {
        throw "Native exact input fingerprint must be an uppercase SHA-256 value"
    }

    $directory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($ReceiptPath))
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidatePath = "$ReceiptPath.$([guid]::NewGuid().ToString('N')).candidate"
    try {
        [System.IO.File]::WriteAllText($candidatePath, $Fingerprint)
        [System.IO.File]::Move($candidatePath, $ReceiptPath, $true)
    } finally {
        Remove-Item -LiteralPath $candidatePath -ErrorAction SilentlyContinue
    }
}

function Test-NativeExactFixtureReceipt {
    param(
        [Parameter(Mandatory)][string]$InputFingerprint,
        [Parameter(Mandatory)][string]$InputReceiptPath,
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$OutputReceiptPath
    )

    return (Test-NativeExactFixtureInputReceipt `
            -Fingerprint $InputFingerprint `
            -ReceiptPath $InputReceiptPath) -and
        (Test-Stage2ArtifactReceipt `
            -LlvmPath $LlvmPath `
            -BitcodePath $BitcodePath `
            -ExecutablePath $ExecutablePath `
            -ReceiptPath $OutputReceiptPath)
}

function Publish-NativeExactFixtureReceipt {
    param(
        [Parameter(Mandatory)][string]$InputFingerprint,
        [Parameter(Mandatory)][string]$InputReceiptPath,
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$OutputReceiptPath
    )

    # The input receipt is the commit marker. Publishing it last prevents a
    # canceled verification from authenticating a partially written output set.
    Write-Stage2ArtifactReceipt `
        -LlvmPath $LlvmPath `
        -BitcodePath $BitcodePath `
        -ExecutablePath $ExecutablePath `
        -ReceiptPath $OutputReceiptPath
    Write-NativeExactFixtureInputReceipt `
        -Fingerprint $InputFingerprint `
        -ReceiptPath $InputReceiptPath
}
