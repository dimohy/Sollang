[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCandidateSha256,
    [string]$OutputDirectory = '',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$candidate = (Resolve-Path -LiteralPath $CandidateCompiler).Path
$ExpectedCandidateSha256 = $ExpectedCandidateSha256.ToUpperInvariant()
$output = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $root ('artifacts/scratch/c394-final-candidate-' + [guid]::NewGuid().ToString('N'))
} else { [IO.Path]::GetFullPath($OutputDirectory) }
[IO.Directory]::CreateDirectory($output) | Out-Null

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function RepoPath([string]$Path) { (Resolve-Path -LiteralPath (Join-Path $root $Path)).Path }

$contractPath = RepoPath 'scripts/contracts/c394-final-candidate.json'
$schemaPath = RepoPath 'scripts/contracts/c394-final-candidate-result.schema.json'
$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.defectId -cne 'C2026-09-12-394' -or
    $contract.contextualAssertionGroups -ne 17 -or $contract.lexicalPredicateCases -ne 62 -or
    @($contract.expressionFixtures).Count -ne 2) {
    throw 'C394 final-candidate contract shape mismatch'
}

$inputs = [ordered]@{
    compiler = $candidate
    contract = $contractPath
    schema = $schemaPath
    contextualVerifier = RepoPath 'scripts/verify-contextual-integer-literals.ps1'
    expressionVerifier = RepoPath 'scripts/verify-native-exact-fixture-batch.ps1'
    nativeContextFixture = RepoPath $contract.nativeContextFixture.path
    lexicalContract = RepoPath $contract.lexicalContract.path
    diagnosticSource = RepoPath $contract.diagnosticFixture.source
    diagnosticExpected = RepoPath $contract.diagnosticFixture.expected
}
foreach ($fixture in $contract.expressionFixtures) {
    $inputs["source:$($fixture.id)"] = RepoPath "examples/regression/$($fixture.id).slg"
    $inputs["expected:$($fixture.id)"] = RepoPath "examples/regression/expected/$($fixture.id).stdout.txt"
}
$hashes = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $hashes[$entry.Key] = Hash $entry.Value }
if ($hashes.compiler -cne $ExpectedCandidateSha256) {
    throw "C394 candidate hash mismatch: expected=$ExpectedCandidateSha256 actual=$($hashes.compiler)"
}
if ($hashes.nativeContextFixture -cne $contract.nativeContextFixture.sha256 -or
    $hashes.lexicalContract -cne $contract.lexicalContract.sha256 -or
    $hashes.diagnosticSource -cne $contract.diagnosticFixture.sourceSha256 -or
    $hashes.diagnosticExpected -cne $contract.diagnosticFixture.expectedSha256) {
    throw 'C394 frozen contract input hash mismatch'
}
foreach ($fixture in $contract.expressionFixtures) {
    if ($hashes["source:$($fixture.id)"] -cne $fixture.sourceSha256 -or
        $hashes["expected:$($fixture.id)"] -cne $fixture.expectedSha256) {
        throw "C394 frozen expression fixture hash mismatch: $($fixture.id)"
    }
}
if ($ValidateInputsOnly) {
    & (RepoPath 'scripts/verify-native-exact-fixture-batch.ps1') `
        -Compiler $candidate -Label 'c394-inputs' -Platform windows `
        -LlvmRoot (RepoPath '.tools/llvm-22.1.8') -StdlibRoot (RepoPath 'stdlib') `
        -RepositoryRoot $root -OutputDirectory (Join-Path $output 'expression') `
        -Jobs 2 -MinimumCompilerJobs 1 -Fixture @($contract.expressionFixtures.id) -ValidateInputsOnly
    Write-Host "[C394 final candidate input preflight] PASS candidate=$($hashes.compiler)"
    return
}

