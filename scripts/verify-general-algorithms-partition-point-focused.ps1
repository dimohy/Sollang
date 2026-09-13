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

$contractPath = Join-Path $repo 'scripts/contracts/general-algorithms-partition-point.json'
$schemaPath = Join-Path $repo 'scripts/contracts/general-algorithms-partition-point.schema.json'
$resultSchemaPath = Join-Path $repo 'scripts/contracts/general-algorithms-partition-point-result.schema.json'
$generalPath = Join-Path $repo 'scripts/contracts/general-algorithms.json'
$modulePath = Join-Path $repo 'stdlib/std/algorithm.slg'
$verifierPath = [IO.Path]::GetFullPath($PSCommandPath)
$closurePath = Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1'
$formatterPath = Join-Path $repo 'scripts/format-authoritative-slg.ps1'
$llvmRoot = Join-Path $repo '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$compiler = if ([string]::IsNullOrWhiteSpace($CompilerAssembly)) { $null } else { [IO.Path]::GetFullPath($CompilerAssembly) }
$output = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $repo ('artifacts/scratch/general-algorithms-partition-point/' + [guid]::NewGuid().ToString('N'))
} else {
    [IO.Path]::GetFullPath($OutputDirectory)
}

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize([string]$Value) { $Value.Replace("`r`n", "`n").TrimEnd() }
function Assert-ExactSet([object[]]$Actual, [string[]]$Expected, [string]$Name) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    if ($values.Count -ne $Expected.Count -or
        @($values | Sort-Object -Unique).Count -ne $Expected.Count -or
        @(Compare-Object ($Expected | Sort-Object) ($values | Sort-Object)).Count -ne 0) {
        throw "$Name must retain the exact unique authority set"
    }
}
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $repo -Description $Description -TimeoutMilliseconds 120000
}
function Inspect-PartitionPointLlvm([string]$LlvmPath) {
    $llvm = [IO.File]::ReadAllText($LlvmPath)
    # Block methods are deliberately specialized inline. Their stable source
    # identity remains on the generated bounds-failure string inside each
    # complete while region, so inspect those regions instead of inventing a
    # non-existent out-of-line symbol requirement.
    $markers = @([regex]::Matches($llvm, '(?m)^(?<name>@\.slg\.str\.suffix\.\d+)\s*=.*Algorithms\.partitionPoint\$\d+:') | ForEach-Object { $_.Groups['name'].Value })
    $whileRegions = @([regex]::Matches($llvm, '(?ms)^\s*br label %(?<condition>bb_while_condition\d+)\s*^\k<condition>:.*?^bb_while_end\d+:'))
    $bodies = @($whileRegions | Where-Object {
        $region = $_.Value
        @($markers | Where-Object { $region.Contains("ptr $_", [StringComparison]::Ordinal) }).Count -gt 0
    })
    $forbidden = 0
    $inputMutations = 0
    $fixedSliceLifetimeCount = 0
    $prematureLifetimeEndCount = 0
    foreach ($bodyMatch in $bodies) {
        $body = $bodyMatch.Value
        $forbidden += [regex]::Matches($body, '(?m)\bcall\b[^\r\n]*@(?:sollang_(?:alloc|realloc|free)|llvm\.mem(?:cpy|move)|memcpy|memmove)\(').Count
        $gepNames = @([regex]::Matches($body, '(?m)^\s*(?<name>%[A-Za-z0-9_.]+)\s*=\s*getelementptr\b') | ForEach-Object { $_.Groups['name'].Value })
        foreach ($name in $gepNames) {
            $inputMutations += [regex]::Matches($body, '(?m)^\s*store\b[^\r\n]*,\s*ptr\s+' + [regex]::Escape($name) + '(?:,|\s|$)').Count
        }
    }
    foreach ($slice in [regex]::Matches($llvm, '(?m)^\s*(?<slice>%slice_ptr\d+)\s*=\s*getelementptr[^\r\n]*ptr\s+(?<slot>%stack_slot\d+)')) {
        $fixedSliceLifetimeCount += 1
        $sliceName = $slice.Groups['slice'].Value
        $slotName = $slice.Groups['slot'].Value
        $slicePosition = $slice.Index
        $lastUsePosition = $slicePosition
        foreach ($use in [regex]::Matches($llvm, [regex]::Escape($sliceName))) {
            if ($use.Index -gt $lastUsePosition) { $lastUsePosition = $use.Index }
        }
        $startPositions = @([regex]::Matches($llvm, 'call void @llvm\.lifetime\.start\.p0\([^\r\n]*ptr\s+' + [regex]::Escape($slotName) + '\)') | Where-Object Index -lt $slicePosition | ForEach-Object Index)
        $startPosition = if ($startPositions.Count -eq 0) { -1 } else { $startPositions[-1] }
        $endPositions = @([regex]::Matches($llvm, 'call void @llvm\.lifetime\.end\.p0\([^\r\n]*ptr\s+' + [regex]::Escape($slotName) + '\)') | Where-Object Index -gt $startPosition | ForEach-Object Index)
        if ($startPosition -lt 0 -or $endPositions.Count -eq 0 -or $endPositions[0] -le $lastUsePosition) {
            $prematureLifetimeEndCount += 1
        }
    }
    [pscustomobject]@{
        BodyCount = $bodies.Count
        ForbiddenMemoryCallCount = $forbidden
        InputMutationCount = $inputMutations
        FixedSliceLifetimeCount = $fixedSliceLifetimeCount
        PrematureLifetimeEndCount = $prematureLifetimeEndCount
        LifetimeOrderingPassed = $prematureLifetimeEndCount -eq 0
    }
}

