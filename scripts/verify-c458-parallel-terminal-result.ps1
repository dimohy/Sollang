[CmdletBinding()]
param(
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
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$total = 8

function Save-Result([string]$Status, [int]$ExitCode) {
    $compiler = Join-Path $output 'compiler.exe'
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-22-458'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        candidateCompiler = if (Test-Path -LiteralPath $compiler -PathType Leaf) {
            [IO.Path]::GetRelativePath($root, $compiler).Replace('\', '/')
        } else { $null }
        candidateCompilerSha256 = if (Test-Path -LiteralPath $compiler -PathType Leaf) {
            (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        } else { $null }
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    $managedCompiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
    $llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
    $llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
    $stdlib = Join-Path $root 'stdlib'
    foreach ($path in @($managedCompiler, $llvmAs, $stdlib)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "C458 required input is missing: $path" }
    }

    $resolver = Join-Path $root 'selfhost/semantic/expression_type_ids_resolution_phases.slg'
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $resolver
    if ($LASTEXITCODE -ne 0) { throw 'C458 resolver format failed' }
    $resolverText = [IO.File]::ReadAllText($resolver)
    foreach ($required in @(
        'prepared.callIndexByAst[parallelRange.astStart + parallelCandidate.astNode] < 0',
        'parallelCandidateNode.kind == 42',
        'concrete terminal producer inside the region')) {
        if (-not $resolverText.Contains($required, [StringComparison]::Ordinal)) {
            throw "C458 terminal-producer contract is missing: $required"
        }
    }
    $completed++

    $sources = @(Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
    $compilerLlvm = Join-Path $output 'compiler.ll'
    $compilerBuildOutput = Join-Path $output 'compiler-build.stdout.txt'
    $compilerError = Join-Path $output 'compiler.err'
    $compilerBitcode = Join-Path $output 'compiler.bc'
    $compiler = Join-Path $output 'compiler.exe'
    Invoke-VerificationProcessToFile -FilePath 'dotnet' `
        -ArgumentList (@($managedCompiler, 'build') + $sources + @(
            '-o', $compiler, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps')) `
        -Description 'C458 managed current-source compiler build' -OutputPath $compilerBuildOutput -ErrorPath $compilerError `
        -TimeoutMilliseconds 3600000
    $compilerBuildDiagnostics = ([IO.File]::ReadAllText($compilerBuildOutput) + [IO.File]::ReadAllText($compilerError))
    if ([regex]::IsMatch($compilerBuildDiagnostics, '(?m)(?:^|\r?\n)(?:warning S|note N)\d{3}\b')) {
        throw 'C458 managed current-source compiler build emitted a warning or note'
    }
    if (-not (Test-Path -LiteralPath $compilerLlvm -PathType Leaf)) {
        $generatedLlvm = Get-ChildItem -LiteralPath $output -Filter 'compiler*.ll' | Select-Object -First 1
        if ($null -eq $generatedLlvm) { throw 'C458 compiler build did not preserve LLVM output' }
        $compilerLlvm = $generatedLlvm.FullName
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C458 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o $compilerBitcode
    if ($LASTEXITCODE -ne 0) { throw 'C458 compiler llvm-as failed' }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'C458 compiler executable is missing' }
    $completed++

    $fixture1320 = Join-Path $root 'examples/regression/1320-parallel-role-two-reference-captures.slg'
    $records = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('expression-type-records', $fixture1320) `
        -Description 'C458 parallel semantic result inventory' -TimeoutMilliseconds 30000
    if ($records.ExitCode -ne 0 -or $records.Stderr.Length -ne 0) {
        throw "C458 expression type inventory failed:`n$($records.Stdout)`n$($records.Stderr)"
    }
    $parallelMatch = [regex]::Match($records.Stdout, '(?m)^expression \d+ source 0 ast 74 kind 48 .* type (?<type>\d+)/3/-1/-1/-1/2/-1/-1 status 0$')
    if (-not $parallelMatch.Success) { throw 'C458 parallel result is not a growable Int array' }
    $resultType = [regex]::Escape($parallelMatch.Groups['type'].Value)
    if (-not [regex]::IsMatch($records.Stdout, "(?m)^expression \d+ source 0 ast 101 kind 15 .* type $resultType/3/-1/-1/-1/2/-1/-1 status 0$")) {
        throw 'C458 shifted binding does not retain the exact parallel result type'
    }
    $completed++

    foreach ($fixture in @(
        '1320-parallel-role-two-reference-captures',
        '1234-selfhost-parallel-nested-flow-arguments',
        '1321-parallel-additional-borrow-result',
        '386-try-parallel-result')) {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
            -Compiler $compiler -Label "c458-$fixture" -Fixture $fixture -Platform windows `
            -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
            -OutputDirectory (Join-Path $output $fixture) -Jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw "C458 exact fixture failed: $fixture" }
        $completed++
    }

    Save-Result -Status 'passed' -ExitCode 0
    Write-Host "[C458 parallel terminal result] PASS $completed/$total result=$resultPath"
} catch {
    $failureIds.Add('C458_PARALLEL_TERMINAL_RESULT')
    Save-Result -Status 'failed' -ExitCode 1
    throw
}
