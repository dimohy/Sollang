param(
    [switch]$Rebuild,
    [ValidateSet("Slg", "Stage2Bridge", "ManagedRecovery")]
    [string]$SeedMode = "Slg",
    [string]$SlgSeedCompiler = "",
    [ValidateRange(1, 64)]
    [int]$Stage2BuildJobs = 8,
    [switch]$ResumeCandidate
)

$ErrorActionPreference = "Stop"
if ($Rebuild -and $ResumeCandidate) {
    throw "-Rebuild and -ResumeCandidate are mutually exclusive"
}

. (Join-Path $PSScriptRoot "selfhost-verification-lock.ps1")
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "stage3-seed-provenance.ps1")
. (Join-Path $PSScriptRoot "input-fingerprint-stability.ps1")
. (Join-Path $PSScriptRoot "verification-process.ps1")
$selfHostVerificationLock = Enter-SelfHostVerificationLock
try {

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$runnerProject = Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$manifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$managedOraclePath = Join-Path $artifactsDir "selfhost-sollangc-driver.exe"
$stage1Path = Join-Path $artifactsDir "selfhost-stage1-verification.exe"
$defaultSlgSeedCompiler = Join-Path $repoRoot "artifacts\incremental-selfhost\selfhost-slg-seed.exe"
$stage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2.ll"
$stage2BitcodePath = Join-Path $artifactsDir "selfhost-stage2.bc"
$stage2Path = Join-Path $artifactsDir "selfhost-stage2.exe"
$stage2FingerprintPath = Join-Path $artifactsDir "selfhost-stage2.inputs.sha256"
$stage2ArtifactReceiptPath = Join-Path $artifactsDir "selfhost-stage2.outputs.sha256"
$publishedStage2LlvmPath = $stage2LlvmPath
$publishedStage2BitcodePath = $stage2BitcodePath
$publishedStage2Path = $stage2Path
$stage2WasRebuilt = $false
$stdlibRoot = Join-Path $repoRoot "stdlib"
$llvmDir = Join-Path $repoRoot ".tools\llvm-22.1.8"
$llvmAsPath = Join-Path $llvmDir "bin\llvm-as.exe"
$clangPath = Join-Path $llvmDir "bin\clang.exe"
$windowsRuntimeLibraries = @("-lshell32", "-lbcrypt", "-lws2_32")
$singleSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-single-smoke.slg"
$mouseEventSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-mouse-source.slg"
$multiLibrarySource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-library-smoke.slg"
$multiMainSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-main-smoke.slg"
$groupedNotSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-grouped-not-smoke.slg"
$fileIntrinsicsControlSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-file-intrinsics-control.slg"
$directoryCreateSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-directory-create.slg"
$pathNormalizeResultSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-path-normalize-result.slg"
$runtimeEprintlnSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\runtime-eprintln.slg"
$runtimeEprintlnInterpolationSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\runtime-eprintln-interpolation.slg"
$runtimeEprintlnSourceTextSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\runtime-eprintln-source-text.slg"
$runtimeIntrinsicAbiSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-runtime-intrinsic-abi-separation.slg"
$interpolationLengthSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-interpolation-len.slg"
$nestedUInt8IfSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-if-uint8-value.slg"
$unusedIfAssignmentSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-unused-if-assignment.slg"
$unusedMatchAssignmentSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-unused-match-assignment.slg"
$mutableResetAfterWhileSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-mutable-reset-after-while.slg"
$directPatternSecondArgumentSource = Join-Path $repoRoot "examples\regression\1016-selfhost-direct-pattern-second-argument.slg"
$directPatternSecondArgumentFixture = Join-Path $repoRoot "examples\regression\fixtures\1016-pattern-call-frame.slg"
$resultPropagationControlSource = Join-Path $repoRoot "examples\regression\1017-quic-friendly-ipv4-endpoints.slg"
$socketEndpointObservationSource = Join-Path $repoRoot "examples\regression\1117-socket-endpoint-observation.slg"
$socketNoDelaySource = Join-Path $repoRoot "examples\regression\1141-socket-no-delay-instance.slg"
$socketNoDelayExpected = Join-Path $repoRoot "examples\regression\expected\1141-socket-no-delay-instance.stdout.txt"
$subjectWhenDirectResultSource = Join-Path $repoRoot "examples\user\670-inclusive-and-half-open-ranges.slg"
$sequenceSource = Join-Path $repoRoot "stdlib\std\sequence.slg"
$sequenceRuntimeSource = Join-Path $repoRoot "stdlib\sys\runtime\sequence.slg"
$streamTableSource = Join-Path $repoRoot "examples\regression\576-linq-multiplication-table.slg"
$streamDeferredTextSource = Join-Path $repoRoot "examples\regression\580-deferred-text-evaluation.slg"
$streamSensorSource = Join-Path $repoRoot "examples\regression\582-billion-sensor-alerts.slg"
$streamStateSource = Join-Path $repoRoot "examples\regression\583-stream-state-take-skip.slg"
$streamRiskSource = Join-Path $repoRoot "examples\regression\585-stream-transaction-risk-scan.slg"
$streamPartitionSource = Join-Path $repoRoot "examples\user\797-partition-first-match-direct-dispatch.slg"
$borrowConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-conflict.slg"
$borrowUnionConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-union-conflict.slg"
$borrowAliasConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-alias-conflict.slg"
$borrowAggregateConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-aggregate-conflict.slg"
$borrowProjectionConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-projection-conflict.slg"
$partialMoveConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-partial-move-conflict.slg"
$branchPartialMoveConflictSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-branch-partial-move-conflict.slg"
$parallelMutableCaptureSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-parallel-mutable-capture.slg"
$parallelNonSendableCaptureSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-parallel-nonsendable-capture.slg"
$referenceTemporarySource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-temporary.slg"
$referenceLivenessSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-liveness.slg"
$referenceOwnerMoveSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-owner-move.slg"
$referenceLoopContinueSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-loop-continue.slg"
$referenceStoredStructSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-struct.slg"
$referenceAggregateEscapeSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-aggregate-escape.slg"
$referenceStoredEnumSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-enum.slg"
$referenceStoredArraySource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-array.slg"
$referenceEnumEscapeSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-enum-escape.slg"
$referenceArrayEscapeSource = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-array-escape.slg"
$borrowSourceRuntime = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-borrow-source.slg"
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$fingerprintSources = @(
    (Join-Path $repoRoot "examples\regression\fixtures\429-selfhost-root\Alpha.slg")
    (Join-Path $repoRoot "examples\regression\fixtures\429-selfhost-root\Zeta.slg")
    (Join-Path $repoRoot "examples\regression\fixtures\429-selfhost-root\nested\Beta.slg")
)
$semanticContextSource = Join-Path $repoRoot "selfhost\semantic\context.slg"
$compilerRuntimeSources = Get-Content $runtimeManifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_.Trim() }
$compilerSources = Get-Content $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
$expectedStage2Bytes = if (Test-Stage2ArtifactReceipt `
        -LlvmPath $stage2LlvmPath `
        -BitcodePath $stage2BitcodePath `
        -ExecutablePath $stage2Path `
        -ReceiptPath $stage2ArtifactReceiptPath) {
    (Get-Item -LiteralPath $stage2LlvmPath).Length
} else {
    29656847L
}
$expectedStage2Definitions = if (Test-Path -LiteralPath $stage2LlvmPath) {
    @((Select-String -LiteralPath $stage2LlvmPath -Pattern '^define\s')).Count
} else {
    0
}

& (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
    -Manifest @($manifestPath, $runtimeManifestPath) `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-compiler-contracts.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-quic-frame-consumers.ps1") -RepositoryRoot $repoRoot -Jobs 3
& (Join-Path $PSScriptRoot "verify-gzip-stream-api-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-zstd-foundation-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-brotli-foundation-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-body-framing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-portable-memory-io-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-response-writing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-request-writing-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-client-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-http-server-contract.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "show-project-progress.ps1") -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "format-authoritative-slg.ps1") -Check

New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null
& (Join-Path $PSScriptRoot "verify-stage2-artifact-receipt.ps1")

$semanticContextText = [System.IO.File]::ReadAllText($semanticContextSource)
if (-not $semanticContextText.Contains("public struct SemanticSnapshot") -or
    $semanticContextText.Contains("public struct CompilationContext")) {
    throw "semantic workers are not separated from construction by SemanticSnapshot"
}

function Invoke-ProcessToFile {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$OutputPath,
        [string]$ErrorPath
    )

    Remove-Item -LiteralPath $OutputPath, $ErrorPath -ErrorAction SilentlyContinue
    $startParameters = @{
        FilePath = $FilePath
        RedirectStandardOutput = $OutputPath
        RedirectStandardError = $ErrorPath
        PassThru = $true
        WindowStyle = "Hidden"
    }
    if ($ArgumentList.Count -gt 0) {
        $startParameters.ArgumentList = $ArgumentList
    }
    $process = Start-Process @startParameters
    $null = $process.Handle
    return $process
}

function Assert-ProcessSucceeded {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$ErrorPath,
        [string]$Description
    )

    Wait-VerificationProcess $Process $Description
    $Process.Refresh()
    if ($Process.ExitCode -ne 0) {
        $details = if (Test-Path $ErrorPath) { Get-Content $ErrorPath -Raw } else { "" }
        throw "$Description failed with exit code $($Process.ExitCode).`n$details"
    }
}