foreach ($path in @($contractPath, $schemaPath, $resultSchemaPath, $generalPath, $modulePath, $verifierPath, $closurePath, $formatterPath, $llvmAs)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "partitionPoint authority input is missing: $path" }
}
$contractJson = [IO.File]::ReadAllText($contractPath)
if (-not ($contractJson | Test-Json -SchemaFile $schemaPath)) { throw 'partitionPoint contract schema validation failed' }
$contract = $contractJson | ConvertFrom-Json
Assert-ExactSet @($contract.fixtures | ForEach-Object id) @('boundaries', 'noncopyable-readonly', 'fixed-readonly-lifetime') 'partitionPoint fixtures'

$paths = [ordered]@{
    contract = $contractPath
    contractSchema = $schemaPath
    resultSchema = $resultSchemaPath
    general = $generalPath
    module = $modulePath
    verifier = $verifierPath
    closureVerifier = $closurePath
    formatter = $formatterPath
    llvmAs = $llvmAs
}
foreach ($fixture in $contract.fixtures) {
    $paths["source:$($fixture.id)"] = Join-Path $repo $fixture.source
    $paths["expected:$($fixture.id)"] = Join-Path $repo $fixture.expected
}
foreach ($entry in $paths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) { throw "missing partitionPoint input: $($entry.Value)" }
}

