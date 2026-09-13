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
$partitionPointContractPath = Join-Path $repo $contract.partitionPoint.contract
$partitionPointSchemaPath = Join-Path $repo $contract.partitionPoint.schema
$partitionPointVerifierPath = Join-Path $repo $contract.partitionPoint.verifier
$partitionContractPath = Join-Path $repo $contract.partitionInPlace.contract
$partitionSchemaPath = Join-Path $repo $contract.partitionInPlace.schema
$partitionResultSchemaPath = Join-Path $repo $contract.partitionInPlace.resultSchema
$partitionVerifierPath = Join-Path $repo $contract.partitionInPlace.verifier
$sequenceContractPath = Join-Path $repo 'scripts/contracts/sequence-iterator-transforms.json'
$sequenceSchemaPath = Join-Path $repo 'scripts/contracts/sequence-iterator-transforms.schema.json'
$sequenceVerifierPath = Join-Path $repo 'scripts/verify-sequence-iterator-transforms-focused.ps1'
$sequenceModulePath = Join-Path $repo 'stdlib/std/sequence.slg'
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
$requiredRemainingSequence = @()
$requiredUnresolved = @(
    'partitionPoint selfhost/platform validation',
    'partitionInPlace managed/selfhost/platform validation',
    'sorted-merge output-overlap diagnostics',
    'selfhost candidate validation of generic readonly/reference, stable-sort, sorted-merge, and iterator-transform paths',
    'Windows/Linux/browser final fixed-point closure'
)
$requiredPendingProbes = @(
    'scripts/probes/general-algorithms/generic-readonly-slice.slg',
    'scripts/probes/general-algorithms/generic-explicit-reference.slg',
    'scripts/probes/general-algorithms/stable-sort.slg',
    'scripts/probes/general-algorithms/sorted-merge.slg',
    'scripts/probes/general-algorithms/partition-point-boundaries.slg',
    'scripts/probes/general-algorithms/partition-point-noncopyable.slg',
    'scripts/probes/general-algorithms/partition-point-fixed-readonly-lifetime.slg'
)
function Assert-ExactSet([object[]]$Actual, [string[]]$Expected, [string]$Name) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    if ($values.Count -ne $Expected.Count -or
        @($values | Sort-Object -Unique).Count -ne $Expected.Count -or
        @(Compare-Object ($Expected | Sort-Object) ($values | Sort-Object)).Count -ne 0) {
        throw "$Name must retain the exact unique authority set"
    }
}
if ($contract.schemaVersion -ne 6 -or $contract.scope -ne 'caller-owned-growable-arrays-copyable-selection-and-readonly-generic-sequences' -or
    $contract.module -cne 'stdlib/std/algorithm.slg' -or
    $contract.sort.stable -ne $false -or $contract.fixtures.Count -ne 3 -or
    $contract.negativeFixtures.Count -ne 3 -or $contract.managedProbes.Count -ne 5 -or
    $contract.readonlySequence.methods.Count -ne 5 -or
    $contract.noncopyablePermutation.status -cne 'exchange-primitive-integrated' -or
    $contract.noncopyablePermutation.requiredPrimitive -cne 'satisfied by values! -> exchange(left, right), preserving the same array owner, length, capacity, and exactly-once drop state' -or
    $contract.noncopyablePermutation.existingNegativeEvidence -cne 'algorithm-ordering-owned-negative' -or
    $contract.stableSort.algorithm -cne 'bottom-up merge sort' -or
    $contract.stableSort.stable -ne $true -or
    $contract.stableSort.heapAllocations -ne 0 -or
    $contract.stableSort.bulkStorageCopies -ne 0 -or
    $contract.stableSort.coverage.Count -ne 7 -or
    $contract.merge.method -cne 'Ordering.mergeSorted' -or
    $contract.merge.heapAllocations -ne 0 -or
    $contract.merge.bulkStorageCopies -ne 0 -or
    $contract.merge.coverage.Count -ne 7 -or
    $contract.partitionPoint.status -cne 'managed-windows-focused-complete' -or
    $contract.partitionPoint.method -cne 'Algorithms.partitionPoint' -or
    $contract.partitionPoint.contract -cne 'scripts/contracts/general-algorithms-partition-point.json' -or
    $contract.partitionPoint.schema -cne 'scripts/contracts/general-algorithms-partition-point.schema.json' -or
    $contract.partitionPoint.verifier -cne 'scripts/verify-general-algorithms-partition-point-focused.ps1' -or
    $contract.partitionPoint.result -cne 'artifacts/scratch/general-algorithms-partition-point/c427-validation-v4/result.json' -or
    $contract.partitionPoint.resultSha256 -cne '282A37CBDC2EF809C81DE03ADAAD314D0E961E719EBCCD697D57F09476A292C3' -or
    $contract.partitionPoint.semantics -cne 'readonly true*false* predicate partition; first false or length; O(log n); zero mutation and allocation' -or
    $contract.partitionInPlace.status -cne 'implemented-static-managed-pending' -or
    $contract.partitionInPlace.method -cne 'Algorithms.partitionInPlace' -or
    $contract.partitionInPlace.contract -cne 'scripts/contracts/general-algorithms-partition.json' -or
    $contract.partitionInPlace.schema -cne 'scripts/contracts/general-algorithms-partition.schema.json' -or
    $contract.partitionInPlace.resultSchema -cne 'scripts/contracts/general-algorithms-partition-result.schema.json' -or
    $contract.partitionInPlace.verifier -cne 'scripts/verify-general-algorithms-partition-focused.ps1' -or
    @($contract.remainingSequence.PSObject.Properties).Count -ne 0 -or
    $contract.iteratorTransforms.status -cne 'managed-windows-focused-complete' -or
    $contract.iteratorTransforms.module -cne 'stdlib/std/sequence.slg' -or
    $contract.iteratorTransforms.contract -cne 'scripts/contracts/sequence-iterator-transforms.json' -or
    $contract.iteratorTransforms.schema -cne 'scripts/contracts/sequence-iterator-transforms.schema.json' -or
    $contract.iteratorTransforms.verifier -cne 'scripts/verify-sequence-iterator-transforms-focused.ps1' -or
    $contract.iteratorTransforms.result -cne 'current-input result emitted by the focused verifier and embedded into the General result' -or
    $contract.iteratorTransforms.completed -ne 12 -or $contract.iteratorTransforms.total -ne 12) {
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
if ($contract.acceptance -cne 'managed Windows algorithm slice plus current-input sequence iterator-transform and partitionPoint focused closure; partitionInPlace static/parser 5/5 complete; partitionInPlace managed, selfhost, and platform closure pending') {
    throw 'general algorithms acceptance must not overstate selfhost or platform closure'
}

foreach ($path in @($partitionPointContractPath, $partitionPointSchemaPath, $partitionPointVerifierPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "partitionPoint authority input is missing: $path"
    }
}
$partitionContractJson = Get-Content -LiteralPath $partitionContractPath -Raw
if (-not ($partitionContractJson | Test-Json -SchemaFile $partitionSchemaPath)) {
    throw 'partitionInPlace contract failed its current schema'
}
$partitionContract = $partitionContractJson | ConvertFrom-Json
if ($partitionContract.status -cne 'implemented-static-managed-pending' -or
    $partitionContract.api.owner -cne 'Algorithms' -or
    $partitionContract.api.method -cne 'partitionInPlace' -or
    $partitionContract.api.signature -cne 'public partitionInPlace<T>: self, values: mut [T; ~] -> Int block item: ref T -> Bool' -or
    $partitionContract.ownership.mutation -cne 'values -> exchange(boundary!, index!)' -or
    $partitionContract.fixtures.Count -ne 5) {
    throw 'partitionInPlace focused authority no longer matches the General split'
}
foreach ($path in @($partitionContractPath, $partitionSchemaPath, $partitionResultSchemaPath, $partitionVerifierPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "partitionInPlace authority input is missing: $path" }
}
$partitionPointContractJson = Get-Content -LiteralPath $partitionPointContractPath -Raw
if (-not ($partitionPointContractJson | Test-Json -SchemaFile $partitionPointSchemaPath)) {
    throw 'partitionPoint contract failed its current schema'
}
$partitionPointContract = $partitionPointContractJson | ConvertFrom-Json
if ($partitionPointContract.status -cne 'managed-windows-focused-complete' -or
    $partitionPointContract.api.owner -cne 'Algorithms' -or
    $partitionPointContract.api.method -cne 'partitionPoint' -or
    $partitionPointContract.precondition -cne 'predicate results over values have the form true*false*' -or
    $partitionPointContract.algorithm.time -cne 'O(log n)' -or
    $partitionPointContract.ownership.mutations -ne 0 -or
    $partitionPointContract.ownership.heapAllocations -ne 0 -or
    $partitionPointContract.remaining.partitionInPlace -cne 'separate mutable permutation API is implemented with static/parser 5/5 and awaits managed/selfhost/platform validation' -or
    $partitionPointContract.managedResult.completed -ne 3 -or
    $partitionPointContract.managedResult.total -ne 3 -or
    $partitionPointContract.acceptance -cne 'managed Windows focused 3/3 complete; selfhost and other platforms pending') {
    throw 'partitionPoint focused authority no longer matches the General split'
}
Assert-ExactSet @($partitionPointContract.fixtures | ForEach-Object id) @('boundaries', 'noncopyable-readonly', 'fixed-readonly-lifetime') 'partitionPoint static fixtures'

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
$sequenceContractHash = (Get-FileHash -LiteralPath $sequenceContractPath -Algorithm SHA256).Hash
$sequenceSchemaHash = (Get-FileHash -LiteralPath $sequenceSchemaPath -Algorithm SHA256).Hash
$sequenceVerifierHash = (Get-FileHash -LiteralPath $sequenceVerifierPath -Algorithm SHA256).Hash
$sequenceModuleHash = (Get-FileHash -LiteralPath $sequenceModulePath -Algorithm SHA256).Hash
$partitionPointContractHash = (Get-FileHash -LiteralPath $partitionPointContractPath -Algorithm SHA256).Hash
$partitionPointSchemaHash = (Get-FileHash -LiteralPath $partitionPointSchemaPath -Algorithm SHA256).Hash
$partitionPointVerifierHash = (Get-FileHash -LiteralPath $partitionPointVerifierPath -Algorithm SHA256).Hash
$probeAuthority = @{
    'generic-readonly-slice' = @{ source = 'scripts/probes/general-algorithms/generic-readonly-slice.slg'; stdout = '2' }
    'generic-explicit-reference' = @{ source = 'scripts/probes/general-algorithms/generic-explicit-reference.slg'; stdout = '1' }
    'readonly-sequence' = @{ source = 'scripts/probes/general-algorithms/readonly-sequence.slg'; stdout = "true`nfalse`nsearch=1,true`nlower=1`nupper=3`nrange=1,3`nreuse=1,3" }
    'stable-sort' = @{ source = 'scripts/probes/general-algorithms/stable-sort.slg'; stdout = "1:1`n1:3`n2:0`n2:2`n3:4`nstorage=5,5,5,5`ncapacity=5,5`n3:4`n2:0`n2:2`n1:1`n1:3`nempty=0,0`nsingle=7,1,1`nshort=3,1,2,0,0" }
    'sorted-merge' = @{ source = 'scripts/probes/general-algorithms/sorted-merge.slg'; stdout = "ascending=7`n1:0:0`n2:0:1`n2:0:2`n2:1:0`n2:1:1`n3:1:2`n5:0:3`nstorage=7,7,7`ninputs=4,3`ndescending=7`n5:0:3`n3:1:2`n2:0:1`n2:0:2`n2:1:0`n2:1:1`n1:0:0`nempty=0,0,0`nshort-capacity`ncapacity-unchanged=99,1,1`nshort-length`nlength-unchanged=0,4" }
}
Assert-ExactSet @($contract.managedProbes | ForEach-Object id) @($probeAuthority.Keys) 'managed probes'
$probeHashes = @{}
foreach ($probe in $contract.managedProbes) {
    $algorithmBodyAudit = $null
    if (-not $probeAuthority.ContainsKey($probe.id) -or
        $probe.source -cne $probeAuthority[$probe.id].source -or
        $probe.stdout -cne $probeAuthority[$probe.id].stdout) {
        throw "managed probe contract drifted from verifier authority: $($probe.id)"
    }
    $probePath = Join-Path $repo $probe.source
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) { throw "managed probe source is missing: $($probe.source)" }
    $probeHashes[$probePath] = (Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash
}
foreach ($fixture in $partitionPointContract.fixtures) {
    foreach ($relativePath in @($fixture.source, $fixture.expected)) {
        $path = Join-Path $repo $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "partitionPoint fixture authority is missing: $relativePath"
        }
        $probeHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
}

$sequenceContractJson = Get-Content -LiteralPath $sequenceContractPath -Raw
if (-not ($sequenceContractJson | Test-Json -SchemaFile $sequenceSchemaPath)) {
    throw 'sequence iterator-transform contract failed its current schema'
}
$sequenceOutput = (& $sequenceVerifierPath -RepositoryRoot $repo 6>&1 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "sequence iterator-transform focused verifier failed: $sequenceOutput" }
$sequenceResultMatch = [regex]::Match($sequenceOutput, '(?m)^\[sequence iterator transforms\] result=(.+)$')
if (-not $sequenceResultMatch.Success) { throw 'sequence iterator-transform verifier emitted no result path' }
$sequenceResultPath = $sequenceResultMatch.Groups[1].Value.Trim()
if (-not (Test-Path -LiteralPath $sequenceResultPath -PathType Leaf)) {
    throw "sequence iterator-transform result is missing: $sequenceResultPath"
}
$sequenceResult = Get-Content -LiteralPath $sequenceResultPath -Raw | ConvertFrom-Json
if ($sequenceResult.status -cne 'passed' -or $sequenceResult.completed -ne 12 -or $sequenceResult.total -ne 12 -or
    @($sequenceResult.failureIds).Count -ne 0 -or @($sequenceResult.cases).Count -ne 12 -or
    @($sequenceResult.cases | Where-Object status -cne 'passed').Count -ne 0 -or @($sequenceResult.runs).Count -ne 14 -or
    $sequenceResult.compilerSha256 -cne $compilerHash -or
    $sequenceResult.moduleSha256 -cne $sequenceModuleHash -or
    $sequenceResult.contractSha256 -cne $sequenceContractHash -or
    $sequenceResult.schemaSha256 -cne $sequenceSchemaHash -or
    $sequenceResult.verifierSha256 -cne $sequenceVerifierHash -or
    $sequenceResult.acceptance -cne 'managed Windows focused native and LLVM evidence only; selfhost and other platforms pending') {
    throw 'sequence iterator-transform result is not a current exact 12/12 authority result'
}
foreach ($property in $sequenceResult.sourceHashes.PSObject.Properties) {
    $inputPath = Join-Path $repo $property.Name
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash -cne [string]$property.Value) {
        throw "sequence iterator-transform result input drifted: $($property.Name)"
    }
}
$sequenceResultHash = (Get-FileHash -LiteralPath $sequenceResultPath -Algorithm SHA256).Hash
$sequenceAggregateResult = [ordered]@{
    fixture = 'iterator-transforms'
    status = 'passed'
    completed = 12
    total = 12
    nativeRuns = 14
    resultPath = $sequenceResultPath
    resultSha256 = $sequenceResultHash
    moduleSha256 = $sequenceModuleHash
    contractSha256 = $sequenceContractHash
    schemaSha256 = $sequenceSchemaHash
    verifierSha256 = $sequenceVerifierHash
    failureIds = @()
    selfhost = 'pending-stable-candidate'
    platforms = 'Linux and browser pending'
}
$formatSources = @(
    (Join-Path $repo $contract.module),
    (Join-Path $repo 'scripts/probes/general-algorithms/stable-sort.slg'),
    (Join-Path $repo 'scripts/probes/general-algorithms/sorted-merge.slg'),
    (Join-Path $repo 'scripts/probes/general-algorithms/partition-point-boundaries.slg'),
    (Join-Path $repo 'scripts/probes/general-algorithms/partition-point-noncopyable.slg'),
    (Join-Path $repo 'scripts/probes/general-algorithms/partition-point-fixed-readonly-lifetime.slg')
)
& (Join-Path $repo 'scripts/format-authoritative-slg.ps1') -Check -Source $formatSources
if ($LASTEXITCODE -ne 0) { throw 'general algorithms authoritative format check failed' }
$results = @($sequenceAggregateResult)
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
    if ($probe.id -eq 'stable-sort') {
        $ir = Get-Content -LiteralPath $irPath -Raw
        $stableBodies = [regex]::Matches($ir, '(?ms)^define[^\r\n]*@(sollang_fn_std_algorithm_Ordering_(?:stableSort|mergeStable)[A-Za-z0-9_]*)[^\r\n]*\{.*?^\}')
        if ($stableBodies.Count -eq 0) { throw 'stable sort emitted no independently inspectable algorithm body' }
        foreach ($body in $stableBodies) {
            if ($body.Value -match '\bcall\b[^\r\n]*@(sollang_alloc|memcpy|memmove)\(') {
                throw "stable sort helper allocates or bulk-copies storage: $($body.Groups[1].Value)"
            }
        }
        $algorithmBodyAudit = [ordered]@{
            inspectedBodyCount = $stableBodies.Count
            forbiddenAllocationOrBulkCopyCallCount = 0
            forbiddenSymbols = @('sollang_alloc', 'memcpy', 'memmove')
        }
    }
    if ($probe.id -eq 'sorted-merge') {
        $ir = Get-Content -LiteralPath $irPath -Raw
        $mergeBodies = [regex]::Matches($ir, '(?ms)^define[^\r\n]*@(sollang_fn_std_algorithm_Ordering_mergeSorted_[A-Za-z0-9_]*)[^\r\n]*\{.*?^\}')
        if ($mergeBodies.Count -eq 0) { throw 'sorted merge emitted no independently inspectable algorithm body' }
        foreach ($body in $mergeBodies) {
            if ($body.Value -match '\bcall\b[^\r\n]*@(sollang_alloc|memcpy|memmove)\(') {
                throw "sorted merge helper allocates or bulk-copies storage: $($body.Groups[1].Value)"
            }
        }
        $algorithmBodyAudit = [ordered]@{
            inspectedBodyCount = $mergeBodies.Count
            forbiddenAllocationOrBulkCopyCallCount = 0
            forbiddenSymbols = @('sollang_alloc', 'memcpy', 'memmove')
        }
    }
    $probeResult = [ordered]@{
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
    if ($null -ne $algorithmBodyAudit) { $probeResult['algorithmBodyAudit'] = $algorithmBodyAudit }
    $results += $probeResult
}
if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -ne $compilerHash -or
    (Get-FileHash -LiteralPath (Join-Path $repo $contract.module) -Algorithm SHA256).Hash -ne $moduleHash -or
    (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash -ne $contractHash -or
    (Get-FileHash -LiteralPath $verifierPath -Algorithm SHA256).Hash -ne $verifierHash -or
    (Get-FileHash -LiteralPath $sequenceContractPath -Algorithm SHA256).Hash -ne $sequenceContractHash -or
    (Get-FileHash -LiteralPath $sequenceSchemaPath -Algorithm SHA256).Hash -ne $sequenceSchemaHash -or
    (Get-FileHash -LiteralPath $sequenceVerifierPath -Algorithm SHA256).Hash -ne $sequenceVerifierHash -or
    (Get-FileHash -LiteralPath $sequenceModulePath -Algorithm SHA256).Hash -ne $sequenceModuleHash -or
    (Get-FileHash -LiteralPath $partitionPointContractPath -Algorithm SHA256).Hash -ne $partitionPointContractHash -or
    (Get-FileHash -LiteralPath $partitionPointSchemaPath -Algorithm SHA256).Hash -ne $partitionPointSchemaHash -or
    (Get-FileHash -LiteralPath $partitionPointVerifierPath -Algorithm SHA256).Hash -ne $partitionPointVerifierHash -or
    (Get-FileHash -LiteralPath $sequenceResultPath -Algorithm SHA256).Hash -ne $sequenceResultHash) {
    throw 'compiler, algorithm source, contract, or verifier changed during focused verification'
}
foreach ($probePath in $probeHashes.Keys) {
    if ((Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash -ne $probeHashes[$probePath]) {
        throw "managed probe changed during focused verification: $probePath"
    }
}
foreach ($property in $sequenceResult.sourceHashes.PSObject.Properties) {
    $inputPath = Join-Path $repo $property.Name
    if ((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash -cne [string]$property.Value) {
        throw "sequence iterator-transform input changed during General verification: $($property.Name)"
    }
}
$inputHashes = [ordered]@{
    compiler = $compilerHash
    module = $moduleHash
    contract = $contractHash
    verifier = $verifierHash
    sequenceModule = $sequenceModuleHash
    sequenceContract = $sequenceContractHash
    sequenceSchema = $sequenceSchemaHash
    sequenceVerifier = $sequenceVerifierHash
    sequenceResult = $sequenceResultHash
    partitionPointContract = $partitionPointContractHash
    partitionPointSchema = $partitionPointSchemaHash
    partitionPointVerifier = $partitionPointVerifierHash
}
foreach ($probePath in @($probeHashes.Keys | Sort-Object)) {
    $relativePath = [IO.Path]::GetRelativePath($repo, $probePath).Replace('\', '/')
    $inputHashes[$relativePath] = $probeHashes[$probePath]
}
$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    completed = $results.Count
    total = $contract.fixtures.Count + $contract.negativeFixtures.Count + $contract.managedProbes.Count + 1
    failureIds = @()
    scope = $contract.scope
    compilerSha256 = $compilerHash
    moduleSha256 = $moduleHash
    contractSha256 = $contractHash
    verifierSha256 = $verifierHash
    inputHashes = $inputHashes
    allocationEvidence = 'zero additional emitted allocation/bulk-copy sites against fixture baseline; owner/length/capacity reuse executed'
    iteratorTransforms = $sequenceAggregateResult
    selfhostExecution = 'pending-final-accumulated-compiler-verification'
    results = $results
}
$recordPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 8))
Write-Output "General algorithms focused PASS $($record.completed)/$($record.total): preserved 3 reference fixtures, 3 early negative controls, 5 generic readonly/ref/owned-sequence/stable-sort/sorted-merge probes, and current-input iteratorTransforms 12/12 closure; partitionPoint static authority remains pending C426 managed execution."
Write-Output $recordPath
