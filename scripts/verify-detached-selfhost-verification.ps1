param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$runId = "detached-contract-$PID-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$scratchRoot = Join-Path $RepositoryRoot "artifacts\scratch"
$logPath = Join-Path $scratchRoot "$runId.log"
$completionRecordPath = Join-Path $scratchRoot "$runId.result.json"
$observerOutputPath = Join-Path $scratchRoot "$runId.observer.json"
$launcherPath = Join-Path $RepositoryRoot "scripts\invoke-detached-selfhost-verification.ps1"
$cancellationRequesterPath = Join-Path $RepositoryRoot "scripts\request-detached-selfhost-cancellation.ps1"
$progressReaderPath = Join-Path $RepositoryRoot "scripts\read-detached-selfhost-progress.ps1"
$resultSchemaPath = Join-Path $RepositoryRoot "scripts\contracts\detached-selfhost-verification-result.schema.json"
$contractStarted = [DateTimeOffset]::UtcNow
$contractChecks = [Collections.Generic.List[string]]::new()
$contractStatus = 'failed'
$contractError = ''
$contractPaths = @(
    $PSCommandPath, $launcherPath, $cancellationRequesterPath, $progressReaderPath, $resultSchemaPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'),
    (Join-Path $PSScriptRoot 'verify-selfhost-incremental.ps1'),
    (Join-Path $PSScriptRoot 'expression-batch-selection.ps1'),
    (Join-Path $PSScriptRoot 'verify-expression-lowering-focused-batch.ps1'),
    (Join-Path $PSScriptRoot 'verify-additional-move-ownership.ps1'),
    (Join-Path $PSScriptRoot 'verify-binary-checksum-codecs-focused.ps1'),
    (Join-Path $PSScriptRoot 'verify-generic-type-contexts.ps1'),
    (Join-Path $PSScriptRoot 'verify-selfhost-deferred-text-storage.ps1'),
    (Join-Path $PSScriptRoot 'verify-selfhost-c424-nested-whole-owner.ps1'),
    (Join-Path $PSScriptRoot 'verify-linux-ownership-storage-focused.ps1'),
    (Join-Path $PSScriptRoot 'verify-c341-final-selfhost-candidate.ps1'),
    (Join-Path $PSScriptRoot 'verify-c394-final-candidate.ps1'),
    (Join-Path $PSScriptRoot 'contracts/expression-batch-selection.schema.json'),
    (Join-Path $PSScriptRoot 'contracts/binary-checksum-codecs.json'),
    (Join-Path $PSScriptRoot 'contracts/additional-move-ownership-result.schema.json'),
    (Join-Path $PSScriptRoot 'contracts/generic-type-context-execution.json'),
    (Join-Path $PSScriptRoot 'contracts/readonly-text-slice.json'),
    (Join-Path $PSScriptRoot 'contracts/selfhost-c424-nested-whole-owner-result.schema.json'),
    (Join-Path $PSScriptRoot 'contracts/c341-final-selfhost-candidate-result.schema.json'),
    (Join-Path $PSScriptRoot 'contracts/c394-final-candidate-result.schema.json'),
    (Join-Path $PSScriptRoot 'probes/type-delimiters/cases.json'),
    (Join-Path $PSScriptRoot 'contracts/fixtures/detached-verification-probe.ps1')
)
$inputHashes = @($contractPaths | ForEach-Object { Get-FileHash -LiteralPath $_ -Algorithm SHA256 } |
    Select-Object Path, Hash)
