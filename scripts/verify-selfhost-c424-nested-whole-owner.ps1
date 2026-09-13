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

function Match-One([string]$Text, [string]$Pattern, [string]$Description) {
    $matches = [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    if ($matches.Count -ne 1) {
        throw "C424 expected exactly one $Description, found $($matches.Count)"
    }
    return $matches[0]
}

function Function-Body([string]$Llvm, [string]$FunctionName) {
    $escaped = [regex]::Escape($FunctionName)
    $match = [regex]::Match(
        $Llvm,
        "(?ms)^define[^`r`n]*@$escaped\([^`r`n]*\)\s*\{(?<body>.*?)^\}")
    if (-not $match.Success) { throw "C424 cannot isolate LLVM function @$FunctionName" }
    return $match.Groups['body'].Value
}

$CandidateCompiler = Resolve-RepositoryPath $CandidateCompiler
$SeedCompiler = Resolve-RepositoryPath $SeedCompiler
if ([string]::IsNullOrWhiteSpace($GenerationRecord)) {
    $GenerationRecord = [IO.Path]::ChangeExtension($CandidateCompiler, '.generation.json')
} else {
    $GenerationRecord = Resolve-RepositoryPath $GenerationRecord
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/c424-selfhost-nested-owner-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

$sourcePath = Join-Path $root 'scripts/probes/portable-memory-io/c424-nested-whole-owner.slg'
$resultSchemaPath = Join-Path $root 'scripts/contracts/selfhost-c424-nested-whole-owner-result.schema.json'
$generationSchemaPath = Join-Path $root 'scripts/contracts/selfhost-stage1-generation.schema.json'
$compilerManifestPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt'
$runtimeManifestPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$fingerprintHelperPath = Join-Path $root 'scripts/compiler-emission-fingerprint.ps1'
$llvmAsPath = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clangPath = Join-Path $root '.tools/llvm-22.1.8/bin/clang.exe'
$seedHashPath = [IO.Path]::ChangeExtension($SeedCompiler, '.sha256')

$inputPaths = [ordered]@{
    compiler = $CandidateCompiler
    seedCompiler = $SeedCompiler
    seedHash = $seedHashPath
    generationRecord = $GenerationRecord
    source = $sourcePath
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
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf) -or
        (Get-Item -LiteralPath $entry.Value).Length -eq 0) {
        throw "C424 selfhost required input is missing or empty: $($entry.Value)"
    }
}

$generationText = [IO.File]::ReadAllText($GenerationRecord)
if (-not ($generationText | Test-Json -SchemaFile $generationSchemaPath -ErrorAction Stop)) {
    throw 'C424 candidate generation record schema validation failed'
}
$generation = $generationText | ConvertFrom-Json
$candidateHash = Hash $CandidateCompiler
$seedHash = Hash $SeedCompiler
$recordedSeedHash = [IO.File]::ReadAllText($seedHashPath).Trim().ToUpperInvariant()
if ($recordedSeedHash -cne $seedHash) { throw 'C424 SLG seed does not match its immutable verification hash' }
if ($generation.seedMode -cne 'Slg' -or $generation.optimization -cne 'O1' -or
    $generation.hostTarget -cne 'windows' -or $generation.verificationTarget -cne 'windows' -or
    -not $generation.focusedExecutionVerified) {
    throw 'C424 candidate is not a verified Windows O1 SLG-seeded Stage1 generation'
}
if ($generation.generatedByCompilerFingerprint -cne $seedHash) {
    throw 'C424 candidate was not generated by the supplied immutable SLG seed'
}
if ($generation.compilerFingerprint -cne $candidateHash) {
    throw 'C424 candidate hash differs from its generation record'
}
$recordedCompilerPath = Resolve-RepositoryPath ([string]$generation.compilerPath)
if (-not [string]::Equals($recordedCompilerPath, $CandidateCompiler, [StringComparison]::OrdinalIgnoreCase)) {
    throw "C424 generation record names another compiler: $recordedCompilerPath"
}
$recordedLlvmPath = Resolve-RepositoryPath ([string]$generation.llvmPath)
if (-not (Test-Path -LiteralPath $recordedLlvmPath -PathType Leaf) -or
    (Hash $recordedLlvmPath) -cne $generation.llvmFingerprint) {
    throw 'C424 candidate generation LLVM is missing or differs from its recorded hash'
}

