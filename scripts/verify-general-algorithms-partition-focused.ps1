[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CompilerAssembly = '',
    [string]$ExpectedCompilerSha256 = '',
    [string]$OutputDirectory = '',
    [switch]$RunManaged
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $repo 'scripts/verification-process.ps1')

$contractPath = Join-Path $repo 'scripts/contracts/general-algorithms-partition.json'
$contractSchemaPath = Join-Path $repo 'scripts/contracts/general-algorithms-partition.schema.json'
$resultSchemaPath = Join-Path $repo 'scripts/contracts/general-algorithms-partition-result.schema.json'
$modulePath = Join-Path $repo 'stdlib/std/algorithm.slg'
$formatterPath = Join-Path $repo 'scripts/format-authoritative-slg.ps1'
$closurePath = Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $repo 'tests/native-interop/indexed_owned_exchange_audit.c'
$llvmRoot = Join-Path $repo '.tools/llvm-22.1.8'
$llvmAsPath = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clangPath = Join-Path $llvmRoot 'bin/clang.exe'
$compiler = if ([string]::IsNullOrWhiteSpace($CompilerAssembly)) { $null } else { [IO.Path]::GetFullPath($CompilerAssembly) }
$output = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $repo ('artifacts/scratch/general-algorithms-partition/' + [guid]::NewGuid().ToString('N'))
} else {
    [IO.Path]::GetFullPath($OutputDirectory)
}

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize([string]$Value) { $Value.Replace("`r`n", "`n").TrimEnd() }
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $repo -Description $Description -TimeoutMilliseconds 120000
}
function Assert-ExactSet([object[]]$Actual, [string[]]$Expected, [string]$Name) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    if ($values.Count -ne $Expected.Count -or
        @($values | Sort-Object -Unique).Count -ne $Expected.Count -or
        @(Compare-Object ($Expected | Sort-Object) ($values | Sort-Object)).Count -ne 0) {
        throw "$Name must retain the exact unique authority set"
    }
}
function Inspect-PartitionLlvm([string]$LlvmPath) {
    $llvm = [IO.File]::ReadAllText($LlvmPath)
    $markers = @([regex]::Matches($llvm, '(?m)^(?<name>@\.slg\.str\.[^=]+)\s*=.*Algorithms\.partitionInPlace\$\d+:') |
        ForEach-Object { $_.Groups['name'].Value.TrimEnd() })
    $regions = @([regex]::Matches($llvm, '(?ms)^\s*br label %(?<condition>bb_while_condition\d+)\s*^\k<condition>:.*?^bb_while_end\d+:'))
    $partitionRegions = @($regions | Where-Object {
        $region = $_.Value
        @($markers | Where-Object { $region.Contains("ptr $_", [StringComparison]::Ordinal) }).Count -gt 0
    })
    $forbidden = 0
    foreach ($region in $partitionRegions) {
        $forbidden += [regex]::Matches(
            $region.Value,
            '(?im)\bcall\b[^\r\n]*@(?:sollang_(?:alloc|realloc|free|drop)|llvm\.mem(?:cpy|move)|memcpy|memmove)\(').Count
    }
    [pscustomobject]@{ BodyCount = $partitionRegions.Count; ForbiddenCallCount = $forbidden }
}
function Invoke-AllocationAudit([string]$LlvmPath, [string]$Expected, [string]$Prefix) {
    $auditLl = "$Prefix.audit.ll"
    $auditExe = "$Prefix.audit.exe"
    $llvm = [IO.File]::ReadAllText($LlvmPath)
    $llvm = $llvm.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(')
    $llvm = $llvm.Replace('call void @sollang_free(', 'call void @audit_free(')
    $llvm = $llvm.Replace('@sollang_start()', '@slg_program_main()')
    $llvm += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
    [IO.File]::WriteAllText($auditLl, $llvm, [Text.UTF8Encoding]::new($false))
    $link = Run $clangPath @('-Wno-override-module', $auditLl, $auditShimPath, '-O1', '-o', $auditExe) 'partition noncopyable audit link'
    if ($link.ExitCode -ne 0) { return [pscustomobject]@{ Passed=$false; Invalid=$null; Failure="audit link failed: $($link.Stdout) $($link.Stderr)" } }
    $run = Run $auditExe @() 'partition noncopyable audit execute'
    $actual = Normalize $run.Stdout
    $lines = @($actual -split "`n")
    $counts = [regex]::Match($lines[-1], '^allocations=(?<alloc>\d+),releases=(?<release>\d+),invalid=(?<invalid>\d+)$')
    $programOutput = Normalize (($lines | Select-Object -SkipLast 1) -join "`n")
    $passed = $run.ExitCode -eq 0 -and $counts.Success -and $programOutput -ceq $Expected -and
        [int]$counts.Groups['alloc'].Value -eq [int]$counts.Groups['release'].Value -and
        [int]$counts.Groups['invalid'].Value -eq 0
    [pscustomobject]@{
        Passed = $passed
        Invalid = if ($counts.Success) { [int]$counts.Groups['invalid'].Value } else { $null }
        Failure = if ($passed) { $null } else { "allocation audit mismatch: $actual $($run.Stderr)" }
    }
}

foreach ($path in @($contractPath, $contractSchemaPath, $resultSchemaPath, $modulePath, $formatterPath, $closurePath, $auditShimPath, $llvmAsPath, $clangPath, $PSCommandPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "partitionInPlace authority input is missing: $path" }
}
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath)) { throw 'partitionInPlace contract schema validation failed' }
$contract = $contractText | ConvertFrom-Json
Assert-ExactSet @($contract.fixtures.id) @('P-BOUNDARIES', 'P-NONCOPYABLE', 'N-CALLBACK-RESULT', 'N-WRONG-OWNER', 'N-READONLY-OWNER') 'partitionInPlace cases'

