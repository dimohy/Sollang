[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)]
    [string]$CandidateCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$fixture = Join-Path $root 'scripts/contracts/fixtures/c410-post-arithmetic-mutable-slot.slg'
$expectedPath = Join-Path $root 'scripts/contracts/fixtures/c410-post-arithmetic-mutable-slot.stdout.txt'
$aliasesPath = Join-Path $root 'selfhost/ir/typed/value_aliases.slg'
$finalizePath = Join-Path $root 'selfhost/ir/typed/resolved_context_finalize.slg'
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$candidate = [IO.Path]::GetFullPath($CandidateCompiler)
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$stdlib = Join-Path $root 'stdlib'
$output = Join-Path $root ('artifacts/scratch/post-arithmetic-mutable-slot-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'

$required = @($fixture, $expectedPath, $aliasesPath, $finalizePath, $managed, $candidate, (Join-Path $llvm 'bin/llvm-as.exe'))
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing input: $path" }
}
if (-not (Test-Path -LiteralPath $stdlib -PathType Container)) { throw "missing stdlib root: $stdlib" }

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'post-arithmetic-mutable-slot-type-fixed-point'
    completed = 0
    total = 8
    checks = @()
    inputHashes = [ordered]@{}
    resultPath = $resultPath
}
foreach ($path in @($required + $PSCommandPath | Select-Object -Unique)) {
    $record.inputHashes[$path] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}
function Assert-Contains([string]$Text, [string]$Fragment, [string]$Label) {
    if (-not $Text.Contains($Fragment)) { throw "$Label drifted: $Fragment" }
}

try {
    Save-Result
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $fixture
    if ($LASTEXITCODE -ne 0) { throw 'fixture authoritative format failed' }
    Complete-Check 'fixture-authoritative-format'

    $aliases = [IO.File]::ReadAllText($aliasesPath).Replace("`r`n", "`n")
    Assert-Contains $aliases 'sealPostArithmeticSlotTypes nodes: mut [TypedIrNode; ~]' 'post-arithmetic slot authority'
    Assert-Contains $aliases 'arithmeticRootBySymbol!' 'exact mutable source-symbol root index'
    Assert-Contains $aliases 'nodes -> sealIntegerLiteralPeerContext(arithmeticRebindValue!.operand1, arithmeticRoot)' 'rebind literal context'
    Complete-Check 'post-arithmetic-slot-root-contract'

    $finalize = [IO.File]::ReadAllText($finalizePath).Replace("`r`n", "`n")
    Assert-Contains $finalize 'true => numericTypesChanged!' 'contextual numeric fixed point'
    Assert-Contains $finalize 'previousResultTypeId != nodes[numericIndex!].typeId' 'contextual numeric convergence observation'
    Complete-Check 'contextual-numeric-fixed-point-contract'

    $finalSequence = @'
    nodes -> sealFinalBinaryOperandTopology(prepared)
    nodes -> sealPostArithmeticSlotTypes(prepared)
    nodes -> sealFinalContextualNumericLiterals
    nodes -> sealPostArithmeticSlotTypes(prepared)
    nodes -> sealEnumMatchTypesFromTerminalArms(frozenRecursiveSemanticTypes, recursiveTypeFlags)
'@
    Assert-Contains $finalize $finalSequence.Replace("`r`n", "`n") 'final producer-consumer ordering'
    Complete-Check 'final-slot-numeric-match-ordering'

    $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")
    $managedExe = Join-Path $output 'managed.exe'
    $managedLog = (& dotnet $managed build $fixture -o $managedExe --target windows-x64 -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $managedLog -match '(?m)^warning ' -or -not (Test-Path -LiteralPath $managedExe)) {
        throw "managed fixture build failed or warned: $managedLog"
    }
    $managedOutput = (& $managedExe 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or ($managedOutput.TrimEnd() + "`n") -cne $expected) {
        throw "managed fixture output mismatch: $managedOutput"
    }
    Complete-Check 'managed-warning-zero-native-exact'

    $candidateExe = Join-Path $output 'candidate.exe'
    $candidateLog = (& $candidate run $fixture --stdlib $stdlib --llvm $llvm -o $candidateExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $candidateLog -match '(?m)^warning ' -or -not (Test-Path -LiteralPath $candidateExe)) {
        throw "candidate fixture run failed or warned: $candidateLog"
    }
    if (($candidateLog.TrimEnd() + "`n") -cne $expected) { throw "candidate fixture output mismatch: $candidateLog" }
    Complete-Check 'candidate-warning-zero-native-exact'

    $candidateLlvm = $candidateExe + '.ll'
    & (Join-Path $llvm 'bin/llvm-as.exe') $candidateLlvm -o (Join-Path $output 'candidate.bc')
    if ($LASTEXITCODE -ne 0) { throw 'candidate LLVM assembly failed' }
    Complete-Check 'candidate-llvm-assembly'

    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $candidateLlvm
    if ($LASTEXITCODE -ne 0) { throw 'candidate direct-call closure failed' }
    Complete-Check 'candidate-direct-call-closure'

    $record.status = 'passed'
    Save-Result
    Write-Host "PASS $($record.completed)/$($record.total); $resultPath"
} catch {
    $record.status = 'failed'
    $record.error = $_.Exception.Message
    Save-Result
    throw
}
