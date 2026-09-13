[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$launcher = Join-Path $root 'scripts/invoke-detached-selfhost-verification.ps1'
$schema = Join-Path $root 'scripts/contracts/detached-selfhost-verification-result.schema.json'
$compiler = Join-Path $root 'artifacts/scratch/c341-fixed-copy/candidate-v2/compiler/bin/Sollang.Compiler/release/Sollang.Compiler.dll'
$output = Join-Path $root 'artifacts/scratch/portable-memory-io/detached-9c16-v1'
$sha256 = '9C16D0CEC55FB471E39E2C879C415161D8530FED3A903371136A782C5FB7F235'

foreach ($path in @($launcher, $schema, $compiler)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "portable detached route input is missing: $path" }
}
$launcherText = [IO.File]::ReadAllText($launcher)
foreach ($required in @(
    '"PortableMemoryIo" { Join-Path $PSScriptRoot "verify-portable-memory-io-contract.ps1" }',
    '"-PortableMemoryIoExpectedCompilerSha256", $PortableMemoryIoExpectedCompilerSha256',
    '"-ExpectedCompilerSha256", $PortableMemoryIoExpectedCompilerSha256',
    'PortableMemoryIo compiler hash mismatch',
    'PortableMemoryIo requires compiler, expected SHA-256, and output directory together'
)) {
    if (-not $launcherText.Contains($required, [StringComparison]::Ordinal)) {
        throw "portable detached route lost fixed authority: $required"
    }
}

function Require-Failure([hashtable]$Arguments, [string]$Expected) {
    $failed = $false
    try {
        & $launcher @Arguments | Out-Null
    } catch {
        $failed = $_.Exception.Message.Contains($Expected, [StringComparison]::Ordinal)
    }
    if (-not $failed) { throw "portable detached negative control did not fail with: $Expected" }
}
Require-Failure @{ Verification = 'PortableMemoryIo' } 'PortableMemoryIo compiler, expected SHA-256, and output directory are required'
Require-Failure @{
    Verification = 'Probe'
    PortableMemoryIoCompiler = $compiler
    PortableMemoryIoExpectedCompilerSha256 = $sha256
    PortableMemoryIoOutputDirectory = $output
} 'required only for Verification PortableMemoryIo'
Require-Failure @{
    Verification = 'PortableMemoryIo'
    PortableMemoryIoCompiler = $compiler
    PortableMemoryIoExpectedCompilerSha256 = ('0' * 64)
    PortableMemoryIoOutputDirectory = $output
    ValidateInputsOnly = $true
} 'PortableMemoryIo compiler hash mismatch'

$validated = & $launcher -Verification PortableMemoryIo `
    -PortableMemoryIoCompiler $compiler `
    -PortableMemoryIoExpectedCompilerSha256 $sha256 `
    -PortableMemoryIoOutputDirectory $output `
    -ValidateInputsOnly | ConvertFrom-Json
if (-not $validated.validated -or $validated.compilerSha256 -cne $sha256 -or
    [IO.Path]::GetFullPath($validated.outputDirectory) -cne [IO.Path]::GetFullPath($output)) {
    throw 'portable detached positive input validation drifted'
}

$record = [ordered]@{
    schemaVersion = 2
    runId = 'portable-memory-static-control'
    verification = 'PortableMemoryIo'
    executionMode = 'detached-supervisor'
    supervisorPid = 1
    startedAtUtc = '2026-09-13T00:00:00Z'
    completedAtUtc = '2026-09-13T00:00:01Z'
    durationMilliseconds = 1000
    exitCode = 0
    status = 'passed'
    failureIds = @()
    logPath = 'portable.log'
    standardErrorPath = 'portable.log.stderr'
    cancellationRequestPath = 'portable.result.json.cancel.json'
    targetProcessId = 2
    targetExitCode = 0
    orphanProcessIds = @()
    processAudit = [ordered]@{ method = 'observed-pid-creation-time-snapshots'; completed = $true; snapshotCount = 1; observedProcessIds = @(2) }
}
$json = $record | ConvertTo-Json -Depth 8
if (-not ($json | Test-Json -SchemaFile $schema)) { throw 'portable detached success record failed schema' }
$record.orphanProcessIds = @(4242)
if (($record | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $schema -ErrorAction SilentlyContinue) {
    throw 'portable detached schema accepted a success orphan'
}
$record.orphanProcessIds = @()
$record.verification = 'PortableMemoryIoUnknown'
if (($record | ConvertTo-Json -Depth 8) | Test-Json -SchemaFile $schema -ErrorAction SilentlyContinue) {
    throw 'portable detached schema accepted an unknown verification mode'
}

Write-Host '[detached portable-memory-io route] PASS positive validation and 5 negative/static controls'
