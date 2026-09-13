[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CandidateCompiler,
    [string]$GenerationRecord = '',
    [string]$SeedCompiler = 'artifacts/incremental-selfhost/selfhost-slg-seed.exe',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/verification-process.ps1')
. (Join-Path $root 'scripts/compiler-emission-fingerprint.ps1')

function Resolve-RepositoryPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

function Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Normalize([string]$Text) {
    return $Text.Replace("`r`n", "`n").TrimEnd()
}

function Resolve-SourceManifest([string]$Path) {
    return @(Get-Content -LiteralPath $Path |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $root $_.Trim())).Path })
}

function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    return Invoke-VerificationProcessCapture `
        -FilePath $File `
        -ArgumentList $Arguments `
        -WorkingDirectory $root `
        -Description $Description `
        -TimeoutMilliseconds 120000
}

function Write-Log([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

$CandidateCompiler = Resolve-RepositoryPath $CandidateCompiler
$SeedCompiler = Resolve-RepositoryPath $SeedCompiler
if ([string]::IsNullOrWhiteSpace($GenerationRecord)) {
    $GenerationRecord = [IO.Path]::ChangeExtension($CandidateCompiler, '.generation.json')
} else {
    $GenerationRecord = Resolve-RepositoryPath $GenerationRecord
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/selfhost-fixed-owner-parity-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

$resultSchemaPath = Join-Path $root 'scripts/contracts/selfhost-fixed-owner-parity-result.schema.json'
$generationSchemaPath = Join-Path $root 'scripts/contracts/selfhost-stage1-generation.schema.json'
$compilerManifestPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$runtimeManifestPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$fingerprintHelperPath = Join-Path $root 'scripts/compiler-emission-fingerprint.ps1'
$llvmAsPath = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clangPath = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$seedHashPath = [IO.Path]::ChangeExtension($SeedCompiler, '.sha256')
$cases = @(
    [pscustomobject]@{
        id = 'PROJECTED_FACTORY_TEMPORARY'
        source = Join-Path $root 'scripts/probes/fixed-owner-parity/projected-factory-temporary.slg'
        expected = '7'
        allocations = 0
        promotedBackingDrops = 0
    },
    [pscustomobject]@{
        id = 'INLINE_NAMED_FIXED_COPY'
        source = Join-Path $root 'scripts/probes/fixed-owner-parity/inline-named-fixed-copy.slg'
        expected = '9'
        allocations = 1
        promotedBackingDrops = 1
    }
)

$inputPaths = [ordered]@{
    compiler = $CandidateCompiler
    seedCompiler = $SeedCompiler
    seedHash = $seedHashPath
    generationRecord = $GenerationRecord
    resultSchema = $resultSchemaPath
    generationSchema = $generationSchemaPath
    compilerManifest = $compilerManifestPath
    runtimeManifest = $runtimeManifestPath
    verifier = $PSCommandPath
    closureVerifier = $closurePath
    auditShim = $auditShimPath
    fingerprintHelper = $fingerprintHelperPath
    llvmAs = $llvmAsPath
    clang = $clangPath
}
foreach ($case in $cases) { $inputPaths["source:$($case.id)"] = $case.source }
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf) -or
        (Get-Item -LiteralPath $entry.Value).Length -eq 0) {
        throw "fixed-owner parity required input is missing or empty: $($entry.Value)"
    }
}

$generationText = [IO.File]::ReadAllText($GenerationRecord)
if (-not ($generationText | Test-Json -SchemaFile $generationSchemaPath -ErrorAction Stop)) {
    throw 'fixed-owner parity candidate generation record schema validation failed'
}
$generation = $generationText | ConvertFrom-Json
$candidateHash = Hash $CandidateCompiler
$seedHash = Hash $SeedCompiler
$recordedSeedHash = [IO.File]::ReadAllText($seedHashPath).Trim().ToUpperInvariant()
if ($recordedSeedHash -cne $seedHash) { throw 'fixed-owner parity SLG seed hash mismatch' }
if ($generation.seedMode -cne 'Slg' -or $generation.optimization -cne 'O1' -or
    $generation.hostTarget -cne 'windows' -or $generation.verificationTarget -cne 'windows' -or
    -not $generation.focusedExecutionVerified) {
    throw 'fixed-owner parity candidate is not a verified Windows O1 SLG-seeded Stage1 generation'
}
if ($generation.generatedByCompilerFingerprint -cne $seedHash -or
    $generation.compilerFingerprint -cne $candidateHash) {
    throw 'fixed-owner parity candidate provenance does not match the supplied seed and compiler'
}
$recordedCompilerPath = Resolve-RepositoryPath ([string]$generation.compilerPath)
if (-not [string]::Equals($recordedCompilerPath, $CandidateCompiler, [StringComparison]::OrdinalIgnoreCase)) {
    throw "fixed-owner parity generation record names another compiler: $recordedCompilerPath"
}
$recordedLlvmPath = Resolve-RepositoryPath ([string]$generation.llvmPath)
if (-not (Test-Path -LiteralPath $recordedLlvmPath -PathType Leaf) -or
    (Hash $recordedLlvmPath) -cne $generation.llvmFingerprint) {
    throw 'fixed-owner parity generation LLVM is missing or differs from its recorded hash'
}

$compilerSources = Resolve-SourceManifest $compilerManifestPath
$runtimeSources = Resolve-SourceManifest $runtimeManifestPath
$compilerInputSources = @($compilerSources + $runtimeSources | Select-Object -Unique)
$sourceFingerprint = Get-CompilerEmissionInputFingerprint -RepositoryRoot $root -Path $compilerInputSources
if ($generation.sourceFingerprint -cne $sourceFingerprint) {
    throw "fixed-owner parity candidate source fingerprint is stale: recorded=$($generation.sourceFingerprint) current=$sourceFingerprint"
}
$inputPaths.generationLlvm = $recordedLlvmPath
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashes[$entry.Key] = Hash $entry.Value }

[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'
$results = @()
foreach ($case in $cases) {
    $prefix = Join-Path $OutputDirectory $case.id
    $llPath = "$prefix.ll"
    $item = [ordered]@{
        id = $case.id
        passed = $false
        sourceSha256 = Hash $case.source
        expectedStdout = $case.expected
        expectedAllocationCount = $case.allocations
        expectedPromotedBackingDropCalls = $case.promotedBackingDrops
        compileExit = -1
        stderrEmpty = $false
        targetLlvmProduced = $false
        diagnosticFree = $false
        promotedBackingDropCalls = $null
        llvmAsExit = $null
        closureExit = $null
        nativeLinkExit = $null
        nativeExit = $null
        nativeExact = $false
        auditLinkExit = $null
        auditExit = $null
        allocationCount = $null
        releaseCount = $null
        invalidReleaseCount = $null
        allocationBalanced = $false
        failure = $null
    }
    try {
        $compile = Run $CandidateCompiler @('windows', $case.source) "$($case.id) selfhost compile"
        $item.compileExit = $compile.ExitCode
        $item.stderrEmpty = [string]::IsNullOrWhiteSpace($compile.Stderr)
        Write-Log "$prefix.stdout.log" ($compile.Stdout + "`n")
        Write-Log "$prefix.stderr.log" ($compile.Stderr + "`n")
        $llvm = Normalize $compile.Stdout
        $item.targetLlvmProduced = $llvm -match '(?m)^target datalayout = ' -and
            $llvm -match '(?m)^target triple = "x86_64-pc-windows-msvc"$' -and
            $llvm -match '(?m)^define(?: [^{\r\n]+)? i32 @main\('
        $item.diagnosticFree = $llvm -notmatch '(?im)\b(?:warning|note)\b|(?:semantic )?error(?:\[E\d+\])?:'
        if ($compile.ExitCode -ne 0) { throw "selfhost compile failed: $llvm $($compile.Stderr)" }
        if (-not $item.stderrEmpty) { throw "selfhost compile wrote stderr: $($compile.Stderr)" }
        if (-not $item.targetLlvmProduced) { throw 'selfhost output is not a complete Windows target LLVM module' }
        if (-not $item.diagnosticFree) { throw 'selfhost LLVM contains a warning, note, or compiler diagnostic' }
        Write-Log $llPath ($compile.Stdout + "`n")
        $item.promotedBackingDropCalls = [regex]::Matches($llvm, '(?m)^\s*call void @free\(ptr %fixedbacking\d+_\d+\)').Count
        if ($item.promotedBackingDropCalls -ne $case.promotedBackingDrops) {
            throw "promoted backing cleanup mismatch: expected=$($case.promotedBackingDrops) actual=$($item.promotedBackingDropCalls)"
        }

        $assembled = Run $llvmAsPath @($llPath, '-o', "$prefix.bc") "$($case.id) llvm-as"
        $item.llvmAsExit = $assembled.ExitCode
        if ($assembled.ExitCode -ne 0) { throw "llvm-as failed: $($assembled.Stdout) $($assembled.Stderr)" }
        $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $llPath) "$($case.id) V004"
        $item.closureExit = $closure.ExitCode
        if ($closure.ExitCode -ne 0) { throw "V004 failed: $($closure.Stdout) $($closure.Stderr)" }

        $exePath = "$prefix.exe"
        $linked = Run $clangPath @('-Wno-override-module', $llPath, '-O1', '-o', $exePath) "$($case.id) native link"
        $item.nativeLinkExit = $linked.ExitCode
        if ($linked.ExitCode -ne 0) { throw "native link failed: $($linked.Stdout) $($linked.Stderr)" }
        $native = Run $exePath @() "$($case.id) native execute"
        $item.nativeExit = $native.ExitCode
        $item.nativeExact = $native.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($native.Stderr) -and
            (Normalize $native.Stdout) -ceq $case.expected
        if (-not $item.nativeExact) { throw "native exact mismatch: $($native.Stdout) $($native.Stderr)" }

        $auditLlPath = "$prefix.audit.ll"
        $auditText = [IO.File]::ReadAllText($llPath)
        $auditText = $auditText.Replace('@malloc', '@audit_malloc').Replace('@realloc', '@audit_realloc').Replace('@free', '@audit_free').Replace('@main(', '@slg_program_main(')
        Write-Log $auditLlPath $auditText
        $auditExePath = "$prefix.audit.exe"
        $auditLink = Run $clangPath @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$($case.allocations)", $auditLlPath, $auditShimPath, '-O1', '-o', $auditExePath) "$($case.id) allocation link"
        $item.auditLinkExit = $auditLink.ExitCode
        if ($auditLink.ExitCode -ne 0) { throw "allocation link failed: $($auditLink.Stdout) $($auditLink.Stderr)" }
        $audit = Run $auditExePath @() "$($case.id) allocation execute"
        $item.auditExit = $audit.ExitCode
        $auditOutput = Normalize $audit.Stdout
        $auditMatch = [regex]::Match($auditOutput, '(?m)^allocations=(?<allocations>\d+),releases=(?<releases>\d+)$')
        if ($auditMatch.Success) {
            $item.allocationCount = [int]$auditMatch.Groups['allocations'].Value
            $item.releaseCount = [int]$auditMatch.Groups['releases'].Value
        }
        $item.invalidReleaseCount = [regex]::Matches($audit.Stderr, 'invalid (?:release|realloc):').Count
        $item.allocationBalanced = $audit.ExitCode -eq 0 -and
            $item.allocationCount -eq $case.allocations -and
            $item.releaseCount -eq $case.allocations -and
            $item.invalidReleaseCount -eq 0
        $expectedAudit = "$($case.expected)`nallocations=$($case.allocations),releases=$($case.allocations)"
        if (-not $item.allocationBalanced -or -not [string]::IsNullOrWhiteSpace($audit.Stderr) -or
            $auditOutput -cne $expectedAudit) {
            throw "allocation audit mismatch: $($audit.Stdout) $($audit.Stderr)"
        }
        $item.passed = $true
    } catch {
        $item.failure = $_.Exception.Message
    }
    $results += [pscustomobject]$item
}

