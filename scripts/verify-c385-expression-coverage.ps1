[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanPath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$RevalidateExistingFamily,
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'verification-compiler-product.ps1')

function RepoFile([string]$Path) {
    $absolute = [IO.Path]::GetFullPath((Join-Path $repo $Path))
    if (-not $absolute.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        throw "C385_COVERAGE_INPUT_MISSING_OR_OUTSIDE_REPOSITORY: $Path"
    }
    return $absolute
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function NthByteOffset([byte[]]$Bytes, [byte[]]$Needle, [int]$Occurrence) {
    $seen = 0
    for ($index = 0; $index -le $Bytes.Length - $Needle.Length; $index++) {
        $match = $true
        for ($offset = 0; $offset -lt $Needle.Length; $offset++) {
            if ($Bytes[$index + $offset] -ne $Needle[$offset]) { $match = $false; break }
        }
        if ($match) {
            if ($seen -eq $Occurrence) { return $index }
            $seen++
        }
    }
    return -1
}
$script:pairedBatchValidated = @{}
function NativeBatchPassed([string]$Path, [string]$CompilerSha, [string]$Fixture) {
    $report = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
    if ($report.PSObject.Properties['runs']) {
        if (-not $script:pairedBatchValidated.ContainsKey($Path)) {
            foreach ($entry in $report.inputHashesStart.PSObject.Properties) {
                if (-not (Test-Path -LiteralPath $entry.Name -PathType Leaf) -or
                    (Hash $entry.Name) -cne $entry.Value) {
                    throw "C385_PAIRED_NATIVE_INPUT_DRIFT: $($entry.Name)"
                }
            }
            $script:pairedBatchValidated[$Path] = $report.inputHashesStart
        }
        $nativeRows = @($report.runs | Where-Object {
            $_.fixture -ceq $Fixture -and $_.compilerSha256 -ceq $CompilerSha -and
            $_.buildExit -eq 0 -and $_.llvmAsExit -eq 0 -and
            $_.directCallExit -eq 0 -and $_.nativeExit -eq 0
        })
        if ($report.schemaVersion -ne 1 -or $report.status -cne 'passed' -or
            $report.inputStable -ne $true -or $report.completed -ne $report.total -or
            $nativeRows.Count -ne 1) {
            throw "C385_PAIRED_NATIVE_NOT_PASSED: $Path"
        }
        return
    }
    if ($report.schemaVersion -ne 1 -or $report.platform -cne 'windows' -or $report.state -cne 'passed' -or
        $report.compilerSha256 -cne $CompilerSha -or $report.completed -ne $report.total -or
        $report.passed -ne $report.total -or $report.failed -ne 0 -or $report.missing -ne 0 -or
        @($report.results | Where-Object { $_.Fixture -ceq $Fixture -and $_.Success -eq $true -and $_.Error -ceq '' }).Count -ne 1) {
        throw "C385_NATIVE_BATCH_NOT_PASSED: $Path"
    }
}

$planFile = RepoFile $PlanPath
$planSchema = RepoFile 'scripts/contracts/c385-expression-coverage-plan.schema.json'
$resultSchema = RepoFile 'scripts/contracts/c385-expression-coverage-result.schema.json'
$parityFile = RepoFile 'scripts/contracts/expression-lowering-parity.json'
$planText = [IO.File]::ReadAllText($planFile)
if (-not ($planText | Test-Json -SchemaFile $planSchema -ErrorAction Stop)) { throw 'C385_COVERAGE_PLAN_SCHEMA_INVALID' }
$plan = $planText | ConvertFrom-Json
$parity = [IO.File]::ReadAllText($parityFile) | ConvertFrom-Json
$managedProduct = Resolve-VerificationCompilerProduct $repo $plan.managedCompiler.path $plan.managedCompiler.sha256
$selfhostProduct = Resolve-VerificationCompilerProduct $repo $plan.selfhostCompiler.path $plan.selfhostCompiler.sha256
$managedCompiler = $managedProduct.Path
$selfhostCompiler = $selfhostProduct.Path
if ((Hash $managedCompiler) -cne $plan.managedCompiler.sha256 -or
    (Hash $selfhostCompiler) -cne $plan.selfhostCompiler.sha256) { throw 'C385_COVERAGE_COMPILER_SHA_MISMATCH' }
$families = @($plan.cases.family)
if (@($families | Sort-Object -Unique).Count -ne $families.Count) { throw 'C385_COVERAGE_DUPLICATE_FAMILY' }
$priorCoverage = [IO.File]::ReadAllText((RepoFile 'scripts/contracts/c385-expression-family-batch.json')) | ConvertFrom-Json
$alreadyCovered = @($priorCoverage.fixtures.probes.family)
$inputs = [ordered]@{
    plan = $planFile; planSchema = $planSchema; resultSchema = $resultSchema
    parity = $parityFile; priorCoverage = (RepoFile 'scripts/contracts/c385-expression-family-batch.json')
    verifier = $PSCommandPath; processHelper = (RepoFile 'scripts/verification-process.ps1')
    managedCompiler = $managedCompiler; selfhostCompiler = $selfhostCompiler
}
$inputs.compilerProductResolver = RepoFile 'scripts/verification-compiler-product.ps1'
foreach ($product in @($managedProduct, $selfhostProduct)) {
    foreach ($path in $product.InputHashes.Keys) { $inputs["compiler-proof:$path"] = $path }
}
foreach ($case in $plan.cases) {
    $mapping = @($parity.mappings | Where-Object managedExpression -CEQ $case.family)
    if ($mapping.Count -ne 1) { throw "C385_COVERAGE_MAPPING_INVALID: $($case.family)" }
    if ($RevalidateExistingFamily) {
        $prior = @($priorCoverage.fixtures.probes | Where-Object family -CEQ $case.family)
        if ($prior.Count -ne 1 -or $case.astKind -notin @($prior[0].astKinds) -or
            $case.typedIrKind -notin @($prior[0].typedIrKinds)) {
            throw "C385_COVERAGE_REVALIDATION_MAPPING_INVALID: $($case.family)"
        }
    } elseif ($case.family -in $alreadyCovered) {
        throw "C385_COVERAGE_MAPPING_INVALID: $($case.family)"
    }
    if ($case.proofMode -ceq 'direct') {
        if ($case.astKind -notin @($mapping[0].selfhostAstKinds) -or
            $case.typedIrKind -notin @($mapping[0].typedIrKinds)) { throw "C385_COVERAGE_DIRECT_MAPPING_INVALID: $($case.family)" }
    } elseif ($mapping[0].behavior -cne 'compile-time' -or @($mapping[0].typedIrKinds).Count -ne 0 -or
        $case.astKind -ne 37 -or $case.typedIrKind -ne 14) {
        throw "C385_COVERAGE_FOLDED_MAPPING_INVALID: $($case.family)"
    }
    $source = RepoFile "examples/regression/$($case.fixture).slg"
    $expected = RepoFile "examples/regression/expected/$($case.fixture).stdout.txt"
    $managedBatch = RepoFile $case.managedBatchResult
    $selfhostBatch = RepoFile $case.selfhostBatchResult
    if ((NthByteOffset ([IO.File]::ReadAllBytes($source)) ([Text.Encoding]::UTF8.GetBytes($case.anchor)) $case.occurrence) -lt 0) {
        throw "C385_COVERAGE_ANCHOR_MISSING: $($case.family)"
    }
    NativeBatchPassed $managedBatch $plan.managedCompiler.sha256 $case.fixture
    NativeBatchPassed $selfhostBatch $plan.selfhostCompiler.sha256 $case.fixture
    $inputs["source:$($case.family)"] = $source
    $inputs["expected:$($case.family)"] = $expected
    $inputs["managedBatch:$($case.family)"] = $managedBatch
    $inputs["selfhostBatch:$($case.family)"] = $selfhostBatch
}
$hashes = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $hashes[$entry.Key] = Hash $entry.Value }
foreach ($product in @($managedProduct, $selfhostProduct)) {
    foreach ($path in $product.InputHashes.Keys) {
        if ($hashes["compiler-proof:$path"] -cne $product.InputHashes[$path]) { throw 'C385_COMPILER_BUILD_PROOF_INPUT_DRIFT' }
    }
}
if ($ValidateInputsOnly) {
    Write-Host "[C385 coverage preflight] PASS $($plan.cases.Count) family plans; AST and Typed IR remain unverified"
    return
}
$output = [IO.Path]::GetFullPath((Join-Path $repo $OutputDirectory))
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/scratch'))
if (-not $output.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -gt 0)) {
    throw 'C385_COVERAGE_OUTPUT_MUST_BE_FRESH_SCRATCH_DIRECTORY'
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$results = @()
foreach ($case in $plan.cases) {
    $source = $inputs["source:$($case.family)"]
    $mapping = @($parity.mappings | Where-Object managedExpression -CEQ $case.family)[0]
    $offset = NthByteOffset ([IO.File]::ReadAllBytes($source)) ([Text.Encoding]::UTF8.GetBytes($case.anchor)) $case.occurrence
    $nodeId = $null; $irKind = $null; $failure = $null; $unfoldedAstKindAbsent = $null
    try {
        $ast = Invoke-VerificationProcessCapture -FilePath $selfhostCompiler -ArgumentList @('ast-nodes', $source) -WorkingDirectory $repo -Description "C385 $($case.family) AST" -TimeoutMilliseconds 120000
        $ir = Invoke-VerificationProcessCapture -FilePath $selfhostCompiler -ArgumentList @('typed-ir-nodes', $source) -WorkingDirectory $repo -Description "C385 $($case.family) Typed IR" -TimeoutMilliseconds 120000
        if ($ast.ExitCode -ne 0 -or $ir.ExitCode -ne 0 -or $ast.Stderr.Length -ne 0 -or $ir.Stderr.Length -ne 0) { throw 'AST_OR_TYPED_IR_COMMAND_FAILED' }
        $pattern = '^ast source 0 node (?<id>\d+) kind (?<kind>\d+) parent -?\d+ start (?<start>\d+) length (?<length>\d+)'
        $anchorLength = [Text.Encoding]::UTF8.GetByteCount($case.anchor)
        $nodes = @($ast.Stdout -split "`n" | ForEach-Object {
            if ($_ -match $pattern -and [int]$Matches.kind -eq $case.astKind) {
                $nodeStart = [int]$Matches.start; $nodeLength = [int]$Matches.length
                $spanMatches = if ($case.selector -ceq 'exact') {
                    $nodeStart -eq $offset -and $nodeLength -eq $anchorLength
                } else {
                    $nodeStart -le $offset -and ($nodeStart + $nodeLength) -ge ($offset + $anchorLength)
                }
                if ($spanMatches) { [pscustomobject]@{ id = [int]$Matches.id; length = $nodeLength } }
            }
        })
        if ($case.selector -ceq 'smallest-containing' -and $nodes.Count -gt 0) {
            $minimumLength = ($nodes | Measure-Object -Property length -Minimum).Minimum
            $nodes = @($nodes | Where-Object length -eq $minimumLength)
        }
        if ($nodes.Count -ne 1) { throw "AST_EXACT_NODE_COUNT_$($nodes.Count)" }
        $nodeId = $nodes[0].id
        if ($case.proofMode -ceq 'folded-compile-time') {
            $unfolded = @($ast.Stdout -split "`n" | ForEach-Object {
                if ($_ -match $pattern -and [int]$Matches.kind -in @($mapping.selfhostAstKinds) -and
                    [int]$Matches.start -eq $offset -and [int]$Matches.length -eq [Text.Encoding]::UTF8.GetByteCount($case.anchor)) { [int]$Matches.id }
            })
            $unfoldedAstKindAbsent = $unfolded.Count -eq 0
            if (-not $unfoldedAstKindAbsent) { throw 'COMPILE_TIME_EXPRESSION_NOT_FOLDED' }
        }
        $irPattern = '^node \d+ kind (?<kind>\d+) parent -?\d+ source 0 ast (?<ast>-?\d+)'
        $irNodes = @($ir.Stdout -split "`n" | ForEach-Object {
            if ($_ -match $irPattern -and [int]$Matches.ast -eq $nodeId -and [int]$Matches.kind -eq $case.typedIrKind) { [int]$Matches.kind }
        })
        if ($irNodes.Count -ne 1) { throw "TYPED_IR_NODE_COUNT_$($irNodes.Count)" }
        $irKind = $irNodes[0]
    } catch { $failure = $_.Exception.Message }
    $results += [ordered]@{
        family = [string]$case.family; fixture = [string]$case.fixture; proofMode = [string]$case.proofMode
        unfoldedAstKindAbsent = $unfoldedAstKindAbsent; passed = ($null -eq $failure)
        astNodeId = $nodeId; typedIrKind = $irKind
        managedBatchSha256 = $hashes["managedBatch:$($case.family)"]
        selfhostBatchSha256 = $hashes["selfhostBatch:$($case.family)"]
        failure = $failure
    }
}
$endHashes = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $endHashes[$entry.Key] = Hash $entry.Value }
$pairedInputStable = $true
foreach ($receiptInputs in $script:pairedBatchValidated.Values) {
    foreach ($entry in $receiptInputs.PSObject.Properties) {
        if (-not (Test-Path -LiteralPath $entry.Name -PathType Leaf) -or
            (Hash $entry.Name) -cne $entry.Value) { $pairedInputStable = $false }
    }
}
$inputStable = $pairedInputStable -and -not [bool]@(Compare-Object @($hashes.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) @($endHashes.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }))
$failureIds = @($results | Where-Object { -not $_.passed } | ForEach-Object { $_.family })
if (-not $inputStable) { $failureIds += 'INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($results | Where-Object passed).Count; total = $results.Count; remainingFamilyTotal = 14
    inputStable = $inputStable; inputHashes = $hashes; inputHashesEnd = $endHashes
    cases = @($results); failureIds = @($failureIds)
}
$resultPath = Join-Path $output 'result.json'
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchema -ErrorAction Stop)) { throw "C385_COVERAGE_RESULT_SCHEMA_INVALID: $resultPath" }
if ($record.status -ne 'passed') { throw "C385_COVERAGE_FAILED: $resultPath" }
Write-Host "[C385 coverage] PASS $($record.completed)/$($record.total) structural and native-exact families; result=$resultPath"
