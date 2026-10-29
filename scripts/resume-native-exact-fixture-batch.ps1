[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$PhaseExecutionContract,
    [Parameter(Mandatory)][string]$PreviousBatch,
    [Parameter(Mandatory)][string]$PreviousBatchSha256,
    [Parameter(Mandatory)][string]$ShutdownAudit,
    [Parameter(Mandatory)][string]$OriginalOutputDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$CompletedPendingBatch = '',
    [string]$CompletedPendingBatchSha256 = '',
    [string]$Label = 'selfhost',
    [string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1,64)][int]$Jobs = 4,
    [ValidateRange(1000,180000)][int]$TimeoutMilliseconds = 180000,
    [string]$CancellationRequestPath = '',
    [string]$CancellationRunId = '',
    [string]$CancellationAcknowledgementPath = '',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'native-exact-batch-allocation.ps1')
. (Join-Path $PSScriptRoot 'native-exact-source-closure.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')

function Get-RetainedExactCase {
    param([string]$FixtureName, [int]$CompilerJobs, [bool]$PhaseCase,
        [string]$CaseOutputDirectory = $originalOutput, [string]$CaseLabel = $Label)
    $expectedRoot = Join-Path $repositoryPath 'examples/regression/expected'
    $source = Join-Path $repositoryPath "examples/regression/$FixtureName.slg"
    $manifest = Join-Path $expectedRoot "$FixtureName.sources.txt"
    $inputs = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        foreach ($line in [IO.File]::ReadAllLines($manifest)) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $inputs.Add((Resolve-Path -LiteralPath (Join-Path $repositoryPath $line.Trim())).Path)
            }
        }
        if ($source -cnotin $inputs) { throw 'NATIVE_RESUME_MANIFEST_ROOT_MISSING' }
    } else { $inputs.Add($source) }
    Assert-NativeExactCompilerSourceClosure -RepositoryRoot $repositoryPath -Fixture $FixtureName -SourcePath @($inputs | Where-Object { $_.EndsWith('.slg') })
    $expected = Join-Path $expectedRoot "$FixtureName.stdout.txt"
    foreach ($suffix in @('compiler.stderr.exact.txt','args.txt')) {
        $candidate = Join-Path $expectedRoot "$FixtureName.$suffix"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $inputs.Add($candidate) }
    }
    # Fingerprinting preserves the verifier's input sequence, not just its set.
    if (Test-Path -LiteralPath $manifest -PathType Leaf) { $inputs.Add($manifest) }
    $inputs.Add($expected)
    if ((Test-Path -LiteralPath (Join-Path $expectedRoot "$FixtureName.compiler.stderr.exact.txt")) -and
        (Test-Path -LiteralPath (Join-Path $expectedRoot "$FixtureName.compiler.stderr.contains.txt"))) {
        throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_AMBIGUOUS'
    }
    $side = if ($PhaseCase) { 'selfhost' } else { '' }
    $contracts = Get-NativeExactLlvmContracts -ExpectedRoot $expectedRoot -Fixture $FixtureName `
        -CompilerIsManagedDll $false -CompilerSide $side -PhaseContractProvided $PhaseCase
    foreach ($path in $contracts.InputPaths) { $inputs.Add($path) }
    $fingerprint = Get-NativeExactPerFixtureInputFingerprint -RepositoryRoot $repositoryPath `
        -CommonFingerprint $commonInputFingerprint -Fixture $FixtureName -Label $CaseLabel `
        -Platform windows -Distribution Ubuntu -Jobs $CompilerJobs -ExpectedStdoutLength 0 -InputPath $inputs.ToArray()
    $artifact = Join-Path $CaseOutputDirectory "$CaseLabel-exact-$FixtureName.exe"
    if (-not (Test-NativeExactFixtureReceipt -InputFingerprint $fingerprint `
            -InputReceiptPath "$artifact.inputs.sha256" -OutputReceiptPath "$artifact.outputs.sha256" `
            -LlvmPath "$artifact.ll" -BitcodePath "$artifact.bc" -ExecutablePath $artifact)) {
        throw "NATIVE_RESUME_RETAINED_CASE_CHANGED: $FixtureName"
    }
    $records = @(Get-ChildItem -LiteralPath $CaseOutputDirectory -File -Filter "$CaseLabel-$FixtureName.case-*.execution.json")
    $accepted = @()
    foreach ($file in $records) {
        $record = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($record.status -ceq 'passed' -and $record.exit -eq 0 -and $record.processesStopped -eq $true -and
            $record.failure -eq $null -and $record.pid -gt 0) {
            $command = @($record.command)
            if ($command -cnotcontains '-Fixture' -or $command[$command.IndexOf('-Fixture')+1] -cne $FixtureName -or
                $command -cnotcontains '-Compiler' -or $command[$command.IndexOf('-Compiler')+1] -cne $compilerPath -or
                $command -cnotcontains '-Jobs' -or [int]$command[$command.IndexOf('-Jobs')+1] -ne $CompilerJobs -or
                $command -cnotcontains '-TimeoutMilliseconds' -or [int]$command[$command.IndexOf('-TimeoutMilliseconds')+1] -ne $TimeoutMilliseconds -or
                $command -cnotcontains '-OutputDirectory' -or [IO.Path]::GetFullPath($command[$command.IndexOf('-OutputDirectory')+1]) -cne $CaseOutputDirectory) {
                throw 'NATIVE_RESUME_CASE_COMMAND_MISMATCH'
            }
            $elapsed = ([DateTimeOffset]$record.finishedAtUtc - [DateTimeOffset]$record.startedAtUtc).TotalMilliseconds
            if ($elapsed -lt 0 -or $elapsed -gt $TimeoutMilliseconds) { throw 'NATIVE_RESUME_CASE_BUDGET_INVALID' }
            $accepted += $file
        }
    }
    if ($accepted.Count -ne 1) { throw "NATIVE_RESUME_CASE_COMPLETION_AMBIGUOUS: $FixtureName" }
    [pscustomobject]@{fixture=$FixtureName; inputFingerprint=$fingerprint;
        outputDirectory=$CaseOutputDirectory; label=$CaseLabel;
        completion=(Get-NativeExactPhaseReference $repositoryPath $accepted[0].FullName);
        inputs=(Get-NativeExactPhaseReference $repositoryPath "$artifact.inputs.sha256");
        outputs=(Get-NativeExactPhaseReference $repositoryPath "$artifact.outputs.sha256")}
}

function Assert-RetainedExactCaseReferences {
    param([object[]]$Cases)
    foreach ($case in $Cases) {
        foreach ($reference in @($case.completion,$case.inputs,$case.outputs)) {
            # Input/output hash records are plain text, not JSON documents.
            $actual = Get-NativeExactPhaseReference $repositoryPath $reference.path
            if ($actual.sha256 -ine $reference.sha256) { throw 'NATIVE_RESUME_CASE_REFERENCE_CHANGED' }
        }
    }
}

$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if ($Label -cne 'selfhost') { throw 'NATIVE_RESUME_SELFHOST_LABEL_REQUIRED' }
if (-not [string]::IsNullOrWhiteSpace($CancellationRequestPath)) {
    Initialize-VerificationCancellation -RequestPath $CancellationRequestPath -RunId $CancellationRunId `
        -AcknowledgementPath $CancellationAcknowledgementPath
}
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmPath = (Resolve-Path -LiteralPath $LlvmRoot).Path
$stdlibPath = (Resolve-Path -LiteralPath $StdlibRoot).Path
$originalOutput = (Resolve-Path -LiteralPath $OriginalOutputDirectory).Path
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
[void](Assert-NativeExactPhaseOutputPath $repositoryPath $outputPath)
if ($outputPath -ceq $originalOutput -or (Test-Path -LiteralPath $outputPath)) { throw 'NATIVE_RESUME_NEW_OUTPUT_REQUIRED' }
if ((Get-FileHash -LiteralPath $PreviousBatch -Algorithm SHA256).Hash -ine $PreviousBatchSha256) { throw 'NATIVE_RESUME_PREVIOUS_BATCH_CHANGED' }
$previous = Get-Content -LiteralPath $PreviousBatch -Raw | ConvertFrom-Json
$audit = Get-Content -LiteralPath $ShutdownAudit -Raw | ConvertFrom-Json
if (@($audit.activeOwnedProcessIds).Count -ne 0 -or @($audit.activeMatchingProcessIds).Count -ne 0 -or
    $audit.outputsPreserved -ne $true -or [int]$audit.rootPid -le 0) { throw 'NATIVE_RESUME_SHUTDOWN_AUDIT_REQUIRED' }
