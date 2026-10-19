param(
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ('artifacts\scratch\stage3-cancellation-contract-' + [guid]::NewGuid().ToString('N'))
}
if (Test-Path -LiteralPath $OutputDirectory) {
    throw 'Cancellation contract output directory must be new'
}
[void](New-Item -ItemType Directory -Path $OutputDirectory)
$stage3Script = Join-Path $PSScriptRoot 'verify-selfhost-stage3.ps1'
$supervisorScript = Join-Path $PSScriptRoot 'invoke-detached-selfhost-verification.ps1'
$processScript = Join-Path $PSScriptRoot 'verification-process.ps1'
$powerShellPath = (Get-Process -Id $PID).Path

foreach ($scriptPath in @($stage3Script, $supervisorScript, $processScript)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
    if (@($parseErrors).Count -ne 0) {
        throw "PowerShell parse failed: $scriptPath"
    }
}
$stage3Source = Get-Content -LiteralPath $stage3Script -Raw
$supervisorSource = Get-Content -LiteralPath $supervisorScript -Raw
foreach ($required in @('Initialize-VerificationCancellation', 'Assert-VerificationCancellationNotRequested',
        'trap [OperationCanceledException] { exit 130 }', 'Test-VerificationCancellationRequested',
        '-CancellationAcknowledgementPath $stage2CancellationAcknowledgementPath')) {
    if (-not $stage3Source.Contains($required)) { throw "Stage3 cancellation path missing: $required" }
}
if ($supervisorSource -notmatch '(?s)"Stage3"\s*\{[^}]*"-CancellationRequestPath"[^}]*"-CancellationRunId"[^}]*"-CancellationAcknowledgementPath"') {
    throw 'Supervisor does not forward the Stage3 cancellation triplet'
}
if (-not $supervisorSource.Contains('STAGE3_PUBLICATION_INPUT_DRIFT') -or
    -not $supervisorSource.Contains('publicationMayBePartial = $Verification -eq ''Stage3'' -and $exitCode -ne 0')) {
    throw 'Supervisor does not classify post-commit input drift and partial-publication risk'
}
if ($stage3Source -notmatch '(?s)while \(-not \$process\.WaitForExit\(100\)\)\s*\{\s*if \(Test-VerificationCancellationRequested\)' -or
    $stage3Source -notmatch '(?s)\$stage2CancellationAcknowledgementPath = if .*?"\$CancellationAcknowledgementPath\.stage2".*?Assert-VerificationCancellationNotRequested\s+if \(\$LASTEXITCODE') {
    throw 'Stage3 active-process, nested-Stage2, or pre-publication cancellation boundary is missing'
}
$phaseIndex = $stage3Source.IndexOf('-Phase "Stage3"', [StringComparison]::Ordinal)
$firstProbeIndex = $stage3Source.IndexOf('Assert-VerificationCancellationNotRequested', $phaseIndex, [StringComparison]::Ordinal)
$commitIndex = $stage3Source.IndexOf('Write-Stage3PublicationRecord -Path $stage3PublicationCommitPath', $firstProbeIndex, [StringComparison]::Ordinal)
$secondProbeIndex = $stage3Source.IndexOf('Assert-VerificationCancellationNotRequested', $commitIndex, [StringComparison]::Ordinal)
$publishIndex = $stage3Source.IndexOf('Move-Item -LiteralPath $stage3LlvmPath -Destination $publishedStage3LlvmPath', $secondProbeIndex, [StringComparison]::Ordinal)
$provenanceIndex = $stage3Source.IndexOf('$incrementalSeedProvenancePath = Write-VerifiedStage3SeedProvenance', $publishIndex, [StringComparison]::Ordinal)
$completionFingerprintIndex = $stage3Source.IndexOf('Assert-InputFingerprintStable', $provenanceIndex, [StringComparison]::Ordinal)
$completionRecordIndex = $stage3Source.IndexOf('Write-Stage3PublicationRecord -Path $stage3PublicationCompletePath', $completionFingerprintIndex, [StringComparison]::Ordinal)
if ($phaseIndex -lt 0 -or $firstProbeIndex -lt 0 -or $commitIndex -lt 0 -or
    $secondProbeIndex -lt 0 -or $publishIndex -lt 0 -or $provenanceIndex -lt 0 -or
    $completionFingerprintIndex -lt 0 -or $completionRecordIndex -lt 0 -or
    $stage3Source.IndexOf('STAGE3_PUBLICATION_INPUT_DRIFT', $provenanceIndex, [StringComparison]::Ordinal) -gt $completionRecordIndex -or
    $stage3Source.IndexOf('Remove-Item -LiteralPath $stage3PublicationCommitPath', $commitIndex, [StringComparison]::Ordinal) -gt $publishIndex) {
    throw 'Stage3 publication has no ordered input, request, commit, second-request, and publish boundary'
}
$stage3Lines = Get-Content -LiteralPath $stage3Script
for ($index = 1; $index -lt $stage3Lines.Count; $index++) {
    if ($stage3Lines[$index] -match '^# Publication is committed\.') { break }
    if ($stage3Lines[$index] -match '^\s*(& \(Join-Path|& \$llvmAsPath|& \$clangPath|& dotnet|\$\w+ = Start-Process|\$\w+ = Invoke-VerificationProcessCapture)' -and
        $stage3Lines[$index - 1].Trim() -ne 'Assert-VerificationCancellationNotRequested') {
        throw "Stage3 starts work without a cancellation probe at line $($index + 1)"
    }
}

