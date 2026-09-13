param(
    [Parameter(Mandatory)]
    [ValidateSet("Stage2", "Stage3", "Stage2Linux", "Stage3Linux", "BrowserStage2", "Incremental", "ArrayInherent", "C341Focused", "C341FinalSelfhost", "C394FinalCandidate", "ExpressionBatch", "PortableMemoryIo", "TypedBlockMutableBorrow", "BinaryChecksum", "GzipSelfhost", "AdditionalMoveOwnership", "GenericTypeContexts", "SelfhostDeferredTextStorage", "SelfhostC424NestedWholeOwner", "LinuxOwnershipStorage", "ManagedHost", "Probe")]
    [string]$Verification,
    [ValidateSet("Slg", "Stage2Bridge", "ManagedRecovery")]
    [string]$SeedMode = "Slg",
    [ValidateRange(1, 64)]
    [int]$Jobs = 8,
    [string]$Distribution = "Ubuntu",
    [switch]$ResumeCandidate,
    [string]$RunId = "",
    [string]$LogPath = "",
    [string]$CompletionRecordPath = "",
    [string]$CancellationRequestPath = "",
    [ValidateRange(1, 600)]
    [int]$CancellationTimeoutSeconds = 120,
    [string]$BrowserCandidateCompiler = "",
    [string]$BrowserFocusedFixture = "",
    [string]$IncrementalFixture = "",
    [string]$ManagedCompiler = "",
    [string]$ExpectedManagedCompilerSha256 = "",
    [string]$ExpressionBatchCompiler = "",
    [string[]]$ExpressionBatchFixture = @(),
    [string]$ExpressionBatchManifest = "",
    [string]$ExpressionBatchManifestSha256 = "",
    [string]$PortableMemoryIoCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$PortableMemoryIoExpectedCompilerSha256 = "",
    [string]$PortableMemoryIoOutputDirectory = "",
    [string]$TypedBlockMutableBorrowCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$TypedBlockMutableBorrowExpectedCompilerSha256 = "",
    [string]$TypedBlockMutableBorrowOutputDirectory = "",
    [string]$BinaryChecksumCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$BinaryChecksumExpectedCompilerSha256 = "",
    [string]$BinaryChecksumOutputDirectory = "",
    [string]$GzipSelfhostCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$GzipSelfhostExpectedCompilerSha256 = "",
    [string]$GzipSelfhostOutputDirectory = "",
    [string]$AdditionalMoveOwnershipCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$AdditionalMoveOwnershipExpectedCompilerSha256 = "",
    [string]$AdditionalMoveOwnershipOutputDirectory = "",
    [string]$GenericTypeContextsCandidateCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$GenericTypeContextsExpectedCompilerSha256 = "",
    [string]$SelfhostDeferredTextStorageCandidateCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$SelfhostDeferredTextStorageExpectedCompilerSha256 = "",
    [string]$SelfhostC424NestedWholeOwnerCandidateCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$SelfhostC424NestedWholeOwnerExpectedCompilerSha256 = "",
    [string]$SelfhostC424NestedWholeOwnerOutputDirectory = "",
    [string]$LinuxOwnershipStorageCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$LinuxOwnershipStorageExpectedCompilerSha256 = "",
    [string]$C341FinalCandidateCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$C341FinalExpectedCompilerSha256 = "",
    [string]$C341FinalOutputDirectory = "",
    [string]$C341FinalGenerationRecord = "",
    [string]$C341FinalSeedCompiler = "",
    [string]$C394FinalCandidateCompiler = "",
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$C394FinalExpectedCompilerSha256 = "",
    [string]$C394FinalOutputDirectory = "",
    [switch]$ValidateInputsOnly,
    [ValidateSet("windows", "linux")]
    [string]$IncrementalTarget = "windows",
    [ValidateSet("O0", "O1")]
    [string]$IncrementalStage1Optimization = "O0",
    [ValidateSet("Pass", "Fail", "PlainFail", "Wait", "ChildPass", "ChildOrphan", "CooperativeWait", "CooperativeChild", "NonCooperativeWait")]
    [string]$ProbeOutcome = "Fail",
    [switch]$Supervisor
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scratchRoot = Join-Path $repositoryRoot "artifacts\scratch"
if ($Verification -eq "Stage3" -and $SeedMode -eq "Stage2Bridge") {
    throw "Stage3 does not accept SeedMode Stage2Bridge"
}
if (($BrowserCandidateCompiler -eq "") -ne ($BrowserFocusedFixture -eq "")) {
    throw "BrowserCandidateCompiler and BrowserFocusedFixture must be supplied together"
}
if ($Verification -ne "BrowserStage2" -and $BrowserCandidateCompiler -ne "") {
    throw "focused browser inputs require Verification BrowserStage2"
}
if (($Verification -eq "Incremental") -ne (-not [string]::IsNullOrWhiteSpace($IncrementalFixture))) {
    throw "IncrementalFixture is required only for Verification Incremental"
}
if ([string]::IsNullOrWhiteSpace($ManagedCompiler) -ne [string]::IsNullOrWhiteSpace($ExpectedManagedCompilerSha256)) {
    throw 'ManagedCompiler and ExpectedManagedCompilerSha256 must be supplied together'
}
if ($Verification -ne 'Incremental' -and -not [string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    throw 'ManagedCompiler is valid only for Verification Incremental'
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedManagedCompilerSha256) -and
    $ExpectedManagedCompilerSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'ExpectedManagedCompilerSha256 must contain exactly 64 hexadecimal characters'
}
if (($Verification -eq "ExpressionBatch") -ne (-not [string]::IsNullOrWhiteSpace($ExpressionBatchCompiler))) {
    throw "ExpressionBatchCompiler is required only for Verification ExpressionBatch"
}
if ($Verification -ne "ExpressionBatch" -and
    ($ExpressionBatchFixture.Count -gt 0 -or $ExpressionBatchManifest -ne "" -or
        $ExpressionBatchManifestSha256 -ne "" -or
        ($ValidateInputsOnly -and $Verification -notin @("PortableMemoryIo", "TypedBlockMutableBorrow", "BinaryChecksum", "GzipSelfhost", "AdditionalMoveOwnership", "GenericTypeContexts", "SelfhostDeferredTextStorage", "SelfhostC424NestedWholeOwner", "LinuxOwnershipStorage", "C341FinalSelfhost", "C394FinalCandidate")))) {
    throw "Expression batch selection and input validation require Verification ExpressionBatch"
}
$portableMemoryIoInputsPresent = -not [string]::IsNullOrWhiteSpace($PortableMemoryIoCompiler) -or
    -not [string]::IsNullOrWhiteSpace($PortableMemoryIoExpectedCompilerSha256) -or
    -not [string]::IsNullOrWhiteSpace($PortableMemoryIoOutputDirectory)
if (($Verification -eq "PortableMemoryIo") -ne $portableMemoryIoInputsPresent) {
    throw "PortableMemoryIo compiler, expected SHA-256, and output directory are required only for Verification PortableMemoryIo"
}
if ($Verification -eq "PortableMemoryIo" -and
    ([string]::IsNullOrWhiteSpace($PortableMemoryIoCompiler) -or
        [string]::IsNullOrWhiteSpace($PortableMemoryIoExpectedCompilerSha256) -or
        [string]::IsNullOrWhiteSpace($PortableMemoryIoOutputDirectory))) {
    throw "PortableMemoryIo requires compiler, expected SHA-256, and output directory together"
}
$typedBlockInputsPresent = -not [string]::IsNullOrWhiteSpace($TypedBlockMutableBorrowCompiler) -or
    -not [string]::IsNullOrWhiteSpace($TypedBlockMutableBorrowExpectedCompilerSha256) -or
    -not [string]::IsNullOrWhiteSpace($TypedBlockMutableBorrowOutputDirectory)
if (($Verification -eq "TypedBlockMutableBorrow") -ne $typedBlockInputsPresent) {
    throw "TypedBlockMutableBorrow compiler, expected SHA-256, and output directory are required only for Verification TypedBlockMutableBorrow"
}
if ($Verification -eq "TypedBlockMutableBorrow" -and
    ([string]::IsNullOrWhiteSpace($TypedBlockMutableBorrowCompiler) -or
        [string]::IsNullOrWhiteSpace($TypedBlockMutableBorrowExpectedCompilerSha256) -or
        [string]::IsNullOrWhiteSpace($TypedBlockMutableBorrowOutputDirectory))) {
    throw "TypedBlockMutableBorrow requires compiler, expected SHA-256, and output directory together"
}
$binaryChecksumInputsPresent = -not [string]::IsNullOrWhiteSpace($BinaryChecksumCompiler) -or
    -not [string]::IsNullOrWhiteSpace($BinaryChecksumExpectedCompilerSha256) -or
    -not [string]::IsNullOrWhiteSpace($BinaryChecksumOutputDirectory)
if (($Verification -eq "BinaryChecksum") -ne $binaryChecksumInputsPresent) {
    throw "BinaryChecksum compiler, expected SHA-256, and output directory are required only for Verification BinaryChecksum"
}
if ($Verification -eq "BinaryChecksum" -and
    ([string]::IsNullOrWhiteSpace($BinaryChecksumCompiler) -or
        [string]::IsNullOrWhiteSpace($BinaryChecksumExpectedCompilerSha256) -or
        [string]::IsNullOrWhiteSpace($BinaryChecksumOutputDirectory))) {
    throw "BinaryChecksum requires compiler, expected SHA-256, and output directory together"
}
$gzipSelfhostInputsPresent = -not [string]::IsNullOrWhiteSpace($GzipSelfhostCompiler) -or
    -not [string]::IsNullOrWhiteSpace($GzipSelfhostExpectedCompilerSha256) -or
    -not [string]::IsNullOrWhiteSpace($GzipSelfhostOutputDirectory)
if (($Verification -eq "GzipSelfhost") -ne $gzipSelfhostInputsPresent) {
    throw "GzipSelfhost compiler, expected SHA-256, and output directory are required only for Verification GzipSelfhost"
}
if ($Verification -eq "GzipSelfhost" -and
    ([string]::IsNullOrWhiteSpace($GzipSelfhostCompiler) -or
        [string]::IsNullOrWhiteSpace($GzipSelfhostExpectedCompilerSha256) -or
        [string]::IsNullOrWhiteSpace($GzipSelfhostOutputDirectory))) {
    throw "GzipSelfhost requires compiler, expected SHA-256, and output directory together"
}
$additionalMoveOwnershipInputsPresent = -not [string]::IsNullOrWhiteSpace($AdditionalMoveOwnershipCompiler) -or
    -not [string]::IsNullOrWhiteSpace($AdditionalMoveOwnershipExpectedCompilerSha256) -or
    -not [string]::IsNullOrWhiteSpace($AdditionalMoveOwnershipOutputDirectory)
if (($Verification -eq "AdditionalMoveOwnership") -ne $additionalMoveOwnershipInputsPresent) {
    throw "AdditionalMoveOwnership compiler, expected SHA-256, and output directory are required only for Verification AdditionalMoveOwnership"
}
if ($Verification -eq "AdditionalMoveOwnership" -and
    ([string]::IsNullOrWhiteSpace($AdditionalMoveOwnershipCompiler) -or
        [string]::IsNullOrWhiteSpace($AdditionalMoveOwnershipExpectedCompilerSha256) -or
        [string]::IsNullOrWhiteSpace($AdditionalMoveOwnershipOutputDirectory))) {
    throw "AdditionalMoveOwnership requires compiler, expected SHA-256, and output directory together"
}
$genericTypeContextsInputsPresent = -not [string]::IsNullOrWhiteSpace($GenericTypeContextsCandidateCompiler) -or
    -not [string]::IsNullOrWhiteSpace($GenericTypeContextsExpectedCompilerSha256)
if (($Verification -eq "GenericTypeContexts") -ne $genericTypeContextsInputsPresent) {
    throw "GenericTypeContexts candidate compiler and expected SHA-256 are required only for Verification GenericTypeContexts"
}
if ($Verification -eq "GenericTypeContexts" -and
    ([string]::IsNullOrWhiteSpace($GenericTypeContextsCandidateCompiler) -or
        [string]::IsNullOrWhiteSpace($GenericTypeContextsExpectedCompilerSha256))) {
    throw "GenericTypeContexts requires candidate compiler and expected SHA-256 together"
}
$deferredStorageInputsPresent = -not [string]::IsNullOrWhiteSpace($SelfhostDeferredTextStorageCandidateCompiler) -or
    -not [string]::IsNullOrWhiteSpace($SelfhostDeferredTextStorageExpectedCompilerSha256)
if (($Verification -eq "SelfhostDeferredTextStorage") -ne $deferredStorageInputsPresent) {
    throw "SelfhostDeferredTextStorage candidate compiler and expected SHA-256 are required only for Verification SelfhostDeferredTextStorage"
}
if ($Verification -eq "SelfhostDeferredTextStorage" -and
    ([string]::IsNullOrWhiteSpace($SelfhostDeferredTextStorageCandidateCompiler) -or
        [string]::IsNullOrWhiteSpace($SelfhostDeferredTextStorageExpectedCompilerSha256))) {
    throw "SelfhostDeferredTextStorage requires candidate compiler and expected SHA-256 together"
}
$c424InputsPresent = -not [string]::IsNullOrWhiteSpace($SelfhostC424NestedWholeOwnerCandidateCompiler) -or
    -not [string]::IsNullOrWhiteSpace($SelfhostC424NestedWholeOwnerExpectedCompilerSha256) -or
    -not [string]::IsNullOrWhiteSpace($SelfhostC424NestedWholeOwnerOutputDirectory)
if (($Verification -eq "SelfhostC424NestedWholeOwner") -ne $c424InputsPresent) {
    throw "SelfhostC424NestedWholeOwner candidate compiler, expected SHA-256, and output directory are required only for Verification SelfhostC424NestedWholeOwner"
}
if ($Verification -eq "SelfhostC424NestedWholeOwner" -and
    ([string]::IsNullOrWhiteSpace($SelfhostC424NestedWholeOwnerCandidateCompiler) -or
        [string]::IsNullOrWhiteSpace($SelfhostC424NestedWholeOwnerExpectedCompilerSha256) -or
        [string]::IsNullOrWhiteSpace($SelfhostC424NestedWholeOwnerOutputDirectory))) {
    throw "SelfhostC424NestedWholeOwner requires candidate compiler, expected SHA-256, and output directory together"
}
$linuxOwnershipInputsPresent = -not [string]::IsNullOrWhiteSpace($LinuxOwnershipStorageCompiler) -or
    -not [string]::IsNullOrWhiteSpace($LinuxOwnershipStorageExpectedCompilerSha256)
if (($Verification -eq "LinuxOwnershipStorage") -ne $linuxOwnershipInputsPresent) {
    throw "LinuxOwnershipStorage compiler and expected SHA-256 are required only for Verification LinuxOwnershipStorage"
}
if ($Verification -eq "LinuxOwnershipStorage" -and
    ([string]::IsNullOrWhiteSpace($LinuxOwnershipStorageCompiler) -or
        [string]::IsNullOrWhiteSpace($LinuxOwnershipStorageExpectedCompilerSha256))) {
    throw "LinuxOwnershipStorage requires compiler and expected SHA-256 together"
}
$c341FinalInputs = @($C341FinalCandidateCompiler, $C341FinalExpectedCompilerSha256, $C341FinalOutputDirectory, $C341FinalGenerationRecord, $C341FinalSeedCompiler)
$c341FinalInputsPresent = @($c341FinalInputs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
if (($Verification -eq 'C341FinalSelfhost') -ne $c341FinalInputsPresent -or
    ($Verification -eq 'C341FinalSelfhost' -and @($c341FinalInputs | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0)) {
    throw 'C341FinalSelfhost requires candidate, expected SHA-256, output directory, generation record, and seed compiler together and only in that mode'
}
$c394FinalInputs = @($C394FinalCandidateCompiler, $C394FinalExpectedCompilerSha256, $C394FinalOutputDirectory)
$c394FinalInputsPresent = @($c394FinalInputs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
if (($Verification -eq 'C394FinalCandidate') -ne $c394FinalInputsPresent -or
    ($Verification -eq 'C394FinalCandidate' -and @($c394FinalInputs | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0)) {
    throw 'C394FinalCandidate requires candidate, expected SHA-256, and output directory together and only in that mode'
}
$selectedFixtures = @()
if ($Verification -eq "ExpressionBatch") {
    . (Join-Path $PSScriptRoot 'expression-batch-selection.ps1')
    $defaults = @( (Get-Content (Join-Path $PSScriptRoot 'contracts/expression-lowering-parity.json') -Raw | ConvertFrom-Json).representativeFixtures )
    $selectedFixtures = @(Get-ExpressionBatchFixtureSelection -Fixture $ExpressionBatchFixture `
        -ManifestPath $ExpressionBatchManifest -ManifestSha256 $ExpressionBatchManifestSha256 `
        -DefaultFixture $defaults)
    if ($selectedFixtures.Count -eq 0) { throw 'Expression batch fixture selection is empty' }
}
if ($Verification -eq "Incremental") {
    $incrementalFixturePath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $IncrementalFixture))
    if (-not $incrementalFixturePath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "IncrementalFixture must be under $repositoryRoot"
    }
    if (-not (Test-Path -LiteralPath $incrementalFixturePath -PathType Leaf)) {
        throw "IncrementalFixture does not exist: $incrementalFixturePath"
    }
    $IncrementalFixture = [IO.Path]::GetRelativePath($repositoryRoot, $incrementalFixturePath)
    if (-not [string]::IsNullOrWhiteSpace($ManagedCompiler)) {
        $managedCompilerPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $ManagedCompiler))
        if (-not $managedCompilerPath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "ManagedCompiler must be under $repositoryRoot"
        }
        if (-not (Test-Path -LiteralPath $managedCompilerPath -PathType Leaf)) {
            throw "ManagedCompiler does not exist: $managedCompilerPath"
        }
        $actualManagedCompilerHash = (Get-FileHash -LiteralPath $managedCompilerPath -Algorithm SHA256).Hash
        if ($actualManagedCompilerHash -cne $ExpectedManagedCompilerSha256.ToUpperInvariant()) {
            throw "ManagedCompiler hash mismatch: expected=$($ExpectedManagedCompilerSha256.ToUpperInvariant()) actual=$actualManagedCompilerHash"
        }
        $ManagedCompiler = [IO.Path]::GetRelativePath($repositoryRoot, $managedCompilerPath)
        $ExpectedManagedCompilerSha256 = $actualManagedCompilerHash
    }
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory)][string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Assert-ArtifactPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $fullPath = [IO.Path]::GetFullPath($Path)
    $artifactRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts"))
    if (-not $fullPath.StartsWith($artifactRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name must be under $artifactRoot"
    }
    return $fullPath
}

function Write-JsonAtomically {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    $temporaryPath = "$Path.tmp-$PID"
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporaryPath -Encoding utf8
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}

. (Join-Path $PSScriptRoot 'detached-gzip-selfhost-result.ps1')

if ($Verification -eq "PortableMemoryIo") {
    $PortableMemoryIoCompiler = Assert-ArtifactPath -Path $PortableMemoryIoCompiler -Name "PortableMemoryIoCompiler"
    $PortableMemoryIoOutputDirectory = Assert-ArtifactPath -Path $PortableMemoryIoOutputDirectory -Name "PortableMemoryIoOutputDirectory"
    if (-not (Test-Path -LiteralPath $PortableMemoryIoCompiler -PathType Leaf)) {
        throw "PortableMemoryIo compiler does not exist"
    }
    $PortableMemoryIoExpectedCompilerSha256 = $PortableMemoryIoExpectedCompilerSha256.ToUpperInvariant()
    $portableCompilerSha256 = (Get-FileHash -LiteralPath $PortableMemoryIoCompiler -Algorithm SHA256).Hash
    if ($portableCompilerSha256 -cne $PortableMemoryIoExpectedCompilerSha256) {
        throw "PortableMemoryIo compiler hash mismatch: expected=$PortableMemoryIoExpectedCompilerSha256 actual=$portableCompilerSha256"
    }
    if ($ValidateInputsOnly) {
        [ordered]@{
            verification = "PortableMemoryIo"
            compiler = $PortableMemoryIoCompiler
            compilerSha256 = $portableCompilerSha256
            outputDirectory = $PortableMemoryIoOutputDirectory
            validated = $true
        } | ConvertTo-Json -Compress
        return
    }
}

if ($Verification -eq "TypedBlockMutableBorrow") {
    $TypedBlockMutableBorrowCompiler = Assert-ArtifactPath -Path $TypedBlockMutableBorrowCompiler -Name "TypedBlockMutableBorrowCompiler"
    $TypedBlockMutableBorrowOutputDirectory = Assert-ArtifactPath -Path $TypedBlockMutableBorrowOutputDirectory -Name "TypedBlockMutableBorrowOutputDirectory"
    if (-not (Test-Path -LiteralPath $TypedBlockMutableBorrowCompiler -PathType Leaf)) {
        throw "TypedBlockMutableBorrow compiler does not exist"
    }
    $TypedBlockMutableBorrowExpectedCompilerSha256 = $TypedBlockMutableBorrowExpectedCompilerSha256.ToUpperInvariant()
    $typedBlockCompilerSha256 = (Get-FileHash -LiteralPath $TypedBlockMutableBorrowCompiler -Algorithm SHA256).Hash
    if ($typedBlockCompilerSha256 -cne $TypedBlockMutableBorrowExpectedCompilerSha256) {
        throw "TypedBlockMutableBorrow compiler hash mismatch: expected=$TypedBlockMutableBorrowExpectedCompilerSha256 actual=$typedBlockCompilerSha256"
    }
    if ($ValidateInputsOnly) {
        [ordered]@{
            verification = "TypedBlockMutableBorrow"
            compiler = $TypedBlockMutableBorrowCompiler
            compilerSha256 = $typedBlockCompilerSha256
            outputDirectory = $TypedBlockMutableBorrowOutputDirectory
            validated = $true
        } | ConvertTo-Json -Compress
        return
    }
}

if ($Verification -eq "BinaryChecksum") {
    $binaryCompilerInput = if ([IO.Path]::IsPathRooted($BinaryChecksumCompiler)) {
        $BinaryChecksumCompiler
    } else {
        Join-Path $repositoryRoot $BinaryChecksumCompiler
    }
    $binaryCompilerPath = [IO.Path]::GetFullPath($binaryCompilerInput)
    if (-not $binaryCompilerPath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "BinaryChecksumCompiler must be under $repositoryRoot"
    }
    $BinaryChecksumCompiler = $binaryCompilerPath
    $BinaryChecksumExpectedCompilerSha256 = $BinaryChecksumExpectedCompilerSha256.ToUpperInvariant()
    $BinaryChecksumOutputDirectory = Assert-ArtifactPath -Path $BinaryChecksumOutputDirectory -Name "BinaryChecksumOutputDirectory"
    $scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $BinaryChecksumOutputDirectory.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "BinaryChecksumOutputDirectory must be under $scratchRoot"
    }
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $BinaryChecksumCompiler -PathType Leaf)) {
            throw "BinaryChecksum compiler does not exist: $BinaryChecksumCompiler"
        }
        $binaryCompilerSha256 = (Get-FileHash -LiteralPath $BinaryChecksumCompiler -Algorithm SHA256).Hash
        if ($binaryCompilerSha256 -cne $BinaryChecksumExpectedCompilerSha256) {
            throw "BinaryChecksum compiler hash mismatch: expected=$BinaryChecksumExpectedCompilerSha256 actual=$binaryCompilerSha256"
        }
        if (Test-Path -LiteralPath $BinaryChecksumOutputDirectory) {
            if (-not (Test-Path -LiteralPath $BinaryChecksumOutputDirectory -PathType Container) -or
                @(Get-ChildItem -LiteralPath $BinaryChecksumOutputDirectory -Force).Count -ne 0) {
                throw "BinaryChecksumOutputDirectory must be a new or empty directory"
            }
        }
        if ($ValidateInputsOnly) {
            [ordered]@{
                verification = "BinaryChecksum"
                compiler = $BinaryChecksumCompiler
                compilerSha256 = $binaryCompilerSha256
                outputDirectory = $BinaryChecksumOutputDirectory
                wslDistribution = $Distribution
                validated = $true
            } | ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq "GzipSelfhost") {
    $gzipCompilerInput = if ([IO.Path]::IsPathRooted($GzipSelfhostCompiler)) {
        $GzipSelfhostCompiler
    } else {
        Join-Path $repositoryRoot $GzipSelfhostCompiler
    }
    $gzipCompilerPath = [IO.Path]::GetFullPath($gzipCompilerInput)
    if (-not $gzipCompilerPath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "GzipSelfhostCompiler must be under $repositoryRoot"
    }
    $GzipSelfhostCompiler = $gzipCompilerPath
    $GzipSelfhostExpectedCompilerSha256 = $GzipSelfhostExpectedCompilerSha256.ToUpperInvariant()
    $GzipSelfhostOutputDirectory = Assert-ArtifactPath -Path $GzipSelfhostOutputDirectory -Name "GzipSelfhostOutputDirectory"
    $scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $GzipSelfhostOutputDirectory.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "GzipSelfhostOutputDirectory must be under $scratchRoot"
    }
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $GzipSelfhostCompiler -PathType Leaf)) {
            throw "GzipSelfhost compiler does not exist: $GzipSelfhostCompiler"
        }
        $gzipCompilerSha256 = (Get-FileHash -LiteralPath $GzipSelfhostCompiler -Algorithm SHA256).Hash
        if ($gzipCompilerSha256 -cne $GzipSelfhostExpectedCompilerSha256) {
            throw "GzipSelfhost compiler hash mismatch: expected=$GzipSelfhostExpectedCompilerSha256 actual=$gzipCompilerSha256"
        }
        if (Test-Path -LiteralPath $GzipSelfhostOutputDirectory) {
            if (-not (Test-Path -LiteralPath $GzipSelfhostOutputDirectory -PathType Container) -or
                @(Get-ChildItem -LiteralPath $GzipSelfhostOutputDirectory -Force).Count -ne 0) {
                throw "GzipSelfhostOutputDirectory must be a new or empty directory"
            }
        }
        if ($ValidateInputsOnly) {
            [ordered]@{
                verification = "GzipSelfhost"
                compiler = $GzipSelfhostCompiler
                compilerSha256 = $gzipCompilerSha256
                outputDirectory = $GzipSelfhostOutputDirectory
                validated = $true
            } | ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq "AdditionalMoveOwnership") {
    $additionalMoveCompilerInput = if ([IO.Path]::IsPathRooted($AdditionalMoveOwnershipCompiler)) {
        $AdditionalMoveOwnershipCompiler
    } else {
        Join-Path $repositoryRoot $AdditionalMoveOwnershipCompiler
    }
    $additionalMoveCompilerPath = [IO.Path]::GetFullPath($additionalMoveCompilerInput)
    if (-not $additionalMoveCompilerPath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "AdditionalMoveOwnershipCompiler must be under $repositoryRoot"
    }
    $AdditionalMoveOwnershipCompiler = $additionalMoveCompilerPath
    $AdditionalMoveOwnershipExpectedCompilerSha256 = $AdditionalMoveOwnershipExpectedCompilerSha256.ToUpperInvariant()
    $AdditionalMoveOwnershipOutputDirectory = Assert-ArtifactPath -Path $AdditionalMoveOwnershipOutputDirectory -Name "AdditionalMoveOwnershipOutputDirectory"
    $scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $AdditionalMoveOwnershipOutputDirectory.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "AdditionalMoveOwnershipOutputDirectory must be under $scratchRoot"
    }
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $AdditionalMoveOwnershipCompiler -PathType Leaf)) {
            throw "AdditionalMoveOwnership compiler does not exist: $AdditionalMoveOwnershipCompiler"
        }
        $additionalMoveCompilerSha256 = (Get-FileHash -LiteralPath $AdditionalMoveOwnershipCompiler -Algorithm SHA256).Hash
        if ($additionalMoveCompilerSha256 -cne $AdditionalMoveOwnershipExpectedCompilerSha256) {
            throw "AdditionalMoveOwnership compiler hash mismatch: expected=$AdditionalMoveOwnershipExpectedCompilerSha256 actual=$additionalMoveCompilerSha256"
        }
        if (Test-Path -LiteralPath $AdditionalMoveOwnershipOutputDirectory) {
            if (-not (Test-Path -LiteralPath $AdditionalMoveOwnershipOutputDirectory -PathType Container) -or
                @(Get-ChildItem -LiteralPath $AdditionalMoveOwnershipOutputDirectory -Force).Count -ne 0) {
                throw "AdditionalMoveOwnershipOutputDirectory must be a new or empty directory"
            }
        }
        if ($ValidateInputsOnly) {
            [ordered]@{
                verification = "AdditionalMoveOwnership"
                compiler = $AdditionalMoveOwnershipCompiler
                compilerSha256 = $additionalMoveCompilerSha256
                outputDirectory = $AdditionalMoveOwnershipOutputDirectory
                validated = $true
            } | ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq 'C341FinalSelfhost') {
    foreach ($entry in @(
        @{ Name='C341FinalCandidateCompiler'; Value=$C341FinalCandidateCompiler },
        @{ Name='C341FinalGenerationRecord'; Value=$C341FinalGenerationRecord },
        @{ Name='C341FinalSeedCompiler'; Value=$C341FinalSeedCompiler })) {
        $inputPath = if ([IO.Path]::IsPathRooted($entry.Value)) { $entry.Value } else { Join-Path $repositoryRoot $entry.Value }
        $full = [IO.Path]::GetFullPath($inputPath)
        if (-not $full.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "$($entry.Name) must be under $repositoryRoot" }
        Set-Variable -Name $entry.Name -Value $full
    }
    $C341FinalOutputDirectory = Assert-ArtifactPath -Path $C341FinalOutputDirectory -Name 'C341FinalOutputDirectory'
    if (-not $C341FinalOutputDirectory.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C341FinalOutputDirectory must be under the scratch root' }
    $C341FinalExpectedCompilerSha256 = $C341FinalExpectedCompilerSha256.ToUpperInvariant()
    if (-not $Supervisor) {
        foreach ($path in @($C341FinalCandidateCompiler,$C341FinalGenerationRecord,$C341FinalSeedCompiler)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C341FinalSelfhost input does not exist: $path" } }
        $c341FinalCompilerSha256 = (Get-FileHash $C341FinalCandidateCompiler -Algorithm SHA256).Hash
        $c341FinalGenerationSha256 = (Get-FileHash $C341FinalGenerationRecord -Algorithm SHA256).Hash
        $c341FinalSeedSha256 = (Get-FileHash $C341FinalSeedCompiler -Algorithm SHA256).Hash
        if ($c341FinalCompilerSha256 -cne $C341FinalExpectedCompilerSha256) { throw "C341FinalSelfhost compiler hash mismatch: expected=$C341FinalExpectedCompilerSha256 actual=$c341FinalCompilerSha256" }
        if ((Test-Path -LiteralPath $C341FinalOutputDirectory) -and (@(Get-ChildItem -LiteralPath $C341FinalOutputDirectory -Force).Count -ne 0)) { throw 'C341FinalOutputDirectory must be new or empty' }
        if ($ValidateInputsOnly) {
            & (Join-Path $PSScriptRoot 'verify-c341-final-selfhost-candidate.ps1') -CandidateCompiler $C341FinalCandidateCompiler -ExpectedCandidateSha256 $C341FinalExpectedCompilerSha256 -OutputDirectory $C341FinalOutputDirectory -ValidateInputsOnly
            [ordered]@{verification='C341FinalSelfhost';compiler=$C341FinalCandidateCompiler;compilerSha256=$c341FinalCompilerSha256;generationRecord=$C341FinalGenerationRecord;generationRecordSha256=$c341FinalGenerationSha256;seedCompiler=$C341FinalSeedCompiler;seedCompilerSha256=$c341FinalSeedSha256;outputDirectory=$C341FinalOutputDirectory;resultPath=(Join-Path $C341FinalOutputDirectory 'result.json');validated=$true}|ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq 'C394FinalCandidate') {
    $c394InputPath = if ([IO.Path]::IsPathRooted($C394FinalCandidateCompiler)) { $C394FinalCandidateCompiler } else { Join-Path $repositoryRoot $C394FinalCandidateCompiler }
    $C394FinalCandidateCompiler = [IO.Path]::GetFullPath($c394InputPath)
    if (-not $C394FinalCandidateCompiler.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "C394FinalCandidateCompiler must be under $repositoryRoot" }
    $C394FinalOutputDirectory = Assert-ArtifactPath -Path $C394FinalOutputDirectory -Name 'C394FinalOutputDirectory'
    if (-not $C394FinalOutputDirectory.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C394FinalOutputDirectory must be under the scratch root' }
    $C394FinalExpectedCompilerSha256 = $C394FinalExpectedCompilerSha256.ToUpperInvariant()
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $C394FinalCandidateCompiler -PathType Leaf)) { throw "C394FinalCandidate compiler does not exist: $C394FinalCandidateCompiler" }
        $c394FinalCompilerSha256 = (Get-FileHash $C394FinalCandidateCompiler -Algorithm SHA256).Hash
        if ($c394FinalCompilerSha256 -cne $C394FinalExpectedCompilerSha256) { throw "C394FinalCandidate compiler hash mismatch: expected=$C394FinalExpectedCompilerSha256 actual=$c394FinalCompilerSha256" }
        if ((Test-Path -LiteralPath $C394FinalOutputDirectory) -and (@(Get-ChildItem -LiteralPath $C394FinalOutputDirectory -Force).Count -ne 0)) { throw 'C394FinalOutputDirectory must be new or empty' }
        if ($ValidateInputsOnly) {
            & (Join-Path $PSScriptRoot 'verify-c394-final-candidate.ps1') -CandidateCompiler $C394FinalCandidateCompiler -ExpectedCandidateSha256 $C394FinalExpectedCompilerSha256 -OutputDirectory $C394FinalOutputDirectory -ValidateInputsOnly
            [ordered]@{verification='C394FinalCandidate';compiler=$C394FinalCandidateCompiler;compilerSha256=$c394FinalCompilerSha256;outputDirectory=$C394FinalOutputDirectory;resultPath=(Join-Path $C394FinalOutputDirectory 'result.json');validated=$true}|ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq "GenericTypeContexts") {
    $genericCandidateInput = if ([IO.Path]::IsPathRooted($GenericTypeContextsCandidateCompiler)) {
        $GenericTypeContextsCandidateCompiler
    } else {
        Join-Path $repositoryRoot $GenericTypeContextsCandidateCompiler
    }
    $genericCandidatePath = [IO.Path]::GetFullPath($genericCandidateInput)
    if (-not $genericCandidatePath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "GenericTypeContextsCandidateCompiler must be under $repositoryRoot"
    }
    $GenericTypeContextsCandidateCompiler = $genericCandidatePath
    $GenericTypeContextsExpectedCompilerSha256 = $GenericTypeContextsExpectedCompilerSha256.ToUpperInvariant()
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $GenericTypeContextsCandidateCompiler -PathType Leaf)) {
            throw "GenericTypeContexts candidate compiler does not exist: $GenericTypeContextsCandidateCompiler"
        }
        $genericCandidateSha256 = (Get-FileHash -LiteralPath $GenericTypeContextsCandidateCompiler -Algorithm SHA256).Hash
        if ($genericCandidateSha256 -cne $GenericTypeContextsExpectedCompilerSha256) {
            throw "GenericTypeContexts candidate compiler hash mismatch: expected=$GenericTypeContextsExpectedCompilerSha256 actual=$genericCandidateSha256"
        }
        if ($ValidateInputsOnly) {
            [ordered]@{
                verification = "GenericTypeContexts"
                candidateCompiler = $GenericTypeContextsCandidateCompiler
                compilerSha256 = $genericCandidateSha256
                fixedFlags = @("TypeDelimiters", "ReadonlyTextSlice", "ExecuteFixtures")
                validated = $true
            } | ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq "SelfhostDeferredTextStorage") {
    $deferredCandidateInput = if ([IO.Path]::IsPathRooted($SelfhostDeferredTextStorageCandidateCompiler)) {
        $SelfhostDeferredTextStorageCandidateCompiler
    } else { Join-Path $repositoryRoot $SelfhostDeferredTextStorageCandidateCompiler }
    $SelfhostDeferredTextStorageCandidateCompiler = [IO.Path]::GetFullPath($deferredCandidateInput)
    if (-not $SelfhostDeferredTextStorageCandidateCompiler.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "SelfhostDeferredTextStorageCandidateCompiler must be under $repositoryRoot"
    }
    $SelfhostDeferredTextStorageExpectedCompilerSha256 = $SelfhostDeferredTextStorageExpectedCompilerSha256.ToUpperInvariant()
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $SelfhostDeferredTextStorageCandidateCompiler -PathType Leaf)) {
            throw "SelfhostDeferredTextStorage candidate compiler does not exist: $SelfhostDeferredTextStorageCandidateCompiler"
        }
        $deferredCandidateSha256 = (Get-FileHash -LiteralPath $SelfhostDeferredTextStorageCandidateCompiler -Algorithm SHA256).Hash
        if ($deferredCandidateSha256 -cne $SelfhostDeferredTextStorageExpectedCompilerSha256) {
            throw "SelfhostDeferredTextStorage candidate compiler hash mismatch: expected=$SelfhostDeferredTextStorageExpectedCompilerSha256 actual=$deferredCandidateSha256"
        }
        if ($ValidateInputsOnly) {
            [ordered]@{ verification = "SelfhostDeferredTextStorage"; candidateCompiler = $SelfhostDeferredTextStorageCandidateCompiler
                compilerSha256 = $deferredCandidateSha256; requireCandidateGate = $true; validated = $true } |
                ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq "SelfhostC424NestedWholeOwner") {
    $c424CandidateInput = if ([IO.Path]::IsPathRooted($SelfhostC424NestedWholeOwnerCandidateCompiler)) {
        $SelfhostC424NestedWholeOwnerCandidateCompiler
    } else { Join-Path $repositoryRoot $SelfhostC424NestedWholeOwnerCandidateCompiler }
    $SelfhostC424NestedWholeOwnerCandidateCompiler = [IO.Path]::GetFullPath($c424CandidateInput)
    if (-not $SelfhostC424NestedWholeOwnerCandidateCompiler.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "SelfhostC424NestedWholeOwnerCandidateCompiler must be under $repositoryRoot"
    }
    $SelfhostC424NestedWholeOwnerExpectedCompilerSha256 = $SelfhostC424NestedWholeOwnerExpectedCompilerSha256.ToUpperInvariant()
    $SelfhostC424NestedWholeOwnerOutputDirectory = Assert-ArtifactPath -Path $SelfhostC424NestedWholeOwnerOutputDirectory -Name "SelfhostC424NestedWholeOwnerOutputDirectory"
    $c424ScratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $SelfhostC424NestedWholeOwnerOutputDirectory.StartsWith($c424ScratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "SelfhostC424NestedWholeOwnerOutputDirectory must be under $scratchRoot"
    }
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $SelfhostC424NestedWholeOwnerCandidateCompiler -PathType Leaf)) {
            throw "SelfhostC424NestedWholeOwner candidate compiler does not exist: $SelfhostC424NestedWholeOwnerCandidateCompiler"
        }
        $c424CandidateSha256 = (Get-FileHash -LiteralPath $SelfhostC424NestedWholeOwnerCandidateCompiler -Algorithm SHA256).Hash
        if ($c424CandidateSha256 -cne $SelfhostC424NestedWholeOwnerExpectedCompilerSha256) {
            throw "SelfhostC424NestedWholeOwner candidate compiler hash mismatch: expected=$SelfhostC424NestedWholeOwnerExpectedCompilerSha256 actual=$c424CandidateSha256"
        }
        if (Test-Path -LiteralPath $SelfhostC424NestedWholeOwnerOutputDirectory) {
            if (-not (Test-Path -LiteralPath $SelfhostC424NestedWholeOwnerOutputDirectory -PathType Container) -or
                @(Get-ChildItem -LiteralPath $SelfhostC424NestedWholeOwnerOutputDirectory -Force).Count -ne 0) {
                throw "SelfhostC424NestedWholeOwnerOutputDirectory must be a new or empty directory"
            }
        }
        if ($ValidateInputsOnly) {
            [ordered]@{ verification = "SelfhostC424NestedWholeOwner"; candidateCompiler = $SelfhostC424NestedWholeOwnerCandidateCompiler
                compilerSha256 = $c424CandidateSha256; outputDirectory = $SelfhostC424NestedWholeOwnerOutputDirectory; validated = $true } |
                ConvertTo-Json -Compress
            return
        }
    }
}

