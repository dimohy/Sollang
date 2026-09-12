[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

function Get-SlgFunction {
    param([string]$Text, [string]$Signature)
    $start = $Text.IndexOf($Signature, [StringComparison]::Ordinal)
    if ($start -lt 0 -or $Text.IndexOf($Signature, $start + $Signature.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Expected exactly one production function signature: $Signature"
    }
    $brace = $Text.IndexOf('{', $start)
    if ($brace -lt 0) { throw "Production function has no body: $Signature" }
    $depth = 0
    for ($index = $brace; $index -lt $Text.Length; $index++) {
        if ($Text[$index] -ceq '{') { $depth++ }
        elseif ($Text[$index] -ceq '}') {
            $depth--
            if ($depth -eq 0) { return $Text.Substring($start, $index - $start + 1) }
        }
    }
    throw "Production function body is unbalanced: $Signature"
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$source = Join-Path $root 'selfhost/llvm/text/ownership.slg'
$template = Join-Path $root 'scripts/contracts/fixtures/c401-known-borrowed-source-text-drop.slg.in'
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$formatter = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/c401-known-borrowed-source-text-drop-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$generated = Join-Path $output 'c401-known-borrowed-source-text-drop.slg'
$executable = Join-Path $output 'c401-known-borrowed-source-text-drop.exe'
$llvmPath = Join-Path $output 'c401-known-borrowed-source-text-drop.ll'
$resultPath = Join-Path $output 'result.json'

$inputs = @($source, $template, $compiler, $formatter, $closureVerifier, $PSCommandPath,
    (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
    (Join-Path $PSScriptRoot 'stage2-artifact-receipt.ps1'))
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C401 probe input is missing: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$stdlibRoot = Join-Path $root 'stdlib'
$stdlibSources = Get-NativeExactOrderedSourceClosure -Root $stdlibRoot
$stdlibFingerprintSettings = [ordered]@{ platform = 'windows'; scope = 'c401-selfhost-drop-probe-stdlib' }
$stdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath $stdlibSources
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'selfhost-normal-drop-glue-known-borrowed-source-text-focused'
    completed = 0
    total = 20
    behavior = [ordered]@{ positive = 0; positiveTotal = 5; negative = 0; negativeTotal = 10 }
    checks = @()
    inputHashes = $hashes
    stdlibSourceCount = $stdlibSources.Count
    stdlibSourceFingerprint = $stdlibFingerprint
    generatedSource = $generated
    runLog = Join-Path $output 'run.log'
    exclusions = @('emitEnumPayloadDrop C402', 'whole selfhost compiler build', 'Stage2/Stage3', 'central specification and defect ledger')
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}

try {
    Save-Result
    $production = [IO.File]::ReadAllText($source).Replace("`r`n", "`n")
    $helperSignature = 'knownBorrowedSourceTextDrop request: DropGlueRequest, context: ref emitterContext.EmitContext -> Bool {'
    $normalSignature = 'emitDropGlue request: DropGlueRequest, edgeNodeIndex: Int, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {'
    $enumSignature = 'emitEnumPayloadDrop request: EnumPayloadDropRequest, context: ref emitterContext.EmitContext, state: ref CoreEmitterState -> Unit uses Console {'
    $helper = Get-SlgFunction $production $helperSignature
    $normal = Get-SlgFunction $production $normalSignature
    $enum = Get-SlgFunction $production $enumSignature
    if ([regex]::Matches($normal, 'knownBorrowedSourceTextDrop\(context\)').Count -ne 1) {
        throw 'Normal emitDropGlue must call the C401 predicate exactly once.'
    }
    if ([regex]::Matches($enum, 'knownBorrowedSourceTextDrop\(context\)').Count -ne 0) {
        throw 'C401 predicate must not enter emitEnumPayloadDrop (C402 authority).'
    }
    if (-not $helper.Contains('candidate.flags != 1') -or
        -not $helper.Contains('candidate.opcode == -206 or candidate.opcode == -232')) {
        throw 'C401 helper no longer has the frozen immutable-alias and borrowed-producer boundaries.'
    }
    Complete-Check 'brace-balanced-production-helper-and-normal-only-integration'

    $probeHelper = $helper.Replace(
        'context: ref emitterContext.EmitContext', 'context: ref EmitContext').Replace(
        'typeQueries.isSourceText', 'isSourceText')
    $templateText = [IO.File]::ReadAllText($template).Replace("`r`n", "`n")
    if ([regex]::Matches($templateText, '__PRODUCTION_HELPER__').Count -ne 1) {
        throw 'C401 fixture template must contain exactly one production-helper placeholder.'
    }
    [IO.File]::WriteAllText($generated, $templateText.Replace('__PRODUCTION_HELPER__', $probeHelper), [Text.UTF8Encoding]::new($false))
    # The generated fixture lives in scratch, outside the authoritative-source
    # allowlist. Invoke the same frozen formatter directly for this derived file.
    & dotnet $compiler format --check $generated
    if ($LASTEXITCODE -ne 0) { throw 'Generated C401 SLG fixture is not authoritative-format clean.' }
    Complete-Check 'generated-slg-authoritative-format'

    $actual = (& dotnet $compiler run $generated --llvm $llvm -o $executable --keep-temps 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText($record.runLog, $actual + "`n", [Text.UTF8Encoding]::new($false))
    $expectedLines = @(
        'direct-borrow-text=true',
        'direct-borrow-bytes=true',
        'immutable-binding=true',
        'immutable-read=true',
        'immutable-two-hop=true',
        'mutable-read=false',
        'control-wrapper=false',
        'tap-wrapper=false',
        'opaque-call=false',
        'owned-map=false',
        'owned-stdin=false',
        'owned-chunk=false',
        'parameter-read=false',
        'field-value-kind=false',
        'alias-cycle=false',
        'C401 known borrowed SourceText drop=true: 15/15'
    )
    $actualLines = @($actual.Replace("`r`n", "`n").TrimEnd("`n") -split "`n")
    if ($exitCode -ne 0 -or $actualLines.Count -ne $expectedLines.Count) {
        throw "C401 fixture failed or returned an unexpected line count (exit=$exitCode, lines=$($actualLines.Count))."
    }
    for ($index = 0; $index -lt 15; $index++) {
        if ($actualLines[$index] -cne $expectedLines[$index]) {
            throw "C401 behavior mismatch at case $($index + 1): $($actualLines[$index])"
        }
        if ($index -lt 5) { $record.behavior.positive++ } else { $record.behavior.negative++ }
        Complete-Check "behavior-$($index + 1)-$($expectedLines[$index])"
    }
    if ($actualLines[15] -cne $expectedLines[15]) { throw 'C401 fixture summary is not exact.' }
    Complete-Check 'managed-compile-execute-exact-summary'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf) -or -not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
        throw 'C401 fixture did not produce both executable and LLVM output.'
    }

    & (Join-Path $llvm 'bin/llvm-as.exe') $llvmPath -o (Join-Path $output 'c401-known-borrowed-source-text-drop.bc')
    if ($LASTEXITCODE -ne 0) { throw 'C401 fixture LLVM assembly failed.' }
    & $closureVerifier -LlvmPath $llvmPath
    if ($LASTEXITCODE -ne 0) { throw 'C401 fixture direct-call closure failed.' }
    Complete-Check 'llvm-assemble-and-direct-call-closure'

    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) {
            throw "C401 verification input changed during execution: $path"
        }
    }
    $endingStdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath (Get-NativeExactOrderedSourceClosure -Root $stdlibRoot)
    if ($endingStdlibFingerprint -cne $stdlibFingerprint) {
        throw 'C401 stdlib source closure changed during verification.'
    }
    $record.generatedHashes = [ordered]@{
        source = (Get-FileHash -LiteralPath $generated -Algorithm SHA256).Hash
        llvm = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
        executable = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
    }
    Complete-Check 'input-hashes-stable'
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    Save-Result
    Write-Host "[C401 selfhost normal cleanup] $($record.status) $($record.completed)/$($record.total); behavior $($record.behavior.positive)/$($record.behavior.positiveTotal) positive + $($record.behavior.negative)/$($record.behavior.negativeTotal) negative; $resultPath"
}
if ($record.status -ne 'passed') { exit 1 }
