[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedDllSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [Parameter(ParameterSetName = 'Run')][switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [int]$TimeoutMilliseconds = 180000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Resolve-File([string]$Path) {
    $candidate = if ([IO.Path]::IsPathFullyQualified($Path)) { $Path } else { Join-Path $root $Path }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "UNICODE_PARENT_INPUT_MISSING: $candidate" }
    (Resolve-Path -LiteralPath $candidate).Path
}
function Verify-Sha([string]$Path, [string]$Expected) {
    if ((Sha $Path) -cne $Expected) { throw "UNICODE_PARENT_INPUT_SHA_MISMATCH: $Path" }
}
function Invoke-Pinned([string]$Executable, [string[]]$Arguments, [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "UNICODE_PARENT_PROCESS_START: $Executable" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "UNICODE_PARENT_PROCESS_TIMEOUT: $Executable"
        }
        [IO.File]::WriteAllText($StdoutPath, $stdoutTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($StderrPath, $stderrTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
        $process.ExitCode
    } finally { $process.Dispose() }
}
function Input-Fingerprint {
    $lines = foreach ($file in $inputs) { "$file|$(Sha $file)" }
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))
}
function Write-Result([string]$Path, [object]$Record) {
    $temporary = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    [IO.File]::WriteAllText($temporary, ($Record | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $Path, $true)
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$fixture = Resolve-File 'scripts/probes/file/windows-unicode-parent-process.slg'
$expectedOutput = [Text.Encoding]::UTF8.GetBytes("unicode parent ok`n")
$expectedChild = [Text.Encoding]::UTF8.GetBytes("unicode child`n")
if ($SelfTest) {
    if ($expectedOutput.Length -ne 18 -or $expectedChild.Length -ne 14) { throw 'UNICODE_PARENT_CONTRACT_INVALID' }
    Write-Host '[Windows Unicode parent] PASS contract'
    return
}
$managed = Resolve-File $ManagedCompiler
$managedDll = Resolve-File (Join-Path (Split-Path -Parent $managed) 'Sollang.Compiler.dll')
$selfhost = Resolve-File $SelfhostCompiler
Verify-Sha $managed $ManagedCompilerSha256
Verify-Sha $managedDll $ManagedDllSha256
Verify-Sha $selfhost $SelfhostCompilerSha256
$llvm = if ([IO.Path]::IsPathFullyQualified($LlvmRoot)) { $LlvmRoot } else { Join-Path $root $LlvmRoot }
$llvm = (Resolve-Path -LiteralPath $llvm).Path
$llvmAs = Resolve-File (Join-Path $llvm 'bin/llvm-as.exe')
$clang = Resolve-File (Join-Path $llvm 'bin/clang.exe')
$stdlib = (Resolve-Path -LiteralPath (Join-Path $root 'stdlib')).Path
$stdlibSources = @([IO.Directory]::GetFiles($stdlib, '*.slg', [IO.SearchOption]::AllDirectories))
[Array]::Sort($stdlibSources, [StringComparer]::Ordinal)
$inputs = @($PSCommandPath, $fixture, $managed, $managedDll, $selfhost, $llvmAs, $clang) + $stdlibSources
$fingerprintStart = Input-Fingerprint
if ($ValidateInputsOnly) {
    Write-Host "[Windows Unicode parent] PASS inputs $fingerprintStart"
    return
}
$output = if ([IO.Path]::IsPathFullyQualified($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }
if (Test-Path -LiteralPath $output) { throw "UNICODE_PARENT_OUTPUT_EXISTS: $output" }
[void](New-Item -ItemType Directory -Path $output)
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1; gate = 'windows-unicode-parent-process'; state = 'running'
    total = 4; completed = 0; passed = 0; failureId = $null
    fixtureSha256 = Sha $fixture; managedSha256 = Sha $managed; managedDllSha256 = Sha $managedDll
    selfhostSha256 = Sha $selfhost; inputFingerprintStart = $fingerprintStart
    inputFingerprintEnd = $null; inputsStable = $false; cases = @(); orphanProcessIds = @()
}
Write-Result $resultPath $record
try {
    foreach ($compiler in @(
        [pscustomobject]@{ id = 'managed'; path = $managed },
        [pscustomobject]@{ id = 'selfhost'; path = $selfhost }
    )) {
        $compilerDirectory = Join-Path $output $compiler.id
        [void](New-Item -ItemType Directory -Path $compilerDirectory)
        $product = Join-Path $compilerDirectory 'probe.exe'
        $buildArgs = @('build', $fixture, '-o', $product, '--target', 'windows-x64', '--llvm', $llvm)
        if ($compiler.id -eq 'selfhost') { $buildArgs += @('--stdlib', $stdlib, '--jobs', '1') }
        $buildArgs += @('-O1', '--keep-temps')
        $buildExit = Invoke-Pinned $compiler.path $buildArgs (Join-Path $compilerDirectory 'build.stdout.txt') (Join-Path $compilerDirectory 'build.stderr.txt')
        if ($buildExit -ne 0) { throw "UNICODE_PARENT_BUILD_EXIT: $($compiler.id)" }
        $buildText = [IO.File]::ReadAllText((Join-Path $compilerDirectory 'build.stdout.txt')) + [IO.File]::ReadAllText((Join-Path $compilerDirectory 'build.stderr.txt'))
        if ($buildText -match '(?im)\b(?:warning|note)\s*:|\b(?:warning|note)\b|경고\s*\d+') { throw "UNICODE_PARENT_BUILD_WARNING: $($compiler.id)" }
        if ((Get-Item -LiteralPath (Join-Path $compilerDirectory 'build.stderr.txt')).Length -ne 0) { throw "UNICODE_PARENT_BUILD_STDERR: $($compiler.id)" }
        $ll = "$product.ll"
        if (-not (Test-Path -LiteralPath $product -PathType Leaf) -or -not (Test-Path -LiteralPath $ll -PathType Leaf)) { throw "UNICODE_PARENT_BUILD_ARTIFACT: $($compiler.id)" }
        $llvmText = [IO.File]::ReadAllText($ll)
        if ($llvmText -notmatch 'call ptr @CreateFileW\(' -or $llvmText -notmatch 'call i32 @sollang_windows_utf8_path\(') { throw "UNICODE_PARENT_WIDE_CALL_MISSING: $($compiler.id)" }
        $bitcode = Join-Path $compilerDirectory 'probe.bc'
        $asExit = Invoke-Pinned $llvmAs @($ll, '-o', $bitcode) (Join-Path $compilerDirectory 'llvm-as.stdout.txt') (Join-Path $compilerDirectory 'llvm-as.stderr.txt')
        if ($asExit -ne 0) { throw "UNICODE_PARENT_LLVM_AS_EXIT: $($compiler.id)" }
        foreach ($scenario in @('ascii', 'unicode')) {
            $scenarioDirectory = Join-Path $compilerDirectory $scenario
            [void](New-Item -ItemType Directory -Path $scenarioDirectory)
            $parentName = if ($scenario -eq 'ascii') { 'parent' } else { '검증-Ω' }
            $parent = Join-Path $scenarioDirectory $parentName
            $statusPath = Join-Path $parent 'status.txt'
            $stdioPath = Join-Path $parent 'stdio.txt'
            $runOut = Join-Path $scenarioDirectory 'run.stdout.txt'
            $runErr = Join-Path $scenarioDirectory 'run.stderr.txt'
            $runExit = Invoke-Pinned $product @($parent, $statusPath, $stdioPath) $runOut $runErr
            if ($runExit -ne 0) { throw "UNICODE_PARENT_RUN_EXIT: $($compiler.id)/$scenario" }
            if ((Get-Item -LiteralPath $runErr).Length -ne 0) { throw "UNICODE_PARENT_RUN_STDERR: $($compiler.id)/$scenario" }
            if ([Convert]::ToHexString([IO.File]::ReadAllBytes($runOut)) -cne [Convert]::ToHexString($expectedOutput)) { throw "UNICODE_PARENT_STDOUT_MISMATCH: $($compiler.id)/$scenario" }
            $inventory = @((Get-ChildItem -LiteralPath $parent -Force | ForEach-Object Name) | Sort-Object)
            if (($inventory -join '|') -cne 'status.txt|stdio.txt') { throw "UNICODE_PARENT_ARTIFACT_SET: $($compiler.id)/$scenario" }
            foreach ($name in $inventory) {
                if ([Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $parent $name))) -cne [Convert]::ToHexString($expectedChild)) { throw "UNICODE_PARENT_FILE_MISMATCH: $($compiler.id)/$scenario/$name" }
            }
            $record.cases += [ordered]@{
                compiler = $compiler.id; scenario = $scenario; buildExitCode = $buildExit
                llvmAsExitCode = $asExit; runExitCode = $runExit; artifactInventory = $inventory
                compilerSha256 = Sha $compiler.path; exeSha256 = Sha $product; llvmSha256 = Sha $ll
                stdoutSha256 = Sha $runOut; childOutputSha256 = Sha (Join-Path $parent 'status.txt')
            }
            $record.completed++; $record.passed++
            Write-Result $resultPath $record
            Write-Host "[Windows Unicode parent] $($record.completed)/4 $($compiler.id)/$scenario passed"
        }
    }
    $record.inputFingerprintEnd = Input-Fingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'UNICODE_PARENT_INPUT_DRIFT' }
    $record.state = 'passed'
    Write-Result $resultPath $record
} catch {
    $message = $_.Exception.Message
    $record.failureId = if ($message -match '^(UNICODE_PARENT_[A-Z_]+)') { $Matches[1] } else { 'UNICODE_PARENT_VERIFIER_FAILED' }
    $record.inputFingerprintEnd = Input-Fingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    $record.state = 'failed'
    Write-Result $resultPath $record
    throw
}
