[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-UnderRoot([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

$compilerPath = Resolve-UnderRoot $Compiler
$llvmPath = Resolve-UnderRoot $LlvmRoot
$stdlibPath = Resolve-UnderRoot $StdlibRoot
$probePath = Join-Path $root 'scripts/probes/dictionary/c471-missing-key-index-update.slg'
$contractPath = Join-Path $root 'scripts/contracts/c471-missing-key-trap.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$nativeCases = @($contract.cases | Where-Object id -CEQ 'native-missing-key')
if ($nativeCases.Count -ne 1 -or $nativeCases[0].expectedRuntimeExit -ne -1073741795 -or
    $nativeCases[0].source -cne 'scripts/probes/dictionary/c471-missing-key-index-update.slg') {
    throw 'C471 missing-key runtime contract is invalid'
}
$expectedRuntimeExit = [int]$nativeCases[0].expectedRuntimeExit
$outputPath = Resolve-UnderRoot $OutputDirectory
$scratchRoot = Join-Path $root 'artifacts/scratch'
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be a child of $scratchRoot"
}
foreach ($path in @($compilerPath, $probePath, (Join-Path $llvmPath 'bin/llvm-as.exe'), (Join-Path $llvmPath 'bin/clang.exe'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file not found: $path" }
}
if (-not (Test-Path -LiteralPath $stdlibPath -PathType Container)) { throw "StdlibRoot not found: $stdlibPath" }
if ([IO.Path]::GetExtension($compilerPath) -cne '.exe') { throw 'C471 missing-key gate requires a Windows selfhost compiler executable' }

function Get-InputFingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'C471-missing-key-trap'
        commonFingerprint = $common
        optimization = 'O1'
        expectedExitCode = [string]$expectedRuntimeExit
    }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings `
        -InputPath @($PSCommandPath, $probePath, $contractPath)
}

$inputStart = Get-InputFingerprint
$compilerSha = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
$probeSha = (Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash
if ($ValidateInputsOnly) {
    [pscustomobject]@{ status = 'preflight-passed'; compilerSha256 = $compilerSha
        probeSha256 = $probeSha; inputFingerprint = $inputStart } | ConvertTo-Json -Compress
    return
}
if (Test-Path -LiteralPath $outputPath) { throw "OutputDirectory must not already exist: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$executable = Join-Path $outputPath 'missing-key.exe'
$llvm = "$executable.ll"
$bitcode = "$executable.bc"
$resultPath = Join-Path $outputPath 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    defectId = 'C2026-09-23-471'
    status = 'running'
    compilerSha256 = $compilerSha
    probeSha256 = $probeSha
    inputFingerprintStart = $inputStart
    inputFingerprintEnd = $null
    inputStable = $false
    buildExitCode = $null
    llvmDirectCallClosure = 'not-run'
    llvmAssembly = 'not-run'
    runExitCode = $null
    stdoutLength = $null
    stderrLength = $null
    llvmSha256 = $null
    executableSha256 = $null
    failure = $null
    inputHashes = @{ $contractPath = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash }
    cases = @()
    processesStopped = $false
    completed = 0
    total = 1
}
try {
    $build = Invoke-VerificationProcessCapture -FilePath $compilerPath `
        -ArgumentList @('build', $probePath, '-o', $executable, '--target', 'windows-x64',
            '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps') `
        -ExecutionRecordPath (Join-Path $outputPath 'build.execution.json') `
        -Description 'C471 missing-key selfhost build' -WorkingDirectory $root -TimeoutMilliseconds 120000
    $record.buildExitCode = $build.ExitCode
    if ($build.ExitCode -ne 0) { throw "Build failed: $($build.Stderr.Trim()) $($build.Stdout.Trim())" }
    if (($build.Stdout + $build.Stderr) -match '(?im)\bwarning\b|\bN00[12]\b') {
        throw 'Build emitted a warning or source-style note'
    }
    foreach ($path in @($executable, $llvm)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build product missing: $path" }
    }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $llvm
    if (-not $?) { throw 'LLVM direct-call closure failed' }
    $record.llvmDirectCallClosure = 'passed'
    $assembly = Invoke-VerificationProcessCapture -FilePath (Join-Path $llvmPath 'bin/llvm-as.exe') `
        -ExecutionRecordPath (Join-Path $outputPath 'assembly.execution.json') `
        -ArgumentList @($llvm, '-o', $bitcode) -Description 'C471 missing-key LLVM assembly' -TimeoutMilliseconds 30000
    if ($assembly.ExitCode -ne 0) { throw "LLVM assembly failed: $($assembly.Stderr.Trim())" }
    $record.llvmAssembly = 'passed'
    $source = Get-Content -LiteralPath $llvm -Raw
    if ($source -notmatch '(?s)assign\d+_missing:\s+call void @llvm\.trap\(\)\s+unreachable') {
        throw 'Indexed replacement has no explicit missing-key trap block'
    }
    $run = Invoke-VerificationProcessCapture -FilePath $executable -Description 'C471 missing-key runtime' -TimeoutMilliseconds 10000 `
        -ExecutionRecordPath (Join-Path $outputPath 'run.execution.json')
    $record.runExitCode = $run.ExitCode
    $record.stdoutLength = $run.Stdout.Length
    $record.stderrLength = $run.Stderr.Length
    if ($run.ExitCode -ne $expectedRuntimeExit -or $run.Stdout.Length -ne 0) {
        throw "Missing-key behavior changed: exit=$($run.ExitCode), stdoutLength=$($run.Stdout.Length), stderr=$($run.Stderr.Trim())"
    }
    $record.llvmSha256 = (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash
    $record.executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
    $record.cases = @(@{ id = 'native-missing-key'; status = 'passed'; passed = $true
        buildExit = $build.ExitCode; runExit = $run.ExitCode })
    $record.completed = 1
    $record.processesStopped = @('build', 'assembly', 'run' | ForEach-Object {
        (Get-Content -LiteralPath (Join-Path $outputPath "$_.execution.json") -Raw | ConvertFrom-Json).processesStopped
    } | Where-Object { $_ -ne $true }).Count -eq 0
    if (-not $record.processesStopped) { throw 'C471 process shutdown is unconfirmed' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
} finally {
    $record.inputFingerprintEnd = Get-InputFingerprint
    $record.inputStable = $record.inputFingerprintEnd -ceq $inputStart
    if (-not $record.inputStable) {
        $record.status = 'failed'
        $record.failure = 'Input fingerprint changed during C471 missing-key verification'
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"))
}
if ($record.status -ne 'passed') { throw "C471 missing-key gate failed: $($record.failure); result=$resultPath" }
$cleanupPlan = Join-Path $outputPath 'artifact-cleanup-plan.json'
& python -X utf8 (Join-Path $PSScriptRoot 'completed_artifact_plan.py') --repo $root --output-directory $outputPath --plan $cleanupPlan
if ($LASTEXITCODE -ne 0) { throw 'C471 completed artifact plan failed' }
$cleanup = Get-Content -LiteralPath $cleanupPlan -Raw | ConvertFrom-Json
if (@($cleanup.completionRecords).Count -ne 1) { throw 'C471 cleanup completion evidence missing' }
& (Join-Path $PSScriptRoot 'Invoke-CompletedArtifactCleanup.ps1') -Plan $cleanupPlan -Execute
if (-not $?) { throw 'C471 completed artifact cleanup failed' }
Write-Output "[C471 missing-key] PASS explicit trap, LLVM closure/assembly, stable inputs: $resultPath"
