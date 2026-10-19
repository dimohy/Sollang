[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineCompiler,
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$FixtureArtifactsDirectory = $OutputDirectory,
    [ValidateRange(1, 16)][int]$Jobs = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$fixtureArtifacts = [IO.Path]::GetFullPath($FixtureArtifactsDirectory)
[IO.Directory]::CreateDirectory($fixtureArtifacts) | Out-Null
$resultPath = Join-Path $output 'c468-result.json'
$baseline = (Resolve-Path -LiteralPath $BaselineCompiler).Path
$candidate = (Resolve-Path -LiteralPath $CandidateCompiler).Path
$baselineHash = (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash
$candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$total = 7

$sourceManifest = 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$inputPaths = @(
    $sourceManifest,
    'scripts/verify-c468-nested-stream-slice.ps1',
    'scripts/verify-native-exact-fixture.ps1',
    'scripts/verify-native-exact-fixture-batch.ps1',
    'scripts/verification-process.ps1',
    'examples/regression/1555-generic-stream-consumer-call-identity.slg',
    'examples/regression/expected/1555-generic-stream-consumer-call-identity.stdout.txt',
    'examples/regression/expected/1555-generic-stream-consumer-call-identity.sources.txt',
    'examples/regression/583-stream-state-take-skip.slg',
    'examples/regression/expected/583-stream-state-take-skip.stdout.txt',
    'examples/regression/585-stream-transaction-risk-scan.slg',
    'examples/regression/expected/585-stream-transaction-risk-scan.stdout.txt',
    'examples/regression/diagnostics/generic-dynamic-array-readonly-take.slg',
    'examples/regression/diagnostics/generic-dynamic-array-readonly-take.stderr.contains.txt',
    'syntax/sollang.grammar',
    'syntax/sollang.lexer'
) + @(Get-Content -LiteralPath (Join-Path $root $sourceManifest) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_.Trim() })
$managedSourceRoots = @('src/Sollang.Compiler', 'tests/Sollang.ExampleTests')
$inputPaths += @(foreach ($sourceRoot in $managedSourceRoots) {
    Get-ChildItem -LiteralPath (Join-Path $root $sourceRoot) -Recurse -File |
        Where-Object { $_.Extension -in @('.cs', '.csproj') -and
            $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
        ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/') }
})
$inputPaths = @($inputPaths | Sort-Object -Unique)

function Get-InputHashes {
    $hashes = [ordered]@{}
    foreach ($relative in $inputPaths) {
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

function Save-Result([string]$Status, [int]$ExitCode) {
    $endHashes = Get-InputHashes
    $endFingerprint = Get-Fingerprint $endHashes
    if ($endFingerprint -cne $inputFingerprint -and -not $failureIds.Contains('C468_INPUT_DRIFT')) {
        $failureIds.Add('C468_INPUT_DRIFT')
        $Status = 'failed'
        $ExitCode = 1
    }
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-23-468'
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
        baselineCompilerSha256 = $baselineHash
        candidateCompilerSha256 = $candidateHash
        fixtureArtifactsDirectory = $fixtureArtifacts
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
    if ($ExitCode -ne 0) { throw "C468 verification failed; see $resultPath" }
}

function Invoke-Captured([string]$File, [string[]]$Arguments, [string]$Description, [string]$LogName,
    [int]$TimeoutMilliseconds = 600000) {
    $result = Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments `
        -Description $Description -TimeoutMilliseconds $TimeoutMilliseconds
    [IO.File]::WriteAllText((Join-Path $output $LogName),
        "exitCode=$($result.ExitCode)`nstdout:`n$($result.Stdout)`nstderr:`n$($result.Stderr)",
        [Text.UTF8Encoding]::new($false))
    $result
}

try {
    $positive = Join-Path $root 'examples/regression/1555-generic-stream-consumer-call-identity.slg'
    $negative = Join-Path $root 'examples/regression/diagnostics/generic-dynamic-array-readonly-take.slg'
    $llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
    $stdlib = Join-Path $root 'stdlib'

    $baselineIr = Invoke-Captured $baseline @('typed-ir-nodes', $positive) `
        'C468 baseline Typed IR' 'c468-baseline-ir.txt' 30000
    if ($baselineIr.ExitCode -ne 0 -or $baselineIr.Stderr.Length -ne 0 -or
        -not [regex]::IsMatch($baselineIr.Stdout, '(?m)^node 21 kind 9 .* opcode -213 operands 13/14/15 ')) {
        $failureIds.Add('C468_BASELINE_NOT_REPRODUCED')
        throw 'C468 baseline did not reproduce collection opcode -213 for nested stream take'
    }
    $completed++

    $changed = @(
        'selfhost/ir/typed.slg',
        'selfhost/ir/typed/ordinary_function_expressions.slg',
        'selfhost/ir/typed/source_lowering.slg',
        'selfhost/ir/typed/ordinary_function_finalize_phases.slg',
        'selfhost/ir/typed/source_lowering_finalize.slg'
    ) | ForEach-Object { Join-Path $root $_ }
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $changed
    if ($LASTEXITCODE -ne 0) {
        $failureIds.Add('C468_FORMAT_FAILED')
        throw 'C468 authoritative format failed'
    }
    $completed++

    $managed = Invoke-Captured 'dotnet' @('run', '--project',
        (Join-Path $root 'tests/Sollang.ExampleTests/Sollang.ExampleTests.csproj'),
        '-c', 'Release', '--no-restore', '--', '--exact',
        '1555-generic-stream-consumer-call-identity') `
        'C468 managed oracle' 'c468-managed-oracle.txt' 600000
    if ($managed.ExitCode -ne 0 -or
        -not $managed.Stdout.Contains('All 1 example tests passed.', [StringComparison]::Ordinal)) {
        $failureIds.Add('C468_MANAGED_ORACLE_FAILED')
        throw 'C468 managed stream-consumer oracle failed'
    }
    $completed++

    $candidateIr = Invoke-Captured $candidate @('typed-ir-nodes', $positive) `
        'C468 candidate sequential Typed IR' 'c468-candidate-ir.txt' 30000
    $parallelIr = Invoke-Captured $candidate @('typed-ir-nodes-parallel', $positive) `
        'C468 candidate parallel Typed IR' 'c468-candidate-parallel-ir.txt' 30000
    if ($candidateIr.ExitCode -ne 0 -or $parallelIr.ExitCode -ne 0 -or
        $candidateIr.Stderr.Length -ne 0 -or $parallelIr.Stderr.Length -ne 0 -or
        $candidateIr.Stdout -cne $parallelIr.Stdout -or
        -not [regex]::IsMatch($candidateIr.Stdout, '(?m)^node 21 kind 9 .* opcode -275 operands 13/14/15 ')) {
        $failureIds.Add('C468_TYPED_IR_DIVERGED')
        throw 'C468 candidate lacks identical sequential and parallel stream-slice Typed IR'
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
        -Compiler $candidate -Label 'c468-nested-stream-slice' `
        -Fixture '1555-generic-stream-consumer-call-identity' -Platform windows `
        -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
        -OutputDirectory (Join-Path $fixtureArtifacts 'fixture-1555') -Jobs $Jobs
    if ($LASTEXITCODE -ne 0) {
        $failureIds.Add('C468_1555_FAILED')
        throw 'C468 exact 1555 fixture failed'
    }
    $completed++

    & (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') `
        -Compiler $candidate -Label 'c468-focused-controls' -Platform windows `
        -LlvmRoot $llvmRoot -StdlibRoot $stdlib -RepositoryRoot $root `
        -OutputDirectory (Join-Path $fixtureArtifacts 'focused-controls') -Jobs $Jobs `
        -Fixture @('583-stream-state-take-skip', '585-stream-transaction-risk-scan')
    if ($LASTEXITCODE -ne 0) {
        $failureIds.Add('C468_STREAM_CONTROLS_FAILED')
        throw 'C468 exact stream controls failed'
    }
    $completed++

    $negativeIr = Invoke-Captured $candidate @('typed-ir-nodes', $negative) `
        'C468 readonly-array Typed IR' 'c468-negative-ir.txt' 30000
    $negativeBuild = Invoke-Captured $candidate @('build', $negative, '-o',
        (Join-Path $output 'readonly-take-negative.exe'), '--target', 'windows-x64',
        '--llvm', $llvmRoot, '--stdlib', $stdlib, '--jobs', '1', '-O1', '--keep-temps') `
        'C468 readonly-array checked build' 'c468-negative-build.txt' 600000
    if ($negativeIr.ExitCode -ne 0 -or $negativeIr.Stderr.Length -ne 0 -or
        -not [regex]::IsMatch($negativeIr.Stdout, '(?m)^node 3 kind 9 .* opcode -213 operands 4/5/-1 ') -or
        $negativeBuild.ExitCode -eq 0 -or
        -not ($negativeBuild.Stdout + $negativeBuild.Stderr).Contains('compiler error S051: collection mutation has no canonical writable owner', [StringComparison]::Ordinal)) {
        $failureIds.Add('C468_READONLY_ARRAY_REGRESSION')
        throw 'C468 readonly array take was not preserved as a rejected collection mutation'
    }
    $completed++

    if ((Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash -cne $baselineHash -or
        (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -cne $candidateHash) {
        $failureIds.Add('C468_COMPILER_DRIFT')
        throw 'C468 compiler binary changed during verification'
    }
    Save-Result 'passed' 0
    Write-Host "[C468] PASS $completed/$total nested stream slice and readonly array boundary."
} catch {
    if ($failureIds.Count -eq 0) { $failureIds.Add('C468_GATE_FAILED') }
    try { Save-Result 'failed' 1 } catch { }
    throw
}
