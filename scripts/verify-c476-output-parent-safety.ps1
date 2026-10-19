[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$CompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

if (-not $IsWindows) { throw 'OUTPUT_PARENT_PLATFORM_UNSUPPORTED: Windows-only path contract' }
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$driverPath = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.slg'
$sourcePath = Join-Path $root 'scripts/probes/typed/c478-comparison-control.slg'
$compilerPath = [IO.Path]::GetFullPath($Compiler, $root)
$llvmPath = [IO.Path]::GetFullPath($LlvmRoot, $root)
$stdlibPath = [IO.Path]::GetFullPath($StdlibRoot, $root)
$outputPath = [IO.Path]::GetFullPath($OutputDirectory, $root)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_PARENT_PATH_INVALID: output must be below $scratchRoot"
}
foreach ($path in @($compilerPath, $driverPath, $sourcePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OUTPUT_PARENT_INPUT_MISSING: $path" }
}
foreach ($path in @($llvmPath, $stdlibPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "OUTPUT_PARENT_INPUT_MISSING: $path" }
}
$compilerActualSha = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($CompilerSha256 -cnotmatch '^[A-Fa-f0-9]{64}$' -or $compilerActualSha -cne $CompilerSha256.ToUpperInvariant()) {
    throw 'OUTPUT_PARENT_COMPILER_IDENTITY: compiler SHA-256 differs'
}
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PARENT_PATH_EXISTS: $outputPath" }

$driver = [IO.File]::ReadAllText($driverPath)
function Get-DriverFunction([string]$Name) {
    $expression = "(?ms)^$([regex]::Escape($Name))\s+[^`r`n]*\{.*?^\}"
    $matches = [regex]::Matches($driver, $expression)
    if ($matches.Count -ne 1) { throw "OUTPUT_PARENT_FUNCTION_IDENTITY: expected one $Name function" }
    return $matches[0].Value
}
$parentFunction = Get-DriverFunction 'executableDirectory'
$driveFunction = Get-DriverFunction 'windowsDriveRelative'
if ($driver -notmatch 'output -> windowsDriveRelative -> if' -or
    $driver -notmatch 'info\.kind -> when' -or
    $driver -notmatch 'stageDirectory -> claimNativeBuildStages') {
    throw 'OUTPUT_PARENT_PREFLIGHT_MISSING: driver lacks required path guards'
}
$inputs = @($compilerPath, $driverPath, $sourcePath, $PSCommandPath,
    (Join-Path $llvmPath 'bin/clang.exe'), (Join-Path $llvmPath 'bin/llvm-as.exe'))
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OUTPUT_PARENT_INPUT_MISSING: $path" }
}
function Get-InputFingerprint {
    $lines = foreach ($path in $inputs) { "$path $((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)" }
    $lines += "stdlib $stdlibPath"
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lines -join "`n")))
}
$inputFingerprint = Get-InputFingerprint
if ($ValidateInputsOnly) {
    Write-Host "[c476 output parent] inputs valid; fingerprint=$inputFingerprint; compiler not launched"
    return
}

