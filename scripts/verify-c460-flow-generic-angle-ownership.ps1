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
        defectId = 'C2026-09-22-460'
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
        if (-not (Test-Path -LiteralPath $path)) { throw "C460 required input is missing: $path" }
    }

    $astSource = Join-Path $root 'selfhost/syntax/ast.slg'
    $aliasSource = Join-Path $root 'selfhost/ir/typed/value_aliases.slg'
    $finalizeSource = Join-Path $root 'selfhost/ir/typed/resolved_context_finalize.slg'
    $fixture1760 = Join-Path $root 'examples/regression/1760-selfhost-flow-generic-angle-ownership.slg'
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source @($astSource, $aliasSource, $finalizeSource)
    if ($LASTEXITCODE -ne 0) { throw 'C460 AST source format failed' }
    $astText = [IO.File]::ReadAllText($astSource)
    $aliasText = [IO.File]::ReadAllText($aliasSource)
    $finalizeText = [IO.File]::ReadAllText($finalizeSource)
    if (-not $astText.Contains('grammar.ruleIdFlowGenericArgument()', [StringComparison]::Ordinal)) {
        throw 'C460 FlowGenericArgument angle owner is missing'
    }
    if (-not $aliasText.Contains('nodes[binding!.operand0].kind == 5', [StringComparison]::Ordinal)) {
        throw 'C460 finalized binding-read alias contract is missing'
    }
    if (-not $finalizeText.Contains("nodes -> sealPostArithmeticSlotTypes(prepared)`n    # The second slot pass", [StringComparison]::Ordinal) -or
        -not $finalizeText.Contains("nodes -> sealLateValueAliasTypes(prepared)`n    nodes -> sealFinalContextualNumericLiterals", [StringComparison]::Ordinal)) {
        throw 'C460 late alias/numeric fixed-point order is missing'
    }
    $completed++

    $sources = @(Get-Content -LiteralPath (Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
    $compilerLlvm = Join-Path $output 'compiler.ll'
    $compilerStdout = Join-Path $output 'compiler-build.stdout.txt'
    $compilerStderr = Join-Path $output 'compiler.err'
    $compilerBitcode = Join-Path $output 'compiler.bc'
    $compiler = Join-Path $output 'compiler.exe'
    Invoke-VerificationProcessToFile -FilePath 'dotnet' `
        -ArgumentList (@($managedCompiler, 'build') + $sources + @(
            '-o', $compiler, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps')) `
        -Description 'C460 managed current-source compiler build' -OutputPath $compilerStdout -ErrorPath $compilerStderr `
        -TimeoutMilliseconds 3600000
    $compilerDiagnostics = [IO.File]::ReadAllText($compilerStdout) + [IO.File]::ReadAllText($compilerStderr)
    if ([regex]::IsMatch($compilerDiagnostics, '(?m)(?:^|\r?\n)(?:warning S|note N)\d{3}\b')) {
        throw 'C460 managed compiler build emitted a warning or note'
    }
    if (-not (Test-Path -LiteralPath $compilerLlvm -PathType Leaf)) {
        $generatedLlvm = Get-ChildItem -LiteralPath $output -Filter 'compiler*.ll' | Select-Object -First 1
        if ($null -eq $generatedLlvm) { throw 'C460 compiler build did not preserve LLVM output' }
        $compilerLlvm = $generatedLlvm.FullName
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C460 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o $compilerBitcode
    if ($LASTEXITCODE -ne 0) { throw 'C460 compiler llvm-as failed' }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'C460 compiler executable is missing' }
    $completed++

    $astRun = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('ast-nodes', $fixture1760) -Description 'C460 AST ownership' -TimeoutMilliseconds 30000
    if ($astRun.ExitCode -ne 0 -or $astRun.Stderr.Length -ne 0) {
        throw "C460 AST inventory failed:`n$($astRun.Stdout)`n$($astRun.Stderr)"
    }
    $fixtureText = [IO.File]::ReadAllText($fixture1760)
    $comparisonSpans = @([regex]::Matches($astRun.Stdout, '(?m)^ast source 0 node \d+ kind 19 .* start (?<start>\d+) length (?<length>\d+) '))
    $spuriousGenericFlow = @($comparisonSpans | Where-Object {
        $start = [int]$_.Groups['start'].Value
        $length = [int]$_.Groups['length'].Value
        $fixtureText.Substring($start, $length).Contains('choose<Bool>', [StringComparison]::Ordinal)
    })
    $realArgumentComparison = @($comparisonSpans | Where-Object {
        $start = [int]$_.Groups['start'].Value
        $length = [int]$_.Groups['length'].Value
        $fixtureText.Substring($start, $length) -ceq '3 > 2'
    })
    if ($spuriousGenericFlow.Count -ne 0 -or $realArgumentComparison.Count -lt 1) {
        throw "C460 AST ownership mismatch: generic=$($spuriousGenericFlow.Count), argument=$($realArgumentComparison.Count)"
    }
    $completed++

    $sequential = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('typed-ir-nodes', $fixture1760) -Description 'C460 sequential Typed IR' -TimeoutMilliseconds 30000
    $parallel = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('typed-ir-nodes-parallel', $fixture1760) -Description 'C460 parallel Typed IR' -TimeoutMilliseconds 30000
    if ($sequential.ExitCode -ne 0 -or $parallel.ExitCode -ne 0 -or
        $sequential.Stderr.Length -ne 0 -or $parallel.Stderr.Length -ne 0 -or
        $sequential.Stdout -cne $parallel.Stdout) {
        throw 'C460 sequential/parallel Typed IR identity failed'
    }
    $completed++

    foreach ($fixture in @(
        '1760-selfhost-flow-generic-angle-ownership',
        '1761-selfhost-late-mutable-read-alias-width')) {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
            -Compiler $compiler -Label "c460-$fixture" -Fixture $fixture -Platform windows `
            -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
            -OutputDirectory (Join-Path $output $fixture) -Jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw "C460 exact fixture failed: $fixture" }
        $completed++
    }

    $fixture683Sources = @(Get-Content -LiteralPath (Join-Path $root 'examples/regression/expected/683-selfhost-cli-package-lock-render.sources.txt') |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
    $fixture683Executable = Join-Path $output '683-selfhost-cli-package-lock-render.exe'
    $fixture683Llvm = Join-Path $output '683-selfhost-cli-package-lock-render.ll'
    $fixture683Build = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList (@('build') + $fixture683Sources + @(
            '-o', $fixture683Executable, '--target', 'windows-x64', '--llvm', $llvmRoot,
            '--stdlib', $stdlib, '--jobs', $Jobs.ToString([Globalization.CultureInfo]::InvariantCulture),
            '-O1', '--keep-temps')) `
        -Description 'C460 package-lock checked build' -TimeoutMilliseconds 3600000
    $fixture683Diagnostics = $fixture683Build.Stdout + $fixture683Build.Stderr
    if ($fixture683Build.ExitCode -ne 0 -or
        [regex]::IsMatch($fixture683Diagnostics, '(?m)(?:compiler error S008|compiler error S059|warning S\d+|note N\d+)')) {
        throw "C460 package-lock checked build failed:`n$fixture683Diagnostics"
    }
    if (-not (Test-Path -LiteralPath $fixture683Llvm -PathType Leaf)) {
        $selfhostLlvm = "$fixture683Executable.ll"
        if (Test-Path -LiteralPath $selfhostLlvm -PathType Leaf) {
            $fixture683Llvm = $selfhostLlvm
        }
    }
    if (-not (Test-Path -LiteralPath $fixture683Llvm -PathType Leaf)) {
        throw 'C460 package-lock checked LLVM is missing'
    }
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $fixture683Llvm
    if ($LASTEXITCODE -ne 0) { throw 'C460 package-lock direct-call closure failed' }
    & $llvmAs $fixture683Llvm -o (Join-Path $output '683-selfhost-cli-package-lock-render.bc')
    if ($LASTEXITCODE -ne 0) { throw 'C460 package-lock llvm-as failed' }
    $completed++

    Save-Result 'passed' 0
    Write-Host "[C460] PASS $completed/$total generic flow angle ownership, late alias width, and package-lock checked build."
} catch {
    $failureIds.Add('C460_GATE_FAILED')
    Save-Result 'failed' 1
    throw
}
