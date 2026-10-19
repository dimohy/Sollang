[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 16)][int]$Jobs = 8
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$baseline = (Resolve-Path -LiteralPath $BaselineCompiler).Path
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$total = 5

function Save-Result([string]$Status, [int]$ExitCode) {
    $compiler = Join-Path $output 'compiler.exe'
    $inputs = @(
        'selfhost/syntax/ast.slg',
        'examples/regression/1410-selfhost-constant-expression-plan.slg',
        'examples/regression/expected/1410-selfhost-constant-expression-plan.stdout.txt',
        'examples/regression/expected/1410-selfhost-constant-expression-plan.sources.txt'
    )
    $inputHashes = [ordered]@{}
    $lines = foreach ($relative in $inputs) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash
        $inputHashes[$relative] = $hash
        "$relative=$hash"
    }
    $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-23-466'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        inputFingerprint = $fingerprint
        inputHashes = $inputHashes
        baselineCompilerSha256 = (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash
        candidateCompilerSha256 = if (Test-Path -LiteralPath $compiler -PathType Leaf) {
            (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        } else { $null }
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-Sources {
    @(Get-Content -LiteralPath (Join-Path $root 'examples/regression/expected/1410-selfhost-constant-expression-plan.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
}

try {
    $managedCompiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
    $llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
    $llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
    $stdlib = Join-Path $root 'stdlib'
    $fixture = Join-Path $root 'examples/regression/1410-selfhost-constant-expression-plan.slg'
    $fixtureText = [IO.File]::ReadAllText($fixture)
    $flowText = 'error -> Result<Long, expression.Error>.Err'
    $sources = Get-Sources

    $baselineAst = Invoke-VerificationProcessCapture -FilePath $baseline `
        -ArgumentList @('ast-nodes', $fixture) -Description 'C466 baseline AST inventory' -TimeoutMilliseconds 30000
    $baselineBuild = Invoke-VerificationProcessCapture -FilePath $baseline `
        -ArgumentList (@('build') + $sources + @(
            '-o', (Join-Path $output 'baseline-1410.exe'), '--target', 'windows-x64',
            '--llvm', $llvmRoot, '--stdlib', $stdlib, '--jobs',
            $Jobs.ToString([Globalization.CultureInfo]::InvariantCulture), '-O1', '--keep-temps')) `
        -Description 'C466 baseline checked 1410 build' -TimeoutMilliseconds 3600000
    $baselineComparisons = @([regex]::Matches($baselineAst.Stdout,
        '(?m)^ast source 0 node \d+ kind 19 .* start (?<start>\d+) length (?<length>\d+) '))
    $falseBaselineComparison = @($baselineComparisons | Where-Object {
        $start = [int]$_.Groups['start'].Value
        $length = [int]$_.Groups['length'].Value
        $fixtureText.Substring($start, $length).StartsWith($flowText, [StringComparison]::Ordinal)
    })
    $baselineDiagnostics = $baselineBuild.Stdout + $baselineBuild.Stderr
    if ($baselineAst.ExitCode -ne 0 -or $baselineAst.Stderr.Length -ne 0 -or
        $falseBaselineComparison.Count -ne 1 -or
        -not $baselineDiagnostics.Contains('compiler error S059: binary binding initializer was not materialized in Typed IR', [StringComparison]::Ordinal) -or
        -not $baselineDiagnostics.Contains('byte 1363, length 54', [StringComparison]::Ordinal)) {
        throw 'C466 preserved baseline did not reproduce the exact false comparison and S059'
    }
    $completed++

    $astSource = Join-Path $root 'selfhost/syntax/ast.slg'
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source @($astSource, $fixture)
    if ($LASTEXITCODE -ne 0) { throw 'C466 authoritative source format failed' }
    $astSourceText = [IO.File]::ReadAllText($astSource)
    if (-not $astSourceText.Contains('typeApplicationNode.ruleId == grammar.ruleIdStandardGenericEnumFlowTarget()', [StringComparison]::Ordinal)) {
        throw 'C466 standard generic enum flow angle owner is missing'
    }
    $completed++

    $compilerSources = @(Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
    $compiler = Join-Path $output 'compiler.exe'
    $compilerLlvm = Join-Path $output 'compiler.ll'
    $compilerStdout = Join-Path $output 'compiler-build.stdout.txt'
    $compilerStderr = Join-Path $output 'compiler.err'
    Invoke-VerificationProcessToFile -FilePath 'dotnet' `
        -ArgumentList (@($managedCompiler, 'build') + $compilerSources + @(
            '-o', $compiler, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps')) `
        -Description 'C466 managed current-source compiler build' -OutputPath $compilerStdout -ErrorPath $compilerStderr `
        -TimeoutMilliseconds 3600000
    $compilerDiagnostics = [IO.File]::ReadAllText($compilerStdout) + [IO.File]::ReadAllText($compilerStderr)
    if ([regex]::IsMatch($compilerDiagnostics, '(?m)(?:^|\r?\n)(?:warning S|note N)\d{3}\b')) {
        throw 'C466 managed compiler build emitted a warning or note'
    }
    if (-not (Test-Path -LiteralPath $compilerLlvm -PathType Leaf)) {
        $compilerLlvm = (Get-ChildItem -LiteralPath $output -Filter 'compiler*.ll' | Select-Object -First 1).FullName
    }
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C466 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o (Join-Path $output 'compiler.bc')
    if ($LASTEXITCODE -ne 0) { throw 'C466 compiler llvm-as failed' }
    $completed++

    $candidateAst = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('ast-nodes', $fixture) -Description 'C466 candidate AST inventory' -TimeoutMilliseconds 30000
    $candidateSequential = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList (@('typed-ir-nodes') + $sources) -Description 'C466 candidate sequential Typed IR' -TimeoutMilliseconds 30000
    $candidateParallel = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList (@('typed-ir-nodes-parallel') + $sources) -Description 'C466 candidate parallel Typed IR' -TimeoutMilliseconds 30000
    if ($candidateAst.ExitCode -ne 0 -or $candidateAst.Stderr.Length -ne 0 -or
        $candidateSequential.ExitCode -ne 0 -or $candidateParallel.ExitCode -ne 0 -or
        $candidateSequential.Stderr.Length -ne 0 -or $candidateParallel.Stderr.Length -ne 0 -or
        $candidateSequential.Stdout -cne $candidateParallel.Stdout) {
        throw 'C466 candidate AST/Typed IR inventory failed or diverged'
    }
    $candidateComparisons = @([regex]::Matches($candidateAst.Stdout,
        '(?m)^ast source 0 node \d+ kind 19 .* start (?<start>\d+) length (?<length>\d+) '))
    $falseCandidateComparison = @($candidateComparisons | Where-Object {
        $start = [int]$_.Groups['start'].Value
        $length = [int]$_.Groups['length'].Value
        $fixtureText.Substring($start, $length).StartsWith($flowText, [StringComparison]::Ordinal)
    })
    $bindingMatch = [regex]::Match($candidateAst.Stdout,
        '(?m)^ast source 0 node (?<ast>\d+) kind 9 parent \d+ start 1363 length 54 ')
    if ($falseCandidateComparison.Count -ne 0 -or -not $bindingMatch.Success) {
        throw 'C466 candidate retained the false comparison or lost the binding owner'
    }
    $bindingAst = [int]$bindingMatch.Groups['ast'].Value
    $bindingIr = [regex]::Match($candidateSequential.Stdout,
        "(?m)^node (?<ir>\d+) kind 17 .* source 0 ast $bindingAst .* operands (?<initializer>\d+)/")
    if (-not $bindingIr.Success) { throw 'C466 candidate binding Typed IR is missing' }
    $initializer = [int]$bindingIr.Groups['initializer'].Value
    if (-not [regex]::IsMatch($candidateSequential.Stdout, "(?m)^node $initializer kind 26 ")) {
        throw 'C466 candidate binding did not retain the enum-constructor producer'
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
        -Compiler $compiler -Label 'c466-standard-generic-enum-flow' `
        -Fixture '1410-selfhost-constant-expression-plan' -Platform windows `
        -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
        -OutputDirectory (Join-Path $output 'fixture-1410') -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'C466 exact 1410 fixture failed' }
    $completed++

    Save-Result 'passed' 0
    Write-Host "[C466] PASS $completed/$total standard generic enum flow angle ownership."
} catch {
    $failureIds.Add('C466_GATE_FAILED')
    Save-Result 'failed' 1
    throw
}