$live = @(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq $audit.rootPid -or
    ($_.Name -in @('compiler.exe','clang.exe','llvm-as.exe') -and $_.CommandLine -and $_.CommandLine.Contains($originalOutput)) })
if ($live.Count -gt 0) { throw 'NATIVE_RESUME_PREVIOUS_PROCESS_STILL_ACTIVE' }
$context = Get-NativeExactPhaseContext $repositoryPath $PhaseExecutionContract selfhost $compilerPath $PSCommandPath
$plan = @($context.Contract.wholeFixturePlan)
if ($previous.schemaVersion -ne 1 -or $previous.state -cnotin @('running','cancelled') -or
    $previous.label -cne $Label -or $previous.platform -cne 'windows' -or
    $previous.compilerSha256 -ine $context.CompilerBinary.sha256 -or $previous.total -ne $plan.Count -or
    (@($previous.phaseFixturePlan) -join "`0") -cne ($plan -join "`0") -or $previous.failed -ne 0 -or
    $previous.completed -ne $previous.passed -or $previous.completed -ne @($previous.results).Count -or
    $previous.missing -ne $previous.total-$previous.completed -or
    @($previous.results | Where-Object { $_.Success -ne $true -or $_.Error -cne '' -or $_.Fixture -cnotin $plan }).Count -gt 0 -or
    @($previous.results.Fixture | Sort-Object -Unique).Count -ne $previous.completed) { throw 'NATIVE_RESUME_PREVIOUS_SCOPE_INVALID' }
