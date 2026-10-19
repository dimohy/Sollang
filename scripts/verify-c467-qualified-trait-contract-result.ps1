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
$total = 6

$fixtureSources = @(
    'examples/regression/1454-trait-imported-collision-main.slg',
    'examples/regression/trait-contract-modules/trait-imported-comparison.slg',
    'examples/regression/trait-contract-modules/trait-imported-other.slg'
)
$contractInputs = @(
    'selfhost/ir/typed/function_lowering.slg',
    'selfhost/ir/typed/ordinary_function_expressions.slg',
    'selfhost/ir/typed/source_lowering.slg',
    'examples/regression/expected/1454-trait-imported-collision-main.sources.txt',
    'examples/regression/expected/1454-trait-imported-collision-main.stdout.txt',
    'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt',
    'scripts/verify-c467-qualified-trait-contract-result.ps1',
    'scripts/verify-native-exact-fixture.ps1',
    'scripts/verification-process.ps1'
) + $fixtureSources

function Get-CompilerSources {
    @(Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
}

function Get-FixtureSources {
    @($fixtureSources | ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_)).Path })
}

function Get-InputHashes {
    $relativeInputs = @($contractInputs + @(
        Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    ) | Sort-Object -Unique)
    $hashes = [ordered]@{}
    foreach ($relative in $relativeInputs) {
        $hashes[$relative] = (Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash
    }
    $hashes
}

function Get-Fingerprint([Collections.IDictionary]$Hashes) {
    $lines = foreach ($entry in $Hashes.GetEnumerator()) { "$($entry.Key)=$($entry.Value)" }
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))
}

