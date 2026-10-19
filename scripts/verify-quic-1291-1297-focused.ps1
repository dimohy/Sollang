[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 64)][int]$Jobs = 4,
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$compiler = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }))
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
$scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "output must be under artifacts/scratch: $output"
}
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) {
        throw "output must be new or empty: $output"
    }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$expectedHash = $ExpectedCompilerSha256.ToUpperInvariant()
$batchVerifier = Join-Path $root 'scripts/verify-native-exact-fixture-batch.ps1'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$stdlibRoot = Join-Path $root 'stdlib'
$fixtures = @('1291-quic-unidirectional-stream-registry', '1297-quic-unidirectional-stream-owners')
$resultPath = Join-Path $output 'result.json'
$batchLabel = 'quic-1291-1297-current-source'
$batchResultPath = Join-Path $output "$batchLabel-batch-results.json"
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$status = 'failed'
$compilerHashStart = $null
$compilerHashEnd = $null
$caught = $null

try {
    foreach ($path in @($compiler, $batchVerifier)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "required input is missing: $path" }
    }
    foreach ($path in @($llvmRoot, $stdlibRoot)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "required input is missing: $path" }
    }
    $compilerHashStart = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
    if ($compilerHashStart -cne $expectedHash) {
        $failureIds.Add('COMPILER_HASH_MISMATCH')
        throw "compiler hash mismatch: expected=$expectedHash actual=$compilerHashStart"
    }

    $arguments = @{
        Compiler = $compiler
        Label = $batchLabel
        Platform = 'windows'
        LlvmRoot = $llvmRoot
        StdlibRoot = $stdlibRoot
        RepositoryRoot = $root
        OutputDirectory = $output
        Jobs = $Jobs
        Fixture = $fixtures
    }
    if ($ValidateInputsOnly) { $arguments.ValidateInputsOnly = $true }
    & $batchVerifier @arguments

    if ($ValidateInputsOnly) {
        $status = 'validated-inputs'
    }
    else {
        if (-not (Test-Path -LiteralPath $batchResultPath -PathType Leaf)) {
            $failureIds.Add('BATCH_RESULT_MISSING')
            throw 'native exact batch did not publish its result'
        }
        $batch = Get-Content -LiteralPath $batchResultPath -Raw | ConvertFrom-Json
        if ($batch.state -cne 'passed' -or $batch.completed -ne 2 -or $batch.passed -ne 2 -or
            $batch.failed -ne 0 -or $batch.missing -ne 0 -or $batch.total -ne 2 -or
            $batch.compilerSha256 -cne $expectedHash) {
            $failureIds.Add('BATCH_RESULT_INVALID')
            throw 'native exact batch result does not prove 2/2 current-source cases'
        }
        $actualFixtures = @($batch.results | ForEach-Object Fixture | Sort-Object)
        if (($actualFixtures -join '|') -cne (@($fixtures | Sort-Object) -join '|') -or
            @($batch.results | Where-Object { -not $_.Success }).Count -ne 0) {
            $failureIds.Add('BATCH_RESULT_INVALID')
            throw 'native exact batch fixture identity or success state drifted'
        }
        $completed = 2
        $status = 'passed'
    }
}
catch {
    if ($failureIds.Count -eq 0) { $failureIds.Add('FOCUSED_GATE_FAILED') }
    $caught = $_
}
finally {
    if (Test-Path -LiteralPath $compiler -PathType Leaf) {
        $compilerHashEnd = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        if ($null -ne $compilerHashStart -and $compilerHashEnd -cne $compilerHashStart) {
            $failureIds.Add('COMPILER_DRIFT')
            $status = 'failed'
        }
    }
    $record = [ordered]@{
        schemaVersion = 1
        status = $status
        scope = 'current-source-managed-native-quic-1291-1297'
        completed = $completed
        total = 2
        fixtureIds = $fixtures
        compilerPath = $compiler
        expectedCompilerSha256 = $expectedHash
        compilerSha256Start = $compilerHashStart
        compilerSha256End = $compilerHashEnd
        compilerDrift = $null -ne $compilerHashStart -and $compilerHashEnd -cne $compilerHashStart
        batchResultPath = if (Test-Path -LiteralPath $batchResultPath) { $batchResultPath } else { $null }
        batchResultSha256 = if (Test-Path -LiteralPath $batchResultPath) { (Get-FileHash -LiteralPath $batchResultPath -Algorithm SHA256).Hash } else { $null }
        failureIds = @($failureIds | Sort-Object -Unique)
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
    Write-Host "[QUIC 1291/1297] $status $completed/2; result=$resultPath"
}

if ($null -ne $caught) { throw $caught }
