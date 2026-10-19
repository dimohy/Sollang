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
    $resolved = if ([IO.Path]::IsPathFullyQualified($Path)) { $Path } else { Join-Path $root $Path }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "UNICODE_INPUT_MISSING: $resolved" }
    (Resolve-Path -LiteralPath $resolved).Path
}
function Verify-Sha([string]$Path, [string]$Expected) {
    if ((Sha $Path) -cne $Expected) { throw "UNICODE_INPUT_SHA_MISMATCH: $Path" }
}
function Inventory([string]$Directory) {
    @((Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name) | Sort-Object)
}
function Assert-Inventory([string]$Directory, [string[]]$Expected) {
    $actual = Inventory $Directory
    if ((@($actual) -join '|') -cne (@($Expected | Sort-Object) -join '|')) {
        throw "UNICODE_ARTIFACT_SET: $Directory actual=$($actual -join ',') expected=$($Expected -join ',')"
    }
    $actual
}
function Invoke-Pinned([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory,
        [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Executable
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "UNICODE_PROCESS_START: $Executable" }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "UNICODE_PROCESS_TIMEOUT: $Executable"
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
    $json = $Record | ConvertTo-Json -Depth 12
    $temporary = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $Path, $true)
}

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$contractPath = Resolve-File 'scripts/contracts/windows-unicode-path-boundary.json'
$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.gate -cne 'windows-unicode-path-boundary' -or
    @($contract.requiredWideCalls).Count -ne 7 -or @($contract.forbiddenNarrowCalls).Count -ne 5) {
    throw 'UNICODE_CONTRACT_INVALID'
}
$fixture = Resolve-File $contract.fixture.path
Verify-Sha $fixture $contract.fixture.sha256
if ($SelfTest) {
    Write-Host '[Windows Unicode path] PASS contract and fixture'
    return
}
$managed = Resolve-File $ManagedCompiler
$managedDll = Join-Path (Split-Path -Parent $managed) 'Sollang.Compiler.dll'
$managedDll = Resolve-File $managedDll
$selfhost = Resolve-File $SelfhostCompiler
Verify-Sha $managed $ManagedCompilerSha256
Verify-Sha $managedDll $ManagedDllSha256
Verify-Sha $selfhost $SelfhostCompilerSha256
$llvm = if ([IO.Path]::IsPathFullyQualified($LlvmRoot)) { $LlvmRoot } else { Join-Path $root $LlvmRoot }
$llvm = (Resolve-Path -LiteralPath $llvm).Path
$llvmAs = Resolve-File (Join-Path $llvm 'bin/llvm-as.exe')
$clang = Resolve-File (Join-Path $llvm 'bin/clang.exe')
$linker = Resolve-File (Join-Path $llvm 'bin/lld-link.exe')
$librarian = Resolve-File (Join-Path $llvm 'bin/llvm-lib.exe')
$stdlib = (Resolve-Path -LiteralPath (Join-Path $root 'stdlib')).Path
$inputs = @($contractPath, $fixture, $managed, $managedDll, $selfhost, $llvmAs,
    $clang, $linker, $librarian, (Resolve-File 'selfhost/llvm/runtime.slg'),
    (Resolve-File 'selfhost/llvm/text/context_prepare.slg'),
    (Resolve-File 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'),
    (Resolve-File 'src/Sollang.Compiler/Tooling/WindowsLinker.cs'), $PSCommandPath)
$fingerprintStart = Input-Fingerprint
if ($ValidateInputsOnly) {
    Write-Host "[Windows Unicode path] PASS inputs $fingerprintStart"
    return
}
$output = if ([IO.Path]::IsPathFullyQualified($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }
if (Test-Path -LiteralPath $output) { throw "UNICODE_OUTPUT_EXISTS: $output" }
[void](New-Item -ItemType Directory -Path $output)
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1; gate = $contract.gate; state = 'running'; total = 2
    completed = 0; passed = 0; failureId = $null; fixtureSha256 = $contract.fixture.sha256
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null
    inputsStable = $false; cases = @(); orphanProcessIds = @()
}
Write-Result $resultPath $record
try {
    foreach ($compiler in @(
        [pscustomobject]@{ id = 'managed'; path = $managed; expected = @($contract.expectedBuildArtifacts.managed) },
        [pscustomobject]@{ id = 'selfhost'; path = $selfhost; expected = @($contract.expectedBuildArtifacts.selfhost) }
    )) {
        $caseDirectory = Join-Path $output $compiler.id
        $work = Join-Path $caseDirectory 'work'
        [void](New-Item -ItemType Directory -Path $work -Force)
        $product = Join-Path $work 'probe.exe'
        $buildOut = Join-Path $caseDirectory 'build.stdout.txt'
        $buildErr = Join-Path $caseDirectory 'build.stderr.txt'
        $buildArgs = @('build', $fixture, '-o', $product, '--target', 'windows-x64',
            '--llvm', $llvm)
        if ($compiler.id -eq 'selfhost') { $buildArgs += @('--stdlib', $stdlib, '--jobs', '1') }
        $buildArgs += @('-O1', '--keep-temps')
        $buildExit = Invoke-Pinned $compiler.path $buildArgs $root $buildOut $buildErr
        if ($buildExit -ne 0) { throw "UNICODE_BUILD_EXIT: $($compiler.id)" }
        $buildText = [IO.File]::ReadAllText($buildOut) + [IO.File]::ReadAllText($buildErr)
        if ($buildText -match '(?im)\b(?:warning|note)\s*:|\b(?:warning|note)\b|경고\s*\d+') {
            throw "UNICODE_BUILD_WARNING: $($compiler.id)"
        }
        if ((Get-Item -LiteralPath $buildErr).Length -ne 0) { throw "UNICODE_BUILD_STDERR: $($compiler.id)" }
        $inventory = Assert-Inventory $work $compiler.expected
        $ll = "$product.ll"
        $llvmText = [IO.File]::ReadAllText($ll)
        foreach ($symbol in $contract.requiredWideCalls) {
            if ($llvmText -notmatch "(?m)call\s+[^`n]*@$symbol\(") {
                throw "UNICODE_WIDE_CALL_MISSING: $($compiler.id)/$symbol"
            }
        }
        foreach ($symbol in $contract.forbiddenNarrowCalls) {
            if ($llvmText -match "(?m)call\s+[^`n]*@$symbol\(") {
                throw "UNICODE_NARROW_CALL_RETAINED: $($compiler.id)/$symbol"
            }
        }
        $bitcode = Join-Path $caseDirectory 'probe.bc'
        $asExit = Invoke-Pinned $llvmAs @($ll, '-o', $bitcode) $root `
            (Join-Path $caseDirectory 'llvm-as.stdout.txt') (Join-Path $caseDirectory 'llvm-as.stderr.txt')
        if ($asExit -ne 0) { throw "UNICODE_LLVM_AS_EXIT: $($compiler.id)" }
        $runOut = Join-Path $caseDirectory 'run.stdout.txt'
        $runErr = Join-Path $caseDirectory 'run.stderr.txt'
        $runExit = Invoke-Pinned $product @() $root $runOut $runErr
        if ($runExit -ne 0) { throw "UNICODE_RUN_EXIT: $($compiler.id)" }
        if ((Get-Item -LiteralPath $runErr).Length -ne 0) { throw "UNICODE_RUN_STDERR: $($compiler.id)" }
        $expectedBytes = [Text.Encoding]::UTF8.GetBytes($contract.expectedStdout)
        $actualBytes = [IO.File]::ReadAllBytes($runOut)
        if ([Convert]::ToHexString($actualBytes) -cne [Convert]::ToHexString($expectedBytes)) {
            throw "UNICODE_STDOUT_MISMATCH: $($compiler.id)"
        }
        $record.cases += [ordered]@{
            compiler = $compiler.id; buildExitCode = $buildExit; llvmAsExitCode = $asExit
            runExitCode = $runExit; warningCount = 0; artifactInventory = $inventory
            exeSha256 = Sha $product; llvmSha256 = Sha $ll; stdoutSha256 = Sha $runOut
        }
        $record.completed++; $record.passed++
        Write-Result $resultPath $record
        Write-Host "[Windows Unicode path] $($record.completed)/2 $($compiler.id) passed"
    }
    $record.inputFingerprintEnd = Input-Fingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'UNICODE_INPUT_DRIFT' }
    $record.state = 'passed'
    Write-Result $resultPath $record
} catch {
    $message = $_.Exception.Message
    $record.failureId = if ($message -match '^(UNICODE_[A-Z_]+)') { $Matches[1] } else { 'UNICODE_VERIFIER_FAILED' }
    $record.inputFingerprintEnd = Input-Fingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    $record.state = 'failed'
    Write-Result $resultPath $record
    throw
}
