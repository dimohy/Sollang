[CmdletBinding()]
param(
    [string]$InstallRoot = "P:\Utils\sollang",
    [string]$Stage3Path,
    [string]$LinuxStage3Path,
    [string]$BrowserStage2Compiler,
    [string]$LlvmRoot,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "verified-install-scope.ps1")
. (Join-Path $PSScriptRoot "selfhost-verification-lock.ps1")

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$InstallRoot = Assert-SafeVerifiedInstallRoot $InstallRoot $RepositoryRoot
if ([string]::IsNullOrWhiteSpace($Stage3Path)) {
    $Stage3Path = Join-Path $RepositoryRoot "artifacts\example-tests\selfhost-stage3.exe"
}
if ([string]::IsNullOrWhiteSpace($LinuxStage3Path)) {
    $LinuxStage3Path = Join-Path $RepositoryRoot "artifacts\example-tests\selfhost-stage3-linux"
}
if ([string]::IsNullOrWhiteSpace($BrowserStage2Compiler)) {
    $BrowserStage2Compiler = Join-Path $RepositoryRoot "artifacts\example-tests\selfhost-stage2.exe"
}
if ([string]::IsNullOrWhiteSpace($LlvmRoot)) {
    $LlvmRoot = Join-Path $RepositoryRoot ".tools\llvm-22.1.8"
}
$Stage3Path = [System.IO.Path]::GetFullPath($Stage3Path)
$LinuxStage3Path = [System.IO.Path]::GetFullPath($LinuxStage3Path)
$BrowserStage2Compiler = [System.IO.Path]::GetFullPath($BrowserStage2Compiler)
$LlvmRoot = [System.IO.Path]::GetFullPath($LlvmRoot)
$sourceStdlibRoot = Join-Path $RepositoryRoot "stdlib"
$receiptSchemaPath = Join-Path $PSScriptRoot "contracts\sollang-verified-install.schema.json"
$smokeSource = Join-Path $RepositoryRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-single-smoke.slg"
$browserWasmPath = Join-Path $RepositoryRoot "artifacts\sollangc-browser.wasm"
$browserInputFingerprintPath = Join-Path $RepositoryRoot "artifacts\sollangc-browser.inputs.sha256"
$installParent = [System.IO.Path]::GetDirectoryName($InstallRoot)
$transactionNonce = "transaction"
$runNonce = [guid]::NewGuid().ToString("N")
$stagingRoot = New-VerifiedInstallSiblingPath $InstallRoot "install" $transactionNonce
$backupRoot = New-VerifiedInstallSiblingPath $InstallRoot "backup" $transactionNonce
$swapped = $false
$completed = $false

function Get-TreeManifest {
    param([Parameter(Mandatory)][string]$Root)

    $absoluteRoot = [System.IO.Path]::GetFullPath($Root)
    if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) {
        throw "Manifest root is missing: $absoluteRoot"
    }
    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $entries = @(
        Get-ChildItem -LiteralPath $absoluteRoot -Recurse -File |
            ForEach-Object {
                $relative = [System.IO.Path]::GetRelativePath($absoluteRoot, $_.FullName).Replace("\", "/")
                [pscustomobject]@{
                    Path = $relative
                    Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                }
            } |
            Sort-Object Path
    )
    foreach ($entry in $entries) {
        $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$($entry.Path)`0"))
        $hash.AppendData([Convert]::FromHexString($entry.Hash))
    }
    [pscustomobject]@{
        Entries = $entries
        Hash = [Convert]::ToHexString($hash.GetHashAndReset())
    }
}

function Assert-TreeManifestEqual {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual,
        [Parameter(Mandatory)][string]$Description
    )

    if ($Expected.Hash -cne $Actual.Hash -or $Expected.Entries.Count -ne $Actual.Entries.Count) {
        throw "$Description differs: expected $($Expected.Entries.Count) files/$($Expected.Hash), actual $($Actual.Entries.Count) files/$($Actual.Hash)"
    }
    for ($index = 0; $index -lt $Expected.Entries.Count; $index += 1) {
        if ($Expected.Entries[$index].Path -cne $Actual.Entries[$index].Path -or
            $Expected.Entries[$index].Hash -cne $Actual.Entries[$index].Hash) {
            throw "$Description first mismatch at index $index`: expected $($Expected.Entries[$index].Path)/$($Expected.Entries[$index].Hash), actual $($Actual.Entries[$index].Path)/$($Actual.Entries[$index].Hash)"
        }
    }
}

