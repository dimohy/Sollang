[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$fixture = Join-Path $root 'scripts/contracts/fixtures/c394-call-result-each-struct-field.slg'
$expectedPath = Join-Path $root 'scripts/contracts/fixtures/c394-call-result-each-struct-field.stdout.txt'
$typeIdsPath = Join-Path $root 'selfhost/semantic/expression_type_ids_paths.slg'
$typesPath = Join-Path $root 'selfhost/semantic/expression_types.slg'
$astPath = Join-Path $root 'selfhost/syntax/ast.slg'
$functionExpressionsPath = Join-Path $root 'selfhost/llvm/text/function_expressions.slg'
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$baseline = Join-Path $root 'artifacts/incremental-selfhost/selfhost-slg-seed.exe'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$stdlibRoot = Join-Path $root 'stdlib'
$output = Join-Path $root ('artifacts/scratch/each-call-result-source-selection-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'

$stdlibSources = if (Test-Path -LiteralPath $stdlibRoot -PathType Container) {
    @(Get-ChildItem -LiteralPath $stdlibRoot -Recurse -File -Filter '*.slg' |
        Sort-Object FullName |
        ForEach-Object { $_.FullName })
} else {
    @()
}
if ($stdlibSources.Count -eq 0) {
    throw "candidate fixture requires a non-empty authoritative stdlib root: $stdlibRoot"
}
$required = @($fixture, $expectedPath, $typeIdsPath, $typesPath, $astPath, $functionExpressionsPath, $managed, $baseline) + $stdlibSources
if (-not [string]::IsNullOrWhiteSpace($CandidateCompiler)) {
    $required += [IO.Path]::GetFullPath($CandidateCompiler)
}
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing input: $path" }
}

$hashes = [ordered]@{}
foreach ($path in @($required + $PSCommandPath | Select-Object -Unique)) {
    $hashes[$path] = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
}
$candidateRequired = -not [string]::IsNullOrWhiteSpace($CandidateCompiler)
$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'intrinsic-each-explicit-preceding-call-stage-selection'
    completed = 0
    total = if ($candidateRequired) { 12 } else { 9 }
    candidateRequired = $candidateRequired
    inputHashes = $hashes
    checks = @()
    resultPath = $resultPath
}
function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}
function Assert-SelectionStructure(
    [string]$Path,
    [string]$IndexName,
    [string]$NodeName,
    [string]$CandidateEndName,
    [string]$SourceEndName,
    [string]$DistanceName,
    [string]$SourceDistanceName
) {
    $source = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $requiredFragments = @(
        "UIntSize(0) => $SourceEndName!",
        "$NodeName.start + $NodeName.length => $CandidateEndName",
        "$IndexName! < 0 or $CandidateEndName > $SourceEndName! or ($CandidateEndName == $SourceEndName! and $DistanceName! < $SourceDistanceName!)",
        "$CandidateEndName => $SourceEndName!"
    )
    foreach ($fragment in $requiredFragments) {
        if (-not $source.Contains($fragment)) { throw "selection structure drifted in ${Path}: $fragment" }
    }
    if ($source.Contains("$DistanceName! < $SourceDistanceName!`n")) {
        throw "distance-only each-source selection returned in $Path"
    }
}