[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$resultPath = Join-Path $outputPath 'result.json'
$result = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-parent-safety'; state = 'running'
    compilerPath = $compilerPath; compilerSha256 = $compilerActualSha
    inputFingerprintStart = $inputFingerprint; inputFingerprintEnd = $null; inputsStable = $false
    completed = 0; passed = 0; cases = [ordered]@{}; failure = $null
}
function Write-Result { [IO.File]::WriteAllText($resultPath, ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false)) }
Write-Result
$activeCase = $null
try {
    $activeCase = 'parentRoots'
    $probeSource = Join-Path $outputPath 'parent-probe.slg'
    $probeExe = Join-Path $outputPath 'parent-probe.exe'
    $probe = @'
main {
    "C:\\probe.exe" -> executableDirectory -> println
    "\\probe.exe" -> executableDirectory -> println
    "C:probe.exe" -> windowsDriveRelative -> println
    "C:\\probe.exe" -> windowsDriveRelative -> println
}
'@
    [IO.File]::WriteAllText($probeSource, "$parentFunction`n`n$driveFunction`n`n$probe", [Text.UTF8Encoding]::new($false))
    $build = Invoke-VerificationProcessCapture -FilePath $compilerPath -WorkingDirectory $root -TimeoutMilliseconds $TimeoutMilliseconds -Description 'C476 output parent probe build' -ArgumentList @('build', $probeSource, '-o', $probeExe, '--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1')
    if ($build.ExitCode -ne 0 -or $build.Stderr.Length -ne 0 -or -not (Test-Path -LiteralPath $probeExe -PathType Leaf)) {
        throw "OUTPUT_PARENT_PROBE_BUILD_FAILED: exit=$($build.ExitCode) stderr=$($build.Stderr)"
    }
    $run = Invoke-VerificationProcessCapture -FilePath $probeExe -WorkingDirectory $root -TimeoutMilliseconds $TimeoutMilliseconds -Description 'C476 output parent probe'
    $expected = "C:\`n\`ntrue`nfalse`n"
    if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0 -or $run.Stdout -cne $expected) {
        throw "OUTPUT_PARENT_PROBE_MISMATCH: exit=$($run.ExitCode) stdout=$($run.Stdout) stderr=$($run.Stderr)"
    }
    $result.cases.parentRoots = [ordered]@{ state = 'passed'; stdout = $run.Stdout }
    $result.completed++; $result.passed++; Write-Result
    $activeCase = 'driveRelative'
    $driveCasePath = Join-Path $outputPath 'driveRelative'
    [IO.Directory]::CreateDirectory($driveCasePath) | Out-Null
    $driveOutput = "P:probe.exe"
    if ([IO.Path]::GetFullPath($driveOutput, $driveCasePath) -cne (Join-Path $driveCasePath 'probe.exe')) {
        throw 'OUTPUT_PARENT_DRIVE_SCOPE_INVALID: drive-relative probe escapes its owned case directory'
    }
    $drive = Invoke-VerificationProcessCapture -FilePath $compilerPath -WorkingDirectory $driveCasePath -TimeoutMilliseconds $TimeoutMilliseconds -Description 'C476 drive-relative output' -ArgumentList @('build', $sourcePath, '-o', $driveOutput, '--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps')
    if ($drive.ExitCode -eq 0 -or $drive.Stdout.Length -ne 0 -or
        $drive.Stderr -notmatch '(?i)sollang: output path is drive-relative and unsafe' -or
        @(Get-ChildItem -LiteralPath $driveCasePath -Force).Count -ne 0) {
        throw "OUTPUT_PARENT_DRIVE_NOT_REJECTED: exit=$($drive.ExitCode) stdout=$($drive.Stdout) stderr=$($drive.Stderr)"
    }
    $result.cases.driveRelative = [ordered]@{ state = 'passed'; exitCode = $drive.ExitCode; products = @() }
    $result.completed++; $result.passed++; Write-Result

    $activeCase = 'existingDirectory'
    $casePath = Join-Path $outputPath 'existingDirectory'
    $artifactPath = Join-Path $casePath 'artifacts'
    $destination = Join-Path $artifactPath 'foo.exe'
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    $sentinel = Join-Path $destination 'child.txt'
    [IO.File]::WriteAllText($sentinel, 'C476-owned-sentinel', [Text.UTF8Encoding]::new($false))
    $beforeSha = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
    $existing = Invoke-VerificationProcessCapture -FilePath $compilerPath -WorkingDirectory $casePath -TimeoutMilliseconds $TimeoutMilliseconds -Description 'C476 existing output directory' -ArgumentList @('build', $sourcePath, '-o', $destination, '--target', 'windows-x64', '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps')
    $afterSha = (Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
    $caseNames = @(Get-ChildItem -LiteralPath $artifactPath -Force | ForEach-Object Name)
    $childNames = @(Get-ChildItem -LiteralPath $destination -Force | ForEach-Object Name)
    if ($existing.ExitCode -eq 0 -or $existing.Stdout.Length -ne 0 -or
        $existing.Stderr -notmatch '(?i)sollang: output path names an existing directory' -or
        $beforeSha -cne $afterSha -or
        $caseNames.Count -ne 1 -or $caseNames[0] -cne 'foo.exe' -or
        $childNames.Count -ne 1 -or $childNames[0] -cne 'child.txt') {
        throw "OUTPUT_PARENT_DIRECTORY_NOT_PRESERVED: exit=$($existing.ExitCode) stdout=$($existing.Stdout) stderr=$($existing.Stderr)"
    }
    $result.cases.existingDirectory = [ordered]@{ state = 'passed'; exitCode = $existing.ExitCode; sentinelSha256 = $afterSha; products = $caseNames }
    $result.completed++; $result.passed++; Write-Result
    $activeCase = $null
    $result.inputFingerprintEnd = Get-InputFingerprint
    $result.inputsStable = $result.inputFingerprintStart -ceq $result.inputFingerprintEnd
    if (-not $result.inputsStable) { throw 'OUTPUT_PARENT_INPUT_DRIFT: inputs changed' }
    $result.state = 'passed'
    Write-Result
    Write-Host "[c476 output parent] passed=$($result.passed)/3 fingerprint=$inputFingerprint result=$resultPath"
} catch {
    if ($null -ne $activeCase -and -not $result.cases.Contains($activeCase)) {
        $result.cases[$activeCase] = [ordered]@{ state = 'failed'; failure = $_.Exception.Message }
        $result.completed++
    }
    $result.state = 'failed'; $result.failure = $_.Exception.Message
    $result.inputFingerprintEnd = Get-InputFingerprint
    $result.inputsStable = $result.inputFingerprintStart -ceq $result.inputFingerprintEnd
    Write-Result
    throw
}
