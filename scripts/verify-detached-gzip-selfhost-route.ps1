[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Compiler = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$launcher = Join-Path $root 'scripts/invoke-detached-selfhost-verification.ps1'
$progressReader = Join-Path $root 'scripts/read-detached-selfhost-progress.ps1'
$schema = Join-Path $root 'scripts/contracts/detached-selfhost-verification-result.schema.json'
$workerResultReader = Join-Path $root 'scripts/detached-gzip-selfhost-result.ps1'
$workerResultSchema = Join-Path $root 'scripts/contracts/gzip-selfhost-focused-result.schema.json'
$defaultCompiler = Join-Path $root 'scripts/verify-gzip-selfhost-focused.ps1'
$compilerPath = [IO.Path]::GetFullPath($(if ([string]::IsNullOrWhiteSpace($Compiler)) { $defaultCompiler } else { $Compiler }))
$output = Join-Path $root 'artifacts/scratch/gzip-selfhost/detached-route-static-control'
$sha256 = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash

foreach ($path in @($launcher, $progressReader, $schema, $workerResultReader, $workerResultSchema, $compilerPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "GZIP detached route input is missing: $path" }
}
$launcherText = [IO.File]::ReadAllText($launcher)
foreach ($required in @(
    '"GzipSelfhost" { Join-Path $PSScriptRoot "verify-gzip-selfhost-focused.ps1" }',
    '"-GzipSelfhostExpectedCompilerSha256", $GzipSelfhostExpectedCompilerSha256',
    '"-ExpectedCompilerSha256", $GzipSelfhostExpectedCompilerSha256',
    '"-OutputDirectory", (ConvertTo-ProcessArgument $GzipSelfhostOutputDirectory)',
    'GzipSelfhost compiler hash mismatch',
    'GzipSelfhost requires compiler, expected SHA-256, and output directory together'
    "Read-GzipSelfhostWorkerResult"
)) {
    if (-not $launcherText.Contains($required, [StringComparison]::Ordinal)) {
        throw "GZIP detached route lost fixed authority: $required"
    }
}
$workerResultReaderText = [IO.File]::ReadAllText($workerResultReader)
foreach ($required in @(
    'GZIP_SELFHOST_RESULT_MISSING',
    'GZIP_SELFHOST_RESULT_INVALID',
    'GZIP_SELFHOST_COMPILER_SHA_MISMATCH'
)) {
    if (-not $workerResultReaderText.Contains($required, [StringComparison]::Ordinal)) {
        throw "GZIP detached worker-result reader lost fixed authority: $required"
    }
}

. $workerResultReader
$workerResultDirectory = Join-Path $root 'artifacts/scratch/gzip-selfhost/detached-worker-result-control'
[IO.Directory]::CreateDirectory($workerResultDirectory) | Out-Null
$workerResultPath = Join-Path $workerResultDirectory 'result.json'
$workerFailureIds = @(
    'crc-parity-o0', 'crc-parity-o2',
    'transactional-concatenated-o0', 'transactional-concatenated-o2',
    'one-byte-boundaries-o0', 'one-byte-boundaries-o2',
    'private-codec-state', 'private-encoder-state', 'private-decoder-state'
)
$focusedContractPath = Join-Path $root 'scripts/contracts/gzip-selfhost-focused.json'
$focusedContract = [IO.File]::ReadAllText($focusedContractPath) | ConvertFrom-Json
$expectedHashes = Get-GzipSelfhostExpectedInputHashes -RepositoryRoot $root -CompilerPath $compilerPath -FocusedContractPath $focusedContractPath -ResultSchemaPath $workerResultSchema
$workerCases = [Collections.Generic.List[object]]::new()
foreach ($caseId in @($focusedContract.positiveCaseIds)) {
    foreach ($optimization in @($focusedContract.optimizations)) {
        $id = "$caseId-$($optimization.ToLowerInvariant())"
        $passed = $workerFailureIds -cnotcontains $id
        $workerCases.Add([ordered]@{ id = $id; kind = 'positive'; optimization = $optimization; passed = $passed; compileExit = $(if ($passed) { 0 } else { 1 }); diagnosticFree = $passed; llvmProduced = $passed; llvmAsExit = $(if ($passed) { 0 } else { $null }); closureExit = $(if ($passed) { 0 } else { $null }); linkExit = $(if ($passed) { 0 } else { $null }); nativeExit = $(if ($passed) { 0 } else { $null }); exact = $passed; stdoutSha256 = $(if ($passed) { 'B' * 64 } else { $null }); failure = $(if ($passed) { $null } else { 'focused failure' }) })
    }
}
foreach ($caseId in @($focusedContract.negativeCaseIds)) {
    $passed = $workerFailureIds -cnotcontains $caseId
    $workerCases.Add([ordered]@{ id = $caseId; kind = 'negative'; optimization = $null; passed = $passed; compileExit = 1; diagnosticFree = $false; llvmProduced = $false; llvmAsExit = $null; closureExit = $null; linkExit = $null; nativeExit = $null; exact = $passed; stdoutSha256 = $null; failure = $(if ($passed) { $null } else { 'focused failure' }) })
}
$failedWorkerRecord = [ordered]@{
    schemaVersion = 1; mode = 'selfhost-native-gzip-focused'; status = 'failed'; platform = 'windows-x64'; phase = 'execution'; attempted = 23
    executionMode = 'detached-supervisor-worker'; processAuditAuthority = 'scripts/invoke-detached-selfhost-verification.ps1 completion record'; orphanProcessIds = $null
    completed = 14; total = 23; positive = [ordered]@{ completed = 14; total = 20 }; negative = [ordered]@{ completed = 0; total = 3 }
    expectedCompilerSha256 = $sha256; compilerSha256Start = $sha256; compilerSha256End = $sha256
    inputStable = $true; inputDrift = @(); inputHashesStart = $expectedHashes; inputHashesEnd = $expectedHashes
    toolHashes = [ordered]@{ compiler = $sha256; llvmAs = $expectedHashes.llvmAs; clang = $expectedHashes.clang; closureVerifier = $expectedHashes.closureVerifier }
    dynamic = [ordered]@{ caseId = 'dynamic-writer'; btype = 2; independentReader = 'System.IO.Compression.GZipStream'; decodedExact = $true; deterministicAcrossOptimizations = $true; stdoutSha256O0 = 'B' * 64; stdoutSha256O2 = 'B' * 64 }
    cases = @($workerCases); failureIds = $workerFailureIds
}
[IO.File]::WriteAllText($workerResultPath, ($failedWorkerRecord | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$readerArguments = @{ ResultPath = $workerResultPath; SchemaPath = $workerResultSchema; FocusedContractPath = $focusedContractPath; RepositoryRoot = $root; CompilerPath = $compilerPath; ExpectedCompilerSha256 = $sha256 }
$failedWorkerAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if (-not $failedWorkerAudit.valid -or @($failedWorkerAudit.workerFailureIds).Count -ne 9 -or
    (@($failedWorkerAudit.workerFailureIds) -join ',') -cne ($workerFailureIds -join ',')) {
    throw 'GZIP detached worker result did not preserve the nine ordered failure IDs'
}
$mismatchedExitAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 0
if ($mismatchedExitAudit.valid -or $mismatchedExitAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') {
    throw 'GZIP detached worker result accepted failed status with target exit zero'
}
$missingArguments = $readerArguments.Clone(); $missingArguments.ResultPath = Join-Path $workerResultDirectory 'missing.json'
$missingWorkerAudit = Read-GzipSelfhostWorkerResult @missingArguments -TargetExitCode 1
if ($missingWorkerAudit.valid -or $missingWorkerAudit.failureId -cne 'GZIP_SELFHOST_RESULT_MISSING') {
    throw 'GZIP detached worker result did not fail closed on a missing result'
}
$forgedWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$forgedWorkerRecord.failureIds = @($forgedWorkerRecord.failureIds) + 'forged-case-id'
[IO.File]::WriteAllText($workerResultPath, ($forgedWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$forgedAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if ($forgedAudit.valid -or $forgedAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') { throw 'GZIP detached worker result accepted an unknown failure ID' }
$countWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$countWorkerRecord.completed = 15
[IO.File]::WriteAllText($workerResultPath, ($countWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$countAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if ($countAudit.valid -or $countAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') { throw 'GZIP detached worker result accepted a forged completed count' }
$hashWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$hashWorkerRecord.inputHashesEnd.compiler = '0' * 64
[IO.File]::WriteAllText($workerResultPath, ($hashWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$hashAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if ($hashAudit.valid -or $hashAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') { throw 'GZIP detached worker result accepted input hash drift' }
$toolWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$toolWorkerRecord.toolHashes.llvmAs = '0' * 64
[IO.File]::WriteAllText($workerResultPath, ($toolWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$toolAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if ($toolAudit.valid -or $toolAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') { throw 'GZIP detached worker result accepted tool hash drift' }
$caseWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$caseWorkerRecord.cases[0].compileExit = 1
[IO.File]::WriteAllText($workerResultPath, ($caseWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$caseAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if ($caseAudit.valid -or $caseAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') { throw 'GZIP detached worker result accepted forged passed-case evidence' }
$dynamicWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$dynamicWorkerRecord.dynamic.stdoutSha256O2 = 'C' * 64
[IO.File]::WriteAllText($workerResultPath, ($dynamicWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$dynamicAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if ($dynamicAudit.valid -or $dynamicAudit.failureId -cne 'GZIP_SELFHOST_RESULT_INVALID') { throw 'GZIP detached worker result accepted forged dynamic summary evidence' }
$preflightWorkerRecord = ($failedWorkerRecord | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$preflightWorkerRecord.phase = 'preflight'; $preflightWorkerRecord.attempted = 0; $preflightWorkerRecord.completed = 0
$preflightWorkerRecord.positive.completed = 0; $preflightWorkerRecord.negative.completed = 0
$preflightWorkerRecord.cases = @(); $preflightWorkerRecord.failureIds = @('GZIP_SELFHOST_PREFLIGHT_FAILED')
[IO.File]::WriteAllText($workerResultPath, ($preflightWorkerRecord | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$preflightAudit = Read-GzipSelfhostWorkerResult @readerArguments -TargetExitCode 1
if (-not $preflightAudit.valid -or (@($preflightAudit.workerFailureIds) -join ',') -cne 'GZIP_SELFHOST_PREFLIGHT_FAILED') { throw 'GZIP detached worker result lost the exact preflight failure ID' }

function Require-Failure([hashtable]$Arguments, [string]$Expected) {
    $failed = $false
    try {
        & $launcher @Arguments | Out-Null
    } catch {
        $failed = $_.Exception.Message.Contains($Expected, [StringComparison]::Ordinal)
    }
    if (-not $failed) { throw "GZIP detached negative control did not fail with: $Expected" }
}

Require-Failure @{ Verification = 'GzipSelfhost' } 'compiler, expected SHA-256, and output directory are required'
Require-Failure @{
    Verification = 'GzipSelfhost'
    GzipSelfhostCompiler = $compilerPath
    GzipSelfhostExpectedCompilerSha256 = $sha256
} 'requires compiler, expected SHA-256, and output directory together'
Require-Failure @{
    Verification = 'Probe'
    GzipSelfhostCompiler = $compilerPath
    GzipSelfhostExpectedCompilerSha256 = $sha256
    GzipSelfhostOutputDirectory = $output
} 'required only for Verification GzipSelfhost'
Require-Failure @{
    Verification = 'GzipSelfhost'
    GzipSelfhostCompiler = $compilerPath
    GzipSelfhostExpectedCompilerSha256 = ('0' * 64)
    GzipSelfhostOutputDirectory = $output
    ValidateInputsOnly = $true
} 'GzipSelfhost compiler hash mismatch'
Require-Failure @{
    Verification = 'GzipSelfhost'
    GzipSelfhostCompiler = (Join-Path (Split-Path -Parent $root) 'outside-gzip-compiler.exe')
    GzipSelfhostExpectedCompilerSha256 = $sha256
    GzipSelfhostOutputDirectory = $output
    ValidateInputsOnly = $true
} 'GzipSelfhostCompiler must be under'
Require-Failure @{
    Verification = 'GzipSelfhost'
    GzipSelfhostCompiler = $compilerPath
    GzipSelfhostExpectedCompilerSha256 = $sha256
    GzipSelfhostOutputDirectory = (Join-Path $root 'gzip-route-outside-scratch')
    ValidateInputsOnly = $true
} 'GzipSelfhostOutputDirectory must be under'

$validated = & $launcher -Verification GzipSelfhost `
    -GzipSelfhostCompiler $compilerPath `
    -GzipSelfhostExpectedCompilerSha256 $sha256 `
    -GzipSelfhostOutputDirectory $output `
    -ValidateInputsOnly | ConvertFrom-Json
if (-not $validated.validated -or $validated.verification -cne 'GzipSelfhost' -or
    $validated.compilerSha256 -cne $sha256 -or
    [IO.Path]::GetFullPath($validated.compiler) -cne $compilerPath -or
    [IO.Path]::GetFullPath($validated.outputDirectory) -cne [IO.Path]::GetFullPath($output)) {
    throw 'GZIP detached positive input validation drifted'
}

$record = [ordered]@{
    schemaVersion = 2
    runId = 'gzip-selfhost-static-control'
    verification = 'GzipSelfhost'
    executionMode = 'detached-supervisor'
    supervisorPid = 1
    startedAtUtc = '2026-09-13T00:00:00Z'
    completedAtUtc = '2026-09-13T00:00:01Z'
    durationMilliseconds = 1000
    exitCode = 0
    status = 'passed'
    failureIds = @()
    logPath = 'gzip-selfhost.log'
    standardErrorPath = 'gzip-selfhost.log.stderr'
    cancellationRequestPath = 'gzip-selfhost.result.json.cancel.json'
    targetProcessId = 2
    targetExitCode = 0
    orphanProcessIds = @()
    processAudit = [ordered]@{ method = 'observed-pid-creation-time-snapshots'; completed = $true; snapshotCount = 1; observedProcessIds = @(2) }
}
$json = $record | ConvertTo-Json -Depth 8
if (-not ($json | Test-Json -SchemaFile $schema)) { throw 'GZIP detached success record failed schema' }
$record.verification = 'GzipSelfhostUnknown'
if (($record | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $schema -ErrorAction SilentlyContinue) {
    throw 'GZIP detached schema accepted an unknown verification mode'
}

$progressDirectory = Join-Path $root 'artifacts/scratch/gzip-selfhost/detached-route-progress-control'
[IO.Directory]::CreateDirectory($progressDirectory) | Out-Null
$progressLog = Join-Path $progressDirectory 'progress.log'
$progressResult = Join-Path $progressDirectory 'progress.result.json'
$progressLaunch = "$progressResult.launch.json"
[IO.File]::WriteAllText($progressLog, "[GZIP selfhost focused 11/23] PASS fixture-o0`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($progressLaunch, ([ordered]@{
    schemaVersion = 1
    runId = 'gzip-selfhost-progress-control'
    verification = 'GzipSelfhost'
    supervisorPid = $PID
    logPath = $progressLog
} | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
if (Test-Path -LiteralPath $progressResult -PathType Leaf) { Remove-Item -LiteralPath $progressResult -Force }
$progress = & $progressReader -CompletionRecordPath $progressResult | ConvertFrom-Json
if ($progress.status -cne 'running' -or $progress.completed -ne 11 -or $progress.total -ne 23 -or $progress.percent -ne 47.8) {
    throw 'GZIP detached progress reader did not preserve 11/23 running state'
}

Write-Host '[detached GZIP selfhost route] PASS ordered 23-case failure propagation, preflight preservation, forged ID/count/case/dynamic/input/tool rejection, 7 route controls, and 11/23 progress parsing; compiler launches 0'
