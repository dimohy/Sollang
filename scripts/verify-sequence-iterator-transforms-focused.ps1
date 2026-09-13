[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$verifierPath = [IO.Path]::GetFullPath($PSCommandPath)
$contractPath = Join-Path $repo 'scripts/contracts/sequence-iterator-transforms.json'
$schemaPath = Join-Path $repo 'scripts/contracts/sequence-iterator-transforms.schema.json'
$compiler = Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $repo '.tools/llvm-22.1.8'
$output = Join-Path $repo ('artifacts/scratch/sequence-iterator-transforms/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force | Out-Null

function Normalize([string]$Value) { $Value.Replace("`r`n", "`n").TrimEnd() }
function Assert-ExactSet([object[]]$Actual, [string[]]$Expected, [string]$Name) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    if ($values.Count -ne $Expected.Count -or
        @($values | Sort-Object -Unique).Count -ne $Expected.Count -or
        @(Compare-Object ($Expected | Sort-Object) ($values | Sort-Object)).Count -ne 0) {
        throw "$Name must retain the exact unique authority set"
    }
}
function Get-StartBody([string]$Ir, [string]$Name) {
    $match = [regex]::Match($Ir, '(?ms)^define[^\r\n]*@sollang_start\([^\r\n]*\)[^\r\n]*\{.*?^\}')
    if (-not $match.Success) { throw "$Name has no inspectable sollang_start body" }
    $match.Value
}
function Count-Calls([string]$Body, [string]$Callee) {
    [regex]::Matches($Body, '(?m)^\s*.*\bcall\b[^\r\n]*@' + [regex]::Escape($Callee) + '\(').Count
}

$contractJson = Get-Content -LiteralPath $contractPath -Raw
if (-not ($contractJson | Test-Json -SchemaFile $schemaPath)) { throw 'iterator transforms contract schema validation failed' }
$contract = $contractJson | ConvertFrom-Json
$requiredMethods = @('map', 'mapArray', 'filter', 'tap', 'take', 'skip', 'scan', 'beforeEach', 'afterEach', 'flatMap')
$requiredCases = @(
    'source-contract', 'composition', 'lazy-billion-early-stop', 'nested-state-early-stop',
    'scan-state', 'first-class-stream', 'function-boundary', 'typed-callback-matrix',
    'zip-shortest', 'latest-policy', 'concurrent-merge-cancellation', 'concurrent-latest-cancellation'
)
Assert-ExactSet $contract.methods $requiredMethods 'iterator transform methods'
Assert-ExactSet @($contract.cases | ForEach-Object id) $requiredCases 'focused cases'

$caseSources = @{
    'source-contract' = @('stdlib/std/sequence.slg')
    'composition' = @('scripts/probes/sequence-iterator-transforms/composition.slg')
    'lazy-billion-early-stop' = @('examples/regression/582-billion-sensor-alerts.slg')
    'nested-state-early-stop' = @('examples/regression/583-stream-state-take-skip.slg')
    'scan-state' = @('examples/regression/585-stream-transaction-risk-scan.slg')
    'first-class-stream' = @('examples/regression/586-first-class-stream.slg')
    'function-boundary' = @('examples/regression/587-stream-library-boundary.slg')
    'typed-callback-matrix' = @(
        'examples/regression/1602-stream-mapped-text-flatmap-input.slg',
        'examples/regression/1605-stream-mapped-bool-flatmap-input.slg',
        'examples/regression/1606-stream-mapped-uint64-flatmap-input.slg',
        'examples/regression/1607-stream-bool-map-filter-input.slg'
    )
    'zip-shortest' = @('examples/regression/798-zip-shortest-stream.slg')
    'latest-policy' = @('examples/regression/801-concat-and-latest-policies.slg')
    'concurrent-merge-cancellation' = @('examples/regression/813-concurrent-merge-early-cancellation.slg')
    'concurrent-latest-cancellation' = @('examples/regression/814-concurrent-latest-early-cancellation.slg')
}
foreach ($case in $contract.cases) {
    Assert-ExactSet $case.sources $caseSources[$case.id] "sources for $($case.id)"
}

$sequencePath = Join-Path $repo $contract.module
$sequenceSource = Get-Content -LiteralPath $sequencePath -Raw
foreach ($method in $requiredMethods) {
    $count = [regex]::Matches($sequenceSource, '(?m)^public\s+' + [regex]::Escape($method) + '(?:<[^\r\n]+?>)?\s').Count
    if ($count -ne 1) { throw "std.sequence must define public $method exactly once" }
}
if ($sequenceSource -match '(?m)->\s*(?:push|reserve)\s*\(' -or
    $sequenceSource -match '\[[^\r\n;]+;\s*~\]\s*=>') {
    throw 'std.sequence adapters must not build or grow an element collection'
}
if ($sequenceSource -cnotmatch '(?s)public take<.*?\bstop\b' -or
    $sequenceSource -cnotmatch '(?s)public skip<.*?=> state skipped!' -or
    $sequenceSource -cnotmatch '(?s)public scan<.*?=> state current!') {
    throw 'take/skip/scan control-state contract drifted'
}

$allSources = @($caseSources.Values | ForEach-Object { $_ } | Sort-Object -Unique)
$formatSources = @(
    $sequencePath,
    (Join-Path $repo 'scripts/probes/sequence-iterator-transforms/composition.slg')
)
& (Join-Path $repo 'scripts/format-authoritative-slg.ps1') -Check -Source $formatSources
if ($LASTEXITCODE -ne 0) { throw 'iterator transforms authoritative format check failed' }

$expectations = @{
    'scripts/probes/sequence-iterator-transforms/composition.slg' = 'scripts/probes/sequence-iterator-transforms/composition.stdout.txt'
}
foreach ($source in $allSources) {
    if ($source -eq $contract.module) { continue }
    if (-not $expectations.ContainsKey($source)) {
        $stem = [IO.Path]::GetFileNameWithoutExtension($source)
        $expectations[$source] = "examples/regression/expected/$stem.stdout.txt"
    }
}

$sourceHashes = [ordered]@{}
$runs = @()
$irBySource = @{}
foreach ($source in $allSources) {
    $sourcePath = Join-Path $repo $source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "missing source: $source" }
    $sourceHashes[$source] = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    if ($source -eq $contract.module) { continue }
    $expectedPath = Join-Path $repo $expectations[$source]
    if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) { throw "missing exact output: $($expectations[$source])" }
    $sourceHashes[$expectations[$source]] = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
    $expected = Normalize (Get-Content -LiteralPath $expectedPath -Raw)
    $name = [IO.Path]::GetFileNameWithoutExtension($source)
    $executable = Join-Path $output "$name.exe"
    $actual = (& dotnet $compiler run $sourcePath --llvm $llvm -o $executable --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$source failed: $actual" }
    if ((Normalize $actual) -cne $expected) { throw "$source output mismatch, warning, or note: $actual" }
    $irPath = [IO.Path]::ChangeExtension($executable, '.ll')
    $bcPath = [IO.Path]::ChangeExtension($executable, '.bc')
    $assemblyOutput = (& (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o $bcPath 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($assemblyOutput)) {
        throw "$source LLVM assembly failed or produced diagnostics: $assemblyOutput"
    }
    & (Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $irPath
    $ir = Get-Content -LiteralPath $irPath -Raw
    $start = Get-StartBody $ir $source
    foreach ($callee in @('sollang_realloc', 'memcpy', 'memmove')) {
        if ((Count-Calls $start $callee) -ne 0) { throw "$source materializes or bulk-copies elements in sollang_start via $callee" }
    }
    $irBySource[$source] = @{ ir = $ir; start = $start }
    $runs += [ordered]@{
        source = $source
        status = 'passed'
        stdoutSha256 = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
        llvmAs = 'passed'
        v004 = 'passed'
        startAllocCalls = Count-Calls $start 'sollang_alloc'
        startReallocCalls = Count-Calls $start 'sollang_realloc'
        startMemcpyCalls = Count-Calls $start 'memcpy'
        startMemmoveCalls = Count-Calls $start 'memmove'
    }
}

$composition = $irBySource['scripts/probes/sequence-iterator-transforms/composition.slg']
if ((Count-Calls $composition.start 'sollang_alloc') -ne 1) {
    throw 'composition must emit exactly one allocation for its one explicit growable-array literal'
}
$localNoCollectionSources = @(
    'examples/regression/582-billion-sensor-alerts.slg',
    'examples/regression/583-stream-state-take-skip.slg',
    'examples/regression/585-stream-transaction-risk-scan.slg',
    'examples/regression/1602-stream-mapped-text-flatmap-input.slg',
    'examples/regression/1605-stream-mapped-bool-flatmap-input.slg',
    'examples/regression/1606-stream-mapped-uint64-flatmap-input.slg',
    'examples/regression/1607-stream-bool-map-filter-input.slg'
)
foreach ($source in $localNoCollectionSources) {
    if ((Count-Calls $irBySource[$source].start 'sollang_alloc') -ne 0) {
        throw "$source unexpectedly allocates in its fused local pipeline"
    }
}
$typedSources = @($caseSources['typed-callback-matrix']) + @('scripts/probes/sequence-iterator-transforms/composition.slg')
foreach ($source in $typedSources) {
    if ($irBySource[$source].start -match '(?m)^\s*(?:%[^=]+?=\s*)?call\b[^@\r\n]*%[A-Za-z0-9_.]+\(') {
        throw "$source contains indirect callback dispatch in sollang_start"
    }
}

$caseResults = @()
foreach ($case in $contract.cases) {
    $caseResults += [ordered]@{ id = $case.id; status = 'passed'; sources = @($case.sources); proves = @($case.proves) }
}
$result = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    completed = $caseResults.Count
    total = $contract.cases.Count
    compilerSha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
    moduleSha256 = (Get-FileHash -LiteralPath $sequencePath -Algorithm SHA256).Hash
    contractSha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash
    schemaSha256 = (Get-FileHash -LiteralPath $schemaPath -Algorithm SHA256).Hash
    verifierSha256 = (Get-FileHash -LiteralPath $verifierPath -Algorithm SHA256).Hash
    sourceHashes = $sourceHashes
    cases = $caseResults
    runs = $runs
    failureIds = @()
    acceptance = $contract.acceptance
    unresolved = @($contract.unresolved)
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 12))
Write-Host "[sequence iterator transforms] PASS $($caseResults.Count)/$($contract.cases.Count)"
Write-Host "[sequence iterator transforms] result=$resultPath"