$launcherText = [IO.File]::ReadAllText($launcherPath)
if (-not $launcherText.Contains('"C341Focused" { Join-Path $PSScriptRoot "verify-selfhost-direct-owned-field-binding.ps1" }', [StringComparison]::Ordinal)) {
    throw 'detached launcher omits the dedicated C341 focused verifier route'
}
if (-not $launcherText.Contains('"-Stage1Optimization", $IncrementalStage1Optimization', [StringComparison]::Ordinal)) {
    throw 'detached incremental launcher omits the selected Stage1 optimization'
}
if (-not $launcherText.Contains('[ValidateSet("O0", "O1")]', [StringComparison]::Ordinal)) {
    throw 'detached incremental Stage1 optimization is not constrained to O0/O1'
}
foreach ($launchAuthority in @(
    'incrementalFixture = $IncrementalFixture',
    'incrementalTarget = $IncrementalTarget')) {
    if (-not $launcherText.Contains($launchAuthority, [StringComparison]::Ordinal)) {
        throw "detached incremental launch record omits authority: $launchAuthority"
    }
}
$progressReaderText = [IO.File]::ReadAllText($progressReaderPath)
foreach ($progressAuthority in @(
    "incrementalFixture = if (`$null -ne `$incrementalFixtureProperty)",
    "incrementalTarget = if (`$null -ne `$incrementalTargetProperty)")) {
    if (-not $progressReaderText.Contains($progressAuthority, [StringComparison]::Ordinal)) {
        throw "detached progress output omits authority: $progressAuthority"
    }
}
if (-not $launcherText.Contains('"-ManagedCompiler", (ConvertTo-ProcessArgument $ManagedCompiler)', [StringComparison]::Ordinal) -or
    -not $launcherText.Contains('"-ExpectedManagedCompilerSha256", $ExpectedManagedCompilerSha256', [StringComparison]::Ordinal)) {
    throw 'detached incremental launcher omits the receipt-bound managed compiler inputs'
}
if (-not $launcherText.Contains('"BinaryChecksum" { Join-Path $PSScriptRoot "verify-binary-checksum-codecs-focused.ps1" }', [StringComparison]::Ordinal)) {
    throw 'detached launcher omits the dedicated BinaryChecksum verifier route'
}
foreach ($forwardedInput in @(
    '"-RepositoryRoot", (ConvertTo-ProcessArgument $repositoryRoot)',
    '"-CompilerPath", (ConvertTo-ProcessArgument $BinaryChecksumCompiler)',
    '"-OutputDirectory", (ConvertTo-ProcessArgument $BinaryChecksumOutputDirectory)',
    '"-WslDistribution", (ConvertTo-ProcessArgument $Distribution)')) {
    if (-not $launcherText.Contains($forwardedInput, [StringComparison]::Ordinal)) {
        throw "detached BinaryChecksum launcher omits child input: $forwardedInput"
    }
}
foreach ($binaryPostcondition in @(
    "'BINARY_CHECKSUM_RESULT_MISSING'",
    "'BINARY_CHECKSUM_RESULT_INVALID'",
    "'BINARY_CHECKSUM_COMPILER_SHA_MISMATCH'")) {
    if (-not $launcherText.Contains($binaryPostcondition, [StringComparison]::Ordinal)) {
        throw "detached BinaryChecksum launcher omits postcondition: $binaryPostcondition"
    }
}
if (-not $launcherText.Contains('"GenericTypeContexts" { Join-Path $PSScriptRoot "verify-generic-type-contexts.ps1" }', [StringComparison]::Ordinal)) {
    throw 'detached launcher omits the dedicated GenericTypeContexts verifier route'
}
foreach ($genericInput in @(
    '"-RepositoryRoot", (ConvertTo-ProcessArgument $repositoryRoot)',
    '"-CandidateCompiler", (ConvertTo-ProcessArgument $GenericTypeContextsCandidateCompiler)',
    '"-TypeDelimiters"',
    '"-ReadonlyTextSlice"',
    '"-ExecuteFixtures"')) {
    if (-not $launcherText.Contains($genericInput, [StringComparison]::Ordinal)) {
        throw "detached GenericTypeContexts launcher omits fixed child input: $genericInput"
    }
}
foreach ($genericPostcondition in @(
    "'GENERIC_TYPE_CONTEXTS_RESULT_MISSING'",
    "'GENERIC_TYPE_CONTEXTS_RESULT_INVALID'",
    "'GENERIC_TYPE_CONTEXTS_COMPILER_SHA_MISMATCH'")) {
    if (-not $launcherText.Contains($genericPostcondition, [StringComparison]::Ordinal)) {
        throw "detached GenericTypeContexts launcher omits postcondition: $genericPostcondition"
    }
}
foreach ($route in @(
    @{ Name = 'SelfhostDeferredTextStorage'; Script = 'verify-selfhost-deferred-text-storage.ps1' },
    @{ Name = 'SelfhostC424NestedWholeOwner'; Script = 'verify-selfhost-c424-nested-whole-owner.ps1' },
    @{ Name = 'LinuxOwnershipStorage'; Script = 'verify-linux-ownership-storage-focused.ps1' },
    @{ Name = 'C341FinalSelfhost'; Script = 'verify-c341-final-selfhost-candidate.ps1' },
    @{ Name = 'C394FinalCandidate'; Script = 'verify-c394-final-candidate.ps1' }
)) {
    $routeText = '"' + $route.Name + '" { Join-Path $PSScriptRoot "' + $route.Script + '" }'
    if (-not $launcherText.Contains($routeText, [StringComparison]::Ordinal)) {
        throw "detached launcher omits the dedicated $($route.Name) verifier route"
    }
}
foreach ($requiredText in @(
    '"-CandidateCompiler", (ConvertTo-ProcessArgument $SelfhostDeferredTextStorageCandidateCompiler)',
    '"-RequireCandidateGate"',
    '"-CandidateCompiler", (ConvertTo-ProcessArgument $SelfhostC424NestedWholeOwnerCandidateCompiler)',
    '"-OutputDirectory", (ConvertTo-ProcessArgument $SelfhostC424NestedWholeOwnerOutputDirectory)',
    '$linuxCompilerKey = ''src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'''
)) {
    if (-not $launcherText.Contains($requiredText, [StringComparison]::Ordinal)) {
        throw "detached focused storage launcher omits required contract text: $requiredText"
    }
}
foreach ($postcondition in @(
    "'SELFHOST_DEFERRED_TEXT_STORAGE_RESULT_MISSING'", "'SELFHOST_DEFERRED_TEXT_STORAGE_RESULT_INVALID'", "'SELFHOST_DEFERRED_TEXT_STORAGE_COMPILER_SHA_MISMATCH'",
    "'SELFHOST_C424_NESTED_WHOLE_OWNER_RESULT_MISSING'", "'SELFHOST_C424_NESTED_WHOLE_OWNER_RESULT_INVALID'", "'SELFHOST_C424_NESTED_WHOLE_OWNER_COMPILER_SHA_MISMATCH'",
    "'LINUX_OWNERSHIP_STORAGE_RESULT_MISSING'", "'LINUX_OWNERSHIP_STORAGE_RESULT_INVALID'", "'LINUX_OWNERSHIP_STORAGE_COMPILER_SHA_MISMATCH'"
)) {
    if (-not $launcherText.Contains($postcondition, [StringComparison]::Ordinal)) {
        throw "detached focused storage launcher omits postcondition: $postcondition"
    }
}
Start-Transcript -LiteralPath (Join-Path $scratchRoot "$runId.contract.log") | Out-Null
try {

$managedCompilerFixture = 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$incrementalFixture = 'examples/regression/1740-selfhost-direct-owned-field-analysis.slg'
try {
    & $launcherPath -Verification Incremental -IncrementalFixture $incrementalFixture `
        -ManagedCompiler $managedCompilerFixture -RunId "$runId-unpaired-managed" | Out-Null
    throw 'unpaired managed compiler unexpectedly launched'
}
catch {
    if ($_.Exception.Message -notlike '*must be supplied together*') { throw }
}
try {
    & $launcherPath -Verification Incremental -IncrementalFixture $incrementalFixture `
        -ManagedCompiler $managedCompilerFixture -ExpectedManagedCompilerSha256 ('0' * 64) `
        -RunId "$runId-managed-hash-mismatch" | Out-Null
    throw 'managed compiler hash mismatch unexpectedly launched'
}
catch {
    if ($_.Exception.Message -notlike '*ManagedCompiler hash mismatch*') { throw }
}

$binaryCompilerFixture = Join-Path $RepositoryRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$binaryCompilerHash = (Get-FileHash -LiteralPath $binaryCompilerFixture -Algorithm SHA256).Hash
$binaryOutput = Join-Path $scratchRoot "$runId-binary-checksum-output"
try {
    & $launcherPath -Verification BinaryChecksum -BinaryChecksumCompiler $binaryCompilerFixture `
        -RunId "$runId-binary-unpaired" -ValidateInputsOnly | Out-Null
    throw 'unpaired BinaryChecksum inputs unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*requires compiler, expected SHA-256, and output directory together*') { throw }
}
try {
    & $launcherPath -Verification BinaryChecksum -BinaryChecksumCompiler $binaryCompilerFixture `
        -BinaryChecksumExpectedCompilerSha256 ('0' * 64) -BinaryChecksumOutputDirectory $binaryOutput `
        -RunId "$runId-binary-hash" -ValidateInputsOnly | Out-Null
    throw 'BinaryChecksum compiler hash mismatch unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*BinaryChecksum compiler hash mismatch*') { throw }
}
try {
    & $launcherPath -Verification BinaryChecksum -BinaryChecksumCompiler $binaryCompilerFixture `
        -BinaryChecksumExpectedCompilerSha256 $binaryCompilerHash `
        -BinaryChecksumOutputDirectory (Join-Path $RepositoryRoot "$runId-outside") `
        -RunId "$runId-binary-outside" -ValidateInputsOnly | Out-Null
    throw 'BinaryChecksum output outside artifacts unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*must be under*') { throw }
}
$occupiedBinaryOutput = Join-Path $scratchRoot "$runId-binary-occupied"
New-Item -ItemType Directory -Path $occupiedBinaryOutput -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $occupiedBinaryOutput 'occupied.txt') -Force | Out-Null
try {
    & $launcherPath -Verification BinaryChecksum -BinaryChecksumCompiler $binaryCompilerFixture `
        -BinaryChecksumExpectedCompilerSha256 $binaryCompilerHash -BinaryChecksumOutputDirectory $occupiedBinaryOutput `
        -RunId "$runId-binary-occupied" -ValidateInputsOnly | Out-Null
    throw 'occupied BinaryChecksum output unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*must be a new or empty directory*') { throw }
}
try {
    & $launcherPath -Verification Probe -BinaryChecksumCompiler $binaryCompilerFixture `
        -BinaryChecksumExpectedCompilerSha256 $binaryCompilerHash -BinaryChecksumOutputDirectory $binaryOutput `
        -RunId "$runId-binary-wrong-route" | Out-Null
    throw 'BinaryChecksum inputs on another route unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*required only for Verification BinaryChecksum*') { throw }
}
$binaryValidation = & $launcherPath -Verification BinaryChecksum -BinaryChecksumCompiler $binaryCompilerFixture `
    -BinaryChecksumExpectedCompilerSha256 $binaryCompilerHash -BinaryChecksumOutputDirectory $binaryOutput `
    -Distribution Ubuntu -RunId "$runId-binary-valid" -ValidateInputsOnly | ConvertFrom-Json
if (-not $binaryValidation.validated -or $binaryValidation.verification -cne 'BinaryChecksum' -or
    $binaryValidation.compilerSha256 -cne $binaryCompilerHash -or
    $binaryValidation.outputDirectory -cne $binaryOutput -or $binaryValidation.wslDistribution -cne 'Ubuntu') {
    throw 'BinaryChecksum validate-inputs-only result did not preserve exact inputs'
}
$contractChecks.Add('binary-checksum-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS BinaryChecksum route and validate-inputs-only controls; compiler launches 0.'

$additionalMoveCompiler = Join-Path $RepositoryRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$additionalMoveCompilerHash = (Get-FileHash -LiteralPath $additionalMoveCompiler -Algorithm SHA256).Hash
$additionalMoveOutput = Join-Path $scratchRoot "$runId-additional-move-output"
$additionalMoveValidation = & $launcherPath -Verification AdditionalMoveOwnership `
    -AdditionalMoveOwnershipCompiler $additionalMoveCompiler `
    -AdditionalMoveOwnershipExpectedCompilerSha256 $additionalMoveCompilerHash `
    -AdditionalMoveOwnershipOutputDirectory $additionalMoveOutput -ValidateInputsOnly | ConvertFrom-Json
if ($additionalMoveValidation.verification -cne 'AdditionalMoveOwnership' -or
    $additionalMoveValidation.compiler -cne $additionalMoveCompiler -or
    $additionalMoveValidation.compilerSha256 -cne $additionalMoveCompilerHash -or
    $additionalMoveValidation.outputDirectory -cne $additionalMoveOutput -or
    -not $additionalMoveValidation.validated) {
    throw 'AdditionalMoveOwnership validate-inputs-only result did not preserve exact immutable inputs'
}
$additionalMoveProgressResult = Join-Path $scratchRoot "$runId-additional-move-progress.result.json"
$additionalMoveProgressLog = Join-Path $scratchRoot "$runId-additional-move-progress.log"
'[C92 additional move ownership] PASS 6/6 compiler=fixture result=fixture' |
    Set-Content -LiteralPath $additionalMoveProgressLog -Encoding utf8
[ordered]@{
    schemaVersion = 1; runId = "$runId-additional-move-progress"; verification = 'AdditionalMoveOwnership'
    supervisorPid = $PID; logPath = $additionalMoveProgressLog
    additionalMoveOwnershipCompiler = $additionalMoveCompiler
    additionalMoveOwnershipExpectedCompilerSha256 = $additionalMoveCompilerHash
    additionalMoveOwnershipOutputDirectory = $additionalMoveOutput
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$additionalMoveProgressResult.launch.json" -Encoding utf8
$additionalMoveProgress = & $progressReaderPath -CompletionRecordPath $additionalMoveProgressResult | ConvertFrom-Json
if ($additionalMoveProgress.verification -cne 'AdditionalMoveOwnership' -or
    $additionalMoveProgress.completed -ne 6 -or $additionalMoveProgress.total -ne 6 -or
    $additionalMoveProgress.additionalMoveOwnershipCompiler -cne $additionalMoveCompiler -or
    $additionalMoveProgress.additionalMoveOwnershipExpectedCompilerSha256 -cne $additionalMoveCompilerHash -or
    $additionalMoveProgress.additionalMoveOwnershipOutputDirectory -cne $additionalMoveOutput) {
    throw 'AdditionalMoveOwnership progress did not preserve exact route inputs and 6/6 topology'
}
foreach ($invalidAdditionalMove in @('partial-tuple', 'wrong-hash')) {
    $rejected = $false
    try {
        if ($invalidAdditionalMove -eq 'partial-tuple') {
            & $launcherPath -Verification AdditionalMoveOwnership `
                -AdditionalMoveOwnershipCompiler $additionalMoveCompiler -ValidateInputsOnly | Out-Null
        } else {
            & $launcherPath -Verification AdditionalMoveOwnership `
                -AdditionalMoveOwnershipCompiler $additionalMoveCompiler `
                -AdditionalMoveOwnershipExpectedCompilerSha256 ('0' * 64) `
                -AdditionalMoveOwnershipOutputDirectory $additionalMoveOutput -ValidateInputsOnly | Out-Null
        }
    } catch { $rejected = $true }
    if (-not $rejected) { throw "AdditionalMoveOwnership accepted invalid inputs: $invalidAdditionalMove" }
}
$contractChecks.Add('additional-move-ownership-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS AdditionalMoveOwnership route and immutable input controls; compiler launches 0.'

$finalCandidateFixture = Join-Path $RepositoryRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$finalCandidateHash = (Get-FileHash -LiteralPath $finalCandidateFixture -Algorithm SHA256).Hash
$c341GenerationFixture = Join-Path $PSScriptRoot 'contracts/c341-final-selfhost-candidate.json'
$c341SeedFixture = Join-Path $RepositoryRoot 'artifacts/incremental-selfhost/selfhost-slg-seed.exe'
$c341FinalOutput = Join-Path $scratchRoot "$runId-c341-final-output"
$c394FinalOutput = Join-Path $scratchRoot "$runId-c394-final-output"

foreach ($invalidFinalRoute in @('c341-partial', 'c341-hash', 'c394-partial', 'c394-hash', 'c394-outside', 'cross-mode')) {
    $rejected = $false
    try {
        switch ($invalidFinalRoute) {
            'c341-partial' {
                & $launcherPath -Verification C341FinalSelfhost -C341FinalCandidateCompiler $finalCandidateFixture `
                    -C341FinalExpectedCompilerSha256 $finalCandidateHash -C341FinalOutputDirectory $c341FinalOutput `
                    -C341FinalGenerationRecord $c341GenerationFixture -ValidateInputsOnly | Out-Null
            }
            'c341-hash' {
                & $launcherPath -Verification C341FinalSelfhost -C341FinalCandidateCompiler $finalCandidateFixture `
                    -C341FinalExpectedCompilerSha256 ('0' * 64) -C341FinalOutputDirectory $c341FinalOutput `
                    -C341FinalGenerationRecord $c341GenerationFixture -C341FinalSeedCompiler $c341SeedFixture -ValidateInputsOnly | Out-Null
            }
            'c394-partial' {
                & $launcherPath -Verification C394FinalCandidate -C394FinalCandidateCompiler $finalCandidateFixture `
                    -C394FinalExpectedCompilerSha256 $finalCandidateHash -ValidateInputsOnly | Out-Null
            }
            'c394-hash' {
                & $launcherPath -Verification C394FinalCandidate -C394FinalCandidateCompiler $finalCandidateFixture `
                    -C394FinalExpectedCompilerSha256 ('0' * 64) -C394FinalOutputDirectory $c394FinalOutput -ValidateInputsOnly | Out-Null
            }
            'c394-outside' {
                & $launcherPath -Verification C394FinalCandidate -C394FinalCandidateCompiler $finalCandidateFixture `
                    -C394FinalExpectedCompilerSha256 $finalCandidateHash -C394FinalOutputDirectory (Join-Path $RepositoryRoot "$runId-outside") -ValidateInputsOnly | Out-Null
            }
            'cross-mode' {
                & $launcherPath -Verification Probe -C394FinalCandidateCompiler $finalCandidateFixture `
                    -C394FinalExpectedCompilerSha256 $finalCandidateHash -C394FinalOutputDirectory $c394FinalOutput | Out-Null
            }
        }
    } catch { $rejected = $true }
    if (-not $rejected) { throw "Detached final-candidate route accepted invalid inputs: $invalidFinalRoute" }
}

$c341FinalValidation = & $launcherPath -Verification C341FinalSelfhost `
    -C341FinalCandidateCompiler $finalCandidateFixture -C341FinalExpectedCompilerSha256 $finalCandidateHash `
    -C341FinalOutputDirectory $c341FinalOutput -C341FinalGenerationRecord $c341GenerationFixture `
    -C341FinalSeedCompiler $c341SeedFixture -ValidateInputsOnly | Select-Object -Last 1 | ConvertFrom-Json
if (-not $c341FinalValidation.validated -or $c341FinalValidation.verification -cne 'C341FinalSelfhost' -or
    $c341FinalValidation.compilerSha256 -cne $finalCandidateHash -or
    $c341FinalValidation.generationRecordSha256 -cne (Get-FileHash -LiteralPath $c341GenerationFixture -Algorithm SHA256).Hash -or
    $c341FinalValidation.seedCompilerSha256 -cne (Get-FileHash -LiteralPath $c341SeedFixture -Algorithm SHA256).Hash -or
    $c341FinalValidation.outputDirectory -cne $c341FinalOutput -or
    $c341FinalValidation.resultPath -cne (Join-Path $c341FinalOutput 'result.json')) {
    throw 'C341FinalSelfhost preflight did not preserve exact paired inputs and hashes'
}
$c394FinalValidation = & $launcherPath -Verification C394FinalCandidate `
    -C394FinalCandidateCompiler $finalCandidateFixture -C394FinalExpectedCompilerSha256 $finalCandidateHash `
    -C394FinalOutputDirectory $c394FinalOutput -ValidateInputsOnly | Select-Object -Last 1 | ConvertFrom-Json
if (-not $c394FinalValidation.validated -or $c394FinalValidation.verification -cne 'C394FinalCandidate' -or
    $c394FinalValidation.compilerSha256 -cne $finalCandidateHash -or
    $c394FinalValidation.outputDirectory -cne $c394FinalOutput -or
    $c394FinalValidation.resultPath -cne (Join-Path $c394FinalOutput 'result.json')) {
    throw 'C394FinalCandidate preflight did not preserve exact paired inputs and hashes'
}
$contractChecks.Add('c341-final-selfhost-route-and-input-controls')
$contractChecks.Add('c394-final-candidate-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS C341/C394 final routes, exact immutable inputs, and 6 negative controls; candidate launches 0.'

$genericCandidateFixture = Join-Path $RepositoryRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$genericCandidateHash = (Get-FileHash -LiteralPath $genericCandidateFixture -Algorithm SHA256).Hash
try {
    & $launcherPath -Verification GenericTypeContexts `
        -GenericTypeContextsCandidateCompiler $genericCandidateFixture `
        -RunId "$runId-generic-unpaired" -ValidateInputsOnly | Out-Null
    throw 'unpaired GenericTypeContexts inputs unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*requires candidate compiler and expected SHA-256 together*') { throw }
}
try {
    & $launcherPath -Verification GenericTypeContexts `
        -GenericTypeContextsCandidateCompiler $genericCandidateFixture `
        -GenericTypeContextsExpectedCompilerSha256 ('0' * 64) `
        -RunId "$runId-generic-hash" -ValidateInputsOnly | Out-Null
    throw 'GenericTypeContexts candidate compiler hash mismatch unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*candidate compiler hash mismatch*') { throw }
}
try {
    & $launcherPath -Verification GenericTypeContexts `
        -GenericTypeContextsCandidateCompiler (Join-Path (Split-Path -Parent $RepositoryRoot) 'outside-generic-candidate.exe') `
        -GenericTypeContextsExpectedCompilerSha256 $genericCandidateHash `
        -RunId "$runId-generic-outside" -ValidateInputsOnly | Out-Null
    throw 'GenericTypeContexts candidate compiler outside the repository unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*must be under*') { throw }
}
try {
    & $launcherPath -Verification Probe `
        -GenericTypeContextsCandidateCompiler $genericCandidateFixture `
        -GenericTypeContextsExpectedCompilerSha256 $genericCandidateHash `
        -RunId "$runId-generic-wrong-route" | Out-Null
    throw 'GenericTypeContexts inputs on another route unexpectedly validated'
}
catch {
    if ($_.Exception.Message -notlike '*required only for Verification GenericTypeContexts*') { throw }
}
$genericValidation = & $launcherPath -Verification GenericTypeContexts `
    -GenericTypeContextsCandidateCompiler $genericCandidateFixture `
    -GenericTypeContextsExpectedCompilerSha256 $genericCandidateHash `
    -RunId "$runId-generic-valid" -ValidateInputsOnly | ConvertFrom-Json
if (-not $genericValidation.validated -or $genericValidation.verification -cne 'GenericTypeContexts' -or
    $genericValidation.candidateCompiler -cne $genericCandidateFixture -or
    $genericValidation.compilerSha256 -cne $genericCandidateHash -or
    (@($genericValidation.fixedFlags) -join '|') -cne 'TypeDelimiters|ReadonlyTextSlice|ExecuteFixtures') {
    throw 'GenericTypeContexts validate-inputs-only result did not preserve exact candidate provenance and fixed flags'
}
$contractChecks.Add('generic-type-contexts-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS GenericTypeContexts route and validate-inputs-only controls; compiler launches 0.'

$storageCandidateFixture = Join-Path $RepositoryRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$storageCandidateHash = (Get-FileHash -LiteralPath $storageCandidateFixture -Algorithm SHA256).Hash
try {
    & $launcherPath -Verification SelfhostDeferredTextStorage `
        -SelfhostDeferredTextStorageCandidateCompiler $storageCandidateFixture `
        -RunId "$runId-deferred-unpaired" -ValidateInputsOnly | Out-Null
    throw 'unpaired SelfhostDeferredTextStorage inputs unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*requires candidate compiler and expected SHA-256 together*') { throw } }
try {
    & $launcherPath -Verification SelfhostDeferredTextStorage `
        -SelfhostDeferredTextStorageCandidateCompiler $storageCandidateFixture `
        -SelfhostDeferredTextStorageExpectedCompilerSha256 ('0' * 64) `
        -RunId "$runId-deferred-hash" -ValidateInputsOnly | Out-Null
    throw 'SelfhostDeferredTextStorage hash mismatch unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*candidate compiler hash mismatch*') { throw } }