function Assert-CompilerVersion {
    param(
        [Parameter(Mandatory)][string]$Compiler,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [Parameter(Mandatory)][string]$Description
    )

    $result = Invoke-VerificationProcess `
        -FilePath $Compiler `
        -ArgumentList @("--version") `
        -Description $Description `
        -TimeoutMilliseconds 60000
    if ($result.Stdout.Trim() -cne "Sollang $ExpectedVersion" -or
        -not [string]::IsNullOrWhiteSpace($result.Stderr)) {
        throw "$Description returned unexpected output: stdout='$($result.Stdout.Trim())', stderr='$($result.Stderr.Trim())'"
    }
}

function Write-VerifiedInstallReceipt {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$CompilerVersion,
        [Parameter(Mandatory)][string]$Stage3Fingerprint,
        [Parameter(Mandatory)][string]$LinuxStage3Fingerprint,
        [Parameter(Mandatory)][string]$BrowserStage2Fingerprint,
        [Parameter(Mandatory)][string]$BrowserInputFingerprint,
        [Parameter(Mandatory)]$StdlibManifest,
        [Parameter(Mandatory)][bool]$GlobalEnvironmentSmokeVerified
    )

    $receipt = [ordered]@{
        schemaVersion = 2
        mode = "verified-selfhost-stage3-install"
        producer = "install-verified-stage3.ps1"
        target = "windows"
        compilerVersion = $CompilerVersion
        installedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
        stage3Fingerprint = $Stage3Fingerprint
        linuxStage3Fingerprint = $LinuxStage3Fingerprint
        browserStage2Fingerprint = $BrowserStage2Fingerprint
        browserInputFingerprint = $BrowserInputFingerprint
        stdlibManifestFingerprint = $StdlibManifest.Hash
        stdlibFileCount = $StdlibManifest.Entries.Count
        stage3ArtifactsVerified = $true
        linuxStage3ArtifactsVerified = $true
        browserStage2ArtifactsVerified = $true
        stagedSmokeVerified = $true
        globalEnvironmentSmokeVerified = $GlobalEnvironmentSmokeVerified
    }
    $receiptJson = $receipt | ConvertTo-Json -Depth 4
    if (-not ($receiptJson | Test-Json -SchemaFile $receiptSchemaPath -ErrorAction Stop)) {
        throw "Generated install receipt does not satisfy $receiptSchemaPath"
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $Root "install.receipt.json"),
        $receiptJson,
        [System.Text.UTF8Encoding]::new($false))
}

function Test-FinalVerifiedInstallReceipt {
    param([Parameter(Mandatory)][string]$Root)

    $path = Join-Path $Root "install.receipt.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $false
    }
    try {
        $json = Get-Content -LiteralPath $path -Raw
        if (-not ($json | Test-Json -SchemaFile $receiptSchemaPath -ErrorAction Stop)) {
            return $false
        }
        return [bool](($json | ConvertFrom-Json).globalEnvironmentSmokeVerified)
    } catch {
        return $false
    }
}