function Invoke-FocusedProcess {
    param([string]$CaseId, [string]$ScriptPath, [string[]]$Arguments)

    $stdoutPath = Join-Path $OutputDirectory "$CaseId.stdout.txt"
    $stderrPath = Join-Path $OutputDirectory "$CaseId.stderr.txt"
    $process = Start-Process -FilePath $powerShellPath `
        -ArgumentList (@('-NoProfile', '-File', $ScriptPath) + $Arguments) `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
        -PassThru -WindowStyle Hidden
    try {
        if (-not $process.WaitForExit(10000)) {
            $process.Kill($true)
            [void]$process.WaitForExit(5000)
            throw "Focused cancellation case timed out: $CaseId"
        }
        [pscustomobject]@{
            CaseId = $CaseId
            ProcessId = $process.Id
            ExitCode = $process.ExitCode
            StdoutPath = $stdoutPath
            StderrPath = $stderrPath
        }
    } finally {
        $process.Dispose()
    }
}

# The no-request probe is safe without starting a full Stage3 verification.
. $processScript
$normalRequestPath = Join-Path $OutputDirectory 'normal-request.json'
$normalAckPath = Join-Path $OutputDirectory 'normal-ack.json'
Initialize-VerificationCancellation -RequestPath $normalRequestPath -RunId 'normal' -AcknowledgementPath $normalAckPath
Assert-VerificationCancellationNotRequested
if (Test-Path -LiteralPath $normalAckPath) { throw 'No-request probe produced an acknowledgement' }

$single = Invoke-FocusedProcess -CaseId 'one-argument' -ScriptPath $stage3Script -Arguments @(
    '-CancellationRequestPath', (Join-Path $OutputDirectory 'one-request.json'))
if ($single.ExitCode -eq 0 -or $single.ExitCode -eq 130 -or
    (Get-Content -LiteralPath $single.StderrPath -Raw) -notlike '*must be supplied together*') {
    throw 'One cancellation argument was not rejected before Stage3 work'
}
$double = Invoke-FocusedProcess -CaseId 'two-arguments' -ScriptPath $stage3Script -Arguments @(
    '-CancellationRequestPath', (Join-Path $OutputDirectory 'two-request.json'), '-CancellationRunId', 'two')
if ($double.ExitCode -eq 0 -or $double.ExitCode -eq 130 -or
    (Get-Content -LiteralPath $double.StderrPath -Raw) -notlike '*must be supplied together*') {
    throw 'Two cancellation arguments were not rejected before Stage3 work'
}
$missingRunId = Invoke-FocusedProcess -CaseId 'missing-run-id' -ScriptPath $stage3Script -Arguments @(
    '-CancellationRequestPath', (Join-Path $OutputDirectory 'empty-request.json'),
    '-CancellationAcknowledgementPath', (Join-Path $OutputDirectory 'empty-ack.json'))
if ($missingRunId.ExitCode -eq 0 -or $missingRunId.ExitCode -eq 130 -or
    (Get-Content -LiteralPath $missingRunId.StderrPath -Raw) -notlike '*must be supplied together*') {
    throw 'Missing cancellation run ID was not rejected before Stage3 work'
}

