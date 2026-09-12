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
    $PSCommandPath, $launcherPath, $resultSchemaPath,
    (Join-Path $PSScriptRoot 'expression-batch-selection.ps1'),
    (Join-Path $PSScriptRoot 'verify-expression-lowering-focused-batch.ps1'),
    (Join-Path $PSScriptRoot 'contracts/expression-batch-selection.schema.json'),
    (Join-Path $PSScriptRoot 'contracts/fixtures/detached-verification-probe.ps1')
)
$inputHashes = @($contractPaths | ForEach-Object { Get-FileHash -LiteralPath $_ -Algorithm SHA256 } |
    Select-Object Path, Hash)
Start-Transcript -LiteralPath (Join-Path $scratchRoot "$runId.contract.log") | Out-Null
try {

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
    [ordered]@{ Verification = "Stage3Linux"; Stage = "linux-stage3"; Current = 2; Completed = 1; Total = 3; Percent = 33.3 }
)) {
    $linuxRunId = "$runId-$($linuxProgressCase.Verification.ToLowerInvariant())"
    $linuxLogPath = Join-Path $scratchRoot "$linuxRunId.log"
    $linuxCompletionRecordPath = Join-Path $scratchRoot "$linuxRunId.result.json"
    "[$($linuxProgressCase.Stage) $($linuxProgressCase.Current)/$($linuxProgressCase.Total)] active" |
        Set-Content -LiteralPath $linuxLogPath -Encoding utf8
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
foreach ($kind in @('Incremental', 'ExpressionBatch', 'ManagedHost')) {
    $incrementalSuccess = $passResultJson | ConvertFrom-Json
    $incrementalSuccess.verification = $kind
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
    -ProbeOutcome Wait `
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
$cancelProgress = & $progressReaderPath -CompletionRecordPath $cancelCompletionRecordPath | ConvertFrom-Json
if ($cancelProgress.status -cne "cancelled" -or $cancelProgress.exitCode -eq 0) {
    throw "cancelled detached progress state is incorrect"
}

Write-Host "[detached selfhost verification] PASS supported cancellation preserved cancelled, non-zero exit, CANCELLATION_REQUESTED, and zero orphans."
$contractChecks.Add('legacy-cancellation')

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

if ($passResult.schemaVersion -ne 2 -or -not $passResult.processAudit.completed -or
    $passResult.processAudit.snapshotCount -lt 1) { throw 'New successful result is missing an actual process audit' }
foreach ($invalidAudit in @('missing', 'incomplete', 'unobserved')) {
    $invalid = $passResultJson | ConvertFrom-Json
    switch ($invalidAudit) {
        'missing' { $invalid.PSObject.Properties.Remove('processAudit') }
        'incomplete' { $invalid.processAudit.completed = $false }
        'unobserved' { $invalid.processAudit.observedProcessIds = @() }
    }
    if (($invalid | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
        throw "Schema accepted $invalidAudit audit as v2 success"
    }
}
$legacy = $passResultJson | ConvertFrom-Json
$legacy.schemaVersion = 1
$legacy.PSObject.Properties.Remove('processAudit')
$legacy.PSObject.Properties.Remove('targetExitCode')
if (-not (($legacy | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $resultSchemaPath)) {
    throw 'Historical v1 results lost schema compatibility'
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
if ($contractChecks.Count -ne 13) { throw "Incomplete harness groups: $($contractChecks.Count)/13" }
$contractStatus = 'passed'
} catch {
    $contractError = $_.Exception.Message
    throw
} finally {
    [ordered]@{
        schemaVersion = 1; state = $contractStatus; runId = $runId
        passed = $contractChecks.Count; total = 13; groups = @($contractChecks)
        error = $contractError; inputHashes = $inputHashes
        durationMilliseconds = [math]::Round(([DateTimeOffset]::UtcNow - $contractStarted).TotalMilliseconds)
        scope = 'Detached harness and input dispatch only; no compiler build or Stage execution'
    } | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $scratchRoot "$runId.contract-result.json") -Encoding utf8
    Stop-Transcript | Out-Null
}
Write-Host "[detached selfhost verification] PASS 13/13 groups: $(Join-Path $scratchRoot "$runId.contract-result.json")"
