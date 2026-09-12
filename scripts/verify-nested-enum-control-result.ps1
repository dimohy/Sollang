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
$fixture = Join-Path $root 'scripts/contracts/fixtures/c412-nested-enum-control-result.slg'
$expectedPath = Join-Path $root 'scripts/contracts/fixtures/c412-nested-enum-control-result.stdout.txt'
$typedPath = Join-Path $root 'selfhost/ir/typed/function_lowering.slg'
$controlPath = Join-Path $root 'selfhost/llvm/text/control.slg'
$stdlib = Join-Path $root 'stdlib'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvm 'bin/llvm-as.exe'
$output = Join-Path $root ('artifacts/scratch/nested-enum-control-result-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'

foreach ($path in @($candidate, $managed, $fixture, $expectedPath, $typedPath, $controlPath, $stdlib, $llvmAs)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing C412 input: $path" }
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'nested-enum-payload-subject-and-subject-when-control-result'
    completed = 0
    total = 8
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
    $typed = [IO.File]::ReadAllText($typedPath)
    Require-Text $typed 'enumPayloadArmIndex payloadIndex: Int' 'payload-arm authority'
    Require-Text $typed 'nodes[payloadParent].operand0 == payloadIndex' 'pattern payload edge'
    Require-Text $typed 'subjectBinding.kind == 29 -> if {' 'direct payload subject transfer'
    Complete-Check 'exact-pattern-payload-arm-topology'
    Complete-Check 'direct-payload-read-subject-linkage'

    $control = [IO.File]::ReadAllText($controlPath)
    Require-Text $control 'context.ir[resolved!].parent == armResultIndex' 'subject-when arm ownership'
    Require-Text $control 'context.ir[resolved!].operand1 => directControlIndex' 'subject-when direct control edge'
    Require-Text $control 'directControlIndex => resolved!' 'subject-when control selection'
    Complete-Check 'subject-when-direct-control-result-selection'

    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $fixture,$typedPath,$controlPath
    if ($LASTEXITCODE -ne 0) { throw 'authoritative focused format failed' }
    Complete-Check 'authoritative-focused-format'

    $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    $managedExe = Join-Path $output 'managed.exe'
    $managedLog = (& dotnet $managed run $fixture --llvm $llvm -o $managedExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $managedLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) {
        throw "managed C412 exact execution failed: $managedLog"
    }
    Complete-Check 'managed-native-exact'

    $candidateExe = Join-Path $output 'candidate.exe'
    $candidateLog = (& $candidate run $fixture --stdlib $stdlib --llvm $llvm -o $candidateExe --keep-temps -O0 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $candidateLog -match '(?m)^warning ' -or
        $candidateLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) {
        throw "selfhost C412 exact execution failed: $candidateLog"
    }
    Complete-Check 'current-selfhost-native-exact-warning-zero'

    $candidateLlvm = $candidateExe + '.ll'
    if (-not (Test-Path -LiteralPath $candidateLlvm -PathType Leaf)) {
        throw "selfhost C412 LLVM is missing: $candidateLlvm"
    }
    & $llvmAs $candidateLlvm -o (Join-Path $output 'candidate.bc')
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C412 LLVM assembly failed' }
    Complete-Check 'llvm-assembly'

    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $candidateLlvm
    if ($LASTEXITCODE -ne 0) { throw 'selfhost C412 direct-call closure failed' }
    Complete-Check 'direct-call-closure'

    $record.status = 'passed'
    Save-Result
    Write-Host "[nested enum control result] PASS 8/8; $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
