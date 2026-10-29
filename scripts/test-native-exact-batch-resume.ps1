[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
. (Join-Path $PSScriptRoot 'native-exact-source-closure.ps1')
$errors = $null; $tokens = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot 'resume-native-exact-fixture-batch.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count -gt 0) { throw 'RESUME_TEST_PARSE_FAILED' }
$function = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -ceq 'Get-RetainedExactCase'},$true)
. ([scriptblock]::Create($function.Extent.Text))
$referencesFunction=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -ceq 'Assert-RetainedExactCaseReferences'},$true)
. ([scriptblock]::Create($referencesFunction.Extent.Text))

$repositoryPath = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $repositoryPath) { throw 'RESUME_TEST_FRESH_OUTPUT_REQUIRED' }
$expected = Join-Path $repositoryPath 'examples/regression/expected'
$originalOutput = Join-Path $repositoryPath 'products'
[void][IO.Directory]::CreateDirectory($expected)
[void][IO.Directory]::CreateDirectory($originalOutput)
$compilerPath = Join-Path $repositoryPath 'compiler.exe'
$fixtureName = 'resume-control'
$source = Join-Path $repositoryPath "examples/regression/$fixtureName.slg"
$stdout = Join-Path $expected "$fixtureName.stdout.txt"
$diagnostic = Join-Path $expected "$fixtureName.compiler.stderr.exact.txt"
$arguments = Join-Path $expected "$fixtureName.args.txt"
$manifest = Join-Path $expected "$fixtureName.sources.txt"
foreach ($item in @(@($compilerPath,'compiler'),@($source,'source'),@($stdout,"ok`n"),
        @($diagnostic,"warning S003 deliberate fixture`n"),@($arguments,"argument`n"),
        @($manifest,"examples/regression/$fixtureName.slg`n"))) {
    [IO.File]::WriteAllText($item[0],$item[1])
}
$Label='selfhost'; $TimeoutMilliseconds=180000; $commonInputFingerprint='A'*64
$artifact = Join-Path $originalOutput "$Label-exact-$fixtureName.exe"
foreach ($path in @($artifact,"$artifact.ll","$artifact.bc")) { [IO.File]::WriteAllText($path,'product') }
$fingerprint = Get-NativeExactPerFixtureInputFingerprint -RepositoryRoot $repositoryPath `
    -CommonFingerprint $commonInputFingerprint -Fixture $fixtureName -Label $Label -Platform windows `
    -Distribution Ubuntu -Jobs 1 -ExpectedStdoutLength 0 -InputPath @($source,$diagnostic,$arguments,$manifest,$stdout)
Publish-NativeExactFixtureReceipt $fingerprint "$artifact.inputs.sha256" "$artifact.ll" "$artifact.bc" $artifact "$artifact.outputs.sha256"
$recordPath = Join-Path $originalOutput "$Label-$fixtureName.case-control.execution.json"
$record = [ordered]@{schemaVersion=1;status='passed';pid=123;exit=0;processesStopped=$true;failure=$null;
    startedAtUtc='2026-10-29T00:00:00Z';finishedAtUtc='2026-10-29T00:00:01Z';
    command=@('pwsh','-Fixture',$fixtureName,'-Compiler',$compilerPath,'-Jobs','1',
        '-TimeoutMilliseconds','180000','-OutputDirectory',$originalOutput)}
function Save-Control { [IO.File]::WriteAllText($recordPath,($record|ConvertTo-Json -Depth 5)) }
Save-Control
$results = [Collections.Generic.List[object]]::new()
function Check-Control {
    param([string]$Name,[string]$ExpectedFailure='')
    $failure=''
    try { $case=Get-RetainedExactCase $fixtureName 1 $false; Assert-RetainedExactCaseReferences @($case) }
    catch { $failure=$_.Exception.Message }
    $passed = if ($ExpectedFailure) { $failure.Contains($ExpectedFailure,[StringComparison]::Ordinal) } else { $failure -ceq '' }
    $results.Add([pscustomobject]@{name=$Name;passed=$passed;expectedFailure=$ExpectedFailure;actualFailure=$failure})
    if (-not $passed) { throw "RESUME_CONTROL_FAILED: $Name : $failure" }
}
# Unit fixtures deliberately use synthetic process records. These exercise the
# acceptance boundary and never count as actual compiler execution evidence.
Check-Control 'unchanged-ordered-contract'
Check-Control 'plain-hash-records-are-not-parsed-as-json'
[IO.File]::AppendAllText($stdout,'changed')
Check-Control 'changed-source-oracle' 'NATIVE_RESUME_RETAINED_CASE_CHANGED'
[IO.File]::WriteAllText($stdout,"ok`n")
[IO.File]::AppendAllText($artifact,'changed')
Check-Control 'changed-product' 'NATIVE_RESUME_RETAINED_CASE_CHANGED'
[IO.File]::WriteAllText($artifact,'product')
$record.processesStopped=$false; Save-Control
Check-Control 'unstopped-process' 'NATIVE_RESUME_CASE_COMPLETION_AMBIGUOUS'
$record.processesStopped=$true; $record.finishedAtUtc='2026-10-29T00:03:01Z'; Save-Control
Check-Control 'whole-case-over-budget' 'NATIVE_RESUME_CASE_BUDGET_INVALID'
$record.finishedAtUtc='2026-10-29T00:00:01Z'; $record.command[4]='other-compiler'; Save-Control
Check-Control 'different-compiler-command' 'NATIVE_RESUME_CASE_COMMAND_MISMATCH'
$record.command[4]=$compilerPath; Save-Control
$duplicate=Join-Path $originalOutput "$Label-$fixtureName.case-duplicate.execution.json"
Copy-Item -LiteralPath $recordPath -Destination $duplicate
Check-Control 'ambiguous-completion' 'NATIVE_RESUME_CASE_COMPLETION_AMBIGUOUS'
Remove-Item -LiteralPath $duplicate
Check-Control 'restored-control'
$result=[ordered]@{schemaVersion=1;status='passed';completed=$results.Count;total=$results.Count;
    compilerExecutions=0;syntheticProcessRecords=$true;cases=@($results)}
[IO.File]::WriteAllText((Join-Path $repositoryPath 'result.json'),($result|ConvertTo-Json -Depth 8))
Write-Host "[native exact resume controls] PASS $($results.Count)/$($results.Count)"
