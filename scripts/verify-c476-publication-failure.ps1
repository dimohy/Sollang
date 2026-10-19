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
function Get-Inputs {
    return [ordered]@{
        commonNativeInput = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
        runner = Get-Sha $PSCommandPath; contract = Get-Sha $contractPath
        compiler = Get-Sha $compilerPath; positiveSource = Get-Sha $sourcePath
    }
}
function Save-Result { [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false)) }

if (-not $IsWindows) { throw 'OUTPUT_PLATFORM_UNSUPPORTED: this gate requires windows-x64' }
$compilerPath = Resolve-Input $Compiler
$sourcePath = Resolve-Input $PositiveSource
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$contractPath = Resolve-Input 'scripts/contracts/c476-output-transaction.json'
if ($CompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) { throw 'OUTPUT_COMPILER_IDENTITY' }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.scenarios.publicationFailure.given.failurePoint -cne 'publication' -or
    $contract.scenarios.publicationFailure.technique -cne 'fault-injection') { throw 'OUTPUT_CONTRACT_INVALID' }
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_PATH_INVALID' }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PATH_EXISTS: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$caseDir = Join-Path $outputPath 'publicationFailure'
$artifactDir = Join-Path $caseDir 'artifacts'
[void][IO.Directory]::CreateDirectory($artifactDir)
$exe = Join-Path $artifactDir 'probe.exe'
$ll = "$exe.ll"
[IO.File]::WriteAllText($exe, 'C476-existing-executable-sentinel', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($ll, 'C476-existing-llvm-sentinel', [Text.UTF8Encoding]::new($false))
$exeBefore = Get-Sha $exe
$llBefore = Get-Sha $ll
$inputsStart = Get-Inputs
$resultPath = Join-Path $outputPath 'result.json'
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-publication-failure'; state = 'running'
    compilerSha256 = $inputsStart.compiler; inputHashesStart = $inputsStart; inputHashesEnd = $null
    inputsStable = $false; passed = 0; total = 1; failureId = $null; failure = $null
    case = [ordered]@{ state = 'running'; exitCode = $null; existingExecutablePreserved = $false
        existingLlvmPreserved = $false; diagnosticPresent = $false; artifactNames = @()
        stdoutPath = Join-Path $caseDir 'build.stdout.txt'; stderrPath = Join-Path $caseDir 'build.stderr.txt' }
}
Save-Result
$hold = $null
$process = $null
try {
    $hold = [IO.File]::Open($ll, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $compilerPath
    $start.WorkingDirectory = $caseDir
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @('build', $sourcePath, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps')) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'OUTPUT_PUBLICATION_SPAWN_FAILED' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMilliseconds)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw 'OUTPUT_PUBLICATION_TIMEOUT'
    }
    $result.case.exitCode = $process.ExitCode
    [IO.File]::WriteAllText($result.case.stdoutPath, $stdoutTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($result.case.stderrPath, $stderrTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
    $hold.Dispose()
    $hold = $null
    $result.case.existingExecutablePreserved = (Get-Sha $exe) -ceq $exeBefore
    $result.case.existingLlvmPreserved = (Get-Sha $ll) -ceq $llBefore
    $result.case.diagnosticPresent = [IO.File]::ReadAllText($result.case.stderrPath).Contains('sollang: native build publication failed:', [StringComparison]::Ordinal)
    $result.case.artifactNames = @([IO.Directory]::GetFileSystemEntries($artifactDir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
    if ($result.case.exitCode -eq 0 -or -not $result.case.existingExecutablePreserved -or
        -not $result.case.existingLlvmPreserved -or -not $result.case.diagnosticPresent -or
        ($result.case.artifactNames -join '|') -cne 'probe.exe|probe.exe.ll' -or
        (Get-Item -LiteralPath $result.case.stdoutPath).Length -ne 0) { throw 'OUTPUT_PUBLICATION_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-Inputs
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    if (-not $result.inputsStable) { throw 'OUTPUT_INPUT_DRIFT' }
    $result.case.state = 'passed'
    $result.passed = 1
    $result.state = 'passed'
    Save-Result
    Write-Host "[C476 publication failure] 1/1 passed; $resultPath"
} catch {
    if ($null -ne $process -and -not $process.HasExited) { try { $process.Kill($true); $process.WaitForExit() } catch { } }
    if ($null -ne $hold) { $hold.Dispose(); $hold = $null }
    $result.state = 'failed'
    $result.case.state = 'failed'
    $result.failure = $_.Exception.Message
    $result.failureId = if ($result.failure -match '^OUTPUT_[A-Z_]+') { ($result.failure -split ':')[0] } else { 'OUTPUT_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-Inputs
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    Save-Result
    throw
} finally {
    if ($null -ne $hold) { $hold.Dispose() }
    if ($null -ne $process) { $process.Dispose() }
}