try {
    & $launcherPath -Verification Probe `
        -SelfhostDeferredTextStorageCandidateCompiler $storageCandidateFixture `
        -SelfhostDeferredTextStorageExpectedCompilerSha256 $storageCandidateHash `
        -RunId "$runId-deferred-wrong-route" | Out-Null
    throw 'SelfhostDeferredTextStorage inputs on another route unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*required only for Verification SelfhostDeferredTextStorage*') { throw } }
$deferredValidation = & $launcherPath -Verification SelfhostDeferredTextStorage `
    -SelfhostDeferredTextStorageCandidateCompiler $storageCandidateFixture `
    -SelfhostDeferredTextStorageExpectedCompilerSha256 $storageCandidateHash `
    -RunId "$runId-deferred-valid" -ValidateInputsOnly | ConvertFrom-Json
if (-not $deferredValidation.validated -or $deferredValidation.verification -cne 'SelfhostDeferredTextStorage' -or
    $deferredValidation.candidateCompiler -cne $storageCandidateFixture -or
    $deferredValidation.compilerSha256 -cne $storageCandidateHash -or -not $deferredValidation.requireCandidateGate) {
    throw 'SelfhostDeferredTextStorage validate-inputs-only result did not preserve exact candidate provenance'
}
$contractChecks.Add('selfhost-deferred-text-storage-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS SelfhostDeferredTextStorage route and input controls; compiler launches 0.'

$c424Output = Join-Path $scratchRoot "$runId-c424-output"
try {
    & $launcherPath -Verification SelfhostC424NestedWholeOwner `
        -SelfhostC424NestedWholeOwnerCandidateCompiler $storageCandidateFixture `
        -RunId "$runId-c424-unpaired" -ValidateInputsOnly | Out-Null
    throw 'unpaired SelfhostC424NestedWholeOwner inputs unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*requires candidate compiler, expected SHA-256, and output directory together*') { throw } }
try {
    & $launcherPath -Verification SelfhostC424NestedWholeOwner `
        -SelfhostC424NestedWholeOwnerCandidateCompiler $storageCandidateFixture `
        -SelfhostC424NestedWholeOwnerExpectedCompilerSha256 ('0' * 64) `
        -SelfhostC424NestedWholeOwnerOutputDirectory $c424Output `
        -RunId "$runId-c424-hash" -ValidateInputsOnly | Out-Null
    throw 'SelfhostC424NestedWholeOwner hash mismatch unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*candidate compiler hash mismatch*') { throw } }
