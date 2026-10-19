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
        injectedMissingRoot = $missingRoot
    }
}
function Save-Result { [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false)) }
function Invoke-Compiler([string[]]$Arguments, [string]$WorkDirectory, [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $compilerPath
    $start.WorkingDirectory = $WorkDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'OUTPUT_EMITTER_SPAWN_FAILED' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'OUTPUT_EMITTER_TIMEOUT'
        }
        [IO.File]::WriteAllText($StdoutPath, $stdoutTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($StderrPath, $stderrTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        return $process.ExitCode
    } finally { $process.Dispose() }
}

if (-not $IsWindows) { throw 'OUTPUT_PLATFORM_UNSUPPORTED: this gate requires windows-x64' }
$compilerPath = Resolve-Input $Compiler
$sourcePath = Resolve-Input $PositiveSource
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$contractPath = Resolve-Input 'scripts/contracts/c476-output-transaction.json'
if ($CompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) { throw 'OUTPUT_COMPILER_IDENTITY' }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
foreach ($name in @('emitterFailureFresh', 'existingSentinelEmitterFailure')) {
    if ($contract.scenarios.$name.given.failurePoint -cne 'emitter' -or $contract.scenarios.$name.technique -cne 'fault-injection') { throw "OUTPUT_CONTRACT_INVALID: $name" }
}
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_PATH_INVALID' }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PATH_EXISTS: $outputPath" }
$missingRoot = Join-Path $outputPath 'injected-missing-stdlib'
if (Test-Path -LiteralPath $missingRoot) { throw 'OUTPUT_EMITTER_FAULT_PATH_EXISTS' }
$inputsStart = Get-Inputs
[void][IO.Directory]::CreateDirectory($outputPath)
$resultPath = Join-Path $outputPath 'result.json'
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-emitter-failure'; state = 'running'
    injection = 'missing stdlib root in child emitter after output-stage claim'
    compilerSha256 = $inputsStart.compiler; inputHashesStart = $inputsStart; inputHashesEnd = $null
    inputsStable = $false; passed = 0; total = 2; cases = [ordered]@{}; failureId = $null; failure = $null
}
Save-Result
try {
    foreach ($name in @('emitterFailureFresh', 'existingSentinelEmitterFailure')) {
        if (Test-Path -LiteralPath $missingRoot) { throw 'OUTPUT_EMITTER_FAULT_PATH_CHANGED' }
        if ((ConvertTo-Json (Get-Inputs) -Compress) -cne (ConvertTo-Json $inputsStart -Compress)) { throw 'OUTPUT_INPUT_DRIFT' }
        $caseDir = Join-Path $outputPath $name
        $artifactDir = Join-Path $caseDir 'artifacts'
        [void][IO.Directory]::CreateDirectory($artifactDir)
        $exe = Join-Path $artifactDir 'probe.exe'
        $ll = "$exe.ll"
        $sentinel = $name -ceq 'existingSentinelEmitterFailure'
        if ($sentinel) {
            [IO.File]::WriteAllText($exe, 'C476-existing-executable-sentinel', [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($ll, 'C476-existing-llvm-sentinel', [Text.UTF8Encoding]::new($false))
            $exeBefore = Get-Sha $exe
            $llBefore = Get-Sha $ll
        }
        $stdoutPath = Join-Path $caseDir 'build.stdout.txt'
        $stderrPath = Join-Path $caseDir 'build.stderr.txt'
        $arguments = @('build', $sourcePath, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $missingRoot, '--jobs', '1', '-O1')
        if ($sentinel) { $arguments += '--keep-temps' }
        $exitCode = Invoke-Compiler $arguments $caseDir $stdoutPath $stderrPath
        $names = @([IO.Directory]::GetFileSystemEntries($artifactDir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
        $expected = if ($sentinel) { @('probe.exe', 'probe.exe.ll') } else { @() }
        $preserved = -not $sentinel -or ((Get-Sha $exe) -ceq $exeBefore -and (Get-Sha $ll) -ceq $llBefore)
        $diagnostic = [IO.File]::ReadAllText($stderrPath).Contains('sollang source root error: source root contains no readable .slg files', [StringComparison]::Ordinal)
        if ($exitCode -eq 0 -or -not $preserved -or -not $diagnostic -or
            ($names -join '|') -cne ($expected -join '|') -or (Get-Item -LiteralPath $stdoutPath).Length -ne 0) {
            throw "OUTPUT_EMITTER_ASSERTION_FAILED: $name exit=$exitCode files=$($names -join ',')"
        }
        $result.cases[$name] = [ordered]@{ state = 'passed'; exitCode = $exitCode; artifactNames = $names
            existingFilesPreserved = [bool]$preserved; diagnosticPresent = [bool]$diagnostic
            stdoutPath = $stdoutPath; stderrPath = $stderrPath }
        $result.passed++
        Save-Result
    }
    $result.inputHashesEnd = Get-Inputs
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress) -and -not (Test-Path -LiteralPath $missingRoot)
    if (-not $result.inputsStable) { throw 'OUTPUT_INPUT_DRIFT' }
    $result.state = 'passed'
    Save-Result
    Write-Host "[C476 emitter failure] 2/2 passed; $resultPath"
} catch {
    $result.state = 'failed'
    $result.failure = $_.Exception.Message
    $result.failureId = if ($result.failure -match '^OUTPUT_[A-Z_]+') { ($result.failure -split ':')[0] } else { 'OUTPUT_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-Inputs
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    Save-Result
    throw
}
