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
$root = [IO.Path]::GetFullPath($RepositoryRoot)
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
        if (-not $process.Start()) { throw "OUTPUT_SPAWN_HELPER_FAILED: $File" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "OUTPUT_PROCESS_TIMEOUT: $File"
        }
        [IO.File]::WriteAllText($StdoutPath, $stdoutTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($StderrPath, $stderrTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        return $process.ExitCode
    } finally { $process.Dispose() }
}
function Get-Inputs {
    return [ordered]@{
        commonNativeInput = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
        runner = Get-Sha $PSCommandPath; contract = Get-Sha $contractPath
        compiler = Get-Sha $compilerPath; positiveSource = Get-Sha $sourcePath
        launcherSource = Get-Sha $launcherSource; launcher = Get-Sha $launcherPath
        absentChildImage = $fakeChild
    }
}
function Save-Result { [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false)) }

if (-not $IsWindows) { throw 'OUTPUT_PLATFORM_UNSUPPORTED: this gate requires windows-x64' }
$compilerPath = Resolve-Input $Compiler
$sourcePath = Resolve-Input $PositiveSource
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$clangPath = Join-Path $llvmPath 'bin/clang.exe'
$contractPath = Resolve-Input 'scripts/contracts/c476-output-transaction.json'
$launcherSource = Resolve-Input 'scripts/probes/c476-spawn-argv0-launcher.c'
if ($CompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) { throw 'OUTPUT_COMPILER_IDENTITY' }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.scenarios.spawnFailure.given.failurePoint -cne 'spawn' -or $contract.scenarios.spawnFailure.technique -cne 'fault-injection') { throw 'OUTPUT_CONTRACT_INVALID' }
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_PATH_INVALID' }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PATH_EXISTS: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$launcherPath = Join-Path $outputPath 'launcher.exe'
$buildOut = Join-Path $outputPath 'launcher-build.stdout.txt'
$buildErr = Join-Path $outputPath 'launcher-build.stderr.txt'
$buildExit = Invoke-Captured $clangPath @($launcherSource, '-o', $launcherPath) $outputPath $buildOut $buildErr
if ($buildExit -ne 0 -or -not (Test-Path -LiteralPath $launcherPath -PathType Leaf) -or
    (Get-Item -LiteralPath $buildOut).Length -ne 0 -or (Get-Item -LiteralPath $buildErr).Length -ne 0) { throw 'OUTPUT_SPAWN_HELPER_BUILD_FAILED' }
$fakeChild = Join-Path $outputPath 'absent-emitter.exe'
if (Test-Path -LiteralPath $fakeChild) { throw 'OUTPUT_SPAWN_FAULT_IMAGE_EXISTS' }
$caseDir = Join-Path $outputPath 'spawnFailure'
$artifactDir = Join-Path $caseDir 'artifacts'
[void][IO.Directory]::CreateDirectory($artifactDir)
$exe = Join-Path $artifactDir 'probe.exe'
$rawArguments = 'build "' + $sourcePath + '" -o "' + $exe + '" --target windows-x64 --llvm "' + $llvmPath + '" --stdlib "' + $stdlibPath + '" --jobs 1 -O1 --keep-temps'
$inputsStart = Get-Inputs
$resultPath = Join-Path $outputPath 'result.json'
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-spawn-failure'; state = 'running'
    injection = 'real compiler image with absent argv0 used only for its emitter child'
    compilerSha256 = $inputsStart.compiler; inputHashesStart = $inputsStart; inputHashesEnd = $null
    inputsStable = $false; passed = 0; total = 1; failureId = $null; failure = $null
    case = [ordered]@{ state = 'running'; exitCode = $null; diagnosticPresent = $false
        artifactNames = @(); stdoutPath = Join-Path $caseDir 'build.stdout.txt'
        stderrPath = Join-Path $caseDir 'build.stderr.txt' }
}
Save-Result
try {
    $result.case.exitCode = Invoke-Captured $launcherPath @($compilerPath, $fakeChild, $rawArguments) $caseDir $result.case.stdoutPath $result.case.stderrPath
    $result.case.artifactNames = @([IO.Directory]::GetFileSystemEntries($artifactDir) | ForEach-Object { [IO.Path]::GetFileName($_) })
    $result.case.diagnosticPresent = [IO.File]::ReadAllText($result.case.stderrPath).Contains('sollang: spawn', [StringComparison]::Ordinal)
    if ($result.case.exitCode -eq 0 -or -not $result.case.diagnosticPresent -or
        $result.case.artifactNames.Count -ne 0 -or (Get-Item -LiteralPath $result.case.stdoutPath).Length -ne 0 -or
        (Test-Path -LiteralPath $fakeChild)) { throw 'OUTPUT_SPAWN_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-Inputs
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    if (-not $result.inputsStable) { throw 'OUTPUT_INPUT_DRIFT' }
    $result.case.state = 'passed'
    $result.passed = 1
    $result.state = 'passed'
    Save-Result
    Write-Host "[C476 spawn failure] 1/1 passed; $resultPath"
} catch {
    $result.state = 'failed'
    $result.case.state = 'failed'
    $result.failure = $_.Exception.Message
    $result.failureId = if ($result.failure -match '^OUTPUT_[A-Z_]+') { ($result.failure -split ':')[0] } else { 'OUTPUT_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-Inputs
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    Save-Result
    throw
}
