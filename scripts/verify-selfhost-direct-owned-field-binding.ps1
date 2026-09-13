[CmdletBinding()]
param(
    [string]$CandidateCompiler = 'artifacts/incremental-selfhost/selfhost-stage1-host-o1.exe',
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
function Get-FocusedFixtureFingerprint([string[]]$Paths) {
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash(
        [Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        foreach ($path in $Paths) {
            $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
            $hash.AppendData([Text.Encoding]::UTF8.GetBytes("$relative`0"))
            $hash.AppendData([IO.File]::ReadAllBytes($path))
        }
        return [Convert]::ToHexString($hash.GetHashAndReset())
    } finally {
        $hash.Dispose()
    }
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
    $OutputDirectory = Join-Path $root ('artifacts/scratch/c341-selfhost-direct-binding-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

$contractPath = Join-Path $root 'scripts/contracts/direct-owned-field-binding.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/direct-owned-field-binding.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/selfhost-direct-owned-field-binding-result.schema.json'
$generationSchemaPath = Join-Path $root 'scripts/contracts/selfhost-stage1-generation.schema.json'
$compilerManifestPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$runtimeManifestPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
$analysisFixturePath = Join-Path $root 'examples/regression/1740-selfhost-direct-owned-field-analysis.slg'
$analysisSourcesPath = Join-Path $root 'examples/regression/expected/1740-selfhost-direct-owned-field-analysis.sources.txt'
$analysisExpectedPath = Join-Path $root 'examples/regression/expected/1740-selfhost-direct-owned-field-analysis.stdout.txt'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAsPath = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clangPath = Join-Path $llvmRoot 'bin/clang.exe'
$seedHashPath = [IO.Path]::ChangeExtension($SeedCompiler, '.sha256')

$requiredPaths = @(
    $CandidateCompiler, $GenerationRecord, $SeedCompiler, $seedHashPath,
    $contractPath, $contractSchemaPath, $resultSchemaPath, $generationSchemaPath,
    $compilerManifestPath, $runtimeManifestPath, $analysisFixturePath, $analysisSourcesPath, $analysisExpectedPath,
    $closurePath, $auditShimPath,
    $llvmAsPath, $clangPath, $PSCommandPath
)
foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        throw "C341 selfhost required input is missing or empty: $path"
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath -ErrorAction Stop)) {
    throw 'C341 shared contract schema validation failed'
}
$contract = $contractText | ConvertFrom-Json
$caseIds = @($contract.cases.id)
if ($caseIds.Count -ne 20 -or @($caseIds | Sort-Object -Unique).Count -ne 20) {
    throw 'C341 shared contract must contain exactly twenty unique IDs'
}

$generationText = [IO.File]::ReadAllText($GenerationRecord)
if (-not ($generationText | Test-Json -SchemaFile $generationSchemaPath -ErrorAction Stop)) {
    throw 'C341 candidate generation record schema validation failed'
}
$generation = $generationText | ConvertFrom-Json
$candidateHash = Hash $CandidateCompiler
$seedHash = Hash $SeedCompiler
$recordedSeedHash = [IO.File]::ReadAllText($seedHashPath).Trim().ToUpperInvariant()
if ($recordedSeedHash -cne $seedHash) { throw 'C341 SLG seed does not match its immutable verification hash' }
if ($generation.seedMode -cne 'Slg' -or $generation.optimization -cne 'O1' -or
    $generation.hostTarget -cne 'windows' -or $generation.verificationTarget -cne 'windows' -or
    -not $generation.focusedExecutionVerified) {
    throw 'C341 candidate is not a verified Windows O1 SLG-seeded Stage1 generation'
}
if ($generation.generatedByCompilerFingerprint -cne $seedHash) {
    throw 'C341 candidate generation was not produced by the supplied immutable SLG seed'
}
if ($generation.compilerFingerprint -cne $candidateHash) {
    throw 'C341 candidate hash differs from its generation record'
}
$recordedCompilerPath = Resolve-RepositoryPath ([string]$generation.compilerPath)
if (-not [string]::Equals($recordedCompilerPath, $CandidateCompiler, [StringComparison]::OrdinalIgnoreCase)) {
    throw "C341 generation record names another compiler: $recordedCompilerPath"
}
$recordedLlvmPath = Resolve-RepositoryPath ([string]$generation.llvmPath)
if (-not (Test-Path -LiteralPath $recordedLlvmPath -PathType Leaf) -or
    (Hash $recordedLlvmPath) -cne $generation.llvmFingerprint) {
    throw 'C341 candidate generation LLVM is missing or differs from its recorded hash'
}

$compilerSources = Resolve-SourceManifest $compilerManifestPath
$runtimeSources = Resolve-SourceManifest $runtimeManifestPath
$compilerInputSources = @($compilerSources + $runtimeSources | Select-Object -Unique)
$sourceFingerprint = Get-CompilerEmissionInputFingerprint -RepositoryRoot $root -Path $compilerInputSources
if ($generation.sourceFingerprint -cne $sourceFingerprint) {
    throw "C341 candidate source fingerprint is stale: recorded=$($generation.sourceFingerprint) current=$sourceFingerprint"
}
$analysisRelativePath = [IO.Path]::GetRelativePath($root, $analysisFixturePath).Replace('\', '/')
$analysisExpectedRelativePath = [IO.Path]::GetRelativePath($root, $analysisExpectedPath).Replace('\', '/')
foreach ($property in @(
    'focusedFixtureRoots', 'focusedFixtureRootSha256', 'focusedFixtureFingerprint',
    'focusedExpectedPath', 'focusedExpectedSha256')) {
    if ($generation.PSObject.Properties.Name -notcontains $property) {
        throw "C341 candidate generation omits required 1740 binding property '$property'"
    }
}
$generationFixtureRoots = @($generation.focusedFixtureRoots)
$generationFixtureRootHashes = @($generation.focusedFixtureRootSha256)
$analysisSources = Resolve-SourceManifest $analysisSourcesPath
$analysisFingerprint = Get-FocusedFixtureFingerprint $analysisSources
if ($generationFixtureRoots.Count -ne 1 -or $generationFixtureRoots[0] -cne $analysisRelativePath -or
    $generationFixtureRootHashes.Count -ne 1 -or $generationFixtureRootHashes[0] -cne (Hash $analysisFixturePath) -or
    $generation.focusedFixtureFingerprint -cne $analysisFingerprint -or
    $generation.focusedExpectedPath -cne $analysisExpectedRelativePath -or
    $generation.focusedExpectedSha256 -cne (Hash $analysisExpectedPath)) {
    throw 'C341 candidate generation is not bound to the exact 1740 analysis source and expected output'
}

[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'
$inputPaths = [ordered]@{
    compiler = $CandidateCompiler
    seedCompiler = $SeedCompiler
    seedHash = $seedHashPath
    generationRecord = $GenerationRecord
    generationLlvm = $recordedLlvmPath
    contract = $contractPath
    contractSchema = $contractSchemaPath
    resultSchema = $resultSchemaPath
    generationSchema = $generationSchemaPath
    compilerManifest = $compilerManifestPath
    runtimeManifest = $runtimeManifestPath
    analysisFixture = $analysisFixturePath
    analysisSources = $analysisSourcesPath
    analysisExpected = $analysisExpectedPath
    verifier = $PSCommandPath
    closureVerifier = $closurePath
    auditShim = $auditShimPath
    fingerprintHelper = Join-Path $root 'scripts/compiler-emission-fingerprint.ps1'
}
foreach ($case in $contract.cases) {
    $inputPaths["source:$($case.id)"] = Resolve-RepositoryPath ([string]$case.source)
    if ($case.PSObject.Properties.Name -contains 'expected') {
        $inputPaths["expected:$($case.id)"] = Resolve-RepositoryPath ([string]$case.expected)
    }
}
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
        throw "C341 selfhost input is missing: $($entry.Value)"
    }
    $inputHashes[$entry.Key] = Hash $entry.Value
}

$expectedCodes = @{
    N1 = 'E17'; N2 = 'E17'; N2B = 'E17'; N3A = 'E34'; N3B = 'E34'; N3C = 'E34'; N4 = 'E36'
    R341N = 'E17'; R424N1 = 'E17'; R424N2 = 'E17'
}
$record = [ordered]@{
    schemaVersion = 1
    mode = 'selfhost-direct-owned-field-binding'
    defectId = 'C2026-09-06-341'
    runStatus = 'failed'
    completionStatus = 'in-progress'
    completed = 0
    total = 20
    target = 'windows'
    compilerSha256 = $candidateHash
    seedCompilerSha256 = $seedHash
    generationRecordSha256 = Hash $GenerationRecord
    sourceFingerprint = $sourceFingerprint
    inputHashes = $inputHashes
    cases = @()
    failureIds = @()
}
function Save-Result {
    $json = ($record | ConvertTo-Json -Depth 8) + "`n"
    [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
}

foreach ($case in $contract.cases) {
    $source = $inputPaths["source:$($case.id)"]
    $prefix = Join-Path $OutputDirectory ([string]$case.id)
    $llPath = "$prefix.ll"
    $item = [ordered]@{
        id = [string]$case.id
        kind = [string]$case.kind
        passed = $false
        sourceSha256 = Hash $source
        compileExit = -1
        stderrEmpty = $false
        warningNoteFree = $false
        targetLlvmProduced = $false
        diagnosticOnlyOutput = $false
        commentOnlyDiagnostic = $false
        diagnosticCount = 0
        expectedDiagnosticCode = if ($case.kind -eq 'negative') { $expectedCodes[[string]$case.id] } else { $null }
        diagnosticMatched = $null
        llvmAsExit = $null
        closureExit = $null
        nativeExit = $null
        auditExit = $null
        failure = $null
    }
    try {
        $compile = Run $CandidateCompiler @('windows', $source) "$($case.id) selfhost compile"
        $item.compileExit = $compile.ExitCode
        $item.stderrEmpty = [string]::IsNullOrWhiteSpace($compile.Stderr)
        Write-Log "$prefix.stdout.log" ($compile.Stdout + "`n")
        Write-Log "$prefix.stderr.log" ($compile.Stderr + "`n")
        $stdout = Normalize $compile.Stdout
        $hasDataLayout = $stdout -match '(?m)^target datalayout = '
        $hasTriple = $stdout -match '(?m)^target triple = "x86_64-pc-windows-msvc"$'
        $hasMain = $stdout -match '(?m)^define(?: [^{\r\n]+)? i32 @main\('
        $hasAnyLlvm = $stdout -match '(?m)^(?:target (?:datalayout|triple) = |source_filename = |%[^;\r\n]*= type|@[^;\r\n]*= |declare |define )'
        $item.targetLlvmProduced = $hasDataLayout -and $hasTriple -and $hasMain
        $nonemptyLines = @($stdout -split '\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $item.commentOnlyDiagnostic = $nonemptyLines.Count -gt 0 -and
            @($nonemptyLines | Where-Object { -not $_.TrimStart().StartsWith(';', [StringComparison]::Ordinal) }).Count -eq 0
        $item.diagnosticOnlyOutput = $nonemptyLines.Count -gt 0 -and -not $hasAnyLlvm
        $item.diagnosticCount = [regex]::Matches($stdout, '(?im)^;\s*sollang error\[E\d+\]:').Count
        $item.warningNoteFree = -not [regex]::IsMatch($stdout, '(?im)^;\s*sollang (?:warning|note)(?:\[|\s|:)')

        if ($case.kind -eq 'negative') {
            $code = [string]$item.expectedDiagnosticCode
            $codeMatched = switch ($code) {
                'E17' { $stdout -match 'error\[E17\]: use of a partially moved value' }
                'E34' { $stdout -match '(?:error\[E34\]:[^\r\n]*)?owned container values must be created directly at their binding site' }
                'E36' { $stdout -match 'error\[E36\]:[^\r\n]*must be reinitialized by the immediately following infallible statement' }
                default { $false }
            }
            $item.diagnosticMatched = [bool]$codeMatched
            if ($compile.ExitCode -ne 1) { throw "negative exited $($compile.ExitCode), expected source-error exit 1" }
            if (-not $item.stderrEmpty) { throw "negative wrote stderr: $($compile.Stderr)" }
            if ($hasAnyLlvm -or $item.targetLlvmProduced) { throw 'negative emitted target LLVM instead of stopping in semantics' }
            if (-not $item.diagnosticOnlyOutput) { throw 'negative produced neither an isolated diagnostic nor a valid fail-closed result' }
            if (-not $item.commentOnlyDiagnostic) { throw 'negative output contains a non-diagnostic data line' }
            if ($item.diagnosticCount -ne 1) { throw "negative produced $($item.diagnosticCount) diagnostics instead of exactly one" }
            if (-not $item.warningNoteFree) { throw 'negative produced a warning or note beside the expected error' }
            if (-not $item.diagnosticMatched) { throw "negative $code diagnostic mismatch: $stdout" }
            $item.passed = $true
        } else {
            if ($compile.ExitCode -ne 0) { throw "positive compile failed: $stdout $($compile.Stderr)" }
            if (-not $item.stderrEmpty) { throw "positive wrote stderr: $($compile.Stderr)" }
            if (-not $item.targetLlvmProduced) { throw 'positive output is not a complete Windows target LLVM module' }
            if ($stdout -match '(?im)\b(?:warning|note)\b|(?:semantic )?error(?:\[E\d+\])?:') {
                throw 'positive LLVM contains a warning, note, or compiler diagnostic'
            }
            $item.warningNoteFree = $true
            Write-Log $llPath ($compile.Stdout + "`n")
            $assembled = Run $llvmAsPath @($llPath, '-o', "$prefix.bc") "$($case.id) llvm-as"
            $item.llvmAsExit = $assembled.ExitCode
            if ($assembled.ExitCode -ne 0) { throw "llvm-as failed: $($assembled.Stdout) $($assembled.Stderr)" }
            $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $llPath) "$($case.id) V004"
            $item.closureExit = $closure.ExitCode
            if ($closure.ExitCode -ne 0) { throw "V004 failed: $($closure.Stdout) $($closure.Stderr)" }
            $expected = if ($case.PSObject.Properties.Name -contains 'expected') {
                Normalize ([IO.File]::ReadAllText($inputPaths["expected:$($case.id)"]))
            } else {
                Normalize ([string]$case.expectedText)
            }
            $exePath = "$prefix.exe"
            $linked = Run $clangPath @('-Wno-override-module', $llPath, '-O1', '-o', $exePath) "$($case.id) native link"
            if ($linked.ExitCode -ne 0) { throw "native link failed: $($linked.Stdout) $($linked.Stderr)" }
            $native = Run $exePath @() "$($case.id) native execute"
            $item.nativeExit = $native.ExitCode
            if ($native.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($native.Stderr)) {
                throw "native failed: $($native.Stdout) $($native.Stderr)"
            }
            if ((Normalize $native.Stdout) -cne $expected) { throw "native exact mismatch: $($native.Stdout)" }
            if ($case.PSObject.Properties.Name -contains 'auditAllocations') {
                $auditLlPath = "$prefix.audit.ll"
                $auditText = [IO.File]::ReadAllText($llPath)
                $auditText = $auditText.Replace('@malloc', '@audit_malloc').Replace('@realloc', '@audit_realloc').Replace('@free', '@audit_free').Replace('@main(', '@slg_program_main(')
                Write-Log $auditLlPath $auditText
                $auditExePath = "$prefix.audit.exe"
                $auditLink = Run $clangPath @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$($case.auditAllocations)", $auditLlPath, $auditShimPath, '-O1', '-o', $auditExePath) "$($case.id) allocation link"
                if ($auditLink.ExitCode -ne 0) { throw "allocation link failed: $($auditLink.Stdout) $($auditLink.Stderr)" }
                $audit = Run $auditExePath @() "$($case.id) allocation execute"
                $item.auditExit = $audit.ExitCode
                $expectedAudit = "$expected`nallocations=$($case.auditAllocations),releases=$($case.auditAllocations)"
                if ($audit.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($audit.Stderr) -or
                    (Normalize $audit.Stdout) -cne $expectedAudit) {
                    throw "allocation audit mismatch: $($audit.Stdout) $($audit.Stderr)"
                }
            }
            $item.passed = $true
        }
    } catch {
        $item.failure = $_.Exception.Message
    }
    $record.cases += [pscustomobject]$item
    if ($item.passed) { $record.completed++ } else { $record.failureIds += $item.id }
    Save-Result
    $caseStatus = if ($item.passed) { 'passed' } else { 'failed' }
    Write-Host "[c341 $($record.completed)/20] $($item.id) $caseStatus"
}

$drift = @()
foreach ($entry in $inputPaths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $drift += $entry.Key }
}
$endingSources = Resolve-SourceManifest $compilerManifestPath
$endingRuntimeSources = Resolve-SourceManifest $runtimeManifestPath
$endingFingerprint = Get-CompilerEmissionInputFingerprint `
    -RepositoryRoot $root `
    -Path @($endingSources + $endingRuntimeSources | Select-Object -Unique)
if ($endingFingerprint -cne $sourceFingerprint) { $drift += 'compilerSourceFingerprint' }
if ($drift.Count -gt 0) { $record.failureIds += 'C341_INPUT_DRIFT' }
$record.failureIds = @($record.failureIds | Select-Object -Unique)
$record.runStatus = if ($record.failureIds.Count -eq 0) { 'passed' } else { 'failed' }
$record.completionStatus = if ($record.runStatus -eq 'passed' -and $record.completed -eq 20 -and $record.cases.Count -eq 20) { 'complete' } else { 'in-progress' }
Save-Result
$resultText = [IO.File]::ReadAllText($resultPath)
if (-not ($resultText | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw "C341 selfhost result schema validation failed: $resultPath"
}
if ($record.runStatus -ne 'passed' -or $record.completionStatus -ne 'complete') {
    throw "C341 selfhost focused failed $($record.completed)/20: $($record.failureIds -join ', '); result=$resultPath"
}
Write-Host "[C341 selfhost direct owned field binding] PASS 20/20 compiler=$candidateHash result=$resultPath"