if ($Verification -eq "LinuxOwnershipStorage") {
    $linuxCompilerInput = if ([IO.Path]::IsPathRooted($LinuxOwnershipStorageCompiler)) {
        $LinuxOwnershipStorageCompiler
    } else { Join-Path $repositoryRoot $LinuxOwnershipStorageCompiler }
    $LinuxOwnershipStorageCompiler = [IO.Path]::GetFullPath($linuxCompilerInput)
    $canonicalLinuxCompiler = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'))
    if (-not [string]::Equals($LinuxOwnershipStorageCompiler, $canonicalLinuxCompiler, [StringComparison]::OrdinalIgnoreCase)) {
        throw "LinuxOwnershipStorageCompiler must equal the verifier's canonical compiler path: $canonicalLinuxCompiler"
    }
    $LinuxOwnershipStorageExpectedCompilerSha256 = $LinuxOwnershipStorageExpectedCompilerSha256.ToUpperInvariant()
    if (-not $Supervisor) {
        if (-not (Test-Path -LiteralPath $LinuxOwnershipStorageCompiler -PathType Leaf)) {
            throw "LinuxOwnershipStorage compiler does not exist: $LinuxOwnershipStorageCompiler"
        }
        $linuxCompilerSha256 = (Get-FileHash -LiteralPath $LinuxOwnershipStorageCompiler -Algorithm SHA256).Hash
        if ($linuxCompilerSha256 -cne $LinuxOwnershipStorageExpectedCompilerSha256) {
            throw "LinuxOwnershipStorage compiler hash mismatch: expected=$LinuxOwnershipStorageExpectedCompilerSha256 actual=$linuxCompilerSha256"
        }
        if ($ValidateInputsOnly) {
            [ordered]@{ verification = "LinuxOwnershipStorage"; compiler = $LinuxOwnershipStorageCompiler
                compilerSha256 = $linuxCompilerSha256; target = "linux-x64"; validated = $true } |
                ConvertTo-Json -Compress
            return
        }
    }
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
}
if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $scratchRoot "$($Verification.ToLowerInvariant())-$RunId.log"
}
if ([string]::IsNullOrWhiteSpace($CompletionRecordPath)) {
    $CompletionRecordPath = Join-Path $scratchRoot "$($Verification.ToLowerInvariant())-$RunId.result.json"
}
if ([string]::IsNullOrWhiteSpace($CancellationRequestPath)) {
    $CancellationRequestPath = "$CompletionRecordPath.cancel.json"
}
$CancellationAcknowledgementPath = "$CancellationRequestPath.ack.json"

