[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $repo '.tools/llvm-22.1.8'
$output = Join-Path $repo ('artifacts/scratch/general-algorithms/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$contractPath = Join-Path $repo 'scripts/contracts/general-algorithms.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -ne 'caller-owned-growable-arrays-and-copyable-values' -or
    $contract.sort.stable -ne $false -or $contract.fixtures.Count -ne 3 -or $contract.negativeFixtures.Count -ne 3) {
    throw 'unexpected general algorithms contract'
}

# The reference uses .NET sorting and linear predicates, not the SLG heap or
# binary-search implementation. Fixture inputs are deliberately deterministic.
$values = [int[]]@(0..127 | ForEach-Object { ($_ * 73 + 19) % 101 - 50 })
[Array]::Sort($values)
$sort = @(($values -join ',') + ',')
[Array]::Reverse($values)
$sort += ($values -join ',') + ','
$sort += @('storage=128,129,129', 'reuse=129,999', 'empty=0', 'single=7')
$extremes = [int[]]@([int]::MaxValue, 0, [int]::MinValue, 0)
[Array]::Sort($extremes)
$sort += ($extremes -join ',') + ','
$pairs = [Tuple[int,int][]]@([Tuple]::Create(2,7), [Tuple]::Create(-1,9), [Tuple]::Create(2,3))
[Array]::Sort($pairs)
$sort += (@($pairs | ForEach-Object { '{0}:{1}' -f $_.Item1, $_.Item2 }) -join ',') + ','
$search = @()
$ordered = [int[]]@(-3,-1,-1,-1,2,4,4,9)
foreach ($direction in @('asc', 'desc')) {
    if ($direction -eq 'desc') { [Array]::Reverse($ordered) }
    foreach ($needle in -5..11) {
        $index = [Array]::FindIndex[int]($ordered, [Predicate[int]]{
            param($value)
            if ($direction -eq 'asc') { return $value -ge $needle }
            return $value -le $needle
        })
        if ($index -lt 0) { $index = $ordered.Length }
        $found = $index -lt $ordered.Length -and $ordered[$index] -eq $needle
        $search += ('{0}={1},{2},{3}' -f $direction, $needle, $index, $found.ToString().ToLowerInvariant())
    }
}
$search += @('empty=0,false', 'single=6,0,false', 'single=7,0,true', 'single=8,1,false')
$selection = @(
    [Math]::Min([int]::MinValue, [int]::MaxValue).ToString(),
    [Math]::Max([int]::MinValue, [int]::MaxValue).ToString(),
    [Math]::Max([int]::MinValue, [int]::MaxValue).ToString(),
    [Math]::Min([int]::MinValue, [int]::MaxValue).ToString(),
    'ties=1,1,1,2'
)
foreach ($direction in @('asc', 'desc')) {
    $cases = @(
        @{ value = -20; lower = -10; upper = 10 },
        @{ value = 0; lower = -10; upper = 10 },
        @{ value = 20; lower = -10; upper = 10 },
        @{ value = 99; lower = 7; upper = 7 },
        @{ value = [int]::MinValue; lower = [int]::MinValue; upper = [int]::MaxValue },
        @{ value = [int]::MaxValue; lower = [int]::MinValue; upper = [int]::MaxValue },
        @{ value = 0; lower = 10; upper = -10 }
    )
    foreach ($case in $cases) {
        $lower = $case.lower
        $upper = $case.upper
        if ($direction -eq 'desc') { $lower = $case.upper; $upper = $case.lower }
        $reversed = if ($direction -eq 'asc') { $lower -gt $upper } else { $lower -lt $upper }
        if ($reversed) {
            $selection += 'clamp=reversed'
        } else {
            $selection += 'clamp=' + [Math]::Clamp([int]$case.value, [Math]::Min($lower, $upper), [Math]::Max($lower, $upper))
        }
    }
}
$references = @{
    '1712-algorithm-in-place-ordering' = $sort -join "`n"
    '1713-algorithm-first-binary-search' = $search -join "`n"
    '1718-algorithm-min-max-clamp' = $selection -join "`n"
}

$compilerHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
$moduleHash = (Get-FileHash -LiteralPath (Join-Path $repo $contract.module) -Algorithm SHA256).Hash
$results = @()
foreach ($fixture in $contract.fixtures) {
    $sourcePath = Join-Path $repo "examples/regression/$fixture.slg"
    $expectationPath = Join-Path $repo "examples/regression/expected/$fixture.stdout.txt"
    $expected = (Get-Content -LiteralPath $expectationPath -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($expected -cne $references[$fixture]) { throw "$fixture expectation disagrees with independent .NET reference" }
    $executable = Join-Path $output "$fixture.exe"
    $actual = (& dotnet $compiler run $sourcePath --llvm $llvm -o $executable --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$fixture failed: $actual" }
    if ($actual.Replace("`r`n", "`n").TrimEnd() -cne $expected) { throw "$fixture output mismatch or warning: $actual" }
    $irPath = [IO.Path]::ChangeExtension($executable, '.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o ([IO.Path]::ChangeExtension($executable, '.bc'))
    if ($LASTEXITCODE -ne 0) { throw "$fixture LLVM assembly failed" }
    & (Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $irPath

    # The audit baseline retains every fixture allocation, data owner, output
    # and comparator declaration. Only the algorithm calls are removed. Compare
    # emitted allocation and bulk-copy sites, including non-inlined callees.
    $source = Get-Content -LiteralPath $sourcePath -Raw
    $sortPattern = '(?m)^(\s*)(?:ascending|descending) -> sort\(([^,\r\n]+),[^\r\n]+\)\r?$'
    $searchPattern = '(?m)^(\s*)(?:ascending|descending) -> binarySearch\(([^\r\n]+)\) => ([A-Za-z]+)\r?$'
    $selectionPattern = '(?m)^(\s*)(?:ascending|descending|ordering) -> (min|max|clamp)\(([^\r\n]+)\)'
    $removedSort = [regex]::Matches($source, $sortPattern).Count
    $removedSearch = [regex]::Matches($source, $searchPattern).Count
    $removedSelection = [regex]::Matches($source, $selectionPattern).Count
    if ($removedSort + $removedSearch + $removedSelection -eq 0) { throw "$fixture audit baseline removed no calls" }
    $baseline = [regex]::Replace($source, $sortPattern, '$1AlgorithmAuditBorrow { } -> retain($2)')
    $baseline = [regex]::Replace($baseline, $searchPattern, '$1AlgorithmAuditBorrow { } -> first($2) => $3')
    $baseline = [regex]::Replace($baseline, $selectionPattern, '$1AlgorithmAuditBorrow { } -> $2($3)')
    # Retain each mutable-borrow call boundary without a sort body, so the
    # baseline keeps the original storage declarations and remains warning-free.
    $auditBorrow = @'
struct AlgorithmAuditBorrow { }
impl AlgorithmAuditBorrow {
    retain<T>: self, values: mut [T; ~] -> Unit { }
    min<T, C>: self, left: T, right: T, comparison: C -> T where C: algorithm.Comparison, C.Item == T => left
    max<T, C>: self, left: T, right: T, comparison: C -> T where C: algorithm.Comparison, C.Item == T => left
    clamp<T, C>: self, value: T, lower: T, upper: T, comparison: C -> Result<T, algorithm.Error> where C: algorithm.Comparison, C.Item == T {
        Result<T, algorithm.Error>.Ok(value)
    }
    first<T, C>: self, values: [T; ~], needle: T, comparison: C -> algorithm.SearchResult where C: algorithm.Comparison, C.Item == T {
        false => found!
        values -> len > 0 -> if {
            comparison -> algorithm.Comparison.compare(values[0], needle) == 0 => found!
        }
        algorithm.SearchResult { index: 0, found: found! }
    }
}

main {
'@
    $baseline = [regex]::Replace($baseline, '(?m)^main \{', $auditBorrow)
    $baselineSource = Join-Path $output "$fixture-baseline.slg"
    [IO.File]::WriteAllText($baselineSource, $baseline)
    $baselineExecutable = Join-Path $output "$fixture-baseline.exe"
    $baselineLog = (& dotnet $compiler build $baselineSource --llvm $llvm -o $baselineExecutable --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $baselineLog -match '(?m)^(?:warning|note) ') { throw "$fixture baseline failed: $baselineLog" }
    $ir = Get-Content -LiteralPath $irPath -Raw
    $baselineIr = Get-Content -LiteralPath ([IO.Path]::ChangeExtension($baselineExecutable, '.ll')) -Raw
    $siteCounts = @{}
    foreach ($name in @('sollang_alloc', 'memcpy', 'memmove')) {
        $pattern = '(?m)^\s*.*\bcall\b[^\r\n]*@' + $name + '\('
        $count = [regex]::Matches($ir, $pattern).Count
        $baselineCount = [regex]::Matches($baselineIr, $pattern).Count
        if ($count -ne $baselineCount) { throw "$fixture added $name sites: active=$count baseline=$baselineCount" }
        $siteCounts[$name] = @{ active = $count; baseline = $baselineCount; delta = 0 }
    }
    $algorithmBodies = [regex]::Matches($ir, '(?ms)^define[^\r\n]*@(sollang_fn_std_algorithm_(?!Comparison_)[A-Za-z0-9_]+)[^\r\n]*\{.*?^\}')
    if ($algorithmBodies.Count -eq 0) { throw "$fixture emitted no independently inspectable algorithm helper bodies" }
    $helperNames = @($algorithmBodies | ForEach-Object { $_.Groups[1].Value })
    foreach ($body in $algorithmBodies) {
        if ($body.Value -match '\bcall\b[^\r\n]*@(sollang_alloc|memcpy|memmove)\(') {
            throw "$fixture algorithm body allocates or bulk-copies storage"
        }
    }
    $results += [ordered]@{
        fixture = $fixture
        status = 'passed'
        sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        expectationSha256 = (Get-FileHash -LiteralPath $expectationPath -Algorithm SHA256).Hash
        executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
        llvmSha256 = (Get-FileHash -LiteralPath $irPath -Algorithm SHA256).Hash
        removedSortCalls = $removedSort
        removedSearchCalls = $removedSearch
        removedSelectionCalls = $removedSelection
        inspectedLibraryHelperBodyCount = $algorithmBodies.Count
        inspectedLibraryHelperSymbols = $helperNames
        shapeEvidenceLimit = 'non-inlined library-owned bodies plus emitted-site delta; inline paths proven by focused behavior, callback costs excluded'
        emittedSiteCounts = $siteCounts
        independentlyComparedLines = ($expected -split "`n").Count
    }
}
foreach ($fixture in $contract.negativeFixtures) {
    $sourcePath = Join-Path $repo "examples/regression/diagnostics/$fixture.slg"
    $diagnostic = (Get-Content -LiteralPath (Join-Path $repo "examples/regression/diagnostics/$fixture.stderr.contains.txt") -Raw).Trim()
    $actual = (& dotnet $compiler build $sourcePath --llvm $llvm -o (Join-Path $output "$fixture.exe") 2>&1) -join "`n"
    if ($LASTEXITCODE -eq 0 -or -not $actual.Contains($diagnostic)) { throw "$fixture did not produce its required early diagnostic: $actual" }
    $results += [ordered]@{ fixture = $fixture; status = 'passed'; requiredDiagnostic = $diagnostic }
}
if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -ne $compilerHash -or
    (Get-FileHash -LiteralPath (Join-Path $repo $contract.module) -Algorithm SHA256).Hash -ne $moduleHash) {
    throw 'compiler or algorithm source changed during focused verification'
}
$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    completed = $results.Count
    total = $contract.fixtures.Count + $contract.negativeFixtures.Count
    scope = $contract.scope
    compilerSha256 = $compilerHash
    moduleSha256 = $moduleHash
    contractSha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash
    allocationEvidence = 'zero additional emitted allocation/bulk-copy sites against fixture baseline; owner/length/capacity reuse executed'
    selfhostExecution = 'pending-final-accumulated-compiler-verification'
    results = $results
}
$recordPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 8))
Write-Output "General algorithms focused PASS $($record.completed)/$($record.total): .NET reference, native execution, LLVM, storage reuse, nonempty helper-body audit, zero extra allocation/copy sites, three early negative controls."
Write-Output $recordPath
