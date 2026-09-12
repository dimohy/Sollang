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
$rangeHelper = Read-Declaration 'selfhost/llvm/emitter/diagnostics.slg' 'initializerIntegerLiteralFits'
$characterSpan = Read-Declaration 'selfhost/syntax/source.slg' 'public struct SourceSpan'
$characterDecoder = Read-Declaration 'selfhost/syntax/source.slg' 'public decodeCharacterLiteral'
$constantFind = Read-Declaration 'selfhost/semantic/constant_collection_lowering.slg' 'public find'
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

$rangeContractPath = Join-Path $repo 'scripts/contracts/fixtures/c394-contextual-integer-range.json'
$rangeContract = Get-Content -LiteralPath $rangeContractPath -Raw | ConvertFrom-Json
if ($rangeContract.schemaVersion -ne 1 -or @($rangeContract.cases).Count -eq 0) {
    throw 'invalid C394 contextual integer range contract'
}
$authoritativeRangeTuples = @'
int-alias-min|2|64|2147483648|true|true
int-alias-underflow|2|64|2147483649|true|false
int-alias-max|2|64|2147483647|false|true
int-alias-overflow|2|64|2147483648|false|false
int8-min|3|64|128|true|true
int8-underflow|3|64|129|true|false
int8-max|3|64|127|false|true
int8-overflow|3|64|128|false|false
int16-min|4|64|32768|true|true
int16-underflow|4|64|32769|true|false
int16-max|4|64|32767|false|true
int16-overflow|4|64|32768|false|false
int32-min|5|64|2147483648|true|true
int32-underflow|5|64|2147483649|true|false
int32-max|5|64|2147483647|false|true
int32-overflow|5|64|2147483648|false|false
int64-min|6|64|9223372036854775808|true|true
int64-underflow|6|64|9223372036854775809|true|false
int64-max|6|64|9223372036854775807|false|true
int64-overflow|6|64|9223372036854775808|false|false
long-alias-min|7|64|9223372036854775808|true|true
long-alias-underflow|7|64|9223372036854775809|true|false
long-alias-max|7|64|9223372036854775807|false|true
long-alias-overflow|7|64|9223372036854775808|false|false
int64-min-underscores|6|64|9_223_372_036_854_775_808|true|true
signed-negative-zero|6|64|0|true|true
uint8-max|8|64|255|false|true
uint8-overflow|8|64|256|false|false
uint8-negative|8|64|1|true|false
unsigned-negative-zero|8|64|0|true|true
uint16-max|9|64|65535|false|true
uint16-overflow|9|64|65536|false|false
uint32-max|10|64|4294967295|false|true
uint32-overflow|10|64|4294967296|false|false
uint64-max|11|64|18446744073709551615|false|true
uint64-overflow|11|64|18446744073709551616|false|false
size32-min|12|32|2147483648|true|true
size32-underflow|12|32|2147483649|true|false
size32-max|12|32|2147483647|false|true
size32-overflow|12|32|2147483648|false|false
usize32-max|13|32|4294967295|false|true
usize32-overflow|13|32|4294967296|false|false
size64-min|12|64|9223372036854775808|true|true
size64-underflow|12|64|9223372036854775809|true|false
size64-max|12|64|9223372036854775807|false|true
size64-overflow|12|64|9223372036854775808|false|false
usize64-max|13|64|18446744073709551615|false|true
usize64-overflow|13|64|18446744073709551616|false|false
codepoint-before-surrogate|14|64|55295|false|true
codepoint-surrogate-start|14|64|55296|false|false
codepoint-surrogate-end|14|64|57343|false|false
codepoint-after-surrogate|14|64|57344|false|true
codepoint-max|14|64|1114111|false|true
codepoint-overflow|14|64|1114112|false|false
codepoint-negative|14|64|1|true|false
lexeme-only-underscore|6|64|_|false|false
lexeme-letter|6|64|12x|false|false
lexeme-empty|6|64||false|false
lexeme-leading-underscore|6|64|_1|false|false
lexeme-trailing-underscore|6|64|1_|false|false
lexeme-double-underscore|6|64|1__0|false|false
lexeme-valid-underscore|6|64|1_0|false|true
'@ -split '\r?\n' | Where-Object { $_ -ne '' }
$expectedRangeCaseProperties = @('name', 'typeSymbol', 'pointerBitWidth', 'spelling', 'negative', 'fits')
foreach ($case in $rangeContract.cases) {
    $caseProperties = @($case.PSObject.Properties.Name)
    if (($caseProperties -join '|') -cne ($expectedRangeCaseProperties -join '|')) {
        throw 'C394 contextual integer range cases require the exact ordered property schema'
    }
    if ($case.name -isnot [string] -or $case.typeSymbol -isnot [long] -or $case.pointerBitWidth -isnot [long] `
        -or $case.spelling -isnot [string] -or $case.negative -isnot [bool] -or $case.fits -isnot [bool]) {
        throw "C394 contextual integer range case has an invalid property type: $($case.name)"
    }
}
$actualRangeTuples = @($rangeContract.cases | ForEach-Object {
    @(
        $_.name,
        [string]$_.typeSymbol,
        [string]$_.pointerBitWidth,
        [string]$_.spelling,
        ([bool]$_.negative).ToString().ToLowerInvariant(),
        ([bool]$_.fits).ToString().ToLowerInvariant()
    ) -join '|'
})
if (($actualRangeTuples -join "`n") -cne ($authoritativeRangeTuples -join "`n")) {
    throw 'C394 contextual integer range contract must exactly match the authoritative ordered tuple matrix'
}
$rangeNames = @($rangeContract.cases | ForEach-Object { $_.name })
if (@($rangeNames | Sort-Object -Unique).Count -ne $rangeNames.Count) {
    throw 'C394 contextual integer range case names must be unique'
}
foreach ($case in $rangeContract.cases) {
    if ($case.name -notmatch '^[a-z0-9-]+$' -or $case.spelling -notmatch '^[A-Za-z0-9_]*$') {
        throw "unsafe C394 contextual integer range case text: $($case.name)"
    }
    if ($case.typeSymbol -lt 2 -or $case.typeSymbol -gt 14 -or $case.pointerBitWidth -notin @(32, 64)) {
        throw "invalid C394 contextual integer range target: $($case.name)"
    }
}

$rangeSources = @(
    @{ Name = 'range-types.slg'; Text = @"
namespace c394.type_ids
public struct SemanticType { public kind: Int, public origin: Int, public symbol: Int }
"@ },
    @{ Name = 'range-analysis.slg'; Text = @"
namespace c394.analysis
public struct SourceRange { public astStart: Int, public literalStart: Int, public literalCount: Int }
"@ },
    @{ Name = 'range-ast.slg'; Text = @"
namespace c394.ast
public struct AstNode { public start: UIntSize, public length: UIntSize }
"@ },
    @{ Name = 'range-typed.slg'; Text = @"
namespace c394.typed
public struct TypedIrNode { public kind: Int, public sourceModule: Int, public astNode: Int, public opcode: Int, public operand0: Int }
"@ },
    @{ Name = 'range-constant.slg'; Text = @"
namespace c394.constant
public struct Literal { public astNode: Int, public value: Long }
$constantFind
"@ },
    @{ Name = 'range-syntax.slg'; Text = @"
namespace c394.syntax
$characterSpan
$characterDecoder
"@ },
    @{ Name = 'range-context.slg'; Text = @"
namespace c394.context
import c394.analysis as analysis
import c394.ast as ast
import c394.constant as constantLowering
import c394.typed as typedIr
import c394.type_ids as typeIds
public struct EmitContext {
    public sources: [Text; ~]
    public ranges: [analysis.SourceRange; ~]
    public nodes: [ast.AstNode; ~]
    public constantLiterals: [constantLowering.Literal; ~]
    public ir: [typedIr.TypedIrNode; ~]
    public types: [typeIds.SemanticType; ~]
    public pointerBitWidth: Int
}
"@ },
    @{ Name = 'range-grammar.slg'; Text = "namespace syntax.generated.slg`n$($grammarDeclarations[0])`n" },
    @{ Name = 'range-helper.slg'; Text = @"
namespace sollang.compiler.llvm.emitter.diagnostics
import c394.constant as constantLowering
import c394.context as emitterContext
import c394.syntax as syntax
import c394.typed as typedIr
import syntax.generated.slg as grammar
$rangeHelper
"@ },
    @{ Name = 'range-entry.slg'; Text = @"
import sollang.compiler.llvm.emitter.diagnostics as diagnostics
main {
$(@($rangeContract.cases | ForEach-Object -Begin { $caseIndex = 0 } -Process {
    $negative = if ($_.negative) { 'true' } else { 'false' }
    $lines = @(
        '    "' + $_.spelling + '" -> diagnostics.sourceLiteralFits(' + $_.typeSymbol + ', ' + $_.pointerBitWidth + ', ' + $negative + ') => rangeCase' + $caseIndex
        '    "' + $_.name + '=$rangeCase' + $caseIndex + '" -> println'
    )
    $caseIndex++
    $lines -join "`n"
}) -join "`n")
}
"@ }
)
$rangePaths = @()
foreach ($source in $rangeSources) {
    $path = Join-Path $output $source.Name
    [IO.File]::WriteAllText($path, $source.Text)
    $rangePaths += $path
}
$rangePaths += Join-Path $repo 'scripts/probes/contextual-integer-literals/range-diagnostics.slg'
$rangeActual = (& dotnet $compiler run @rangePaths --llvm (Join-Path $repo '.tools/llvm-22.1.8') -o (Join-Path $output 'range-probe.exe') 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "contextual integer lexical range execution failed: $rangeActual" }
$rangeExpected = @($rangeContract.cases | ForEach-Object { $_.name + '=' + ([bool]$_.fits).ToString().ToLowerInvariant() }) -join "`n"
if ($rangeActual.Replace("`r`n", "`n").TrimEnd() -cne $rangeExpected) {
    throw "contextual integer lexical range output mismatch: $rangeActual"
}

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
    rangeHelperSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($rangeHelper)))
    stdout = $actual
    selfhostCandidateExecution = if ($RequireCandidateSealed) { 'actual-candidate-native-context-sealed' } else { 'pending-accumulated-compiler-verification' }
    candidateSealingRequired = [bool]$RequireCandidateSealed
    signedAndRangeDiagnostics = [ordered]@{
        status = 'passed-production-bounds-predicate-execution'
        completed = @($rangeContract.cases).Count
        total = @($rangeContract.cases).Count
        countUnit = 'source-lexical-boundary-cases'
        classifications = [ordered]@{
            signed = 26
            unsigned = 10
            size = 12
            codePoint = 7
            lexeme = 7
        }
        contract = 'scripts/contracts/fixtures/c394-contextual-integer-range.json'
        contractSha256 = (Get-FileHash -LiteralPath $rangeContractPath -Algorithm SHA256).Hash
        probeSha256 = (Get-FileHash -LiteralPath (Join-Path $repo 'scripts/probes/contextual-integer-literals/range-diagnostics.slg') -Algorithm SHA256).Hash
        characterDecoderSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($characterDecoder)))
        constantFindSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($constantFind)))
        diagnosticIntegration = 'pending-whole-selfhost-source-to-diagnostic'
        stdout = $rangeActual
    }
    sourceDecimalClassification = 'production lexical bounds proven independently; whole selfhost source-to-diagnostic integration pending'
    nativeFloatTopology = 'integer-and-float-share-canonical-operand0-leaf-carrier-context'
    nativeCandidateTopology = $nativeTopology
}
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($evidence | ConvertTo-Json -Depth 4))
Write-Output "Contextual integer literals: metadata helpers PASS $($evidence.completed)/$($evidence.total) assertion groups; production lexical bounds PASS $($evidence.signedAndRangeDiagnostics.completed)/$($evidence.signedAndRangeDiagnostics.total) cases (signed 26, unsigned 10, Size/USize 12, CodePoint 7, lexeme 7); rebuilt whole selfhost pending."
Write-Output (Join-Path $output 'result.json')