function Invoke-InstalledSmoke {
    param(
        [Parameter(Mandatory)][string]$Compiler,
        [Parameter(Mandatory)][string]$StdlibRoot,
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][bool]$UseExplicitPaths
    )

    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    $smokeExecutable = Join-Path $OutputRoot "smoke.exe"
    $arguments = @("build", $smokeSource, "-o", $smokeExecutable, "--target", "windows-x64", "-O1")
    if ($UseExplicitPaths) {
        $arguments += @("--stdlib", $StdlibRoot, "--llvm", $LlvmRoot)
    }
    $build = Invoke-VerificationProcess `
        -FilePath $Compiler `
        -ArgumentList $arguments `
        -Description "verified Stage3 install smoke build" `
        -TimeoutMilliseconds 600000
    $diagnostics = $build.Stdout + $build.Stderr
    if ($diagnostics -match '(?m)^(warning S\d+|note N\d+)') {
        throw "verified Stage3 install smoke emitted a warning or note: $diagnostics"
    }
    $execution = Invoke-VerificationProcess `
        -FilePath $smokeExecutable `
        -Description "verified Stage3 install smoke execution" `
        -TimeoutMilliseconds 60000
    if ($execution.Stdout.Trim() -cne "stage2-single-ok" -or
        -not [string]::IsNullOrWhiteSpace($execution.Stderr)) {
        throw "verified Stage3 install smoke output mismatch: stdout='$($execution.Stdout.Trim())', stderr='$($execution.Stderr.Trim())'"
    }
}

function Assert-PlatformClosure {
    & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
        -Platform windows `
        -Stage3Path $Stage3Path `
        -RepositoryRoot $RepositoryRoot
    & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
        -Platform linux `
        -Stage3Path $LinuxStage3Path `
        -RepositoryRoot $RepositoryRoot
    & (Join-Path $PSScriptRoot "verify-browser-stage2-artifacts.ps1") `
        -Stage2Compiler $BrowserStage2Compiler `
        -RepositoryRoot $RepositoryRoot
}

if (-not (Test-Path -LiteralPath $Stage3Path -PathType Leaf)) {
    throw "Verified Windows Stage3 compiler is missing: $Stage3Path"
}
if (-not (Test-Path -LiteralPath $LinuxStage3Path -PathType Leaf)) {
    throw "Verified Linux Stage3 compiler is missing: $LinuxStage3Path"
}
if (-not (Test-Path -LiteralPath $LlvmRoot -PathType Container)) {
    throw "LLVM root is missing: $LlvmRoot"
}
New-Item -ItemType Directory -Path $installParent -Force | Out-Null

$versionSource = [System.IO.File]::ReadAllText((Join-Path $RepositoryRoot "selfhost\compiler_version.slg"))
$versionMatch = [regex]::Match($versionSource, 'public\s+current\s*:\s*->\s*Text\s*=>\s*"(?<version>\d+\.\d+\.\d+)"')
if (-not $versionMatch.Success) {
    throw "Canonical compiler version is missing from selfhost/compiler_version.slg"
}
$version = $versionMatch.Groups["version"].Value

$selfHostVerificationLock = Enter-SelfHostVerificationLock
try {
    Write-Host "[verified install recovery] Resolve any interrupted prior transaction."
    if (Test-Path -LiteralPath $backupRoot) {
        if (-not (Test-Path -LiteralPath $InstallRoot)) {
            Move-Item -LiteralPath $backupRoot -Destination $InstallRoot
        } elseif (Test-FinalVerifiedInstallReceipt $InstallRoot) {
            Remove-VerifiedInstallSibling $InstallRoot $backupRoot
        } else {
            Remove-Item -LiteralPath $InstallRoot -Recurse -Force
            Move-Item -LiteralPath $backupRoot -Destination $InstallRoot
        }
    }
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-VerifiedInstallSibling $InstallRoot $stagingRoot
    }
    if ((Test-Path -LiteralPath $stagingRoot) -or (Test-Path -LiteralPath $backupRoot)) {
        throw "Interrupted install transaction could not be recovered cleanly"
    }

    Write-Host "[verified install 1/6] Verify current Windows, Linux, and browser platform closure."
    Assert-PlatformClosure
    $stage3Hash = (Get-FileHash -LiteralPath $Stage3Path -Algorithm SHA256).Hash
    $linuxStage3Hash = (Get-FileHash -LiteralPath $LinuxStage3Path -Algorithm SHA256).Hash
    $browserStage2Hash = (Get-FileHash -LiteralPath $browserWasmPath -Algorithm SHA256).Hash
    $browserInputFingerprint = [System.IO.File]::ReadAllText($browserInputFingerprintPath).Trim()
    $sourceStdlibManifest = Get-TreeManifest $sourceStdlibRoot

    Write-Host "[verified install 2/6] Stage compiler and exact standard library."
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
    Copy-Item -LiteralPath $Stage3Path -Destination (Join-Path $stagingRoot "sollang.exe")
    Copy-Item -LiteralPath $sourceStdlibRoot -Destination (Join-Path $stagingRoot "stdlib") -Recurse
    $stagedCompilerHash = (Get-FileHash -LiteralPath (Join-Path $stagingRoot "sollang.exe") -Algorithm SHA256).Hash
    if ($stagedCompilerHash -cne $stage3Hash) {
        throw "Staged compiler differs from verified Stage3: expected $stage3Hash, actual $stagedCompilerHash"
    }
    Assert-TreeManifestEqual $sourceStdlibManifest (Get-TreeManifest (Join-Path $stagingRoot "stdlib")) "staged standard library"
    Write-Host "[verified install 3/6] Verify staged version and explicit-path smoke."
    Assert-CompilerVersion (Join-Path $stagingRoot "sollang.exe") $version "staged compiler version"
    $preSwapSmoke = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-install-stage-" + $runNonce)
    try {
        Invoke-InstalledSmoke (Join-Path $stagingRoot "sollang.exe") (Join-Path $stagingRoot "stdlib") $preSwapSmoke $true
    } finally {
        if (Test-Path -LiteralPath $preSwapSmoke) {
            Remove-Item -LiteralPath $preSwapSmoke -Recurse -Force
        }
    }
    Write-VerifiedInstallReceipt `
        -Root $stagingRoot `
        -CompilerVersion $version `
        -Stage3Fingerprint $stage3Hash `
        -LinuxStage3Fingerprint $linuxStage3Hash `
        -BrowserStage2Fingerprint $browserStage2Hash `
        -BrowserInputFingerprint $browserInputFingerprint `
        -StdlibManifest $sourceStdlibManifest `
        -GlobalEnvironmentSmokeVerified $false

    Write-Host "[verified install 4/6] Recheck immutable inputs immediately before atomic replacement."
    Assert-PlatformClosure
    if ((Get-FileHash -LiteralPath $Stage3Path -Algorithm SHA256).Hash -cne $stage3Hash) {
        throw "Verified Stage3 changed while the installation was staged"
    }
    if ((Get-FileHash -LiteralPath $LinuxStage3Path -Algorithm SHA256).Hash -cne $linuxStage3Hash) {
        throw "Verified Linux Stage3 changed while the installation was staged"
    }
    if ((Get-FileHash -LiteralPath $browserWasmPath -Algorithm SHA256).Hash -cne $browserStage2Hash -or
        [System.IO.File]::ReadAllText($browserInputFingerprintPath).Trim() -cne $browserInputFingerprint) {
        throw "Verified browser Stage2 changed while the installation was staged"
    }
    Assert-TreeManifestEqual $sourceStdlibManifest (Get-TreeManifest $sourceStdlibRoot) "source standard library during installation"

    Write-Host "[verified install 5/6] Atomically replace the install root with rollback protection."
    if (Test-Path -LiteralPath $InstallRoot) {
        Move-Item -LiteralPath $InstallRoot -Destination $backupRoot
    }
    Move-Item -LiteralPath $stagingRoot -Destination $InstallRoot
    $swapped = $true

    Write-Host "[verified install 6/6] Verify the real global path with environment-only LLVM discovery."
    if ((Get-FileHash -LiteralPath (Join-Path $InstallRoot "sollang.exe") -Algorithm SHA256).Hash -cne $stage3Hash) {
        throw "Installed compiler differs from verified Stage3"
    }
    Assert-TreeManifestEqual $sourceStdlibManifest (Get-TreeManifest (Join-Path $InstallRoot "stdlib")) "installed standard library"
    $rootEntries = @(Get-ChildItem -LiteralPath $InstallRoot | ForEach-Object { $_.Name } | Sort-Object)
    if (($rootEntries -join "`n") -cne ((@("install.receipt.json", "sollang.exe", "stdlib") | Sort-Object) -join "`n")) {
        throw "Installed root contains unexpected entries: $($rootEntries -join ', ')"
    }
    Assert-CompilerVersion (Join-Path $InstallRoot "sollang.exe") $version "installed compiler version"
    $savedLlvmHome = $env:SOLLANG_LLVM_HOME
    $postSwapSmoke = Join-Path ([System.IO.Path]::GetTempPath()) ("sollang-install-global-" + $runNonce)
    try {
        $env:SOLLANG_LLVM_HOME = $LlvmRoot
        Invoke-InstalledSmoke (Join-Path $InstallRoot "sollang.exe") (Join-Path $InstallRoot "stdlib") $postSwapSmoke $false
    } finally {
        $env:SOLLANG_LLVM_HOME = $savedLlvmHome
        if (Test-Path -LiteralPath $postSwapSmoke) {
            Remove-Item -LiteralPath $postSwapSmoke -Recurse -Force
        }
    }
    Write-VerifiedInstallReceipt `
        -Root $InstallRoot `
        -CompilerVersion $version `
        -Stage3Fingerprint $stage3Hash `
        -LinuxStage3Fingerprint $linuxStage3Hash `
        -BrowserStage2Fingerprint $browserStage2Hash `
        -BrowserInputFingerprint $browserInputFingerprint `
        -StdlibManifest $sourceStdlibManifest `
        -GlobalEnvironmentSmokeVerified $true
    if (-not (Test-FinalVerifiedInstallReceipt $InstallRoot)) {
        throw "Installed receipt does not bind the verified compiler, standard library, and global smoke"
    }

    $completed = $true
    if (Test-Path -LiteralPath $backupRoot) {
        Remove-VerifiedInstallSibling $InstallRoot $backupRoot
    }
    Write-Host "[verified install complete] $InstallRoot; compiler $stage3Hash; stdlib $($sourceStdlibManifest.Entries.Count) files/$($sourceStdlibManifest.Hash)."
} catch {
    $failure = $_
    if (-not $completed) {
        if ($swapped -and (Test-Path -LiteralPath $InstallRoot)) {
            Remove-Item -LiteralPath $InstallRoot -Recurse -Force
        }
        if (Test-Path -LiteralPath $backupRoot) {
            Move-Item -LiteralPath $backupRoot -Destination $InstallRoot
        }
    }
    throw $failure
} finally {
    try {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-VerifiedInstallSibling $InstallRoot $stagingRoot
        }
        if (-not $completed -and (Test-Path -LiteralPath $backupRoot) -and -not (Test-Path -LiteralPath $InstallRoot)) {
            Move-Item -LiteralPath $backupRoot -Destination $InstallRoot
        }
    } finally {
        Release-SelfHostVerificationLock $selfHostVerificationLock
    }
}
