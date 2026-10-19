[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 16)][int]$Jobs = 3
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
        defectId = 'C2026-09-18-457'
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
        if (-not (Test-Path -LiteralPath $path)) { throw "C457 required input is missing: $path" }
    }

    $resolver = Join-Path $root 'selfhost/semantic/call_resolution_sources.slg'
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $resolver
    if ($LASTEXITCODE -ne 0) { throw 'C457 resolver format failed' }
    & (Join-Path $PSScriptRoot 'verify-c457-nullary-enum-call-closure.ps1') -ExpectedResolverState fixed
    if ($LASTEXITCODE -ne 0) { throw 'C457 static/direct-call closure contract failed' }
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
        -Description 'C457 managed current-source compiler build' -OutputPath $compilerBuildOutput -ErrorPath $compilerError `
        -TimeoutMilliseconds 3600000
    $compilerBuildDiagnostics = ([IO.File]::ReadAllText($compilerBuildOutput) + [IO.File]::ReadAllText($compilerError))
    if ([regex]::IsMatch($compilerBuildDiagnostics, '(?m)(?:^|\r?\n)(?:warning S|note N)\d{3}\b')) {
        throw 'C457 managed current-source compiler build emitted a warning or note'
    }
    if (-not (Test-Path -LiteralPath $compilerLlvm -PathType Leaf)) {
        $generatedLlvm = Get-ChildItem -LiteralPath $output -Filter 'compiler*.ll' | Select-Object -First 1
        if ($null -eq $generatedLlvm) { throw 'C457 compiler build did not preserve LLVM output' }
        $compilerLlvm = $generatedLlvm.FullName
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C457 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o $compilerBitcode
    if ($LASTEXITCODE -ne 0) { throw 'C457 compiler llvm-as failed' }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'C457 compiler executable is missing' }
    $completed++

    $integerSource = Join-Path $root 'selfhost/semantic/constant_integer.slg'
    $integerCalls = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('typed-ir-calls', $integerSource) `
        -Description 'C457 payloadless enum Typed IR call closure' -TimeoutMilliseconds 30000
    if ($integerCalls.ExitCode -ne 0 -or $integerCalls.Stderr.Length -ne 0) {
        throw "C457 constant_integer Typed IR inventory failed:`n$($integerCalls.Stdout)`n$($integerCalls.Stderr)"
    }
    if ($integerCalls.Stdout -match '(?m)^call \d+ source 0 ast \d+ target 0:(?:7|8)\b') {
        throw "C457 payloadless enum variant survived as a call:`n$($integerCalls.Stdout)"
    }
    $completed++

    $compilerHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
    & (Join-Path $PSScriptRoot 'verify-c451-inferred-instance-receivers.ps1') `
        -CandidateCompiler $compiler -ExpectedCompilerSha256 $compilerHash `
        -OutputDirectory (Join-Path $output 'c451-payload-constructor-control')
    if ($LASTEXITCODE -ne 0) { throw 'C457 payload-bearing sibling enum constructor control failed' }
    $completed++

    $fixtures = @(
        '787-selfhost-file-write-match-subject-ir',
        '1217-selfhost-late-indexed-array-type-contract',
        '1383-selfhost-inferred-receiver-method-owner')
    foreach ($fixture in $fixtures) {
        $fixtureOutput = Join-Path $output $fixture
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
            -Compiler $compiler -Label "c457-$fixture" -Fixture $fixture -Platform windows `
            -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
            -OutputDirectory $fixtureOutput -Jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw "C457 exact fixture failed: $fixture" }
        $llvm = Get-ChildItem -LiteralPath $fixtureOutput -Filter '*.ll' | Select-Object -First 1
        if ($null -eq $llvm) { throw "C457 retained LLVM is missing: $fixture" }
        & (Join-Path $PSScriptRoot 'verify-c457-nullary-enum-call-closure.ps1') `
            -ExpectedResolverState fixed -CandidateLlvmPath $llvm.FullName
        if ($LASTEXITCODE -ne 0) { throw "C457 focused direct-call closure failed: $fixture" }
        $completed++
    }

    Save-Result -Status 'passed' -ExitCode 0
    Write-Host "[C457 nullary enum reachability] PASS $completed/$total result=$resultPath"
} catch {
    $failureIds.Add('C457_NULLARY_ENUM_REACHABILITY')
    Save-Result -Status 'failed' -ExitCode 1
    throw
}