$runId = 'stage3-contract-' + [guid]::NewGuid().ToString('N')
$requestPath = Join-Path $OutputDirectory 'requested.json'
$ackPath = Join-Path $OutputDirectory 'requested-ack.json'
@{ schemaVersion = 1; runId = $runId; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $requestPath -Encoding utf8
$cancelled = Invoke-FocusedProcess -CaseId 'requested' -ScriptPath $stage3Script -Arguments @(
    '-CancellationRequestPath', $requestPath, '-CancellationRunId', $runId,
    '-CancellationAcknowledgementPath', $ackPath)
if ($cancelled.ExitCode -ne 130 -or -not (Test-Path -LiteralPath $ackPath -PathType Leaf)) {
    throw 'A valid pre-start request did not produce exit 130 and acknowledgement'
}
$ack = Get-Content -LiteralPath $ackPath -Raw | ConvertFrom-Json
if ($ack.schemaVersion -ne 1 -or $ack.runId -cne $runId -or
    [int]$ack.targetProcessId -ne $cancelled.ProcessId -or
    [string]::IsNullOrWhiteSpace([string]$ack.observedAtUtc)) {
    throw 'Stage3 acknowledgement does not identify the target run and process'
}

$nestedRunId = 'nested-stage2-' + [guid]::NewGuid().ToString('N')
$nestedRequestPath = Join-Path $OutputDirectory 'nested-request.json'
$nestedParentAckPath = Join-Path $OutputDirectory 'nested-parent-ack.json'
$nestedChildAckPath = "$nestedParentAckPath.stage2"
@{ schemaVersion = 1; runId = $nestedRunId; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $nestedRequestPath -Encoding utf8
$nestedChild = Invoke-FocusedProcess -CaseId 'nested-stage2-child' `
    -ScriptPath (Join-Path $PSScriptRoot 'verify-selfhost-stage2.ps1') -Arguments @(
        '-CancellationRequestPath', $nestedRequestPath, '-CancellationRunId', $nestedRunId,
        '-CancellationAcknowledgementPath', $nestedChildAckPath)
if ($nestedChild.ExitCode -ne 130 -or -not (Test-Path -LiteralPath $nestedChildAckPath -PathType Leaf) -or
    (Test-Path -LiteralPath $nestedParentAckPath)) {
    throw 'Nested Stage2 did not acknowledge only its own cancellation path'
}
Initialize-VerificationCancellation -RequestPath $nestedRequestPath -RunId $nestedRunId `
    -AcknowledgementPath $nestedParentAckPath
$nestedParentCancelled = $false
try {
    Assert-VerificationCancellationNotRequested
} catch [OperationCanceledException] {
    $nestedParentCancelled = $true
}
$nestedChildAck = Get-Content -LiteralPath $nestedChildAckPath -Raw | ConvertFrom-Json
$nestedParentAck = Get-Content -LiteralPath $nestedParentAckPath -Raw | ConvertFrom-Json
if (-not $nestedParentCancelled -or $nestedChildAck.runId -cne $nestedRunId -or
    $nestedParentAck.runId -cne $nestedRunId -or
    [int]$nestedChildAck.targetProcessId -ne $nestedChild.ProcessId -or
    [int]$nestedParentAck.targetProcessId -ne $PID) {
    throw 'Nested Stage2 and Stage3 acknowledgement ownership is not separated'
}

$staleRequestPath = Join-Path $OutputDirectory 'stale.json'
$staleAckPath = Join-Path $OutputDirectory 'stale-ack.json'
@{ schemaVersion = 1; runId = 'old-run'; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $staleRequestPath -Encoding utf8
$stale = Invoke-FocusedProcess -CaseId 'stale-request' -ScriptPath $stage3Script -Arguments @(
    '-CancellationRequestPath', $staleRequestPath, '-CancellationRunId', 'new-run',
    '-CancellationAcknowledgementPath', $staleAckPath)
if ($stale.ExitCode -eq 0 -or $stale.ExitCode -eq 130 -or
    (Test-Path -LiteralPath $staleAckPath) -or
    (Get-Content -LiteralPath $stale.StderrPath -Raw) -notlike '*does not match the active verification target*') {
    throw 'Stale request was not rejected without acknowledgement'
}
$invalidSchemaPath = Join-Path $OutputDirectory 'invalid-schema.json'
$invalidSchemaAckPath = Join-Path $OutputDirectory 'invalid-schema-ack.json'
@{ schemaVersion = 2; runId = $runId; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $invalidSchemaPath -Encoding utf8
$invalidSchema = Invoke-FocusedProcess -CaseId 'invalid-schema' -ScriptPath $stage3Script -Arguments @(
    '-CancellationRequestPath', $invalidSchemaPath, '-CancellationRunId', $runId,
    '-CancellationAcknowledgementPath', $invalidSchemaAckPath)
if ($invalidSchema.ExitCode -eq 0 -or $invalidSchema.ExitCode -eq 130 -or
    (Test-Path -LiteralPath $invalidSchemaAckPath) -or
    (Get-Content -LiteralPath $invalidSchema.StderrPath -Raw) -notlike '*does not match the active verification target*') {
    throw 'Invalid request schema was not rejected without acknowledgement'
}

$duplicate = Invoke-FocusedProcess -CaseId 'duplicate-run-path' -ScriptPath $supervisorScript -Arguments @(
    '-Verification', 'Stage3', '-RunId', $runId,
    '-LogPath', (Join-Path $OutputDirectory 'duplicate.log'),
    '-CompletionRecordPath', (Join-Path $OutputDirectory 'duplicate.result.json'),
    '-CancellationRequestPath', $requestPath)
if ($duplicate.ExitCode -eq 0 -or
    (Get-Content -LiteralPath $duplicate.StderrPath -Raw) -notlike '*selected run paths already exist*' -or
    (Test-Path -LiteralPath (Join-Path $OutputDirectory 'duplicate.result.json'))) {
    throw 'Supervisor did not reject a reused cancellation request path before launch'
}

# Exercise the real publication functions with short, isolated files.
foreach ($functionSource in @(
    @{ Path = $stage3Script; Name = 'Write-Stage3PublicationRecord' },
    @{ Path = $supervisorScript; Name = 'Assert-Stage3PublicationComplete' },
    @{ Path = $supervisorScript; Name = 'Get-Stage3LateCancellationOutcome' },
    @{ Path = (Join-Path $PSScriptRoot 'request-detached-selfhost-cancellation.ps1'); Name = 'Assert-Stage3LateCancellation' },
    @{ Path = (Join-Path $PSScriptRoot 'request-detached-selfhost-cancellation.ps1'); Name = 'Add-Stage3LateCancellationOutcome' },
    @{ Path = (Join-Path $PSScriptRoot 'input-fingerprint-stability.ps1'); Name = 'Assert-InputFingerprintStable' }
)) {
    $tokens = $null
    $errors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $functionSource.Path, [ref]$tokens, [ref]$errors)
    $functionAst = $scriptAst.Find({ param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $functionSource.Name
    }, $true)
    if ($null -eq $functionAst) { throw "Publication function is missing: $($functionSource.Name)" }
    Invoke-Expression $functionAst.Extent.Text
}
$preCommitRunId = 'pre-commit-' + [guid]::NewGuid().ToString('N')
$preCommitRequestPath = Join-Path $OutputDirectory 'pre-commit-request.json'
$preCommitAckPath = Join-Path $OutputDirectory 'pre-commit-ack.json'
$preCommitMarkerPath = Join-Path $OutputDirectory 'pre-commit-marker.json'
Initialize-VerificationCancellation -RequestPath $preCommitRequestPath -RunId $preCommitRunId `
    -AcknowledgementPath $preCommitAckPath
Assert-VerificationCancellationNotRequested
Write-Stage3PublicationRecord -Path $preCommitMarkerPath -Record ([ordered]@{
    schemaVersion = 1
    runId = $preCommitRunId
    targetProcessId = $PID
    inputFingerprint = 'B' * 64
    committedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
})
$originalMarkerHash = (Get-FileHash -LiteralPath $preCommitMarkerPath -Algorithm SHA256).Hash
$duplicateMarkerRejected = $false
try {
    Write-Stage3PublicationRecord -Path $preCommitMarkerPath -Record @{ schemaVersion = 1 }
} catch [System.IO.IOException] {
    $duplicateMarkerRejected = $true
}
if (-not $duplicateMarkerRejected -or
    (Get-FileHash -LiteralPath $preCommitMarkerPath -Algorithm SHA256).Hash -cne $originalMarkerHash) {
    throw 'Publication marker creation overwrote an existing run marker'
}
@{ schemaVersion = 1; runId = $preCommitRunId; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $preCommitRequestPath -Encoding utf8
$preCommitCancelled = $false
try {
    Assert-VerificationCancellationNotRequested
} catch [OperationCanceledException] {
    Remove-Item -LiteralPath $preCommitMarkerPath
    $preCommitCancelled = $true
}
if (-not $preCommitCancelled -or (Test-Path -LiteralPath $preCommitMarkerPath) -or
    -not (Test-Path -LiteralPath $preCommitAckPath -PathType Leaf)) {
    throw 'Request between marker creation and publication was not acknowledged and aborted'
}
$repositoryRoot = Join-Path $OutputDirectory 'publication-stub'
$exampleArtifacts = Join-Path $repositoryRoot 'artifacts\example-tests'
$seedArtifacts = Join-Path $repositoryRoot 'artifacts\incremental-selfhost'
[void][IO.Directory]::CreateDirectory($exampleArtifacts)
[void][IO.Directory]::CreateDirectory($seedArtifacts)
$expectedFiles = [ordered]@{
    stage3Llvm = Join-Path $exampleArtifacts 'selfhost-stage3.ll'
    stage3Bitcode = Join-Path $exampleArtifacts 'selfhost-stage3.bc'
    stage3Executable = Join-Path $exampleArtifacts 'selfhost-stage3.exe'
    stage3InputReceipt = Join-Path $exampleArtifacts 'selfhost-stage3.inputs.sha256'
    stage3OutputReceipt = Join-Path $exampleArtifacts 'selfhost-stage3.outputs.sha256'
    seedExecutable = Join-Path $seedArtifacts 'selfhost-slg-seed.exe'
    seedHashReceipt = Join-Path $seedArtifacts 'selfhost-slg-seed.sha256'
    seedProvenance = Join-Path $seedArtifacts 'selfhost-slg-seed.stage3-seed.json'
}
$RunId = 'publication-stub-' + [guid]::NewGuid().ToString('N')
$targetProcessId = $PID
$fingerprint = 'A' * 64
Assert-InputFingerprintStable -ExpectedFingerprint $fingerprint -CurrentFingerprint $fingerprint -Phase 'Stage3 publication completion'
$driftRejected = $false
try {
    Assert-InputFingerprintStable -ExpectedFingerprint $fingerprint -CurrentFingerprint ('B' * 64) -Phase 'Stage3 publication completion'
} catch {
    $driftRejected = $true
}
if (-not $driftRejected) { throw 'Publication input drift was not rejected before the completion record' }
$stubRequestPath = Join-Path $OutputDirectory 'stub-after-commit-request.json'
$stage3PublicationCommitPath = "$stubRequestPath.commit.json"
$stage3PublicationCompletePath = "$stubRequestPath.published.json"
if ($null -ne (Get-Stage3LateCancellationOutcome -TargetExitCode 0 -OrphanCount 0)) {
    throw 'A run without a publication commit was classified as a late cancellation'
}
Write-Stage3PublicationRecord -Path $stage3PublicationCommitPath -Record ([ordered]@{
    schemaVersion = 1
    runId = $RunId
    targetProcessId = $targetProcessId
    inputFingerprint = $fingerprint
    committedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
})
@{ schemaVersion = 1; runId = $RunId; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
    ConvertTo-Json -Compress | Set-Content -LiteralPath $stubRequestPath -Encoding utf8
$incompleteOutcome = Get-Stage3LateCancellationOutcome -TargetExitCode 0 -OrphanCount 0
if ($incompleteOutcome.FailureId -cne 'STAGE3_PUBLICATION_INCOMPLETE') {
    throw 'A commit without completed publication was accepted'
}

[IO.File]::WriteAllText($expectedFiles.stage3Llvm, 'stage3 llvm')
[IO.File]::WriteAllText($expectedFiles.stage3Bitcode, 'stage3 bitcode')
[IO.File]::WriteAllText($expectedFiles.stage3Executable, 'stage3 executable')
[IO.File]::Copy($expectedFiles.stage3Executable, $expectedFiles.seedExecutable)
$llvmHash = (Get-FileHash -LiteralPath $expectedFiles.stage3Llvm -Algorithm SHA256).Hash
$bitcodeHash = (Get-FileHash -LiteralPath $expectedFiles.stage3Bitcode -Algorithm SHA256).Hash
$executableHash = (Get-FileHash -LiteralPath $expectedFiles.stage3Executable -Algorithm SHA256).Hash
[IO.File]::WriteAllText($expectedFiles.stage3InputReceipt, $fingerprint)
[IO.File]::WriteAllText($expectedFiles.stage3OutputReceipt,
    "llvm $llvmHash`nbitcode $bitcodeHash`nexecutable $executableHash")
[IO.File]::WriteAllText($expectedFiles.seedHashReceipt, $executableHash)
$outputReceiptHash = (Get-FileHash -LiteralPath $expectedFiles.stage3OutputReceipt -Algorithm SHA256).Hash
[ordered]@{
    schemaVersion = 1
    mode = 'verified-selfhost-stage3-seed'
    producer = 'verify-selfhost-stage3.ps1'
    publishedByStage3Gate = $true
    seedFingerprint = $executableHash
    stage3 = [ordered]@{
        executableFingerprint = $executableHash
        llvmFingerprint = $llvmHash
        bitcodeFingerprint = $bitcodeHash
        outputReceiptFingerprint = $outputReceiptHash
        inputFingerprint = $fingerprint
    }
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $expectedFiles.seedProvenance -Encoding utf8
$fileRecords = @($expectedFiles.GetEnumerator() | ForEach-Object {
    [ordered]@{
        role = $_.Key
        path = [IO.Path]::GetFullPath($_.Value)
        sha256 = (Get-FileHash -LiteralPath $_.Value -Algorithm SHA256).Hash
    }
})
Write-Stage3PublicationRecord -Path $stage3PublicationCompletePath -Record ([ordered]@{
    schemaVersion = 1
    runId = $RunId
    targetProcessId = $targetProcessId
    inputFingerprint = $fingerprint
    completedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    files = $fileRecords
})
$lateOutcome = Get-Stage3LateCancellationOutcome -TargetExitCode 0 -OrphanCount 0
if ($lateOutcome.Disposition -cne 'afterCommit' -or $lateOutcome.FailureId -cne '' -or
    (Get-Stage3LateCancellationOutcome -TargetExitCode 1 -OrphanCount 0).FailureId -cne 'STAGE3_PUBLICATION_FAILED' -or
    (Get-Stage3LateCancellationOutcome -TargetExitCode 0 -OrphanCount 1).FailureId -cne 'ORPHAN_PROCESSES_REMAIN') {
    throw 'Late cancellation did not distinguish complete, failed, and orphaned publication'
}
$stubCommitHash = (Get-FileHash -LiteralPath $stage3PublicationCommitPath -Algorithm SHA256).Hash
$stubCompleteHash = (Get-FileHash -LiteralPath $stage3PublicationCompletePath -Algorithm SHA256).Hash
$stubLaunch = [pscustomobject]@{ runId = $RunId; verification = 'Stage3' }
$stubResult = [pscustomobject]@{
    verification = 'Stage3'
    cancellationDisposition = 'afterCommit'
    status = 'passed'
    exitCode = 0
    targetExitCode = 0
    failureIds = @()
    cancellationAcknowledgement = $null
    publicationMayBePartial = $false
    targetProcessId = $targetProcessId
    stage3PublicationCommitSha256 = $stubCommitHash
    stage3PublicationCompleteSha256 = $stubCompleteHash
}
Assert-Stage3LateCancellation -Result $stubResult -Launch $stubLaunch -RequestPath $stubRequestPath
Add-Stage3LateCancellationOutcome -Result $stubResult
if ($stubResult.cancellationRequestOutcome -cne 'accepted-after-publication-commit-not-stopped' -or
    $stubResult.cancellationRequestMessage -notlike '*was not stopped*') {
    throw 'Public cancellation command did not explicitly report the late request outcome'
}
$stubResult.publicationMayBePartial = $true
$partialRejected = $false
try { Assert-Stage3LateCancellation -Result $stubResult -Launch $stubLaunch -RequestPath $stubRequestPath }
catch { $partialRejected = $true }
$stubResult.publicationMayBePartial = $false
$stubResult.stage3PublicationCompleteSha256 = 'C' * 64
$hashRejected = $false
try { Assert-Stage3LateCancellation -Result $stubResult -Launch $stubLaunch -RequestPath $stubRequestPath }
catch { $hashRejected = $true }
$stubResult.stage3PublicationCompleteSha256 = $stubCompleteHash
$stubLaunch.runId = 'other-run'
$identityRejected = $false
try { Assert-Stage3LateCancellation -Result $stubResult -Launch $stubLaunch -RequestPath $stubRequestPath }
catch { $identityRejected = $true }
if (-not $partialRejected -or -not $hashRejected -or -not $identityRejected) {
    throw 'Public cancellation command accepted partial, hash-mismatched, or wrong-run publication'
}
[IO.File]::AppendAllText($expectedFiles.stage3Llvm, ' changed')
if ((Get-Stage3LateCancellationOutcome -TargetExitCode 0 -OrphanCount 0).FailureId -cne 'STAGE3_PUBLICATION_INCOMPLETE') {
    throw 'Published file drift was accepted as a late cancellation success'
}

$probeRunId = 'stage3-supervisor-probe-' + [guid]::NewGuid().ToString('N')
$probeResultPath = Join-Path $OutputDirectory 'supervisor-probe.result.json'
$probeLogPath = Join-Path $OutputDirectory 'supervisor-probe.log'
$probeLaunch = & $supervisorScript -Verification Probe -ProbeOutcome CooperativeWait `
    -RunId $probeRunId -LogPath $probeLogPath -CompletionRecordPath $probeResultPath | ConvertFrom-Json
if ($probeLaunch.runId -cne $probeRunId -or $probeLaunch.verification -cne 'Probe') {
    throw 'Focused supervisor probe did not return the selected run identity'
}
$probeResult = & (Join-Path $PSScriptRoot 'request-detached-selfhost-cancellation.ps1') `
    -CompletionRecordPath $probeResultPath -TimeoutSeconds 20 | ConvertFrom-Json
if ($probeResult.status -cne 'cancelled' -or $probeResult.exitCode -ne 130 -or
    $probeResult.targetExitCode -ne 130 -or @($probeResult.failureIds).Count -ne 1 -or
    $probeResult.failureIds[0] -cne 'CANCELLATION_REQUESTED' -or
    @($probeResult.orphanProcessIds).Count -ne 0 -or
    [int]$probeResult.cancellationAcknowledgement.targetProcessId -ne [int]$probeResult.targetProcessId) {
    throw 'Supervisor probe did not preserve exact cooperative cancellation and zero orphans'
}
$resultSchemaPath = Join-Path $PSScriptRoot 'contracts/detached-selfhost-verification-result.schema.json'
if (-not ((Get-Content -LiteralPath $probeResultPath -Raw) |
        Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw 'Supervised cancellation does not match the completion schema'
}
$lateRecord = Get-Content -LiteralPath $probeResultPath -Raw | ConvertFrom-Json
$lateRecord.verification = 'Stage3'
$lateRecord.status = 'passed'
$lateRecord.exitCode = 0
$lateRecord.targetExitCode = 0
$lateRecord.failureIds = @()
$lateRecord.cancellationAcknowledgement = $null
$lateRecord.cancellationDisposition = 'afterCommit'
$lateRecord.stage3PublicationCommitSha256 = $stubCommitHash
$lateRecord.stage3PublicationCompleteSha256 = $stubCompleteHash
$lateRecord.publicationMayBePartial = $false
if (-not (($lateRecord | ConvertTo-Json -Depth 12) |
        Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw 'Validated late completion does not match the completion schema'
}
$lateRecord.status = 'cancelled'
if (($lateRecord | ConvertTo-Json -Depth 12) |
    Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
    throw 'The completion schema accepted afterCommit as cancelled'
}
$lateRecord.status = 'failed'
$lateRecord.exitCode = 1
$lateRecord.targetExitCode = 1
$lateRecord.failureIds = @('STAGE3_PUBLICATION_INPUT_DRIFT')
$lateRecord.cancellationDisposition = 'notHonored'
$lateRecord.publicationMayBePartial = $true
if (-not (($lateRecord | ConvertTo-Json -Depth 12) |
        Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw 'The completion schema rejected an explicit post-commit input-drift failure'
}

Write-Host "PASS Stage3 cancellation contract: pre/post-commit stub, nested Stage2 acknowledgement, work boundaries, invalid requests, duplicate run path, supervised cancellation. Output: $OutputDirectory"
