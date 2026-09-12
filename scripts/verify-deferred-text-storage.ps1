[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$ObserveBaseline,
    [switch]$PositiveOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-ExpectedStorageDiagnostic {
    param([string]$Actual, [string]$Expected, [int]$ExitCode, [int]$OutputCount)
    return -not [string]::IsNullOrWhiteSpace($Expected) -and $ExitCode -ne 0 -and $OutputCount -eq 0 `
        -and $Actual -match '(?m)^sollang: semantic error at ' -and $Actual.Contains($Expected.Trim()) `
        -and $Actual -notmatch '(?im)warning|\bN00[12]\b'
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/deferred-text-storage-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$names = @(
    'deferred-text-array-storage', 'deferred-text-product-storage',
    'deferred-text-struct-storage', 'deferred-text-named-storage',
    'deferred-text-field-assignment', 'deferred-text-index-assignment',
    'deferred-text-array-push', 'deferred-text-dictionary-key-storage',
    'deferred-text-dictionary-value-storage', 'deferred-text-dictionary-put',
    'deferred-text-contextual-struct-storage', 'deferred-text-growable-array-storage',
    'deferred-text-bounded-array-storage', 'deferred-text-dictionary-index-key',
    'deferred-text-set-insert', 'deferred-text-deque-push'
)
if ($PositiveOnly) { $names = @() }
$record = [ordered]@{
    schemaVersion = 1; status = 'running'; observeBaseline = [bool]$ObserveBaseline; positiveOnly = [bool]$PositiveOnly
    completed = 0; total = $names.Count + 1; cases = @(); inputHashes = [ordered]@{}
    promotion = 'managed focused only; selfhost and Stage2/Stage3 pending'
}
try {
    $positive = Join-Path $root 'examples/regression/1725-materialized-text-storage-boundaries.slg'
    $sources = @($positive) + @($names | ForEach-Object { Join-Path $root "examples/regression/diagnostics/$_.slg" })
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $sources
    foreach ($path in @($compiler, $PSCommandPath) + $sources + @(
        (Join-Path $root 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs')
    )) { $record.inputHashes[$path] = (Get-FileHash -LiteralPath $path).Hash }
    foreach ($name in $names) {
        $source = Join-Path $root "examples/regression/diagnostics/$name.slg"
        $expected = Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt"
        $expectedDiagnostic = [IO.File]::ReadAllText($expected).Trim()
        if ([string]::IsNullOrWhiteSpace($expectedDiagnostic)) { throw "expected semantic diagnostic is empty: $expected" }
        $record.inputHashes[$expected] = (Get-FileHash -LiteralPath $expected).Hash
        $caseOutput = Join-Path $output $name
        [IO.Directory]::CreateDirectory($caseOutput) | Out-Null
        $actual = (& dotnet $compiler build $source --llvm $llvm -o (Join-Path $caseOutput "$name.exe") --keep-temps 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output "$name.log"), $actual + "`n")
        $emitted = @(Get-ChildItem -LiteralPath $caseOutput -Recurse -File | Where-Object Extension -In '.ll', '.exe')
        $passed = Test-ExpectedStorageDiagnostic -Actual $actual -Expected $expectedDiagnostic -ExitCode $exitCode -OutputCount $emitted.Count
        $record.cases += @{ name = $name; passed = $passed; exitCode = $exitCode; output = $actual; emittedLlvmOrExecutableCount = $emitted.Count; executableRun = $false }
        if ($passed) { $record.completed++ }
        Write-Host "$name = $passed"
        if (-not $passed -and $actual -match "\[module '(?!<main>')[^']+'\]") {
            throw 'a dependency module failed before the focused source; remaining cases were not run'
        }
    }
    $positiveOutput = Join-Path $output 'positive'
    [IO.Directory]::CreateDirectory($positiveOutput) | Out-Null
    $actual = (& dotnet $compiler run $positive --llvm $llvm -o (Join-Path $positiveOutput 'positive.exe') --keep-temps 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'positive.log'), $actual + "`n")
    $value = 7
    $expected = (@("value=$value", "value=$value", "value=$value", "value=$value", "immediate=$value") -join "`n")
    $passed = $exitCode -eq 0 -and $actual -ceq $expected
    $assembly = $false
    $closure = $false
    if ($passed) {
        $llvmPath = Join-Path $positiveOutput 'positive.ll'
        & (Join-Path $llvm 'bin/llvm-as.exe') $llvmPath -o (Join-Path $positiveOutput 'positive.bc')
        $assembly = $LASTEXITCODE -eq 0
        if (-not $assembly) { throw 'positive LLVM assembly failed' }
        & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $llvmPath
        $closure = $true
        foreach ($path in @($llvmPath, (Join-Path $positiveOutput 'positive.exe'), (Join-Path $output 'positive.log'))) {
            $record.inputHashes[$path] = (Get-FileHash -LiteralPath $path).Hash
        }
    }
    $record.cases += @{ name = '1725-materialized-text-storage-boundaries'; passed = $passed; exitCode = $exitCode; output = $actual; expected = $expected; reference = 'independent .NET integer interpolation'; executableRun = $true; llvmAsPassed = $assembly; directCallClosurePassed = $closure }
    if ($passed) { $record.completed++ }
    foreach ($path in $record.inputHashes.Keys) {
        if ((Get-FileHash -LiteralPath $path).Hash -cne $record.inputHashes[$path]) { throw "verification input changed: $path" }
    }
    $record.inputHashesStable = $true
    $record.status = if ($record.completed -eq $record.total) { 'passed' } elseif ($ObserveBaseline) { 'baseline-observed-not-passing' } else { 'failed' }
} catch {
    $record.status = 'failed'; $record.failure = $_.Exception.Message; throw
} finally {
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), (($record | ConvertTo-Json -Depth 7) + "`n"))
    Write-Host "[deferred Text storage] $($record.status) $($record.completed)/$($record.total); $output/result.json"
}
if ($record.status -eq 'failed') { exit 1 }
