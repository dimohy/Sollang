[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot "native-exact-fixture-receipt.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $PSScriptRoot "contracts\native-exact-fixture-receipt.json"
$testRoot = Join-Path $repoRoot "artifacts\native-exact-fixture-receipt-test-$([guid]::NewGuid().ToString('N'))"
$firstPath = Join-Path $testRoot "first.slg"
$secondPath = Join-Path $testRoot "second.txt"
$receiptPath = Join-Path $testRoot "fixture.inputs.sha256"
$outputReceiptPath = Join-Path $testRoot "fixture.outputs.sha256"
$llvmPath = Join-Path $testRoot "fixture.ll"
$bitcodePath = Join-Path $testRoot "fixture.bc"
$executablePath = Join-Path $testRoot "fixture.exe"
$closureRoot = Join-Path $testRoot "closure"
$fakeLlvmRoot = Join-Path $testRoot "llvm"

try {
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    if ($contract.schemaVersion -ne 1 -or
        $contract.executionContract.optionalArgumentsSuffix -cne ".args.txt" -or
        $contract.executionContract.argumentsEncoding -cne "UTF-8" -or
        $contract.executionContract.argumentsFormat -cne "one-argument-per-line-preserve-empty-lines" -or
        -not $contract.executionContract.argumentsAffectInputFingerprint -or
        -not $contract.executionContract.rejectArgumentsPresenceChangeDuringVerification -or
        $contract.executionContract.requiredExitCode -ne 0 -or
        $contract.executionContract.requiredStderr -cne "empty" -or
        $contract.inputIdentity.contentAlgorithm -cne "SHA-256" -or
        $contract.outputIdentity.contentAlgorithm -cne "SHA-256" -or
        -not $contract.fingerprintLayers.commonOncePerBatch.Contains("stdlibSourceClosure") -or
        -not $contract.fingerprintLayers.perFixture.Contains("commonFingerprint") -or
        $contract.platformEnvironment.windows.contentHashedTools.Count -ne 5 -or
        -not $contract.platformEnvironment.windows.contentHashedTools.Contains("clang.exe") -or
        -not $contract.platformEnvironment.windows.contentHashedTools.Contains("llvm-split.exe") -or
        -not $contract.platformEnvironment.windows.contentHashedTools.Contains("llvm-lib.exe") -or
        -not $contract.platformEnvironment.windows.contentHashedTools.Contains("lld-link.exe") -or
        $contract.platformEnvironment.linux.unidentifiedEnvironmentPolicy -cne "rebuild" -or
        $contract.publicationOrder[-1] -cne "publish-input-receipt-as-commit-marker" -or
        -not $contract.reuseRules.Contains("execute-cached-binary-and-compare-exact-output")) {
        throw "native exact fixture receipt contract is incomplete or incompatible"
    }

    Assert-NativeExactFixturePlan -Fixture @("one", "two")
    $duplicateFixtureRejected = $false
    try {
        Assert-NativeExactFixturePlan -Fixture @("same", "SAME")
    } catch {
        $duplicateFixtureRejected = $_.Exception.Message -match "exactly one writer"
    }
    if (-not $duplicateFixtureRejected) {
        throw "native exact fixture plan accepted duplicate output writers"
    }

    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $closureRoot "nested")) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $fakeLlvmRoot "bin")) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $closureRoot "z.slg"), "z")
    [System.IO.File]::WriteAllText((Join-Path $closureRoot "a.slg"), "a")
    [System.IO.File]::WriteAllText((Join-Path $closureRoot "nested\b.slg"), "b")
    [System.IO.File]::WriteAllText((Join-Path $closureRoot "ignored.txt"), "ignored")
    $orderedClosure = @(Get-NativeExactOrderedSourceClosure -Root $closureRoot)
    $orderedRelativeClosure = @($orderedClosure | ForEach-Object {
        [System.IO.Path]::GetRelativePath($closureRoot, $_).Replace('\', '/')
    })
    if (($orderedRelativeClosure -join ",") -cne "a.slg,nested/b.slg,z.slg") {
        throw "native exact source closure is not ordinal and SLG-only: $($orderedRelativeClosure -join ',')"
    }
    [System.IO.File]::WriteAllText($firstPath, "first")
    [System.IO.File]::WriteAllText($secondPath, "second")
    [System.IO.File]::WriteAllText($llvmPath, "llvm")

    [System.IO.File]::WriteAllText($bitcodePath, "bitcode")
    [System.IO.File]::WriteAllText($executablePath, "executable")
    foreach ($toolName in $contract.platformEnvironment.windows.contentHashedTools) {
        [System.IO.File]::WriteAllText((Join-Path $fakeLlvmRoot "bin\$toolName"), $toolName)
    }
    $commonFingerprint = Get-NativeExactWindowsCommonInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CompilerPath $executablePath `
        -StdlibRoot $closureRoot `
        -LlvmRoot $fakeLlvmRoot
    if ($commonFingerprint -cnotmatch '^[0-9A-F]{64}$') {
        throw "native exact Windows common fingerprint is not SHA-256"
    }
    [System.IO.File]::WriteAllText((Join-Path $fakeLlvmRoot "bin\clang.exe"), "mutated clang")
    $mutatedCommonFingerprint = Get-NativeExactWindowsCommonInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CompilerPath $executablePath `
        -StdlibRoot $closureRoot `
        -LlvmRoot $fakeLlvmRoot
    if ($mutatedCommonFingerprint -ceq $commonFingerprint) {
        throw "native exact Windows common fingerprint ignored a linker tool mutation"
    }
    $perFixtureFingerprint = Get-NativeExactPerFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CommonFingerprint $commonFingerprint `
        -Fixture "receipt-contract" `
        -Label "stage1-seed" `
        -Platform "windows" `
        -Distribution "" `
        -Jobs 2 `
        -ExpectedStdoutLength 0 `
        -InputPath @($firstPath, $secondPath)
    $changedCommonPerFixtureFingerprint = Get-NativeExactPerFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CommonFingerprint $mutatedCommonFingerprint `
        -Fixture "receipt-contract" `
        -Label "stage1-seed" `
        -Platform "windows" `
        -Distribution "" `
        -Jobs 2 `
        -ExpectedStdoutLength 0 `
        -InputPath @($firstPath, $secondPath)
    if ($perFixtureFingerprint -cnotmatch '^[0-9A-F]{64}$' -or
        $changedCommonPerFixtureFingerprint -ceq $perFixtureFingerprint) {
        throw "native exact per-fixture fingerprint is invalid or ignores its common identity"
    }
    $settings = [ordered]@{
        fixture = "receipt-contract"
        jobs = "2"
        nativeJobLimit = ""
        platform = "windows"
    }
    $inputPaths = @($firstPath, $secondPath)
    $emptySettingsRejected = $false
    try {
        Get-NativeExactFixtureInputFingerprint `
            -RepositoryRoot $repoRoot `
            -Settings @{} `
            -InputPath $inputPaths | Out-Null
    } catch {
        $emptySettingsRejected = $_.Exception.Message -match "at least one setting"
    }
    if (-not $emptySettingsRejected) {
        throw "native exact input fingerprint accepted empty settings"
    }

    $emptyInputsRejected = $false
    try {
        Get-NativeExactFixtureInputFingerprint `
            -RepositoryRoot $repoRoot `
            -Settings $settings `
            -InputPath @() | Out-Null
    } catch {
        $emptyInputsRejected = $true
    }
    if (-not $emptyInputsRejected) {
        throw "native exact input fingerprint accepted an empty input file set"
    }

    $fingerprint = Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Settings $settings `
        -InputPath $inputPaths
    $reorderedSettings = [ordered]@{
        platform = "windows"
        fixture = "receipt-contract"
        nativeJobLimit = ""
        jobs = "2"
    }
    $reorderedSettingsFingerprint = Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Settings $reorderedSettings `
        -InputPath $inputPaths
    if ($reorderedSettingsFingerprint -cne $fingerprint) {
        throw "native exact input fingerprint depends on setting insertion order"
    }
    $configuredNativeJobsSettings = [ordered]@{
        fixture = "receipt-contract"
        jobs = "2"
        nativeJobLimit = "4"
        platform = "windows"
    }
    $configuredNativeJobsFingerprint = Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Settings $configuredNativeJobsSettings `
        -InputPath $inputPaths
    if ($configuredNativeJobsFingerprint -ceq $fingerprint) {
        throw "native exact input fingerprint does not distinguish an unset and configured native job limit"
    }

    if (Test-NativeExactFixtureInputReceipt -Fingerprint $fingerprint -ReceiptPath $receiptPath) {
        throw "missing native exact input receipt was accepted"
    }

    Publish-NativeExactFixtureReceipt `
        -InputFingerprint $fingerprint `
        -InputReceiptPath $receiptPath `
        -LlvmPath $llvmPath `
        -BitcodePath $bitcodePath `
        -ExecutablePath $executablePath `
        -OutputReceiptPath $outputReceiptPath
    if (-not (Test-NativeExactFixtureReceipt `
            -InputFingerprint $fingerprint `
            -InputReceiptPath $receiptPath `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -OutputReceiptPath $outputReceiptPath)) {
        throw "fresh native exact input/output receipt was rejected"
    }

    Remove-Item -LiteralPath $outputReceiptPath
    if (Test-NativeExactFixtureReceipt `
            -InputFingerprint $fingerprint `
            -InputReceiptPath $receiptPath `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -OutputReceiptPath $outputReceiptPath) {
        throw "native exact input receipt without an output receipt was accepted"
    }
    Write-Stage2ArtifactReceipt `
        -LlvmPath $llvmPath `
        -BitcodePath $bitcodePath `
        -ExecutablePath $executablePath `
        -ReceiptPath $outputReceiptPath

    [System.IO.File]::WriteAllText($firstPath, "mutated")
    $mutatedInputFingerprint = Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Settings $settings `
        -InputPath $inputPaths
    if (Test-NativeExactFixtureInputReceipt -Fingerprint $mutatedInputFingerprint -ReceiptPath $receiptPath) {
        throw "mutated native exact input was accepted"
    }

    [System.IO.File]::WriteAllText($firstPath, "first")
    $mutatedSettings = [ordered]@{
        fixture = "receipt-contract"
        jobs = "3"
        nativeJobLimit = ""
        platform = "windows"
    }
    $mutatedSettingFingerprint = Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Settings $mutatedSettings `
        -InputPath $inputPaths
    if (Test-NativeExactFixtureInputReceipt -Fingerprint $mutatedSettingFingerprint -ReceiptPath $receiptPath) {
        throw "mutated native exact setting was accepted"
    }

    $reorderedFingerprint = Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Settings $settings `
        -InputPath @($secondPath, $firstPath)
    if (Test-NativeExactFixtureInputReceipt -Fingerprint $reorderedFingerprint -ReceiptPath $receiptPath) {
        throw "reordered native exact inputs were accepted"
    }

    [System.IO.File]::WriteAllText($llvmPath, "mutated llvm")
    if (Test-NativeExactFixtureReceipt `
            -InputFingerprint $fingerprint `
            -InputReceiptPath $receiptPath `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -OutputReceiptPath $outputReceiptPath) {
        throw "mutated native exact output was accepted"
    }
    [System.IO.File]::WriteAllText($llvmPath, "llvm")

    Remove-Item -LiteralPath $receiptPath
    [System.IO.File]::WriteAllText("$receiptPath.candidate", $fingerprint)
    if (Test-NativeExactFixtureReceipt `
            -InputFingerprint $fingerprint `
            -InputReceiptPath $receiptPath `
            -LlvmPath $llvmPath `
            -BitcodePath $bitcodePath `
            -ExecutablePath $executablePath `
            -OutputReceiptPath $outputReceiptPath) {
        throw "unpublished native exact input receipt candidate was accepted"
    }

    Write-Host "[native exact receipt] PASS schema v$($contract.schemaVersion), unique writer plan, layered Windows common/per-fixture identity, deterministic source closure/settings, positive, nonempty identity, missing input/output receipt, mutated-input, mutated-setting, reordered-input, mutated-output, and unpublished-candidate contracts."
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