$LogPath = Assert-ArtifactPath -Path $LogPath -Name "LogPath"
$CompletionRecordPath = Assert-ArtifactPath -Path $CompletionRecordPath -Name "CompletionRecordPath"
$CancellationRequestPath = Assert-ArtifactPath -Path $CancellationRequestPath -Name "CancellationRequestPath"
$distinctPaths = @($LogPath, $CompletionRecordPath, $CancellationRequestPath, $CancellationAcknowledgementPath) |
    ForEach-Object { $_.ToLowerInvariant() } |
    Select-Object -Unique
if (@($distinctPaths).Count -ne 4) {
    throw "LogPath, CompletionRecordPath, CancellationRequestPath, and CancellationAcknowledgementPath must be distinct"
}

New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($LogPath)) -Force | Out-Null
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($CompletionRecordPath)) -Force | Out-Null

if (-not $Supervisor) {
    if ((Test-Path -LiteralPath $LogPath) -or
        (Test-Path -LiteralPath $CompletionRecordPath) -or
        (Test-Path -LiteralPath $CancellationRequestPath) -or
        (Test-Path -LiteralPath $CancellationAcknowledgementPath)) {
        throw "The selected run paths already exist; choose a new RunId"
    }

    New-Item -ItemType File -Path $LogPath -Force | Out-Null
    $powerShellPath = (Get-Process -Id $PID).Path
    $argumentList = @(
        "-NoProfile",
        "-File", (ConvertTo-ProcessArgument $PSCommandPath),
        "-Supervisor",
        "-Verification", $Verification,
        "-SeedMode", $SeedMode,
        "-Jobs", $Jobs.ToString(),
        "-Distribution", (ConvertTo-ProcessArgument $Distribution),
        "-RunId", $RunId,
        "-LogPath", (ConvertTo-ProcessArgument $LogPath),
        "-CompletionRecordPath", (ConvertTo-ProcessArgument $CompletionRecordPath),
        "-CancellationRequestPath", (ConvertTo-ProcessArgument $CancellationRequestPath),
        "-CancellationTimeoutSeconds", $CancellationTimeoutSeconds.ToString(),
        "-ProbeOutcome", $ProbeOutcome,
        "-IncrementalStage1Optimization", $IncrementalStage1Optimization
    )
    if ($BrowserCandidateCompiler -ne "") {
        $argumentList += @(
            "-BrowserCandidateCompiler", (ConvertTo-ProcessArgument $BrowserCandidateCompiler),
            "-BrowserFocusedFixture", (ConvertTo-ProcessArgument $BrowserFocusedFixture)
        )
    }
    if ($IncrementalFixture -ne "") {
        $argumentList += @(
            "-IncrementalFixture", (ConvertTo-ProcessArgument $IncrementalFixture),
            "-IncrementalTarget", $IncrementalTarget
        )
    }
    if ($ManagedCompiler -ne "") {
        $argumentList += @(
            "-ManagedCompiler", (ConvertTo-ProcessArgument $ManagedCompiler),
            "-ExpectedManagedCompilerSha256", $ExpectedManagedCompilerSha256
        )
    }
    if ($ExpressionBatchCompiler -ne "") {
        $selectionPath = "$CompletionRecordPath.fixtures.json"
        if (Test-Path -LiteralPath $selectionPath) { throw "Fixture selection snapshot already exists: $selectionPath" }
        Write-JsonAtomically -Path $selectionPath -Value ([ordered]@{ schemaVersion = 1; fixtures = $selectedFixtures })
        $selectionHash = (Get-FileHash -LiteralPath $selectionPath -Algorithm SHA256).Hash
        $argumentList += @(
            "-ExpressionBatchCompiler", (ConvertTo-ProcessArgument $ExpressionBatchCompiler),
            "-ExpressionBatchManifest", (ConvertTo-ProcessArgument $selectionPath),
            "-ExpressionBatchManifestSha256", $selectionHash
        )
        if ($ValidateInputsOnly) { $argumentList += '-ValidateInputsOnly' }
    }
    if ($PortableMemoryIoCompiler -ne "") {
        $argumentList += @(
            "-PortableMemoryIoCompiler", (ConvertTo-ProcessArgument $PortableMemoryIoCompiler),
            "-PortableMemoryIoExpectedCompilerSha256", $PortableMemoryIoExpectedCompilerSha256,
            "-PortableMemoryIoOutputDirectory", (ConvertTo-ProcessArgument $PortableMemoryIoOutputDirectory)
        )
    }
    if ($TypedBlockMutableBorrowCompiler -ne "") {
        $argumentList += @(
            "-TypedBlockMutableBorrowCompiler", (ConvertTo-ProcessArgument $TypedBlockMutableBorrowCompiler),
            "-TypedBlockMutableBorrowExpectedCompilerSha256", $TypedBlockMutableBorrowExpectedCompilerSha256,
            "-TypedBlockMutableBorrowOutputDirectory", (ConvertTo-ProcessArgument $TypedBlockMutableBorrowOutputDirectory)
        )
    }
    if ($BinaryChecksumCompiler -ne "") {
        $argumentList += @(
            "-BinaryChecksumCompiler", (ConvertTo-ProcessArgument $BinaryChecksumCompiler),
            "-BinaryChecksumExpectedCompilerSha256", $BinaryChecksumExpectedCompilerSha256,
            "-BinaryChecksumOutputDirectory", (ConvertTo-ProcessArgument $BinaryChecksumOutputDirectory)
        )
    }
    if ($GzipSelfhostCompiler -ne "") {
        $argumentList += @(
            "-GzipSelfhostCompiler", (ConvertTo-ProcessArgument $GzipSelfhostCompiler),
            "-GzipSelfhostExpectedCompilerSha256", $GzipSelfhostExpectedCompilerSha256,
            "-GzipSelfhostOutputDirectory", (ConvertTo-ProcessArgument $GzipSelfhostOutputDirectory)
        )
    }
    if ($AdditionalMoveOwnershipCompiler -ne "") {
        $argumentList += @(
            "-AdditionalMoveOwnershipCompiler", (ConvertTo-ProcessArgument $AdditionalMoveOwnershipCompiler),
            "-AdditionalMoveOwnershipExpectedCompilerSha256", $AdditionalMoveOwnershipExpectedCompilerSha256,
            "-AdditionalMoveOwnershipOutputDirectory", (ConvertTo-ProcessArgument $AdditionalMoveOwnershipOutputDirectory)
        )
    }
    if ($C341FinalCandidateCompiler -ne '') {
        $argumentList += @(
            '-C341FinalCandidateCompiler', (ConvertTo-ProcessArgument $C341FinalCandidateCompiler),
            '-C341FinalExpectedCompilerSha256', $C341FinalExpectedCompilerSha256,
            '-C341FinalOutputDirectory', (ConvertTo-ProcessArgument $C341FinalOutputDirectory),
            '-C341FinalGenerationRecord', (ConvertTo-ProcessArgument $C341FinalGenerationRecord),
            '-C341FinalSeedCompiler', (ConvertTo-ProcessArgument $C341FinalSeedCompiler)
        )
    }
    if ($C394FinalCandidateCompiler -ne '') {
        $argumentList += @(
            '-C394FinalCandidateCompiler', (ConvertTo-ProcessArgument $C394FinalCandidateCompiler),
            '-C394FinalExpectedCompilerSha256', $C394FinalExpectedCompilerSha256,
            '-C394FinalOutputDirectory', (ConvertTo-ProcessArgument $C394FinalOutputDirectory)
        )
    }
    if ($GenericTypeContextsCandidateCompiler -ne "") {
        $argumentList += @(
            "-GenericTypeContextsCandidateCompiler", (ConvertTo-ProcessArgument $GenericTypeContextsCandidateCompiler),
            "-GenericTypeContextsExpectedCompilerSha256", $GenericTypeContextsExpectedCompilerSha256
        )
    }
    if ($SelfhostDeferredTextStorageCandidateCompiler -ne "") {
        $argumentList += @(
            "-SelfhostDeferredTextStorageCandidateCompiler", (ConvertTo-ProcessArgument $SelfhostDeferredTextStorageCandidateCompiler),
            "-SelfhostDeferredTextStorageExpectedCompilerSha256", $SelfhostDeferredTextStorageExpectedCompilerSha256
        )
    }
    if ($SelfhostC424NestedWholeOwnerCandidateCompiler -ne "") {
        $argumentList += @(
            "-SelfhostC424NestedWholeOwnerCandidateCompiler", (ConvertTo-ProcessArgument $SelfhostC424NestedWholeOwnerCandidateCompiler),
            "-SelfhostC424NestedWholeOwnerExpectedCompilerSha256", $SelfhostC424NestedWholeOwnerExpectedCompilerSha256,
            "-SelfhostC424NestedWholeOwnerOutputDirectory", (ConvertTo-ProcessArgument $SelfhostC424NestedWholeOwnerOutputDirectory)
        )
    }
    if ($LinuxOwnershipStorageCompiler -ne "") {
        $argumentList += @(
            "-LinuxOwnershipStorageCompiler", (ConvertTo-ProcessArgument $LinuxOwnershipStorageCompiler),
            "-LinuxOwnershipStorageExpectedCompilerSha256", $LinuxOwnershipStorageExpectedCompilerSha256
        )
    }
    if ($ResumeCandidate) {
        $argumentList += "-ResumeCandidate"
    }

    $supervisorProcess = Start-Process `
        -FilePath $powerShellPath `
        -ArgumentList $argumentList `
        -WorkingDirectory $repositoryRoot `
        -WindowStyle Hidden `
        -PassThru

    $launchRecordPath = "$CompletionRecordPath.launch.json"
    Write-JsonAtomically -Path $launchRecordPath -Value ([ordered]@{
        schemaVersion = 1
        runId = $RunId
        verification = $Verification
        executionMode = "detached-supervisor"
        supervisorPid = $supervisorProcess.Id
        observerPid = $PID
        survivesObserverDisconnect = $true
        selectedFixtures = $selectedFixtures
        incrementalFixture = $IncrementalFixture
        incrementalTarget = $IncrementalTarget
        incrementalStage1Optimization = $IncrementalStage1Optimization
        managedCompiler = $ManagedCompiler
        expectedManagedCompilerSha256 = $ExpectedManagedCompilerSha256
        typedBlockMutableBorrowCompiler = $TypedBlockMutableBorrowCompiler
        typedBlockMutableBorrowExpectedCompilerSha256 = $TypedBlockMutableBorrowExpectedCompilerSha256
        typedBlockMutableBorrowOutputDirectory = $TypedBlockMutableBorrowOutputDirectory
        binaryChecksumCompiler = $BinaryChecksumCompiler
        binaryChecksumExpectedCompilerSha256 = $BinaryChecksumExpectedCompilerSha256
        binaryChecksumOutputDirectory = $BinaryChecksumOutputDirectory
        gzipSelfhostCompiler = $GzipSelfhostCompiler
        gzipSelfhostExpectedCompilerSha256 = $GzipSelfhostExpectedCompilerSha256
        gzipSelfhostOutputDirectory = $GzipSelfhostOutputDirectory
        additionalMoveOwnershipCompiler = $AdditionalMoveOwnershipCompiler
        additionalMoveOwnershipExpectedCompilerSha256 = $AdditionalMoveOwnershipExpectedCompilerSha256
        additionalMoveOwnershipOutputDirectory = $AdditionalMoveOwnershipOutputDirectory
        c341FinalCandidateCompiler = $C341FinalCandidateCompiler
        c341FinalCandidateCompilerSha256 = if ($Verification -eq 'C341FinalSelfhost') { $c341FinalCompilerSha256 } else { $null }
        c341FinalExpectedCompilerSha256 = $C341FinalExpectedCompilerSha256
        c341FinalGenerationRecord = $C341FinalGenerationRecord
        c341FinalGenerationRecordSha256 = if ($Verification -eq 'C341FinalSelfhost') { $c341FinalGenerationSha256 } else { $null }
        c341FinalSeedCompiler = $C341FinalSeedCompiler
        c341FinalSeedCompilerSha256 = if ($Verification -eq 'C341FinalSelfhost') { $c341FinalSeedSha256 } else { $null }
        c341FinalOutputDirectory = $C341FinalOutputDirectory
        c341FinalResultPath = if ($Verification -eq 'C341FinalSelfhost') { Join-Path $C341FinalOutputDirectory 'result.json' } else { $null }
        c341FinalResultSha256 = $null
        c394FinalCandidateCompiler = $C394FinalCandidateCompiler
        c394FinalCandidateCompilerSha256 = if ($Verification -eq 'C394FinalCandidate') { $c394FinalCompilerSha256 } else { $null }
        c394FinalExpectedCompilerSha256 = $C394FinalExpectedCompilerSha256
        c394FinalOutputDirectory = $C394FinalOutputDirectory
        c394FinalResultPath = if ($Verification -eq 'C394FinalCandidate') { Join-Path $C394FinalOutputDirectory 'result.json' } else { $null }
        c394FinalResultSha256 = $null
        genericTypeContextsCandidateCompiler = $GenericTypeContextsCandidateCompiler
        genericTypeContextsExpectedCompilerSha256 = $GenericTypeContextsExpectedCompilerSha256
        selfhostDeferredTextStorageCandidateCompiler = $SelfhostDeferredTextStorageCandidateCompiler
        selfhostDeferredTextStorageExpectedCompilerSha256 = $SelfhostDeferredTextStorageExpectedCompilerSha256
        selfhostC424NestedWholeOwnerCandidateCompiler = $SelfhostC424NestedWholeOwnerCandidateCompiler
        selfhostC424NestedWholeOwnerExpectedCompilerSha256 = $SelfhostC424NestedWholeOwnerExpectedCompilerSha256
        selfhostC424NestedWholeOwnerOutputDirectory = $SelfhostC424NestedWholeOwnerOutputDirectory
        linuxOwnershipStorageCompiler = $LinuxOwnershipStorageCompiler
        linuxOwnershipStorageExpectedCompilerSha256 = $LinuxOwnershipStorageExpectedCompilerSha256
        logPath = $LogPath
        completionRecordPath = $CompletionRecordPath
        cancellationRequestPath = $CancellationRequestPath
        cancellationAcknowledgementPath = $CancellationAcknowledgementPath
        launchedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    })
    [ordered]@{
        runId = $RunId
        verification = $Verification
        supervisorPid = $supervisorProcess.Id
        logPath = $LogPath
        completionRecordPath = $CompletionRecordPath
        cancellationRequestPath = $CancellationRequestPath
        cancellationAcknowledgementPath = $CancellationAcknowledgementPath
        launchRecordPath = $launchRecordPath
        focusedResultPath = if ($Verification -eq 'C341FinalSelfhost') { Join-Path $C341FinalOutputDirectory 'result.json' } elseif ($Verification -eq 'C394FinalCandidate') { Join-Path $C394FinalOutputDirectory 'result.json' } else { $null }
        focusedResultSha256 = $null
    } | ConvertTo-Json -Compress
    return
}

$startedAt = [DateTimeOffset]::UtcNow
$exitCode = 255
$failureIds = [Collections.Generic.List[string]]::new()
$cancelled = $false
$cancellationRequested = $false
$cancellationAcknowledgement = $null
$targetProcessId = $null
$targetExitCode = $null
$orphanProcessIds = [Collections.Generic.List[int]]::new()
$focusedResultPath = if ($Verification -eq 'C341FinalSelfhost') { Join-Path $C341FinalOutputDirectory 'result.json' } elseif ($Verification -eq 'C394FinalCandidate') { Join-Path $C394FinalOutputDirectory 'result.json' } else { $null }
$focusedResultSha256 = $null
$standardErrorPath = "$LogPath.stderr"
$observedProcesses = [Collections.Generic.Dictionary[string, object]]::new()
$processSnapshotCount = 0
$processAuditCompleted = $false

function Update-ObservedProcessTree {
    # CIM dates have microsecond precision. Match both PID and creation time;
    # a recycled PID never inherits the old process's completion obligation.
    $records = @(Get-CimInstance Win32_Process -ErrorAction Stop |
        Select-Object ProcessId, ParentProcessId, CreationDate)
    $script:processSnapshotCount++
    $byId = @{}
    foreach ($record in $records) { $byId[[int]$record.ProcessId] = $record }
    $pending = [Collections.Generic.Queue[string]]::new()
    $found = [Collections.Generic.HashSet[string]]::new()
    foreach ($identity in @($observedProcesses.Keys)) { $pending.Enqueue($identity) }
    while ($pending.Count -gt 0) {
        $identity = $pending.Dequeue()
        if (-not $found.Add($identity)) { continue }
        $parent = $observedProcesses[$identity].ProcessId
        $parentCreated = $observedProcesses[$identity].CreatedTicks
        # An absent parent is not an ancestry authority: its PID may have been
        # recycled by a process that was itself gone before this snapshot.
        # Already observed children keep their own completion obligations.
        if (-not $byId.ContainsKey($parent) -or
            $byId[$parent].CreationDate.ToUniversalTime().Ticks -ne $parentCreated) { continue }
        foreach ($record in $records) {
            if ([int]$record.ParentProcessId -ne $parent) { continue }
            $created = $record.CreationDate.ToUniversalTime().Ticks
            if ($created -lt $parentCreated) { continue }
            $child = [int]$record.ProcessId
            $childIdentity = "${child}:$created"
            if (-not $observedProcesses.ContainsKey($childIdentity)) {
                $observedProcesses.Add($childIdentity, [pscustomobject]@{ ProcessId = $child; CreatedTicks = $created })
                $pending.Enqueue($childIdentity)
            }
        }
    }
    foreach ($observed in @($observedProcesses.Values)) {
        $processId = $observed.ProcessId
        if ($byId.ContainsKey($processId) -and
            $byId[$processId].CreationDate.ToUniversalTime().Ticks -eq $observed.CreatedTicks) {
            $processId
        }
    }
}

function Complete-ObservedProcessAudit {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
    do {
        $remaining = @(Update-ObservedProcessTree)
        if ($remaining.Count -eq 0 -or [DateTimeOffset]::UtcNow -ge $deadline) { break }
        Start-Sleep -Milliseconds 100
    } while ($true)
    foreach ($processId in $remaining) { $orphanProcessIds.Add($processId) }
    $script:processAuditCompleted = $true
}

function Read-CancellationRequest {
    if (-not (Test-Path -LiteralPath $CancellationRequestPath -PathType Leaf)) { return $null }
    $request = Get-Content -LiteralPath $CancellationRequestPath -Raw | ConvertFrom-Json
    if ($request.schemaVersion -ne 1 -or $request.runId -cne $RunId -or
        [string]::IsNullOrWhiteSpace($request.requestedAtUtc)) {
        throw "Cancellation request does not match the active run"
    }
    return $request
}
try {
    $targetScript = switch ($Verification) {
        "Stage2" { Join-Path $PSScriptRoot "verify-selfhost-stage2.ps1" }
        "Stage3" { Join-Path $PSScriptRoot "verify-selfhost-stage3.ps1" }
        "Stage2Linux" { Join-Path $PSScriptRoot "verify-selfhost-stage2-linux.ps1" }
        "Stage3Linux" { Join-Path $PSScriptRoot "verify-selfhost-stage3-linux.ps1" }
        "BrowserStage2" { Join-Path $PSScriptRoot "build-stage2-browser.ps1" }
        "Incremental" { Join-Path $PSScriptRoot "verify-selfhost-incremental.ps1" }
        "ArrayInherent" { Join-Path $PSScriptRoot "verify-selfhost-array-inherent-methods.ps1" }
        "C341Focused" { Join-Path $PSScriptRoot "verify-selfhost-direct-owned-field-binding.ps1" }
        "C341FinalSelfhost" { Join-Path $PSScriptRoot "verify-c341-final-selfhost-candidate.ps1" }
        "C394FinalCandidate" { Join-Path $PSScriptRoot "verify-c394-final-candidate.ps1" }
        "ExpressionBatch" { Join-Path $PSScriptRoot "verify-expression-lowering-focused-batch.ps1" }
        "PortableMemoryIo" { Join-Path $PSScriptRoot "verify-portable-memory-io-contract.ps1" }
        "TypedBlockMutableBorrow" { Join-Path $PSScriptRoot "verify-typed-block-mutable-borrow-focused.ps1" }
        "BinaryChecksum" { Join-Path $PSScriptRoot "verify-binary-checksum-codecs-focused.ps1" }
        "GzipSelfhost" { Join-Path $PSScriptRoot "verify-gzip-selfhost-focused.ps1" }
        "AdditionalMoveOwnership" { Join-Path $PSScriptRoot "verify-additional-move-ownership.ps1" }
        "GenericTypeContexts" { Join-Path $PSScriptRoot "verify-generic-type-contexts.ps1" }
        "SelfhostDeferredTextStorage" { Join-Path $PSScriptRoot "verify-selfhost-deferred-text-storage.ps1" }
        "SelfhostC424NestedWholeOwner" { Join-Path $PSScriptRoot "verify-selfhost-c424-nested-whole-owner.ps1" }
        "LinuxOwnershipStorage" { Join-Path $PSScriptRoot "verify-linux-ownership-storage-focused.ps1" }
        "ManagedHost" { Join-Path $PSScriptRoot "build-managed-host.ps1" }
        "Probe" { Join-Path $PSScriptRoot "contracts\fixtures\detached-verification-probe.ps1" }
    }
    if (-not (Test-Path -LiteralPath $targetScript -PathType Leaf)) {
        throw "Verification script is missing: $targetScript"
    }

    $targetArguments = @("-NoProfile", "-File", (ConvertTo-ProcessArgument $targetScript))
    switch ($Verification) {
        "Stage2" {
            $targetArguments += @("-SeedMode", $SeedMode, "-Stage2BuildJobs", $Jobs.ToString())
            if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" }
        }
        "Stage3" {
            $targetArguments += @("-SeedMode", $SeedMode, "-Jobs", $Jobs.ToString())
            if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" }
        }
        "Stage2Linux" {
            $targetArguments += @("-Distribution", (ConvertTo-ProcessArgument $Distribution), "-Jobs", $Jobs.ToString())
            if ($ResumeCandidate) { $targetArguments += "-ResumeCandidate" } else { $targetArguments += "-Rebuild" }
        }
        "Stage3Linux" {
            $targetArguments += @("-Distribution", (ConvertTo-ProcessArgument $Distribution), "-Jobs", $Jobs.ToString())
        }
        "BrowserStage2" {
            if ($BrowserCandidateCompiler -ne "") {
                $targetArguments += @(
                    "-Stage2Compiler", (ConvertTo-ProcessArgument $BrowserCandidateCompiler),
                    "-FocusedFixture", (ConvertTo-ProcessArgument $BrowserFocusedFixture),
                    "-AllowUnpromotedCandidate",
                    "-CandidateOutputDirectory", (ConvertTo-ProcessArgument ("artifacts\scratch\browser-focused-" + $RunId))
                )
            }
        }
        "Incremental" {
            $targetArguments += @(
                "-Fixture", (ConvertTo-ProcessArgument $IncrementalFixture),
                "-Target", $IncrementalTarget,
                "-SeedMode", $SeedMode,
                "-Stage1Optimization", $IncrementalStage1Optimization,
                "-ManagedCompiler", (ConvertTo-ProcessArgument $ManagedCompiler),
                "-ExpectedManagedCompilerSha256", $ExpectedManagedCompilerSha256,
                "-CompareStage2:`$false",
                "-CancellationRequestPath", (ConvertTo-ProcessArgument $CancellationRequestPath),
                "-CancellationRunId", (ConvertTo-ProcessArgument $RunId),
                "-CancellationAcknowledgementPath", (ConvertTo-ProcessArgument $CancellationAcknowledgementPath)
            )
        }
        "C341Focused" {
            $targetArguments += @(
                "-OutputDirectory",
                (ConvertTo-ProcessArgument (Join-Path $scratchRoot "c341-selfhost-$RunId"))
            )
        }
        "C341FinalSelfhost" {
            $targetArguments += @(
                '-CandidateCompiler', (ConvertTo-ProcessArgument $C341FinalCandidateCompiler),
                '-ExpectedCandidateSha256', $C341FinalExpectedCompilerSha256,
                '-GenerationRecord', (ConvertTo-ProcessArgument $C341FinalGenerationRecord),
                '-SeedCompiler', (ConvertTo-ProcessArgument $C341FinalSeedCompiler),
                '-OutputDirectory', (ConvertTo-ProcessArgument $C341FinalOutputDirectory)
            )
        }
        "C394FinalCandidate" {
            $targetArguments += @(
                '-CandidateCompiler', (ConvertTo-ProcessArgument $C394FinalCandidateCompiler),
                '-ExpectedCandidateSha256', $C394FinalExpectedCompilerSha256,
                '-OutputDirectory', (ConvertTo-ProcessArgument $C394FinalOutputDirectory)
            )
        }
        "ExpressionBatch" {
            $targetArguments += @(
                "-Compiler", (ConvertTo-ProcessArgument $ExpressionBatchCompiler),
                "-RunId", $RunId,
                "-Jobs", $Jobs.ToString()
            )
            if ($ExpressionBatchManifest -ne "") {
                $targetArguments += @(
                    "-FixtureManifest", (ConvertTo-ProcessArgument $ExpressionBatchManifest),
                    "-FixtureManifestSha256", $ExpressionBatchManifestSha256
                )
            }
            if ($ValidateInputsOnly) { $targetArguments += '-ValidateInputsOnly' }
        }
        "PortableMemoryIo" {
            $targetArguments += @(
                "-OutputDirectory", (ConvertTo-ProcessArgument $PortableMemoryIoOutputDirectory),
                "-Compiler", (ConvertTo-ProcessArgument $PortableMemoryIoCompiler),
                "-ExpectedCompilerSha256", $PortableMemoryIoExpectedCompilerSha256
            )
        }
        "TypedBlockMutableBorrow" {
            $targetArguments += @(
                "-CompilerAssembly", (ConvertTo-ProcessArgument $TypedBlockMutableBorrowCompiler),
                "-ExpectedCompilerSha256", $TypedBlockMutableBorrowExpectedCompilerSha256,
                "-OutputDirectory", (ConvertTo-ProcessArgument $TypedBlockMutableBorrowOutputDirectory),
                "-RunManaged"
            )
        }
        "BinaryChecksum" {
            $targetArguments += @(
                "-RepositoryRoot", (ConvertTo-ProcessArgument $repositoryRoot),
                "-CompilerPath", (ConvertTo-ProcessArgument $BinaryChecksumCompiler),
                "-OutputDirectory", (ConvertTo-ProcessArgument $BinaryChecksumOutputDirectory),
                "-WslDistribution", (ConvertTo-ProcessArgument $Distribution)
            )
        }
        "GzipSelfhost" {
            if ($ValidateInputsOnly) {
                $targetArguments += "-ValidateOnly"
            } else {
                $targetArguments += @(
                    "-Compiler", (ConvertTo-ProcessArgument $GzipSelfhostCompiler),
                    "-ExpectedCompilerSha256", $GzipSelfhostExpectedCompilerSha256,
                    "-OutputDirectory", (ConvertTo-ProcessArgument $GzipSelfhostOutputDirectory)
                )
            }
        }
        "AdditionalMoveOwnership" {
            $targetArguments += @(
                "-Compiler", (ConvertTo-ProcessArgument $AdditionalMoveOwnershipCompiler),
                "-ExpectedCompilerSha256", $AdditionalMoveOwnershipExpectedCompilerSha256,
                "-OutputDirectory", (ConvertTo-ProcessArgument $AdditionalMoveOwnershipOutputDirectory)
            )
        }
        "GenericTypeContexts" {
            $targetArguments += @(
                "-RepositoryRoot", (ConvertTo-ProcessArgument $repositoryRoot),
                "-CandidateCompiler", (ConvertTo-ProcessArgument $GenericTypeContextsCandidateCompiler),
                "-TypeDelimiters",
                "-ReadonlyTextSlice",
                "-ExecuteFixtures"
            )
        }
        "SelfhostDeferredTextStorage" {
            $targetArguments += @(
                "-RepositoryRoot", (ConvertTo-ProcessArgument $repositoryRoot),
                "-CandidateCompiler", (ConvertTo-ProcessArgument $SelfhostDeferredTextStorageCandidateCompiler),
                "-RequireCandidateGate"
            )
        }
        "SelfhostC424NestedWholeOwner" {
            $targetArguments += @(
                "-CandidateCompiler", (ConvertTo-ProcessArgument $SelfhostC424NestedWholeOwnerCandidateCompiler),
                "-OutputDirectory", (ConvertTo-ProcessArgument $SelfhostC424NestedWholeOwnerOutputDirectory)
            )
        }
        "LinuxOwnershipStorage" {
            $targetArguments += @("-RepositoryRoot", (ConvertTo-ProcessArgument $repositoryRoot))
        }
        "ManagedHost" { $targetArguments += @("-RunId", (ConvertTo-ProcessArgument $RunId)) }
        "Probe" { $targetArguments += @(
                "-Outcome", $ProbeOutcome,
                '-EvidencePath', (ConvertTo-ProcessArgument "$CompletionRecordPath.probe-child.json"),
                '-CancellationRequestPath', (ConvertTo-ProcessArgument $CancellationRequestPath),
                '-CancellationRunId', (ConvertTo-ProcessArgument $RunId),
                '-CancellationAcknowledgementPath', (ConvertTo-ProcessArgument $CancellationAcknowledgementPath)
            ) }
    }

    $savedBuildEnvironment = [ordered]@{
        DOTNET_CLI_USE_MSBUILD_SERVER = $env:DOTNET_CLI_USE_MSBUILD_SERVER
        MSBUILDDISABLENODEREUSE = $env:MSBUILDDISABLENODEREUSE
        UseSharedCompilation = $env:UseSharedCompilation
    }
    try {
        $env:DOTNET_CLI_USE_MSBUILD_SERVER = '0'
        $env:MSBUILDDISABLENODEREUSE = '1'
        $env:UseSharedCompilation = 'false'
        $targetProcess = Start-Process `
            -FilePath (Get-Process -Id $PID).Path `
            -ArgumentList $targetArguments `
            -WorkingDirectory $repositoryRoot `
            -RedirectStandardOutput $LogPath `
            -RedirectStandardError $standardErrorPath `
            -WindowStyle Hidden `
            -PassThru
    } finally {
        foreach ($name in $savedBuildEnvironment.Keys) {
            $value = $savedBuildEnvironment[$name]
            if ($null -eq $value) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:$name" $value }
        }
    }
    $targetProcessId = $targetProcess.Id
    $startTicks = $targetProcess.StartTime.ToUniversalTime().Ticks
    $startTicks -= $startTicks % 10
    $observedProcesses.Add("$($targetProcess.Id):$startTicks", [pscustomobject]@{
        ProcessId = $targetProcess.Id; CreatedTicks = $startTicks
    })
    Update-ObservedProcessTree | Out-Null
    while ($true) {
        $request = Read-CancellationRequest
        if ($null -eq $request) {
            if ($targetProcess.WaitForExit(100)) { break }
            Update-ObservedProcessTree | Out-Null
            continue
        }

        $cancellationRequested = $true
        $cancellationDeadline = [DateTimeOffset]::UtcNow.AddSeconds($CancellationTimeoutSeconds)
        while (-not $targetProcess.WaitForExit(100)) {
            Update-ObservedProcessTree | Out-Null
            if ([DateTimeOffset]::UtcNow -ge $cancellationDeadline) { break }
        }
        if (-not $targetProcess.HasExited) {
            $exitCode = 124
            $failureIds.Add('COOPERATIVE_CANCELLATION_TIMEOUT')
            Complete-ObservedProcessAudit
            break
        }
        $targetExitCode = $targetProcess.ExitCode
        if (Test-Path -LiteralPath $CancellationAcknowledgementPath -PathType Leaf) {
            try {
                $ack = Get-Content -LiteralPath $CancellationAcknowledgementPath -Raw | ConvertFrom-Json
                if ($ack.schemaVersion -eq 1 -and $ack.runId -ceq $RunId -and
                    [int]$ack.targetProcessId -eq $targetProcessId -and
                    -not [string]::IsNullOrWhiteSpace([string]$ack.observedAtUtc)) {
                    $cancellationAcknowledgement = $ack
                }
            } catch { $cancellationAcknowledgement = $null }
        }
        Complete-ObservedProcessAudit
        if ($null -eq $cancellationAcknowledgement) {
            $exitCode = 1
            $failureIds.Add('CANCELLATION_ACKNOWLEDGEMENT_MISSING')
            break
        }
        if ($targetExitCode -ne 130) {
            $exitCode = 1
            $failureIds.Add('CANCELLATION_NOT_HONORED')
            break
        }
        if ($orphanProcessIds.Count -ne 0) {
            $exitCode = 1
            $failureIds.Add('ORPHAN_PROCESSES_REMAIN')
            break
        }
        $cancelled = $true
        $exitCode = 130
        $failureIds.Add("CANCELLATION_REQUESTED")
        break
    }
    if (-not $cancelled -and -not $cancellationRequested) {
        $targetExitCode = $targetProcess.ExitCode
        $exitCode = $targetExitCode
        Complete-ObservedProcessAudit
        if ($orphanProcessIds.Count -ne 0) {
            if ($exitCode -eq 0) { $exitCode = 1 }
            $failureIds.Add('ORPHAN_PROCESSES_REMAIN')
        }
        if ($Verification -eq 'GzipSelfhost') {
            $gzipWorkerResult = Read-GzipSelfhostWorkerResult `
                -ResultPath (Join-Path $GzipSelfhostOutputDirectory 'result.json') `
                -SchemaPath (Join-Path $PSScriptRoot 'contracts/gzip-selfhost-focused-result.schema.json') `
                -FocusedContractPath (Join-Path $PSScriptRoot 'contracts/gzip-selfhost-focused.json') `
                -RepositoryRoot $repositoryRoot `
                -CompilerPath $GzipSelfhostCompiler `
                -ExpectedCompilerSha256 $GzipSelfhostExpectedCompilerSha256 `
                -TargetExitCode $targetExitCode
            if (-not $gzipWorkerResult.valid) {
                $exitCode = 1
                $failureIds.Add($gzipWorkerResult.failureId)
            } else {
                foreach ($workerFailureId in @($gzipWorkerResult.workerFailureIds)) {
                    if (-not $failureIds.Contains($workerFailureId)) {
                        $failureIds.Add($workerFailureId)
                    }
                }
            }
        }
        if ($Verification -eq 'BinaryChecksum' -and $targetExitCode -eq 0) {
            $binaryResultPath = Join-Path $BinaryChecksumOutputDirectory 'result.json'
            if (-not (Test-Path -LiteralPath $binaryResultPath -PathType Leaf)) {
                $exitCode = 1
                $failureIds.Add('BINARY_CHECKSUM_RESULT_MISSING')
            } else {
                try {
                    $binaryResult = Get-Content -LiteralPath $binaryResultPath -Raw | ConvertFrom-Json
                    if ($binaryResult.status -cne 'passed' -or $binaryResult.completed -ne 27 -or
                        $binaryResult.total -ne 27 -or @($binaryResult.failureIds).Count -ne 0) {
                        $exitCode = 1
                        $failureIds.Add('BINARY_CHECKSUM_RESULT_INVALID')
                    }
                    if ($binaryResult.toolHashes.compiler.sha256 -cne $BinaryChecksumExpectedCompilerSha256) {
                        $exitCode = 1
                        $failureIds.Add('BINARY_CHECKSUM_COMPILER_SHA_MISMATCH')
                    }
                }
                catch {
                    $exitCode = 1
                    if (-not $failureIds.Contains('BINARY_CHECKSUM_RESULT_INVALID')) {
                        $failureIds.Add('BINARY_CHECKSUM_RESULT_INVALID')
                    }
                }
            }
        }
        if ($Verification -eq 'GenericTypeContexts' -and $targetExitCode -eq 0) {
            $genericResultMatches = [regex]::Matches(
                [IO.File]::ReadAllText($LogPath),
                '(?im)^(?<path>[A-Z]:\\[^\r\n]*\\result\.json)\s*$')
            if ($genericResultMatches.Count -ne 1) {
                $exitCode = 1
                $failureIds.Add('GENERIC_TYPE_CONTEXTS_RESULT_MISSING')
            } else {
                try {
                    $genericResultPath = [IO.Path]::GetFullPath($genericResultMatches[0].Groups['path'].Value)
                    $genericResultRoot = [IO.Path]::GetFullPath((Join-Path $scratchRoot 'generic-type-contexts')) + [IO.Path]::DirectorySeparatorChar
                    if (-not $genericResultPath.StartsWith($genericResultRoot, [StringComparison]::OrdinalIgnoreCase) -or
                        -not (Test-Path -LiteralPath $genericResultPath -PathType Leaf)) {
                        throw 'GenericTypeContexts result path is outside its verifier-owned scratch root or missing'
                    }
                    $genericResult = Get-Content -LiteralPath $genericResultPath -Raw | ConvertFrom-Json
                    if ($genericResult.status -cne 'passed' -or $genericResult.completed -ne 21 -or $genericResult.total -ne 21 -or
                        $genericResult.typeDelimiters.status -cne 'passed' -or $genericResult.typeDelimiters.completed -ne 41 -or $genericResult.typeDelimiters.total -ne 41 -or
                        $genericResult.declarationLayouts.status -cne 'passed' -or $genericResult.declarationLayouts.completed -ne 2 -or $genericResult.declarationLayouts.total -ne 2 -or
                        $genericResult.declarationRecursionAndDiagnostics.status -cne 'passed' -or $genericResult.declarationRecursionAndDiagnostics.completed -ne 4 -or $genericResult.declarationRecursionAndDiagnostics.total -ne 4 -or
                        $genericResult.readonlyTextSlice.status -cne 'passed' -or $genericResult.readonlyTextSlice.completed -ne 11 -or $genericResult.readonlyTextSlice.total -ne 11 -or
                        $genericResult.managedExecution.status -cne 'passed' -or $genericResult.managedExecution.completed -ne 9 -or $genericResult.managedExecution.total -ne 9 -or
                        $genericResult.c396CandidateWindows.status -cne 'passed' -or $genericResult.c396CandidateWindows.completed -ne 10 -or $genericResult.c396CandidateWindows.total -ne 10) {
                        $exitCode = 1
                        $failureIds.Add('GENERIC_TYPE_CONTEXTS_RESULT_INVALID')
                    }
                    if ($genericResult.c396CandidateWindows.compilerSha256 -cne $GenericTypeContextsExpectedCompilerSha256) {
                        $exitCode = 1
                        $failureIds.Add('GENERIC_TYPE_CONTEXTS_COMPILER_SHA_MISMATCH')
                    }
                }
                catch {
                    $exitCode = 1
                    if (-not $failureIds.Contains('GENERIC_TYPE_CONTEXTS_RESULT_INVALID')) {
                        $failureIds.Add('GENERIC_TYPE_CONTEXTS_RESULT_INVALID')
                    }
                }
            }
        }
        if ($Verification -eq 'SelfhostDeferredTextStorage' -and $targetExitCode -eq 0) {
            $deferredResultMatches = [regex]::Matches([IO.File]::ReadAllText($LogPath), '(?im)(?<path>[A-Z]:\\[^\r\n]*\\result\.json)\s*$')
            if ($deferredResultMatches.Count -ne 1) {
                $exitCode = 1
                $failureIds.Add('SELFHOST_DEFERRED_TEXT_STORAGE_RESULT_MISSING')
            } else {
                try {
                    $deferredResultPath = [IO.Path]::GetFullPath($deferredResultMatches[0].Groups['path'].Value)
                    $deferredResultRoot = [IO.Path]::GetFullPath($scratchRoot) + [IO.Path]::DirectorySeparatorChar + 'selfhost-deferred-text-storage-'
                    if (-not $deferredResultPath.StartsWith($deferredResultRoot, [StringComparison]::OrdinalIgnoreCase) -or
                        -not (Test-Path -LiteralPath $deferredResultPath -PathType Leaf)) {
                        throw 'SelfhostDeferredTextStorage result path is outside its verifier-owned scratch root or missing'
                    }
                    $deferredResult = Get-Content -LiteralPath $deferredResultPath -Raw | ConvertFrom-Json
                    if ($deferredResult.status -cne 'passed' -or $deferredResult.completed -ne 31 -or $deferredResult.total -ne 31 -or
                        $deferredResult.stage2Stage3Executed -ne $false -or
                        $deferredResult.candidateGate.status -cne 'passed' -or $deferredResult.candidateGate.completed -ne 17 -or
                        $deferredResult.candidateGate.total -ne 17) {
                        $exitCode = 1
                        $failureIds.Add('SELFHOST_DEFERRED_TEXT_STORAGE_RESULT_INVALID')
                    }
                    if ($deferredResult.candidateCompilerSha256 -cne $SelfhostDeferredTextStorageExpectedCompilerSha256) {
                        $exitCode = 1
                        $failureIds.Add('SELFHOST_DEFERRED_TEXT_STORAGE_COMPILER_SHA_MISMATCH')
                    }
                } catch {
                    $exitCode = 1
                    if (-not $failureIds.Contains('SELFHOST_DEFERRED_TEXT_STORAGE_RESULT_INVALID')) {
                        $failureIds.Add('SELFHOST_DEFERRED_TEXT_STORAGE_RESULT_INVALID')
                    }
                }
            }
        }
        if ($Verification -eq 'SelfhostC424NestedWholeOwner' -and $targetExitCode -eq 0) {
            $c424ResultPath = Join-Path $SelfhostC424NestedWholeOwnerOutputDirectory 'result.json'
            if (-not (Test-Path -LiteralPath $c424ResultPath -PathType Leaf)) {
                $exitCode = 1
                $failureIds.Add('SELFHOST_C424_NESTED_WHOLE_OWNER_RESULT_MISSING')
            } else {
                try {
                    $c424Result = Get-Content -LiteralPath $c424ResultPath -Raw | ConvertFrom-Json
                    if ($c424Result.runStatus -cne 'passed' -or $c424Result.completionStatus -cne 'complete' -or
                        $c424Result.completed -ne 1 -or $c424Result.total -ne 1 -or -not $c424Result.case.passed -or
                        @($c424Result.failureIds).Count -ne 0) {
                        $exitCode = 1
                        $failureIds.Add('SELFHOST_C424_NESTED_WHOLE_OWNER_RESULT_INVALID')
                    }
                    if ($c424Result.compilerSha256 -cne $SelfhostC424NestedWholeOwnerExpectedCompilerSha256) {
                        $exitCode = 1
                        $failureIds.Add('SELFHOST_C424_NESTED_WHOLE_OWNER_COMPILER_SHA_MISMATCH')
                    }
                } catch {
                    $exitCode = 1
                    if (-not $failureIds.Contains('SELFHOST_C424_NESTED_WHOLE_OWNER_RESULT_INVALID')) {
                        $failureIds.Add('SELFHOST_C424_NESTED_WHOLE_OWNER_RESULT_INVALID')
                    }
                }
            }
        }
        if ($Verification -in @('C341FinalSelfhost','C394FinalCandidate') -and $targetExitCode -eq 0) {
            $modePrefix = if ($Verification -eq 'C341FinalSelfhost') { 'C341_FINAL_SELFHOST' } else { 'C394_FINAL_CANDIDATE' }
            $modeSchema = if ($Verification -eq 'C341FinalSelfhost') { Join-Path $PSScriptRoot 'contracts/c341-final-selfhost-candidate-result.schema.json' } else { Join-Path $PSScriptRoot 'contracts/c394-final-candidate-result.schema.json' }
            $modeExpectedSha = if ($Verification -eq 'C341FinalSelfhost') { $C341FinalExpectedCompilerSha256 } else { $C394FinalExpectedCompilerSha256 }
            if (-not (Test-Path -LiteralPath $focusedResultPath -PathType Leaf)) {
                $exitCode = 1
                $failureIds.Add("${modePrefix}_RESULT_MISSING")
            } else {
                try {
                    $focusedResultText = [IO.File]::ReadAllText($focusedResultPath)
                    if (-not ($focusedResultText | Test-Json -SchemaFile $modeSchema -ErrorAction Stop)) { throw 'result schema rejected worker result' }
                    $focusedResult = $focusedResultText | ConvertFrom-Json
                    if ($focusedResult.status -cne 'passed' -or -not $focusedResult.inputStable -or -not $focusedResult.candidateShaMatched -or
                        $focusedResult.compilerSha256 -cne $modeExpectedSha -or @($focusedResult.failureIds).Count -ne 0) { throw 'worker result did not satisfy final candidate invariants' }
                    $focusedResultSha256 = (Get-FileHash -LiteralPath $focusedResultPath -Algorithm SHA256).Hash
                } catch {
                    $exitCode = 1
                    $failureIds.Add("${modePrefix}_RESULT_INVALID")
                }
            }
        }
        if ($Verification -eq 'LinuxOwnershipStorage' -and $targetExitCode -eq 0) {
            $linuxResultMatches = [regex]::Matches([IO.File]::ReadAllText($LogPath), '(?im)(?<path>[A-Z]:\\[^\r\n]*\\result\.json)\s*$')
            if ($linuxResultMatches.Count -ne 1) {
                $exitCode = 1
                $failureIds.Add('LINUX_OWNERSHIP_STORAGE_RESULT_MISSING')
            } else {
                try {
                    $linuxResultPath = [IO.Path]::GetFullPath($linuxResultMatches[0].Groups['path'].Value)
                    $linuxResultRoot = [IO.Path]::GetFullPath($scratchRoot) + [IO.Path]::DirectorySeparatorChar + 'linux-ownership-storage-focused-'
                    if (-not $linuxResultPath.StartsWith($linuxResultRoot, [StringComparison]::OrdinalIgnoreCase) -or
                        -not (Test-Path -LiteralPath $linuxResultPath -PathType Leaf)) {
                        throw 'LinuxOwnershipStorage result path is outside its verifier-owned scratch root or missing'
                    }
                    $linuxResult = Get-Content -LiteralPath $linuxResultPath -Raw | ConvertFrom-Json
                    $linuxCompilerKey = 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
                    if ($linuxResult.status -cne 'passed' -or $linuxResult.completed -ne 2 -or $linuxResult.total -ne 2 -or
                        $linuxResult.target -cne 'linux-x64' -or $linuxResult.inputsStable -ne $true) {
                        $exitCode = 1
                        $failureIds.Add('LINUX_OWNERSHIP_STORAGE_RESULT_INVALID')
                    }
                    if ($linuxResult.inputHashes.$linuxCompilerKey -cne $LinuxOwnershipStorageExpectedCompilerSha256) {
                        $exitCode = 1
                        $failureIds.Add('LINUX_OWNERSHIP_STORAGE_COMPILER_SHA_MISMATCH')
                    }
                } catch {
                    $exitCode = 1
                    if (-not $failureIds.Contains('LINUX_OWNERSHIP_STORAGE_RESULT_INVALID')) {
                        $failureIds.Add('LINUX_OWNERSHIP_STORAGE_RESULT_INVALID')
                    }
                }
            }
        }
    }
}
catch {
    $failureIds.Add("SUPERVISOR_EXECUTION_FAILURE")
    "SUPERVISOR_EXECUTION_FAILURE: $($_.Exception.Message)" | Add-Content -LiteralPath $standardErrorPath -Encoding utf8
}
finally {
    if ($null -ne $focusedResultPath -and (Test-Path -LiteralPath $focusedResultPath -PathType Leaf)) {
        $focusedResultSha256 = (Get-FileHash -LiteralPath $focusedResultPath -Algorithm SHA256).Hash
    }
    $cooperativeCancellationTimedOut =
        $failureIds.Count -eq 1 -and
        $failureIds[0] -ceq 'COOPERATIVE_CANCELLATION_TIMEOUT'
    if (-not $cooperativeCancellationTimedOut -and (Test-Path -LiteralPath $standardErrorPath)) {
        $standardError = [IO.File]::ReadAllText($standardErrorPath)
        if (-not [string]::IsNullOrWhiteSpace($standardError)) {
            "`n--- standard error ---`n$standardError" | Add-Content -LiteralPath $LogPath -Encoding utf8
        }
    }

    if (-not $cooperativeCancellationTimedOut -and -not $cancelled -and
        $exitCode -ne 0 -and (Test-Path -LiteralPath $LogPath)) {
        $logText = [IO.File]::ReadAllText($LogPath)
        foreach ($line in $logText -split '\r?\n') {
            if ($line -notmatch '(?i)(?<![a-z0-9-])(?:fail(?:ed|ure)?|error|exception|throw|fatal)(?![a-z0-9-])') {
                continue
            }
            foreach ($match in [regex]::Matches($line, '(?i)\b(?:[ES]\d+|(?:CS|MSB|NETSDK)\d+|\d{1,4}-[a-z0-9][a-z0-9-]*|AS-[A-Z]+-\d+(?:-[A-Z0-9-]+)?|MANAGED_HOST_BUILD_FAILED|SUPERVISOR_EXECUTION_FAILURE)\b')) {
                if (-not $failureIds.Contains($match.Value)) {
                    $failureIds.Add($match.Value)
                }
            }
        }
    }
    if (-not $cancelled -and $null -ne $targetExitCode -and $targetExitCode -ne 0) {
        $specificTargetFailureIds = @($failureIds | Where-Object {
            $_ -cne 'ORPHAN_PROCESSES_REMAIN' -and $_ -cne 'SUPERVISOR_EXECUTION_FAILURE'
        })
        if ($specificTargetFailureIds.Count -eq 0) {
            $failureIds.Add('TARGET_PROCESS_FAILED')
        }
    }

    $completedAt = [DateTimeOffset]::UtcNow
    Write-JsonAtomically -Path $CompletionRecordPath -Value ([ordered]@{
        schemaVersion = 3
        runId = $RunId
        verification = $Verification
        executionMode = "detached-supervisor"
        supervisorPid = $PID
        startedAtUtc = $startedAt.ToString("O")
        completedAtUtc = $completedAt.ToString("O")
        durationMilliseconds = [math]::Round(($completedAt - $startedAt).TotalMilliseconds)
        exitCode = $exitCode
        status = if ($cancelled) { "cancelled" } elseif ($exitCode -eq 0) { "passed" } else { "failed" }
        failureIds = @($failureIds)
        logPath = $LogPath
        standardErrorPath = $standardErrorPath
        cancellationRequestPath = $CancellationRequestPath
        cancellationAcknowledgementPath = $CancellationAcknowledgementPath
        cancellationAcknowledgement = $cancellationAcknowledgement
        additionalMoveOwnershipCompiler = if ($Verification -eq 'AdditionalMoveOwnership') { $AdditionalMoveOwnershipCompiler } else { $null }
        additionalMoveOwnershipExpectedCompilerSha256 = if ($Verification -eq 'AdditionalMoveOwnership') { $AdditionalMoveOwnershipExpectedCompilerSha256 } else { $null }
        additionalMoveOwnershipOutputDirectory = if ($Verification -eq 'AdditionalMoveOwnership') { $AdditionalMoveOwnershipOutputDirectory } else { $null }
        focusedResultPath = $focusedResultPath
        focusedResultSha256 = $focusedResultSha256
        targetProcessId = $targetProcessId
        targetExitCode = $targetExitCode
        orphanProcessIds = @($orphanProcessIds)
        processAudit = [ordered]@{
            method = 'observed-pid-creation-time-snapshots'
            completed = $processAuditCompleted
            snapshotCount = $processSnapshotCount
            observedProcessIds = @($observedProcesses.Values | ForEach-Object { $_.ProcessId } | Sort-Object -Unique)
        }
    })
}

exit $exitCode
