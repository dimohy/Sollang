[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$positive = Join-Path $root 'examples/regression/1731-character-literals.slg'
$positiveExpected = Join-Path $root 'examples/regression/expected/1731-character-literals.stdout.txt'
$selfhostFixture = Join-Path $root 'examples/regression/1732-selfhost-character-literal-diagnostics.slg'
$selfhostExpected = Join-Path $root 'examples/regression/expected/1732-selfhost-character-literal-diagnostics.stdout.txt'
$selfhostManifest = Join-Path $root 'examples/regression/expected/1732-selfhost-character-literal-diagnostics.sources.txt'
$constantFixture = Join-Path $root 'examples/regression/1733-selfhost-character-constant-evaluation.slg'
$constantExpected = Join-Path $root 'examples/regression/expected/1733-selfhost-character-constant-evaluation.stdout.txt'
$constantManifest = Join-Path $root 'examples/regression/expected/1733-selfhost-character-constant-evaluation.sources.txt'
$selfhostGuidFixture = Join-Path $root 'examples/regression/1734-selfhost-guid-character-ranges.slg'
$selfhostGuidExpected = Join-Path $root 'examples/regression/expected/1734-selfhost-guid-character-ranges.stdout.txt'
$selfhostGuidManifest = Join-Path $root 'examples/regression/expected/1734-selfhost-guid-character-ranges.sources.txt'
$output = Join-Path $root ('artifacts/scratch/character-literals-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    scope = 'managed-selfhost-character-literals-and-stdlib-runtime-textual-bytes-and-control-shapes'
    status = 'running'
    completed = 0
    total = 14
    checks = @()
}

function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"))
}

function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}