$compilerSources = Resolve-SourceManifest $compilerManifestPath
$runtimeSources = Resolve-SourceManifest $runtimeManifestPath
$compilerInputSources = @($compilerSources + $runtimeSources | Select-Object -Unique)
$sourceFingerprint = Get-CompilerEmissionInputFingerprint -RepositoryRoot $root -Path $compilerInputSources
if ($generation.sourceFingerprint -cne $sourceFingerprint) {
    throw "C424 candidate source fingerprint is stale: recorded=$($generation.sourceFingerprint) current=$sourceFingerprint"
}

$inputPaths.generationLlvm = $recordedLlvmPath
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashes[$entry.Key] = Hash $entry.Value }

[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'
$prefix = Join-Path $OutputDirectory 'C424-P1'
$llPath = "$prefix.ll"
$expected = 'nested=1,128,256'
$expectedAllocations = 1
$item = [ordered]@{
    id = 'C424-P1'
    passed = $false
    sourceSha256 = Hash $sourcePath
    compileExit = -1
    stderrEmpty = $false
    targetLlvmProduced = $false
    diagnosticFree = $false
    llvmAsExit = $null
    closureExit = $null
    nativeLinkExit = $null
    nativeExit = $null
    expectedStdout = $expected
    nativeExact = $false
    auditLinkExit = $null
    auditExit = $null
    expectedAllocationCount = $expectedAllocations
    allocationCount = $null
    releaseCount = $null
    invalidReleaseCount = $null
    allocationBalanced = $false
    childType = $null
    parentType = $null
    childDropFunction = $null
    parentDropFunction = $null
    childDropCallsInParent = $null
    independentChildDropCalls = $null
    parentDropCalls = $null
    structureMatched = $false
    failure = $null
}

try {
    $compile = Run $CandidateCompiler @('windows', $sourcePath) 'C424-P1 selfhost compile'
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

    $child = Match-One $llvm '^(?<type>%sollang\.struct\.m\d+_s\d+)\s*=\s*type\s*\{\s*%sollang\.array\.i32\s*,\s*i64\s*\}\s*$' 'CipherKey LLVM type'
    $childType = $child.Groups['type'].Value
    $parentPattern = '^(?<type>%sollang\.struct\.m\d+_s\d+)\s*=\s*type\s*\{\s*' + [regex]::Escape($childType) + '\s*,\s*i64\s*\}\s*$'
    $parent = Match-One $llvm $parentPattern 'GcmKey LLVM type'
    $parentType = $parent.Groups['type'].Value
    $childDrop = Match-One $llvm ('^define internal void @(?<name>sollang_drop_t\d+)\(' + [regex]::Escape($childType) + '\s+%value\)\s*\{$') 'CipherKey drop helper'
    $parentDrop = Match-One $llvm ('^define internal void @(?<name>sollang_drop_t\d+)\(' + [regex]::Escape($parentType) + '\s+%value\)\s*\{$') 'GcmKey drop helper'
    $childDropName = $childDrop.Groups['name'].Value
    $parentDropName = $parentDrop.Groups['name'].Value
    $parentDropBody = Function-Body $llvm $parentDropName
    $childCallPattern = '(?m)^\s*call void @' + [regex]::Escape($childDropName) + '\('
    $parentCallPattern = '(?m)^\s*call void @' + [regex]::Escape($parentDropName) + '\('
    $childCallsInParent = [regex]::Matches($parentDropBody, $childCallPattern).Count
    $allChildCalls = [regex]::Matches($llvm, $childCallPattern).Count
    $parentCalls = [regex]::Matches($llvm, $parentCallPattern).Count
    $independentChildCalls = $allChildCalls - $childCallsInParent
    $item.childType = $childType
    $item.parentType = $parentType
    $item.childDropFunction = $childDropName
    $item.parentDropFunction = $parentDropName
    $item.childDropCallsInParent = $childCallsInParent
    $item.independentChildDropCalls = $independentChildCalls
    $item.parentDropCalls = $parentCalls
    $item.structureMatched = $childCallsInParent -eq 1 -and $independentChildCalls -eq 0 -and $parentCalls -eq 1
    if (-not $item.structureMatched) {
        throw "ownership structure mismatch: childInParent=$childCallsInParent independentChild=$independentChildCalls parent=$parentCalls"
    }

    $assembled = Run $llvmAsPath @($llPath, '-o', "$prefix.bc") 'C424-P1 llvm-as'
    $item.llvmAsExit = $assembled.ExitCode
    if ($assembled.ExitCode -ne 0) { throw "llvm-as failed: $($assembled.Stdout) $($assembled.Stderr)" }
    $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $llPath) 'C424-P1 V004'
    $item.closureExit = $closure.ExitCode
    if ($closure.ExitCode -ne 0) { throw "V004 failed: $($closure.Stdout) $($closure.Stderr)" }

    $exePath = "$prefix.exe"
    $linked = Run $clangPath @('-Wno-override-module', $llPath, '-O1', '-o', $exePath) 'C424-P1 native link'
    $item.nativeLinkExit = $linked.ExitCode
    if ($linked.ExitCode -ne 0) { throw "native link failed: $($linked.Stdout) $($linked.Stderr)" }
    $native = Run $exePath @() 'C424-P1 native execute'
    $item.nativeExit = $native.ExitCode
    $item.nativeExact = $native.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($native.Stderr) -and
        (Normalize $native.Stdout) -ceq $expected
    if (-not $item.nativeExact) { throw "native exact mismatch: $($native.Stdout) $($native.Stderr)" }

    $auditLlPath = "$prefix.audit.ll"
    $auditText = [IO.File]::ReadAllText($llPath)
    $auditText = $auditText.Replace('@malloc', '@audit_malloc').Replace('@realloc', '@audit_realloc').Replace('@free', '@audit_free').Replace('@main(', '@slg_program_main(')
    Write-Log $auditLlPath $auditText
    $auditExePath = "$prefix.audit.exe"
    $auditLink = Run $clangPath @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$expectedAllocations", $auditLlPath, $auditShimPath, '-O1', '-o', $auditExePath) 'C424-P1 allocation link'
    $item.auditLinkExit = $auditLink.ExitCode
    if ($auditLink.ExitCode -ne 0) { throw "allocation link failed: $($auditLink.Stdout) $($auditLink.Stderr)" }
    $audit = Run $auditExePath @() 'C424-P1 allocation execute'
    $item.auditExit = $audit.ExitCode
    $auditOutput = Normalize $audit.Stdout
    $auditMatch = [regex]::Match($auditOutput, '(?m)^allocations=(?<allocations>\d+),releases=(?<releases>\d+)$')
    if ($auditMatch.Success) {
        $item.allocationCount = [int]$auditMatch.Groups['allocations'].Value
        $item.releaseCount = [int]$auditMatch.Groups['releases'].Value
    }
    $item.invalidReleaseCount = [regex]::Matches($audit.Stderr, 'invalid (?:release|realloc):').Count
    $item.allocationBalanced = $audit.ExitCode -eq 0 -and $item.allocationCount -eq $expectedAllocations -and
        $item.releaseCount -eq $expectedAllocations -and $item.invalidReleaseCount -eq 0
    if (-not $item.allocationBalanced -or -not [string]::IsNullOrWhiteSpace($audit.Stderr) -or
        $auditOutput -cne "$expected`nallocations=$expectedAllocations,releases=$expectedAllocations") {
        throw "allocation audit mismatch: $($audit.Stdout) $($audit.Stderr)"
    }
    $item.passed = $true
} catch {
    $item.failure = $_.Exception.Message
}