function Get-NormalizedHash {
    param([string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-ContentFingerprint {
    param([string[]]$Paths)

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    foreach ($path in $Paths) {
        $relative = [System.IO.Path]::GetRelativePath($repoRoot, $path).Replace("\", "/")
        $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes("$relative`0"))
        $hash.AppendData([System.IO.File]::ReadAllBytes($path))
    }
    return [Convert]::ToHexString($hash.GetHashAndReset())
}

function Get-Stage2InputFingerprint {
    $paths = @($stage1Path, $manifestPath, $runtimeManifestPath)
    $paths += $compilerSources
    $paths += $compilerRuntimeSources
    return Get-ContentFingerprint $paths
}

function Test-Stage2IsCurrent {
    if ($Rebuild -or
        -not (Test-Stage2ArtifactReceipt `
            -LlvmPath $stage2LlvmPath `
            -BitcodePath $stage2BitcodePath `
            -ExecutablePath $stage2Path `
            -ReceiptPath $stage2ArtifactReceiptPath)) {
        return $false
    }

    $current = Get-Stage2InputFingerprint
    return (Test-Path -LiteralPath $stage2FingerprintPath) -and
        [System.IO.File]::ReadAllText($stage2FingerprintPath).Trim() -ceq $current
}

if ($SeedMode -eq "Slg") {
    if ([string]::IsNullOrWhiteSpace($SlgSeedCompiler)) {
        $SlgSeedCompiler = $defaultSlgSeedCompiler
    }
    $SlgSeedCompiler = [System.IO.Path]::GetFullPath($SlgSeedCompiler)
    $slgSeedReceipt = [System.IO.Path]::ChangeExtension($SlgSeedCompiler, ".sha256")
    if (-not (Test-Path -LiteralPath $SlgSeedCompiler) -or
        (Get-Item -LiteralPath $SlgSeedCompiler).Length -eq 0) {
        throw "verified Stage 3 SLG seed is missing: $SlgSeedCompiler. Use -SeedMode ManagedRecovery only for an explicit bootstrap bridge."
    }
    if (-not (Test-Path -LiteralPath $slgSeedReceipt)) {
        throw "Stage 3 SLG seed has no completed verification receipt: $slgSeedReceipt"
    }
    $recordedSlgSeedHash = [System.IO.File]::ReadAllText($slgSeedReceipt).Trim()
    $actualSlgSeedHash = (Get-FileHash -LiteralPath $SlgSeedCompiler -Algorithm SHA256).Hash
    if ($recordedSlgSeedHash -ne $actualSlgSeedHash) {
        throw "Stage 3 SLG seed does not match its verification receipt: $SlgSeedCompiler"
    }
    Assert-VerifiedStage3SeedProvenance `
        -RepositoryRoot $repoRoot `
        -SeedPath $SlgSeedCompiler `
        -Target windows | Out-Null
    Write-Host "[stage2 1/7] Seed the new Stage 2 with verified Stage 3 $actualSlgSeedHash."
    Copy-Item -LiteralPath $SlgSeedCompiler -Destination $stage1Path -Force
} elseif ($SeedMode -eq "Stage2Bridge") {
    if (-not (Test-Stage2ArtifactReceipt `
            -LlvmPath $stage2LlvmPath `
            -BitcodePath $stage2BitcodePath `
            -ExecutablePath $stage2Path `
            -ReceiptPath $stage2ArtifactReceiptPath) -or
        -not (Test-Path -LiteralPath $stage2FingerprintPath) -or
        [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($stage2FingerprintPath))) {
        throw "Stage2Bridge requires the complete prior Stage2 artifact and input receipts"
    }
    $stage2BridgeHash = (Get-FileHash -LiteralPath $stage2Path -Algorithm SHA256).Hash
    Write-Host "[stage2 1/7] Seed the next SLG generation with receipt-bound Stage2 bridge $stage2BridgeHash."
    Copy-Item -LiteralPath $stage2Path -Destination $stage1Path -Force
} else {
    Write-Warning "ManagedRecovery is an explicit C# bootstrap bridge; publish a fixed-point Stage 3 and return to -SeedMode Slg."
    & dotnet run --project $runnerProject -c Release -- `
        --exact 365-selfhost-llvm-stage2-single-smoke `
        --exact 366-selfhost-llvm-stage2-multi-file-smoke `
        --jobs 2
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    Copy-Item -LiteralPath $managedOraclePath -Destination $stage1Path -Force
}

if (-not (Test-Path $stage1Path)) {
    throw "stage-1 compiler was not produced: $stage1Path"
}

& (Join-Path $PSScriptRoot "verify-selfhost-private-field-diagnostics.ps1") `
    -Compiler $stage1Path `
    -Label "stage1-seed" `
    -RepositoryRoot $repoRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# A seed that still mislabels a referenced growable array as a slice or loses a
# control-region parallel parameter, rejects canonical multiline projected
# assignments, freezes a provisional indexed-element array type, loses a
# unary-Bool match result, names an enum parameter binding as undefined SSA, or
# drops a field projected directly from a resolved call result cannot generate
# the complete compiler. Prove all narrow capabilities before
# paying for the 100k-line Stage2 emission; the
# completed Stage2 is checked again below. A statement-position enum match must
# also remain Unit unless every continuing arm agrees on one value type, and a
# completed late match must seal an enclosing function-result if. Projected
# receivers must also select their lexical root before same-name global fallback.
$stage1SeedExactFixtures = @(
    "787-selfhost-file-write-match-subject-ir"
    "1196-selfhost-cross-fragment-ref-dynamic-array"
    "1208-multiline-projected-assignment"
    "1217-selfhost-late-indexed-array-type-contract"
    "1291-quic-unidirectional-stream-registry"
    "1292-selfhost-unary-not-enum-match-value"
    "1293-selfhost-call-result-member-enum-subject"
    "1357-selfhost-projected-enum-subject-call-plan"
    "1358-selfhost-take-control-wrapper-owner"
    "1359-selfhost-private-empty-slice-helper-reachability"
    "1361-selfhost-nested-all-return-control"
    "1362-selfhost-qualified-flow-after-builtin-conversion"
    "1294-selfhost-statement-match-complete-arm-result"
    "1295-selfhost-late-match-if-result"
    "1296-selfhost-projected-receiver-instance-precedence"
    "1308-selfhost-nested-result-many-argument-owner"
    "1309-selfhost-terminating-if-branch-result"
    "1320-parallel-role-two-reference-captures"
    "1321-parallel-additional-borrow-result"
    "1380-selfhost-final-binding-return-selection"
    "1381-selfhost-terminal-return-only-if"
    "1382-selfhost-terminal-flow-control-return"
    "1383-selfhost-inferred-receiver-method-owner"
    "1384-nested-result-logical-condition"
    "1385-http-request-head-writer"
    "1386-http-client-connection-reuse"
    "1388-selfhost-imported-ref-struct-value-receiver"
    "1389-selfhost-nested-aggregate-partial-move-cleanup"
    "1391-opaque-struct-instance-boundary"
    "1392-selfhost-opaque-struct-ast"
    "1394-selfhost-when-binding-reassignment"
    "1352-selfhost-consuming-call-owned-outcome"
)
# Every exact build loads and verifies the same current standard library. Give
# small ownership/control checks the shared worker budget first so an
# incompatible historical seed fails before heavy compilation. Borrowed and
# fresh enum payloads need opposite cleanup behavior; verify both generations.
# Generic closure construction also requires putIfAbsent; reject an older seed
# on the small dictionary contract before compiling compiler-as-input fixtures.
$stage1SeedCanaryFixtures = @(
    "1201-parallel-move-parameter"
    "1398-selfhost-borrowed-enum-payload-lifetime"
    "1403-selfhost-fresh-directory-payload-cleanup"
    "1451-dictionary-absent-instance-result"
    "1452-each-call-result-record-type"
    "1453-each-push-return-alias"
    "1480-direct-repeat-readonly-slice"
    "1481-resolved-call-early-return-cleanup"
    "1482-signed-unary-contexts"
    "1497-narrow-integer-parameter-print"
    "1496-wide-integer-array-flow-context"
)
$stage1SeedHeavyFixtures = @(
    "787-selfhost-file-write-match-subject-ir"
    "1217-selfhost-late-indexed-array-type-contract"
    "1383-selfhost-inferred-receiver-method-owner"
)
$stage1SeedLightFixtures = @($stage1SeedExactFixtures | Where-Object {
    $_ -notin $stage1SeedHeavyFixtures
})
if (@($stage1SeedHeavyFixtures | Select-Object -Unique).Count -ne $stage1SeedHeavyFixtures.Count -or
    @($stage1SeedHeavyFixtures | Where-Object { $_ -notin $stage1SeedExactFixtures }).Count -ne 0 -or
    $stage1SeedHeavyFixtures.Count + $stage1SeedLightFixtures.Count -ne $stage1SeedExactFixtures.Count) {
    throw "Stage2 seed heavy/light fixture partition is invalid; keep every heavy fixture unique and inside stage1SeedExactFixtures"
}
& (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
    -Compiler $stage1Path `
    -Label "stage1-seed-canary" `
    -Fixture $stage1SeedCanaryFixtures `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory (Join-Path $artifactsDir "stage1-seed-canary-exact") `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
    -Compiler $stage1Path `
    -Label "stage1-seed-heavy" `
    -Fixture $stage1SeedHeavyFixtures `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory (Join-Path $artifactsDir "stage1-seed-heavy-exact") `
    -Jobs $Stage2BuildJobs `
    -MinimumCompilerJobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
    -Compiler $stage1Path `
    -Label "stage1-seed" `
    -Fixture $stage1SeedLightFixtures `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory (Join-Path $artifactsDir "stage1-seed-exact") `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$fileIntrinsicsControlLlvm = Join-Path $artifactsDir "stage2-check-file-intrinsics-control.ll"
$fileIntrinsicsControlBitcode = Join-Path $artifactsDir "stage2-check-file-intrinsics-control.bc"
$fileIntrinsicsControlError = Join-Path $artifactsDir "stage2-check-file-intrinsics-control.err"
$fileIntrinsicsControlArguments = @("windows", $fileIntrinsicsControlSource) + $compilerRuntimeSources
$fileIntrinsicsControlProcess = Invoke-ProcessToFile `
    $stage1Path `
    $fileIntrinsicsControlArguments `
    $fileIntrinsicsControlLlvm `
    $fileIntrinsicsControlError
Assert-ProcessSucceeded $fileIntrinsicsControlProcess $fileIntrinsicsControlError "stage-1 control-region file intrinsic emission"
$fileIntrinsicsControlText = [System.IO.File]::ReadAllText($fileIntrinsicsControlLlvm)
if ($fileIntrinsicsControlText -match '@sollang_m-?\d+_s-1') {
    throw "compiler integrity S049: emitted LLVM contains an unresolved Sollang module symbol. Resolve the required function across every same-namespace sys.runtime fragment as a concrete (module, symbol), keep its source in the compiler runtime manifest, and rebuild before invoking llvm-as."
}
if (-not $fileIntrinsicsControlText.Contains("@sollang_runtime_read_standard_input()") -or
    -not $fileIntrinsicsControlText.Contains("insertvalue %sollang.source_text")) {
    throw "control-region SourceText intrinsics did not lower to their runtime ABI"
}
& $llvmAsPath $fileIntrinsicsControlLlvm -o $fileIntrinsicsControlBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "[stage2 1/7] PASS control-region SourceText intrinsic lowering."

$runtimeEprintlnLlvm = Join-Path $artifactsDir "stage2-check-runtime-eprintln.ll"
$runtimeEprintlnBitcode = Join-Path $artifactsDir "stage2-check-runtime-eprintln.bc"
$runtimeEprintlnExecutable = Join-Path $artifactsDir "stage2-check-runtime-eprintln.exe"
$runtimeEprintlnStdout = Join-Path $artifactsDir "stage2-check-runtime-eprintln.stdout.txt"
$runtimeEprintlnStderr = Join-Path $artifactsDir "stage2-check-runtime-eprintln.stderr.txt"
$runtimeEprintlnError = Join-Path $artifactsDir "stage2-check-runtime-eprintln.err"
$runtimeEprintlnProcess = Invoke-ProcessToFile `
    $stage1Path `
    (@("windows", $runtimeEprintlnSource) + $compilerRuntimeSources) `
    $runtimeEprintlnLlvm `
    $runtimeEprintlnError
Assert-ProcessSucceeded $runtimeEprintlnProcess $runtimeEprintlnError "stage-1 stderr runtime dependency emission"
$runtimeEprintlnText = [System.IO.File]::ReadAllText($runtimeEprintlnLlvm)
if (-not $runtimeEprintlnText.Contains("define internal void @sollang_runtime_eprintln(")) {
    throw "sys.runtime.eprintln did not retain its stderr runtime definition"
}
& $llvmAsPath $runtimeEprintlnLlvm -o $runtimeEprintlnBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $runtimeEprintlnLlvm -o $runtimeEprintlnExecutable @windowsRuntimeLibraries
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtimeEprintlnRun = Invoke-ProcessToFile `
    $runtimeEprintlnExecutable `
    @() `
    $runtimeEprintlnStdout `
    $runtimeEprintlnStderr
Assert-ProcessSucceeded $runtimeEprintlnRun $runtimeEprintlnStderr "stage-1 stderr runtime execution"
$runtimeEprintlnActual = [System.IO.File]::ReadAllText($runtimeEprintlnStderr).Replace("`r`n", "`n").TrimEnd("`n")
if ($runtimeEprintlnActual -ne "stderr contract") {
    throw "sys.runtime.eprintln did not preserve its Text argument: '$runtimeEprintlnActual'"
}
Write-Host "[stage2 1/7] PASS stderr runtime dependency lowering."

$runtimeEprintlnInterpolationLlvm = Join-Path $artifactsDir "stage2-check-runtime-eprintln-interpolation.ll"
$runtimeEprintlnInterpolationBitcode = Join-Path $artifactsDir "stage2-check-runtime-eprintln-interpolation.bc"
$runtimeEprintlnInterpolationExecutable = Join-Path $artifactsDir "stage2-check-runtime-eprintln-interpolation.exe"
$runtimeEprintlnInterpolationStdout = Join-Path $artifactsDir "stage2-check-runtime-eprintln-interpolation.stdout.txt"
$runtimeEprintlnInterpolationStderr = Join-Path $artifactsDir "stage2-check-runtime-eprintln-interpolation.stderr.txt"
$runtimeEprintlnInterpolationError = Join-Path $artifactsDir "stage2-check-runtime-eprintln-interpolation.err"
$runtimeEprintlnInterpolationProcess = Invoke-ProcessToFile `
    $stage1Path `
    (@("windows", $runtimeEprintlnInterpolationSource) + $compilerRuntimeSources) `
    $runtimeEprintlnInterpolationLlvm `
    $runtimeEprintlnInterpolationError
Assert-ProcessSucceeded $runtimeEprintlnInterpolationProcess $runtimeEprintlnInterpolationError "stage-1 stderr interpolation emission"
& $llvmAsPath $runtimeEprintlnInterpolationLlvm -o $runtimeEprintlnInterpolationBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $runtimeEprintlnInterpolationLlvm -o $runtimeEprintlnInterpolationExecutable @windowsRuntimeLibraries
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtimeEprintlnInterpolationRun = Invoke-ProcessToFile `
    $runtimeEprintlnInterpolationExecutable `
    @() `
    $runtimeEprintlnInterpolationStdout `
    $runtimeEprintlnInterpolationStderr
Assert-ProcessSucceeded $runtimeEprintlnInterpolationRun $runtimeEprintlnInterpolationStderr "stage-1 stderr interpolation execution"
$runtimeEprintlnInterpolationActual = [System.IO.File]::ReadAllText($runtimeEprintlnInterpolationStderr).Replace("`r`n", "`n").TrimEnd("`n")
$runtimeEprintlnInterpolationExpected = @(
    "entry int=42 bool=true text=entry",
    "function int=7 bool=true text=sample",
    "control int=8 bool=false text=sample"
) -join "`n"
if ($runtimeEprintlnInterpolationActual -ne $runtimeEprintlnInterpolationExpected) {
    throw "sys.runtime.eprintln interpolation mismatch:`n$runtimeEprintlnInterpolationActual"
}
Write-Host "[stage2 1/7] PASS stderr interpolation lowering in entry, function, and control regions."

$runtimeEprintlnSourceTextLlvm = Join-Path $artifactsDir "stage2-check-runtime-eprintln-source-text.ll"
$runtimeEprintlnSourceTextBitcode = Join-Path $artifactsDir "stage2-check-runtime-eprintln-source-text.bc"
$runtimeEprintlnSourceTextExecutable = Join-Path $artifactsDir "stage2-check-runtime-eprintln-source-text.exe"
$runtimeEprintlnSourceTextStdout = Join-Path $artifactsDir "stage2-check-runtime-eprintln-source-text.stdout.txt"
$runtimeEprintlnSourceTextStderr = Join-Path $artifactsDir "stage2-check-runtime-eprintln-source-text.stderr.txt"
$runtimeEprintlnSourceTextError = Join-Path $artifactsDir "stage2-check-runtime-eprintln-source-text.err"
$runtimeEprintlnSourceTextArguments = @("windows", $runtimeEprintlnSourceTextSource) + $compilerRuntimeSources
$runtimeEprintlnSourceTextProcess = Invoke-ProcessToFile `
    $stage1Path `
    $runtimeEprintlnSourceTextArguments `
    $runtimeEprintlnSourceTextLlvm `
    $runtimeEprintlnSourceTextError
Assert-ProcessSucceeded $runtimeEprintlnSourceTextProcess $runtimeEprintlnSourceTextError "stage-1 current mutable container readonly reference emission"
& $llvmAsPath $runtimeEprintlnSourceTextLlvm -o $runtimeEprintlnSourceTextBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $runtimeEprintlnSourceTextLlvm -o $runtimeEprintlnSourceTextExecutable @windowsRuntimeLibraries
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtimeEprintlnSourceTextRun = Invoke-ProcessToFile `
    $runtimeEprintlnSourceTextExecutable `
    @() `
    $runtimeEprintlnSourceTextStdout `
    $runtimeEprintlnSourceTextStderr
Assert-ProcessSucceeded $runtimeEprintlnSourceTextRun $runtimeEprintlnSourceTextStderr "stage-1 current mutable container readonly reference execution"
$runtimeEprintlnSourceTextActual = [System.IO.File]::ReadAllText($runtimeEprintlnSourceTextStderr).Replace("`r`n", "`n").TrimEnd("`n")
if ($runtimeEprintlnSourceTextActual -ne "stderr") {
    throw "readonly reference observed stale mutable container state: '$runtimeEprintlnSourceTextActual'"
}
Write-Host "[stage2 1/7] PASS current mutable container readonly reference lowering."

$directoryCreateLlvm = Join-Path $artifactsDir "stage2-check-directory-create.ll"
$directoryCreateBitcode = Join-Path $artifactsDir "stage2-check-directory-create.bc"
$directoryCreateExecutable = Join-Path $artifactsDir "stage2-check-directory-create.exe"
$directoryCreateStdout = Join-Path $artifactsDir "stage2-check-directory-create.stdout.txt"
$directoryCreateStderr = Join-Path $artifactsDir "stage2-check-directory-create.stderr.txt"
$directoryCreateError = Join-Path $artifactsDir "stage2-check-directory-create.err"
$directoryCreateTarget = Join-Path $artifactsDir "stage2-directory-create"
if (Test-Path -LiteralPath $directoryCreateTarget) {
    Remove-Item -LiteralPath $directoryCreateTarget -Recurse -Force
}
$directoryCreateProcess = Invoke-ProcessToFile `
    $stage1Path `
    (@("windows", $directoryCreateSource) + $compilerRuntimeSources) `
    $directoryCreateLlvm `
    $directoryCreateError
Assert-ProcessSucceeded $directoryCreateProcess $directoryCreateError "stage-1 directory creation emission"
& $llvmAsPath $directoryCreateLlvm -o $directoryCreateBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $directoryCreateLlvm -o $directoryCreateExecutable @windowsRuntimeLibraries
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$directoryCreateRun = Invoke-ProcessToFile `
    $directoryCreateExecutable `
    @() `
    $directoryCreateStdout `
    $directoryCreateStderr
Assert-ProcessSucceeded $directoryCreateRun $directoryCreateStderr "stage-1 directory creation execution"
$directoryCreateActual = [System.IO.File]::ReadAllText($directoryCreateStdout).Replace("`r`n", "`n").TrimEnd("`n")
if ($directoryCreateActual -ne "created`nexists" -or -not (Test-Path -LiteralPath $directoryCreateTarget -PathType Container)) {
    throw "directory creation contract mismatch: '$directoryCreateActual'"
}
Write-Host "[stage2 1/7] PASS directory creation and existing-directory idempotence."

$pathNormalizeResultLlvm = Join-Path $artifactsDir "stage2-check-path-normalize-result.ll"
$pathNormalizeResultBitcode = Join-Path $artifactsDir "stage2-check-path-normalize-result.bc"
$pathNormalizeResultExecutable = Join-Path $artifactsDir "stage2-check-path-normalize-result.exe"
$pathNormalizeResultStdout = Join-Path $artifactsDir "stage2-check-path-normalize-result.stdout.txt"
$pathNormalizeResultStderr = Join-Path $artifactsDir "stage2-check-path-normalize-result.stderr.txt"
$pathNormalizeResultError = Join-Path $artifactsDir "stage2-check-path-normalize-result.err"
$pathNormalizeResultProcess = Invoke-ProcessToFile `
    $stage1Path `
    (@("windows", $pathNormalizeResultSource) + $compilerRuntimeSources) `
    $pathNormalizeResultLlvm `
    $pathNormalizeResultError
Assert-ProcessSucceeded $pathNormalizeResultProcess $pathNormalizeResultError "stage-1 owned Result path normalization emission"
& $llvmAsPath $pathNormalizeResultLlvm -o $pathNormalizeResultBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $pathNormalizeResultLlvm -o $pathNormalizeResultExecutable @windowsRuntimeLibraries -Xlinker /subsystem:console
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$pathNormalizeResultRun = Invoke-ProcessToFile `
    $pathNormalizeResultExecutable `
    @() `
    $pathNormalizeResultStdout `
    $pathNormalizeResultStderr
Assert-ProcessSucceeded $pathNormalizeResultRun $pathNormalizeResultStderr "stage-1 owned Result path normalization execution"
$pathNormalizeResultActual = [System.IO.File]::ReadAllText($pathNormalizeResultStdout).Replace("`r`n", "`n").TrimEnd("`n")
if ($pathNormalizeResultActual -ne "artifacts\native-grammar-build\probe\generated.slg`ntrue") {
    throw "owned Result path normalization contract mismatch: '$pathNormalizeResultActual'"
}
Write-Host "[stage2 1/7] PASS owned Result nested-return path normalization."

Write-Host "[stage2 2/7] Build or reuse the complete stage-2 compiler."
if (Test-Stage2IsCurrent) {
    Write-Host "[stage2 2/7] REUSE current stage-2 compiler."
} else {
    # A canceled or failed rebuild must not truncate or authenticate a partial
    # Stage2. Run every gate against candidates, then promote and publish fresh
    # output/input receipts only after the complete verification succeeds.
    $stage2CandidateLlvmPath = Get-CandidateArtifactPath $stage2LlvmPath
    $stage2CandidateBitcodePath = Get-CandidateArtifactPath $stage2BitcodePath
    $stage2CandidatePath = Get-CandidateArtifactPath $stage2Path
    $stage2CandidateFingerprintPath = Get-CandidateArtifactPath $stage2FingerprintPath
    $stage2CandidateArtifactReceiptPath = Get-CandidateArtifactPath $stage2ArtifactReceiptPath
    if ($ResumeCandidate) {
        if (-not (Test-Stage2ArtifactReceipt `
                -LlvmPath $stage2CandidateLlvmPath `
                -BitcodePath $stage2CandidateBitcodePath `
                -ExecutablePath $stage2CandidatePath `
                -ReceiptPath $stage2CandidateArtifactReceiptPath) -or
            -not (Test-Path -LiteralPath $stage2CandidateFingerprintPath) -or
            [System.IO.File]::ReadAllText($stage2CandidateFingerprintPath).Trim() -cne (Get-Stage2InputFingerprint)) {
            throw "Stage2 candidate artifacts do not match their input/output receipts; rebuild without -ResumeCandidate"
        }
        Write-Host "[stage2 2/7] RESUME receipt-bound Stage2 candidate."
    } else {
        Remove-Item -LiteralPath $stage2CandidateLlvmPath, $stage2CandidateBitcodePath, $stage2CandidatePath, $stage2CandidateFingerprintPath, $stage2CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
        $sourcePaths = @($compilerSources + ($compilerRuntimeSources | ForEach-Object { (Resolve-Path $_).Path }))
        $sourceLineCount = ($sourcePaths | ForEach-Object { [System.IO.File]::ReadAllLines($_).LongLength } | Measure-Object -Sum).Sum
        $stage2ErrorPath = Join-Path $artifactsDir "selfhost-stage2.err.log"
        $stage2TimeoutMilliseconds = 3600000
        $stage2Started = [DateTimeOffset]::Now
        $lastAnalysisHeartbeat = -1
        $lastLlvmHeartbeat = -1
        $lastReportedBytes = -1L
        $llvmProgressOffset = 0L
        $llvmProgressRemainder = ""
        $emittedDefinitionCount = 0
        Write-Host ("[stage2 2/7] phase 1/2 analyze {0:N0} source files / {1:N0} lines" -f $sourcePaths.Count, $sourceLineCount)
        $stage2Process = Invoke-ProcessToFile `
            -FilePath $stage1Path `
            -ArgumentList (@("windows", "--jobs", $Stage2BuildJobs.ToString([System.Globalization.CultureInfo]::InvariantCulture)) + $sourcePaths) `
            -OutputPath $stage2CandidateLlvmPath `
            -ErrorPath $stage2ErrorPath

        while (-not $stage2Process.HasExited) {
            Start-Sleep -Seconds 2
            $stage2Process.Refresh()
            if (([DateTimeOffset]::Now - $stage2Started).TotalMilliseconds -gt $stage2TimeoutMilliseconds) {
                Wait-VerificationProcess `
                    -Process $stage2Process `
                    -Description "stage-2 LLVM emission" `
                    -TimeoutMilliseconds $stage2TimeoutMilliseconds `
                    -TimeoutStartedAt $stage2Started
            }
            $bytes = if (Test-Path $stage2CandidateLlvmPath) { (Get-Item $stage2CandidateLlvmPath).Length } else { 0L }
            $cpuSeconds = [int]$stage2Process.TotalProcessorTime.TotalSeconds
            $workingMiB = [int]($stage2Process.WorkingSet64 / 1MB)
            if ($bytes -eq 0L) {
                $elapsed = [int]([DateTimeOffset]::Now - $stage2Started).TotalSeconds
                $heartbeat = [Math]::Floor($elapsed / 60)
                if ($heartbeat -gt $lastAnalysisHeartbeat) {
                    Write-Host ("[stage2 2/7] phase 1/2 analyze active ({0:N0}s elapsed, {1:N0}s CPU, {2:N0} MiB)" -f $elapsed, $cpuSeconds, $workingMiB)
                    $lastAnalysisHeartbeat = $heartbeat
                }
            } else {
                if ($bytes -gt $llvmProgressOffset) {
                    $progressStream = [System.IO.File]::Open(
                        $stage2CandidateLlvmPath,
                        [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::Read,
                        [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
                    try {
                        [void]$progressStream.Seek($llvmProgressOffset, [System.IO.SeekOrigin]::Begin)
                        $progressReader = [System.IO.StreamReader]::new(
                            $progressStream,
                            [System.Text.UTF8Encoding]::new($false),
                            $false,
                            65536,
                            $true)
                        try {
                            $newText = $progressReader.ReadToEnd()
                        } finally {
                            $progressReader.Dispose()
                        }
                        $llvmProgressOffset = $progressStream.Position
                    } finally {
                        $progressStream.Dispose()
                    }
                    $progressLines = ($llvmProgressRemainder + $newText).Replace("`r`n", "`n").Split("`n")
                    $llvmProgressRemainder = $progressLines[-1]
                    if ($progressLines.Count -gt 1) {
                        $emittedDefinitionCount += @($progressLines[0..($progressLines.Count - 2)] |
                            Where-Object { $_ -match '^define\s' }).Count
                    }
                }
                $elapsed = [int]([DateTimeOffset]::Now - $stage2Started).TotalSeconds
                $heartbeat = [Math]::Floor($elapsed / 60)
                $percent = [Math]::Min(100.0, 100.0 * $bytes / $expectedStage2Bytes)
                if ($bytes -ne $lastReportedBytes -or $heartbeat -gt $lastLlvmHeartbeat) {
                    $definitionProgress = if ($expectedStage2Definitions -gt 0) {
                        ", definitions $emittedDefinitionCount/$expectedStage2Definitions reference"
                    } else {
                        ", definitions $emittedDefinitionCount/reference unavailable"
                    }
                    Write-Host ("[stage2 2/7] phase 2/2 LLVM {0:N0} bytes ({1:N1}%{2}, {3:N0}s elapsed, {4:N0}s CPU, {5:N0} MiB)" -f $bytes, $percent, $definitionProgress, $elapsed, $cpuSeconds, $workingMiB)
                    $lastReportedBytes = $bytes
                    $lastLlvmHeartbeat = $heartbeat
                }
            }
        }
        Assert-ProcessSucceeded $stage2Process $stage2ErrorPath "stage-2 LLVM emission"

& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $stage2CandidateLlvmPath
& $llvmAsPath $stage2CandidateLlvmPath -o $stage2CandidateBitcodePath
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $clangPath -Wno-override-module $stage2CandidateLlvmPath -O1 -o $stage2CandidatePath @windowsRuntimeLibraries
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Write-Stage2ArtifactReceipt `
            -LlvmPath $stage2CandidateLlvmPath `
            -BitcodePath $stage2CandidateBitcodePath `
            -ExecutablePath $stage2CandidatePath `
            -ReceiptPath $stage2CandidateArtifactReceiptPath
        [System.IO.File]::WriteAllText($stage2CandidateFingerprintPath, (Get-Stage2InputFingerprint))
    }
    $stage2LlvmPath = $stage2CandidateLlvmPath
    $stage2BitcodePath = $stage2CandidateBitcodePath
    $stage2Path = $stage2CandidatePath
    $stage2WasRebuilt = $true
}
& (Join-Path $PSScriptRoot "verify-native-set-intrinsics.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-candidate" `
    -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-managed-cpu-aes-dispatch.ps1") `
    -Label "stage2-managed" `
    -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-cpu-aes-dispatch.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-candidate" `
    -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-cpu-aes-dispatch-differential.ps1") `
    -SelfhostCompiler $stage2Path `
    -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-static-readonly-array.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-candidate" `
    -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-selfhost-late-type-sealing.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-candidate" `
    -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-process-child-lifecycle.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-candidate" `
    -LlvmHome $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-quic-endpoint-ownership.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-candidate" `
    -LlvmHome $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$runtimeIntrinsicAbiLlvm = Join-Path $artifactsDir "stage2-check-runtime-intrinsic-abi-separation.ll"
$runtimeIntrinsicAbiError = Join-Path $artifactsDir "stage2-check-runtime-intrinsic-abi-separation.err"
$runtimeIntrinsicAbiProcess = Invoke-ProcessToFile `
    $stage2Path `
    (@("windows", $runtimeIntrinsicAbiSource) + $compilerRuntimeSources) `
    $runtimeIntrinsicAbiLlvm `
    $runtimeIntrinsicAbiError
Assert-ProcessSucceeded $runtimeIntrinsicAbiProcess $runtimeIntrinsicAbiError "stage-2 runtime intrinsic and foreign ABI separation"
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $runtimeIntrinsicAbiLlvm
& $llvmAsPath $runtimeIntrinsicAbiLlvm -o (Join-Path $artifactsDir "stage2-check-runtime-intrinsic-abi-separation.bc")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$runtimeIntrinsicAbiText = [System.IO.File]::ReadAllText($runtimeIntrinsicAbiLlvm)
if ($runtimeIntrinsicAbiText.Contains("@sollang_native_function_", [System.StringComparison]::Ordinal) -or
    -not $runtimeIntrinsicAbiText.Contains("call void @sollang_runtime_flush_stdout()", [System.StringComparison]::Ordinal)) {
    throw "stage-2 classified a bodyless runtime intrinsic as a foreign native-library call target"
}
Write-Host "[stage2 2/7] PASS runtime intrinsic and foreign native-library ABI separation."

& (Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1") `
    -LlvmPath $stage2LlvmPath `
    -MinimumCallbackCount 4 `
    -RequireNominalTransfer
$stage2Llvm = [System.IO.File]::ReadAllText($stage2LlvmPath)
if ($stage2Llvm -notmatch '(?s)define internal void @sollang_parallel_callback_\d+\(ptr %group, i64 %index\) \{.*?%capture_environment = load ptr,.*?%mapped = call [^\r\n]*@sollang_m\d+_s\d+\([^\r\n]*\).*?store [^\r\n]* %mapped,.*?\r?\n\}') {
    throw "stage-2 LLVM does not contain the function-local typed IR worker callback"
}
$currentLlvmBlock = ""
$lateReferenceAllocas = foreach ($line in [System.IO.File]::ReadLines($stage2LlvmPath)) {
    if ($line -match '^[A-Za-z0-9_.$-]+:$') {
        $currentLlvmBlock = $line.TrimEnd(':')
    }
    if ($line -match '^\s+%callref\d+_arg\d+ = alloca ' -and $currentLlvmBlock -ne 'entry') {
        "$currentLlvmBlock`: $($line.Trim())"
    }
}
if ($lateReferenceAllocas) {
    throw "stage-2 LLVM contains reference-argument allocas outside function entry:`n$($lateReferenceAllocas -join "`n")"
}
Write-Host "[stage2 2/7] PASS reference-argument allocas are hoisted to function entry."

Write-Host "[stage2 3/7] Compare stage-1 and stage-2 LLVM with an explicit worker limit."
$singleStage1Llvm = Join-Path $artifactsDir "stage2-check-single-stage1.ll"
$singleStage2Llvm = Join-Path $artifactsDir "stage2-check-single-stage2.ll"
$singleStage1Error = Join-Path $artifactsDir "stage2-check-single-stage1.err"
$singleStage2Error = Join-Path $artifactsDir "stage2-check-single-stage2.err"
$singleArguments = @("windows", "--jobs", "2", $singleSource)
$singleStage1Process = Invoke-ProcessToFile $stage1Path $singleArguments $singleStage1Llvm $singleStage1Error
$singleStage2Process = Invoke-ProcessToFile $stage2Path $singleArguments $singleStage2Llvm $singleStage2Error
Assert-ProcessSucceeded $singleStage1Process $singleStage1Error "stage-1 single-file emission"
Assert-ProcessSucceeded $singleStage2Process $singleStage2Error "stage-2 single-file emission"
$singleStage1Hash = Get-NormalizedHash $singleStage1Llvm
$singleStage2Hash = Get-NormalizedHash $singleStage2Llvm
if ($singleStage1Hash -ne $singleStage2Hash) {
    throw "single-file normalized LLVM differs: stage1=$singleStage1Hash stage2=$singleStage2Hash"
}
if (-not ([System.IO.File]::ReadAllText($singleStage2Llvm).StartsWith("; sollang workers = 2"))) {
    throw "stage-2 compiler did not report the effective --jobs worker count"
}
Write-Host "[stage2 3/7] PASS $singleStage2Hash"

$mouseEventLlvm = Join-Path $artifactsDir "stage2-check-mouse-source.ll"
$mouseEventBitcode = Join-Path $artifactsDir "stage2-check-mouse-source.bc"
$mouseEventError = Join-Path $artifactsDir "stage2-check-mouse-source.err"
$mouseEventArguments = @("windows-stdlib", $stdlibRoot, $mouseEventSource)
$mouseEventProcess = Invoke-ProcessToFile `
    $stage2Path `
    $mouseEventArguments `
    $mouseEventLlvm `
    $mouseEventError
Assert-ProcessSucceeded $mouseEventProcess $mouseEventError "stage-2 mouse Source instance emission"
if (-not [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($mouseEventError))) {
    throw "stage-2 mouse Source instance emission produced diagnostics"
}
$mouseEventText = [System.IO.File]::ReadAllText($mouseEventLlvm)
if ($mouseEventText -notmatch 'define internal %sollang\.event_stream @sollang_mouse_event_stream_make\(%sollang\.struct\.[^ ]+ %source\)' -or
    $mouseEventText -notmatch 'extractvalue %sollang\.struct\.[^ ]+ %source, 0' -or
    $mouseEventText -notmatch 'extractvalue %sollang\.struct\.[^ ]+ %source, 1' -or
    $mouseEventText -notmatch 'call ptr @sollang_mouse_event_stream_create\(i32 %capacity, i32 %overflow_tag\)') {
    throw "stage-2 mouse Source did not lower to the direct bounded EventStream runtime ABI"
}
& $llvmAsPath $mouseEventLlvm -o $mouseEventBitcode
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "[stage2 3/7] PASS mouse Source direct EventStream lowering."

$groupedStage1Llvm = Join-Path $artifactsDir "stage2-check-grouped-not-stage1.ll"
$groupedStage2Llvm = Join-Path $artifactsDir "stage2-check-grouped-not-stage2.ll"
$groupedStage1Error = Join-Path $artifactsDir "stage2-check-grouped-not-stage1.err"
$groupedStage2Error = Join-Path $artifactsDir "stage2-check-grouped-not-stage2.err"
$groupedStage1Process = Invoke-ProcessToFile $stage1Path @("windows", $groupedNotSource) $groupedStage1Llvm $groupedStage1Error
$groupedStage2Process = Invoke-ProcessToFile $stage2Path @("windows", $groupedNotSource) $groupedStage2Llvm $groupedStage2Error
Assert-ProcessSucceeded $groupedStage1Process $groupedStage1Error "stage-1 grouped-not emission"
Assert-ProcessSucceeded $groupedStage2Process $groupedStage2Error "stage-2 grouped-not emission"
$groupedStage1Hash = Get-NormalizedHash $groupedStage1Llvm
$groupedStage2Hash = Get-NormalizedHash $groupedStage2Llvm
if ($groupedStage1Hash -ne $groupedStage2Hash) {
    throw "grouped-not normalized LLVM differs: stage1=$groupedStage1Hash stage2=$groupedStage2Hash"
}
if (-not ([System.IO.File]::ReadAllText($groupedStage2Llvm).Contains("xor i1"))) {
    throw "grouped-not stage-2 LLVM does not contain unary Boolean lowering"
}
Write-Host "[stage2 3/7] PASS grouped-not $groupedStage2Hash"

$interpolationLengthStage1Llvm = Join-Path $artifactsDir "stage2-check-interpolation-len-stage1.ll"
$interpolationLengthStage2Llvm = Join-Path $artifactsDir "stage2-check-interpolation-len-stage2.ll"
$interpolationLengthStage1Error = Join-Path $artifactsDir "stage2-check-interpolation-len-stage1.err"
$interpolationLengthStage2Error = Join-Path $artifactsDir "stage2-check-interpolation-len-stage2.err"
$interpolationLengthArguments = @("windows", $interpolationLengthSource)
$interpolationLengthStage1Process = Invoke-ProcessToFile $stage1Path $interpolationLengthArguments $interpolationLengthStage1Llvm $interpolationLengthStage1Error
$interpolationLengthStage2Process = Invoke-ProcessToFile $stage2Path $interpolationLengthArguments $interpolationLengthStage2Llvm $interpolationLengthStage2Error
Assert-ProcessSucceeded $interpolationLengthStage1Process $interpolationLengthStage1Error "stage-1 interpolation length emission"
Assert-ProcessSucceeded $interpolationLengthStage2Process $interpolationLengthStage2Error "stage-2 interpolation length emission"
$interpolationLengthStage1Hash = Get-NormalizedHash $interpolationLengthStage1Llvm
$interpolationLengthStage2Hash = Get-NormalizedHash $interpolationLengthStage2Llvm
if ($interpolationLengthStage1Hash -ne $interpolationLengthStage2Hash) {
    throw "interpolation length normalized LLVM differs: stage1=$interpolationLengthStage1Hash stage2=$interpolationLengthStage2Hash"
}
Write-Host "[stage2 3/7] PASS interpolation-len $interpolationLengthStage2Hash"

$nestedUInt8IfStage1Llvm = Join-Path $artifactsDir "stage2-check-if-uint8-stage1.ll"
$nestedUInt8IfStage2Llvm = Join-Path $artifactsDir "stage2-check-if-uint8-stage2.ll"
$nestedUInt8IfStage1Error = Join-Path $artifactsDir "stage2-check-if-uint8-stage1.err"
$nestedUInt8IfStage2Error = Join-Path $artifactsDir "stage2-check-if-uint8-stage2.err"
$nestedUInt8IfArguments = @("windows", $nestedUInt8IfSource)
$nestedUInt8IfStage1Process = Invoke-ProcessToFile $stage1Path $nestedUInt8IfArguments $nestedUInt8IfStage1Llvm $nestedUInt8IfStage1Error
$nestedUInt8IfStage2Process = Invoke-ProcessToFile $stage2Path $nestedUInt8IfArguments $nestedUInt8IfStage2Llvm $nestedUInt8IfStage2Error
Assert-ProcessSucceeded $nestedUInt8IfStage1Process $nestedUInt8IfStage1Error "stage-1 nested UInt8 if emission"
Assert-ProcessSucceeded $nestedUInt8IfStage2Process $nestedUInt8IfStage2Error "stage-2 nested UInt8 if emission"
$nestedUInt8IfStage1Hash = Get-NormalizedHash $nestedUInt8IfStage1Llvm
$nestedUInt8IfStage2Hash = Get-NormalizedHash $nestedUInt8IfStage2Llvm
if ($nestedUInt8IfStage1Hash -ne $nestedUInt8IfStage2Hash) {
    throw "nested UInt8 if normalized LLVM differs: stage1=$nestedUInt8IfStage1Hash stage2=$nestedUInt8IfStage2Hash"
}
if ([System.IO.File]::ReadAllText($nestedUInt8IfStage2Llvm).Contains("freeze void")) {
    throw "nested UInt8 if stage-2 LLVM contains a void value operation"
}
Write-Host "[stage2 3/7] PASS if-uint8 $nestedUInt8IfStage2Hash"

$unusedIfStage1Llvm = Join-Path $artifactsDir "stage2-check-unused-if-stage1.ll"
$unusedIfStage2Llvm = Join-Path $artifactsDir "stage2-check-unused-if-stage2.ll"
$unusedIfStage1Error = Join-Path $artifactsDir "stage2-check-unused-if-stage1.err"
$unusedIfStage2Error = Join-Path $artifactsDir "stage2-check-unused-if-stage2.err"
$unusedIfArguments = @("windows", $unusedIfAssignmentSource)
$unusedIfStage1Process = Invoke-ProcessToFile $stage1Path $unusedIfArguments $unusedIfStage1Llvm $unusedIfStage1Error
$unusedIfStage2Process = Invoke-ProcessToFile $stage2Path $unusedIfArguments $unusedIfStage2Llvm $unusedIfStage2Error
Assert-ProcessSucceeded $unusedIfStage1Process $unusedIfStage1Error "stage-1 unused if emission"
Assert-ProcessSucceeded $unusedIfStage2Process $unusedIfStage2Error "stage-2 unused if emission"
$unusedIfStage1Hash = Get-NormalizedHash $unusedIfStage1Llvm
$unusedIfStage2Hash = Get-NormalizedHash $unusedIfStage2Llvm
if ($unusedIfStage1Hash -ne $unusedIfStage2Hash) {
    throw "unused if normalized LLVM differs: stage1=$unusedIfStage1Hash stage2=$unusedIfStage2Hash"
}
if ([System.IO.File]::ReadAllText($unusedIfStage2Llvm) -match '%if\d+_result = alloca i1') {
    throw "unused statement-position if allocated a Boolean result slot"
}
Write-Host "[stage2 3/7] PASS unused-if $unusedIfStage2Hash"

$unusedMatchStage1Llvm = Join-Path $artifactsDir "stage2-check-unused-match-stage1.ll"
$unusedMatchStage2Llvm = Join-Path $artifactsDir "stage2-check-unused-match-stage2.ll"
$unusedMatchStage1Error = Join-Path $artifactsDir "stage2-check-unused-match-stage1.err"
$unusedMatchStage2Error = Join-Path $artifactsDir "stage2-check-unused-match-stage2.err"
$unusedMatchArguments = @("windows", $unusedMatchAssignmentSource)
$unusedMatchStage1Process = Invoke-ProcessToFile $stage1Path $unusedMatchArguments $unusedMatchStage1Llvm $unusedMatchStage1Error
$unusedMatchStage2Process = Invoke-ProcessToFile $stage2Path $unusedMatchArguments $unusedMatchStage2Llvm $unusedMatchStage2Error
Assert-ProcessSucceeded $unusedMatchStage1Process $unusedMatchStage1Error "stage-1 unused match emission"
Assert-ProcessSucceeded $unusedMatchStage2Process $unusedMatchStage2Error "stage-2 unused match emission"
$unusedMatchStage1Hash = Get-NormalizedHash $unusedMatchStage1Llvm
$unusedMatchStage2Hash = Get-NormalizedHash $unusedMatchStage2Llvm
if ($unusedMatchStage1Hash -ne $unusedMatchStage2Hash) {
    throw "unused match normalized LLVM differs: stage1=$unusedMatchStage1Hash stage2=$unusedMatchStage2Hash"
}
if ([System.IO.File]::ReadAllText($unusedMatchStage2Llvm) -match '%v\d+_result = alloca i1') {
    throw "unused statement-position match allocated a Boolean result slot"
}
Write-Host "[stage2 3/7] PASS unused-match $unusedMatchStage2Hash"

$mutableResetStage1Llvm = Join-Path $artifactsDir "stage2-check-mutable-reset-after-while-stage1.ll"
$mutableResetAfterWhileStage2Llvm = Join-Path $artifactsDir "stage2-check-mutable-reset-after-while-stage2.ll"
$mutableResetStage1Error = Join-Path $artifactsDir "stage2-check-mutable-reset-after-while-stage1.err"
$mutableResetStage2Error = Join-Path $artifactsDir "stage2-check-mutable-reset-after-while-stage2.err"
$mutableResetArguments = @("windows", $mutableResetAfterWhileSource)
$mutableResetStage1Process = Invoke-ProcessToFile $stage1Path $mutableResetArguments $mutableResetStage1Llvm $mutableResetStage1Error
$mutableResetStage2Process = Invoke-ProcessToFile $stage2Path $mutableResetArguments $mutableResetAfterWhileStage2Llvm $mutableResetStage2Error
Assert-ProcessSucceeded $mutableResetStage1Process $mutableResetStage1Error "stage-1 mutable reset after while emission"
Assert-ProcessSucceeded $mutableResetStage2Process $mutableResetStage2Error "stage-2 mutable reset after while emission"
$mutableResetStage1Hash = Get-NormalizedHash $mutableResetStage1Llvm
$mutableResetStage2Hash = Get-NormalizedHash $mutableResetAfterWhileStage2Llvm
if ($mutableResetStage1Hash -ne $mutableResetStage2Hash) {
    throw "mutable reset after while normalized LLVM differs: stage1=$mutableResetStage1Hash stage2=$mutableResetStage2Hash"
}
$mutableResetStage2Text = [System.IO.File]::ReadAllText($mutableResetAfterWhileStage2Llvm)
$mutableResetFirstWhileExit = $mutableResetStage2Text.IndexOf("while", [System.StringComparison]::Ordinal)
$mutableResetStore = $mutableResetStage2Text.IndexOf("store i32 0", $mutableResetFirstWhileExit, [System.StringComparison]::Ordinal)
if ($mutableResetFirstWhileExit -lt 0 -or $mutableResetStore -lt $mutableResetFirstWhileExit) {
    throw "mutable reset after while was not emitted after the first control-flow region"
}
Write-Host "[stage2 3/7] PASS mutable-reset-after-while $mutableResetStage2Hash"

$directPatternStage1Llvm = Join-Path $artifactsDir "stage2-check-direct-pattern-second-argument-stage1.ll"
$directPatternStage2Llvm = Join-Path $artifactsDir "stage2-check-direct-pattern-second-argument-stage2.ll"
$directPatternStage1Error = Join-Path $artifactsDir "stage2-check-direct-pattern-second-argument-stage1.err"
$directPatternStage2Error = Join-Path $artifactsDir "stage2-check-direct-pattern-second-argument-stage2.err"
$directPatternArguments = @("windows", $directPatternSecondArgumentSource, $directPatternSecondArgumentFixture)
$directPatternStage1Process = Invoke-ProcessToFile $stage1Path $directPatternArguments $directPatternStage1Llvm $directPatternStage1Error
$directPatternStage2Process = Invoke-ProcessToFile $stage2Path $directPatternArguments $directPatternStage2Llvm $directPatternStage2Error
Assert-ProcessSucceeded $directPatternStage1Process $directPatternStage1Error "stage-1 direct pattern second-argument emission"
Assert-ProcessSucceeded $directPatternStage2Process $directPatternStage2Error "stage-2 direct pattern second-argument emission"
$directPatternStage1Hash = Get-NormalizedHash $directPatternStage1Llvm
$directPatternStage2Hash = Get-NormalizedHash $directPatternStage2Llvm
if ($directPatternStage1Hash -ne $directPatternStage2Hash) {
    throw "direct pattern second-argument normalized LLVM differs: stage1=$directPatternStage1Hash stage2=$directPatternStage2Hash"
}
Write-Host "[stage2 3/7] PASS direct-pattern-second-argument $directPatternStage2Hash"

$subjectWhenStage1Llvm = Join-Path $artifactsDir "stage2-check-subject-when-direct-result-stage1.ll"
$subjectWhenStage2Llvm = Join-Path $artifactsDir "stage2-check-subject-when-direct-result-stage2.ll"
$subjectWhenStage1Error = Join-Path $artifactsDir "stage2-check-subject-when-direct-result-stage1.err"
$subjectWhenStage2Error = Join-Path $artifactsDir "stage2-check-subject-when-direct-result-stage2.err"
$subjectWhenArguments = @("windows", $subjectWhenDirectResultSource)
$subjectWhenStage1Process = Invoke-ProcessToFile $stage1Path $subjectWhenArguments $subjectWhenStage1Llvm $subjectWhenStage1Error
$subjectWhenStage2Process = Invoke-ProcessToFile $stage2Path $subjectWhenArguments $subjectWhenStage2Llvm $subjectWhenStage2Error
Assert-ProcessSucceeded $subjectWhenStage1Process $subjectWhenStage1Error "stage-1 subject-when direct-result emission"
Assert-ProcessSucceeded $subjectWhenStage2Process $subjectWhenStage2Error "stage-2 subject-when direct-result emission"
$subjectWhenStage1Hash = Get-NormalizedHash $subjectWhenStage1Llvm
$subjectWhenStage2Hash = Get-NormalizedHash $subjectWhenStage2Llvm
if ($subjectWhenStage1Hash -ne $subjectWhenStage2Hash) {
    throw "subject-when direct-result normalized LLVM differs: stage1=$subjectWhenStage1Hash stage2=$subjectWhenStage2Hash"
}
Write-Host "[stage2 3/7] PASS subject-when-direct-result $subjectWhenStage2Hash"

Write-Host "[stage2 4/7] Compare stage-1 and stage-2 LLVM for imported source files."
$multiStage1Llvm = Join-Path $artifactsDir "stage2-check-multi-stage1.ll"
$multiStage2Llvm = Join-Path $artifactsDir "stage2-check-multi-stage2.ll"
$multiStage1Error = Join-Path $artifactsDir "stage2-check-multi-stage1.err"
$multiStage2Error = Join-Path $artifactsDir "stage2-check-multi-stage2.err"
$multiArguments = @("windows", $multiLibrarySource, $multiMainSource)
$multiStage1Process = Invoke-ProcessToFile $stage1Path $multiArguments $multiStage1Llvm $multiStage1Error
$multiStage2Process = Invoke-ProcessToFile $stage2Path $multiArguments $multiStage2Llvm $multiStage2Error
Assert-ProcessSucceeded $multiStage1Process $multiStage1Error "stage-1 multi-file emission"
Assert-ProcessSucceeded $multiStage2Process $multiStage2Error "stage-2 multi-file emission"
$multiStage1Hash = Get-NormalizedHash $multiStage1Llvm
$multiStage2Hash = Get-NormalizedHash $multiStage2Llvm
if ($multiStage1Hash -ne $multiStage2Hash) {
    throw "multi-file normalized LLVM differs: stage1=$multiStage1Hash stage2=$multiStage2Hash"
}
Write-Host "[stage2 4/7] PASS $multiStage2Hash"

Write-Host "[stage2 4/7] Compare stage-1 and stage-2 LLVM for complete stream pipelines."
$streamParityCases = @(
    @("table", $streamTableSource, "576-linq-multiplication-table.stdout.txt"),
    @("deferred-text", $streamDeferredTextSource, "580-deferred-text-evaluation.stdout.txt"),
    @("sensor", $streamSensorSource, "582-billion-sensor-alerts.stdout.txt"),
    @("state", $streamStateSource, "583-stream-state-take-skip.stdout.txt"),
    @("risk", $streamRiskSource, "585-stream-transaction-risk-scan.stdout.txt"),
    @("partition-bound", $streamPartitionSource, "797-partition-first-match-direct-dispatch.stdout.txt")
)
$streamStage2LlvmPaths = @()
foreach ($streamCase in $streamParityCases) {
    $streamName = $streamCase[0]
    $streamSource = $streamCase[1]
    $streamStage1Llvm = Join-Path $artifactsDir "stage2-check-stream-$streamName-stage1.ll"
    $streamStage2Llvm = Join-Path $artifactsDir "stage2-check-stream-$streamName-stage2.ll"
    $streamStage1Error = Join-Path $artifactsDir "stage2-check-stream-$streamName-stage1.err"
    $streamStage2Error = Join-Path $artifactsDir "stage2-check-stream-$streamName-stage2.err"
    $streamArguments = @("windows", $streamSource, $sequenceSource, $sequenceRuntimeSource)
    $streamStage1Process = Invoke-ProcessToFile $stage1Path $streamArguments $streamStage1Llvm $streamStage1Error
    $streamStage2Process = Invoke-ProcessToFile $stage2Path $streamArguments $streamStage2Llvm $streamStage2Error
    Assert-ProcessSucceeded $streamStage1Process $streamStage1Error "stage-1 $streamName stream emission"
    Assert-ProcessSucceeded $streamStage2Process $streamStage2Error "stage-2 $streamName stream emission"
    $streamStage1Hash = Get-NormalizedHash $streamStage1Llvm
    $streamStage2Hash = Get-NormalizedHash $streamStage2Llvm
    if ($streamStage1Hash -ne $streamStage2Hash) {
        throw "$streamName stream normalized LLVM differs: stage1=$streamStage1Hash stage2=$streamStage2Hash"
    }
    $streamStage2LlvmPaths += $streamStage2Llvm
    Write-Host "[stage2 4/7] PASS stream-$streamName $streamStage2Hash"
}

Write-Host "[stage2 4/7] Verify the source-worker LLVM golden before the full native batch."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --skip-bootstrap `
    --compare-compilers `
    --exact 377-selfhost-llvm-source-text-worker-transfer `
    --jobs 1
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "[stage2 5/7] Assemble, link, execute, and exercise the native build path."
& (Join-Path $PSScriptRoot "verify-selfhost-private-field-diagnostics.ps1") `
    -Compiler $stage2Path `
    -Label "stage2" `
    -RepositoryRoot $repoRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
for ($streamExecutionIndex = 0; $streamExecutionIndex -lt $streamStage2LlvmPaths.Count; $streamExecutionIndex++) {
    $streamName = $streamParityCases[$streamExecutionIndex][0]
    $streamExecutablePath = Join-Path $artifactsDir "stage2-check-stream-$streamName.exe"
    $streamBitcodePath = [System.IO.Path]::ChangeExtension($streamExecutablePath, ".bc")
    & $llvmAsPath $streamStage2LlvmPaths[$streamExecutionIndex] -o $streamBitcodePath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $clangPath -Wno-override-module $streamStage2LlvmPaths[$streamExecutionIndex] -o $streamExecutablePath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $streamStdoutPath = Join-Path $artifactsDir "stage2-check-stream-$streamName.stdout.txt"
    $streamStderrPath = Join-Path $artifactsDir "stage2-check-stream-$streamName.stderr.txt"
    $streamProcess = Invoke-ProcessToFile `
        -FilePath $streamExecutablePath `
        -ArgumentList @() `
        -OutputPath $streamStdoutPath `
        -ErrorPath $streamStderrPath
    Wait-VerificationProcess $streamProcess "stage-2 stream executable"
    $streamProcess.Refresh()
    $streamExitCode = $streamProcess.ExitCode
    $streamActual = [System.IO.File]::ReadAllText($streamStdoutPath).Replace("`r`n", "`n").TrimEnd("`r", "`n")
    $streamExpectedPath = Join-Path $repoRoot "examples\regression\expected\$($streamParityCases[$streamExecutionIndex][2])"
    $streamExpected = [System.IO.File]::ReadAllText($streamExpectedPath).Replace("`r`n", "`n").TrimEnd("`r", "`n")
    if ($streamExitCode -ne 0 -or -not [string]::Equals($streamActual, $streamExpected, [System.StringComparison]::Ordinal)) {
        throw "stage-2 $streamName stream execution differs from the checked expectation (exit=$streamExitCode, actualLength=$($streamActual.Length), expectedLength=$($streamExpected.Length))"
    }
}
& (Join-Path $PSScriptRoot "verify-native-exact-fixture-batch.ps1") `
    -Compiler $stage2Path `
    -Label "stage2" `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory (Join-Path $artifactsDir "stage2-exact") `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-exact-fixture.ps1") `
    -Compiler $stage2Path `
    -Label "stage2-large-stdout" `
    -Fixture "1287-windows-large-stdout-complete" `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory (Join-Path $artifactsDir "stage2-large-stdout") `
    -Jobs $Stage2BuildJobs `
    -ExpectedStdoutLength 2097152
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($case in @(
    @($singleStage2Llvm, "stage2-check-single.exe", "stage2-single-ok"),
    @($multiStage2Llvm, "stage2-check-multi.exe", "stage2-multi-ok"),
    @($groupedStage2Llvm, "stage2-check-grouped-not.exe", "grouped-not-ok"),
    @($interpolationLengthStage2Llvm, "stage2-check-interpolation-len.exe", "count=4`nmaterialized=4"),
    @($nestedUInt8IfStage2Llvm, "stage2-check-if-uint8.exe", "ok"),
    @($unusedIfStage2Llvm, "stage2-check-unused-if.exe", "ok"),
    @($unusedMatchStage2Llvm, "stage2-check-unused-match.exe", "ok"),
    @($mutableResetAfterWhileStage2Llvm, "stage2-check-mutable-reset-after-while.exe", "4`ntrue"),
    @($directPatternStage2Llvm, "stage2-check-direct-pattern-second-argument.exe", "42`n42"),
    @($subjectWhenStage2Llvm, "stage2-check-subject-when-direct-result.exe", "6,3,inclusive")
)) {
    $executablePath = Join-Path $artifactsDir $case[1]
    & $llvmAsPath $case[0] -o ([System.IO.Path]::ChangeExtension($executablePath, ".bc"))
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $clangPath -Wno-override-module $case[0] -o $executablePath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $run = Invoke-VerificationProcessCapture `
        -FilePath $executablePath `
        -Description "stage-2 smoke executable"
    $actual = $run.Stdout.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
    if ($run.ExitCode -ne 0 -or $actual -ne $case[2]) {
        throw "stage-2 smoke execution failed: expected '$($case[2])', actual '$actual'"
    }
}

$nativeBuildLlvm = Join-Path $artifactsDir "stage2-check-native-build.ll"
$nativeBuildExecutable = Join-Path $artifactsDir "stage2-check-native-build.exe"
$nativeBuildOutput = Join-Path $artifactsDir "stage2-check-native-build.stdout.txt"
$nativeBuildError = Join-Path $artifactsDir "stage2-check-native-build.stderr.txt"
Remove-Item -LiteralPath $nativeBuildLlvm, $nativeBuildExecutable -ErrorAction SilentlyContinue
$nativeBuildProcess = Invoke-ProcessToFile `
    -FilePath $stage2Path `
    -ArgumentList @("build-windows", $nativeBuildLlvm, $nativeBuildExecutable, $clangPath, $singleSource) `
    -OutputPath $nativeBuildOutput `
    -ErrorPath $nativeBuildError
Assert-ProcessSucceeded $nativeBuildProcess $nativeBuildError "stage-2 native build"

$nativeBuildMessage = ([System.IO.File]::ReadAllText($nativeBuildOutput)).TrimEnd("`r", "`n")
if ($nativeBuildMessage -ne "native build = 0") {
    throw "stage-2 native build did not report success: '$nativeBuildMessage'"
}
if (-not (Test-Path $nativeBuildLlvm) -or -not (Test-Path $nativeBuildExecutable)) {
    throw "stage-2 native build did not produce both LLVM and executable artifacts"
}

$nativeBuildRun = Invoke-VerificationProcessCapture `
    -FilePath $nativeBuildExecutable `
    -Description "stage-2 native build executable"
$nativeBuildActual = $nativeBuildRun.Stdout.TrimEnd("`r", "`n")
if ($nativeBuildRun.ExitCode -ne 0 -or $nativeBuildActual -ne "stage2-single-ok") {
    throw "stage-2 native build execution failed: expected 'stage2-single-ok', actual '$nativeBuildActual'"
}

$resultPropagationExecutable = Join-Path $artifactsDir "stage2-check-result-propagation-control.exe"
$resultPropagationLlvm = $resultPropagationExecutable + ".ll"
$resultPropagationOutput = Join-Path $artifactsDir "stage2-check-result-propagation-control.stdout.txt"
$resultPropagationError = Join-Path $artifactsDir "stage2-check-result-propagation-control.stderr.txt"
Remove-Item -LiteralPath $resultPropagationExecutable, $resultPropagationLlvm -ErrorAction SilentlyContinue
$resultPropagationProcess = Invoke-ProcessToFile `
    -FilePath $stage2Path `
    -ArgumentList @(
        "build", $resultPropagationControlSource,
        "-o", $resultPropagationExecutable,
        "--target", "windows-x64",
        "--llvm", $llvmDir,
        "--stdlib", $stdlibRoot,
        "--jobs", $Stage2BuildJobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        "-O1", "--keep-temps") `
    -OutputPath $resultPropagationOutput `
    -ErrorPath $resultPropagationError
Assert-ProcessSucceeded $resultPropagationProcess $resultPropagationError "stage-2 Result propagation control-order native build"
if (-not (Test-Path $resultPropagationLlvm) -or -not (Test-Path $resultPropagationExecutable)) {
    throw "stage-2 Result propagation control-order build did not retain LLVM and executable artifacts"
}
& $llvmAsPath $resultPropagationLlvm -o ([System.IO.Path]::ChangeExtension($resultPropagationExecutable, ".bc"))
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$resultPropagationRun = Invoke-VerificationProcessCapture `
    -FilePath $resultPropagationExecutable `
    -Description "stage-2 Result propagation control executable"
$resultPropagationActual = $resultPropagationRun.Stdout.TrimEnd("`r", "`n")
if ($resultPropagationRun.ExitCode -ne 0 -or $resultPropagationActual -ne "quic-endpoint=ok") {
    throw "stage-2 Result propagation control-order execution failed: expected 'quic-endpoint=ok', actual '$resultPropagationActual'"
}

$socketEndpointExecutable = Join-Path $artifactsDir "stage2-check-socket-endpoint-observation.exe"
$socketEndpointLlvm = $socketEndpointExecutable + ".ll"
$socketEndpointOutput = Join-Path $artifactsDir "stage2-check-socket-endpoint-observation.stdout.txt"
$socketEndpointError = Join-Path $artifactsDir "stage2-check-socket-endpoint-observation.stderr.txt"
Remove-Item -LiteralPath $socketEndpointExecutable, $socketEndpointLlvm -ErrorAction SilentlyContinue
$socketEndpointProcess = Invoke-ProcessToFile `
    -FilePath $stage2Path `
    -ArgumentList @(
        "build", $socketEndpointObservationSource,
        "-o", $socketEndpointExecutable,
        "--target", "windows-x64",
        "--llvm", $llvmDir,
        "--stdlib", $stdlibRoot,
        "--jobs", $Stage2BuildJobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        "-O1", "--keep-temps") `
    -OutputPath $socketEndpointOutput `
    -ErrorPath $socketEndpointError
Assert-ProcessSucceeded $socketEndpointProcess $socketEndpointError "stage-2 socket endpoint observation native build"
if (-not (Test-Path $socketEndpointLlvm) -or -not (Test-Path $socketEndpointExecutable)) {
    throw "stage-2 socket endpoint observation build did not retain LLVM and executable artifacts"
}
& $llvmAsPath $socketEndpointLlvm -o ([System.IO.Path]::ChangeExtension($socketEndpointExecutable, ".bc"))
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$socketEndpointRun = Invoke-VerificationProcessCapture `
    -FilePath $socketEndpointExecutable `
    -Description "stage-2 socket endpoint observation executable"
$socketEndpointActual = $socketEndpointRun.Stdout.TrimEnd("`r", "`n")
if ($socketEndpointRun.ExitCode -ne 0 -or $socketEndpointActual -ne "socket-endpoints=ok") {
    throw "stage-2 socket endpoint observation execution failed: expected 'socket-endpoints=ok', actual '$socketEndpointActual'"
}

$socketNoDelayExecutable = Join-Path $artifactsDir "stage2-check-socket-no-delay.exe"
$socketNoDelayLlvm = $socketNoDelayExecutable + ".ll"
$socketNoDelayOutput = Join-Path $artifactsDir "stage2-check-socket-no-delay.stdout.txt"
$socketNoDelayError = Join-Path $artifactsDir "stage2-check-socket-no-delay.stderr.txt"
Remove-Item -LiteralPath $socketNoDelayExecutable, $socketNoDelayLlvm -ErrorAction SilentlyContinue
$socketNoDelayProcess = Invoke-ProcessToFile `
    -FilePath $stage2Path `
    -ArgumentList @(
        "build", $socketNoDelaySource,
        "-o", $socketNoDelayExecutable,
        "--target", "windows-x64",
        "--llvm", $llvmDir,
        "--stdlib", $stdlibRoot,
        "--jobs", $Stage2BuildJobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
        "-O1", "--keep-temps") `
    -OutputPath $socketNoDelayOutput `
    -ErrorPath $socketNoDelayError
Assert-ProcessSucceeded $socketNoDelayProcess $socketNoDelayError "stage-2 socket no-delay native build"
if (-not (Test-Path $socketNoDelayLlvm) -or -not (Test-Path $socketNoDelayExecutable)) {
    throw "stage-2 socket no-delay build did not retain LLVM and executable artifacts"
}
& $llvmAsPath $socketNoDelayLlvm -o ([System.IO.Path]::ChangeExtension($socketNoDelayExecutable, ".bc"))
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$socketNoDelayRun = Invoke-VerificationProcessCapture `
    -FilePath $socketNoDelayExecutable `
    -Description "stage-2 socket no-delay executable"
$socketNoDelayActual = $socketNoDelayRun.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
$socketNoDelayExpectedText = [System.IO.File]::ReadAllText($socketNoDelayExpected).Replace("`r`n", "`n").TrimEnd("`n")
if ($socketNoDelayRun.ExitCode -ne 0 -or $socketNoDelayActual -ne $socketNoDelayExpectedText) {
    throw "stage-2 socket no-delay execution failed: '$socketNoDelayActual'"
}
& (Join-Path $PSScriptRoot "verify-native-socket-timeouts.ps1") `
    -Compiler $stage2Path `
    -Label "stage2" `
    -Platform windows `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-mutable-parameter-indexing-batch.ps1") `
    -Compiler $stage2Path `
    -Label "stage2" `
    -Platform windows `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-interpolation-reference-arguments.ps1") `
    -Compiler $stage2Path `
    -Label "stage2" `
    -Platform windows `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-projected-reference-places.ps1") `
    -Compiler $stage2Path `
    -Label "stage2" `
    -Platform windows `
    -LlvmRoot $llvmDir `
    -StdlibRoot $stdlibRoot `
    -RepositoryRoot $repoRoot `
    -OutputDirectory $artifactsDir `
    -Jobs $Stage2BuildJobs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$stage1FingerprintOutput = Join-Path $artifactsDir "stage2-check-fingerprint-stage1.txt"
$stage2FingerprintOutput = Join-Path $artifactsDir "stage2-check-fingerprint-stage2.txt"
$stage1FingerprintError = Join-Path $artifactsDir "stage2-check-fingerprint-stage1.err"
$stage2FingerprintError = Join-Path $artifactsDir "stage2-check-fingerprint-stage2.err"
$fingerprintArguments = @("fingerprint") + $fingerprintSources
$stage1FingerprintProcess = Invoke-ProcessToFile $stage1Path $fingerprintArguments $stage1FingerprintOutput $stage1FingerprintError
$stage2FingerprintProcess = Invoke-ProcessToFile $stage2Path $fingerprintArguments $stage2FingerprintOutput $stage2FingerprintError
Assert-ProcessSucceeded $stage1FingerprintProcess $stage1FingerprintError "stage-1 module fingerprint emission"
Assert-ProcessSucceeded $stage2FingerprintProcess $stage2FingerprintError "stage-2 module fingerprint emission"
$stage1Fingerprints = [System.IO.File]::ReadAllText($stage1FingerprintOutput).Replace("`r`n", "`n")
$stage2Fingerprints = [System.IO.File]::ReadAllText($stage2FingerprintOutput).Replace("`r`n", "`n")
if ($stage1Fingerprints -ne $stage2Fingerprints) {
    throw "stage-1 and stage-2 module fingerprints differ"
}
$fingerprintLineCount = ([regex]::Matches($stage2Fingerprints, '(?m)^module fingerprint = \d+,\d+,\d+,\d+,\d+,\d+,\d+$')).Count
if ($fingerprintLineCount -ne 3) {
    throw "stage-2 module fingerprint mode emitted $fingerprintLineCount records instead of 3"
}
$stage2PrepareOutput = Join-Path $artifactsDir "stage2-check-prepare-stage2.txt"
$stage2PrepareError = Join-Path $artifactsDir "stage2-check-prepare-stage2.err"
$prepareArguments = @("prepare") + $fingerprintSources
$stage2PrepareProcess = Invoke-ProcessToFile $stage2Path $prepareArguments $stage2PrepareOutput $stage2PrepareError
Assert-ProcessSucceeded $stage2PrepareProcess $stage2PrepareError "stage-2 semantic prepare"
$stage2Prepare = [System.IO.File]::ReadAllText($stage2PrepareOutput).Replace("`r`n", "`n")
if ($stage2Prepare -notmatch '^semantic prepare = \d+,\d+,\d+\r?\n?$') {
    throw "stage-2 semantic prepare emitted an invalid summary: $stage2Prepare"
}
$stage1CacheOutput = Join-Path $artifactsDir "stage2-check-module-cache-stage1.txt"
$stage2CacheOutput = Join-Path $artifactsDir "stage2-check-module-cache-stage2.txt"
$stage1CacheError = Join-Path $artifactsDir "stage2-check-module-cache-stage1.err"
$stage2CacheError = Join-Path $artifactsDir "stage2-check-module-cache-stage2.err"
$stage1CachePath = Join-Path $artifactsDir "stage2-check-module-cache-stage1.bin"
$stage1CacheTemporary = Join-Path $artifactsDir "stage2-check-module-cache-stage1.tmp"
$stage2CachePath = Join-Path $artifactsDir "stage2-check-module-cache-stage2.bin"
$stage2CacheTemporary = Join-Path $artifactsDir "stage2-check-module-cache-stage2.tmp"
# A warm destination can hide effect reordering by letting load observe the
# previous process's cache before the current publish. Always exercise the
# cold create -> publish -> load sequence.
Remove-Item -LiteralPath $stage1CachePath, $stage1CacheTemporary, $stage2CachePath, $stage2CacheTemporary -ErrorAction SilentlyContinue
$stage1CacheArguments = @("interface-cache", $stage1CachePath, $stage1CacheTemporary) + $fingerprintSources
$stage2CacheArguments = @("interface-cache", $stage2CachePath, $stage2CacheTemporary) + $fingerprintSources
$stage1CacheProcess = Invoke-ProcessToFile $stage1Path $stage1CacheArguments $stage1CacheOutput $stage1CacheError
$stage2CacheProcess = Invoke-ProcessToFile $stage2Path $stage2CacheArguments $stage2CacheOutput $stage2CacheError
Assert-ProcessSucceeded $stage1CacheProcess $stage1CacheError "stage-1 module-cache planner"
Assert-ProcessSucceeded $stage2CacheProcess $stage2CacheError "stage-2 module-cache planner"
$stage1CacheText = ([System.IO.File]::ReadAllText($stage1CacheOutput)).Trim()
$stage2CacheText = ([System.IO.File]::ReadAllText($stage2CacheOutput)).Trim()
if ($stage1CacheText -ne "module cache = 0,3,0,0,1") {
    throw "stage-1 module-cache planner result differed: $stage1CacheText"
}
if ($stage2CacheText -ne "module cache = 0,3,0,0,1") {
    throw "stage-2 module-cache planner result differed: $stage2CacheText"
}
$stage1ArtifactOutput = Join-Path $artifactsDir "stage2-check-module-artifacts-stage1.txt"
$stage2ArtifactOutput = Join-Path $artifactsDir "stage2-check-module-artifacts-stage2.txt"
$stage1ArtifactError = Join-Path $artifactsDir "stage2-check-module-artifacts-stage1.err"
$stage2ArtifactError = Join-Path $artifactsDir "stage2-check-module-artifacts-stage2.err"
$artifactArguments = @("module-artifacts") + $fingerprintSources
$stage1ArtifactProcess = Invoke-ProcessToFile $stage1Path $artifactArguments $stage1ArtifactOutput $stage1ArtifactError
$stage2ArtifactProcess = Invoke-ProcessToFile $stage2Path $artifactArguments $stage2ArtifactOutput $stage2ArtifactError
Assert-ProcessSucceeded $stage1ArtifactProcess $stage1ArtifactError "stage-1 canonical module artifacts"
Assert-ProcessSucceeded $stage2ArtifactProcess $stage2ArtifactError "stage-2 canonical module artifacts"
$stage1ArtifactText = ([System.IO.File]::ReadAllText($stage1ArtifactOutput)).Trim()
$stage2ArtifactText = ([System.IO.File]::ReadAllText($stage2ArtifactOutput)).Trim()
if ($stage1ArtifactText -ne "module artifacts = 0,3,1") {
    throw "stage-1 canonical module artifacts differed: $stage1ArtifactText"
}
if ($stage2ArtifactText -ne $stage1ArtifactText) {
    throw "stage-2 canonical module artifacts differed: $stage2ArtifactText"
}
$stage1CodegenOutput = Join-Path $artifactsDir "stage2-check-codegen-units-stage1.txt"
$stage2CodegenOutput = Join-Path $artifactsDir "stage2-check-codegen-units-stage2.txt"
$stage1CodegenError = Join-Path $artifactsDir "stage2-check-codegen-units-stage1.err"
$stage2CodegenError = Join-Path $artifactsDir "stage2-check-codegen-units-stage2.err"
$stage1CodegenProcess = Invoke-ProcessToFile $stage1Path @("llvm-codegen-units") $stage1CodegenOutput $stage1CodegenError
$stage2CodegenProcess = Invoke-ProcessToFile $stage2Path @("llvm-codegen-units") $stage2CodegenOutput $stage2CodegenError
Assert-ProcessSucceeded $stage1CodegenProcess $stage1CodegenError "stage-1 canonical codegen units"
Assert-ProcessSucceeded $stage2CodegenProcess $stage2CodegenError "stage-2 canonical codegen units"
$stage1CodegenText = ([System.IO.File]::ReadAllText($stage1CodegenOutput)).Trim()
$stage2CodegenText = ([System.IO.File]::ReadAllText($stage2CodegenOutput)).Trim()
if ($stage1CodegenText -ne "codegen units = 0,2,6") {
    throw "stage-1 canonical codegen units differed: $stage1CodegenText"
}
if ($stage2CodegenText -ne $stage1CodegenText) {
    throw "stage-2 canonical codegen units differed: $stage2CodegenText"
}
$publicStage2Llvm = Join-Path $artifactsDir "stage2-check-public-stdlib-stage2.ll"
$publicStage2Error = Join-Path $artifactsDir "stage2-check-public-stdlib-stage2.err"
$legacyPublicStage1Llvm = Join-Path $artifactsDir "stage2-check-public-stdlib-stage1.ll"
$legacyPublicStage1Error = Join-Path $artifactsDir "stage2-check-public-stdlib-stage1.err"
Remove-Item -LiteralPath $legacyPublicStage1Llvm, $legacyPublicStage1Error -ErrorAction SilentlyContinue
$publicArguments = @("windows-stdlib", $stdlibRoot, $singleSource)
$publicStage2Process = Invoke-ProcessToFile $stage2Path $publicArguments $publicStage2Llvm $publicStage2Error
Assert-ProcessSucceeded $publicStage2Process $publicStage2Error "stage-2 public stdlib source-root emission"
if (-not [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($publicStage2Error))) {
    throw "stage-2 public stdlib source-root emission produced diagnostics"
}
$publicExecutable = Join-Path $artifactsDir "stage2-check-public-stdlib.exe"
& $llvmAsPath $publicStage2Llvm -o ([System.IO.Path]::ChangeExtension($publicExecutable, ".bc"))
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $publicStage2Llvm -O1 -o $publicExecutable @windowsRuntimeLibraries
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$publicRun = Invoke-VerificationProcessCapture `
    -FilePath $publicExecutable `
    -Description "stage-2 public stdlib executable"
$publicActual = $publicRun.Stdout.TrimEnd("`r", "`n")
if ($publicRun.ExitCode -ne 0 -or $publicActual -ne "stage2-single-ok") {
    throw "public stdlib source-root execution failed: expected 'stage2-single-ok', actual '$publicActual'"
}
& (Join-Path $PSScriptRoot "verify-native-source-style.ps1") -Compiler $stage2Path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-cli-format.ps1") -Compiler $stage2Path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot "verify-native-binary-codecs.ps1") -Compiler $stage2Path -LlvmHome $llvmDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "[stage2 5/7] PASS execution, Result propagation control order, current-generation public stdlib source root, native source style, native formatting, native binary/CRC codecs, native build, fingerprints, module cache, typed-IR artifacts, and codegen-unit parity."

Write-Host "[stage2 6/7] Enforce production ownership diagnostics E17 through E23."
foreach ($conflict in @(
    @($borrowConflictSource, "single"),
    @($borrowUnionConflictSource, "union"),
    @($borrowAliasConflictSource, "alias"),
    @($borrowAggregateConflictSource, "aggregate"),
    @($borrowProjectionConflictSource, "projection")
)) {
    foreach ($compiler in @(
        @($stage1Path, "stage1"),
        @($stage2Path, "stage2")
    )) {
        $diagnosticOutput = Join-Path $artifactsDir "stage2-check-borrow-$($conflict[1])-$($compiler[1]).txt"
        $diagnosticError = Join-Path $artifactsDir "stage2-check-borrow-$($conflict[1])-$($compiler[1]).err"
        $diagnosticProcess = Invoke-ProcessToFile `
            -FilePath $compiler[0] `
            -ArgumentList @("windows", $conflict[0], $borrowSourceRuntime) `
            -OutputPath $diagnosticOutput `
            -ErrorPath $diagnosticError
        Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) borrow-conflict diagnostic"
        $diagnosticProcess.Refresh()
        if ($diagnosticProcess.ExitCode -eq 0) {
            throw "$($compiler[1]) accepted a $($conflict[1])-origin move with a live borrowed Text view"
        }
        $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
        if ($diagnosticText -notmatch 'error\[E21\].*origin moved while a borrowed Text view is still live') {
            throw "$($compiler[1]) did not emit ownership diagnostic E21 for $($conflict[1]) origin: '$diagnosticText'"
        }
        if ($diagnosticText -match '^target (datalayout|triple)') {
            throw "$($compiler[1]) began LLVM emission before rejecting $($conflict[1])-origin diagnostic E21"
        }
    }
}
foreach ($compiler in @(
    @($stage1Path, "stage1"),
    @($stage2Path, "stage2")
)) {
    $diagnosticOutput = Join-Path $artifactsDir "stage2-check-partial-move-$($compiler[1]).txt"
    $diagnosticError = Join-Path $artifactsDir "stage2-check-partial-move-$($compiler[1]).err"
    $diagnosticProcess = Invoke-ProcessToFile `
        -FilePath $compiler[0] `
        -ArgumentList @("windows", $partialMoveConflictSource) `
        -OutputPath $diagnosticOutput `
        -ErrorPath $diagnosticError
    Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) partial-move diagnostic"
    $diagnosticProcess.Refresh()
    if ($diagnosticProcess.ExitCode -eq 0) {
        throw "$($compiler[1]) accepted a reachable whole-owner use after a partial move"
    }
    $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
    if ($diagnosticText -notmatch 'error\[E17\].*use of a partially moved value') {
        throw "$($compiler[1]) did not emit ownership diagnostic E17: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($compiler[1]) began LLVM emission before rejecting partial-move diagnostic E17"
    }
}
foreach ($compiler in @(
    @($stage1Path, "stage1"),
    @($stage2Path, "stage2")
)) {
    $diagnosticOutput = Join-Path $artifactsDir "stage2-check-branch-partial-move-$($compiler[1]).txt"
    $diagnosticError = Join-Path $artifactsDir "stage2-check-branch-partial-move-$($compiler[1]).err"
    $diagnosticProcess = Invoke-ProcessToFile `
        -FilePath $compiler[0] `
        -ArgumentList @("windows", $branchPartialMoveConflictSource) `
        -OutputPath $diagnosticOutput `
        -ErrorPath $diagnosticError
    Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) branch-partial-move diagnostic"
    $diagnosticProcess.Refresh()
    if ($diagnosticProcess.ExitCode -eq 0) {
        throw "$($compiler[1]) accepted a branch that exits with a partial move"
    }
    $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
    if ($diagnosticText -notmatch 'error\[E20\].*partial move exits a branch or loop without reinitialization') {
        throw "$($compiler[1]) did not emit ownership diagnostic E20: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($compiler[1]) began LLVM emission before rejecting branch-partial-move diagnostic E20"
    }
}
foreach ($compiler in @(
    @($stage1Path, "stage1"),
    @($stage2Path, "stage2")
)) {
    $diagnosticOutput = Join-Path $artifactsDir "stage2-check-parallel-mutable-capture-$($compiler[1]).txt"
    $diagnosticError = Join-Path $artifactsDir "stage2-check-parallel-mutable-capture-$($compiler[1]).err"
    $diagnosticProcess = Invoke-ProcessToFile `
        -FilePath $compiler[0] `
        -ArgumentList @("windows", $parallelMutableCaptureSource) `
        -OutputPath $diagnosticOutput `
        -ErrorPath $diagnosticError
    Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) mutable parallel-capture diagnostic"
    $diagnosticProcess.Refresh()
    if ($diagnosticProcess.ExitCode -eq 0) {
        throw "$($compiler[1]) accepted a transitive mutable parallel capture"
    }
    $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
    if ($diagnosticText -notmatch 'error\[E18\].*mutable binding captured by a parallel callback') {
        throw "$($compiler[1]) did not emit ownership diagnostic E18: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($compiler[1]) began LLVM emission before rejecting parallel-capture diagnostic E18"
    }
}
foreach ($compiler in @(
    @($stage1Path, "stage1"),
    @($stage2Path, "stage2")
)) {
    $diagnosticOutput = Join-Path $artifactsDir "stage2-check-parallel-nonsendable-capture-$($compiler[1]).txt"
    $diagnosticError = Join-Path $artifactsDir "stage2-check-parallel-nonsendable-capture-$($compiler[1]).err"
    $diagnosticProcess = Invoke-ProcessToFile `
        -FilePath $compiler[0] `
        -ArgumentList @("windows", $parallelNonSendableCaptureSource) `
        -OutputPath $diagnosticOutput `
        -ErrorPath $diagnosticError
    Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) non-sendable parallel-capture diagnostic"
    $diagnosticProcess.Refresh()
    if ($diagnosticProcess.ExitCode -eq 0) {
        throw "$($compiler[1]) accepted a transitive non-sendable parallel capture"
    }
    $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
    if ($diagnosticText -notmatch 'error\[E19\].*non-sendable binding captured by a parallel callback') {
        throw "$($compiler[1]) did not emit ownership diagnostic E19: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($compiler[1]) began LLVM emission before rejecting parallel-capture diagnostic E19"
    }
}
foreach ($compiler in @(
    @($stage1Path, "stage1"),
    @($stage2Path, "stage2")
)) {
    $diagnosticOutput = Join-Path $artifactsDir "stage2-check-reference-temporary-$($compiler[1]).txt"
    $diagnosticError = Join-Path $artifactsDir "stage2-check-reference-temporary-$($compiler[1]).err"
    $diagnosticProcess = Invoke-ProcessToFile $compiler[0] @("windows", $referenceTemporarySource) $diagnosticOutput $diagnosticError
    Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) temporary-reference diagnostic"
    $diagnosticProcess.Refresh()
    if ($diagnosticProcess.ExitCode -eq 0) { throw "$($compiler[1]) accepted a temporary readonly-reference argument" }
    $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
    if ($diagnosticText -notmatch 'error\[E22\].*requires an addressable owner or reference; literals and temporary values cannot be borrowed') {
        throw "$($compiler[1]) did not emit ownership diagnostic E22: '$diagnosticText'"
    }
    if ($diagnosticText -match '^target (datalayout|triple)') {
        throw "$($compiler[1]) began LLVM emission before rejecting readonly-reference diagnostic E22"
    }
}
foreach ($compiler in @(
    @($stage1Path, "stage1"),
    @($stage2Path, "stage2")
)) {
    foreach ($referenceConflict in @(
        @($referenceLivenessSource, "mutation"),
        @($referenceOwnerMoveSource, "move"),
        @($referenceLoopContinueSource, "loop-continue"),
        @($referenceStoredStructSource, "stored-struct"),
        @($referenceStoredEnumSource, "stored-enum"),
        @($referenceStoredArraySource, "stored-array")
    )) {
        $diagnosticOutput = Join-Path $artifactsDir "stage2-check-reference-$($referenceConflict[1])-$($compiler[1]).txt"
        $diagnosticError = Join-Path $artifactsDir "stage2-check-reference-$($referenceConflict[1])-$($compiler[1]).err"
        $diagnosticProcess = Invoke-ProcessToFile $compiler[0] @("windows", $referenceConflict[0]) $diagnosticOutput $diagnosticError
        Wait-VerificationProcess $diagnosticProcess "$($compiler[1]) $($referenceConflict[1])-reference diagnostic"
        $diagnosticProcess.Refresh()
        if ($diagnosticProcess.ExitCode -eq 0) { throw "$($compiler[1]) accepted owner $($referenceConflict[1]) with a live readonly reference" }
        $diagnosticText = [System.IO.File]::ReadAllText($diagnosticOutput)
        if ($diagnosticText -notmatch 'error\[E23\].*owner mutation conflicts with a live readonly reference') {
            throw "$($compiler[1]) did not emit ownership diagnostic E23 for owner $($referenceConflict[1]): '$diagnosticText'"
        }
        if ($diagnosticText -match '^target (datalayout|triple)') {
            throw "$($compiler[1]) began LLVM emission before rejecting readonly-reference owner $($referenceConflict[1]) diagnostic E23"
        }
    }

    foreach ($referenceEscape in @(
        @($referenceAggregateEscapeSource, "aggregate-escape"),
        @($referenceEnumEscapeSource, "enum-escape"),
        @($referenceArrayEscapeSource, "array-escape")
    )) {
        $aggregateEscapeOutput = Join-Path $artifactsDir "stage2-check-reference-$($referenceEscape[1])-$($compiler[1]).txt"
        $aggregateEscapeError = Join-Path $artifactsDir "stage2-check-reference-$($referenceEscape[1])-$($compiler[1]).err"
        $aggregateEscapeProcess = Invoke-ProcessToFile $compiler[0] @("windows", $referenceEscape[0]) $aggregateEscapeOutput $aggregateEscapeError
        Wait-VerificationProcess $aggregateEscapeProcess "$($compiler[1]) $($referenceEscape[1])-escape diagnostic"
        $aggregateEscapeProcess.Refresh()
        $aggregateEscapeText = (Get-Content $aggregateEscapeOutput -Raw) + (Get-Content $aggregateEscapeError -Raw)
        if ($aggregateEscapeProcess.ExitCode -eq 0) { throw "$($compiler[1]) accepted returned $($referenceEscape[1]) containing a callee-owned readonly reference" }
        if ($aggregateEscapeText -notmatch 'error\[E22\]') {
            throw "$($compiler[1]) did not emit ownership diagnostic E22 for $($referenceEscape[1]): '$aggregateEscapeText'"
        }
        if ($aggregateEscapeText -match 'target triple') {
            throw "$($compiler[1]) began LLVM emission before rejecting $($referenceEscape[1]) diagnostic E22"
        }
    }
}
Write-Host "[stage2 6/7] PASS E17-E23 ownership violations block LLVM emission in stage-1 and stage-2."
& (Join-Path $PSScriptRoot "verify-selfhost-owned-block-result-diagnostics.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
Write-Host "[stage2 6/7] PASS E27 owned block results require an explicit owner binding in stage-2."
& (Join-Path $PSScriptRoot "verify-selfhost-owned-container-rebind-diagnostic.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
Write-Host "[stage2 6/7] PASS E28 owned container replacement requires one selected owner in stage-2."
& (Join-Path $PSScriptRoot "verify-selfhost-semantic-parity-diagnostics.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
Write-Host "[stage2 6/7] PASS logical operands and enum exhaustiveness match the source-language diagnostics."
& (Join-Path $PSScriptRoot "verify-selfhost-trait-ownership-diagnostics.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-owned-array-cleanup.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "verify-selfhost-arguments-runtime.ps1") `
    -Compiler $stage2Path `
    -RepositoryRoot $repoRoot `
    -LlvmRoot $llvmDir
$argumentsCompilerHash = (Get-FileHash -LiteralPath $stage2Path -Algorithm SHA256).Hash
Copy-Item -LiteralPath (Join-Path $repoRoot "artifacts/arguments-runtime/$argumentsCompilerHash/results.json") `
    -Destination (Join-Path $artifactsDir "stage2-arguments-runtime.json") -Force
foreach ($diagnosticCompiler in @(
    [ordered]@{ Name = "stage1"; Path = $stage1Path },
    [ordered]@{ Name = "stage2"; Path = $stage2Path }
)) {
    & (Join-Path $PSScriptRoot "verify-selfhost-unresolved-call-diagnostic.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -RepositoryRoot $repoRoot
    & (Join-Path $PSScriptRoot "verify-selfhost-interpolation-capacity-diagnostics.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -RepositoryRoot $repoRoot
    & (Join-Path $PSScriptRoot "verify-selfhost-result-propagation-diagnostics.ps1") `
        -Compiler $diagnosticCompiler.Path `
        -Label $diagnosticCompiler.Name `
        -RepositoryRoot $repoRoot
}
Write-Host "[stage2 6/7] PASS unresolved calls, invalid Result propagation, and invalid capacity receivers remain blocked before LLVM in stage-1 and stage-2."

Write-Host "[stage2 7/7] Compare C# reference and native Sollang compiler runtime behavior."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --skip-bootstrap `
    --compare-compilers `
    --exact 377-selfhost-llvm-source-text-worker-transfer `
    --exact 787-selfhost-file-write-match-subject-ir `
    --exact 1119-time-checked-instance-arithmetic `
    --exact 1120-selfhost-negated-long-literal-context `
    --exact 1121-selfhost-consecutive-control-consumers `
    --exact 1122-consecutive-control-consumer-runtime `
    --exact 1123-selfhost-materialized-console-call `
    --exact 1124-function-control-consumer-runtime `
    --exact 1125-control-region-consumer-runtime `
    --exact 1126-selfhost-console-emission-invariant `
    --exact 1127-unreachable-parallel-callback `
    --exact 1128-selfhost-late-set-intrinsic-classification `
    --exact 1129-selfhost-control-producer-call-shape `
    --exact 1130-four-term-logical-binding `
    --exact 1131-selfhost-four-term-logical-ir `
    --exact 1132-process-child-wait `
    --exact 1133-process-child-scope-drop `
    --exact 1140-selfhost-directory-intrinsic-ir `
    --exact 1143-enum-match-negative-unary-result `
    --exact 1147-mut-parameter-refresh-after-call `
    --exact 1148-second-mut-parameter-refresh-after-call `
    --exact 1149-control-region-mut-parameter-refresh `
    --exact 1150-while-region-mut-parameter-refresh `
    --exact 1151-mutable-parameter-indexing-matrix `
    --exact 1152-early-return-before-checked-index `
    --exact 1153-checked-index-control-before-logical-result `
    --exact 1157-call-wrapped-checked-index-after-early-return `
    --exact 1154-multiline-redundant-control-parentheses-note `
    --exact 1155-multiline-partial-control-parentheses-preserved `
    --exact 1156-interpolation-readonly-struct-reference `
    --exact 1162-selfhost-zero-argument-mut-receiver `
    --exact 1163-selfhost-method-receiver-metadata `
    --exact 1164-selfhost-unqualified-literal-receiver-resolution `
    --exact 1165-selfhost-method-receiver-invariant `
    --exact 1168-qualified-literal-instance-precedence `
    --exact 1169-selfhost-process-instance-precedence `
    --exact 1170-instance-call-after-each-return `
    --exact 1171-process-call-after-each-return `
    --exact 1172-selfhost-qualified-impl-receiver `
    --exact 1173-selfhost-projected-binding-method `
    --exact 987-selfhost-nested-arithmetic-width-contract `
    --exact 1174-selfhost-projected-socket-close-intrinsic `
    --exact 1175-ref-struct-receiver-inside-while `
    --exact 1176-ref-struct-direct-call-forwarding `
    --exact 1177-ref-struct-array-element-assignment `
    --exact 1178-call-result-receiver-before-literal-fallback `
    --exact 1179-process-stdio-file-instance `
    --exact 1180-process-stdio-null-instance `
    --exact 1181-process-status-to-file-configuration `
    --exact 1182-process-bounded-concurrent-capture `
    --exact 1183-process-zero-limit-concurrent-capture `
    --exact 1184-non-process-collect-has-no-process-runtime `
    --exact 1185-selfhost-projected-receiver-instance-call `
    --exact 1186-selfhost-interpolation-projected-call-topology `
    --exact 1187-selfhost-raw-string-no-interpolation `
    --exact 1188-io-memory-reader-caller-buffer `
    --exact 1189-selfhost-member-assignment-after-while `
    --exact 1192-readonly-captured-nested-parameter-projection `
    --exact 1193-struct-field-collection-binding-baseline `
    --exact 1194-struct-field-collection-binding-perturbed `
    --exact 1196-selfhost-cross-fragment-ref-dynamic-array `
    --exact 1197-control-struct-array-result `
    --exact 1198-parallel-transferable-struct-worker `
    --exact 1199-local-function-parallel-callback `
    --exact 1200-parallel-nominal-readonly-captures `
    --exact 1201-parallel-move-parameter `
    --exact 1202-array-element-owner-replacement-after-read `
    --exact 1203-selfhost-enum-payload-binary-binding `
    --exact 1204-selfhost-enum-payload-binary-binding-permuted `
    --exact 1206-quic-bidirectional-multi-stream-routing `
    --exact 1207-enum-owned-payload-projected-queue `
    --exact 1208-multiline-projected-assignment `
    --exact 1209-quic-connection-options-queue-limits `
    --exact 1210-quic-directional-control-frames `
    --exact 1211-quic-directional-owner-transitions `
    --exact 1212-selfhost-member-assignment-after-take `
    --exact 1213-selfhost-result-field-transfer-after-take `
    --exact 1214-gzip-transactional-streaming-decoder `
    --exact 1215-gzip-incremental-byte-boundaries `
    --exact 1216-late-indexed-element-array-type `
    --exact 1217-selfhost-late-indexed-array-type-contract `
    --exact 1220-zstd-raw-rle-streaming `
    --exact 1304-zstd-literal-only-compressed-block `
    --exact 1305-selfhost-interpolation-numeric-separator `
    --exact 1306-zstd-direct-huffman-literals `
    --exact 1308-selfhost-nested-result-many-argument-owner `
    --exact 1309-selfhost-terminating-if-branch-result `
    --exact 1321-parallel-additional-borrow-result `
    --exact 1228-xxhash64-streaming `
    --exact 1229-http-body-framing `
    --exact 1230-selfhost-short-circuit-array-argument `
    --exact 1231-selfhost-nested-result-match-value `
    --exact 1232-selfhost-console-call-owns-if-result `
    --exact 1233-http-response-head-writer `
    --exact 1385-http-request-head-writer `
    --exact 1386-http-client-connection-reuse `
    --exact 1388-selfhost-imported-ref-struct-value-receiver `
    --exact 1389-selfhost-nested-aggregate-partial-move-cleanup `
    --exact 1391-opaque-struct-instance-boundary `
    --exact 1392-selfhost-opaque-struct-ast `
    --exact 1393-selfhost-opaque-struct-diagnostics `
    --exact diagnostic/opaque-struct-construction `
    --exact diagnostic/opaque-struct-field-read `
    --exact diagnostic/opaque-struct-field-write `
    --exact diagnostic/opaque-struct-modifier-rejected `
    --exact diagnostic/private-inferred-field-chain `
    --exact 1352-selfhost-consuming-call-owned-outcome `
    --exact 1234-selfhost-parallel-nested-flow-arguments `
    --exact 1236-socket-send-range-all `
    --exact 1240-http-one-request-server `
    --exact 1340-selfhost-result-arm-owned-field-transfer `
    --exact 1341-http-persistent-pipeline `
    --exact 1354-selfhost-read-before-direct-self-consume `
    --exact 1379-selfhost-nested-control-implicit-return `
    --exact 1382-selfhost-terminal-flow-control-return `
    --exact 1383-selfhost-inferred-receiver-method-owner `
    --exact 1384-nested-result-logical-condition `
    --exact 1395-selfhost-aggregate-child-index-rules `
    --exact 1404-function-tail-each-statement `
    --exact 1405-selfhost-collection-comprehension-syntax `
    --exact 1406-selfhost-constant-integer-arithmetic `
    --exact 1407-module-local-enum-identity `
    --exact 1408-selfhost-qualified-value-shadow `
    --exact 1409-import-qualified-enum-pattern `
    --exact 1410-selfhost-constant-expression-plan `
    --exact 1411-borrowed-receiver-error-reuse `
    --exact 1412-direct-result-control-match `
    --exact 1413-selfhost-constant-collection-expansion `
    --exact 1414-module-local-range-identity `
    --exact 1415-imported-result-projected-each-element `
    --exact 1416-result-match-propagation-producer `
    --exact 1417-imported-result-match-propagation `
    --exact 1418-function-enum-constructor-call-chain `
    --exact 1419-selfhost-constant-collection-lowering `
    --exact 1420-owned-flow-result-preserves-input `
    --exact 1421-early-return-aggregate-move-input `
    --exact 1422-owned-enum-payload-block-result `
    --exact 1423-disjoint-owned-field-transfer `
    --exact 1424-nested-each-interpolation `
    --exact 1425-nested-match-result-constructor `
    --exact 1426-dictionary-index-interpolation `
    --exact 1427-enum-reference-payload-forwarding `
    --exact 1428-mutable-scalar-readonly-reference `
    --exact 1429-tap-side-call-argument-plan `
    --exact 1430-tap-explicit-side-chain `
    --exact 1431-trait-constant-method-receiver `
    --exact 1432-dyn-trait-reachable-implementations `
    --exact 1433-parallel-existing-role-array-references `
    --exact 1434-multistage-console-wrapper `
    --exact 1435-dyn-result-console-wrapper `
    --exact 1436-user-printer-method-flow `
    --exact 1437-generic-inherent-method `
    --exact 1438-generic-method-inference-types `
    --exact 1439-generic-method-trait-constraint `
    --exact 1440-generic-method-owner-scope `
    --exact 1441-generic-function-concrete-abi `
    --exact 1442-selfhost-generic-multi-input-unification `
    --exact 1443-selfhost-generic-method-call-type-isolation `
    --exact 1444-each-mutable-nested-control `
    --exact 1445-each-role-projected-readonly-array `
    --exact 1446-member-assignment-lexical-sibling `
    --exact 1447-generic-trait-constraint-isolation `
    --exact 1448-nested-generic-method-helper `
    --exact 1449-recursive-generic-call-closure `
    --exact 1450-selfhost-generic-closure-reuse `
    --exact 1451-dictionary-absent-instance-result `
    --exact 1452-each-call-result-record-type `
    --exact 1453-each-push-return-alias `
    --exact 1454-trait-imported-collision-main `
    --exact 1455-trait-contract-buffer `
    --exact 1456-trait-associated-array `
    --exact 1457-trait-associated-dictionary `
    --exact 1458-trait-associated-result `
    --exact 1459-trait-associated-fixed `
    --exact 1460-fixed-array-length-preservation `
    --exact 1461-indexed-owned-readonly-positive `
    --exact 1462-indexed-owned-additional-readonly-positive `
    --exact 1463-generic-owned-take-positive `
    --exact 1464-generic-owned-nested-take-positive `
    --exact 1465-chained-match-fixed-enum-array `
    --exact 1466-moving-fixed-array-implicit-cleanup `
    --exact 1467-moving-fixed-array-explicit-cleanup `
    --exact 1468-arena-explicit-return `
    --exact 1469-region-array-scalar-parameters `
    --exact 1470-region-array-bool-literals `
    --exact 1471-region-array-readonly-values `
    --exact 1472-region-array-owned-transfer `
    --exact 1473-struct-initializer-effect-order `
    --exact 1474-array-capacity-hint-contexts `
    --exact 1475-region-array-partial-field-transfer `
    --exact 1476-entry-mutable-binding-scope `
    --exact 1477-typed-record-array-field-identity `
    --exact 1480-direct-repeat-readonly-slice `
    --exact 1482-signed-unary-contexts `
    --exact 1481-resolved-call-early-return-cleanup `
    --exact 1497-narrow-integer-parameter-print `
    --exact 1498-hmac-streaming-segments `
    --exact 1501-bound-imported-method-owner `
    --exact 1502-same-call-projected-owner-controls `
    --exact 1503-nested-call-statement-effect-order `
    --exact 1504-readonly-fixed-call-temporary-cleanup `
    --exact 1505-readonly-independent-copy-cleanup `
    --exact 1506-readonly-owned-element-temporary-cleanup `
    --exact 1507-empty-unit-function-contract `
    --exact 1508-named-fixed-named-reuse-cleanup `
    --exact 1509-named-fixed-stack-literal-cleanup `
    --exact 1510-named-fixed-implicit-return-cleanup `
    --exact 1511-named-fixed-explicit-return-cleanup `
    --exact 1512-named-fixed-early-scalar-return-cleanup `
    --exact 1513-named-fixed-owned-element-named-cleanup `
    --exact 1514-named-fixed-moved-owner-cleanup `
    --exact 1515-named-fixed-ref-return-cleanup `
    --exact 1516-named-fixed-before-binding-return-cleanup `
    --exact 1517-named-fixed-loop-region-cleanup `
    --exact 1518-local-function-intrinsic-collision `
    --exact 1519-fixed-stack-argument-return `
    --exact 1520-fixed-named-argument-return `
    --exact 1521-fixed-implicit-moving-wrapper `
    --exact 1522-fixed-explicit-moving-wrapper `
    --exact 1523-fixed-owned-explicit-wrapper `
    --exact 1524-fixed-owned-implicit-wrapper `
    --exact 1525-fixed-additional-argument-return `
    --exact 1526-fixed-branch-explicit-return `
    --exact 1527-projected-table-push-loop `
    --exact 1528-fixed-field-factory `
    --exact 1529-fixed-field-named `
    --exact 1530-fixed-field-stack `
    --exact 1531-fixed-field-owned `
    --exact 1532-fixed-field-region `
    --exact 1533-fixed-branch-binding `
    --exact 1534-fixed-branch-loop-binding `
    --exact 1535-branch-value-owner `
    --exact 1536-branch-value-fixed `
    --exact 1537-branch-fixed-mixed-storage `
    --exact 1538-branch-fixed-outer-reuse `
    --exact 1539-branch-fixed-owned-elements `
    --exact 1540-branch-fixed-mutable-local `
    --exact 1541-branch-fixed-return `
    --exact 1542-entry-branch-lifetime `
    --exact 1543-fixed-int-branch-result `
    --exact 1544-fixed-text-branch-result `
    --exact 1545-fixed-field-copy-independence `
    --exact 1546-logical-flow-bool `
    --exact 1547-owned-branch-taken `
    --exact 1548-owned-nested-terminating-branch `
    --exact 1549-owned-when-terminating-branch `
    --exact 1552-async-console-capability `
    --exact 1553-projected-push-sibling-reuse `
    --exact 1554-borrowed-fixed-field-copy-independence `
    --exact 1555-generic-stream-consumer-call-identity `
    --exact 1556-generic-inherent-open-import-precedence `
    --exact 1562-nested-bool-region-short-circuit-effects `
    --exact 1563-borrowed-fixed-return-copy-independence `
    --exact 1564-borrowed-nested-fixed-field-copy-independence `
    --exact 1567-borrowed-temporary-record-cleanup `
    --exact 1568-borrowed-named-record-reuse `
    --exact 1569-borrowed-flow-temporary-cleanup `
    --exact 1570-borrowed-temporary-enum-cleanup `
    --exact 1571-borrowed-temporary-independent-result `
    --exact 1572-borrowed-nested-flow-argument-cleanup `
    --exact 1573-named-mutable-receiver-borrow-reuse `
    --exact 1574-consuming-temporary-receiver-cleanup `
    --exact 1575-borrowed-enum-variant-tag-cleanup `
    --exact 1576-consuming-enum-match-cleanup `
    --exact 1577-consuming-enum-payload-transfer `
    --exact 1578-borrowed-named-enum-reuse `
    --exact 1579-borrowed-record-literal-cleanup `
    --exact 1580-borrowed-array-literal-cleanup `
    --exact 1581-borrowed-enum-literal-cleanup `
    --exact 1592-late-contextual-array-boundaries `
    --exact 1602-stream-mapped-text-flatmap-input `
    --exact 1603-stream-mapped-int-flatmap-arithmetic `
    --exact 1604-stream-mapped-flatmap-direct-roles `
    --exact 1605-stream-mapped-bool-flatmap-input `
    --exact 1606-stream-mapped-uint64-flatmap-input `
    --exact 1607-stream-bool-map-filter-input `
    --exact 1609-parameter-range-text-flatmap `
    --exact 1610-parameter-range-map-flatmap `
    --exact 1611-parameter-range-empty-flatmap `
    --exact 1612-parameter-upper-range-flatmap `
    --exact 1613-function-constant-range-flatmap `
    --exact 1614-parameter-range-direct-each `
    --exact 1598-recursive-enum-heap-owner `
    --exact 1599-recursive-enum-box-layout `
    --exact 1600-nested-enum-owned-payload `
    --exact 1601-nested-result-owned-payload `
    --exact 1619-finite-bounded-array-layout `
    --exact 1620-finite-bounded-dictionary-layout `
    --exact 1615-flatmap-single-receiver-scalar-int `
    --exact 1634-flatmap-single-receiver-text `
    --exact 1635-flatmap-single-receiver-parameter `
    --exact 1636-flatmap-single-receiver-take `
    --exact 1637-flatmap-single-receiver-empty `
    --exact 1638-flatmap-single-receiver-uint64 `
    --exact 1639-flatmap-single-receiver-bool `
    --exact 1640-flatmap-single-receiver-range-value `
    --exact 1626-boxed-recursive-enum-cleanup `
    --exact 1627-boxed-enum-named-match-reuse `
    --exact 1628-boxed-enum-payload-transfer `
    --exact 1629-boxed-primitive-cleanup `
    --exact 1630-boxed-nested-cleanup `
    --exact 1642-zero-fixed-recursive-layout `
    --exact 1643-nominal-enum-zero-fixed-payload `
    --exact 1649-static-factory-distinct-owners `
    --exact 1651-enum-integer-payload-boundaries `
    --exact 1658-unused-arguments-runtime `
    --exact 1659-arguments-runtime-lifetime `
    --exact 1660-arguments-runtime-function `
    --exact 1661-arguments-each-layout `
    --exact 1662-nominal-slice-each-direct `
    --exact 1663-nominal-slice-each-function `
    --exact 1664-nominal-slice-each-nested `
    --exact 1665-nominal-slice-each-boundary `
    --exact 1666-arguments-primary-parameter `
    --exact 1667-arguments-additional-parameter `
    --exact 1668-arguments-return-forwarding `
    --exact 1669-arguments-aggregate-storage `
    --exact 1670-arguments-branch-generic `
    --exact 1671-arguments-while-forwarding `
    --exact 1672-arguments-local-capture `
    --exact 1673-imported-struct-enum-field-prefix `
    --exact 1674-owned-field-extraction-repair `
    --exact 1675-owned-field-borrow-preserves-owner `
    --exact 1676-owned-field-replacement-keeps-drop `
    --exact 1677-scalar-enum-copy-with-sibling-text-borrow `
    --exact 1678-nested-enum-payload-move-consumer `
    --exact 1679-nested-enum-payload-borrow-inspection `
    --exact 1621-option-enum-payload-value `
    --exact 1622-nested-option-result-enum-payload `
    --exact 1623-owned-option-enum-payload-cleanup `
    --exact 1624-owned-result-enum-payload-cleanup `
    --exact 1645-runtime-result-nominal-field `
    --exact 1646-owned-runtime-result-field-cleanup `
    --exact 1647-borrowed-runtime-result-field-reuse `
    --exact 1631-boxed-enum-member-consume `
    --exact 1632-boxed-enum-member-borrow-reuse `
    --exact 1633-boxed-temporary-readonly-call `
    --exact 814-concurrent-latest-early-cancellation `
    --exact 816-concurrent-latest-uninitialized-completion `
    --exact 815-stream-join-return-signature-inference `
    --exact diagnostic/1565-borrowed-fixed-owned-element-store `
    --exact diagnostic/1566-borrowed-fixed-owned-element-return `
    --exact diagnostic/1550-mixed-owned-continuing-branches `
    --exact diagnostic/1551-partially-terminating-owned-branch `
    --exact diagnostic/1557-typed-int-array-to-byte-slice `
    --exact diagnostic/1558-additional-typed-array-element-mismatch `
    --exact diagnostic/1559-typed-fixed-array-element-mismatch `
    --exact diagnostic/1560-readonly-fixed-array-element-mismatch `
    --exact diagnostic/1561-returned-array-element-mismatch `
    --exact diagnostic/1507-empty-unit-u8-primary-overflow `
    --exact diagnostic/1507-empty-unit-u8-additional-overflow `
    --exact 1499-projected-owned-call-lifetime `
    --exact 1500-readonly-call-temporary-lifetime `
    --exact diagnostic/1499-projected-owned-call-branch `
    --exact diagnostic/1499-projected-owned-call-break `
    --exact diagnostic/1499-projected-owned-call-continue `
    --exact diagnostic/1499-projected-owned-call-loop `
    --exact diagnostic/1499-projected-owned-call-read-after-move `
    --exact diagnostic/1499-projected-owned-call-readonly `
    --exact diagnostic/1499-projected-owned-call-reuse `
    --exact diagnostic/1499-projected-owned-call-whole-owner `
    --exact diagnostic/1499-projected-owned-same-call `
    --exact diagnostic/1499-projected-owned-return-same-call `
    --exact diagnostic/1500-readonly-slice-alias-return-escape `
    --exact diagnostic/1500-readonly-slice-return-escape `
    --exact 1496-wide-integer-array-flow-context `
    --exact 1478-contextual-integer-field-boundaries `
    --exact diagnostic/typed-array-unknown-field `
    --exact diagnostic/typed-array-wrong-box-element `
    --exact diagnostic/typed-array-duplicate-field `
    --exact diagnostic/nominal-integer-variable-negative `
    --exact diagnostic/nominal-integer-minimum-negative `
    --exact diagnostic/array-integer-u8-primary-repeat-above `
    --exact diagnostic/array-integer-u8-additional-list-below `
    --exact diagnostic/array-integer-i8-primary-list-below `
    --exact diagnostic/array-integer-i8-additional-repeat-above `
    --exact diagnostic/array-integer-i16-primary-repeat-below `
    --exact diagnostic/nominal-codepoint-surrogate-negative `
    --exact diagnostic/contextual-array-element-missing-field `
    --exact diagnostic/contextual-struct-integer-literal-out-of-range `
    --exact diagnostic/struct-wrong-field-type `
    --exact 1486-interpolation-capacity-receivers `
    --exact diagnostic/1487-interpolation-capacity-fixed `
    --exact diagnostic/1488-interpolation-capacity-slice `
    --exact diagnostic/1489-interpolation-capacity-text `
    --exact 857-dictionary-put-if-absent `
    --exact 858-dictionary-put-if-absent-owned `
    --exact 66-generic-dictionary-function-contracts `
    --exact 487-selfhost-borrowed-container-return-analysis `
    --exact 1221-numeric-subject-when-arm-result `
    --exact 1222-selfhost-numeric-subject-when-binding `
    --exact 1223-contextual-intrinsic-instance-precedence `
    --exact 631-selfhost-native-handle-type `
    --exact 1095-selfhost-checked-borrowed-owned-return `
    --exact 892-quic-frame-codec `
    --exact 901-quic-ack-frame-ranges `
    --exact 941-quic-one-rtt-application-engine `
    --exact 942-owned-frame-result-field-match `
    --exact 965-consecutive-frame-encode-owned-payload `
    --exact 915-quic-version-negotiation `
    --exact 916-quic-version-packet `
    --exact 1015-quic-p2p-peer-record `
    --exact 854-set-key-only `
    --exact 365-selfhost-llvm-stage2-single-smoke `
    --exact 366-selfhost-llvm-stage2-multi-file-smoke `
    --jobs 2
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
& (Join-Path $PSScriptRoot "verify-managed-owned-call-cleanup.ps1") -RepositoryRoot $repoRoot
Write-Host "[stage2 7/7] PASS complete stage-2 differential verification."
$verifiedStage2FingerprintPath = if ($stage2WasRebuilt) {
    $stage2CandidateFingerprintPath
} else {
    $stage2FingerprintPath
}
$verifiedStage2InputFingerprint = [System.IO.File]::ReadAllText($verifiedStage2FingerprintPath).Trim()
Assert-InputFingerprintStable `
    -ExpectedFingerprint $verifiedStage2InputFingerprint `
    -CurrentFingerprint (Get-Stage2InputFingerprint) `
    -Phase "Stage2"
if ($stage2WasRebuilt) {
    Move-Item -LiteralPath $stage2LlvmPath -Destination $publishedStage2LlvmPath -Force
    Move-Item -LiteralPath $stage2BitcodePath -Destination $publishedStage2BitcodePath -Force
    Move-Item -LiteralPath $stage2Path -Destination $publishedStage2Path -Force
    $stage2LlvmPath = $publishedStage2LlvmPath
    $stage2BitcodePath = $publishedStage2BitcodePath
    $stage2Path = $publishedStage2Path
    Remove-Item -LiteralPath $stage2CandidateFingerprintPath, $stage2CandidateArtifactReceiptPath -ErrorAction SilentlyContinue
}
Write-Stage2ArtifactReceipt `
    -LlvmPath $stage2LlvmPath `
    -BitcodePath $stage2BitcodePath `
    -ExecutablePath $stage2Path `
    -ReceiptPath $stage2ArtifactReceiptPath
$stage2FingerprintCandidatePath = Get-CandidateArtifactPath $stage2FingerprintPath
[System.IO.File]::WriteAllText(
    $stage2FingerprintCandidatePath,
    $verifiedStage2InputFingerprint)
Move-Item -LiteralPath $stage2FingerprintCandidatePath -Destination $stage2FingerprintPath -Force
}
finally {
    Release-SelfHostVerificationLock $selfHostVerificationLock
}
