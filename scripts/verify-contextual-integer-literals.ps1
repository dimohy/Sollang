[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCompiler,
    [switch]$RequireCandidateSealed
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $repo ('artifacts/scratch/contextual-integer-literals/' + [guid]::NewGuid().ToString('N'))
$compiler = Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
New-Item -ItemType Directory -Path $output -Force | Out-Null
if ($RequireCandidateSealed -and [string]::IsNullOrWhiteSpace($CandidateCompiler)) {
    throw '-RequireCandidateSealed requires -CandidateCompiler.'
}

function Read-Declaration([string]$Path, [string]$Name) {
    $source = Get-Content -LiteralPath (Join-Path $repo $Path) -Raw
    $pattern = '(?ms)^' + [regex]::Escape($Name) + ' [^\r\n]*\{.*?^\}'
    $matches = [regex]::Matches($source, $pattern)
    if ($matches.Count -ne 1) { throw "expected one authoritative declaration: $Path / $Name" }
    return $matches[0].Value
}

$helper = Read-Declaration 'selfhost/ir/typed/type_queries.slg' 'sealIntegerLiteralContext'
$numericHelper = Read-Declaration 'selfhost/ir/typed/type_queries.slg' 'sealNumericLiteralContext'
$numericPeerHelper = Read-Declaration 'selfhost/ir/typed/type_queries.slg' 'sealNumericLiteralPeerContext'
$peerHelper = Read-Declaration 'selfhost/ir/typed/type_queries.slg' 'sealIntegerLiteralPeerContext'
$nativeHelper = Read-Declaration 'selfhost/ir/typed/type_queries.slg' 'sealNativeNumericLiteralContext'
$binaryPass = Read-Declaration 'selfhost/ir/typed/resolved_context_finalize.slg' 'sealFinalContextualNumericLiterals'
$node = Read-Declaration 'selfhost/ir/typed.slg' 'public struct TypedIrNode'
$rank = Read-Declaration 'selfhost/ir/typed.slg' 'integerTypeRank'
$type = Read-Declaration 'selfhost/semantic/type_ids.slg' 'public struct SemanticType'
$grammarSource = Get-Content -LiteralPath (Join-Path $repo 'syntax/generated/sollang_grammar.slg') -Raw
$grammarDeclarations = @('Minus', 'Plus', 'Percent', 'EqualEqual', 'BangEqual', 'LessEqual', 'Greater') | ForEach-Object {
    $declaration = [regex]::Match($grammarSource, ('(?m)^public tokenId' + $_ + ':[^\r\n]+')).Value
    if ([string]::IsNullOrWhiteSpace($declaration)) { throw "missing authoritative tokenId$_ declaration" }
    $declaration
}
$minusTokenId = [int]([regex]::Match($grammarDeclarations[0], '=>\s*(\d+)').Groups[1].Value)

$helperSource = @"
namespace sollang.compiler.ir.typed
import sollang.compiler.semantic.type_ids as typeIds
import syntax.generated.slg as grammar
$node
$rank
$numericHelper
$numericPeerHelper
$helper
$peerHelper
$nativeHelper
$binaryPass
"@
$sources = @(
    @{ Name = 'helper.slg'; Text = $helperSource },
    @{ Name = 'types.slg'; Text = "namespace sollang.compiler.semantic.type_ids`n$type`n" },
    @{ Name = 'grammar.slg'; Text = "namespace syntax.generated.slg`n$($grammarDeclarations -join "`n")`n" },
    @{ Name = 'entry.slg'; Text = "import sollang.compiler.ir.typed as probe`nmain { probe.run() }`n" }
)
$nativeTopology = $null
$nativeExpected = $null
if ($CandidateCompiler) {
    $candidate = [IO.Path]::GetFullPath($CandidateCompiler)
    $fixture = Join-Path $repo 'scripts/contracts/fixtures/1715-native-negative-float-context.slg'
    $candidateIr = (& $candidate typed-ir-nodes $fixture 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "native Float candidate IR failed: $candidateIr" }
    [IO.File]::WriteAllText((Join-Path $output '1715-candidate-typed-ir.txt'), $candidateIr)
    $fieldNames = @('index', 'kind', 'parent', 'sourceModule', 'astNode', 'symbol', 'targetModule', 'typeId', 'typeKind', 'typeOrigin', 'typeModule', 'typeSymbol', 'typeFlags', 'payloadToken', 'opcode', 'operand0', 'operand1', 'nextOperand', 'flags')
    $nativeRows = @($candidateIr -split '\r?\n' | ForEach-Object {
        if ($_ -notmatch '^node \d+ kind -?\d+ parent ') { throw "unexpected typed IR line: $_" }
        $numbers = @([regex]::Matches($_, '-?\d+') | ForEach-Object { [int]$_.Value })
        if ($numbers.Count -ne $fieldNames.Count) { throw "unexpected typed IR field count: $_" }
        $row = [ordered]@{}
        for ($fieldIndex = 0; $fieldIndex -lt $fieldNames.Count; $fieldIndex++) { $row[$fieldNames[$fieldIndex]] = $numbers[$fieldIndex] }
        [pscustomobject]$row
    })
    $nativeFunctions = @($nativeRows | Where-Object { $_.kind -eq 0 -and ($_.flags -band 128) -ne 0 })
    $nativeCalls = @($nativeRows | Where-Object { $_.kind -eq 6 })
    if ($nativeFunctions.Count -ne 1 -or $nativeCalls.Count -ne 1) { throw 'fixture 1715 must contain exactly one native function and call' }
    $nativeFunction = $nativeFunctions[0]
    if ($nativeCalls[0].symbol -ne $nativeFunction.symbol -or $nativeCalls[0].targetModule -ne $nativeFunction.sourceModule) { throw 'fixture 1715 native call identity mismatch' }
    $nativeBody = @('namespace sollang.compiler.ir.typed', 'public runNativeCandidateProbe: -> Unit uses Console {', '    [TypedIrNode; ~] => nativeNodes!')
    $expectedNodeIndex = 0
    foreach ($row in $nativeRows) {
        if ($row.index -ne $expectedNodeIndex) { throw 'candidate typed IR indices must be contiguous' }
        $expectedNodeIndex++
        $fields = $fieldNames | Select-Object -Skip 1 | ForEach-Object { '        ' + $_ + ': ' + $row.$_ }
        $nativeBody += "    nativeNodes! -> push(TypedIrNode {`n$($fields -join "`n")`n    })"
    }
    $argumentIndex = $nativeCalls[0].operand0
    $parameterIndex = $nativeFunction.operand1
    $contextNodes = @()
    for ($argumentOrdinal = 0; $argumentOrdinal -lt 2; $argumentOrdinal++) {
        if ($argumentIndex -lt 0 -or $argumentIndex -ge $nativeRows.Count -or $parameterIndex -lt 0 -or $parameterIndex -ge $nativeRows.Count) { throw 'fixture 1715 invalid argument/parameter edge' }
        $argument = $nativeRows[$argumentIndex]
        if ($argument.kind -ne 7 -or $argument.opcode -ne $minusTokenId -or $argument.operand0 -lt 0 -or $argument.operand0 -ge $nativeRows.Count -or $argument.operand1 -ne -1 -or $nativeRows[$argument.operand0].kind -ne 3) { throw 'fixture 1715 negative literal must use unary operand0' }
        if ($nativeRows[$parameterIndex].typeSymbol -ne 21) { throw 'fixture 1715 requires Float64 parameters' }
        $nativeBody += "    nativeNodes! -> sealNativeNumericLiteralContext($argumentIndex, nativeNodes![$parameterIndex])"
        $contextNodes += $argumentIndex, $argument.operand0
        $argumentIndex = $argument.nextOperand
        $parameterIndex = $nativeFunction.nextOperand
    }
    $interpolations = $contextNodes | ForEach-Object { '$(nativeNodes![' + $_ + '].typeId)' }
    $nativeBody += '    "native-source-context=' + ($interpolations -join ',') + '" -> println'
    $nativeBody += '}'
    $sources[-1].Text = "import sollang.compiler.ir.typed as probe`nmain {`n    probe.run()`n    probe.runNativeCandidateProbe()`n}`n"
    $sources += @{ Name = '1715-native-candidate-context.slg'; Text = $nativeBody -join "`n" }
    $nativeExpected = 'native-source-context=21,21,21,21'
    $candidateContextMismatchCount = @($contextNodes | Where-Object {
        $row = $nativeRows[$_]
        $row.typeId -ne 21 -or $row.typeKind -ne 1 -or $row.typeOrigin -ne 1 `
            -or $row.typeModule -ne -1 -or $row.typeSymbol -ne 21 -or $row.typeFlags -ne 0
    }).Count
    $nativeTopology = [ordered]@{
        fixture = 'scripts/contracts/fixtures/1715-native-negative-float-context.slg'
        fixtureSha256 = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
        candidateSha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
        scope = 'source-only-candidate-ir-replayed-through-current-native-context-helper'
        carrierOperand = 0
        contextNodeIndices = $contextNodes
        candidateUnsealedNodeCount = $candidateContextMismatchCount
        currentHelperExpectedTypeIds = @(21, 21, 21, 21)
        requiredCandidateContext = 'typeId=21 kind=1 origin=1 module=-1 symbol=21 flags=0'
    }
    if ($RequireCandidateSealed -and $nativeTopology.candidateUnsealedNodeCount -ne 0) {
        throw "candidate compiler left $($nativeTopology.candidateUnsealedNodeCount) native Float carrier/leaf nodes outside their declared context"
    }
}
$paths = @()
foreach ($source in $sources) {
    $path = Join-Path $output $source.Name
    [IO.File]::WriteAllText($path, $source.Text)
    $paths += $path
}
$paths += Join-Path $repo 'scripts/probes/contextual-integer-literals.slg'
$actual = (& dotnet $compiler run @paths --llvm (Join-Path $repo '.tools/llvm-22.1.8') -o (Join-Path $output 'probe.exe') 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "contextual integer helper execution failed: $actual" }
$expected = @(
    'negative=6,6,7'
    'nonliteral=2,2,2'
    'invalid=2'
    'unsigned=11,11'
    'casts=11,11,2'
    'leaf-guards=2,21,2,0,20,2'
    'target-guards=2'
    'unsigned-negative-context=11,11'
    'binary=6,6,6,23,2'
    'identity=1,1,-1,6,0'
    'native-integer=6,6,7'
    'native-integer-guards=21,11,2'
    'native-float=20,21,21,7'
    'native-float-unary=21,21,2'
    'native-boundary=2,2'
    'native-float-alias=19,22'
) -join "`n"
if ($nativeExpected) { $expected += "`n$nativeExpected" }
if ($actual.Replace("`r`n", "`n").TrimEnd() -cne $expected) { throw "contextual integer helper output mismatch: $actual" }

$callsites = @('selfhost/ir/typed/resolved_context_normalize_phases.slg', 'selfhost/ir/typed/resolved_context_seal.slg')
foreach ($callsite in $callsites) {
    $body = Get-Content -LiteralPath (Join-Path $repo $callsite) -Raw
    if ($body -notmatch 'nodes -> sealIntegerLiteralContext\(') { throw "missing shared integer context call: $callsite" }
}
$nativeCallsite = Get-Content -LiteralPath (Join-Path $repo 'selfhost/ir/typed/resolved_context_seal.slg') -Raw
if ($nativeCallsite -notmatch 'nodes -> sealNativeNumericLiteralContext\(contextualNativeArgumentIndex!, contextualNativeParameter\)') {
    throw 'missing shared native numeric context call'
}
$evidence = [ordered]@{
    schemaVersion = 1
    scope = 'production-integer-native-helpers-and-final-binary-pass-execution-and-callsite-presence'
    status = 'passed'
    completed = 16 + [int][bool]$nativeExpected
    total = 16 + [int][bool]$nativeExpected
    countUnit = 'exact-output-assertion-groups'
    compilerSha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
    helperSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($helper)))
    numericHelperSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($numericHelper)))
    numericPeerHelperSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($numericPeerHelper)))
    peerHelperSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($peerHelper)))
    nativeHelperSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($nativeHelper)))
    binaryPassSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($binaryPass)))
    stdout = $actual
    selfhostCandidateExecution = if ($RequireCandidateSealed) { 'actual-candidate-native-context-sealed' } else { 'pending-accumulated-compiler-verification' }
    candidateSealingRequired = [bool]$RequireCandidateSealed
    signedAndRangeDiagnostics = 'pending-source-semantic-integration-including-negative-zero'
    sourceDecimalClassification = 'not-proven-by-metadata-probe-initial-semantic-seed-uses-int-for-number-ast'
    nativeFloatTopology = 'integer-and-float-share-canonical-operand0-leaf-carrier-context'
    nativeCandidateTopology = $nativeTopology
}
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($evidence | ConvertTo-Json -Depth 4))
Write-Output "Contextual integer literals: production integer/native helpers and final binary pass PASS $($evidence.completed)/$($evidence.total) assertion groups; rebuilt selfhost and signed/range diagnostics pending."
Write-Output (Join-Path $output 'result.json')
