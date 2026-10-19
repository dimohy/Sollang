param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$helper = Join-Path $PSScriptRoot 'verification-process.ps1'
. $helper
$initialHash = (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'EXECUTION_RECORD_TEST_OUTPUT_EXISTS' }
[void][IO.Directory]::CreateDirectory($output)
$cases = [Collections.Generic.List[object]]::new()
foreach ($case in @(
    @{ id = 'normal'; code = "import sys; print('out'); print('err',file=sys.stderr)"; expectedExit = 0; throws = $false; timeout = 30000 },
    @{ id = 'nonzero'; code = 'import sys; sys.exit(7)'; expectedExit = 7; throws = $false; timeout = 30000 },
    @{ id = 'timeout'; code = 'import time; time.sleep(30)'; expectedExit = $null; throws = $true; timeout = 50 },
    @{ id = 'cancellation'; code = 'import time; time.sleep(0.2)'; expectedExit = 0; throws = $true; timeout = 30000 }
)) {
    $journal = Join-Path $output "$($case.id).json"
    if ($case.id -eq 'cancellation') {
        $request = Join-Path $output 'cancel-request.json'
        @{ schemaVersion = 1; runId = 'execution-record-control'; requestedAtUtc = [DateTimeOffset]::UtcNow.ToString('O') } |
            ConvertTo-Json | Set-Content -LiteralPath $request -Encoding utf8
        Initialize-VerificationCancellation -RequestPath $request -RunId 'execution-record-control' -AcknowledgementPath (Join-Path $output 'cancel-ack.json')
    }
    $thrown = $false
    try {
        $null = Invoke-VerificationProcessCapture -FilePath $python -ArgumentList @('-c', $case.code) -Description $case.id -TimeoutMilliseconds $case.timeout -ExecutionRecordPath $journal
    } catch { $thrown = $true }
    $record = Get-Content -LiteralPath $journal -Raw | ConvertFrom-Json
    $passed = $thrown -eq $case.throws -and $record.processesStopped -and $null -ne $record.pid -and $null -ne $record.exit
    if ($null -ne $case.expectedExit) { $passed = $passed -and $record.exit -eq $case.expectedExit }
    $passed = $passed -and $null -eq (Get-Process -Id $record.pid -ErrorAction SilentlyContinue)
    if ($case.id -eq 'normal') {
        $passed = $passed -and (Get-Content -LiteralPath $record.stdoutPath -Raw).Trim() -eq 'out' -and (Get-Content -LiteralPath $record.stderrPath -Raw).Trim() -eq 'err'
    }
    if ($case.throws) { $passed = $passed -and $record.status -eq 'failed' -and $null -ne $record.failure }
    $cases.Add(@{ id = $case.id; passed = $passed; executionRecord = $journal })
    $script:VerificationCancellationRequestPath = ''
}
foreach ($case in @(
    @{ id = 'missing-parent'; path = (Join-Path $output 'missing/record.json'); failure = 'VERIFICATION_EXECUTION_RECORD_PARENT_MISSING' },
    @{ id = 'existing-record'; path = (Join-Path $output 'normal.json'); failure = 'VERIFICATION_EXECUTION_RECORD_ALREADY_EXISTS' }
)) {
    $passed = $false
    try { $null = Invoke-VerificationProcessCapture -FilePath $python -ArgumentList @('-c', 'raise Exception("must not execute")') -Description $case.id -ExecutionRecordPath $case.path }
    catch { $passed = $_.Exception.Message -eq $case.failure }
    $cases.Add(@{ id = $case.id; passed = $passed })
}
$startFailure = Join-Path $output 'start-failure.json'
try { $null = Invoke-VerificationProcessCapture -FilePath (Join-Path $output 'missing.exe') -Description 'start-failure' -ExecutionRecordPath $startFailure } catch { }
$record = Get-Content -LiteralPath $startFailure -Raw | ConvertFrom-Json
$cases.Add(@{ id = 'start-failure'; passed = $record.status -eq 'failed' -and $null -eq $record.pid -and $null -eq $record.exit -and $record.processesStopped })
$stable = $initialHash -eq (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash
$completed = @($cases | Where-Object passed).Count
$result = @{ schemaVersion = 1; status = if ($stable -and $completed -eq $cases.Count) { 'passed' } else { 'failed' }; completed = $completed; total = $cases.Count; inputsStable = $stable; sourceSha256 = $initialHash; cases = @($cases.ToArray()) }
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
$result | ConvertTo-Json -Depth 8
if ($result.status -ne 'passed') { throw 'EXECUTION_RECORD_CONTROLS_FAILED' }
