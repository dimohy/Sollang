[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
if (Test-Path -LiteralPath $output) { throw 'CASE_BUDGET_TEST_OUTPUT_EXISTS' }
[IO.Directory]::CreateDirectory($output) | Out-Null
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$probe = Join-Path $output 'two-stage-probe.ps1'
$probeText = @'
param($Compiler,$Label,$Fixture,$RepositoryRoot,$OutputDirectory,$TimeoutMilliseconds,
      [int]$BuildDelayMilliseconds,[int]$RunDelayMilliseconds)
[IO.File]::WriteAllText((Join-Path $OutputDirectory "$Fixture.build-started"), [string]$PID)
Start-Sleep -Milliseconds $BuildDelayMilliseconds
[IO.File]::WriteAllText((Join-Path $OutputDirectory "$Fixture.run-started"), [string]$PID)
Start-Sleep -Milliseconds $RunDelayMilliseconds
[IO.File]::WriteAllText((Join-Path $OutputDirectory "$Fixture.done"), 'complete')
'probe-complete'
'@
[IO.File]::WriteAllText($probe, $probeText, [Text.UTF8Encoding]::new($false))
$protected = Join-Path $output 'unverified-existing-output.bin'
[IO.File]::WriteAllText($protected, 'preserve')
$inputs = @($PSCommandPath, $probe, (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
    (Join-Path $PSScriptRoot 'verification-process.ps1'), (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1'),
    (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1'))
$pins = [ordered]@{}
foreach ($path in $inputs) { $pins[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$cases = [Collections.Generic.List[object]]::new()
$failure = $null
try {
    $parameters = [ordered]@{ Compiler='probe';Label='budget';Fixture='normal';RepositoryRoot=$root
        OutputDirectory=$output;TimeoutMilliseconds=4000;BuildDelayMilliseconds=100;RunDelayMilliseconds=100 }
    $normal = Invoke-NativeExactBudgetedFixture -VerifierPath $probe -Parameters $parameters
    if ($normal.Trim() -cne 'probe-complete' -or -not (Test-Path -LiteralPath (Join-Path $output 'normal.done'))) {
        throw 'CASE_BUDGET_NORMAL_FAILED'
    }
    $cases.Add(@{id='normal-two-stage-case';status='passed';passed=$true})

    $parameters.Fixture='aggregate-timeout'
    $parameters.BuildDelayMilliseconds=2500
    $parameters.RunDelayMilliseconds=2500
    $timedOut = $false
    try { Invoke-NativeExactBudgetedFixture -VerifierPath $probe -Parameters $parameters | Out-Null }
    catch { $timedOut=$true }
    $recordPath = @(Get-ChildItem -LiteralPath $output -Filter 'budget-aggregate-timeout.case-*.execution.json')
    if (-not $timedOut -or $recordPath.Count -ne 1) { throw 'CASE_BUDGET_TIMEOUT_NOT_RECORDED' }
    $record = Get-Content -LiteralPath $recordPath[0].FullName -Raw | ConvertFrom-Json
    if ($record.status -cne 'failed' -or $record.processesStopped -ne $true -or $null -eq $record.failure -or
        -not (Test-Path -LiteralPath (Join-Path $output 'aggregate-timeout.run-started')) -or
        (Test-Path -LiteralPath (Join-Path $output 'aggregate-timeout.done')) -or
        (Get-Process -Id $record.pid -ErrorAction SilentlyContinue)) { throw 'CASE_BUDGET_TIMEOUT_SHUTDOWN_FAILED' }
    $cases.Add(@{id='sum-of-individually-valid-stages-exceeds-whole-budget';status='passed';passed=$true;executionRecord=$recordPath[0].FullName})

    $parameters.Fixture='invalid-budget'
    $parameters.TimeoutMilliseconds=180001
    $rejected = $false
    try { Invoke-NativeExactBudgetedFixture -VerifierPath $probe -Parameters $parameters | Out-Null }
    catch { if ($_.Exception.Message -cne 'NATIVE_EXACT_CASE_BUDGET_INVALID') { throw }; $rejected=$true }
    if (-not $rejected) { throw 'CASE_BUDGET_WIDENING_ACCEPTED' }
    $cases.Add(@{id='budget-widening-rejected-before-execution';status='passed';passed=$true})

    $parameters.TimeoutMilliseconds=4000
    $parameters.Label='../../outside'
    $parameters.Fixture='invalid-output'
    $rejected = $false
    try { Invoke-NativeExactBudgetedFixture -VerifierPath $probe -Parameters $parameters | Out-Null }
    catch { if ($_.Exception.Message -cne 'NATIVE_EXACT_CASE_OUTPUT_BOUNDARY') { throw }; $rejected=$true }
    if (-not $rejected -or [IO.File]::ReadAllText($protected) -cne 'preserve') { throw 'CASE_BUDGET_OUTPUT_BOUNDARY_FAILED' }
    $cases.Add(@{id='output-boundary-and-existing-unverified-output-protected';status='passed';passed=$true})
} catch { $failure=$_.Exception.Message }
$endPins = [ordered]@{}
foreach ($path in $inputs) { $endPins[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = ($pins | ConvertTo-Json -Compress) -ceq ($endPins | ConvertTo-Json -Compress)
if (-not $stable) { $failure='CASE_BUDGET_INPUT_DRIFT' }
$executionRecords = @(Get-ChildItem -LiteralPath $output -Filter '*.case-*.execution.json' |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
$stopped = $null -eq $failure -and $executionRecords.Count -eq 2 -and
    @($executionRecords | Where-Object { $_.processesStopped -ne $true -or
        (Get-Process -Id $_.pid -ErrorAction SilentlyContinue) }).Count -eq 0
if (-not $stopped -and $null -eq $failure) { $failure='CASE_BUDGET_SHUTDOWN_UNPROVEN' }
$result = [ordered]@{schemaVersion=1;status=$(if ($null -eq $failure) {'passed'} else {'failed'})
    completed=$cases.Count;total=4;cases=$cases;failure=$failure;inputsStable=$stable
    inputHashes=$pins;inputHashesEnd=$endPins;processesStopped=$stopped;claimsGoalComplete=$false}
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
if ($null -ne $failure) { throw $failure }
'CASE_BUDGET_CONTROLS_4_OF_4'
