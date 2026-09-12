[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$verifierPath = [IO.Path]::GetFullPath($PSCommandPath)
$compiler = Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $repo '.tools/llvm-22.1.8'
$output = Join-Path $repo ('artifacts/scratch/general-algorithms/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$contractPath = Join-Path $repo 'scripts/contracts/general-algorithms.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$requiredFixtures = @(
    '1712-algorithm-in-place-ordering',
    '1713-algorithm-first-binary-search',
    '1718-algorithm-min-max-clamp'
)
$requiredNegativeFixtures = @(
    'algorithm-ordering-owned-negative',
    'algorithm-comparison-item-negative',
    'algorithm-selection-owned-negative'
)
$requiredReadonlyMethods = @('isSorted', 'lowerBound', 'upperBound', 'equalRange', 'binarySearchRef')
$requiredRemainingSequence = @('stableSort', 'partition', 'merge', 'iteratorTransforms')
$requiredUnresolved = @(
    'stable selfhost candidate validation of generic readonly slice and explicit reference specialization',
    'move-safe noncopyable indexed permutation primitive',
    'stable sorting, partitioning, merging, and iterator-style transform coverage',
    'Windows/Linux/browser and final fixed-point closure'
)
$requiredPendingProbes = @(
    'scripts/probes/general-algorithms/generic-readonly-slice.slg',
    'scripts/probes/general-algorithms/generic-explicit-reference.slg'
)
function Assert-ExactSet([object[]]$Actual, [string[]]$Expected, [string]$Name) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    if ($values.Count -ne $Expected.Count -or
        @($values | Sort-Object -Unique).Count -ne $Expected.Count -or
        @(Compare-Object ($Expected | Sort-Object) ($values | Sort-Object)).Count -ne 0) {
        throw "$Name must retain the exact unique authority set"
    }
}
if ($contract.schemaVersion -ne 2 -or $contract.scope -ne 'caller-owned-growable-arrays-copyable-selection-and-readonly-generic-sequences' -or
    $contract.module -cne 'stdlib/std/algorithm.slg' -or
    $contract.sort.stable -ne $false -or $contract.fixtures.Count -ne 3 -or
    $contract.negativeFixtures.Count -ne 3 -or $contract.managedProbes.Count -ne 3 -or
    $contract.readonlySequence.methods.Count -ne 5 -or
    $contract.noncopyablePermutation.status -cne 'blocked-on-general-collection-primitive' -or
    $contract.noncopyablePermutation.existingNegativeEvidence -cne 'algorithm-ordering-owned-negative' -or
    @($contract.remainingSequence.PSObject.Properties).Count -ne 4) {
    throw 'unexpected general algorithms contract'
}
Assert-ExactSet $contract.fixtures $requiredFixtures 'reference fixtures'
Assert-ExactSet $contract.negativeFixtures $requiredNegativeFixtures 'negative fixtures'
Assert-ExactSet $contract.readonlySequence.methods $requiredReadonlyMethods 'readonly sequence methods'
Assert-ExactSet @($contract.remainingSequence.PSObject.Properties.Name) $requiredRemainingSequence 'remaining sequence backlog'
Assert-ExactSet $contract.unresolved $requiredUnresolved 'unresolved work'
Assert-ExactSet $contract.selfhostPendingProbes $requiredPendingProbes 'selfhost pending probes'
foreach ($remaining in $contract.remainingSequence.PSObject.Properties) {
    if ([string]$remaining.Value -cnotmatch '^(?:unimplemented|blocked)\b') {
        throw "remaining sequence item must stay explicitly unimplemented or blocked: $($remaining.Name)"
    }
}
if ($contract.acceptance -cne 'managed Windows focused slice plus managed generic readonly/ref/owned-sequence probes only; selfhost and platform closure pending') {
    throw 'general algorithms acceptance must not overstate selfhost or platform closure'
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
$contractHash = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash
$verifierHash = (Get-FileHash -LiteralPath $verifierPath -Algorithm SHA256).Hash
$probeAuthority = @{
    'generic-readonly-slice' = @{ source = 'scripts/probes/general-algorithms/generic-readonly-slice.slg'; stdout = '2' }
    'generic-explicit-reference' = @{ source = 'scripts/probes/general-algorithms/generic-explicit-reference.slg'; stdout = '1' }
    'readonly-sequence' = @{ source = 'scripts/probes/general-algorithms/readonly-sequence.slg'; stdout = "true`nfalse`nsearch=1,true`nlower=1`nupper=3`nrange=1,3`nreuse=1,3" }
}
Assert-ExactSet @($contract.managedProbes | ForEach-Object id) @($probeAuthority.Keys) 'managed probes'
$probeHashes = @{}
foreach ($probe in $contract.managedProbes) {
    if (-not $probeAuthority.ContainsKey($probe.id) -or
        $probe.source -cne $probeAuthority[$probe.id].source -or
        $probe.stdout -cne $probeAuthority[$probe.id].stdout) {
        throw "managed probe contract drifted from verifier authority: $($probe.id)"
    }
    $probePath = Join-Path $repo $probe.source
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) { throw "managed probe source is missing: $($probe.source)" }
    $probeHashes[$probePath] = (Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash
}
$results = @()
foreach ($fixture in $contract.fixtures) {
    $sourcePath = Join-Path $repo "examples/regression/$fixture.slg"
    $expectationPath = Join-Path $repo "examples/regression/expected/$fixture.stdout.txt"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $expectationPath -PathType Leaf)) {
        throw "$fixture source or exact-output authority is missing"
    }
    $probeHashes[$sourcePath] = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $probeHashes[$expectationPath] = (Get-FileHash -LiteralPath $expectationPath -Algorithm SHA256).Hash
    $expected = (Get-Content -LiteralPath $expectationPath -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($expected -cne $references[$fixture]) { throw "$fixture expectation disagrees with independent .NET reference" }
    $executable = Join-Path $output "$fixture.exe"
    $actual = (& dotnet $compiler run $sourcePath --llvm $llvm -o $executable --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$fixture failed: $actual" }
    if ($actual.Replace("`r`n", "`n").TrimEnd() -cne $expected) { throw "$fixture output mismatch or warning: $actual" }
    $irPath = [IO.Path]::ChangeExtension($executable, '.ll')
    $assemblyOutput = (& (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o ([IO.Path]::ChangeExtension($executable, '.bc')) 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($assemblyOutput)) {
        throw "$fixture LLVM assembly failed or produced diagnostics: $assemblyOutput"
    }
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
    $diagnosticPath = Join-Path $repo "examples/regression/diagnostics/$fixture.stderr.contains.txt"
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $diagnosticPath -PathType Leaf)) {
        throw "$fixture source or diagnostic authority is missing"
    }
    $probeHashes[$sourcePath] = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $probeHashes[$diagnosticPath] = (Get-FileHash -LiteralPath $diagnosticPath -Algorithm SHA256).Hash
    $diagnostic = (Get-Content -LiteralPath $diagnosticPath -Raw).Trim()
    $negativeExecutable = Join-Path $output "$fixture.exe"
    $negativeLlvm = [IO.Path]::ChangeExtension($negativeExecutable, '.ll')
    $negativeBitcode = [IO.Path]::ChangeExtension($negativeExecutable, '.bc')
    $actual = (& dotnet $compiler build $sourcePath --llvm $llvm -o $negativeExecutable 2>&1) -join "`n"
    $actualLines = @($actual.Replace("`r`n", "`n") -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $emittedLlvm = $actual -match '(?m)^(?:source_filename|target triple|target datalayout|define\s)'
    if ($LASTEXITCODE -eq 0 -or $actualLines.Count -ne 1 -or
        -not $actualLines[0].Contains($diagnostic, [StringComparison]::Ordinal) -or
        $actual -match '(?im)\bwarning\b|Unhandled exception|Stack trace' -or $emittedLlvm -or
        (Test-Path -LiteralPath $negativeExecutable) -or
        (Test-Path -LiteralPath $negativeLlvm) -or
        (Test-Path -LiteralPath $negativeBitcode)) {
        throw "$fixture did not produce one exact-class early diagnostic without LLVM artifacts: $actual"
    }
    $results += [ordered]@{ fixture = $fixture; status = 'passed'; requiredDiagnostic = $diagnostic }
}

foreach ($probe in $contract.managedProbes) {
    $sourcePath = Join-Path $repo $probe.source
    $executable = Join-Path $output ($probe.id + '.exe')
    $actual = (& dotnet $compiler run $sourcePath --llvm $llvm -o $executable --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$($probe.id) failed: $actual" }
    $normalized = $actual.Replace("`r`n", "`n").TrimEnd()
    if ($normalized -cne $probeAuthority[$probe.id].stdout) { throw "$($probe.id) output mismatch or warning: $actual" }
    $irPath = [IO.Path]::ChangeExtension($executable, '.ll')
    $assemblyOutput = (& (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o ([IO.Path]::ChangeExtension($executable, '.bc')) 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($assemblyOutput)) {
        throw "$($probe.id) LLVM assembly produced a failure or diagnostic: $assemblyOutput"
    }
    $closureOutput = (& (Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $irPath 6>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$($probe.id) direct-call closure failed: $closureOutput" }
    if ($probe.id -eq 'readonly-sequence') {
        $ir = Get-Content -LiteralPath $irPath -Raw
        # equalRange is a source-level composition that may inline completely;
        # its exact [start,end) behavior is covered by the executed range line.
        foreach ($method in @('isSorted', 'lowerBound', 'upperBound', 'binarySearchRef')) {
            if ($ir -notmatch ('std\.algorithm\.Ordering\.' + $method + '\$')) {
                throw "readonly sequence LLVM lost the specialized $method path"
            }
        }
        $sequenceBodies = [regex]::Matches($ir, '(?ms)^define[^\r\n]*@(sollang_fn_std_algorithm_Ordering_(?:isSorted|lowerBound|upperBound|equalRange|binarySearchRef)[A-Za-z0-9_]*)[^\r\n]*\{.*?^\}')
        if ($sequenceBodies.Count -eq 0) { throw 'readonly sequence emitted no independently inspectable algorithm body' }
        foreach ($body in $sequenceBodies) {
            if ($body.Value -match '\bcall\b[^\r\n]*@(sollang_alloc|memcpy|memmove)\(') {
                throw "readonly sequence helper allocates or bulk-copies storage: $($body.Groups[1].Value)"
            }
        }
        $algorithmSource = Get-Content -LiteralPath (Join-Path $repo $contract.module) -Raw
        foreach ($method in @('lowerBound', 'upperBound', 'equalRange', 'isSorted', 'binarySearchRef')) {
            $methodBody = [regex]::Match($algorithmSource, '(?ms)^    public ' + $method + '<.*?^    \}').Value
            if ([string]::IsNullOrWhiteSpace($methodBody) -or $methodBody -match '->\s*(?:push|take)\(' -or $methodBody -match '->\s*exchange\(') {
                throw "readonly sequence $method structural no-mutation contract drifted"
            }
        }
    }
    $results += [ordered]@{
        fixture = $probe.id
        source = $probe.source
        status = 'passed'
        stdout = $normalized
        sourceSha256 = $probeHashes[$sourcePath]
        llvmSha256 = (Get-FileHash -LiteralPath $irPath -Algorithm SHA256).Hash
        executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
        assembly = 'passed'
        directCallClosure = 'passed'
        selfhost = 'pending-stable-candidate'
    }
}
if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -ne $compilerHash -or
    (Get-FileHash -LiteralPath (Join-Path $repo $contract.module) -Algorithm SHA256).Hash -ne $moduleHash -or
    (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash -ne $contractHash -or
    (Get-FileHash -LiteralPath $verifierPath -Algorithm SHA256).Hash -ne $verifierHash) {
    throw 'compiler, algorithm source, contract, or verifier changed during focused verification'
}
foreach ($probePath in $probeHashes.Keys) {
    if ((Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash -ne $probeHashes[$probePath]) {
        throw "managed probe changed during focused verification: $probePath"
    }
}
$inputHashes = [ordered]@{
    compiler = $compilerHash
    module = $moduleHash
    contract = $contractHash
    verifier = $verifierHash
}
foreach ($probePath in @($probeHashes.Keys | Sort-Object)) {
    $relativePath = [IO.Path]::GetRelativePath($repo, $probePath).Replace('\', '/')
    $inputHashes[$relativePath] = $probeHashes[$probePath]
}
$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    completed = $results.Count
    total = $contract.fixtures.Count + $contract.negativeFixtures.Count + $contract.managedProbes.Count
    failureIds = @()
    scope = $contract.scope
    compilerSha256 = $compilerHash
    moduleSha256 = $moduleHash
    contractSha256 = $contractHash
    verifierSha256 = $verifierHash
    inputHashes = $inputHashes
    allocationEvidence = 'zero additional emitted allocation/bulk-copy sites against fixture baseline; owner/length/capacity reuse executed'
    selfhostExecution = 'pending-final-accumulated-compiler-verification'
    results = $results
}
$recordPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 8))
Write-Output "General algorithms focused PASS $($record.completed)/$($record.total): 3 reference fixtures, 3 early negative controls, and 3 generic readonly/ref/owned-sequence probes with LLVM closure."
Write-Output $recordPath
