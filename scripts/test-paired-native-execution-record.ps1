[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
if (-not $output.StartsWith((Join-Path $root 'artifacts') + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)) {
    throw 'PAIRED_EXECUTION_CONTROL_FRESH_OUTPUT_REQUIRED'
}
$wrapper = Join-Path $PSScriptRoot 'verify-compiler-paired-native-fixtures.ps1'
$helper = Join-Path $PSScriptRoot 'verification-process.ps1'
$paths = @($PSCommandPath, $wrapper, $helper)
$before = [ordered]@{}
foreach ($path in $paths) { $before[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($wrapper, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw 'PAIRED_EXECUTION_WRAPPER_PARSE_FAILED' }
$functions = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Invoke-CaseProcess'
}, $true))
if ($functions.Count -ne 1) { throw 'PAIRED_EXECUTION_WRAPPER_FUNCTION_NOT_UNIQUE' }
. $helper
. ([ScriptBlock]::Create($functions[0].Extent.Text))
[IO.Directory]::CreateDirectory($output) | Out-Null
$shellPath = (Get-Process -Id $PID).Path
$rows = [Collections.Generic.List[object]]::new()
$failure = $null
try {
    $countExpressions = [regex]::Matches([IO.File]::ReadAllText($wrapper), '(?m)^\s*completed = (.+)\r?$')
    if ($countExpressions.Count -ne 1) { throw 'PAIRED_COMPLETION_EXPRESSION_NOT_UNIQUE' }
    $countCompleted = [ScriptBlock]::Create('param($rows) ' + $countExpressions[0].Groups[1].Value)
    foreach ($countCase in @(
        @{ runs = 0; expected = 0 }, @{ runs = 1; expected = 0 },
        @{ runs = 2; expected = 1 }, @{ runs = 3; expected = 1 },
        @{ runs = 15; expected = 7 }, @{ runs = 16; expected = 8 }
    )) {
        $actual = & $countCompleted ([pscustomobject]@{ Count = $countCase.runs })
        if ($actual -ne $countCase.expected) { throw "PAIRED_INCOMPLETE_PAIR_COUNTED: $($countCase.runs)" }
    }
    $rows.Add([ordered]@{ id = 'completed-pairs'; passed = $true; controls = 6; previousFailure = 'Three successful runs are one completed pair, not two.' })
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
public static class VerificationRecordReaderControl {
    public static void ReleaseAfter(FileStream stream, int milliseconds) {
        var thread = new Thread(() => { Thread.Sleep(milliseconds); stream.Dispose(); });
        thread.IsBackground = true;
        thread.Start();
    }
}
'@
    $publicationPath = Join-Path $output 'publication.execution.json'
    Write-VerificationExecutionRecord $publicationPath ([ordered]@{ status = 'running' })
    Write-VerificationExecutionRecord $publicationPath ([ordered]@{ status = 'passed'; value = 1 })
    if ((Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json).value -ne 1) { throw 'PUBLICATION_NORMAL_FAILED' }
    $rows.Add([ordered]@{ id = 'publication-normal'; passed = $true })
    $reader = [IO.File]::Open($publicationPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    [VerificationRecordReaderControl]::ReleaseAfter($reader, 80)
    Write-VerificationExecutionRecord $publicationPath ([ordered]@{ status = 'passed'; value = 2 })
    if ((Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json).value -ne 2 -or
        @(Get-ChildItem -LiteralPath $output -Filter 'publication.execution.json.tmp-*.publication.json').Count -ne 1) {
        throw 'PUBLICATION_TRANSIENT_READER_NOT_RECOVERED'
    }
    $rows.Add([ordered]@{ id = 'publication-transient-reader'; passed = $true; childRerun = $false })
    $reader = [IO.File]::Open($publicationPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $publishFailure = $null
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try { Write-VerificationExecutionRecord $publicationPath ([ordered]@{ status = 'passed'; value = 3 }) }
    catch { $publishFailure = $_.Exception.Message }
    finally { $reader.Dispose(); $watch.Stop() }
    $pending = @(Get-ChildItem -LiteralPath $output -Filter 'publication.execution.json.tmp-*' |
        Where-Object Name -NotLike '*.publication.json')
    if ($publishFailure -notlike 'VERIFICATION_RECORD_PUBLISH_FAILED:*' -or $watch.ElapsedMilliseconds -gt 3000 -or
        $pending.Count -ne 1 -or (Get-Content -LiteralPath $pending[0].FullName -Raw | ConvertFrom-Json).value -ne 3 -or
        (Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json).value -ne 2) {
        throw 'PUBLICATION_PERMANENT_READER_NOT_BOUNDED_OR_DURABLE'
    }
    $rows.Add([ordered]@{ id = 'publication-persistent-reader'; passed = $true; pendingSnapshot = $pending[0].FullName })
    [IO.File]::SetAttributes($publicationPath, [IO.FileAttributes]::ReadOnly)
    $publishFailure = $null
    try { Write-VerificationExecutionRecord $publicationPath ([ordered]@{ status = 'passed'; value = 4 }) }
    catch { $publishFailure = $_.Exception.Message }
    finally { [IO.File]::SetAttributes($publicationPath, [IO.FileAttributes]::Normal) }
    if ($publishFailure -notlike 'VERIFICATION_RECORD_PUBLISH_FAILED:*attempts=1*' -or
        (Get-Content -LiteralPath $publicationPath -Raw | ConvertFrom-Json).value -ne 2) { throw 'PUBLICATION_READONLY_BYPASSED' }
    $rows.Add([ordered]@{ id = 'publication-readonly'; passed = $true })
    foreach ($case in @(
        @{ id = 'normal'; exit = 0; timeout = 5000; script = "[Console]::Out.Write('normal-out'); [Console]::Error.Write('normal-err'); exit 0" },
        @{ id = 'nonzero'; exit = 7; timeout = 5000; script = "[Console]::Out.Write('failure-out'); [Console]::Error.Write('failure-err'); exit 7" },
        @{ id = 'timeout'; exit = $null; timeout = 1500; script = "[Console]::Out.Write('timeout-out'); [Console]::Error.Write('timeout-err'); Start-Sleep -Seconds 30" }
    )) {
        $TimeoutMilliseconds = $case.timeout
        $prefix = Join-Path $output $case.id
        $thrown = $null
        $run = $null
        try { $run = Invoke-CaseProcess $shellPath @('-NoProfile', '-Command', $case.script) $case.id $prefix }
        catch { $thrown = $_.Exception.Message }
        $recordPath = "$prefix.execution.json"
        $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
        $stdout = [IO.File]::ReadAllText($record.stdoutPath)
        $stderr = [IO.File]::ReadAllText($record.stderrPath)
        if (-not $record.processesStopped -or $record.pid -le 0 -or -not $record.finishedAtUtc -or
            $stdout -cne "$($case.id -replace 'nonzero','failure')-out" -or
            $stderr -cne "$($case.id -replace 'nonzero','failure')-err") {
            throw "PAIRED_EXECUTION_CONTROL_LOG_OR_TERMINAL_MISMATCH: $($case.id)"
        }
        if ($case.id -ceq 'timeout') {
            if (-not $thrown -or $record.status -cne 'failed' -or
                $record.failure -notlike '*configured verification limit*1500 ms*' -or
                $thrown -notlike '*timeout-out*' -or $thrown -notlike '*timeout-err*') {
                throw 'PAIRED_EXECUTION_TIMEOUT_OUTPUT_NOT_DURABLE'
            }
        } elseif ($thrown -or $run.ExitCode -ne $case.exit -or $record.exit -ne $case.exit -or
            $record.status -cne $(if ($case.exit -eq 0) { 'passed' } else { 'failed' }) -or
            [IO.File]::ReadAllText("$prefix.stdout.txt") -cne $stdout -or
            [IO.File]::ReadAllText("$prefix.stderr.txt") -cne $stderr) {
            throw "PAIRED_EXECUTION_CONTROL_EXIT_MISMATCH: $($case.id)"
        }
        $rows.Add([ordered]@{ id = $case.id; passed = $true; executionResult = $recordPath; timeoutMilliseconds = $case.timeout })
    }
} catch { $failure = $_.Exception.Message }
finally {
    $after = [ordered]@{}
    foreach ($path in $paths) { $after[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    $stable = @($paths | Where-Object { $before[$_] -cne $after[$_] }).Count -eq 0
    $result = [ordered]@{ schemaVersion = 1; status = if (-not $failure -and $stable -and $rows.Count -eq 8) { 'passed' } else { 'failed' }
        completed = $rows.Count; total = 8; inputsStable = $stable; inputHashesStart = $before; inputHashesEnd = $after
        cases = @($rows.ToArray()); failure = $failure
        limitations = @('stdout/stderr logs are persisted after child termination, not streamed live.',
            'CPU telemetry remains console output; this test does not prove durable CPU diagnostics.',
            'Only the extracted production wrapper and tiny PowerShell children run; no compiler acceptance is rerun.',
            'Changed wrapper/helper pins invalidate current-source reuse of earlier native fixture records.')
    }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
}
if ($result.status -cne 'passed') { throw "PAIRED_EXECUTION_CONTROLS_FAILED: $failure" }
Write-Host "Paired wrapper execution records PASS $($result.completed)/$($result.total); result=$(Join-Path $output 'result.json')"