try {
    & $launcherPath -Verification SelfhostC424NestedWholeOwner `
        -SelfhostC424NestedWholeOwnerCandidateCompiler $storageCandidateFixture `
        -SelfhostC424NestedWholeOwnerExpectedCompilerSha256 $storageCandidateHash `
        -SelfhostC424NestedWholeOwnerOutputDirectory (Join-Path $RepositoryRoot "$runId-c424-outside") `
        -RunId "$runId-c424-outside" -ValidateInputsOnly | Out-Null
    throw 'SelfhostC424NestedWholeOwner output outside artifacts unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*must be under*') { throw } }
$occupiedC424Output = Join-Path $scratchRoot "$runId-c424-occupied"
New-Item -ItemType Directory -Path $occupiedC424Output -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $occupiedC424Output 'occupied.txt') -Force | Out-Null
try {
    & $launcherPath -Verification SelfhostC424NestedWholeOwner `
        -SelfhostC424NestedWholeOwnerCandidateCompiler $storageCandidateFixture `
        -SelfhostC424NestedWholeOwnerExpectedCompilerSha256 $storageCandidateHash `
        -SelfhostC424NestedWholeOwnerOutputDirectory $occupiedC424Output `
        -RunId "$runId-c424-occupied" -ValidateInputsOnly | Out-Null
    throw 'occupied SelfhostC424NestedWholeOwner output unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*must be a new or empty directory*') { throw } }
try {
    & $launcherPath -Verification Probe `
        -SelfhostC424NestedWholeOwnerCandidateCompiler $storageCandidateFixture `
        -SelfhostC424NestedWholeOwnerExpectedCompilerSha256 $storageCandidateHash `
        -SelfhostC424NestedWholeOwnerOutputDirectory $c424Output `
        -RunId "$runId-c424-wrong-route" | Out-Null
    throw 'SelfhostC424NestedWholeOwner inputs on another route unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*required only for Verification SelfhostC424NestedWholeOwner*') { throw } }
$c424Validation = & $launcherPath -Verification SelfhostC424NestedWholeOwner `
    -SelfhostC424NestedWholeOwnerCandidateCompiler $storageCandidateFixture `
    -SelfhostC424NestedWholeOwnerExpectedCompilerSha256 $storageCandidateHash `
    -SelfhostC424NestedWholeOwnerOutputDirectory $c424Output `
    -RunId "$runId-c424-valid" -ValidateInputsOnly | ConvertFrom-Json
if (-not $c424Validation.validated -or $c424Validation.verification -cne 'SelfhostC424NestedWholeOwner' -or
    $c424Validation.candidateCompiler -cne $storageCandidateFixture -or $c424Validation.compilerSha256 -cne $storageCandidateHash -or
    $c424Validation.outputDirectory -cne $c424Output) {
    throw 'SelfhostC424NestedWholeOwner validate-inputs-only result did not preserve exact candidate provenance and output'
}
$contractChecks.Add('selfhost-c424-nested-whole-owner-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS SelfhostC424NestedWholeOwner route and input controls; compiler launches 0.'

try {
    & $launcherPath -Verification LinuxOwnershipStorage -LinuxOwnershipStorageCompiler $storageCandidateFixture `
        -RunId "$runId-linux-storage-unpaired" -ValidateInputsOnly | Out-Null
    throw 'unpaired LinuxOwnershipStorage inputs unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*requires compiler and expected SHA-256 together*') { throw } }
try {
    & $launcherPath -Verification LinuxOwnershipStorage -LinuxOwnershipStorageCompiler $storageCandidateFixture `
        -LinuxOwnershipStorageExpectedCompilerSha256 ('0' * 64) `
        -RunId "$runId-linux-storage-hash" -ValidateInputsOnly | Out-Null
    throw 'LinuxOwnershipStorage hash mismatch unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*compiler hash mismatch*') { throw } }
try {
    & $launcherPath -Verification LinuxOwnershipStorage `
        -LinuxOwnershipStorageCompiler (Join-Path $RepositoryRoot 'scripts/verify-linux-ownership-storage-focused.ps1') `
        -LinuxOwnershipStorageExpectedCompilerSha256 $storageCandidateHash `
        -RunId "$runId-linux-storage-noncanonical" -ValidateInputsOnly | Out-Null
    throw 'LinuxOwnershipStorage noncanonical compiler unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*must equal the verifier*') { throw } }