$module = [IO.File]::ReadAllText($modulePath)
$methodMatch = [regex]::Match($module, '(?ms)^\s*public partitionPoint<T>: self, values: \[T\] -> Int block item: ref T -> Bool \{(?<body>.*?)^\s*# Unstable in-place partition\.')
if (-not $methodMatch.Success) { throw 'Algorithms.partitionPoint implementation is missing or not isolated from partitionInPlace' }
$method = $methodMatch.Groups['body'].Value
if ([regex]::Matches($module, '(?m)^\s*public partitionPoint<T>: self, values: \[T\] -> Int block item: ref T -> Bool \{').Count -ne 1 -or
    $method -cnotmatch 'lower! \+ \(upper! - lower!\) / 2 => middle' -or
    $method -cnotmatch 'values\[middle\] -> yield => inPrefix' -or
    [regex]::Matches($method, '-> yield').Count -ne 1 -or
    $method -match '(?m)\b(?:take|push|reserve|resize|move|box|alloc)\b|=>\s*values\[') {
    throw 'partitionPoint lost its readonly typed callback, binary-search structure, or no-mutation source contract'
}
$general = [IO.File]::ReadAllText($generalPath) | ConvertFrom-Json
if ($general.partitionPoint.status -cne $contract.status -or
    $general.partitionPoint.method -cne 'Algorithms.partitionPoint' -or
    @($general.remainingSequence.PSObject.Properties).Count -ne 0 -or
    $general.partitionInPlace.status -cne 'implemented-static-managed-pending' -or
    $general.partitionInPlace.method -cne 'Algorithms.partitionInPlace') {
    throw 'General authority must separate readonly partitionPoint from implemented partitionInPlace'
}
$discoveryResult = Join-Path $repo $contract.discovery.result
$discoveryLlvm = Join-Path $repo $contract.discovery.llvm
if (-not (Test-Path -LiteralPath $discoveryResult -PathType Leaf) -or
    -not (Test-Path -LiteralPath $discoveryLlvm -PathType Leaf) -or
    (Hash $discoveryResult) -cne $contract.discovery.resultSha256 -or
    (Hash $discoveryLlvm) -cne $contract.discovery.llvmSha256) {
    throw 'C427 discovery result or LLVM evidence is missing or drifted'
}
$managedResult = Join-Path $repo $contract.managedResult.path
if (-not (Test-Path -LiteralPath $managedResult -PathType Leaf) -or
    (Hash $managedResult) -cne $contract.managedResult.sha256) {
    throw 'partitionPoint managed result is missing or drifted'
}
$managedRecord = [IO.File]::ReadAllText($managedResult)
if (-not ($managedRecord | Test-Json -SchemaFile $resultSchemaPath)) {
    throw 'partitionPoint managed result failed its result schema'
}

$formatSources = @($modulePath) + @($contract.fixtures | ForEach-Object { Join-Path $repo $_.source })
$formatCompiler = if ($null -eq $compiler) { '' } else { $compiler }
& $formatterPath -Check -Compiler $formatCompiler -Source $formatSources
if ($LASTEXITCODE -ne 0) { throw 'partitionPoint authoritative format check failed' }

if (-not $RunManaged) {
    if ($contract.status -ceq 'managed-windows-focused-complete') {
        Write-Host '[partitionPoint] PASS static authority and immutable managed result 3/3; no managed run requested'
    } else {
        Write-Host '[partitionPoint] BLOCKED C427; static authority prepared, managed discovery 1/2 original cases, required closure 1/3 until compiler repair'
    }
    return
}
if ($null -eq $compiler -or -not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'managed compiler is required' }
$compilerHash = Hash $compiler
$expectedCompilerHash = if ([string]::IsNullOrWhiteSpace($ExpectedCompilerSha256)) {
    [string]$contract.managedGate.compilerSha256
} else {
    $ExpectedCompilerSha256.ToUpperInvariant()
}
if ($compilerHash -cne $expectedCompilerHash) {
    throw "partitionPoint compiler hash mismatch: expected $expectedCompilerHash, actual $compilerHash"
}
$paths['compiler'] = $compiler
$inputHashes = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) { $inputHashes[$entry.Key] = Hash $entry.Value }
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'

