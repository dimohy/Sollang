[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$CompilerSha256,
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
function Start-Captured([string]$File, [string[]]$Arguments, [string]$WorkDirectory, [string]$Prefix) {
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
    if (-not $process.Start()) { throw "OUTPUT_SPAWN_FAILED: $File" }
    $stdout = [IO.File]::Create("$Prefix.stdout.txt")
    $stderr = [IO.File]::Create("$Prefix.stderr.txt")
    return [pscustomobject]@{
        Process = $process; Stdout = $stdout; Stderr = $stderr
        OutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        ErrCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        StdoutPath = "$Prefix.stdout.txt"; StderrPath = "$Prefix.stderr.txt"
    }
}
function Wait-Captured([object]$Child) {
    if (-not $Child.Process.WaitForExit($TimeoutMilliseconds)) {
        $Child.Process.Kill($true)
        $Child.Process.WaitForExit()
        throw "OUTPUT_PROCESS_TIMEOUT: $($Child.Process.Id)"
    }
    if (-not [Threading.Tasks.Task]::WaitAll(@($Child.OutCopy, $Child.ErrCopy), 5000)) {
        throw "OUTPUT_LOG_DRAIN_TIMEOUT: $($Child.Process.Id)"
    }
    $Child.Stdout.Dispose()
    $Child.Stderr.Dispose()
    $exitCode = $Child.Process.ExitCode
    $Child.Process.Dispose()
    return $exitCode
}
function Get-InputHashes {
    return [ordered]@{
        commonNativeInput = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
        runner = Get-Sha $PSCommandPath; contract = Get-Sha $contractPath
        compiler = Get-Sha $compilerPath; sourceA = Get-Sha $sourceA; sourceB = Get-Sha $sourceB
        clang = Get-Sha $clangPath
    }
}
function Save-Result { [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false)) }
function Invoke-Native([string]$Exe, [string]$Directory, [string]$Prefix) {
    $child = Start-Captured $Exe @() $Directory $Prefix
    return Wait-Captured $child
}
function Assert-LlvmAndNative([string]$Exe, [string]$Directory, [string]$Prefix, [string]$ExpectedMarker) {
    $ll = "$Exe.ll"
    if (-not (Test-Path -LiteralPath $Exe -PathType Leaf) -or -not (Test-Path -LiteralPath $ll -PathType Leaf)) {
        throw "OUTPUT_ARTIFACT_MISSING: $Exe"
    }
    $llvmText = [IO.File]::ReadAllText($ll)
    if ($llvmText -notmatch '(?m)^define\s' -or -not $llvmText.Contains($ExpectedMarker, [StringComparison]::Ordinal)) {
        throw "OUTPUT_LLVM_MARKER_MISMATCH: $ll expected $ExpectedMarker"
    }
    $exit = Invoke-Native $Exe $Directory $Prefix
    if ($exit -ne 0 -or [IO.File]::ReadAllText("$Prefix.stdout.txt") -cne "$ExpectedMarker`n" -or (Get-Item -LiteralPath "$Prefix.stderr.txt").Length -ne 0) {
        throw "OUTPUT_NATIVE_MARKER_MISMATCH: $Exe expected $ExpectedMarker"
    }
}
function Assert-Names([string]$Directory, [string[]]$Expected) {
    $actual = @([IO.Directory]::GetFileSystemEntries($Directory) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
    $sorted = @($Expected | Sort-Object)
    if (($actual -join '|') -cne ($sorted -join '|')) { throw "OUTPUT_ARTIFACT_SET: actual=$($actual -join ',') expected=$($sorted -join ',')" }
}

if (-not $IsWindows) { throw 'OUTPUT_PLATFORM_UNSUPPORTED: this gate requires windows-x64' }
$compilerPath = Resolve-Input $Compiler
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$clangPath = Join-Path $llvmPath 'bin/clang.exe'
$contractPath = Resolve-Input 'scripts/contracts/c476-output-transaction.json'
if ((Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) { throw 'OUTPUT_COMPILER_IDENTITY' }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
foreach ($name in @('sameOutputParallel', 'differentOutputParallel')) {
    if ($contract.scenarios.$name.technique -cne 'parallel-process') { throw "OUTPUT_CONTRACT_INVALID: $name" }
}
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'OUTPUT_PATH_INVALID' }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PATH_EXISTS: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$sourceA = Join-Path $outputPath 'first.slg'
$sourceB = Join-Path $outputPath 'second.slg'
[IO.File]::WriteAllText($sourceA, "main { `"C476-A`" -> println }`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($sourceB, "main { `"C476-B`" -> println }`n", [Text.UTF8Encoding]::new($false))
$inputStart = Get-InputHashes
$resultPath = Join-Path $outputPath 'result.json'
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-concurrency'; state = 'running'
    compilerSha256 = $inputStart.compiler; inputHashesStart = $inputStart; inputHashesEnd = $null; inputsStable = $false
    passed = 0; total = 2; cases = [ordered]@{}; failureId = $null; failure = $null
}
Save-Result
$first = $null
$second = $null
try {
    $sameDir = Join-Path $outputPath 'sameOutputParallel'
    $sameArtifacts = Join-Path $sameDir 'artifacts'
    [void][IO.Directory]::CreateDirectory($sameArtifacts)
    $sameExe = Join-Path $sameArtifacts 'probe.exe'
    $common = @('--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps')
    $first = Start-Captured $compilerPath (@('build', $sourceA, '-o', $sameExe) + $common) $sameDir (Join-Path $sameDir 'first.build')
    $lockPath = "$sameExe.sollang-txn-lock"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $lockObserved = $false
    while ($watch.ElapsedMilliseconds -lt $TimeoutMilliseconds -and -not $first.Process.HasExited) {
        if (Test-Path -LiteralPath $lockPath -PathType Leaf) { $lockObserved = $true; break }
        Start-Sleep -Milliseconds 10
    }
    if (-not $lockObserved) { throw 'OUTPUT_SAME_LOCK_NOT_OBSERVED' }
    $second = Start-Captured $compilerPath (@('build', $sourceB, '-o', $sameExe) + $common) $sameDir (Join-Path $sameDir 'second.build')
    $overlapObserved = -not $first.Process.HasExited
    $secondExit = Wait-Captured $second
    $second = $null
    $firstExit = Wait-Captured $first
    $first = $null
    if (-not $overlapObserved -or $firstExit -ne 0 -or $secondExit -eq 0) { throw "OUTPUT_SAME_PARALLEL_RESULT: first=$firstExit second=$secondExit overlap=$overlapObserved" }
    if ([IO.File]::ReadAllText((Join-Path $sameDir 'second.build.stderr.txt')) -notmatch '(?is)sollang:.*(lock|busy|in use|reserved|already)') { throw 'OUTPUT_SAME_LOCK_DIAGNOSTIC_MISSING' }
    Assert-Names $sameArtifacts @('probe.exe', 'probe.exe.ll')
    Assert-LlvmAndNative $sameExe $sameDir (Join-Path $sameDir 'native') 'C476-A'
    $result.cases.sameOutputParallel = [ordered]@{ state = 'passed'; firstExit = $firstExit; secondExit = $secondExit; lockObserved = $lockObserved; overlapObserved = $overlapObserved; nativeMarker = 'C476-A' }
    $result.passed++
    Save-Result

    $differentDir = Join-Path $outputPath 'differentOutputParallel'
    $differentArtifacts = Join-Path $differentDir 'artifacts'
    [void][IO.Directory]::CreateDirectory($differentArtifacts)
    $exeA = Join-Path $differentArtifacts 'a.exe'
    $exeB = Join-Path $differentArtifacts 'b.exe'
    $first = Start-Captured $compilerPath (@('build', $sourceA, '-o', $exeA) + $common) $differentDir (Join-Path $differentDir 'first.build')
    $second = Start-Captured $compilerPath (@('build', $sourceB, '-o', $exeB) + $common) $differentDir (Join-Path $differentDir 'second.build')
    $differentOverlap = -not $first.Process.HasExited -and -not $second.Process.HasExited
    $secondExit = Wait-Captured $second
    $second = $null
    $firstExit = Wait-Captured $first
    $first = $null
    if (-not $differentOverlap -or $firstExit -ne 0 -or $secondExit -ne 0) { throw "OUTPUT_DIFFERENT_PARALLEL_RESULT: first=$firstExit second=$secondExit overlap=$differentOverlap" }
    Assert-Names $differentArtifacts @('a.exe', 'a.exe.ll', 'b.exe', 'b.exe.ll')
    Assert-LlvmAndNative $exeA $differentDir (Join-Path $differentDir 'a.native') 'C476-A'
    Assert-LlvmAndNative $exeB $differentDir (Join-Path $differentDir 'b.native') 'C476-B'
    $result.cases.differentOutputParallel = [ordered]@{ state = 'passed'; firstExit = $firstExit; secondExit = $secondExit; overlapObserved = $differentOverlap; nativeMarkers = @('C476-A', 'C476-B') }
    $result.passed++
    $result.inputHashesEnd = Get-InputHashes
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    if (-not $result.inputsStable) { throw 'OUTPUT_INPUT_DRIFT' }
    $result.state = 'passed'
    Save-Result
    Write-Host "[C476 output concurrency] 2/2 passed; $resultPath"
} catch {
    foreach ($child in @($second, $first)) {
        if ($null -ne $child) {
            try { $child.Process.Kill($true) } catch { }
            try { $child.Process.WaitForExit(5000) | Out-Null } catch { }
            try { $child.Stdout.Dispose(); $child.Stderr.Dispose(); $child.Process.Dispose() } catch { }
        }
    }
    $result.state = 'failed'
    $result.failure = $_.Exception.Message
    $result.failureId = if ($result.failure -match '^OUTPUT_[A-Z_]+') { ($result.failure -split ':')[0] } else { 'OUTPUT_ASSERTION_FAILED' }
    $result.inputHashesEnd = Get-InputHashes
    $result.inputsStable = (ConvertTo-Json $result.inputHashesStart -Compress) -ceq (ConvertTo-Json $result.inputHashesEnd -Compress)
    Save-Result
    throw
}