try {
    & $launcherPath -Verification Probe -LinuxOwnershipStorageCompiler $storageCandidateFixture `
        -LinuxOwnershipStorageExpectedCompilerSha256 $storageCandidateHash `
        -RunId "$runId-linux-storage-wrong-route" | Out-Null
    throw 'LinuxOwnershipStorage inputs on another route unexpectedly validated'
} catch { if ($_.Exception.Message -notlike '*required only for Verification LinuxOwnershipStorage*') { throw } }
$linuxStorageValidation = & $launcherPath -Verification LinuxOwnershipStorage `
    -LinuxOwnershipStorageCompiler $storageCandidateFixture `
    -LinuxOwnershipStorageExpectedCompilerSha256 $storageCandidateHash `
    -RunId "$runId-linux-storage-valid" -ValidateInputsOnly | ConvertFrom-Json
if (-not $linuxStorageValidation.validated -or $linuxStorageValidation.verification -cne 'LinuxOwnershipStorage' -or
    $linuxStorageValidation.compiler -cne $storageCandidateFixture -or $linuxStorageValidation.compilerSha256 -cne $storageCandidateHash -or
    $linuxStorageValidation.target -cne 'linux-x64') {
    throw 'LinuxOwnershipStorage validate-inputs-only result did not preserve canonical compiler provenance'
}
$contractChecks.Add('linux-ownership-storage-route-and-input-controls')
Write-Host '[detached selfhost verification] PASS LinuxOwnershipStorage route and input controls; compiler launches 0.'

$outsideArtifactPath = Join-Path $RepositoryRoot "$runId.outside.log"
try {
    & $launcherPath -Verification Probe -RunId "$runId-path" -LogPath $outsideArtifactPath | Out-Null
    throw "path outside artifacts unexpectedly launched"
}
catch {
    if ($_.Exception.Message -notlike "*must be under*") { throw }
}
$aliasedPath = Join-Path $scratchRoot "$runId-aliased.json"
try {
    & $launcherPath `
        -Verification Probe `
        -RunId "$runId-aliased" `
        -LogPath $aliasedPath `
        -CompletionRecordPath $aliasedPath | Out-Null
    throw "aliased log and completion paths unexpectedly launched"
}
catch {
    if ($_.Exception.Message -notlike "*must be distinct*") { throw }
}

$invalidRunId = "$runId-invalid-stage3-seed"
$invalidCompletionRecordPath = Join-Path $scratchRoot "$invalidRunId.result.json"
try {
    & $launcherPath `
        -Verification Stage3 `
        -SeedMode Stage2Bridge `
        -RunId $invalidRunId `
        -LogPath (Join-Path $scratchRoot "$invalidRunId.log") `
        -CompletionRecordPath $invalidCompletionRecordPath | Out-Null
    throw "invalid Stage3 seed mode unexpectedly launched"
}
catch {
    if ($_.Exception.Message -notlike "*does not accept SeedMode Stage2Bridge*") { throw }
}
if (Test-Path -LiteralPath "$invalidCompletionRecordPath.launch.json") {
    throw "invalid Stage3 seed mode created launch evidence"
}

