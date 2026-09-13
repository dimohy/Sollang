[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Compiler,
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = '',
    [string]$SourceRepositoryRoot = '',
    [string]$Source = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/verification-process.ps1')

function Resolve-RepositoryPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

function Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Hash-Text([string]$Text) {
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.UTF8Encoding]::new($false).GetBytes($Text)))
}

function Normalize([string]$Text) {
    return $Text.Replace("`r`n", "`n").TrimEnd()
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

function Function-Body([string]$Llvm, [string]$FunctionName) {
    $escaped = [regex]::Escape($FunctionName)
    $match = [regex]::Match(
        $Llvm,
        "(?ms)^define[^`r`n]*@$escaped\([^`r`n]*\)[^`r`n]*\{(?<body>.*?)^\}")
    if (-not $match.Success) { throw "C424 cannot isolate LLVM function @$FunctionName" }
    return $match.Groups['body'].Value
}

$Compiler = Resolve-RepositoryPath $Compiler
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($SourceRepositoryRoot)) {
    $SourceRepositoryRoot = $root
} else {
    $SourceRepositoryRoot = Resolve-RepositoryPath $SourceRepositoryRoot
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/c424-managed-nested-owner-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)

$sourcePath = if ([string]::IsNullOrWhiteSpace($Source)) {
    Join-Path $SourceRepositoryRoot 'scripts/probes/portable-memory-io/c424-nested-whole-owner.slg'
} elseif ([IO.Path]::IsPathRooted($Source)) {
    [IO.Path]::GetFullPath($Source)
} else {
    [IO.Path]::GetFullPath((Join-Path $root $Source))
}
$resultSchemaPath = Join-Path $root 'scripts/contracts/managed-c424-nested-whole-owner-result.schema.json'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAsPath = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clangPath = Join-Path $llvmRoot 'bin/clang.exe'
$inputPaths = [ordered]@{
    compiler = $Compiler
    source = $sourcePath
    resultSchema = $resultSchemaPath
    verifier = $PSCommandPath
    closureVerifier = $closurePath
    auditShim = $auditShimPath
    llvmAs = $llvmAsPath
    clang = $clangPath
}
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf) -or
        (Get-Item -LiteralPath $entry.Value).Length -eq 0) {
        throw "C424 managed required input is missing or empty: $($entry.Value)"
    }
}
$stdlibSources = @(Get-ChildItem -LiteralPath (Join-Path $SourceRepositoryRoot 'stdlib') -Recurse -File -Filter '*.slg' |
    Sort-Object { [IO.Path]::GetRelativePath($SourceRepositoryRoot, $_.FullName).Replace('\', '/') })
$stdlibManifest = ($stdlibSources | ForEach-Object {
    "$([IO.Path]::GetRelativePath($SourceRepositoryRoot, $_.FullName).Replace('\', '/'))=$(Hash $_.FullName)`n"
}) -join ''
$stdlibSourceSetSha256 = Hash-Text $stdlibManifest

$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashes[$entry.Key] = Hash $entry.Value }
$inputHashes.stdlibSourceSet = $stdlibSourceSetSha256
if ($inputHashes.compiler -cne $ExpectedCompilerSha256) {
    throw "C424 managed compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($inputHashes.compiler)"
}

[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'
$prefix = Join-Path $OutputDirectory 'C424-P1'
$llPath = "$prefix.ll"
$expected = 'nested=1,128,256'
$expectedAllocations = 1
$item = [ordered]@{
    id = 'C424-P1'
    passed = $false
    sourceSha256 = $inputHashes.source
    compileExit = -1
    stderrEmpty = $false
    targetLlvmProduced = $false
    diagnosticFree = $false
    llvmAsExit = $null
    closureExit = $null
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
    $exePath = "$prefix.exe"
    $compile = Run 'dotnet' @(
        $Compiler, 'build', $sourcePath, '-o', $exePath,
        '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps'
    ) 'C424-P1 managed compile'
    $item.compileExit = $compile.ExitCode
    $item.stderrEmpty = [string]::IsNullOrWhiteSpace($compile.Stderr)
    Write-Log "$prefix.compile.stdout.log" ($compile.Stdout + "`n")
    Write-Log "$prefix.compile.stderr.log" ($compile.Stderr + "`n")
    $item.targetLlvmProduced = Test-Path -LiteralPath $llPath -PathType Leaf
    $diagnostics = $compile.Stdout + "`n" + $compile.Stderr
    $item.diagnosticFree = $diagnostics -notmatch '(?im)\b(?:warning|note)\b|(?:semantic )?error(?:\[E\d+\])?:'
    if ($compile.ExitCode -ne 0) { throw "managed compile failed: $diagnostics" }
    if (-not $item.stderrEmpty) { throw "managed compile wrote stderr: $($compile.Stderr)" }
    if (-not $item.targetLlvmProduced) { throw 'managed compile produced no LLVM' }
    if (-not $item.diagnosticFree) { throw "managed compile emitted a warning, note, or diagnostic: $diagnostics" }

    $llvm = [IO.File]::ReadAllText($llPath)
    if ($llvm -notmatch '(?m)^target triple = "x86_64-pc-windows-msvc"$' -or
        $llvm -notmatch '(?m)^define(?: [^{\r\n]+)? i32 @sollang_start\(') {
        throw 'managed output is not a complete Windows target LLVM module'
    }

    # The complete module can contain unrelated stdlib structs with the same
    # physical shape. Select the unique child/parent/drop chain that satisfies
    # the ownership invariant instead of assuming shape uniqueness globally.
    $ownershipCandidates = @()
    $childMatches = [regex]::Matches(
        $llvm,
        '^(?<type>%sollang\.struct\.\d+)\s*=\s*type\s*\{\s*%sollang\.dynamic_int_array\s*,\s*i32\s*\}\s*$',
        [Text.RegularExpressions.RegexOptions]::Multiline)
    foreach ($child in $childMatches) {
        $candidateChildType = $child.Groups['type'].Value
        $parentMatches = [regex]::Matches(
            $llvm,
            '^(?<type>%sollang\.struct\.\d+)\s*=\s*type\s*\{\s*' + [regex]::Escape($candidateChildType) + '\s*,\s*i32\s*\}\s*$',
            [Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($parent in $parentMatches) {
            $candidateParentType = $parent.Groups['type'].Value
            $childDrops = [regex]::Matches(
                $llvm,
                '^define internal void @(?<name>sollang_drop_\d+)\(' + [regex]::Escape($candidateChildType) + '\s+%value\)[^\r\n]*\{\s*$',
                [Text.RegularExpressions.RegexOptions]::Multiline)
            $parentDrops = [regex]::Matches(
                $llvm,
                '^define internal void @(?<name>sollang_drop_\d+)\(' + [regex]::Escape($candidateParentType) + '\s+%value\)[^\r\n]*\{\s*$',
                [Text.RegularExpressions.RegexOptions]::Multiline)
            if ($childDrops.Count -ne 1 -or $parentDrops.Count -ne 1) { continue }

            $candidateChildDrop = $childDrops[0].Groups['name'].Value
            $candidateParentDrop = $parentDrops[0].Groups['name'].Value
            $parentDropBody = Function-Body $llvm $candidateParentDrop
            $childCallPattern = '(?m)^\s*call void @' + [regex]::Escape($candidateChildDrop) + '\('
            $parentCallPattern = '(?m)^\s*call void @' + [regex]::Escape($candidateParentDrop) + '\('
            $childCallsInParent = [regex]::Matches($parentDropBody, $childCallPattern).Count
            $allChildCalls = [regex]::Matches($llvm, $childCallPattern).Count
            $parentCalls = [regex]::Matches($llvm, $parentCallPattern).Count
            $independentChildCalls = $allChildCalls - $childCallsInParent
            if ($childCallsInParent -eq 1 -and $independentChildCalls -eq 0 -and $parentCalls -eq 1) {
                $ownershipCandidates += [pscustomobject]@{
                    ChildType = $candidateChildType
                    ParentType = $candidateParentType
                    ChildDrop = $candidateChildDrop
                    ParentDrop = $candidateParentDrop
                    ChildCallsInParent = $childCallsInParent
                    IndependentChildCalls = $independentChildCalls
                    ParentCalls = $parentCalls
                }
            }
        }
    }
    if ($ownershipCandidates.Count -ne 1) {
        throw "ownership structure expected one exact child/parent/drop chain, found $($ownershipCandidates.Count)"
    }
    $ownership = $ownershipCandidates[0]
    $childType = $ownership.ChildType
    $parentType = $ownership.ParentType
    $childDropName = $ownership.ChildDrop
    $parentDropName = $ownership.ParentDrop
    $childCallsInParent = $ownership.ChildCallsInParent
    $independentChildCalls = $ownership.IndependentChildCalls
    $parentCalls = $ownership.ParentCalls
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
    if ($assembled.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($assembled.Stdout + $assembled.Stderr)) {
        throw "llvm-as failed or emitted diagnostics: $($assembled.Stdout) $($assembled.Stderr)"
    }
    $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $llPath) 'C424-P1 V004'
    $item.closureExit = $closure.ExitCode
    if ($closure.ExitCode -ne 0) { throw "V004 failed: $($closure.Stdout) $($closure.Stderr)" }

    $native = Run $exePath @() 'C424-P1 native execute'
    $item.nativeExit = $native.ExitCode
    $item.nativeExact = $native.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($native.Stderr) -and
        (Normalize $native.Stdout) -ceq $expected
    if (-not $item.nativeExact) { throw "native exact mismatch: $($native.Stdout) $($native.Stderr)" }

    $auditLlPath = "$prefix.audit.ll"
    $auditText = $llvm.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('@sollang_start()', '@slg_program_main()')
    $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
    Write-Log $auditLlPath $auditText
    $auditExePath = "$prefix.audit.exe"
    $auditLink = Run $clangPath @(
        '-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$expectedAllocations",
        $auditLlPath, $auditShimPath, '-O1', '-o', $auditExePath
    ) 'C424-P1 allocation link'
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
    $item.allocationBalanced = $audit.ExitCode -eq 0 -and
        $item.allocationCount -eq $expectedAllocations -and
        $item.releaseCount -eq $expectedAllocations -and
        $item.invalidReleaseCount -eq 0
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
$stdlibManifestEnd = (@(Get-ChildItem -LiteralPath (Join-Path $SourceRepositoryRoot 'stdlib') -Recurse -File -Filter '*.slg' |
    Sort-Object { [IO.Path]::GetRelativePath($SourceRepositoryRoot, $_.FullName).Replace('\', '/') }) | ForEach-Object {
    "$([IO.Path]::GetRelativePath($SourceRepositoryRoot, $_.FullName).Replace('\', '/'))=$(Hash $_.FullName)`n"
}) -join ''
if ((Hash-Text $stdlibManifestEnd) -cne $stdlibSourceSetSha256) { $drift += 'stdlibSourceSet' }
$failureIds = @()
if (-not $item.passed) { $failureIds += 'C424-P1' }
if ($drift.Count -gt 0) { $failureIds += 'C424_INPUT_DRIFT' }
$failureIds = @($failureIds | Select-Object -Unique)
$record = [ordered]@{
    schemaVersion = 1
    mode = 'managed-c424-nested-whole-owner'
    defectId = 'C2026-09-13-424'
    runStatus = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completionStatus = if ($failureIds.Count -eq 0 -and $item.passed) { 'complete' } else { 'in-progress' }
    completed = if ($item.passed) { 1 } else { 0 }
    total = 1
    target = 'windows-x64'
    compilerSha256 = $inputHashes.compiler
    expectedCompilerSha256 = $ExpectedCompilerSha256
    inputStable = $drift.Count -eq 0
    inputDrift = $drift
    inputHashes = $inputHashes
    sourceRoot = $SourceRepositoryRoot
    stdlibSourceCount = $stdlibSources.Count
    stdlibSourceSetSha256 = $stdlibSourceSetSha256
    case = [pscustomobject]$item
    failureIds = $failureIds
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) {
    throw "C424 managed result schema validation failed: $resultPath"
}
if ($record.runStatus -ne 'passed' -or $record.completionStatus -ne 'complete') {
    throw "C424 managed focused failed $($record.completed)/1: $($failureIds -join ', '); result=$resultPath"
}
Write-Host "[C424 managed nested whole owner] PASS 1/1 compiler=$($inputHashes.compiler) result=$resultPath"