$contextOutput = Join-Path $output 'contextual'
$expressionOutput = Join-Path $output 'expression'
$expressionLabel = 'c394-final'
$expressionResultPath = Join-Path $expressionOutput "$expressionLabel-batch-results.json"
$contextBundle = [ordered]@{ completed = 0; total = 17; result = $null }
$lexicalBundle = [ordered]@{ completed = 0; total = 62 }
$expressionBundle = [ordered]@{ completed = 0; total = 2; result = $null }
$diagnosticBundle = [ordered]@{ completed = 0; total = 1; exitCode = $null; llvmProduced = $null }
$failureIds = [System.Collections.Generic.List[string]]::new()
$failureMessage = $null
$phase = 'CONTEXTUAL'
try {
    $contextTranscript = & pwsh -NoProfile -File $inputs.contextualVerifier `
        -CandidateCompiler $candidate -ExpectedCandidateSha256 $ExpectedCandidateSha256 `
        -OutputDirectory $contextOutput -RequireCandidateSealed 2>&1
    if ($LASTEXITCODE -ne 0) { throw "C394 contextual verifier failed: $($contextTranscript -join "`n")" }
    $contextResultPath = Join-Path $contextOutput 'result.json'
    $contextResult = [IO.File]::ReadAllText($contextResultPath) | ConvertFrom-Json
    if ($contextResult.status -cne 'passed' -or $contextResult.completed -ne 17 -or $contextResult.total -ne 17 -or
        $contextResult.signedAndRangeDiagnostics.completed -ne 62 -or
        $contextResult.signedAndRangeDiagnostics.total -ne 62 -or
        $contextResult.compilerSha256 -cne $ExpectedCandidateSha256 -or
        $contextResult.nativeCandidateTopology.candidateUnsealedNodeCount -ne 0) {
        throw 'C394 contextual 17/17 or lexical 62/62 same-candidate invariant failed'
    }
    $contextBundle.completed = 17
    $contextBundle.result = $contextResultPath
    $lexicalBundle.completed = 62

    $phase = 'EXPRESSION'
    & $inputs.expressionVerifier -Compiler $candidate -Label $expressionLabel -Platform windows `
        -LlvmRoot (RepoPath '.tools/llvm-22.1.8') -StdlibRoot (RepoPath 'stdlib') `
        -RepositoryRoot $root -OutputDirectory $expressionOutput -Jobs 2 -MinimumCompilerJobs 1 `
        -Fixture @($contract.expressionFixtures.id)
    $expressionResult = [IO.File]::ReadAllText($expressionResultPath) | ConvertFrom-Json
    if ($expressionResult.state -cne 'passed' -or $expressionResult.passed -ne 2 -or
        $expressionResult.total -ne 2 -or $expressionResult.compilerSha256 -cne $ExpectedCandidateSha256) {
        throw 'C394 expression fixture 2/2 same-candidate invariant failed'
    }
    $expressionBundle.completed = 2
    $expressionBundle.result = $expressionResultPath

    $phase = 'DIAGNOSTIC'
    $diagnosticExe = Join-Path $output 'diagnostic.exe'
    $compilerFile = if ([IO.Path]::GetExtension($candidate) -ceq '.dll') { 'dotnet' } else { $candidate }
    $compilerArguments = if ($compilerFile -ceq 'dotnet') { @($candidate) } else { @() }
    $compilerArguments += @('build', $inputs.diagnosticSource, '-o', $diagnosticExe, '--target', 'windows-x64', '--llvm', (RepoPath '.tools/llvm-22.1.8'), '-O1', '--keep-temps')
    $diagnostic = Invoke-VerificationProcessCapture -FilePath $compilerFile -ArgumentList $compilerArguments `
        -WorkingDirectory $root -Description 'C394 whole-selfhost source diagnostic' -TimeoutMilliseconds 120000
    $diagnosticBundle.exitCode = $diagnostic.ExitCode
    $diagnosticText = ($diagnostic.Stdout + $diagnostic.Stderr).Replace("`r`n", "`n")
    $diagnosticLines = @($diagnosticText -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $expectedDiagnostic = [IO.File]::ReadAllText($inputs.diagnosticExpected).TrimEnd([char[]]@("`r", "`n"))
    $diagnosticLl = [IO.Path]::ChangeExtension($diagnosticExe, '.ll')
    $diagnosticBundle.llvmProduced = (Test-Path -LiteralPath $diagnosticLl) -or (Test-Path -LiteralPath $diagnosticExe)
    if ($diagnostic.ExitCode -eq 0 -or $diagnosticLines.Count -ne 1 -or
        -not $diagnosticLines[0].EndsWith($expectedDiagnostic, [StringComparison]::Ordinal) -or
        $diagnosticText -match '(?im)\b(?:warning|note)\b' -or $diagnosticBundle.llvmProduced) {
        throw "C394 whole-selfhost diagnostic invariant failed: $diagnosticText"
    }
    $diagnosticBundle.completed = 1
} catch {
    [void]$failureIds.Add("C394_$($phase)_FAILED")
    $failureMessage = $_.Exception.Message
}

$drift = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $inputs.GetEnumerator()) {
    try {
        if ((Hash $entry.Value) -cne $hashes[$entry.Key]) { [void]$drift.Add($entry.Key) }
    } catch { [void]$drift.Add($entry.Key) }
}
if ($drift.Count -gt 0) {
    [void]$failureIds.Add('C394_INPUT_DRIFT')
    if ([string]::IsNullOrWhiteSpace($failureMessage)) { $failureMessage = "C394 input drift: $($drift -join ', ')" }
}
$candidateShaEnd = try { Hash $candidate } catch { '' }
$candidateShaMatched = $candidateShaEnd -ceq $ExpectedCandidateSha256 -and $hashes.compiler -ceq $ExpectedCandidateSha256
if (-not $candidateShaMatched) {
    [void]$failureIds.Add('C394_CANDIDATE_SHA_DRIFT')
    if ([string]::IsNullOrWhiteSpace($failureMessage)) { $failureMessage = 'C394 candidate SHA changed after preflight' }
}
$failureIds = @($failureIds | Select-Object -Unique)
$record = [ordered]@{
    schemaVersion = 1
    defectId = 'C2026-09-12-394'
    status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    compilerSha256 = $hashes.compiler
    expectedCompilerSha256 = $ExpectedCandidateSha256
    candidateShaMatched = $candidateShaMatched
    inputStable = $drift.Count -eq 0
    inputDrift = @($drift)
    inputHashes = $hashes
    contextual = $contextBundle
    lexicalPredicates = $lexicalBundle
    expressionFixtures = $expressionBundle
    wholeSelfhostDiagnostic = $diagnosticBundle
    failureIds = $failureIds
    failure = if ($failureIds.Count -eq 0) { $null } else { $failureMessage }
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
if (-not ((Get-Content -LiteralPath $resultPath -Raw) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "C394 result schema failure: $resultPath"
}
if ($record.status -ne 'passed') { throw "C394 failed: $($failureIds -join ', '); result=$resultPath" }
Write-Host "[C394 final candidate] PASS contextual 17/17; lexical 62/62; expression 2/2; diagnostic 1/1; result=$resultPath"
