[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmPath = (Resolve-Path -LiteralPath $LlvmRoot).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "Use a fresh output directory: $output" }
$verifier = Join-Path $repo 'scripts/verify-native-exact-fixture.ps1'
. (Join-Path $repo 'scripts/verification-process.ps1')
$fixture = '1661-arguments-each-layout'
$source = Join-Path $repo "examples/regression/$fixture.slg"
$expectedRoot = Join-Path $repo 'examples/regression/expected'
foreach ($path in @($verifier, $source, (Join-Path $expectedRoot "$fixture.args.txt"), (Join-Path $expectedRoot "$fixture.stdout.txt"))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing contract input: $path" }
}
[void][IO.Directory]::CreateDirectory($output)
$utf8 = [Text.UTF8Encoding]::new($false)
$compilerHash = (Get-FileHash -LiteralPath $compilerPath).Hash
$verifierHash = (Get-FileHash -LiteralPath $verifier).Hash
$common = @{
    Compiler = $compilerPath; Label = 'arguments-contract'; Platform = 'windows'
    LlvmRoot = $llvmPath; StdlibRoot = (Join-Path $repo 'stdlib')
    Jobs = 1; TimeoutMilliseconds = $TimeoutMilliseconds
}
$records = [Collections.Generic.List[object]]::new()
function Save-Results {
    $receipt = [ordered]@{
        schemaVersion = 1; compiler = $compilerPath; compilerSha256 = $compilerHash
        verifier = $verifier; verifierSha256 = $verifierHash
        completed = $records.Count; total = 10; cases = @($records.ToArray())
    }
    [IO.File]::WriteAllText((Join-Path $output 'results.json'), ($receipt | ConvertTo-Json -Depth 8), $utf8)
}
function Invoke-ContractCase([string]$Name, [string]$Root, [string]$FixtureName, [string]$Artifacts, [bool]$ExpectCached) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $log = @(& $verifier @common -RepositoryRoot $Root -Fixture $FixtureName -OutputDirectory $Artifacts *>&1)
    $text = $log | Out-String
    [IO.File]::WriteAllText((Join-Path $output "$Name.log"), $text, $utf8)
    $cached = $text.Contains('cached artifacts authenticated')
    if ($cached -ne $ExpectCached) { throw "Unexpected cached=$cached for $Name" }
    $inputs = @(Get-ChildItem -LiteralPath $Artifacts -Filter '*.inputs.sha256')
    $executables = @(Get-ChildItem -LiteralPath $Artifacts -Filter '*.exe')
    if ($inputs.Count -ne 1 -or $executables.Count -ne 1) { throw "Ambiguous artifacts for $Name" }
    $caseSource = Join-Path $Root "examples/regression/$FixtureName.slg"
    $caseExpected = Join-Path $Root "examples/regression/expected/$FixtureName.stdout.txt"
    $caseArgs = Join-Path $Root "examples/regression/expected/$FixtureName.args.txt"
    $argsPresent = Test-Path -LiteralPath $caseArgs -PathType Leaf
    $record = [pscustomobject]@{
        name = $Name; passed = $true; cached = $cached; seconds = $timer.Elapsed.TotalSeconds
        inputFingerprint = [IO.File]::ReadAllText($inputs[0].FullName)
        sourceSha256 = (Get-FileHash -LiteralPath $caseSource).Hash
        expectedSha256 = (Get-FileHash -LiteralPath $caseExpected).Hash
        argumentsPresent = $argsPresent
        argumentsSha256 = $(if ($argsPresent) { (Get-FileHash -LiteralPath $caseArgs).Hash } else { $null })
        executableSha256 = (Get-FileHash -LiteralPath $executables[0].FullName).Hash
    }
    $records.Add($record)
    Save-Results
    Write-Host "PASS $Name (cached=$cached)"
}