$drift = @()
foreach ($entry in $inputPaths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $drift += $entry.Key }
}
$endingSources = Resolve-SourceManifest $compilerManifestPath
$endingRuntimeSources = Resolve-SourceManifest $runtimeManifestPath
$endingFingerprint = Get-CompilerEmissionInputFingerprint -RepositoryRoot $root -Path @($endingSources + $endingRuntimeSources | Select-Object -Unique)
if ($endingFingerprint -cne $sourceFingerprint) { $drift += 'compilerSourceFingerprint' }
$failureIds = @()
if (-not $item.passed) { $failureIds += 'C424-P1' }
if ($drift.Count -gt 0) { $failureIds += 'C424_INPUT_DRIFT' }
$failureIds = @($failureIds | Select-Object -Unique)
$record = [ordered]@{
    schemaVersion = 1
    mode = 'selfhost-c424-nested-whole-owner'
    defectId = 'C2026-09-13-424'
    runStatus = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completionStatus = if ($failureIds.Count -eq 0 -and $item.passed) { 'complete' } else { 'in-progress' }
    completed = if ($item.passed) { 1 } else { 0 }
    total = 1
    target = 'windows'
    compilerSha256 = $candidateHash
    seedCompilerSha256 = $seedHash
    generationRecordSha256 = Hash $GenerationRecord
    sourceFingerprint = $sourceFingerprint
    inputHashes = $inputHashes
    case = [pscustomobject]$item
    failureIds = $failureIds
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw "C424 selfhost result schema validation failed: $resultPath"
}
if ($record.runStatus -ne 'passed' -or $record.completionStatus -ne 'complete') {
    throw "C424 selfhost focused failed $($record.completed)/1: $($failureIds -join ', '); result=$resultPath"
}
Write-Host "[C424 selfhost nested whole owner] PASS 1/1 compiler=$candidateHash result=$resultPath"
