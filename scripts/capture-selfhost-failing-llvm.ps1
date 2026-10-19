[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 120000
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function ContainedFile([string]$Path) {
    $absolute = [IO.Path]::GetFullPath((Join-Path $repo $Path))
    if (-not $absolute.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $absolute -PathType Leaf)) { throw "CAPTURE_INPUT_MISSING_OR_OUTSIDE_REPOSITORY: $Path" }
    return $absolute
}
$compiler = ContainedFile $CompilerPath
$source = ContainedFile $SourcePath
$compilerSha = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
if ($compilerSha -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw 'CAPTURE_COMPILER_SHA_MISMATCH' }
$output = [IO.Path]::GetFullPath((Join-Path $repo $OutputDirectory))
$scratch = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/scratch'))
if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -gt 0)) {
    throw 'CAPTURE_OUTPUT_MUST_BE_FRESH_SCRATCH_DIRECTORY'
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$exe = Join-Path $output 'fixture.exe'
$transientLlvm = Join-Path $output '.l0.ll'
$capturedLlvm = Join-Path $output 'captured.ll'
$stdout = Join-Path $output 'stdout.log'
$stderr = Join-Path $output 'stderr.log'
$llvm = ContainedFile '.tools/llvm-22.1.8/bin/llvm-as.exe'
$arguments = @('build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', (Join-Path $repo '.tools/llvm-22.1.8'), '-O1', '--keep-temps', '--stdlib', (Join-Path $repo 'stdlib'))
$process = Start-Process -FilePath $compiler -ArgumentList $arguments -WorkingDirectory $repo -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
$timer = [Diagnostics.Stopwatch]::StartNew()
$snapshots = 0
$timedOut = $false
function Capture-LlvmSnapshot([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }
    try {
        $stream = [IO.File]::Open($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            if ($stream.Length -le 0) { return $false }
            $bytes = [byte[]]::new($stream.Length)
            $read = $stream.Read($bytes, 0, $bytes.Length)
            if ($read -ne $bytes.Length) { return $false }
            [IO.File]::WriteAllBytes($Destination, $bytes)
            return $true
        } finally { $stream.Dispose() }
    } catch [IO.IOException] { return $false }
}
try {
    while (-not $process.HasExited) {
        if (Capture-LlvmSnapshot $transientLlvm $capturedLlvm) { $snapshots++ }
        if ($timer.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
            $timedOut = $true
            $process.Kill($true)
            break
        }
        Start-Sleep -Milliseconds 20
    }
    $process.WaitForExit()
    $exitCode = $process.ExitCode
} finally { $process.Dispose(); $timer.Stop() }
$captured = Test-Path -LiteralPath $capturedLlvm -PathType Leaf
$record = [ordered]@{
    schemaVersion = 1
    status = if ($timedOut) { 'timeout' } elseif ($captured) { 'captured' } else { 'capture-missing' }
    compilerSha256 = $compilerSha
    sourceSha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    exitCode = $exitCode
    timedOut = $timedOut
    snapshotCount = $snapshots
    llvmSha256 = if ($captured) { (Get-FileHash -LiteralPath $capturedLlvm -Algorithm SHA256).Hash } else { $null }
    llvmBytes = if ($captured) { (Get-Item -LiteralPath $capturedLlvm).Length } else { 0 }
    stdoutSha256 = (Get-FileHash -LiteralPath $stdout -Algorithm SHA256).Hash
    stderrSha256 = (Get-FileHash -LiteralPath $stderr -Algorithm SHA256).Hash
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 4) + "`n"), [Text.UTF8Encoding]::new($false))
if ($timedOut -or -not $captured) { throw "CAPTURE_FAILED: $resultPath" }
Write-Host "[failing LLVM capture] exit=$exitCode snapshots=$snapshots bytes=$($record.llvmBytes) result=$resultPath"
