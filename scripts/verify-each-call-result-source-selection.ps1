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
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$baseline = Join-Path $root 'artifacts/incremental-selfhost/selfhost-slg-seed.exe'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/each-call-result-source-selection-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'

$required = @($fixture, $expectedPath, $typeIdsPath, $typesPath, $managed, $baseline)
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
    scope = 'intrinsic-each-rightmost-call-result-source-selection'
    completed = 0
    total = if ($candidateRequired) { 9 } else { 7 }
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
        $candidateExe = Join-Path $output 'candidate.exe'
        $candidateLog = (& $candidatePath run $fixture --llvm $llvm -o $candidateExe --keep-temps -O0 2>&1) -join "`n"
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
        $candidateLlvm = [IO.Path]::ChangeExtension($candidateExe, '.ll')
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
