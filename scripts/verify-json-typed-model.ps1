[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/json-typed-model.json'
$module = Join-Path $root 'stdlib/std/text/json.slg'
$fixture = Join-Path $root 'scripts/probes/json-typed-model/model-mapping.slg'
$expectedPath = Join-Path $root 'scripts/probes/json-typed-model/model-mapping.stdout.txt'
$writerFixture = Join-Path $root 'scripts/probes/json-typed-model/model-writing.slg'
$writerExpectedPath = Join-Path $root 'scripts/probes/json-typed-model/model-writing.stdout.txt'
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$formatter = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$output = Join-Path $root ('artifacts/scratch/json-typed-model-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{ schemaVersion = 1; status = 'running'; completed = 0; total = 5; checks = @(); failureIds = @(); selfhost = 'pending-stable-candidate' }

function Write-Record {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Write-Record
}

function Read-CanonicalExpected([string]$Path) {
    [byte[]]$bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        throw "JSON expected output must be BOM-free UTF-8: $Path"
    }
    $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    if ($text.Contains("`r", [StringComparison]::Ordinal) -or -not $text.EndsWith("`n", [StringComparison]::Ordinal) -or
        $text.EndsWith("`n`n", [StringComparison]::Ordinal)) {
        throw "JSON expected output must use LF and exactly one terminal newline: $Path"
    }
    $text.Substring(0, $text.Length - 1)
}

function Normalize-ActualOutput([string]$Text) {
    $Text.Replace("`r`n", "`n")
}

$expectedContract = [ordered]@{
    schemaVersion = 4
    scope = 'owned-flat-json-model-and-lossless-number-lexemes'
    module = 'stdlib/std/text/json.slg'
    fixture = 'scripts/probes/json-typed-model/model-mapping.slg'
    expected = 'scripts/probes/json-typed-model/model-mapping.stdout.txt'
    writerFixture = 'scripts/probes/json-typed-model/model-writing.slg'
    writerExpected = 'scripts/probes/json-typed-model/model-writing.stdout.txt'
    typedModel = [ordered]@{
        storage = 'flat-value-arena-with-indexed-array-items-and-object-members'
        userDefinedMapping = 'not-provided; this is an owned typed JSON value model, not schema-driven mapping into caller structs or enums'
        variants = @('Null', 'Boolean', 'Number', 'String', 'Array', 'Object')
        strings = 'decoded-owned-utf8-bytes'
        publicTokenAuthentication = 'source span, quote, content span, decoded length, UTF-8, escapes, and surrogate pairs are revalidated before reserve or decode'
        objectNames = 'decoded-owned-utf8-bytes'
        objectOrder = 'source-order-preserved'
        duplicateNames = 'preserved'
    }
    genericWriter = [ordered]@{
        entrypoint = 'Writer.document(ref Document)'
        validationOrder = 'root/index, canonical payload, exact number, UTF-8, depth, output size, and exactly-once arena reachability before first output mutation'
        graphPolicy = 'one rooted tree; cycles, aliases/revisits, and disconnected values are rejected'
        transactionality = 'validation failure preserves writer bytes and structural state'
        objectOrder = 'source order and duplicate names preserved'
        numberOutput = 'owned exact RFC 8259 UTF-8 lexeme preserved byte-for-byte'
    }
    capabilities = [ordered]@{
        implemented = @(
            'bounded token reader',
            'transactional token writer',
            'owned generic JSON value tree reader',
            'validated transactional generic JSON value tree writer',
            'lossless RFC 8259 number lexemes',
            'exact int64 and uint64 opt-in conversions'
        )
        pending = @(
            'schema-driven mapping into user structs and enums',
            'Float32 and Float64 conversion policy and APIs',
            'fixed-decimal type, scale, rounding, overflow policy and APIs'
        )
    }
    numbers = [ordered]@{
        modelRepresentation = 'owned-exact-rfc8259-utf8-lexeme'
        int64 = 'explicit-exact-range-checked-integer-lexeme-only'
        uint64 = 'explicit-exact-range-checked-nonnegative-integer-lexeme-only'
        float32 = 'not-provided-without-explicit-rounding-overflow-and-negative-zero-policy'
        float64 = 'not-provided-without-explicit-rounding-overflow-and-negative-zero-policy'
        decimal = 'lossless-lexeme-is-authoritative-no-implicit-scale-or-rounding'
        nonFinite = 'rejected-by-rfc8259-lexer'
    }
    existingFixtureAssessment = @(
        [ordered]@{ fixture = 1036; covers = 'strict-token-reader'; typedModel = $false; floatingDecimalPolicy = $false },
        [ordered]@{ fixture = 1041; covers = 'transactional-token-writer'; typedModel = $false; floatingDecimalPolicy = 'raw-syntax-only' },
        [ordered]@{ fixture = 1707; covers = 'exact-int64-uint64-conversion'; typedModel = $false; floatingDecimalPolicy = 'rejects-noninteger-conversion' },
        [ordered]@{ fixture = 1710; covers = 'boolean-null-token-authenticity'; typedModel = $false; floatingDecimalPolicy = $false },
        [ordered]@{ fixture = 1714; covers = 'bounded-skip-without-materialization'; typedModel = $false; floatingDecimalPolicy = $false }
    )
    targetMatrix = [ordered]@{
        targets = @('windows-x64', 'linux-x64', 'wasm32-browser')
        sameExactOutput = $true
        browserAllowedImports = @(
            'env:sollang_browser_alloc',
            'env:sollang_browser_realloc',
            'env:memset',
            'env:memcpy',
            'env:sollang_browser_write',
            'env:sollang_browser_panic'
        )
    }
}

try {
    $inputs = @($contractPath, $module, $fixture, $expectedPath, $writerFixture, $writerExpectedPath, $compiler, $formatter, $closure, $PSCommandPath)
    $distinctInputs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $hashes = [ordered]@{}
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "JSON typed-model input missing: $path" }
        if (-not $distinctInputs.Add([IO.Path]::GetFullPath($path))) { throw "JSON typed-model duplicate input identity: $path" }
        $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    $record.inputHashes = $hashes
    if ($hashes[$fixture] -cne '3A6A4BE5000DBB28DF867D1274DDA37470B9AA191EEAF02EE438DA42F8B38516') {
        throw 'JSON typed-model probe source differs from the independent executable contract'
    }
    if ($hashes[$writerFixture] -cne 'A21A9941CB6B4F4ED43A106C16C584B0F2CEF08EF1711DBA0A69954FE0FC8CD2' -or
        $hashes[$writerExpectedPath] -cne '3ACE53374C0BEC5900D29797A4DBA58A39D0AC51DF2F706B5E3041C648DFC978') {
        throw 'JSON model-writer source/expected tuple differs from the independent executable contract'
    }
    $record.capabilityBoundary = 'owned-json-value-arena-reader-writer only; user-defined schema/model mapping is not implemented'
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $actualContract = $contract | ConvertTo-Json -Depth 8 -Compress
    $canonicalExpected = $expectedContract | ConvertTo-Json -Depth 8 -Compress
    if ($actualContract -cne $canonicalExpected) { throw 'JSON typed-model contract differs from the independent authoritative matrix' }
    $reference = @(
        'root=object',
        'values=8,members=4',
        'name=4,6,83,145',
        'items=3,bool=true,number=8,45,46,101,50',
        'duplicates=3,49,3,50',
        'reader=65,14',
        'forged-span=1',
        'forged-metadata=1'
    ) -join "`n"
    $publishedExpected = Read-CanonicalExpected $expectedPath
    if ($publishedExpected -cne $reference) { throw 'JSON typed-model expected output differs from the independent UTF-8/arena reference' }
    if ((Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash -cne 'F8C1FA011BB9F308F38DAA6AB3D7AD57A6311A40F8F4DB2006F6ED5B65FAF4AE') {
        throw 'JSON typed-model expected output byte hash differs from the independent reference'
    }
    Read-CanonicalExpected $writerExpectedPath | Out-Null
    Complete-Check 'exact-contract-matrix'

    $source = Get-Content -LiteralPath $module -Raw
    foreach ($required in @(
        'public enum ValueKind', 'public struct Member', 'public struct Value', 'public struct Document',
        'public document: mut self -> Result<Document, Error>', 'public document: mut self, value: ref Document -> Result<Unit, Error>',
        'validateModelValue', 'appendEncodedModelValue', 'ownedNumberBytes', 'errors.Kind.InvalidModel',
        'not silently round them to Float32/Float64', 'negative-zero policy',
        'scanString(token.start, tokenEnd', 'token.decodedLength == authenticated.decodedLength')) {
        if (-not $source.Contains($required, [StringComparison]::Ordinal)) { throw "JSON typed-model source contract missing: $required" }
    }
    foreach ($shape in @(
        '(?ms)public enum ValueKind \{\s*Null\s*Boolean\s*Number\s*String\s*Array\s*Object\s*\}',
        '(?ms)public struct Member \{\s*public name: \[UInt8; ~\]\s*public value: Int\s*\}',
        '(?ms)public struct Value \{\s*public kind: ValueKind\s*public boolean: Bool\s*public bytes: \[UInt8; ~\]\s*public items: \[Int; ~\]\s*public members: \[Member; ~\]\s*\}',
        '(?ms)public struct Document \{\s*public values: \[Value; ~\]\s*public root: Int\s*\}'
    )) {
        if ($source -cnotmatch $shape) { throw "JSON typed-model source layout differs from the independent structural contract: $shape" }
    }
    if ($source -cmatch '(?m)^\s*public\s+(float32|float64|decimal)\b') {
        throw 'JSON source exposes an uncontracted floating or decimal conversion API'
    }
    Complete-Check 'source-surface-and-number-policy'

    & $formatter -Check -Source @($module, $fixture, $writerFixture)
    if ($LASTEXITCODE -ne 0) { throw 'JSON typed-model authoritative format failed' }
    Complete-Check 'authoritative-format'

    $exe = Join-Path $output 'json-typed-model.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'managed.log'), $actual + "`n")
    $expected = $publishedExpected
    if ($exitCode -ne 0 -or (Normalize-ActualOutput $actual) -cne $expected) {
        throw "JSON typed-model managed exact execution failed or emitted diagnostics: $actual"
    }
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    Complete-Check 'managed-native-exact'

    $ir = [IO.Path]::ChangeExtension($exe, '.ll')
    $bc = [IO.Path]::ChangeExtension($exe, '.bc')
    & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o $bc
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $bc -PathType Leaf)) { throw 'JSON typed-model LLVM assembly failed' }
    & $closure -LlvmPath $ir
    if ($LASTEXITCODE -ne 0) { throw 'JSON typed-model direct-call closure failed' }
    $record.llvmSha256 = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
    Complete-Check 'llvm-assembly-and-direct-call-closure'

    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { throw "JSON typed-model input changed during verification: $path" }
    }
    $record.inputsStable = $true
    if ($record.completed -ne $record.total) { throw 'JSON typed-model verifier denominator drifted' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @('JSON_TYPED_MODEL_FAILED')
    $record.failure = $_.Exception.Message
    throw
} finally {
    Write-Record
}
Write-Host "[JSON typed model] PASS $($record.completed)/$($record.total); $resultPath"