$drift = @()
foreach ($entry in $inputPaths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $drift += $entry.Key }
}
$endingSources = Resolve-SourceManifest $compilerManifestPath
$endingRuntimeSources = Resolve-SourceManifest $runtimeManifestPath
$endingFingerprint = Get-CompilerEmissionInputFingerprint -RepositoryRoot $root -Path @($endingSources + $endingRuntimeSources | Select-Object -Unique)
if ($endingFingerprint -cne $sourceFingerprint) { $drift += 'compilerSourceFingerprint' }
$completed = @($results | Where-Object passed).Count
$failureIds = @($results | Where-Object { -not $_.passed } | ForEach-Object id)
if ($drift.Count -gt 0) { $failureIds += 'FIXED_OWNER_PARITY_INPUT_DRIFT' }
$failureIds = @($failureIds | Select-Object -Unique)
$record = [ordered]@{
    schemaVersion = 1
    mode = 'selfhost-fixed-owner-parity'
    defectIds = @('C2026-09-06-328', 'C2026-09-06-334', 'C2026-09-06-335')
    runStatus = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completionStatus = if ($failureIds.Count -eq 0 -and $completed -eq 2) { 'complete' } else { 'in-progress' }
    completed = $completed
    total = 2
    target = 'windows'
    compilerSha256 = $candidateHash
    seedCompilerSha256 = $seedHash
    generationRecordSha256 = Hash $GenerationRecord
    sourceFingerprint = $sourceFingerprint
    inputHashes = $inputHashes
    cases = $results
    failureIds = $failureIds
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw "fixed-owner parity result schema validation failed: $resultPath"
}
if ($record.runStatus -ne 'passed' -or $record.completionStatus -ne 'complete') {
    throw "fixed-owner parity failed $completed/2: $($failureIds -join ', '); result=$resultPath"
}
Write-Host "[selfhost fixed-owner parity] PASS 2/2 compiler=$candidateHash result=$resultPath"