$cases = foreach ($fixture in $contract.fixtures) {
    $source = Join-Path $repo $fixture.source
    $expectedPath = Join-Path $repo $fixture.expected
    $prefix = Join-Path $output $fixture.id
    $exe = "$prefix.exe"
    $ll = "$prefix.ll"
    $bc = "$prefix.bc"
    $compile = Run 'dotnet' @($compiler, 'build', $source, '--target', 'windows-x64', '--llvm', $llvmRoot, '-o', $exe, '--keep-temps') "$($fixture.id) compile"
    $native = $null
    $assemble = $null
    $closure = $null
    $structure = $null
    $failure = $null
    if ($compile.ExitCode -eq 0 -and (Test-Path -LiteralPath $ll -PathType Leaf)) {
        $assemble = Run $llvmAs @($ll, '-o', $bc) "$($fixture.id) llvm-as"
        $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) "$($fixture.id) V004"
        $structure = Inspect-PartitionPointLlvm $ll
        $native = Run $exe @() "$($fixture.id) native"
    }
    $expected = Normalize ([IO.File]::ReadAllText($expectedPath))
    $observed = if ($null -eq $native) { $null } else { Normalize $native.Stdout }
    $passed = $true
    $compileOutput = $compile.Stdout + "`n" + $compile.Stderr
    if ($compile.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $ll -PathType Leaf) -or
        $compileOutput -match '(?im)\bwarning\b|\bnote\b|Unhandled exception|Stack trace') {
        $passed = $false; $failure = "compile failed or emitted warning/note: $($compile.Stdout) $($compile.Stderr)"
    } elseif ($assemble.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($assemble.Stdout) -or -not [string]::IsNullOrWhiteSpace($assemble.Stderr)) {
        $passed = $false; $failure = "llvm-as failed or emitted diagnostics: $($assemble.Stdout) $($assemble.Stderr)"
    } elseif ($closure.ExitCode -ne 0) {
        $passed = $false; $failure = "V004 failed: $($closure.Stdout) $($closure.Stderr)"
    } elseif ($structure.BodyCount -lt 1 -or $structure.ForbiddenMemoryCallCount -ne 0 -or $structure.InputMutationCount -ne 0 -or -not $structure.LifetimeOrderingPassed) {
        $passed = $false; $failure = "partitionPoint LLVM body contract failed: bodies=$($structure.BodyCount), forbidden=$($structure.ForbiddenMemoryCallCount), mutation=$($structure.InputMutationCount), fixedSlices=$($structure.FixedSliceLifetimeCount), prematureLifetimeEnd=$($structure.PrematureLifetimeEndCount)"
    } elseif ($native.ExitCode -ne 0 -or $observed -cne $expected -or -not [string]::IsNullOrWhiteSpace($native.Stderr)) {
        $passed = $false; $failure = "native output mismatch or diagnostic: stdout=$($native.Stdout) stderr=$($native.Stderr)"
    }
    [pscustomobject][ordered]@{
        id = [string]$fixture.id
        passed = $passed
        compileExit = $compile.ExitCode
        nativeExit = if ($null -eq $native) { $null } else { $native.ExitCode }
        stdoutMatched = if ($null -eq $native) { $null } else { $observed -ceq $expected }
        observedStdout = $observed
        llvmAsExit = if ($null -eq $assemble) { $null } else { $assemble.ExitCode }
        v004Exit = if ($null -eq $closure) { $null } else { $closure.ExitCode }
        methodBodyCount = if ($null -eq $structure) { $null } else { $structure.BodyCount }
        forbiddenMemoryCallCount = if ($null -eq $structure) { $null } else { $structure.ForbiddenMemoryCallCount }
        inputMutationCount = if ($null -eq $structure) { $null } else { $structure.InputMutationCount }
        fixedSliceLifetimeCount = if ($null -eq $structure) { $null } else { $structure.FixedSliceLifetimeCount }
        prematureLifetimeEndCount = if ($null -eq $structure) { $null } else { $structure.PrematureLifetimeEndCount }
        lifetimeOrderingPassed = if ($null -eq $structure) { $null } else { $structure.LifetimeOrderingPassed }
        sourceSha256 = Hash $source
        expectedSha256 = Hash $expectedPath
        llvmSha256 = if (Test-Path -LiteralPath $ll -PathType Leaf) { Hash $ll } else { $null }
        executableSha256 = if (Test-Path -LiteralPath $exe -PathType Leaf) { Hash $exe } else { $null }
        failure = $failure
    }
}

$failureIds = @($cases | Where-Object { -not $_.passed } | ForEach-Object id)
foreach ($entry in $paths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $failureIds += "INPUT_DRIFT:$($entry.Key)" }
}
$record = [ordered]@{
    schemaVersion = 1
    status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    compilerSha256 = $compilerHash
    inputHashes = $inputHashes
    completed = @($cases | Where-Object passed).Count
    total = 3
    cases = @($cases)
    failureIds = @($failureIds)
    acceptance = 'managed Windows focused native and LLVM evidence only; selfhost and other platforms pending'
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw "partitionPoint result schema validation failed: $resultPath" }
if ($record.status -cne 'passed') { throw "partitionPoint managed focused gate failed: $($failureIds -join ', '); result=$resultPath" }
Write-Host "[partitionPoint] PASS $($record.completed)/$($record.total) result=$resultPath"