function Invoke-Exact([string[]]$Sources, [string]$ExpectedPath, [string]$Name) {
    $exe = Join-Path $output "$Name.exe"
    $actual = (& dotnet $compiler run @Sources --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$Name execution failed: $actual" }
    $expected = [IO.File]::ReadAllText($ExpectedPath).Replace("`r`n", "`n").TrimEnd()
    if ($actual.Replace("`r`n", "`n").TrimEnd() -cne $expected) {
        throw "$Name exact output differs: $actual"
    }
}

try {
    $negativeNames = @(
        'character-literal-empty',
        'character-literal-multiple',
        'character-literal-escape',
        'character-literal-unterminated'
    )
    $required = @(
        $compiler,
        (Join-Path $llvm 'bin/clang.exe'),
        $positive,
        $positiveExpected,
        $selfhostFixture,
        $selfhostExpected,
        $selfhostManifest,
        $constantFixture,
        $constantExpected,
        $constantManifest,
        $selfhostGuidFixture,
        $selfhostGuidExpected,
        $selfhostGuidManifest,
        (Join-Path $root 'syntax/sollang.lexer'),
        (Join-Path $root 'syntax/sollang.grammar'),
        (Join-Path $root 'syntax/generated/sollang_grammar.slg'),
        (Join-Path $root 'src/Sollang.Compiler.Generators/LexerSourceGenerator.cs'),
        (Join-Path $root 'src/Sollang.Compiler.Generators/ParserSourceGenerator.cs'),
        (Join-Path $root 'selfhost/syntax/source.slg'),
        (Join-Path $root 'selfhost/syntax/lexer.slg'),
        (Join-Path $root 'selfhost/syntax/ast.slg'),
        (Join-Path $root 'selfhost/semantic/constant_expressions.slg'),
        (Join-Path $root 'selfhost/llvm/text/core_calls.slg'),
        (Join-Path $root 'selfhost/llvm/emitter/diagnostics.slg')
    )
    foreach ($name in $negativeNames) {
        $required += Join-Path $root "examples/regression/diagnostics/$name.slg"
        $required += Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt"
    }
    foreach ($path in $required) {
        if (-not (Test-Path -LiteralPath $path)) { throw "character literal input is missing: $path" }
    }
    $record.inputHashes = [ordered]@{}
    foreach ($path in $required | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }) {
        $record.inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    Save-Result

    $lexerContract = [IO.File]::ReadAllText((Join-Path $root 'syntax/sollang.lexer'))
    $grammarContract = [IO.File]::ReadAllText((Join-Path $root 'syntax/sollang.grammar'))
    $managedLexer = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler.Generators/LexerSourceGenerator.cs'))
    $managedParser = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler.Generators/ParserSourceGenerator.cs'))
    foreach ($requiredText in @(
        @{ Text = $lexerContract; Value = 'token Character = character_literal' },
        @{ Text = $grammarContract; Value = 'rule CharacterExpression = Character' },
        @{ Text = $managedLexer; Value = 'private void LexCharacter()' },
        @{ Text = $managedParser; Value = 'TokenKind.Character' }
    )) {
        if (-not $requiredText.Text.Contains($requiredText.Value, [StringComparison]::Ordinal)) {
            throw "character literal authority is missing: $($requiredText.Value)"
        }
    }
    Complete-Check 'managed-lexer-parser-authority'

    $selfhostFiles = @(
        'selfhost/syntax/source.slg',
        'selfhost/syntax/lexer.slg',
        'selfhost/syntax/ast.slg',
        'selfhost/semantic/constant_expressions.slg',
        'selfhost/llvm/text/core_calls.slg',
        'selfhost/llvm/emitter/diagnostics.slg'
    )
    foreach ($relative in $selfhostFiles) {
        $text = [IO.File]::ReadAllText((Join-Path $root $relative))
        if (-not $text.Contains('Character', [StringComparison]::Ordinal) -and
            -not $text.Contains('character', [StringComparison]::Ordinal)) {
            throw "selfhost character literal integration is missing: $relative"
        }
    }
    Complete-Check 'selfhost-lexer-ast-constant-and-llvm-authority'

    $stdlibSources = @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Filter '*.slg' -File -Recurse)
    if ($stdlibSources.Count -eq 0) { throw 'stdlib/runtime source inventory is empty' }
    $record.stdlibSourceHashes = [ordered]@{}
    foreach ($source in $stdlibSources | Sort-Object FullName) {
        $relative = [IO.Path]::GetRelativePath($root, $source.FullName).Replace('\\', '/')
        $record.stdlibSourceHashes[$relative] = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
    }
    $stdlibText = ($stdlibSources | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
    foreach ($forbidden in @(
        'suffix == 42',
        'byte >= 48 and byte <= 57',
        'left! + 32',
        'right! + 32',
        'leftByte! + 32',
        'rightByte! + 32',
        '[115, 111, 108, 108, 97, 110, 103, 45, 112, 101, 101, 114]',
        '[83, 80, 50, 80',
        '[UInt8(83), 80, 50, 83'
    )) {
        if ($stdlibText.Contains($forbidden, [StringComparison]::Ordinal)) {
            throw "stdlib/runtime retained a textual-byte numeric spelling: $forbidden"
        }
    }
    foreach ($binaryControl in @(
        @{ Path = 'stdlib/std/compress/zstd.slg'; Text = 'output -> push(47)' },
        @{ Path = 'stdlib/std/compress/brotli/literal_context.slg'; Text = '== 32 { 8 }' },
        @{ Path = 'stdlib/std/net/quic/x509_ed25519.slg'; Text = 'element.tag == 48' }
    )) {
        if (-not [IO.File]::ReadAllText((Join-Path $root $binaryControl.Path)).Contains($binaryControl.Text, [StringComparison]::Ordinal)) {
            throw "binary protocol/table numeric control drifted: $($binaryControl.Path)"
        }
    }
    if ($stdlibText -match '\belse\s*\{\s*\}') {
        throw 'stdlib/runtime retained an empty else body; express the fallback action or use the appropriate control shape'
    }
    $record.stdlibSourceCount = $stdlibSources.Count
    Complete-Check 'all-stdlib-runtime-textual-byte-scan-and-binary-controls'

    # A single subject with mutually exclusive outcomes uses one `when`.
    # Independent phase checks remain separate when a successful arm advances
    # state and deliberately allows the next phase to run in the same call.
    foreach ($control in @(
        @{ Path = 'stdlib/sys/path.slg'; Text = 'code -> when {' },
        @{ Path = 'stdlib/sys/directory.slg'; Text = 'code -> when {' },
        @{ Path = 'stdlib/sys/runtime/process.slg'; Text = 'self.completionState -> when {' },
        @{ Path = 'stdlib/sys/runtime/process.slg'; Text = 'polled.state -> when {' },
        @{ Path = 'stdlib/std/encoding/base64.slg'; Text = 'plan.valueLength -> when {' },
        @{ Path = 'stdlib/std/encoding/base64.slg'; Text = 'self.pendingLength -> when {' },
        @{ Path = 'stdlib/std/compress/zstd.slg'; Text = 'bytes -> when {' },
        @{ Path = 'stdlib/std/compress/brotli.slg'; Text = 'code -> when {' },
        @{ Path = 'stdlib/std/compress/gzip.slg'; Text = 'treeKind -> when {' },
        @{ Path = 'stdlib/std/compress/gzip.slg'; Text = 'blockType -> when {' },
        @{ Path = 'stdlib/std/compress/brotli/prefix_code.slg'; Text = 'low.value -> when {' },
        @{ Path = 'stdlib/std/crypto/field25519.slg'; Text = 'bitIndex -> when {' },
        @{ Path = 'stdlib/std/uri.slg'; Text = 'text -> byte(schemeScan!) => byte' + "`n" + '        byte -> when {' },
        @{ Path = 'stdlib/std/net/http.slg'; Text = 'source -> byte(index!) => byte' + "`n" + '        byte -> when {' },
        @{ Path = 'stdlib/std/text/json.slg'; Text = 'first -> when {' },
        @{ Path = 'stdlib/std/text/json.slg'; Text = 'state -> when {' },
        @{ Path = 'stdlib/std/text/regex.slg'; Text = 'suffix -> when {' }
    )) {
        $controlText = [IO.File]::ReadAllText((Join-Path $root $control.Path)).Replace("`r`n", "`n")
        if (-not $controlText.Contains($control.Text, [StringComparison]::Ordinal)) {
            throw "stdlib/runtime mutually exclusive control shape drifted: $($control.Path): $($control.Text)"
        }
    }
    foreach ($sequential in @(
        @{ Path = 'stdlib/std/compress/gzip.slg'; Text = 'decoder.dynamicPhase == 0 -> if {' },
        @{ Path = 'stdlib/std/compress/gzip.slg'; Text = 'decoder.dynamicPhase == 1 -> if {' },
        @{ Path = 'stdlib/std/compress/zstd/sequence.slg'; Text = 'mode == 3 -> if {' }
    )) {
        if (-not [IO.File]::ReadAllText((Join-Path $root $sequential.Path)).Contains($sequential.Text, [StringComparison]::Ordinal)) {
            throw "stdlib/runtime intentional sequential phase control drifted: $($sequential.Path)"
        }
    }
    Complete-Check 'all-stdlib-runtime-mutually-exclusive-and-sequential-control-shapes'

    $formatSources = @($stdlibSources.FullName) + @(
        $positive,
        $selfhostFixture,
        $constantFixture,
        (Join-Path $root 'selfhost/syntax/source.slg'),
        (Join-Path $root 'selfhost/syntax/lexer.slg'),
        (Join-Path $root 'selfhost/syntax/diagnostics.slg')
    )
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $formatSources
    Complete-Check 'authoritative-format'

    $generatedOne = Join-Path $output 'grammar-one.slg'
    $generatedTwo = Join-Path $output 'grammar-two.slg'
    foreach ($generated in @($generatedOne, $generatedTwo)) {
        & dotnet $compiler grammar build (Join-Path $root 'syntax/sollang.lexer') (Join-Path $root 'syntax/sollang.grammar') -o $generated
        if ($LASTEXITCODE -ne 0) { throw 'character grammar regeneration failed' }
    }
    $checkedInGrammar = Join-Path $root 'syntax/generated/sollang_grammar.slg'
    if ((Get-FileHash $generatedOne -Algorithm SHA256).Hash -cne (Get-FileHash $generatedTwo -Algorithm SHA256).Hash -or
        (Get-FileHash $generatedOne -Algorithm SHA256).Hash -cne (Get-FileHash $checkedInGrammar -Algorithm SHA256).Hash) {
        throw 'generated character grammar is stale or nondeterministic'
    }
    Complete-Check 'generated-grammar-determinism'

    Invoke-Exact -Sources @($positive) -ExpectedPath $positiveExpected -Name 'character-literals'
    Complete-Check 'managed-character-literal-exact-output'

    $selfhostSources = @(Get-Content -LiteralPath $selfhostManifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Join-Path $root $_ })
    Invoke-Exact -Sources $selfhostSources -ExpectedPath $selfhostExpected -Name 'selfhost-character-diagnostics'
    Complete-Check 'selfhost-lexer-parser-diagnostics-exact-output'

    $constantSources = @(Get-Content -LiteralPath $constantManifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Join-Path $root $_ })
    Invoke-Exact -Sources $constantSources -ExpectedPath $constantExpected -Name 'selfhost-character-constant-evaluation'
    Complete-Check 'selfhost-character-constant-evaluation-exact-output'

    $selfhostGuidSources = @(Get-Content -LiteralPath $selfhostGuidManifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Join-Path $root $_ })
    Invoke-Exact -Sources $selfhostGuidSources -ExpectedPath $selfhostGuidExpected -Name 'selfhost-guid-character-ranges'
    Complete-Check 'selfhost-guid-character-range-exact-output'

    foreach ($name in $negativeNames) {
        $source = Join-Path $root "examples/regression/diagnostics/$name.slg"
        $expectedText = [IO.File]::ReadAllText((Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt")).Trim()
        $failure = (& dotnet $compiler build $source --llvm $llvm -o (Join-Path $output "$name.exe") 2>&1) -join "`n"
        if ($LASTEXITCODE -eq 0 -or -not $failure.Contains($expectedText, [StringComparison]::Ordinal)) {
            throw "$name did not fail with its exact diagnostic: $failure"
        }
        Complete-Check "negative-$name"
    }

    $record.status = 'passed'
    Save-Result
    Write-Host "[character literals focused] PASS $($record.completed)/$($record.total), stdlib/runtime $($record.stdlibSourceCount) sources; $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