try {
    Save-Result
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $fixture
    if ($LASTEXITCODE -ne 0) { throw 'fixture authoritative format failed' }
    Complete-Check 'fixture-authoritative-format'

    Assert-SelectionStructure $typeIdsPath 'eachSourceExpression' 'eachSourceNode' 'eachCandidateEnd' 'eachSourceEnd' 'eachDistance' 'eachSourceDistance'
    Complete-Check 'expression-type-id-rightmost-end-then-distance'
    Assert-SelectionStructure $typesPath 'intrinsicRoleSourceTypeIndex' 'intrinsicRoleSourceNode' 'intrinsicRoleCandidateEnd' 'intrinsicRoleSourceEnd' 'intrinsicRoleDistance' 'intrinsicRoleSourceDistance'
    Complete-Check 'expression-type-rightmost-end-then-distance'

    $astSource = [IO.File]::ReadAllText($astPath).Replace("`r`n", "`n")
    $explicitStageContract = '(arrows! -> len) > 1 and stageBodyCount! > 0'
    if (-not $astSource.Contains($explicitStageContract)) {
        throw "single-callback pipeline stage expansion drifted: $explicitStageContract"
    }
    if ($astSource.Contains('(arrows! -> len) > 1 and stageBodyCount! > 1')) {
        throw 'single-callback pipeline returned to unsplit argument-based source inference'
    }
    if (-not $astSource.Contains('not roleBodyReached! -> if { 10 => stage!.kind }')) {
        throw 'ordinary source-call stage is no longer distinguished from a block-function stage'
    }
    Complete-Check 'single-callback-preceding-call-stage-expansion'

    $functionExpressionsSource = [IO.File]::ReadAllText($functionExpressionsPath).Replace("`r`n", "`n")
    foreach ($fragment in @(
        'arrayElement.kind == 3 or arrayElement.kind == 4',
        'arrayElement -> sourceToken(context, state) => arrayElementToken',
        '(context.sources[arrayElement.sourceModule] -> byte(arrayElementToken.span.start)) == 116'
    )) {
        if (-not $functionExpressionsSource.Contains($fragment)) {
            throw "function-local array literal emission lost inline Bool support: $fragment"
        }
    }
    Complete-Check 'function-local-array-inline-bool-emission'

    # The call expression ends after both its receiver and argument. The same-end
    # control keeps the nearest ancestor; input enumeration order is irrelevant.
    $candidates = @(
        [pscustomobject]@{ name='receiver'; end=80; distance=2 },
        [pscustomobject]@{ name='argument'; end=92; distance=2 },
        [pscustomobject]@{ name='call'; end=96; distance=3 },
        [pscustomobject]@{ name='same-end-nearer'; end=96; distance=1 }
    )
    $selected = $null
    foreach ($candidate in $candidates) {
        if ($null -eq $selected -or $candidate.end -gt $selected.end -or
            ($candidate.end -eq $selected.end -and $candidate.distance -lt $selected.distance)) {
            $selected = $candidate
        }
    }
    if ($selected.name -cne 'same-end-nearer') { throw 'rightmost-end selection model failed' }
    $record.selectionModel = [ordered]@{ selected=$selected.name; end=$selected.end; distance=$selected.distance }
    Complete-Check 'rightmost-call-and-same-end-distance-model'

    $managedExe = Join-Path $output 'managed.exe'
    $managedLog = (& dotnet $managed build $fixture -o $managedExe --target windows-x64 -O0 2>&1) -join "`n"
    $managedExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'managed.log'), $managedLog + "`n")
    if ($managedExit -ne 0 -or -not (Test-Path -LiteralPath $managedExe) -or $managedLog -match '(?m)^warning ') {
        throw "managed fixture build failed or warned: $managedLog"
    }
    $managedActual = (& $managedExe 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or ($managedActual.TrimEnd() + "`n") -cne [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")) {
        throw "managed fixture output mismatch: $managedActual"
    }
    $record.managed = [ordered]@{ compilerSha256=$hashes[$managed]; executableSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $managedExe).Hash; stdout=$managedActual }
    Complete-Check 'managed-warning-zero-native-exact'

    $baselineLlvm = Join-Path $output 'baseline.ll'
    $baselineText = (& $baseline windows $fixture 2>&1) -join "`n"
    $baselineExit = $LASTEXITCODE
    [IO.File]::WriteAllText($baselineLlvm, $baselineText + "`n")
    $expectedFailure = 'struct initializer field type mismatch (source 0, field 0)'
    if ($baselineExit -eq 0 -or -not $baselineText.Contains($expectedFailure) -or $baselineText -match '(?m)^define ') {
        throw "stable seed baseline no longer reproduces the exact pre-LLVM failure: $baselineText"
    }
    $record.baseline = [ordered]@{ compilerSha256=$hashes[$baseline]; exitCode=$baselineExit; expectedFailure=$expectedFailure; validLlvmProduced=$false }
    Complete-Check 'stable-seed-exact-pre-llvm-baseline'

    if ($candidateRequired) {
        $candidatePath = [IO.Path]::GetFullPath($CandidateCompiler)
        $candidateAstLog = (& $candidatePath ast-nodes $fixture 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "candidate AST probe failed: $candidateAstLog" }
        $pipelineSource = [IO.File]::ReadAllText($fixture)
        $pipelineStart = $pipelineSource.IndexOf('input -> values(flags) -> each value', [StringComparison]::Ordinal)
        $firstArrow = $pipelineSource.IndexOf('->', $pipelineStart, [StringComparison]::Ordinal)
        $secondArrow = $pipelineSource.IndexOf('->', $firstArrow + 2, [StringComparison]::Ordinal)
        if ($pipelineStart -lt 0 -or $firstArrow -lt 0 -or $secondArrow -lt 0) {
            throw 'candidate AST probe fixture pipeline markers are missing'
        }
        $kind48Matches = [regex]::Matches($candidateAstLog, '(?m)^ast source 0 node (?<node>\d+) kind 48 parent (?<parent>-?\d+) start (?<start>\d+) length (?<length>\d+) ')
        if ($kind48Matches.Count -ne 1) {
            throw "candidate AST probe expected one callback block stage, actual $($kind48Matches.Count)"
        }
        $outerStage = [pscustomobject]@{
            node = [int]$kind48Matches[0].Groups['node'].Value
            parent = [int]$kind48Matches[0].Groups['parent'].Value
            start = [int]$kind48Matches[0].Groups['start'].Value
            length = [int]$kind48Matches[0].Groups['length'].Value
        }
        $kind10Matches = [regex]::Matches($candidateAstLog, '(?m)^ast source 0 node (?<node>\d+) kind 10 parent (?<parent>-?\d+) start (?<start>\d+) length (?<length>\d+) ')
        $stageRows = @($kind10Matches | ForEach-Object {
            [pscustomobject]@{
                node = [int]$_.Groups['node'].Value
                parent = [int]$_.Groups['parent'].Value
                start = [int]$_.Groups['start'].Value
                length = [int]$_.Groups['length'].Value
            }
        })
        $expectedSourceCallLength = $secondArrow - $pipelineStart
        $sourceCallStage = @($stageRows | Where-Object {
            $_.start -eq $pipelineStart -and $_.length -eq $expectedSourceCallLength
        })
        if ($sourceCallStage.Count -ne 1) {
            throw "candidate AST probe expected one ordinary source-call stage, actual $($sourceCallStage.Count): $candidateAstLog"
        }
        $sourceCallStage = $sourceCallStage[0]
        if ($sourceCallStage.start -ne $pipelineStart -or
            $sourceCallStage.length -ne $expectedSourceCallLength -or
            $sourceCallStage.parent -ne $outerStage.node) {
            throw "candidate AST probe did not nest the explicit source call stage: $candidateAstLog"
        }
        $record.candidateAst = [ordered]@{
            stageCount = 2
            sourceCallNode = $sourceCallStage.node
            outerStageNode = $outerStage.node
            sourceCallLength = $sourceCallStage.length
        }
        Complete-Check 'candidate-explicit-source-call-stage'

        $candidateExe = Join-Path $output 'candidate.exe'
        $candidateLog = (& $candidatePath run $fixture --stdlib $stdlibRoot --llvm $llvm -o $candidateExe --keep-temps -O0 2>&1) -join "`n"
        $candidateExit = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output 'candidate.log'), $candidateLog + "`n")
        if ($candidateExit -ne 0 -or -not (Test-Path -LiteralPath $candidateExe) -or $candidateLog -match '(?m)^warning ') {
            throw "candidate fixture run failed or warned: $candidateLog"
        }
        $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
        if ($candidateLog.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) {
            throw "candidate fixture output mismatch: $candidateLog"
        }
        Complete-Check 'candidate-warning-zero-native-exact'
        $candidateLlvm = $candidateExe + '.ll'
        & (Join-Path $llvm 'bin/llvm-as.exe') $candidateLlvm -o (Join-Path $output 'candidate.bc')
        if ($LASTEXITCODE -ne 0) { throw 'candidate LLVM assembly failed' }
        & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $candidateLlvm
        Complete-Check 'candidate-llvm-assembly-and-call-closure'
        $record.candidate = [ordered]@{ compilerSha256=$hashes[$candidatePath]; executableSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $candidateExe).Hash; llvmSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $candidateLlvm).Hash }
    }

    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash -cne $hashes[$path]) { throw "input drift: $path" }
    }
    Complete-Check 'input-hash-stability'
    if ($record.completed -ne $record.total) { throw "denominator mismatch: $($record.completed)/$($record.total)" }
    $record.status = 'passed'
    Save-Result
    Write-Output "PASS $($record.completed)/$($record.total); $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
