[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-UnderRoot([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

$compilerPath = Resolve-UnderRoot $Compiler
$llvmPath = Resolve-UnderRoot $LlvmRoot
$stdlibPath = Resolve-UnderRoot $StdlibRoot
$probePath = Join-Path $root 'scripts/probes/interpolation/c470-invalid-nested-flow-method.slg'
$positivePaths = @(
    (Join-Path $root 'examples/regression/1731-nested-enum-return-flow-interpolation.slg'),
    (Join-Path $root 'examples/regression/1730-mutable-enum-control-storage.slg')
)
$outputPath = Resolve-UnderRoot $OutputDirectory
$scratchRoot = Join-Path $root 'artifacts/scratch'
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be a child of $scratchRoot"
}
foreach ($path in @($compilerPath, $probePath) + $positivePaths + @((Join-Path $llvmPath 'bin/llvm-as.exe'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file not found: $path" }
}
if (-not (Test-Path -LiteralPath $stdlibPath -PathType Container)) { throw "StdlibRoot not found: $stdlibPath" }
if ([IO.Path]::GetExtension($compilerPath) -cne '.exe') { throw 'C470 gate requires a Windows selfhost compiler executable' }

function Get-InputFingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'C470-invalid-interpolation-flow'
        commonFingerprint = $common
        optimization = 'O1'
        expectedDiagnostic = "unknown value-flow target 'missingMethod'"
    }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings `
        -InputPath (@($PSCommandPath, $probePath) + $positivePaths)
}

$inputStart = Get-InputFingerprint
$compilerSha = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($ValidateInputsOnly) {
    [pscustomobject]@{ status = 'preflight-passed'; compilerSha256 = $compilerSha
        inputFingerprint = $inputStart } | ConvertTo-Json -Compress
    return
}
if (Test-Path -LiteralPath $outputPath) { throw "OutputDirectory must not already exist: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$executable = Join-Path $outputPath 'invalid-flow.exe'
$llvm = "$executable.ll"
$resultPath = Join-Path $outputPath 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    defectId = 'C2026-09-23-470'
    status = 'running'
    compilerSha256 = $compilerSha
    probeSha256 = (Get-FileHash -LiteralPath $probePath -Algorithm SHA256).Hash
    inputFingerprintStart = $inputStart
    inputFingerprintEnd = $null
    inputsStable = $false
    negativeValidateExitCode = $null
    negativeValidateStdout = $null
    positiveValidateStdout = @()
    negativeBuildExitCode = $null
    negativeBuildStdout = $null
    negativeBuildStderr = $null
    diagnosticLlvmSha256 = $null
    failure = $null
}
try {
    $negative = Invoke-VerificationProcessCapture -FilePath $compilerPath `
        -ArgumentList @('validate', $probePath) -Description 'C470 negative validation' `
        -WorkingDirectory $root -TimeoutMilliseconds 120000
    $record.negativeValidateExitCode = $negative.ExitCode
    $record.negativeValidateStdout = $negative.Stdout.Trim()
    if ($negative.ExitCode -ne 0 -or $record.negativeValidateStdout -cne 'checked diagnostics = 1' -or $negative.Stderr.Length -ne 0) {
        throw "Negative validation differed: exit=$($negative.ExitCode), stdout=$($negative.Stdout.Trim()), stderr=$($negative.Stderr.Trim())"
    }
    foreach ($positivePath in $positivePaths) {
        $positive = Invoke-VerificationProcessCapture -FilePath $compilerPath `
            -ArgumentList @('validate', $positivePath) -Description 'C470 positive validation' `
            -WorkingDirectory $root -TimeoutMilliseconds 120000
        $record.positiveValidateStdout += $positive.Stdout.Trim()
        if ($positive.ExitCode -ne 0 -or $positive.Stdout.Trim() -cne 'checked diagnostics = 0' -or $positive.Stderr.Length -ne 0) {
            throw "Positive validation differed: $positivePath, exit=$($positive.ExitCode), stdout=$($positive.Stdout.Trim()), stderr=$($positive.Stderr.Trim())"
        }
    }
    $build = Invoke-VerificationProcessCapture -FilePath $compilerPath `
        -ArgumentList @('build', $probePath, '-o', $executable, '--target', 'windows-x64',
            '--llvm', $llvmPath, '--stdlib', $stdlibPath, '--jobs', '1', '-O1', '--keep-temps') `
        -Description 'C470 negative selfhost build' -WorkingDirectory $root -TimeoutMilliseconds 120000
    $record.negativeBuildExitCode = $build.ExitCode
    $record.negativeBuildStdout = $build.Stdout.Trim()
    $record.negativeBuildStderr = $build.Stderr.Trim()
    $diagnostics = $build.Stdout + $build.Stderr
    if ($build.ExitCode -ne 1 -or
        -not $diagnostics.Contains("unknown value-flow target 'missingMethod'") -or
        $diagnostics -match '(?i)linker failed|undefined value|\bwarning\b|\bnote N\d+' -or
        (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Negative build did not reject before LLVM: exit=$($build.ExitCode), diagnostics=$($diagnostics.Trim())"
    }
    if (-not (Test-Path -LiteralPath $llvm -PathType Leaf)) { throw 'Negative build omitted diagnostic LLVM text' }
    $llvmText = Get-Content -LiteralPath $llvm -Raw
    if ($llvmText -match '(?m)^define\s' -or -not $llvmText.Contains("unknown value-flow target 'missingMethod'")) {
        throw 'Negative build emitted LLVM definitions or omitted the semantic diagnostic'
    }
    $record.diagnosticLlvmSha256 = (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
} finally {
    $record.inputFingerprintEnd = Get-InputFingerprint
    $record.inputsStable = $record.inputFingerprintEnd -ceq $inputStart
    if (-not $record.inputsStable) {
        $record.status = 'failed'
        $record.failure = 'Input fingerprint changed during C470 negative verification'
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"))
}
if ($record.status -ne 'passed') { throw "C470 negative gate failed: $($record.failure); result=$resultPath" }
Write-Output "[C470 invalid interpolation flow] PASS semantic rejection before LLVM, stable inputs: $resultPath"