$startHashes = Get-InputHashes
$inputFingerprint = Get-Fingerprint $startHashes
$baselineSha256 = (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash

function Save-Result([string]$Status, [int]$ExitCode) {
    $compiler = Join-Path $output 'compiler.exe'
    $endHashes = Get-InputHashes
    $endFingerprint = Get-Fingerprint $endHashes
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-23-467'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        inputFingerprint = $inputFingerprint
        finalInputFingerprint = $endFingerprint
        inputsStable = $inputFingerprint -ceq $endFingerprint
        inputHashes = $startHashes
        baselineCompilerSha256 = $baselineSha256
        candidateCompilerSha256 = if (Test-Path -LiteralPath $compiler -PathType Leaf) {
            (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        } else { $null }
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    $managedCompiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
    $llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
    $llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
    $stdlib = Join-Path $root 'stdlib'
    $sources = Get-FixtureSources

    $baselineTyped = Invoke-VerificationProcessCapture -FilePath $baseline `
        -ArgumentList (@('typed-ir-nodes') + $sources) `
        -Description 'C467 baseline Typed IR' -TimeoutMilliseconds 30000
    $baselineBuild = Invoke-VerificationProcessCapture -FilePath $baseline `
        -ArgumentList (@('build') + $sources + @(
            '-o', (Join-Path $output 'baseline-1454.exe'), '--target', 'windows-x64',
            '--llvm', $llvmRoot, '--stdlib', $stdlib, '--jobs',
            $Jobs.ToString([Globalization.CultureInfo]::InvariantCulture), '-O1', '--keep-temps')) `
        -Description 'C467 baseline checked 1454 build' -TimeoutMilliseconds 3600000
    $baselineDiagnostics = $baselineBuild.Stdout + $baselineBuild.Stderr
    if ($baselineTyped.ExitCode -ne 0 -or $baselineTyped.Stderr.Length -ne 0 -or
        -not [regex]::IsMatch($baselineTyped.Stdout, '(?m)^node \d+ kind 9 .* source 0 ast 64 .* type -1/-1/1/-1/0/0 .* opcode -226 ') -or
        $baselineBuild.ExitCode -eq 0 -or
        -not $baselineDiagnostics.Contains('S054: cannot bind a unit value', [StringComparison]::Ordinal) -or
        -not $baselineDiagnostics.Contains('source 0, ast 338, byte 3410, length 55', [StringComparison]::Ordinal)) {
        throw 'C467 preserved baseline did not reproduce the untyped qualified trait call and exact S054'
    }
    $completed++

    $managed = Invoke-VerificationProcessCapture -FilePath 'dotnet' `
        -ArgumentList @('run', '--project', (Join-Path $root 'tests/Sollang.ExampleTests/Sollang.ExampleTests.csproj'),
            '-c', 'Release', '--no-restore', '--', '--exact', '1454-trait-imported-collision-main') `
        -Description 'C467 managed oracle' -TimeoutMilliseconds 600000
    if ($managed.ExitCode -ne 0 -or -not $managed.Stdout.Contains('All 1 example tests passed.', [StringComparison]::Ordinal)) {
        throw 'C467 managed oracle failed'
    }
    $completed++

    $changedSources = @(
        (Join-Path $root 'selfhost/ir/typed/function_lowering.slg'),
        (Join-Path $root 'selfhost/ir/typed/ordinary_function_expressions.slg'),
        (Join-Path $root 'selfhost/ir/typed/source_lowering.slg')
    )
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $changedSources
    if ($LASTEXITCODE -ne 0) { throw 'C467 authoritative source format failed' }
    $functionLowering = [IO.File]::ReadAllText($changedSources[0])
    $ordinaryLowering = [IO.File]::ReadAllText($changedSources[1])
    $entryLowering = [IO.File]::ReadAllText($changedSources[2])
    if (-not $functionLowering.Contains('traitMethodResultTypeIdAtPath', [StringComparison]::Ordinal) -or
        -not $functionLowering.Contains('candidate.kind == 29 and candidate.parent == traitSymbol', [StringComparison]::Ordinal) -or
        -not $ordinaryLowering.Contains('traitMethodResultTypeIdAtPath(knownDynDispatchPathIndex!', [StringComparison]::Ordinal) -or
        -not $entryLowering.Contains('traitMethodResultTypeIdAtPath(knownEntryDynDispatchPathIndex!', [StringComparison]::Ordinal)) {
        throw 'C467 shared trait-contract result resolver is not wired into entry and ordinary lowering'
    }
    $completed++

    $compilerSources = Get-CompilerSources
    $compiler = Join-Path $output 'compiler.exe'
    $compilerStdout = Join-Path $output 'compiler-build.stdout.txt'
    $compilerStderr = Join-Path $output 'compiler-build.stderr.txt'
    Invoke-VerificationProcessToFile -FilePath 'dotnet' `
        -ArgumentList (@($managedCompiler, 'build') + $compilerSources + @(
            '-o', $compiler, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps')) `
        -Description 'C467 managed current-source compiler build' -OutputPath $compilerStdout -ErrorPath $compilerStderr `
        -TimeoutMilliseconds 3600000
    $compilerDiagnostics = [IO.File]::ReadAllText($compilerStdout) + [IO.File]::ReadAllText($compilerStderr)
    if ([regex]::IsMatch($compilerDiagnostics, '(?m)(?:^|\r?\n)(?:warning S|note N)\d{3}\b')) {
        throw 'C467 managed compiler build emitted a warning or note'
    }
    $compilerLlvm = Join-Path $output 'compiler.ll'
    if (-not (Test-Path -LiteralPath $compilerLlvm -PathType Leaf)) {
        $compilerLlvm = (Get-ChildItem -LiteralPath $output -Filter 'compiler*.ll' | Select-Object -First 1).FullName
    }
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C467 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o (Join-Path $output 'compiler.bc')
    if ($LASTEXITCODE -ne 0) { throw 'C467 compiler llvm-as failed' }
    $completed++

    $candidateSequential = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList (@('typed-ir-nodes') + $sources) `
        -Description 'C467 candidate sequential Typed IR' -TimeoutMilliseconds 30000
    $candidateParallel = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList (@('typed-ir-nodes-parallel') + $sources) `
        -Description 'C467 candidate parallel Typed IR' -TimeoutMilliseconds 30000
    if ($candidateSequential.ExitCode -ne 0 -or $candidateParallel.ExitCode -ne 0 -or
        $candidateSequential.Stderr.Length -ne 0 -or $candidateParallel.Stderr.Length -ne 0 -or
        $candidateSequential.Stdout -cne $candidateParallel.Stdout -or
        -not [regex]::IsMatch($candidateSequential.Stdout, '(?m)^node \d+ kind 9 .* source 0 ast 64 .* type \d+/1/1/-1/2/0 .* opcode -226 ')) {
        throw 'C467 candidate did not preserve one Int-typed qualified trait call in identical sequential and parallel Typed IR'
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
        -Compiler $compiler -Label 'c467-qualified-trait-contract-result' `
        -Fixture '1454-trait-imported-collision-main' -Platform windows `
        -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
        -OutputDirectory (Join-Path $output 'fixture-1454') -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'C467 exact 1454 fixture failed' }
    $completed++

    $finalHashes = Get-InputHashes
    if ((Get-Fingerprint $finalHashes) -cne $inputFingerprint) {
        $failureIds.Add('C467_INPUT_DRIFT')
        throw 'C467 authoritative inputs changed during verification'
    }
    Save-Result 'passed' 0
    Write-Host "[C467] PASS $completed/$total qualified trait contract result identity."
} catch {
    if ($failureIds.Count -eq 0) { $failureIds.Add('C467_GATE_FAILED') }
    Save-Result 'failed' 1
    throw
}
