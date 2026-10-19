[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$CompilerSha256,
    [Parameter(Mandatory)][string]$PositiveSource,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

function Resolve-Input([string]$Path) {
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Invoke-Captured([string]$File, [string[]]$Arguments, [string]$WorkDirectory, [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $WorkDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "OUTPUT_SPAWN_FAILED: $File" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "OUTPUT_PROCESS_TIMEOUT: $File"
        }
        $stdoutTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $StdoutPath -NoNewline -Encoding utf8NoBOM
        $stderrTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $StderrPath -NoNewline -Encoding utf8NoBOM
        return $process.ExitCode
    } finally { $process.Dispose() }
}
function Get-Inputs {
    $entries = [ordered]@{}
    $entries.commonNativeInput = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $realLlvmRoot
    foreach ($entry in @(
        @{ Name = 'runner'; Path = $PSCommandPath },
        @{ Name = 'contract'; Path = $contractPath },
        @{ Name = 'compiler'; Path = $compilerPath },
        @{ Name = 'positiveSource'; Path = $sourcePath },
        @{ Name = 'realClang'; Path = $realClang },
        @{ Name = 'fakeClangSource'; Path = $fakeClangSource },
        @{ Name = 'fakeClang'; Path = $fakeClang }
    )) { $entries[$entry.Name] = Get-Sha $entry.Path }
    return $entries
}
function Save-Result {
    $json = $result | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
}

if (-not $IsWindows) { throw 'OUTPUT_PLATFORM_UNSUPPORTED: this gate requires windows-x64' }
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = Resolve-Input $Compiler
$sourcePath = Resolve-Input $PositiveSource
$stdlibPath = Resolve-Input $StdlibRoot
$realLlvmRoot = Resolve-Input $LlvmRoot
$realClang = Join-Path $realLlvmRoot 'bin/clang.exe'
$contractPath = Join-Path $root 'scripts/contracts/c476-output-transaction.json'
if (-not (Test-Path -LiteralPath $realClang -PathType Leaf)) { throw "OUTPUT_CLANG_MISSING: $realClang" }
if ($CompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) {
    throw 'OUTPUT_COMPILER_IDENTITY: compiler SHA-256 differs from the pinned input'
}
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
foreach ($name in @('linkerFailureFresh', 'existingSentinelLinkerFailure')) {
    if ($contract.scenarios.$name.given.failurePoint -cne 'linker' -or $contract.scenarios.$name.proofStatus -cne 'not-run') {
        throw "OUTPUT_CONTRACT_INVALID: $name"
    }
}
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_PATH_INVALID: output must be below $scratchRoot"
}
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PATH_EXISTS: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$fakeLlvmRoot = Join-Path $outputPath 'fake-llvm'
$fakeBin = Join-Path $fakeLlvmRoot 'bin'
[void][IO.Directory]::CreateDirectory($fakeBin)
$fakeClangSource = Join-Path $outputPath 'fail-clang.c'
$fakeClang = Join-Path $fakeBin 'clang.exe'
[IO.File]::WriteAllText($fakeClangSource, "#include <stdio.h>`nint main(void) { fputs(`"C476 injected linker failure\n`", stderr); return 42; }`n", [Text.UTF8Encoding]::new($false))
$fakeBuildExit = Invoke-Captured $realClang @('-x', 'c', $fakeClangSource, '-o', $fakeClang) $outputPath (Join-Path $outputPath 'fake-clang.stdout.txt') (Join-Path $outputPath 'fake-clang.stderr.txt')
if ($fakeBuildExit -ne 0 -or -not (Test-Path -LiteralPath $fakeClang -PathType Leaf)) { throw 'OUTPUT_FAKE_CLANG_BUILD_FAILED' }
$inputsStart = Get-Inputs
$resultPath = Join-Path $outputPath 'result.json'
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-linker-failure'; state = 'running'
    compilerSha256 = $inputsStart.compiler; inputHashesStart = $inputsStart; inputHashesEnd = $null
    inputStable = $false; passed = 0; total = 2; cases = [ordered]@{}; failureId = $null; failure = $null
}
Save-Result
try {
    foreach ($name in @('linkerFailureFresh', 'existingSentinelLinkerFailure')) {
        if ((ConvertTo-Json (Get-Inputs) -Compress) -cne (ConvertTo-Json $inputsStart -Compress)) { throw 'OUTPUT_INPUT_DRIFT: before case' }
        $caseDir = Join-Path $outputPath $name
        $artifactDir = Join-Path $caseDir 'artifacts'
        [void][IO.Directory]::CreateDirectory($artifactDir)
        $exe = Join-Path $artifactDir 'probe.exe'
        $ll = "$exe.ll"
        $sentinel = $name -ceq 'existingSentinelLinkerFailure'
        if ($sentinel) {
            [IO.File]::WriteAllText($exe, 'C476-existing-executable-sentinel')
            [IO.File]::WriteAllText($ll, 'C476-existing-llvm-sentinel')
            $exeBefore = Get-Sha $exe
            $llBefore = Get-Sha $ll
        }
        $stdoutPath = Join-Path $caseDir 'build.stdout.txt'
        $stderrPath = Join-Path $caseDir 'build.stderr.txt'
        $args = @('build', $sourcePath, '-o', $exe, '--target', 'windows-x64', '--llvm', $fakeLlvmRoot, '--stdlib', $stdlibPath, '--jobs', '1', '-O1')
        if ($sentinel) { $args += '--keep-temps' }
        $exitCode = Invoke-Captured $compilerPath $args $caseDir $stdoutPath $stderrPath
        $names = @([IO.Directory]::GetFileSystemEntries($artifactDir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
        $expected = if ($sentinel) { @('probe.exe', 'probe.exe.ll') } else { @() }
        if ($exitCode -ne 42 -or ($names -join '|') -cne ($expected -join '|')) { throw "OUTPUT_LINKER_FAILURE_ARTIFACTS: $name exit=$exitCode files=$($names -join ',')" }
        if ((Get-Content -LiteralPath $stderrPath -Raw) -cnotmatch 'C476 injected linker failure') { throw "OUTPUT_LINKER_DIAGNOSTIC_MISSING: $name" }
        if ((Get-Content -LiteralPath $stdoutPath -Raw) -cnotmatch 'sollang: native linker failed with exit code 42') { throw "OUTPUT_LINKER_STATUS_MISSING: $name" }
        if ($sentinel -and ((Get-Sha $exe) -cne $exeBefore -or (Get-Sha $ll) -cne $llBefore)) { throw "OUTPUT_LINKER_SENTINEL_CHANGED: $name" }
        $result.cases[$name] = [ordered]@{ state = 'passed'; exitCode = $exitCode; artifactNames = $names; existingFilesPreserved = $true; diagnosticPresent = $true; buildStdoutPath = $stdoutPath; buildStderrPath = $stderrPath }
        $result.passed++
        Save-Result
    }
    $result.inputHashesEnd = Get-Inputs
    $result.inputStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    if (-not $result.inputStable) { throw 'OUTPUT_INPUT_DRIFT: after cases' }
    $result.state = 'passed'
    Save-Result
    Write-Host "[C476 linker failure] 2/2 passed; $resultPath"
} catch {
    $result.state = 'failed'
    $result.failure = $_.Exception.Message
    $result.failureId = if ($result.failure -match '^OUTPUT_[A-Z_]+:') { ($result.failure -split ':')[0] } else { 'OUTPUT_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-Inputs
    $result.inputStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    Save-Result
    throw
}