$batchPath = [IO.Path]::GetFullPath($context.Contract.batchReports.selfhost,$repositoryPath)
if ([IO.Path]::GetDirectoryName($batchPath) -cne $originalOutput -or
    (Get-FileHash -LiteralPath $batchPath -Algorithm SHA256).Hash -ine $PreviousBatchSha256) { throw 'NATIVE_RESUME_ORIGINAL_REPORT_CHANGED' }
$commonInputFingerprint = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $repositoryPath `
    -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
if ($previous.commonInputFingerprint -cne $commonInputFingerprint) { throw 'NATIVE_RESUME_COMMON_INPUT_CHANGED' }
$allocation = Get-NativeExactBatchAllocation -Fixture $plan -Jobs $Jobs -MinimumCompilerJobs 1
$phaseFixtures = @($context.Contract.cases | Where-Object { 'run' -cin @($_.expectedStages.PSObject.Properties.Name) } |
    ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.fixture.path) })
$acceptedRows = @($previous.results)
$caseDirectories = @{}
foreach ($row in $acceptedRows) { $caseDirectories[$row.Fixture]=$originalOutput }
$priorPendingCount = 0
if (-not [string]::IsNullOrWhiteSpace($CompletedPendingBatch)) {
    if ((Get-FileHash -LiteralPath $CompletedPendingBatch -Algorithm SHA256).Hash -ine $CompletedPendingBatchSha256) {
        throw 'NATIVE_RESUME_PENDING_BATCH_CHANGED'
    }
    $prior = Get-Content -LiteralPath $CompletedPendingBatch -Raw | ConvertFrom-Json
    $priorOutput = [IO.Path]::GetDirectoryName((Resolve-Path -LiteralPath $CompletedPendingBatch).Path)
    if ($prior.state -cnotin @('running','cancelled') -or $prior.compilerSha256 -ine $context.CompilerBinary.sha256 -or
        $prior.commonInputFingerprint -cne $commonInputFingerprint -or $prior.label -cne $Label -or
        $prior.platform -cne 'windows' -or $prior.total -ne $plan.Count -or $prior.failed -ne 0 -or
        $prior.completed -ne $prior.passed -or $prior.completed -ne @($prior.results).Count -or
        $prior.missing -ne $prior.total-$prior.completed -or
        (@($prior.phaseFixturePlan) -join "`0") -cne ($plan -join "`0") -or
        @($prior.results.Fixture | Sort-Object -Unique).Count -ne $prior.completed -or
        @($prior.results | Where-Object { $_.Success -ne $true -or $_.Error -cne '' -or $_.Fixture -cnotin $plan }).Count -gt 0 -or
        $prior.resumeOf.sha256 -ine $PreviousBatchSha256) { throw 'NATIVE_RESUME_PENDING_SCOPE_INVALID' }
    foreach ($row in $previous.results) {
        if (@($prior.results | Where-Object { $_.Fixture -ceq $row.Fixture -and $_.Success -eq $true -and $_.Error -ceq '' }).Count -ne 1) {
            throw 'NATIVE_RESUME_PRIOR_COMPLETION_MISSING'
        }
    }
    $additional = @($prior.results | Where-Object { $_.Fixture -cnotin @($previous.results.Fixture) })
    foreach ($row in $additional) {
        if ([IO.Path]::GetFullPath($row.outputDirectory) -cne $priorOutput) { throw 'NATIVE_RESUME_PRIOR_OUTPUT_BOUNDARY' }
        $caseDirectories[$row.Fixture]=$priorOutput
    }
    $acceptedRows += $additional
    $priorPendingCount=$additional.Count
}
$retained = @($allocation.Items | Where-Object { $_.Fixture -cin @($acceptedRows.Fixture) } | ForEach-Object {
    Assert-VerificationCancellationNotRequested
    Get-RetainedExactCase $_.Fixture $_.CompilerWorkerJobs ($_.Fixture -cin $phaseFixtures) $caseDirectories[$_.Fixture]
})
$pending = @($allocation.Items | Where-Object { $_.Fixture -cnotin @($acceptedRows.Fixture) })
[void][IO.Directory]::CreateDirectory($outputPath)
$validationPath = Join-Path $outputPath 'reuse-validation.json'
$validation = [ordered]@{schemaVersion=1; status='retained-completions-validated'; observedAtUtc=[DateTime]::UtcNow.ToString('o');
    previousBatch=(Get-NativeExactPhaseReference $repositoryPath $PreviousBatch);
    shutdownAudit=(Get-NativeExactPhaseReference $repositoryPath $ShutdownAudit);
    compiler=$context.CompilerBinary; commonInputFingerprint=$commonInputFingerprint; retained=$retained;
    originalReused=@($previous.results).Count; priorPendingReused=$priorPendingCount;
    reused=$retained.Count; pending=$pending.Count; total=$plan.Count; claimsGoalComplete=$false}
if ($CompletedPendingBatch) { $validation.completedPendingBatch=Get-NativeExactPhaseReference $repositoryPath $CompletedPendingBatch }
[IO.File]::WriteAllText($validationPath,($validation|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
if ($ValidateInputsOnly) {
    Write-Host "[native exact resume] inputs verified; reused=$($retained.Count), pending=$($pending.Count), compiler not launched."
    return
}

# The original report and all old products remain unchanged while pending cases
# run in a fresh directory. Only a fully authenticated accumulation is published
# at the contract's whole-batch path; its byte-exact interrupted predecessor and
# the reuse/execution references are retained beside the new execution.
Copy-Item -LiteralPath $PreviousBatch -Destination (Join-Path $outputPath 'interrupted-batch.json')
$results = [Collections.Generic.List[object]]::new()
foreach ($row in $acceptedRows) { $results.Add($row) }
$resumeReportPath = Join-Path $outputPath "$Label-batch-results.json"
function Write-ResumeBatchReport {
    param([ValidateSet('running','passed','failed','cancelled')][string]$State)
    $passedCount = @($results | Where-Object Success).Count
    $report = [ordered]@{schemaVersion=1;label=$Label;platform='windows';state=$State;
        compilerSha256=$context.CompilerBinary.sha256;commonInputFingerprint=$commonInputFingerprint;
        completed=$results.Count;passed=$passedCount;failed=$results.Count-$passedCount;
        missing=$plan.Count-$results.Count;total=$plan.Count;results=@($results);
        phaseFixturePlan=$plan;resumeOf=$validation.previousBatch;
        reuseValidation=(Get-NativeExactPhaseReference $repositoryPath $validationPath);
        reused=$retained.Count;newlyExecuted=$results.Count-$retained.Count}
    [IO.File]::WriteAllText($resumeReportPath,($report|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
}

# Already accepted outcomes are immutable. An unaccepted partial witness must
# be reviewed explicitly rather than overwritten by a retry.
foreach ($case in $context.Contract.cases | Where-Object {
        [IO.Path]::GetFileNameWithoutExtension($_.fixture.path) -cin $phaseFixtures -and
        [IO.Path]::GetFileNameWithoutExtension($_.fixture.path) -cnotin @($acceptedRows.Fixture) }) {
    $prefix = Get-NativeExactPhaseOutcomePrefix $context $case
    foreach ($stage in @('compile','run')) {
        if (Test-Path -LiteralPath "$prefix.$stage.json") { throw 'NATIVE_RESUME_UNACCEPTED_PHASE_OUTCOME_PROTECTED' }
    }
}
Write-ResumeBatchReport running
$verifierPath = Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1'
$fixtureHelper = Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'
$processHelper = Join-Path $PSScriptRoot 'verification-process.ps1'
$pending | ForEach-Object -ThrottleLimit $allocation.Parallelism -Parallel {
    $fixtureName = $_.Fixture
    try {
        . $using:fixtureHelper
        . $using:processHelper
        if (-not [string]::IsNullOrWhiteSpace($using:CancellationRequestPath)) {
            Initialize-VerificationCancellation $using:CancellationRequestPath $using:CancellationRunId $using:CancellationAcknowledgementPath
        }
        Assert-VerificationCancellationNotRequested
        $phaseContract = ''; $side = ''
        if ($fixtureName -cin $using:phaseFixtures) { $phaseContract=$using:PhaseExecutionContract; $side='selfhost' }
        $parameters = [ordered]@{Compiler=$using:compilerPath;Label=$using:Label;Fixture=$fixtureName;
            Platform='windows';Distribution='Ubuntu';LlvmRoot=$using:llvmPath;StdlibRoot=$using:stdlibPath;
            RepositoryRoot=$using:repositoryPath;OutputDirectory=$using:outputPath;
            Jobs=$_.CompilerWorkerJobs;TimeoutMilliseconds=$using:TimeoutMilliseconds;
            CommonInputFingerprint=$using:commonInputFingerprint;PhaseExecutionContract=$phaseContract;CompilerSide=$side;
            CancellationRequestPath=$using:CancellationRequestPath;CancellationRunId=$using:CancellationRunId;
            CancellationAcknowledgementPath=$using:CancellationAcknowledgementPath}
        $null = Invoke-NativeExactBudgetedFixture $using:verifierPath $parameters
        [pscustomobject]@{Fixture=$fixtureName;Success=$true;Error='';outputDirectory=$using:outputPath}
    } catch {
        [pscustomobject]@{Fixture=$fixtureName;Success=$false;Error="$($_.Exception.Message)`n$($_.ScriptStackTrace)";
            outputDirectory=$using:outputPath}
    }
} | ForEach-Object {
    $results.Add($_)
    Write-ResumeBatchReport running
    Write-Host "[native exact resume $($results.Count)/$($plan.Count)] success=$($_.Success) $($_.Fixture)"
    if (-not $_.Success) { Write-Host $_.Error }
}
if (Test-VerificationCancellationRequested) {
    Write-ResumeBatchReport cancelled
    throw [OperationCanceledException]::new('CANCELLATION_REQUESTED')
}
if ($results.Count -ne $plan.Count -or @($results | Where-Object { -not $_.Success }).Count -gt 0) {
    Write-ResumeBatchReport failed
    throw 'NATIVE_RESUME_PENDING_CASES_FAILED'
}
# Recompute current inputs and output hashes, including old accepted cases,
# after the final child exits. Completion JSON alone is insufficient for reuse.
if ((Get-NativeExactWindowsCommonInputFingerprint $repositoryPath $compilerPath $stdlibPath $llvmPath) -cne $commonInputFingerprint) {
    throw 'NATIVE_RESUME_COMMON_INPUT_CHANGED'
}
$endCases = @($allocation.Items | ForEach-Object {
    Assert-VerificationCancellationNotRequested
    $directory = if ($caseDirectories.ContainsKey($_.Fixture)) { $caseDirectories[$_.Fixture] } else { $outputPath }
    Get-RetainedExactCase $_.Fixture $_.CompilerWorkerJobs ($_.Fixture -cin $phaseFixtures) $directory
})
Assert-RetainedExactCaseReferences $retained
if ($CompletedPendingBatch -and (Get-FileHash -LiteralPath $CompletedPendingBatch -Algorithm SHA256).Hash -ine $CompletedPendingBatchSha256) {
    throw 'NATIVE_RESUME_PENDING_BATCH_CHANGED'
}
[IO.File]::WriteAllText((Join-Path $outputPath 'completed-cases.json'),($endCases|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
[void](Get-NativeExactPhaseCommandInputs $context)
if ((Get-FileHash -LiteralPath $batchPath -Algorithm SHA256).Hash -ine $PreviousBatchSha256) {
    throw 'NATIVE_RESUME_ORIGINAL_REPORT_CHANGED'
}
Write-ResumeBatchReport passed
Copy-Item -LiteralPath $resumeReportPath -Destination $batchPath
foreach ($fixtureName in $phaseFixtures | Where-Object { $_ -cnotin $plan }) {
    Assert-VerificationCancellationNotRequested
    $parameters = [ordered]@{Compiler=$compilerPath;Label="$Label-phase-extra";Fixture=$fixtureName;
        Platform='windows';Distribution='Ubuntu';LlvmRoot=$llvmPath;StdlibRoot=$stdlibPath;
        RepositoryRoot=$repositoryPath;OutputDirectory=$outputPath;Jobs=$Jobs;TimeoutMilliseconds=$TimeoutMilliseconds;
        PhaseExecutionContract=$PhaseExecutionContract;CompilerSide='selfhost';
        CancellationRequestPath=$CancellationRequestPath;CancellationRunId=$CancellationRunId;
        CancellationAcknowledgementPath=$CancellationAcknowledgementPath}
    $null = Invoke-NativeExactBudgetedFixture $verifierPath $parameters
    Write-Host "[native exact resume extra] PASS $fixtureName"
}
if (-not (Complete-NativeExactPhaseExecution $context)) { throw 'NATIVE_RESUME_PHASE_OUTCOMES_INCOMPLETE' }
$completion = [ordered]@{schemaVersion=1;status='passed';completed=$plan.Count;total=$plan.Count;
    reused=$retained.Count;newlyExecuted=$pending.Count;phaseWitnesses=@($context.Contract.cases).Count;
    originalReused=@($previous.results).Count;priorPendingReused=$priorPendingCount;
    inputStable=$true;processesStopped=$true;claimsGoalComplete=$false;
    batch=(Get-NativeExactPhaseReference $repositoryPath $batchPath);
    reuseValidation=(Get-NativeExactPhaseReference $repositoryPath $validationPath);
    completedCases=(Get-NativeExactPhaseReference $repositoryPath (Join-Path $outputPath 'completed-cases.json'));
    completedAtUtc=[DateTime]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $outputPath 'completion.json'),($completion|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Write-Host "[native exact resume] PASS $($plan.Count) cases and $(@($context.Contract.cases).Count) phase witnesses."
