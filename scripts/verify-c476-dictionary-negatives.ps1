[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 120000,
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'c476-dictionary-negative-classification.ps1')

$negativeRunner = Join-Path $PSScriptRoot 'verify-compiler-parity-negative-fixture.ps1'
$resultSchema = Join-Path $PSScriptRoot 'contracts/c476-dictionary-negatives-result.schema.json'
$caseNames = @(
    'generic-dictionary-put-wrong-key',
    'generic-dictionary-put-wrong-value',
    'generic-dictionary-put-no-arguments',
    'generic-dictionary-put-one-argument',
    'generic-dictionary-put-three-arguments',
    'generic-dictionary-put-if-absent-wrong-key',
    'generic-dictionary-put-if-absent-wrong-value',
    'generic-dictionary-put-if-absent-no-arguments',
    'generic-dictionary-put-if-absent-one-argument',
    'generic-dictionary-put-if-absent-three-arguments'
)

function Test-C476StrictParity($CaseResult, $ManagedEvidence, $SelfhostEvidence) {
    return $null -ne $CaseResult -and $CaseResult.state -ceq 'passed' -and
        $ManagedEvidence.state -ceq 'passed' -and $SelfhostEvidence.state -ceq 'passed' -and
        $ManagedEvidence.noEmittedProducts -and $SelfhostEvidence.noEmittedProducts
}

function Get-C476InfrastructureFailureId($RunnerFailure, $CaseResult) {
    if ($null -eq $CaseResult) { return 'C476_RUNNER_NO_RESULT' }
    if ($CaseResult.state -cne 'passed' -and $CaseResult.state -cne 'failed') {
        return 'C476_RUNNER_INCOMPLETE'
    }
    if (@($CaseResult.orphanProcessIds).Count -gt 0 -or
        $CaseResult.failureId -ceq 'NEGATIVE_PROCESS_ORPHANED') {
        return 'C476_PROCESS_ORPHANED'
    }
    if ($CaseResult.failureId -ceq 'NEGATIVE_PROCESS_TIMEOUT') {
        return 'C476_PROCESS_TIMEOUT'
    }
    if ($CaseResult.failureId -ceq 'NEGATIVE_LOG_DRAIN_TIMEOUT') {
        return 'C476_LOG_DRAIN_TIMEOUT'
    }
    if ($CaseResult.failureId -ceq 'NEGATIVE_PROCESS_INSPECTION_FAILED') {
        return 'C476_PROCESS_INSPECTION_FAILED'
    }
    if (-not $CaseResult.inputsStable -or $null -eq $CaseResult.inputFingerprintEnd) {
        return 'C476_INPUT_DRIFT'
    }
    if ($null -ne $RunnerFailure -and $CaseResult.failureId -cne 'NEGATIVE_CHECK_FAILED') {
        return 'C476_RUNNER_FAILED'
    }
    if ($CaseResult.state -ceq 'passed' -and $null -ne $RunnerFailure) {
        return 'C476_RUNNER_FAILED'
    }
    if ($CaseResult.state -ceq 'failed' -and $null -eq $RunnerFailure) {
        return 'C476_RUNNER_FAILED'
    }
    return $null
}

