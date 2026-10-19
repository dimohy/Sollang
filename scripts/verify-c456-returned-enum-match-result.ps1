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
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-18-456'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        candidateCompiler = if (Test-Path -LiteralPath (Join-Path $output 'compiler.exe')) {
            [IO.Path]::GetRelativePath($root, (Join-Path $output 'compiler.exe')).Replace('\', '/')
        } else { $null }
        candidateCompilerSha256 = if (Test-Path -LiteralPath (Join-Path $output 'compiler.exe')) {
            (Get-FileHash -LiteralPath (Join-Path $output 'compiler.exe') -Algorithm SHA256).Hash
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
        if (-not (Test-Path -LiteralPath $path)) { throw "C456 required input is missing: $path" }
    }

    $sources = @(Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source @(
        (Join-Path $root 'selfhost/llvm/text/foundation.slg'),
        (Join-Path $root 'selfhost/llvm/text/control.slg'))
    if ($LASTEXITCODE -ne 0) { throw 'C456 focused source format failed' }
    $completed++

    $foundation = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/foundation.slg'))
    $control = [IO.File]::ReadAllText((Join-Path $root 'selfhost/llvm/text/control.slg'))
    foreach ($needle in @('matchResultType -> writeIrType(context, state)', 'matchResultType -> storageAlign(context, state)')) {
        if (-not $foundation.Contains($needle) -or -not $control.Contains($needle)) {
            throw "C456 result type is not shared by allocation and emission: $needle"
        }
    }
    if (-not $control.Contains('matchResultType -> integerNodeWidth(context, state)')) {
        throw 'C456 integer arm conversion does not use the contextual result type'
    }
    $completed++

    $compilerLlvm = Join-Path $output 'compiler.ll'
    $compilerBuildOutput = Join-Path $output 'compiler-build.stdout.txt'
    $compilerError = Join-Path $output 'compiler.err'
    $compilerBitcode = Join-Path $output 'compiler.bc'
    $compiler = Join-Path $output 'compiler.exe'
    Invoke-VerificationProcessToFile -FilePath 'dotnet' `
        -ArgumentList (@($managedCompiler, 'build') + $sources + @(
            '-o', $compiler, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps')) `
        -Description 'C456 managed current-source compiler build' -OutputPath $compilerBuildOutput -ErrorPath $compilerError `
        -TimeoutMilliseconds 3600000
    $compilerBuildDiagnostics = ([IO.File]::ReadAllText($compilerBuildOutput) + [IO.File]::ReadAllText($compilerError))
    if ([regex]::IsMatch($compilerBuildDiagnostics, '(?m)(?:^|\r?\n)(?:warning S|note N)\d{3}\b')) {
        throw 'C456 managed current-source compiler build emitted a warning or note'
    }
    if (-not (Test-Path -LiteralPath $compilerLlvm -PathType Leaf)) {
        $generatedLlvm = Get-ChildItem -LiteralPath $output -Filter 'compiler*.ll' | Select-Object -First 1
        if ($null -eq $generatedLlvm) { throw 'C456 compiler build did not preserve LLVM output' }
        $compilerLlvm = $generatedLlvm.FullName
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C456 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o $compilerBitcode
    if ($LASTEXITCODE -ne 0) { throw 'C456 compiler llvm-as failed' }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
        throw 'C456 managed build did not publish the compiler executable'
    }
    $completed++

    $fixtureIds = @(
        '1398-selfhost-borrowed-enum-payload-lifetime',
        '1397-selfhost-while-chained-wide-match-result',
        '1399-selfhost-move-parameter-enum-field-transfer')
    foreach ($fixture in $fixtureIds) {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
            -Compiler $compiler -Label "c456-$fixture" -Fixture $fixture -Platform windows `
            -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
            -OutputDirectory (Join-Path $output $fixture) -Jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw "C456 exact fixture failed: $fixture" }
        if ($fixture -eq $fixtureIds[0]) {
            $llvm = Get-ChildItem -LiteralPath (Join-Path $output $fixture) -Filter '*.ll' | Select-Object -First 1
            if ($null -eq $llvm) { throw 'C456 1398 LLVM artifact is missing' }
            $llvmText = [IO.File]::ReadAllText($llvm.FullName)
            foreach ($shape in @('_result = alloca i32', 'store i32 0, ptr %', ' = trunc i64 ', '= load i32, ptr %')) {
                if (-not $llvmText.Contains($shape)) { throw "C456 1398 LLVM shape is missing: $shape" }
            }
            if ($llvmText.Contains('store void')) { throw 'C456 1398 LLVM retained store void' }
        }
        $completed++
    }

    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
        -Compiler $managedCompiler -Label 'c456-managed-1398' -Fixture $fixtureIds[0] -Platform windows `
        -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
        -OutputDirectory (Join-Path $output 'managed-1398') -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'C456 managed 1398 exact failed' }
    $completed++

    Save-Result -Status 'passed' -ExitCode 0
    Write-Host "[C456 returned enum match result] PASS $completed/$total result=$resultPath"
} catch {
    $failureIds.Add('C456_RETURNED_ENUM_MATCH_RESULT')
    Save-Result -Status 'failed' -ExitCode 1
    throw
}
