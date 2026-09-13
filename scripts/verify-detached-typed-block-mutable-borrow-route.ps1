[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CompilerAssembly = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$launcher = Join-Path $root 'scripts/invoke-detached-selfhost-verification.ps1'
$schema = Join-Path $root 'scripts/contracts/detached-selfhost-verification-result.schema.json'
$candidates = @(
    $CompilerAssembly,
    (Join-Path $root 'artifacts/scratch/socket-completion-submission/candidate-v11/bin/Sollang.Compiler/release/Sollang.Compiler.dll'),
    (Join-Path $root 'artifacts/scratch/c341-fixed-copy/candidate-v2/compiler/bin/Sollang.Compiler/release/Sollang.Compiler.dll')
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$compiler = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($compiler)) { throw 'typed-block detached route has no existing artifact compiler input' }
$compiler = [IO.Path]::GetFullPath($compiler)
$output = Join-Path $root 'artifacts/scratch/typed-block-mutable-borrow/detached-route-static-control'
$sha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash

foreach ($path in @($launcher, $schema)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "typed-block detached route input is missing: $path" }
}
$launcherText = [IO.File]::ReadAllText($launcher)
foreach ($required in @(
    '"TypedBlockMutableBorrow" { Join-Path $PSScriptRoot "verify-typed-block-mutable-borrow-focused.ps1" }',
    '"-TypedBlockMutableBorrowExpectedCompilerSha256", $TypedBlockMutableBorrowExpectedCompilerSha256',
    '"-ExpectedCompilerSha256", $TypedBlockMutableBorrowExpectedCompilerSha256',
    '"-RunManaged"',
    'TypedBlockMutableBorrow compiler hash mismatch',
    'TypedBlockMutableBorrow requires compiler, expected SHA-256, and output directory together'
)) {
    if (-not $launcherText.Contains($required, [StringComparison]::Ordinal)) {
        throw "typed-block detached route lost fixed authority: $required"
    }
}

function Require-Failure([hashtable]$Arguments, [string]$Expected) {
    $failed = $false
    try {
        & $launcher @Arguments | Out-Null
    } catch {
        $failed = $_.Exception.Message.Contains($Expected, [StringComparison]::Ordinal)
    }
    if (-not $failed) { throw "typed-block detached negative control did not fail with: $Expected" }
}

Require-Failure @{ Verification = 'TypedBlockMutableBorrow' } 'compiler, expected SHA-256, and output directory are required'
Require-Failure @{
    Verification = 'TypedBlockMutableBorrow'
    TypedBlockMutableBorrowCompiler = $compiler
    TypedBlockMutableBorrowExpectedCompilerSha256 = $sha256
} 'requires compiler, expected SHA-256, and output directory together'
Require-Failure @{
    Verification = 'Probe'
    TypedBlockMutableBorrowCompiler = $compiler
    TypedBlockMutableBorrowExpectedCompilerSha256 = $sha256
    TypedBlockMutableBorrowOutputDirectory = $output
} 'required only for Verification TypedBlockMutableBorrow'
Require-Failure @{
    Verification = 'TypedBlockMutableBorrow'
    TypedBlockMutableBorrowCompiler = $compiler
    TypedBlockMutableBorrowExpectedCompilerSha256 = ('0' * 64)
    TypedBlockMutableBorrowOutputDirectory = $output
    ValidateInputsOnly = $true
} 'TypedBlockMutableBorrow compiler hash mismatch'
Require-Failure @{
    Verification = 'TypedBlockMutableBorrow'
    TypedBlockMutableBorrowCompiler = $launcher
    TypedBlockMutableBorrowExpectedCompilerSha256 = (Get-FileHash -LiteralPath $launcher -Algorithm SHA256).Hash
    TypedBlockMutableBorrowOutputDirectory = $output
    ValidateInputsOnly = $true
} 'TypedBlockMutableBorrowCompiler must be under'
Require-Failure @{
    Verification = 'TypedBlockMutableBorrow'
    TypedBlockMutableBorrowCompiler = $compiler
    TypedBlockMutableBorrowExpectedCompilerSha256 = $sha256
    TypedBlockMutableBorrowOutputDirectory = (Join-Path $root 'typed-block-route-outside-artifacts')
    ValidateInputsOnly = $true
} 'TypedBlockMutableBorrowOutputDirectory must be under'

$validated = & $launcher -Verification TypedBlockMutableBorrow `
    -TypedBlockMutableBorrowCompiler $compiler `
    -TypedBlockMutableBorrowExpectedCompilerSha256 $sha256 `
    -TypedBlockMutableBorrowOutputDirectory $output `
    -ValidateInputsOnly | ConvertFrom-Json
if (-not $validated.validated -or $validated.verification -cne 'TypedBlockMutableBorrow' -or
    $validated.compilerSha256 -cne $sha256 -or
    [IO.Path]::GetFullPath($validated.compiler) -cne $compiler -or
    [IO.Path]::GetFullPath($validated.outputDirectory) -cne [IO.Path]::GetFullPath($output)) {
    throw 'typed-block detached positive input validation drifted'
}

$record = [ordered]@{
    schemaVersion = 2
    runId = 'typed-block-static-control'
    verification = 'TypedBlockMutableBorrow'
    executionMode = 'detached-supervisor'
    supervisorPid = 1
    startedAtUtc = '2026-09-13T00:00:00Z'
    completedAtUtc = '2026-09-13T00:00:01Z'
    durationMilliseconds = 1000
    exitCode = 0
    status = 'passed'
    failureIds = @()
    logPath = 'typed-block.log'
    standardErrorPath = 'typed-block.log.stderr'
    cancellationRequestPath = 'typed-block.result.json.cancel.json'
    targetProcessId = 2
    targetExitCode = 0
    orphanProcessIds = @()
    processAudit = [ordered]@{ method = 'observed-pid-creation-time-snapshots'; completed = $true; snapshotCount = 1; observedProcessIds = @(2) }
}
$json = $record | ConvertTo-Json -Depth 8
if (-not ($json | Test-Json -SchemaFile $schema)) { throw 'typed-block detached success record failed schema' }
$record.verification = 'TypedBlockMutableBorrowUnknown'
if (($record | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $schema -ErrorAction SilentlyContinue) {
    throw 'typed-block detached schema accepted an unknown verification mode'
}

Write-Host '[detached typed-block mutable-borrow route] PASS positive input validation and 7 negative/static controls; compiler launches 0'