# Preserve source/expected/argv inputs inside this run, so later content mutations
# exercise the verifier's fingerprint without changing repository fixtures.
$mirror = Join-Path $output 'fixtures'
$expected = Join-Path $mirror 'examples/regression/expected'
[void][IO.Directory]::CreateDirectory($expected)
Copy-Item -LiteralPath $source -Destination (Join-Path $mirror "examples/regression/$fixture.slg")
foreach ($suffix in @('args.txt', 'stdout.txt')) {
    Copy-Item -LiteralPath (Join-Path $expectedRoot "$fixture.$suffix") -Destination (Join-Path $expected "$fixture.$suffix")
}
$unicodeOutput = Join-Path $output 'unicode-output'
Invoke-ContractCase 'unicode-spaces-first' $mirror $fixture $unicodeOutput $false
Invoke-ContractCase 'unicode-spaces-cached' $mirror $fixture $unicodeOutput $true
$originalConsoleOutputEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(949)
    Invoke-ContractCase 'unicode-under-cp949-host' $mirror $fixture $unicodeOutput $true
} finally {
    [Console]::OutputEncoding = $originalConsoleOutputEncoding
}
$argsPath = Join-Path $expected "$fixture.args.txt"
$stdoutPath = Join-Path $expected "$fixture.stdout.txt"
[IO.File]::WriteAllText($argsPath, "`ntail`n", $utf8)
[IO.File]::WriteAllText($stdoutPath, "3`ntrue`n`ntail`n3`n", $utf8)
$emptyOutput = Join-Path $output 'empty-output'
Invoke-ContractCase 'empty-argument-first' $mirror $fixture $emptyOutput $false
Invoke-ContractCase 'empty-argument-cached' $mirror $fixture $emptyOutput $true
$before = $records[$records.Count - 1].inputFingerprint
# Same decoded argv, different argument bytes, unchanged expected stdout.
[IO.File]::WriteAllText($argsPath, "`r`ntail`r`n", $utf8)
Invoke-ContractCase 'args-content-invalidates' $mirror $fixture $emptyOutput $false
if ($before -eq $records[$records.Count - 1].inputFingerprint) { throw 'Argument bytes did not invalidate the fingerprint' }
$noArgsFixture = 'arguments-contract-no-args'
Copy-Item -LiteralPath $source -Destination (Join-Path $mirror "examples/regression/$noArgsFixture.slg")
[IO.File]::WriteAllText((Join-Path $expected "$noArgsFixture.stdout.txt"), "1`ntrue`n1`n", $utf8)
$noArgsOutput = Join-Path $output 'no-args-output'
Invoke-ContractCase 'no-args-first' $mirror $noArgsFixture $noArgsOutput $false
Invoke-ContractCase 'no-args-cached' $mirror $noArgsFixture $noArgsOutput $true
$before = $records[$records.Count - 1].inputFingerprint
[IO.File]::WriteAllText((Join-Path $expected "$noArgsFixture.args.txt"), '', $utf8)
Invoke-ContractCase 'args-presence-invalidates' $mirror $noArgsFixture $noArgsOutput $false
if ($before -eq $records[$records.Count - 1].inputFingerprint) { throw 'Argument presence did not invalidate the fingerprint' }

$negativeFixture = 'arguments-contract-unexpected-stderr'
$negativeSource = Join-Path $mirror "examples/regression/$negativeFixture.slg"
$negativeExpected = Join-Path $expected "$negativeFixture.stdout.txt"
[IO.File]::WriteAllText($negativeSource, "import sys.runtime as runtime`nmain {`n    `"expected`" -> println`n    runtime.eprintln(`"unexpected stderr`")`n}`n", $utf8)
[IO.File]::WriteAllText($negativeExpected, "expected`n", $utf8)
$negativeOutput = Join-Path $output 'stderr-output'
$rejection = $null
try {
    & $verifier @common -RepositoryRoot $mirror -Fixture $negativeFixture -OutputDirectory $negativeOutput *> (Join-Path $output 'unexpected-stderr.log')
} catch { $rejection = $_.Exception.Message }
if ($null -eq $rejection -or $rejection -notmatch 'execution differed \(exit=0, stderrLength=[1-9][0-9]*\)') {
    throw "Unexpected stderr must fail exact execution with exit 0: $rejection"
}
$negativeExecutables = @(Get-ChildItem -LiteralPath $negativeOutput -Filter '*.exe')
if ($negativeExecutables.Count -ne 1) { throw 'Missing negative-control executable' }
$run = Invoke-VerificationProcessCapture -FilePath $negativeExecutables[0].FullName -ArgumentList @() -Description 'unexpected-stderr independent control' -TimeoutMilliseconds $TimeoutMilliseconds
if ($run.ExitCode -ne 0 -or $run.Stdout.Replace("`r`n", "`n") -cne "expected`n" -or $run.Stderr.Replace("`r`n", "`n") -cne "unexpected stderr`n") {
    throw 'Negative control did not produce exact stdout, exit 0, and the intended stderr'
}
$records.Add([pscustomobject]@{
    name = 'unexpected-stderr-rejected'; passed = $true; rejection = $rejection
    exitCode = $run.ExitCode; stdout = $run.Stdout; stderr = $run.Stderr
    sourceSha256 = (Get-FileHash -LiteralPath $negativeSource).Hash
    expectedSha256 = (Get-FileHash -LiteralPath $negativeExpected).Hash
    executableSha256 = (Get-FileHash -LiteralPath $negativeExecutables[0].FullName).Hash
})
if ((Get-FileHash -LiteralPath $compilerPath).Hash -ne $compilerHash -or (Get-FileHash -LiteralPath $verifier).Hash -ne $verifierHash) {
    throw 'Compiler or authoritative verifier changed during the contract run'
}
Save-Results
Write-Host '[native exact arguments contract] PASS 10/10 real-compiler argument, UTF-8 capture, cache, invalidation, and stderr cases.'