if ($SelfTest) {
    $unique = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in $caseNames) {
        if (-not $unique.Add($name)) { throw "C476 case repeated: $name" }
    }
    if ($caseNames.Count -ne 10) { throw 'C476 requires exactly ten symmetric cases' }
    foreach ($operation in @('put', 'put-if-absent')) {
        foreach ($failure in @('wrong-key', 'wrong-value', 'no-arguments', 'one-argument', 'three-arguments')) {
            if (-not $unique.Contains("generic-dictionary-$operation-$failure")) {
                throw "C476 case missing: $operation/$failure"
            }
        }
    }
    $diagnosed = Get-C476Evidence ([pscustomobject]@{
        nonzeroExit = $true; expectedInStderr = $true; noEmittedProducts = $false
        generatedProducts = @('leftover.txt'); outputDirectory = 'synthetic-output'
    })
    if ($diagnosed.state -cne 'passed' -or $diagnosed.noEmittedProducts) {
        throw 'Semantic and strict artifact evidence were conflated'
    }
    $inconsistent = Get-C476Evidence ([pscustomobject]@{
        nonzeroExit = $true; expectedInStderr = $true; noEmittedProducts = $true
        generatedProducts = @('leftover.txt'); outputDirectory = 'synthetic-output'
    }) ''
    if ($inconsistent.noEmittedProducts) {
        throw 'A recorded no-products flag overrode an observed product'
    }
    $lowered = Get-C476Evidence ([pscustomobject]@{
        nonzeroExit = $true; expectedInStderr = $true; noEmittedProducts = $false
        generatedProducts = @('negative.exe.ll'); outputDirectory = 'synthetic-output'
    })
    if ($lowered.state -cne 'failed' -or $lowered.noLoweringProduct) {
        throw 'A generated LLVM file was accepted as pre-LLVM rejection'
    }
    if (Test-C476StrictParity ([pscustomobject]@{ state = 'passed' }) $diagnosed $diagnosed) {
        throw 'A leftover product was accepted as strict parity'
    }
    if ((Get-C476Evidence $null).state -cne 'not-run') {
        throw 'Missing compiler evidence was accepted'
    }
    $diagnosticText = "; sollang workers = 1`n; sollang semantic error: put expects Text key and Int value arguments (source 143)`n"
    if (-not (Test-C476DiagnosticOnlyLlText $diagnosticText 'put expects Text key and Int value arguments')) {
        throw 'An exact diagnostic-only LLVM placeholder was rejected'
    }
    foreach ($invalid in @(
        ($diagnosticText + 'define i32 @main() { ret i32 0 }'),
        ($diagnosticText -replace 'workers = 1', 'workers = 2'),
        ($diagnosticText -replace 'put expects Text', 'put expects Bool'),
        ($diagnosticText + '; extra line' + "`n"))) {
        if (Test-C476DiagnosticOnlyLlText $invalid 'put expects Text key and Int value arguments') {
            throw 'A non-diagnostic LLVM product was accepted as an early rejection'
        }
    }
    if (Test-C476DiagnosticOnlyLlText ($diagnosticText + ('x' * 4096)) 'put expects Text key and Int value arguments') {
        throw 'An oversized LLVM placeholder was accepted'
    }
    $semanticFailure = [pscustomobject]@{
        state = 'failed'; failureId = 'NEGATIVE_CHECK_FAILED'; inputsStable = $true
        inputFingerprintEnd = ('E' * 64); orphanProcessIds = @()
    }
    if ($null -ne (Get-C476InfrastructureFailureId 'semantic mismatch' $semanticFailure)) {
        throw 'A semantic mismatch incorrectly stopped the aggregate gate'
    }
    foreach ($failure in @(
        @{ Id = 'NEGATIVE_PROCESS_ORPHANED'; Expected = 'C476_PROCESS_ORPHANED' },
        @{ Id = 'NEGATIVE_PROCESS_TIMEOUT'; Expected = 'C476_PROCESS_TIMEOUT' },
        @{ Id = 'NEGATIVE_LOG_DRAIN_TIMEOUT'; Expected = 'C476_LOG_DRAIN_TIMEOUT' },
        @{ Id = 'NEGATIVE_PROCESS_INSPECTION_FAILED'; Expected = 'C476_PROCESS_INSPECTION_FAILED' })) {
        $failed = [pscustomobject]@{
            state = 'failed'; failureId = $failure.Id; inputsStable = $true
            inputFingerprintEnd = ('E' * 64); orphanProcessIds = @()
        }
        if ((Get-C476InfrastructureFailureId $failure.Id $failed) -cne $failure.Expected) {
            throw "Infrastructure failure did not stop the aggregate gate: $($failure.Id)"
        }
    }
    $semanticFailure.orphanProcessIds = @(1234)
    if ((Get-C476InfrastructureFailureId 'semantic mismatch' $semanticFailure) -cne 'C476_PROCESS_ORPHANED') {
        throw 'An orphaned semantic failure was accepted'
    }
    $semanticFailure.orphanProcessIds = @()
    $semanticFailure.inputsStable = $false
    if ((Get-C476InfrastructureFailureId 'semantic mismatch' $semanticFailure) -cne 'C476_INPUT_DRIFT') {
        throw 'Input drift was accepted as an ordinary semantic mismatch'
    }
    if ((Get-C476InfrastructureFailureId 'runner crashed' $null) -cne 'C476_RUNNER_NO_RESULT') {
        throw 'A missing child result was accepted'
    }
    $semanticCase = [pscustomobject]@{
        state = 'failed'; failureId = 'NEGATIVE_CHECK_FAILED'
        failure = 'selfhost negative fixture failed: exit=1, expectedInStderr=True, noEmittedProducts=False'
        inputsStable = $true; inputFingerprintEnd = ('E' * 64); orphanProcessIds = @()
    }
    if (-not (Test-C476SemanticEligibility $semanticCase)) {
        throw 'A stable diagnostic-only semantic rejection was discarded'
    }
    $semanticCase.orphanProcessIds = @(99999)
    if (Test-C476SemanticEligibility $semanticCase) {
        throw 'An orphaned negative result was accepted as semantic evidence'
    }
    $semanticCase.orphanProcessIds = @()
    foreach ($failureId in @('NEGATIVE_PROCESS_ORPHANED', 'NEGATIVE_PROCESS_TIMEOUT',
            'NEGATIVE_LOG_DRAIN_TIMEOUT', 'NEGATIVE_PROCESS_INSPECTION_FAILED')) {
        $semanticCase.failureId = $failureId
        if (Test-C476SemanticEligibility $semanticCase) {
            throw "An infrastructure failure was accepted as semantic evidence: $failureId"
        }
    }
    $semanticCase.failureId = 'NEGATIVE_CHECK_FAILED'
    $semanticCase.failure = 'unexpected result writer failure'
    if (Test-C476SemanticEligibility $semanticCase) {
        throw 'An unrelated check failure was accepted as semantic evidence'
    }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c476-dictionary-negatives'; state = 'running'
        total = 10; completed = 0; preflightPassed = 10
        managedCompilerSha256 = ('A' * 64); selfhostCompilerSha256 = ('B' * 64)
        inputFingerprintStart = ('C' * 64); inputFingerprintEnd = $null
        inputsStable = $false; managedSemanticPreLlPassed = 0
        selfhostSemanticPreLlPassed = 0; semanticPairPassed = 0; strictParityPassed = 0
        cases = @(); failureId = $null; failure = $null
    }
    if (-not (Test-Json -Json ($sample | ConvertTo-Json -Depth 10) -SchemaFile $resultSchema)) {
        throw 'C476 result schema rejected a valid running record'
    }
    $sample.state = 'passed'
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 10) -SchemaFile $resultSchema -ErrorAction SilentlyContinue) {
        throw 'C476 result schema accepted unverified success'
    }
    Write-Host '[C476 negatives self-test] PASS 10-case roster, semantic/artifact classification, and infrastructure fail-fast; no compiler executed.'
    return
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-UnderRoot([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}
function Assert-NoReparseAncestors([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = [IO.Path]::GetPathRoot($full)
    foreach ($segment in $full.Substring($cursor.Length) -split '[\\/]') {
        if ($segment) { $cursor = Join-Path $cursor $segment }
        try { $attributes = [IO.File]::GetAttributes($cursor) }
        catch [IO.FileNotFoundException] { return }
        catch [IO.DirectoryNotFoundException] { return }
        if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "C476 output traverses a junction or symbolic link: $cursor"
        }
    }
}

$outputPath = Resolve-UnderRoot $OutputDirectory
$scratchPath = Resolve-UnderRoot 'artifacts/scratch'
if (-not $outputPath.StartsWith($scratchPath + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "C476 OutputDirectory must be below $scratchPath`: $outputPath"
}
Assert-NoReparseAncestors $outputPath
if (Test-Path -LiteralPath $outputPath) { throw "C476 OutputDirectory must be unused: $outputPath" }

$managedPath = Resolve-UnderRoot $ManagedCompiler
$selfhostPath = Resolve-UnderRoot $SelfhostCompiler
$llvmPath = Resolve-UnderRoot $LlvmRoot
$stdlibPath = Resolve-UnderRoot $StdlibRoot
$cases = @($caseNames | ForEach-Object {
    $source = Resolve-UnderRoot "examples/regression/diagnostics/$_.slg"
    [pscustomobject]@{
        id = $_
        source = $source
        expected = $source.Substring(0, $source.Length - 4) + '.stderr.contains.txt'
        outputDirectory = Join-Path $outputPath $_
    }
})
$shared = @{
    ManagedCompiler = $managedPath
    SelfhostCompiler = $selfhostPath
    ManagedCompilerSha256 = $ManagedCompilerSha256
    SelfhostCompilerSha256 = $SelfhostCompilerSha256
    RepositoryRoot = $root
    LlvmRoot = $llvmPath
    StdlibRoot = $stdlibPath
    TimeoutMilliseconds = $TimeoutMilliseconds
}

function Get-C476InputFingerprint {
    $managedCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $managedPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $selfhostCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $selfhostPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'c476-dictionary-negatives-v1'
        managedCommon = $managedCommon
        selfhostCommon = $selfhostCommon
        timeoutMilliseconds = [string]$TimeoutMilliseconds
    }
    $paths = @($PSCommandPath, (Join-Path $PSScriptRoot 'c476-dictionary-negative-classification.ps1'),
        $negativeRunner, $resultSchema,
        (Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'))
    foreach ($case in $cases) { $paths += @($case.source, $case.expected) }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $paths
}

# All ten input contracts are checked before the first compiler is invoked.
$fingerprintStart = Get-C476InputFingerprint
$preflights = @()
foreach ($case in $cases) {
    $response = & $negativeRunner @shared -Source $case.source -Expected $case.expected `
        -OutputDirectory $case.outputDirectory -ValidateInputsOnly
    $preflight = $response | ConvertFrom-Json
    if ($preflight.status -cne 'preflight-passed') {
        throw "C476 preflight failed for $($case.id): $($preflight.status)"
    }
    $preflights += [ordered]@{
        id = $case.id
        sourceSha256 = $preflight.sourceSha256
        expectedSha256 = $preflight.expectedSha256
        inputFingerprint = $preflight.inputFingerprint
    }
}

if ((Get-C476InputFingerprint) -cne $fingerprintStart) {
    throw 'C476 inputs changed during the ten-case preflight'
}
if ($ValidateInputsOnly) {
    [pscustomobject]@{
        status = 'preflight-passed'
        total = $cases.Count
        managedCompilerSha256 = $ManagedCompilerSha256.ToUpperInvariant()
        selfhostCompilerSha256 = $SelfhostCompilerSha256.ToUpperInvariant()
        inputFingerprint = $fingerprintStart
        cases = $preflights
    } | ConvertTo-Json -Depth 5
    return
}

[void][IO.Directory]::CreateDirectory($outputPath)
Assert-NoReparseAncestors $outputPath
$resultPath = Join-Path $outputPath 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    gate = 'c476-dictionary-negatives'
    state = 'running'
    total = $cases.Count
    completed = 0
    preflightPassed = $preflights.Count
    managedCompilerSha256 = $ManagedCompilerSha256.ToUpperInvariant()
    selfhostCompilerSha256 = $SelfhostCompilerSha256.ToUpperInvariant()
    inputFingerprintStart = $fingerprintStart
    inputFingerprintEnd = $null
    inputsStable = $false
    managedSemanticPreLlPassed = 0
    selfhostSemanticPreLlPassed = 0
    semanticPairPassed = 0
    strictParityPassed = 0
    cases = @()
    failureId = $null
    failure = $null
}
function Write-C476Result {
    $json = $record | ConvertTo-Json -Depth 10
    if (-not (Test-Json -Json $json -SchemaFile $resultSchema)) {
        throw 'C476 aggregate result violates its schema'
    }
    [IO.File]::WriteAllText($resultPath, $json,
        [Text.UTF8Encoding]::new($false))
}
Write-C476Result

$fatalCaseFailureId = $null
try {
    foreach ($case in $cases) {
        if ((Get-C476InputFingerprint) -cne $fingerprintStart) {
            throw "C476 inputs changed before $($case.id)"
        }
        $runnerFailure = $null
        try {
            & $negativeRunner @shared -Source $case.source -Expected $case.expected `
                -OutputDirectory $case.outputDirectory
        } catch {
            $runnerFailure = $_.Exception.Message
        }
        $caseResultPath = Join-Path $case.outputDirectory 'result.json'
        $caseResult = if (Test-Path -LiteralPath $caseResultPath -PathType Leaf) {
            Get-Content -LiteralPath $caseResultPath -Raw | ConvertFrom-Json
        } else { $null }
        $expectedDiagnostic = [IO.File]::ReadAllText($case.expected).Trim()
        $managedEvidence = Get-C476Evidence $(if ($null -eq $caseResult) { $null } else { $caseResult.managed }) $expectedDiagnostic
        $selfhostEvidence = Get-C476Evidence $(if ($null -eq $caseResult) { $null } else { $caseResult.selfhost }) $expectedDiagnostic
        $semanticPair = (Test-C476SemanticEligibility $caseResult) -and
            $managedEvidence.state -ceq 'passed' -and $selfhostEvidence.state -ceq 'passed'
        $strict = $null -eq $runnerFailure -and
            (Test-C476StrictParity $caseResult $managedEvidence $selfhostEvidence)
        $infrastructureFailureId = Get-C476InfrastructureFailureId $runnerFailure $caseResult
        $record.cases += [ordered]@{
            id = $case.id
            source = $case.source
            expected = $case.expected
            resultPath = if ($null -eq $caseResult) { $null } else { $caseResultPath }
            managed = $managedEvidence
            selfhost = $selfhostEvidence
            semanticPairPassed = $semanticPair
            strictParityPassed = $strict
            runnerState = if ($null -eq $caseResult) { 'no-result' } else { $caseResult.state }
            runnerFailureId = if ($null -eq $caseResult) { 'C476_RUNNER_NO_RESULT' } else { $caseResult.failureId }
            runnerFailure = $runnerFailure
        }
        $record.completed++
        if ($managedEvidence.state -ceq 'passed') { $record.managedSemanticPreLlPassed++ }
        if ($selfhostEvidence.state -ceq 'passed') { $record.selfhostSemanticPreLlPassed++ }
        if ($semanticPair) { $record.semanticPairPassed++ }
        if ($strict) { $record.strictParityPassed++ }
        Write-C476Result
        Write-Host "[C476 negatives] $($record.completed)/$($record.total) $($case.id): semantic=$semanticPair strict=$strict"
        if ((Get-C476InputFingerprint) -cne $fingerprintStart) {
            throw "C476 inputs changed after $($case.id)"
        }
        if ($null -ne $infrastructureFailureId) {
            $fatalCaseFailureId = $infrastructureFailureId
            throw "C476 infrastructure failure in $($case.id): $infrastructureFailureId; $runnerFailure"
        }
    }
    $record.inputFingerprintEnd = Get-C476InputFingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C476 inputs changed during verification' }
    if ($record.strictParityPassed -ne $record.total) {
        throw "C476 strict parity passed $($record.strictParityPassed)/$($record.total) cases"
    }
    $record.state = 'passed'
    Write-C476Result
    Write-Host "[C476 negatives] PASS $($record.strictParityPassed)/$($record.total); $resultPath"
} catch {
    $record.state = 'failed'
    $record.failure = $_.Exception.Message
    try {
        $record.inputFingerprintEnd = Get-C476InputFingerprint
        $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    } catch {
        $record.failure += "; end fingerprint failed: $($_.Exception.Message)"
    }
    $record.failureId = if (-not $record.inputsStable) { 'C476_INPUT_DRIFT' }
        elseif ($null -ne $fatalCaseFailureId) { $fatalCaseFailureId }
        else { 'C476_STRICT_PARITY_FAILED' }
    Write-C476Result
    throw
}
