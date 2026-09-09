$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verified-install-scope.ps1")

$installerPath = Join-Path $PSScriptRoot "install-verified-stage3.ps1"
$installer = [System.IO.File]::ReadAllText($installerPath)
$receiptSchemaPath = Join-Path $PSScriptRoot "contracts\sollang-verified-install.schema.json"
foreach ($required in @(
    'verify-selfhost-stage3-artifacts.ps1',
    'verify-browser-stage2-artifacts.ps1',
    'Assert-PlatformClosure',
    '-Platform linux',
    'Get-TreeManifest',
    'Assert-TreeManifestEqual',
    'install.receipt.json',
    'Installed receipt does not bind the verified compiler, standard library, and global smoke',
    'Move-Item -LiteralPath $InstallRoot -Destination $backupRoot',
    'Move-Item -LiteralPath $stagingRoot -Destination $InstallRoot',
    'SOLLANG_LLVM_HOME',
    'Invoke-InstalledSmoke',
    'Remove-VerifiedInstallSibling',
    'Enter-SelfHostVerificationLock',
    'Test-FinalVerifiedInstallReceipt',
    'Interrupted install transaction could not be recovered cleanly',
    'contracts\sollang-verified-install.schema.json',
    'linuxStage3Fingerprint',
    'browserStage2Fingerprint',
    'browserInputFingerprint'
)) {
    if (-not $installer.Contains($required)) {
        throw "verified Stage3 installer contract is missing: $required"
    }
}
if ([regex]::Matches($installer, 'Assert-PlatformClosure').Count -ne 3) {
    throw "verified Stage3 installer must define platform closure once and invoke it before staging and replacement"
}
if ($installer -match 'Remove-Item\s+-LiteralPath\s+\$installParent\s+-Recurse') {
    throw "verified Stage3 installer may not recursively remove its parent directory"
}
if ($installer -notmatch '(?s)\$completed = \$true.*?Remove-VerifiedInstallSibling \$InstallRoot \$backupRoot.*?catch.*?if \(-not \$completed\)') {
    throw "verified Stage3 installer does not preserve a verified new install when only backup cleanup fails"
}

$validReceipt = [ordered]@{
    schemaVersion = 2
    mode = "verified-selfhost-stage3-install"
    producer = "install-verified-stage3.ps1"
    target = "windows"
    compilerVersion = "0.4.0"
    installedAtUtc = "2026-08-28T00:00:00.0000000+00:00"
    stage3Fingerprint = "A" * 64
    linuxStage3Fingerprint = "C" * 64
    browserStage2Fingerprint = "D" * 64
    browserInputFingerprint = "E" * 64
    stdlibManifestFingerprint = "B" * 64
    stdlibFileCount = 95
    stage3ArtifactsVerified = $true
    linuxStage3ArtifactsVerified = $true
    browserStage2ArtifactsVerified = $true
    stagedSmokeVerified = $true
    globalEnvironmentSmokeVerified = $true
} | ConvertTo-Json
if (-not ($validReceipt | Test-Json -SchemaFile $receiptSchemaPath -ErrorAction Stop)) {
    throw "verified install receipt schema rejected its positive control"
}
$invalidReceipt = $validReceipt | ConvertFrom-Json
$invalidReceipt.PSObject.Properties.Remove("globalEnvironmentSmokeVerified")
$invalidAccepted = $false
try {
    $invalidAccepted = ($invalidReceipt | ConvertTo-Json | Test-Json -SchemaFile $receiptSchemaPath -ErrorAction Stop)
} catch {
    $invalidAccepted = $false
}
if ($invalidAccepted) {
    throw "verified install receipt schema accepted a receipt without global smoke evidence"
}
$missingPlatformReceipt = $validReceipt | ConvertFrom-Json
$missingPlatformReceipt.PSObject.Properties.Remove("browserStage2ArtifactsVerified")
$missingPlatformAccepted = $false
try {
    $missingPlatformAccepted = ($missingPlatformReceipt | ConvertTo-Json | Test-Json -SchemaFile $receiptSchemaPath -ErrorAction Stop)
} catch {
    $missingPlatformAccepted = $false
}
if ($missingPlatformAccepted) {
    throw "verified install receipt schema accepted a receipt without browser platform evidence"
}

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("sollang-install-scope-contract-" + [guid]::NewGuid().ToString("N"))))
try {
    $repositoryRoot = Join-Path $temporaryRoot "repo"
    $installRoot = Join-Path $temporaryRoot "utils\sollang"
    New-Item -ItemType Directory -Force -Path $repositoryRoot, $installRoot | Out-Null
    $validated = Assert-SafeVerifiedInstallRoot $installRoot $repositoryRoot
    $nonce = "abc123"
    $staging = New-VerifiedInstallSiblingPath $validated "install" $nonce
    $backup = New-VerifiedInstallSiblingPath $validated "backup" $nonce
    New-Item -ItemType Directory -Force -Path $staging, $backup | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $staging "owned.txt"), "owned")
    [System.IO.File]::WriteAllText((Join-Path $backup "owned.txt"), "owned")
    Remove-VerifiedInstallSibling $validated $staging
    Remove-VerifiedInstallSibling $validated $backup
    if ((Test-Path -LiteralPath $staging) -or (Test-Path -LiteralPath $backup)) {
        throw "verified install cleanup retained an owned sibling"
    }
    if (-not (Test-Path -LiteralPath $validated)) {
        throw "verified install cleanup removed the install root"
    }

    $siblingRejected = $false
    try { Remove-VerifiedInstallSibling $validated $repositoryRoot } catch { $siblingRejected = $true }
    if (-not $siblingRejected) { throw "verified install cleanup accepted an unrelated sibling" }
    $repoRejected = $false
    try { Assert-SafeVerifiedInstallRoot $repositoryRoot $repositoryRoot | Out-Null } catch { $repoRejected = $true }
    if (-not $repoRejected) { throw "verified install root accepted the repository" }
    $repoChildRejected = $false
    try { Assert-SafeVerifiedInstallRoot (Join-Path $repositoryRoot "install") $repositoryRoot | Out-Null } catch { $repoChildRejected = $true }
    if (-not $repoChildRejected) { throw "verified install root accepted a repository child" }
    if ($IsWindows) {
        $repoCaseRejected = $false
        try { Assert-SafeVerifiedInstallRoot $repositoryRoot.ToUpperInvariant() $repositoryRoot | Out-Null } catch { $repoCaseRejected = $true }
        if (-not $repoCaseRejected) { throw "verified install root accepted a case-variant repository path" }
    }
    $volumeRejected = $false
    try { Assert-SafeVerifiedInstallRoot ([System.IO.Path]::GetPathRoot($temporaryRoot)) $repositoryRoot | Out-Null } catch { $volumeRejected = $true }
    if (-not $volumeRejected) { throw "verified install root accepted a volume root" }

    Write-Host "[verified Stage3 install contract] PASS three-platform provenance recheck, exact-manifest, atomic swap, rollback, environment-only smoke, and path-scope controls."
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
