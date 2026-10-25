[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmToolRoot = '.tools/llvm-22.1.8'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compiler = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$llvm = [IO.Path]::GetFullPath($LlvmToolRoot, $root)
$clang = Join-Path $llvm 'bin/clang.exe'
if (-not (Test-Path -LiteralPath $clang -PathType Leaf)) {
    throw "C527_TOPOLOGY_LLVM_TOOL_MISSING: $clang"
}
$stem = '1824-c527-indexed-member-interpolation-topology'
$manifest = Join-Path $root "examples/regression/expected/$stem.sources.txt"
$expectedPath = Join-Path $root "examples/regression/expected/$stem.stdout.txt"
$closure = Join-Path $PSScriptRoot 'verify-source-manifest-closure.ps1'
foreach ($path in @($manifest, $expectedPath, $closure)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C527_TOPOLOGY_INPUT_MISSING: $path" }
}
& $closure -Manifest @($manifest) -RepositoryRoot $root
if (-not $?) { throw 'C527_TOPOLOGY_SOURCE_CLOSURE_FAILED' }

$sources = @([IO.File]::ReadAllLines($manifest) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $root $_.Trim() })
$inputs = @($compiler, $manifest, $expectedPath, $closure, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'), $clang) + $sources
$compilerBase = Join-Path (Split-Path -Parent $compiler) ([IO.Path]::GetFileNameWithoutExtension($compiler))
$inputs += @("$compilerBase.dll", "$compilerBase.deps.json", "$compilerBase.runtimeconfig.json")
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C527_TOPOLOGY_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C527_TOPOLOGY_OUTPUT_EXISTS: $output" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$llvmVersion = Invoke-VerificationProcessCapture -FilePath $clang -ArgumentList @('--version') `
    -WorkingDirectory $root -ExecutionRecordPath (Join-Path $output 'llvm-version.execution.json') `
    -Description 'C527 LLVM version preflight' -TimeoutMilliseconds 10000
if ($llvmVersion.ExitCode -ne 0 -or $llvmVersion.Stdout -notmatch 'clang version 22\.') {
    throw 'C527_TOPOLOGY_LLVM_VERSION_UNSUPPORTED'
}
$product = Join-Path $output 'topology.exe'
$build = Invoke-VerificationProcessCapture -FilePath $compiler `
    -ArgumentList (@('build') + $sources + @('--target', 'windows-x64', '--llvm', $llvm, '-o', $product)) `
    -WorkingDirectory $root -ExecutionRecordPath (Join-Path $output 'build.execution.json') `
    -Description 'C527 managed interpolation topology build'
$run = if ($build.ExitCode -eq 0 -and (Test-Path -LiteralPath $product -PathType Leaf)) {
    Invoke-VerificationProcessCapture -FilePath $product -ArgumentList @() `
        -WorkingDirectory $root -ExecutionRecordPath (Join-Path $output 'runtime.execution.json') `
        -Description 'C527 managed interpolation topology runtime'
} else { $null }
$expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n")
$actual = if ($null -ne $run) { $run.Stdout.Replace("`r`n", "`n") } else { '' }
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
$failureIds = @(
    if ($build.ExitCode -ne 0) { 'C527_TOPOLOGY_BUILD' }
    if ($null -eq $run -or $run.ExitCode -ne 0) { 'C527_TOPOLOGY_RUNTIME' }
    if ($actual -cne $expected) { 'C527_TOPOLOGY_STDOUT' }
    if (-not $stable) { 'C527_TOPOLOGY_INPUT_CHANGED' }
    if ($build.Stderr -match '(?i)warning' -or ($null -ne $run -and $run.Stderr.Length -gt 0)) {
        'C527_TOPOLOGY_DIAGNOSTIC'
    }
)
$record = [ordered]@{
    schemaVersion = 1
    unit = 'C527IndexedMemberTopology'
    status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completed = if ($failureIds.Count -eq 0) { 1 } else { 0 }
    total = 1
    compilerSha256 = $hashes[$compiler]
    llvmToolRoot = $llvm
    llvmVersion = $llvmVersion.Stdout.TrimEnd()
    inputStable = $stable
    inputHashes = $hashes
    inputHashesEnd = $endHashes
    buildExit = $build.ExitCode
    runtimeExit = if ($null -ne $run) { $run.ExitCode } else { $null }
    actualStdout = $actual
    buildStdout = $build.Stdout
    buildStderr = $build.Stderr
    buildExecutionRecord = Join-Path $output 'build.execution.json'
    runtimeExecutionRecord = if ($null -ne $run) { Join-Path $output 'runtime.execution.json' } else { $null }
    processesStopped = @(
        Get-ChildItem -LiteralPath $output -File -Filter '*.execution.json' |
            ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json } |
            Where-Object processesStopped -ne $true
    ).Count -eq 0
    failureIds = $failureIds
}
[IO.File]::WriteAllText((Join-Path $output 'result.json'),
    (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failureIds.Count -gt 0) { throw "C527 topology verification failed: $($failureIds -join ', ')" }
Write-Output "[C527 indexed member topology] PASS 1/1; $output/result.json"
