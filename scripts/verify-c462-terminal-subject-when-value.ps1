[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$BuildDirectory,
    [Parameter(Mandatory)][string]$FormatCompiler,
    [ValidateRange(1, 16)][int]$Jobs = 8
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'C462_FRESH_OUTPUT_REQUIRED' }
$build = (Resolve-Path -LiteralPath $BuildDirectory).Path
$compiler = Join-Path $build 'compiler.exe'
[string]$compilerLlvm = ''
$inputHashesStart = [ordered]@{}
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$total = 8

function Save-Result([string]$Status, [int]$ExitCode) {
    $fingerprintInputs = @(
        'selfhost/ir/typed/resolved_context_finalize.slg',
        'examples/regression/1762-selfhost-terminal-subject-when-value.slg',
        'examples/regression/expected/1762-selfhost-terminal-subject-when-value.stdout.txt',
        'examples/regression/907-x25519-rfc7748.slg',
        'examples/regression/1167-quic-endpoint-two-connection-routing.slg'
    )
    $fingerprintText = ($fingerprintInputs | ForEach-Object {
        $path = Join-Path $root $_
        "$_=$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
    }) -join "`n"
    $fingerprintBytes = [Text.Encoding]::UTF8.GetBytes($fingerprintText)
    $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($fingerprintBytes))
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-22-462'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        inputFingerprint = $fingerprint
        inputHashes = [ordered]@{}
        inputsStable = $true
        processesStopped = $true
        compilerBuildResult = Join-Path $build 'result.json'
        candidateCompiler = if (Test-Path -LiteralPath $compiler -PathType Leaf) {
            [IO.Path]::GetRelativePath($root, $compiler).Replace('\', '/')
        } else { $null }
        candidateCompilerSha256 = if (Test-Path -LiteralPath $compiler -PathType Leaf) {
            (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        } else { $null }
    }
    foreach ($relativePath in $fingerprintInputs) {
        $record.inputHashes[(Join-Path $root $relativePath)] = (Get-FileHash -LiteralPath (Join-Path $root $relativePath) -Algorithm SHA256).Hash
    }
    foreach ($path in $inputHashesStart.Keys) {
        $record.inputHashes[$path] = $inputHashesStart[$path]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashesStart[$path]) {
            $record.inputsStable = $false
        }
    }
    if (-not $record.inputsStable) {
        $record.status = 'failed'
        $record.exitCode = 1
        $record.failureIds += 'C462_INPUT_DRIFT'
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    $managedCompiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
    $llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
    $llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
    $stdlib = Join-Path $root 'stdlib'
    foreach ($path in @($managedCompiler, $llvmAs, $stdlib, $FormatCompiler)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "C462 required input is missing: $path" }
    }

    $finalizeSource = Join-Path $root 'selfhost/ir/typed/resolved_context_finalize.slg'
    $fixture1762 = Join-Path $root 'examples/regression/1762-selfhost-terminal-subject-when-value.slg'
    $productProof = Join-Path $output 'compiler-product-inputs.json'
    & python (Join-Path $PSScriptRoot 'verify-current-compiler-product.py') --build $build --output $productProof
    if ($LASTEXITCODE -ne 0) { throw 'C462_CURRENT_COMPILER_PRODUCT_INVALID' }
    $product = Get-Content -LiteralPath $productProof -Raw | ConvertFrom-Json
    $compilerLlvm = $product.llvm
    foreach ($property in $product.inputHashes.PSObject.Properties) { $inputHashesStart[$property.Name] = $property.Value }
    foreach ($path in @($PSCommandPath, $managedCompiler, $FormatCompiler, $finalizeSource, $fixture1762) +
        @(Get-ChildItem -LiteralPath (Join-Path $root 'examples/regression/expected') -File |
            Where-Object { $_.Name -match '^(1762-selfhost-terminal-subject-when-value|907-x25519-rfc7748|1167-quic-endpoint-two-connection-routing)\.' } |
            ForEach-Object FullName) + @(
            (Join-Path $root 'examples/regression/907-x25519-rfc7748.slg'),
            (Join-Path $root 'examples/regression/1167-quic-endpoint-two-connection-routing.slg'),
            (Join-Path $PSScriptRoot 'verification-process.ps1'),
            (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1'),
            (Join-Path $PSScriptRoot 'verify-c462-typed-ir.py'),
            (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
            (Join-Path $PSScriptRoot 'native-exact-source-closure.ps1'),
            (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1'),
            (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'))) {
        $inputHashesStart[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Compiler $FormatCompiler -Check -Source @($finalizeSource, $fixture1762)
    if ($LASTEXITCODE -ne 0) { throw 'C462 authoritative source format failed' }
    $finalizeText = [IO.File]::ReadAllText($finalizeSource)
    if (-not $finalizeText.Contains('seedReturnedNumericSubjectWhenFromCompleteLiteralArms nodes:', [StringComparison]::Ordinal) -or
        -not $finalizeText.Contains('and candidate.operand0 == nodes[function.operand0].operand0', [StringComparison]::Ordinal) -or
        -not $finalizeText.Contains("nodes -> seedReturnedNumericSubjectWhenFromCompleteLiteralArms(prepared)`n    # Final return selection", [StringComparison]::Ordinal)) {
        throw 'C462 terminal subject-when ownership contract is missing'
    }
    $completed++
    Save-Result 'running' 0

    # Current-source, zero-diagnostic managed build evidence was validated above.
    $compilerBitcode = Join-Path $output 'compiler.bc'
    $completed++
    Save-Result 'running' 0

    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $compilerLlvm
    if ($LASTEXITCODE -ne 0) { throw 'C462 compiler direct-call closure failed' }
    & $llvmAs $compilerLlvm -o $compilerBitcode
    if ($LASTEXITCODE -ne 0) { throw 'C462 compiler llvm-as failed' }
    if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'C462 compiler executable is missing' }
    $completed++
    Save-Result 'running' 0

    $sequential = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('typed-ir-nodes', $fixture1762) -Description 'C462 sequential Typed IR' -TimeoutMilliseconds 30000
    $parallel = Invoke-VerificationProcessCapture -FilePath $compiler `
        -ArgumentList @('typed-ir-nodes-parallel', $fixture1762) -Description 'C462 parallel Typed IR' -TimeoutMilliseconds 30000
    foreach ($run in @(@('sequential', $sequential), @('parallel', $parallel))) {
        [IO.File]::WriteAllText((Join-Path $output "$($run[0]).typed-ir.stdout.txt"), $run[1].Stdout)
        [IO.File]::WriteAllText((Join-Path $output "$($run[0]).typed-ir.stderr.txt"), $run[1].Stderr)
    }
    if ($sequential.ExitCode -ne 0 -or $parallel.ExitCode -ne 0 -or
        $sequential.Stderr.Length -ne 0 -or $parallel.Stderr.Length -ne 0 -or
        $sequential.Stdout -cne $parallel.Stdout) {
        throw 'C462 sequential/parallel Typed IR identity failed'
    }
    & python (Join-Path $PSScriptRoot 'verify-c462-typed-ir.py') --input (Join-Path $output 'sequential.typed-ir.stdout.txt') --output (Join-Path $output 'typed-ir-ownership.json')
    if ($LASTEXITCODE -ne 0) { throw 'C462 terminal/nonterminal function-result ownership mismatch' }
    $completed++
    Save-Result 'running' 0

    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
        -Compiler $managedCompiler -Label 'c462-managed-1762' -Fixture '1762-selfhost-terminal-subject-when-value' `
        -Platform windows -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
        -OutputDirectory (Join-Path $output 'managed-1762') -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'C462 managed 1762 exact fixture failed' }
    $completed++
    Save-Result 'running' 0

    foreach ($fixture in @(
        '1762-selfhost-terminal-subject-when-value',
        '907-x25519-rfc7748',
        '1167-quic-endpoint-two-connection-routing')) {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
            -Compiler $compiler -Label "c462-$fixture" -Fixture $fixture -Platform windows `
            -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
            -OutputDirectory (Join-Path $output $fixture) -Jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw "C462 exact fixture failed: $fixture" }
        $completed++
    Save-Result 'running' 0
    }

    Save-Result 'passed' 0
    if (-not (Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json).inputsStable) { throw 'C462_INPUT_DRIFT' }
    Write-Host "[C462] PASS $completed/$total terminal subject-when value, X25519, and QUIC routing."
} catch {
    $failureIds.Add('C462_GATE_FAILED')
    Save-Result 'failed' 1
    throw
}