$interruptedRunId = "$runId-interrupted"
$interruptedLogPath = Join-Path $scratchRoot "$interruptedRunId.log"
$interruptedCompletionRecordPath = Join-Path $scratchRoot "$interruptedRunId.result.json"
New-Item -ItemType File -Path $interruptedLogPath -Force | Out-Null
([ordered]@{
    schemaVersion = 1
    runId = $interruptedRunId
    verification = "Stage2"
    executionMode = "detached-supervisor"
    supervisorPid = 2147483647
    observerPid = $PID
    survivesObserverDisconnect = $true
    logPath = $interruptedLogPath
    completionRecordPath = $interruptedCompletionRecordPath
    launchedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
} | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath "$interruptedCompletionRecordPath.launch.json" -Encoding utf8
$interruptedProgress = & $progressReaderPath -CompletionRecordPath $interruptedCompletionRecordPath | ConvertFrom-Json
if ($interruptedProgress.status -cne "interrupted-without-result") {
    throw "missing completion record was not classified as an interruption"
}

foreach ($linuxProgressCase in @(
    [ordered]@{ Verification = "Stage2Linux"; Stage = "linux-stage2"; Current = 3; Completed = 2; Total = 6; Percent = 33.3 },
    [ordered]@{ Verification = "Stage3Linux"; Stage = "linux-stage3"; Current = 2; Completed = 1; Total = 3; Percent = 33.3 },
    [ordered]@{ Verification = "C341Focused"; Stage = "c341"; Current = 8; Completed = 7; Total = 20; Percent = 35.0 },
    [ordered]@{
        Verification = "BinaryChecksum"; Current = 26; Completed = 26; Total = 27; Percent = 96.3
        LogLines = @('[binary/checksum positive 24/24] PASS positive', '[binary/checksum negative 2/3] PASS negative')
    },
    [ordered]@{
        Verification = "GenericTypeContexts"; Current = 62; Completed = 62; Total = 98; Percent = 63.3
        LogLines = @(
            'Generic type contexts: extracted production methods + current DLL type parser and place validator PASS 21/21.',
            'Type delimiters: selected production parser branches + existing real type table PASS 41/41; whole compiler integration pending.'
        )
    },
    [ordered]@{
        Verification = "SelfhostDeferredTextStorage"; Current = 31; Completed = 31; Total = 48; Percent = 64.6
        LogLines = @('Selfhost deferred storage production guard PASS 31/31: P:\scratch\result.json')
    },
    [ordered]@{
        Verification = "SelfhostC424NestedWholeOwner"; Current = 1; Completed = 1; Total = 1; Percent = 100.0
        LogLines = @('[C424 selfhost nested whole owner] PASS 1/1 compiler=ABC result=P:\scratch\result.json')
    },
    [ordered]@{
        Verification = "LinuxOwnershipStorage"; Current = 2; Completed = 2; Total = 2; Percent = 100.0
        LogLines = @('[Linux ownership/storage focused] passed 2/2; P:\scratch\result.json')
    }
)) {
    $linuxRunId = "$runId-$($linuxProgressCase.Verification.ToLowerInvariant())"
    $linuxLogPath = Join-Path $scratchRoot "$linuxRunId.log"
    $linuxCompletionRecordPath = Join-Path $scratchRoot "$linuxRunId.result.json"
    if ($linuxProgressCase.Contains('LogLines')) {
        @($linuxProgressCase.LogLines) | Set-Content -LiteralPath $linuxLogPath -Encoding utf8
    } else {
        "[$($linuxProgressCase.Stage) $($linuxProgressCase.Current)/$($linuxProgressCase.Total)] active" |
            Set-Content -LiteralPath $linuxLogPath -Encoding utf8
    }
    ([ordered]@{
        schemaVersion = 1
        runId = $linuxRunId
        verification = $linuxProgressCase.Verification
        executionMode = "detached-supervisor"
        supervisorPid = 2147483647
        observerPid = $PID
        survivesObserverDisconnect = $true
        logPath = $linuxLogPath
        completionRecordPath = $linuxCompletionRecordPath
        launchedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    } | ConvertTo-Json -Depth 5) |
        Set-Content -LiteralPath "$linuxCompletionRecordPath.launch.json" -Encoding utf8
    $linuxProgress = & $progressReaderPath -CompletionRecordPath $linuxCompletionRecordPath | ConvertFrom-Json
    if ($linuxProgress.status -cne "interrupted-without-result" -or
        $linuxProgress.completed -ne $linuxProgressCase.Completed -or
        $linuxProgress.total -ne $linuxProgressCase.Total -or
        $linuxProgress.percent -ne $linuxProgressCase.Percent) {
        throw "$($linuxProgressCase.Verification) progress mapping is incorrect"
    }
}

Write-Host "[detached selfhost verification] PASS Linux Stage2/Stage3 progress mappings."
$contractChecks.Add('legacy-path-and-progress-contracts')

$observer = Start-Process `
    -FilePath (Get-Process -Id $PID).Path `
    -ArgumentList @(
        "-NoProfile",
        "-File", ('"' + $launcherPath + '"'),
        "-Verification", "Probe",
        "-RunId", $runId,
        "-LogPath", ('"' + $logPath + '"'),
        "-CompletionRecordPath", ('"' + $completionRecordPath + '"')
    ) `
    -WorkingDirectory $RepositoryRoot `
    -RedirectStandardOutput $observerOutputPath `
    -WindowStyle Hidden `
    -Wait `
    -PassThru
if ($observer.ExitCode -ne 0) {
    throw "detached launcher observer failed with exit code $($observer.ExitCode)"
}

$deadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $completionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $deadline) {
        throw "detached supervisor did not publish its structured completion record"
    }
    Start-Sleep -Milliseconds 100
}

$result = Get-Content -LiteralPath $completionRecordPath -Raw | ConvertFrom-Json
$resultJson = Get-Content -LiteralPath $completionRecordPath -Raw
if (-not ($resultJson | Test-Json -SchemaFile $resultSchemaPath)) { throw "failed result does not match its schema" }
if ($result.executionMode -cne "detached-supervisor") { throw "unexpected execution mode" }
if ($result.exitCode -ne 7) { throw "probe exit code was not preserved" }
if ($result.status -cne "failed") { throw "probe status was not preserved" }
if (@($result.failureIds) -notcontains "E999") { throw "diagnostic failure id E999 was not preserved" }
if (@($result.failureIds) -notcontains "S015") { throw "self-host diagnostic failure id S015 was not preserved" }
if (@($result.failureIds) -notcontains "9999-detached-supervisor-probe") { throw "fixture failure id was not preserved" }
if (@($result.failureIds) -notcontains "80-unicode-code-points") { throw "two-digit fixture failure id was not preserved" }
if (@($result.failureIds) -notcontains "1-short-fixture-id") { throw "one-digit fixture failure id was not preserved" }
if (@($result.failureIds) -contains "1411-borrowed-receiver-error-reuse") { throw "passing fixture name containing error was misclassified as a failure identifier" }
if (@($result.failureIds) -contains "2-error-name-negative-control") { throw "passing short fixture name was misclassified as a failure identifier" }
if (@($result.failureIds).Count -ne 5) { throw "failed probe reported unexpected failure identifiers" }
if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { throw "durable log is missing" }
if ($observer.Id -eq $result.supervisorPid) { throw "observer and supervisor must be distinct processes" }
$failedProgress = & $progressReaderPath -CompletionRecordPath $completionRecordPath | ConvertFrom-Json
if ($failedProgress.status -cne "failed" -or $failedProgress.exitCode -ne 7) {
    throw "failed detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS observer exited independently; exit code 7 and 5/5 failure IDs preserved."
$contractChecks.Add('legacy-failure-identities-and-detachment')

$passRunId = "$runId-pass"
$passLogPath = Join-Path $scratchRoot "$passRunId.log"
$passCompletionRecordPath = Join-Path $scratchRoot "$passRunId.result.json"
& $launcherPath `
    -Verification Probe `
    -ProbeOutcome Pass `
    -RunId $passRunId `
    -LogPath $passLogPath `
    -CompletionRecordPath $passCompletionRecordPath | Out-Null
$passDeadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $passCompletionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $passDeadline) {
        throw "successful detached probe did not publish its structured completion record"
    }
    Start-Sleep -Milliseconds 100
}
$passResult = Get-Content -LiteralPath $passCompletionRecordPath -Raw | ConvertFrom-Json
$passResultJson = Get-Content -LiteralPath $passCompletionRecordPath -Raw
if (-not ($passResultJson | Test-Json -SchemaFile $resultSchemaPath)) { throw "successful result does not match its schema" }
foreach ($kind in @('Incremental', 'C341Focused', 'ExpressionBatch', 'PortableMemoryIo', 'TypedBlockMutableBorrow', 'BinaryChecksum', 'GzipSelfhost', 'AdditionalMoveOwnership', 'GenericTypeContexts', 'SelfhostDeferredTextStorage', 'SelfhostC424NestedWholeOwner', 'LinuxOwnershipStorage', 'ManagedHost')) {
    $incrementalSuccess = $passResultJson | ConvertFrom-Json
    $incrementalSuccess.verification = $kind
    if ($kind -eq 'AdditionalMoveOwnership') {
        $incrementalSuccess.additionalMoveOwnershipCompiler = $additionalMoveCompiler
        $incrementalSuccess.additionalMoveOwnershipExpectedCompilerSha256 = $additionalMoveCompilerHash
        $incrementalSuccess.additionalMoveOwnershipOutputDirectory = $additionalMoveOutput
    }
    if (-not (($incrementalSuccess | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath)) {
        throw "$kind result does not match its schema"
    }
}
$unknownVerification = $passResultJson | ConvertFrom-Json
$unknownVerification.verification = "Unknown"
if (($unknownVerification | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted an unknown verification kind"
}
if ($passResult.exitCode -ne 0 -or $passResult.status -cne "passed") {
    throw "successful detached probe outcome was not preserved"
}
if (@($passResult.failureIds).Count -ne 0) {
    throw "successful detached probe reported failure identifiers"
}
if (@($passResult.orphanProcessIds).Count -ne 0) {
    throw "successful detached probe reported orphan processes"
}
$invalidSuccess = $passResultJson | ConvertFrom-Json
$invalidSuccess.failureIds = @("E1")
if (($invalidSuccess | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted a failure identifier on success"
}
$invalidSuccess = $passResultJson | ConvertFrom-Json
$invalidSuccess.orphanProcessIds = @(4242)
if (($invalidSuccess | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted an orphan process on success"
}
$invalidFailure = $resultJson | ConvertFrom-Json
$invalidFailure.exitCode = 0
if (($invalidFailure | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw "result schema accepted a zero exit code on failure"
}
$passedProgress = & $progressReaderPath -CompletionRecordPath $passCompletionRecordPath | ConvertFrom-Json
if ($passedProgress.status -cne "passed" -or $passedProgress.completed -ne 1 -or $passedProgress.total -ne 1) {
    throw "successful detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS successful termination, Incremental schema coverage, exit code 0, 0 failure IDs, and 0 orphans."
$contractChecks.Add('legacy-success-and-schema-controls')

$spacedRoot = Join-Path $scratchRoot "$runId path with spaces"
$spacedLogPath = Join-Path $spacedRoot "probe output.log"
$spacedCompletionRecordPath = Join-Path $spacedRoot "probe result.json"
& $launcherPath `
    -Verification Probe `
    -ProbeOutcome Pass `
    -RunId "$runId-spaced" `
    -LogPath $spacedLogPath `
    -CompletionRecordPath $spacedCompletionRecordPath | Out-Null
$spacedDeadline = [DateTimeOffset]::UtcNow.AddSeconds(20)
while (-not (Test-Path -LiteralPath $spacedCompletionRecordPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $spacedDeadline) {
        throw "detached probe with spaced paths did not publish its structured completion record"
    }
    Start-Sleep -Milliseconds 100
}
$spacedResult = Get-Content -LiteralPath $spacedCompletionRecordPath -Raw | ConvertFrom-Json
if ($spacedResult.exitCode -ne 0 -or $spacedResult.logPath -cne $spacedLogPath) {
    throw "detached probe did not preserve spaced paths"
}

Write-Host "[detached selfhost verification] PASS paths containing spaces preserve execution and evidence identity."
$contractChecks.Add('legacy-spaced-evidence-paths')

$cancelRunId = "$runId-cancel"
$cancelLogPath = Join-Path $scratchRoot "$cancelRunId.log"
$cancelCompletionRecordPath = Join-Path $scratchRoot "$cancelRunId.result.json"
$cancelLaunch = & $launcherPath `
    -Verification Probe `
    -ProbeOutcome CooperativeChild `
    -RunId $cancelRunId `
    -LogPath $cancelLogPath `
    -CompletionRecordPath $cancelCompletionRecordPath | ConvertFrom-Json
$targetDeadline = [DateTimeOffset]::UtcNow.AddSeconds(10)
do {
    $targetPid = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ParentProcessId -eq $cancelLaunch.supervisorPid } |
        Select-Object -First 1 -ExpandProperty ProcessId
    if ($null -ne $targetPid) { break }
    if ([DateTimeOffset]::UtcNow -ge $targetDeadline) {
        throw "cancellation probe did not start its supervised target"
    }
    Start-Sleep -Milliseconds 100
} while ($true)
$cancelResult = & $cancellationRequesterPath `
    -CompletionRecordPath $cancelCompletionRecordPath `
    -TimeoutSeconds 20 | ConvertFrom-Json
$cancelResultJson = Get-Content -LiteralPath $cancelCompletionRecordPath -Raw
if (-not ($cancelResultJson | Test-Json -SchemaFile $resultSchemaPath)) {
    throw "cancelled result does not match its schema"
}
if ($cancelResult.status -cne "cancelled" -or $cancelResult.exitCode -eq 0) {
    throw "cancelled result did not preserve terminal status and non-zero exit code"
}
if (@($cancelResult.failureIds).Count -ne 1 -or $cancelResult.failureIds[0] -cne "CANCELLATION_REQUESTED") {
    throw "cancelled result did not preserve the exact cancellation failure ID"
}
if (@($cancelResult.orphanProcessIds).Count -ne 0) {
    throw "cancelled result reported orphan processes"
}
if ($null -ne (Get-Process -Id ([int]$targetPid) -ErrorAction SilentlyContinue)) {
    throw "cancelled supervised target is still running"
}
$cooperativeChildEvidence = Get-Content -LiteralPath "$cancelCompletionRecordPath.probe-child.json" -Raw | ConvertFrom-Json
if (@($cancelResult.processAudit.observedProcessIds) -notcontains [int]$cooperativeChildEvidence.processId -or
    $null -ne (Get-Process -Id ([int]$cooperativeChildEvidence.processId) -ErrorAction SilentlyContinue) -or
    $cancelResult.targetExitCode -ne 130 -or
    $cancelResult.cancellationAcknowledgement.targetProcessId -ne $cancelResult.targetProcessId) {
    throw 'cooperative cancellation did not preserve exact target/child completion and acknowledgement'
}
$cancelProgress = & $progressReaderPath -CompletionRecordPath $cancelCompletionRecordPath | ConvertFrom-Json
if ($cancelProgress.status -cne "cancelled" -or $cancelProgress.exitCode -eq 0) {
    throw "cancelled detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS cooperative parent/child cancellation preserved cancelled, exit 130, exact acknowledgement, CANCELLATION_REQUESTED, and zero orphans."
$contractChecks.Add('legacy-cancellation')

$nonCooperativeResultPath = Join-Path $scratchRoot "$runId-noncooperative.result.json"
$nonCooperativeLaunch = & $launcherPath -Verification Probe -ProbeOutcome NonCooperativeWait `
    -CancellationTimeoutSeconds 2 -RunId "$runId-noncooperative" `
    -CompletionRecordPath $nonCooperativeResultPath | ConvertFrom-Json
$nonCooperativeRequest = [ordered]@{
    schemaVersion = 1; runId = $nonCooperativeLaunch.runId
    requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O'); requestedByPid = $PID
}
$nonCooperativeRequest | ConvertTo-Json | Set-Content -LiteralPath $nonCooperativeLaunch.cancellationRequestPath -Encoding utf8
$nonCooperativeResultDeadline = [DateTimeOffset]::UtcNow.AddSeconds(15)
while (-not (Test-Path -LiteralPath $nonCooperativeResultPath -PathType Leaf)) {
    if ([DateTimeOffset]::UtcNow -ge $nonCooperativeResultDeadline) { throw 'noncooperative result was not published' }
    Start-Sleep -Milliseconds 100
}
$nonCooperativeResultJson = Get-Content -LiteralPath $nonCooperativeResultPath -Raw
if (-not ($nonCooperativeResultJson | Test-Json -SchemaFile $resultSchemaPath)) {
    throw 'noncooperative failure result does not match its schema'
}
$nonCooperativeResult = $nonCooperativeResultJson | ConvertFrom-Json
$nonCooperativeTargetPid = [int]$nonCooperativeResult.targetProcessId
if ($nonCooperativeResult.status -cne 'failed' -or $nonCooperativeResult.exitCode -eq 0 -or
    $null -ne $nonCooperativeResult.targetExitCode -or
    @($nonCooperativeResult.failureIds).Count -ne 1 -or
    $nonCooperativeResult.failureIds[0] -cne 'COOPERATIVE_CANCELLATION_TIMEOUT' -or
    $null -ne $nonCooperativeResult.cancellationAcknowledgement -or
    @($nonCooperativeResult.orphanProcessIds) -notcontains [int]$nonCooperativeTargetPid) {
    throw 'noncooperative cancellation timeout was killed or misclassified'
}
if ($null -eq (Get-Process -Id ([int]$nonCooperativeTargetPid) -ErrorAction SilentlyContinue)) {
    throw 'noncooperative cancellation timeout unexpectedly killed its target'
}
while ($null -ne (Get-Process -Id ([int]$nonCooperativeTargetPid) -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 100
}
$contractChecks.Add('noncooperative-cancellation-fails-without-kill')
Write-Host '[detached selfhost verification] PASS noncooperative cancellation fails without kill or cancelled status.'

$startupRaceResultPath = Join-Path $scratchRoot "$runId-cancellation-startup-race.result.json"
$startupRaceLaunch = & $launcherPath -Verification Probe -ProbeOutcome CooperativeWait `
    -RunId "$runId-cancellation-startup-race" -CompletionRecordPath $startupRaceResultPath |
    ConvertFrom-Json
$startupRaceResult = & $cancellationRequesterPath -CompletionRecordPath $startupRaceResultPath `
    -TimeoutSeconds 20 | ConvertFrom-Json
if ($startupRaceResult.status -cne 'cancelled' -or $startupRaceResult.exitCode -ne 130 -or
    $startupRaceResult.targetExitCode -ne 130 -or @($startupRaceResult.failureIds).Count -ne 1 -or
    $startupRaceResult.failureIds[0] -cne 'CANCELLATION_REQUESTED' -or
    @($startupRaceResult.orphanProcessIds).Count -ne 0 -or
    $startupRaceResult.cancellationAcknowledgement.targetProcessId -ne $startupRaceResult.targetProcessId) {
    throw 'cooperative cancellation startup race did not preserve exact terminal evidence'
}
foreach ($invalidCancellation in @('zero-target-exit', 'missing-acknowledgement', 'extra-failure-id')) {
    $invalid = $startupRaceResult | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    switch ($invalidCancellation) {
        'zero-target-exit' { $invalid.targetExitCode = 0 }
        'missing-acknowledgement' { $invalid.cancellationAcknowledgement = $null }
        'extra-failure-id' { $invalid.failureIds = @('CANCELLATION_REQUESTED', 'TARGET_PROCESS_FAILED') }
    }
    if (($invalid | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
        throw "result schema accepted invalid cancellation evidence: $invalidCancellation"
    }
}
$contractChecks.Add('cancellation-schema-and-startup-race-controls')
Write-Host '[detached selfhost verification] PASS cancellation startup race and schema negative controls.'

function Wait-ContractResult {
    param([string]$Path)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(25)
    while (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ([DateTimeOffset]::UtcNow -ge $deadline) { throw "No detached result: $Path" }
        Start-Sleep -Milliseconds 100
    }
    $json = [IO.File]::ReadAllText($Path)
    if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw "Invalid detached result: $Path" }
    return $json | ConvertFrom-Json
}

$plainFailureResultPath = Join-Path $scratchRoot "$runId-plain-failure.result.json"
& $launcherPath -Verification Probe -ProbeOutcome PlainFail -RunId "$runId-plain-failure" `
    -CompletionRecordPath $plainFailureResultPath | Out-Null
$plainFailureResult = Wait-ContractResult $plainFailureResultPath
if ($plainFailureResult.status -cne 'failed' -or $plainFailureResult.targetExitCode -ne 9 -or
    @($plainFailureResult.failureIds).Count -ne 1 -or
    $plainFailureResult.failureIds[0] -cne 'TARGET_PROCESS_FAILED' -or
    @($plainFailureResult.orphanProcessIds).Count -ne 0) {
    throw 'Unidentified target failure did not preserve the canonical fallback failure ID'
}
$contractChecks.Add('unidentified-target-failure-id')
Write-Host '[detached selfhost verification] PASS unidentified non-zero target exit preserves TARGET_PROCESS_FAILED.'

foreach ($outcome in @('ChildPass', 'ChildOrphan')) {
    $childResultPath = Join-Path $scratchRoot "$runId-$outcome.result.json"
    try {
        & $launcherPath -Verification Probe -ProbeOutcome $outcome -RunId "$runId-$outcome" `
            -CompletionRecordPath $childResultPath | Out-Null
        $childResult = Wait-ContractResult $childResultPath
        $childEvidence = Get-Content "$childResultPath.probe-child.json" -Raw | ConvertFrom-Json
        if ($childResult.targetExitCode -ne 0 -or -not $childResult.processAudit.completed -or $childResult.processAudit.snapshotCount -lt 2 -or
            @($childResult.processAudit.observedProcessIds) -notcontains $childEvidence.processId -or
            @($childResult.processAudit.observedProcessIds) -notcontains $childResult.targetProcessId) {
            throw "$outcome did not audit the actual target and child identities"
        }
        if ($outcome -eq 'ChildPass') {
            if ($childResult.status -cne 'passed' -or $childResult.exitCode -ne 0 -or
                @($childResult.orphanProcessIds).Count -ne 0 -or
                $null -ne (Get-Process -Id $childEvidence.processId -ErrorAction SilentlyContinue)) {
                throw 'A completed observed child did not produce verified success'
            }
        } else {
            # Windows may also create a console-host descendant for the child.
            # Require the exact live observed set, not an invented one-PID tree.
            $liveObserved = @($childResult.processAudit.observedProcessIds | Where-Object {
                $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue)
            } | Sort-Object)
            if ($childResult.status -cne 'failed' -or $childResult.exitCode -eq 0 -or
                @($childResult.failureIds).Count -ne 1 -or $childResult.failureIds[0] -cne 'ORPHAN_PROCESSES_REMAIN' -or
                @($childResult.orphanProcessIds) -notcontains $childEvidence.processId -or
                (($childResult.orphanProcessIds | Sort-Object) -join ',') -cne ($liveObserved -join ',')) {
                throw 'Live observed child identities did not match the failed audit record'
            }
        }
        $contractChecks.Add("observed-descendant-$outcome")
        Write-Host "[detached selfhost verification] PASS $outcome actual target/child completion audit."
    } finally {
        if (Test-Path -LiteralPath "$childResultPath.probe-child.json") {
            $childEvidence = Get-Content "$childResultPath.probe-child.json" -Raw | ConvertFrom-Json
            # The test-owned child supports a cooperative release marker. Never
            # terminate a PID merely because it once appeared in a probe result.
            New-Item -ItemType File -Path $childEvidence.releasePath -Force | Out-Null
            $releaseDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
            $cleanupIds = @($childEvidence.processId)
            if ($null -ne $childResult) { $cleanupIds += @($childResult.orphanProcessIds) }
            while (@($cleanupIds | Where-Object { $null -ne (Get-Process -Id $_ -ErrorAction SilentlyContinue) }).Count -gt 0) {
                if ([DateTimeOffset]::UtcNow -ge $releaseDeadline) { throw 'Probe child did not acknowledge its release marker' }
                Start-Sleep -Milliseconds 100
            }
        }
    }
}

if ($passResult.schemaVersion -ne 3 -or -not $passResult.processAudit.completed -or
    $passResult.processAudit.snapshotCount -lt 1) { throw 'New successful result is missing an actual process audit' }
foreach ($invalidAudit in @('missing', 'incomplete', 'unobserved')) {
    $invalid = $passResultJson | ConvertFrom-Json
    switch ($invalidAudit) {
        'missing' { $invalid.PSObject.Properties.Remove('processAudit') }
        'incomplete' { $invalid.processAudit.completed = $false }
        'unobserved' { $invalid.processAudit.observedProcessIds = @() }
    }
    if (($invalid | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
        throw "Schema accepted $invalidAudit audit as v3 success"
    }
}
$legacy = $passResultJson | ConvertFrom-Json
$legacy.schemaVersion = 1
$legacy.PSObject.Properties.Remove('processAudit')
$legacy.PSObject.Properties.Remove('targetExitCode')
if (-not (($legacy | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath)) {
    throw 'Historical v1 results lost schema compatibility'
}
$launcherText = [IO.File]::ReadAllText($launcherPath)
$requesterText = [IO.File]::ReadAllText($cancellationRequesterPath)
$verificationProcessText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'verification-process.ps1'))
$incrementalText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'verify-selfhost-incremental.ps1'))
if ($launcherText -match '\.Kill\s*\(' -or $requesterText -match '\.Kill\s*\(') {
    throw 'Cancellation supervisor/request path contains raw process termination'
}
foreach ($requiredIsolation in @('DOTNET_CLI_USE_MSBUILD_SERVER', 'MSBUILDDISABLENODEREUSE', 'UseSharedCompilation')) {
    if ($launcherText -notmatch [regex]::Escape($requiredIsolation)) {
        throw "Detached target launch is missing per-run build isolation: $requiredIsolation"
    }
}
if ($launcherText -match 'build-server\s+shutdown' -or $incrementalText -match 'build-server\s+shutdown') {
    throw 'Detached verification must not perform global build-server shutdown'
}
if ($incrementalText -notmatch '--disable-build-servers' -or
    $incrementalText -notmatch '-nodeReuse:false' -or
    $incrementalText -notmatch '-p:UseSharedCompilation=false' -or
    $verificationProcessText -notmatch 'Test-VerificationCancellationRequested' -or
    $incrementalText -notmatch 'CancellationAcknowledgementPath') {
    throw 'Incremental verification is missing cooperative cancellation or per-run build isolation wiring'
}
$launcherAst = [Management.Automation.Language.Parser]::ParseFile($launcherPath, [ref]$null, [ref]$null)
$observerFunction = $launcherAst.Find({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-ObservedProcessTree'
}, $true)
& {
    param($productionFunction)
    . ([scriptblock]::Create($productionFunction))
    function Get-CimInstance { param($ClassName, $ErrorAction) return $script:identityRecords }
    function Record($id, $parent, $tick) {
        [pscustomobject]@{ ProcessId = $id; ParentProcessId = $parent; CreationDate = [datetime]::new($tick, [DateTimeKind]::Utc) }
    }
    $script:processSnapshotCount = 0
    $observedProcesses = [Collections.Generic.Dictionary[string, object]]::new()
    $observedProcesses.Add('100:1000', [pscustomobject]@{ ProcessId = 100; CreatedTicks = 1000L })
    $script:identityRecords = @((Record 100 1 1000), (Record 200 100 2000), (Record 201 200 3000), (Record 199 100 500))
    if (((@(Update-ObservedProcessTree) | Sort-Object) -join ',') -cne '100,200,201') {
        throw 'Observed tree missed nested children or accepted a pre-parent identity'
    }
    $script:identityRecords = @((Record 100 1 1000), (Record 200 999 4000), (Record 201 200 3000), (Record 202 200 5000))
    if (((@(Update-ObservedProcessTree) | Sort-Object) -join ',') -cne '100,201') {
        throw 'Recycled unrelated PID inherited the old child identity'
    }
    $script:identityRecords = @((Record 100 1 1000), (Record 200 100 6000), (Record 203 200 7000))
    if (((@(Update-ObservedProcessTree) | Sort-Object) -join ',') -cne '100,200,203' -or $observedProcesses.Count -ne 5) {
        throw 'A later legitimate child reusing a PID was not independently tracked'
    }
    $script:identityRecords = @((Record 100 1 1000))
    if (((@(Update-ObservedProcessTree) | Sort-Object) -join ',') -cne '100') {
        throw 'Exited descendant identities remained alive'
    }
    # A different process reused PID 200 and exited between snapshots. Its
    # orphan is not a descendant of the former observed identity 200:6000.
    $script:identityRecords = @((Record 100 1 1000), (Record 300 200 8000))
    if (((@(Update-ObservedProcessTree) | Sort-Object) -join ',') -cne '100' -or $observedProcesses.Count -ne 5) {
        throw 'An absent recycled parent attached an unrelated late child'
    }
} $observerFunction.Extent.Text
$contractChecks.Add('v2-audit-required-v1-history-preserved')

. (Join-Path $PSScriptRoot 'expression-batch-selection.ps1')
$uriFixtures = @('1697-uri-normalization-policy', '1698-uri-resolution-boundaries', '1031-uri-percent-codec', '1032-uri-reference-authority')
$manifestPath = Join-Path $scratchRoot "$runId selection with spaces.json"
[ordered]@{ schemaVersion = 1; fixtures = $uriFixtures } | ConvertTo-Json |
    Set-Content -LiteralPath $manifestPath -Encoding utf8
$defaults = @((Get-Content (Join-Path $PSScriptRoot 'contracts/expression-lowering-parity.json') -Raw | ConvertFrom-Json).representativeFixtures)
$defaultSelection = @(Get-ExpressionBatchFixtureSelection -DefaultFixture $defaults)
if (($defaultSelection -join '|') -cne ($defaults -join '|')) { throw 'Default fixture inventory changed' }
foreach ($invalidSelection in @('duplicate', 'path', 'mixed', 'hash', 'empty')) {
    $rejected = $false
    try {
        switch ($invalidSelection) {
            'duplicate' { Get-ExpressionBatchFixtureSelection -Fixture @($uriFixtures[0], $uriFixtures[0]) }
            'path' { Get-ExpressionBatchFixtureSelection -Fixture @('../1697-uri-normalization-policy') }
            'mixed' { Get-ExpressionBatchFixtureSelection -Fixture @($uriFixtures[0]) -ManifestPath $manifestPath }
            'hash' { Get-ExpressionBatchFixtureSelection -ManifestPath $manifestPath -ManifestSha256 ('0' * 64) }
            'empty' {
                $emptyManifest = Join-Path $scratchRoot "$runId-empty-selection.json"
                '{"schemaVersion":1,"fixtures":[]}' | Set-Content -LiteralPath $emptyManifest -Encoding utf8
                Get-ExpressionBatchFixtureSelection -ManifestPath $emptyManifest
            }
        }
    } catch { $rejected = $true }
    if (-not $rejected) { throw "Invalid selection $invalidSelection was accepted" }
}
$contractChecks.Add('selection-default-and-negative-controls')

foreach ($selectionMode in @('array', 'manifest', 'singleton')) {
    $selected = @(if ($selectionMode -eq 'singleton') { $uriFixtures[0] } else { $uriFixtures })
    $selectionResultPath = Join-Path $scratchRoot "$runId-$selectionMode.result.json"
    $selectionArguments = @{
        Verification = 'ExpressionBatch'; ExpressionBatchCompiler = $launcherPath
        ValidateInputsOnly = $true; RunId = "$runId-$selectionMode"
        CompletionRecordPath = $selectionResultPath
    }
    if ($selectionMode -eq 'manifest') { $selectionArguments.ExpressionBatchManifest = $manifestPath }
    else { $selectionArguments.ExpressionBatchFixture = $selected }
    & $launcherPath @selectionArguments | Out-Null
    $selectionResult = Wait-ContractResult $selectionResultPath
    $selectionLaunch = Get-Content "$selectionResultPath.launch.json" -Raw | ConvertFrom-Json
    $snapshot = Get-Content "$selectionResultPath.fixtures.json" -Raw | ConvertFrom-Json
    if ($selectionResult.status -cne 'passed' -or
        ($selectionLaunch.selectedFixtures -join '|') -cne ($selected -join '|') -or
        ($snapshot.fixtures -join '|') -cne ($selected -join '|') -or
        [IO.File]::ReadAllText($selectionResult.logPath) -notlike "*PASS $($selected.Count) fixture inputs*") {
        throw "$selectionMode selection failed to cross both detached process boundaries exactly"
    }
    # The deliberately non-executable Compiler path proves this exercised only
    # real input validation/dispatch, not native compiler or Stage execution.
    $contractChecks.Add("detached-selection-$selectionMode")
    Write-Host "[detached selfhost verification] PASS $selectionMode selected $($selected.Count) exact fixtures; compiler launches 0."
}
foreach ($entry in $inputHashes) {
    if ((Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash -cne $entry.Hash) {
        throw "Harness source changed during its contract test: $($entry.Path)"
    }
}
if ($contractChecks.Count -ne 23) { throw "Incomplete harness groups: $($contractChecks.Count)/23" }
$contractStatus = 'passed'
} catch {
    $contractError = $_.Exception.Message
    throw
} finally {
    [ordered]@{
        schemaVersion = 1; state = $contractStatus; runId = $runId
        passed = $contractChecks.Count; total = 23; groups = @($contractChecks)
        error = $contractError; inputHashes = $inputHashes
        durationMilliseconds = [math]::Round(([DateTimeOffset]::UtcNow - $contractStarted).TotalMilliseconds)
        scope = 'Detached harness and input dispatch only; no compiler build or Stage execution'
    } | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $scratchRoot "$runId.contract-result.json") -Encoding utf8
    Stop-Transcript | Out-Null
}
Write-Host "[detached selfhost verification] PASS 23/23 groups: $(Join-Path $scratchRoot "$runId.contract-result.json")"