$inputPaths = [ordered]@{
    contract = $contractPath; contractSchema = $contractSchemaPath; resultSchema = $resultSchemaPath
    module = $modulePath; verifier = $PSCommandPath; formatter = $formatterPath
    closureVerifier = $closurePath; auditShim = $auditShimPath; llvmAs = $llvmAsPath; clang = $clangPath
}
foreach ($case in $contract.fixtures) {
    $inputPaths["source:$($case.id)"] = Join-Path $repo $case.source
    $inputPaths["expected:$($case.id)"] = Join-Path $repo $case.expected
}
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) { throw "partitionInPlace case input is missing: $($entry.Value)" }
}

$module = [IO.File]::ReadAllText($modulePath)
$methodMatch = [regex]::Match($module, '(?ms)^\s*public partitionInPlace<T>: self, values: mut \[T; ~\] -> Int block item: ref T -> Bool \{(?<body>.*?)^\s*\}')
if (-not $methodMatch.Success) { throw 'partitionInPlace exact typed-block signature is missing' }
$body = $methodMatch.Groups['body'].Value
if ([regex]::Matches($module, '(?m)^\s*public partitionInPlace<T>:').Count -ne 1 -or
    [regex]::Matches($body, 'values\[index!\] -> yield => selected').Count -ne 1 -or
    [regex]::Matches($body, 'values -> exchange\(boundary!, index!\)').Count -ne 1 -or
    [regex]::Matches($body, '-> yield').Count -ne 1 -or
    [regex]::Matches($body, '-> exchange\(').Count -ne 1 -or
    $body -notmatch '0 => boundary!' -or $body -notmatch '0 => index!' -or
    $body -match 'boundary!\s*(?:==|!=)\s*index!' -or
    $body -match '(?i)\b(?:Predicate|take|push|reserve|resize|box|memcpy|memmove|alloc|free|drop)\b' -or
    $body -match 'values\[[^\]]+\]\s*=>\s*(?!selected\b)') {
    throw 'partitionInPlace lost its single-scan typed-block atomic-exchange source contract'
}
foreach ($pending in @('partitionApiPlaceholder', 'trait Predicate', '.pending.slg')) {
    if ($module.Contains($pending, [StringComparison]::Ordinal) -or $contractText.Contains($pending, [StringComparison]::Ordinal)) {
        throw "partitionInPlace retained pending authority '$pending'"
    }
}
$formatSources = @($modulePath) + @($contract.fixtures | ForEach-Object { Join-Path $repo $_.source })
$formatCompiler = if ($null -eq $compiler) { '' } else { $compiler }
& $formatterPath -Check -Compiler $formatCompiler -Source $formatSources
if ($LASTEXITCODE -ne 0) { throw 'partitionInPlace authoritative formatter check failed' }
if (-not $RunManaged) {
    Write-Host '[partitionInPlace focused] PREPARED static/parser 5/5; managed 0/5 not run'
    return
}
if ($null -eq $compiler -or -not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'managed compiler is required' }
$compilerHash = Hash $compiler
if ([string]::IsNullOrWhiteSpace($ExpectedCompilerSha256) -or $ExpectedCompilerSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'ExpectedCompilerSha256 must bind the managed run to exactly 64 hexadecimal characters'
}
if ($compilerHash -cne $ExpectedCompilerSha256.ToUpperInvariant()) {
    throw "partitionInPlace compiler hash mismatch: expected $($ExpectedCompilerSha256.ToUpperInvariant()), actual $compilerHash"
}
$inputPaths.compiler = $compiler
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashes[$entry.Key] = Hash $entry.Value }
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'

