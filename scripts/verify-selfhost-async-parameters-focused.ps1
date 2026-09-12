[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CandidateCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$candidate = [IO.Path]::GetFullPath($CandidateCompiler)
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$contractPath = Join-Path $root 'scripts/contracts/selfhost-async-parameters.json'
$fixture = Join-Path $root 'scripts/contracts/fixtures/c415-async-scalar-parameters.slg'
$expectedPath = Join-Path $root 'scripts/contracts/fixtures/c415-async-scalar-parameters.stdout.txt'
$ownedFixture = Join-Path $root 'scripts/contracts/fixtures/c415-async-owned-parameter.slg'
$ownedExpectedPath = Join-Path $root 'scripts/contracts/fixtures/c415-async-owned-parameter.stdout.txt'
$standaloneFixture = Join-Path $root 'examples/regression/225-structured-async.slg'
$standaloneExpectedPath = Join-Path $root 'examples/regression/expected/225-structured-async.stdout.txt'
$standaloneSourceRoot = Join-Path $root 'scripts/contracts/fixtures/c416-standalone-root'
$functionsPath = Join-Path $root 'selfhost/llvm/text/functions.slg'
$stdlib = Join-Path $root 'stdlib'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvm 'bin/llvm-as.exe'
$output = Join-Path $root ('artifacts/scratch/selfhost-async-parameters-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'

foreach ($path in @($candidate, $managed, $contractPath, $fixture, $expectedPath, $ownedFixture, $ownedExpectedPath, $standaloneFixture, $standaloneExpectedPath, $standaloneSourceRoot, $functionsPath, $stdlib, $llvmAs)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing C415 input: $path" }
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'selfhost-affine-task-scalar-parameter-transfer'
    completed = 0
    total = 11
    candidateSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash
    checks = @()
    resultPath = $resultPath
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}
function Require-Text([string]$Source, [string]$Expected, [string]$Label) {
    if (-not $Source.Contains($Expected)) { throw "$Label is missing: $Expected" }
}

Save-Result
try {
    $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
    if ($contract.schemaVersion -ne 1 -or @($contract.fixtures).Count -ne 3 -or
        @($contract.supportSourceRoots).Count -ne 1 -or
        @($contract.invariants).Count -ne 7 -or @($contract.deferred).Count -ne 3) {
        throw 'C415 focused contract dimensions drifted'
    }
    Complete-Check 'contract-dimensions'

    $fixtureText = [IO.File]::ReadAllText($fixture).Replace("`r`n", "`n")
    foreach ($fragment in @(
        'weighted value: Int, scale: Int, offset: Int -> async Int',
        'signed value: Int, positive: Bool -> async Int',
        'weightedTask -> await => weightedValue',
        'signedTask -> await => signedValue'
    )) {
        Require-Text $fixtureText $fragment 'natural scalar-parameter fixture'
    }
    Complete-Check 'natural-slg-parameter-fixture'

    $functions = [IO.File]::ReadAllText($functionsPath).Replace("`r`n", "`n")
    foreach ($fragment in @(
        'alignedAsyncContextOffset offset: Int, alignment: Int',
        'asyncParameterContextOffset functionIndex: Int, targetParameterIndex: Int',
        'asyncContextStorageSize functionIndex: Int'
    )) {
        Require-Text $functions $fragment 'aligned context layout authority'
    }
    Complete-Check 'aligned-context-layout-authority'

    foreach ($fragment in @(
        '%async_arg_address = getelementptr i8, ptr %async_context',
        '%async_arg = load ',
        ' %arg, ptr %async_arg_address',
        '_async_body(' 
    )) {
        Require-Text $functions $fragment 'wrapper-store and worker-load authority'
    }
    Complete-Check 'wrapper-store-worker-load-authority'

    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $fixture,$functionsPath
    if ($LASTEXITCODE -ne 0) { throw 'C415 authoritative focused format failed' }

    $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    $managedExe = Join-Path $output 'managed.exe'
    $managedLog = (& dotnet $managed run $fixture --llvm $llvm -o $managedExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $managedLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) {
        throw "managed C415 exact execution failed: $managedLog"
    }
    Complete-Check 'managed-native-exact'

    $candidateExe = Join-Path $output 'candidate.exe'
    $candidateLog = (& $candidate run $fixture --stdlib $stdlib --llvm $llvm -o $candidateExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $candidateLog -match '(?m)^warning ' -or
        $candidateLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) {
        throw "selfhost C415 exact execution failed: $candidateLog"
    }
    Complete-Check 'current-selfhost-native-exact-warning-zero'

    $ownedExpected = [IO.File]::ReadAllText($ownedExpectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    $ownedManagedExe = Join-Path $output 'owned-managed.exe'
    $ownedManagedLog = (& dotnet $managed run $ownedFixture --llvm $llvm -o $ownedManagedExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $ownedManagedLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $ownedExpected) {
        throw "managed C415 owned-parameter exact execution failed: $ownedManagedLog"
    }
    $ownedCandidateExe = Join-Path $output 'owned-candidate.exe'
    $ownedCandidateLog = (& $candidate run $ownedFixture --stdlib $stdlib --llvm $llvm -o $ownedCandidateExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $ownedCandidateLog -match '(?m)^warning ' -or
        $ownedCandidateLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $ownedExpected) {
        throw "selfhost C415 owned-parameter exact execution failed: $ownedCandidateLog"
    }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath ($ownedCandidateExe + '.ll')
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C415 owned-parameter direct-call closure failed' }
    Complete-Check 'owned-parameter-normal-completion'

    $standaloneExpected = [IO.File]::ReadAllText($standaloneExpectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    $standaloneExe = Join-Path $output 'standalone.exe'
    $standaloneLog = (& $candidate run $standaloneFixture --stdlib $standaloneSourceRoot --llvm $llvm -o $standaloneExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $standaloneLog -match '(?m)^warning ' -or
        $standaloneLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $standaloneExpected) {
        throw "standalone selfhost async runtime failed: $standaloneLog"
    }
    $standaloneLlvm = $standaloneExe + '.ll'
    $standaloneLlvmText = [IO.File]::ReadAllText($standaloneLlvm).Replace("`r`n", "`n")
    foreach ($definition in @(
        'define internal ptr @sollang_task_start(',
        'define internal i1 @sollang_task_join(',
        'define internal i1 @sollang_task_release('
    )) {
        Require-Text $standaloneLlvmText $definition 'standalone Task runtime definition'
    }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $standaloneLlvm
    if ($LASTEXITCODE -ne 0) { throw 'standalone selfhost async direct-call closure failed' }
    Complete-Check 'standalone-async-runtime-call-definition-closure'

    $candidateLlvm = $candidateExe + '.ll'
    if (-not (Test-Path -LiteralPath $candidateLlvm -PathType Leaf)) {
        throw "selfhost C415 LLVM is missing: $candidateLlvm"
    }
    $llvmText = [IO.File]::ReadAllText($candidateLlvm).Replace("`r`n", "`n")
    if ($llvmText -notmatch 'define %sollang\.task @sollang_m\d+_s\d+\(i32 %arg, i32 %arg1, i32 %arg2\)' -or
        $llvmText -notmatch 'call i32 @sollang_m\d+_s\d+_async_body\(i32 %async_arg, i32 %async_arg1, i32 %async_arg2\)' -or
        $llvmText -match 'call i32 @sollang_m\d+_s\d+_async_body\(\)') {
        throw 'generated C415 LLVM does not preserve the exact async parameter call shape'
    }
    Complete-Check 'generated-llvm-parameter-shape'

    & $llvmAs $candidateLlvm -o (Join-Path $output 'candidate.bc')
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C415 LLVM assembly failed' }
    Complete-Check 'llvm-assembly'

    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $candidateLlvm
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C415 direct-call closure failed' }
    Complete-Check 'direct-call-closure'

    if ($record.completed -ne $record.total) { throw "C415 denominator mismatch: $($record.completed)/$($record.total)" }
    $record.status = 'passed'
    Save-Result
    Write-Host "[selfhost async parameters] PASS 11/11; $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