$results = foreach ($case in $contract.fixtures) {
    $source = $inputPaths["source:$($case.id)"]
    $expectedPath = $inputPaths["expected:$($case.id)"]
    $expected = Normalize ([IO.File]::ReadAllText($expectedPath))
    $prefix = Join-Path $output ([string]$case.id)
    $exe = "$prefix.exe"; $ll = "$prefix.ll"
    $compile = Run 'dotnet' @($compiler, 'build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps') "$($case.id) compile"
    $diagnostics = Normalize ($compile.Stdout + "`n" + $compile.Stderr)
    $warningNoteFree = -not [regex]::IsMatch($diagnostics, '(?im)^\s*(?:sollang:\s*)?(?:warning|note)(?:\[|\s|:)')
    $llvmProduced = Test-Path -LiteralPath $ll -PathType Leaf
    $item = [ordered]@{
        id=[string]$case.id; kind=[string]$case.kind; passed=$false; sourceSha256=Hash $source; expectedSha256=Hash $expectedPath
        compileExit=$compile.ExitCode; warningNoteFree=$warningNoteFree; llvmProduced=$llvmProduced
        diagnosticCount=[regex]::Matches($diagnostics, '(?im)^\s*sollang:\s*(?:semantic\s+)?error\b').Count
        diagnosticMatched=$null; llvmAsExit=$null; closureExit=$null; nativeExit=$null; stdoutMatched=$null; observedStdout=$null
        partitionBodyCount=$null; forbiddenBodyCallCount=$null; predicateOrderMatched=$null; ownerPreserved=$null
        allocationBalanced=$null; invalidAllocationCount=$null; failure=$null
    }
    try {
        if (-not $warningNoteFree) { throw "compile produced warning or note: $diagnostics" }
        if ($case.kind -ceq 'compile-failure') {
            $item.diagnosticMatched = $diagnostics.Contains($expected, [StringComparison]::Ordinal)
            if ($compile.ExitCode -eq 0) { throw 'negative compiled successfully' }
            if ($llvmProduced) { throw 'negative produced LLVM' }
            if ($item.diagnosticCount -ne 1) { throw "negative produced $($item.diagnosticCount) diagnostics instead of exactly one" }
            if (-not $item.diagnosticMatched) { throw "negative diagnostic mismatch: $diagnostics" }
        } else {
            if ($compile.ExitCode -ne 0 -or -not $llvmProduced) { throw "positive compile failed: $diagnostics" }
            $assemble = Run $llvmAsPath @($ll, '-o', "$prefix.bc") "$($case.id) llvm-as"
            $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) "$($case.id) V004"
            $native = Run $exe @() "$($case.id) native"
            $structure = Inspect-PartitionLlvm $ll
            $observed = Normalize $native.Stdout
            $item.llvmAsExit = $assemble.ExitCode; $item.closureExit = $closure.ExitCode; $item.nativeExit = $native.ExitCode
            $item.observedStdout = $observed; $item.stdoutMatched = $observed -ceq $expected
            $item.partitionBodyCount = $structure.BodyCount; $item.forbiddenBodyCallCount = $structure.ForbiddenCallCount
            $item.predicateOrderMatched = if ($case.id -ceq 'P-BOUNDARIES') { $observed.Contains('mixed=3,6,123456,', [StringComparison]::Ordinal) } else { $observed.Contains('order=-826,', [StringComparison]::Ordinal) }
            $item.ownerPreserved = if ($case.id -ceq 'P-BOUNDARIES') {
                $observed.Contains('empty=0,0,true,true', [StringComparison]::Ordinal) -and
                    $observed.Contains('all-true=3,3,246,true,true', [StringComparison]::Ordinal) -and
                    $observed.Contains('all-false=0,3,135,true,true', [StringComparison]::Ordinal) -and
                    $observed.Contains('mixed=3,6,123456,true,true', [StringComparison]::Ordinal)
            } else {
                $observed.Contains('len=true,capacity=true', [StringComparison]::Ordinal)
            }
            if ($assemble.ExitCode -ne 0) { throw "llvm-as failed: $($assemble.Stdout) $($assemble.Stderr)" }
            if ($closure.ExitCode -ne 0) { throw "V004 failed: $($closure.Stdout) $($closure.Stderr)" }
            if ($native.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($native.Stderr) -or -not $item.stdoutMatched) { throw "native mismatch: $observed $($native.Stderr)" }
            if ($structure.BodyCount -lt 1 -or $structure.ForbiddenCallCount -ne 0) { throw "partition body structure failed: bodies=$($structure.BodyCount) forbidden=$($structure.ForbiddenCallCount)" }
            if (-not $item.predicateOrderMatched -or -not $item.ownerPreserved) { throw 'predicate order/count or owner preservation failed' }
            if ($case.kind -ceq 'native-success-audit') {
                $audit = Invoke-AllocationAudit $ll $expected $prefix
                $item.allocationBalanced = $audit.Passed; $item.invalidAllocationCount = $audit.Invalid
                if (-not $audit.Passed) { throw $audit.Failure }
            }
        }
        $item.passed = $true
    } catch { $item.failure = $_.Exception.Message }
    [pscustomobject]$item
}

$drift = @()
foreach ($entry in $inputPaths.GetEnumerator()) { if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $drift += $entry.Key } }
$failureIds = @($results | Where-Object { -not $_.passed } | ForEach-Object id)
if ($drift.Count -gt 0) { $failureIds += 'PARTITION_INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion=1; status=if($failureIds.Count -eq 0){'passed'}else{'failed'}; compilerSha256=$compilerHash; inputHashes=$inputHashes; completed=@($results|Where-Object passed).Count; total=5; cases=@($results); failureIds=@($failureIds) }
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw "partitionInPlace result schema failure: $resultPath" }
if ($record.status -ne 'passed') { throw "partitionInPlace focused failed $($record.completed)/5: $($failureIds -join ', '); result=$resultPath" }
Write-Host "[partitionInPlace focused] PASS 5/5 result=$resultPath"
