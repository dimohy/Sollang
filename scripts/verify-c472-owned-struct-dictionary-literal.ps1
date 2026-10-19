[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
function Resolve-Input([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

$contractPath = Join-Path $PSScriptRoot 'contracts/c472-owned-struct-dictionary-literal.json'
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
$compilerPath = Resolve-Input $Compiler
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$stdlibRoot = Join-Path $root 'stdlib'
$llvmAsPath = Join-Path $llvmRoot 'bin/llvm-as.exe'
$closureScript = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$outputPath = Resolve-Input $OutputDirectory
$scratchRoot = Join-Path $root 'artifacts/scratch'
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be a child of $scratchRoot"
}
if ([IO.Path]::GetExtension($compilerPath) -cne '.exe') {
    throw 'C472 focused gate requires a Windows selfhost compiler executable'
}

$cases = @(
    [pscustomobject]@{ Name = 'entry'; Source = $contract.source; SourceHash = $contract.sourceSha256; Expected = $contract.expected; ExpectedHash = $contract.expectedSha256 },
    [pscustomobject]@{ Name = 'function'; Source = $contract.functionSource; SourceHash = $contract.functionSourceSha256; Expected = $contract.functionExpected; ExpectedHash = $contract.functionExpectedSha256 },
    [pscustomobject]@{ Name = 'field-order'; Source = $contract.fieldOrderSource; SourceHash = $contract.fieldOrderSourceSha256; Expected = $contract.fieldOrderExpected; ExpectedHash = $contract.fieldOrderExpectedSha256 },
    [pscustomobject]@{ Name = 'explicit'; Source = $contract.explicitControl; SourceHash = $contract.explicitControlSourceSha256; Expected = $contract.explicitControlExpected; ExpectedHash = $contract.explicitControlExpectedSha256 },
    [pscustomobject]@{ Name = 'owned-replacement'; Source = $contract.retainedOwnedReplacement; SourceHash = $contract.retainedOwnedReplacementSourceSha256; Expected = $contract.retainedOwnedReplacementExpected; ExpectedHash = $contract.retainedOwnedReplacementExpectedSha256 },
    [pscustomobject]@{ Name = 'array-valued'; Source = $contract.arrayValuedControl; SourceHash = $contract.arrayValuedControlSourceSha256; Expected = $contract.arrayValuedControlExpected; ExpectedHash = $contract.arrayValuedControlExpectedSha256 }
)
$inputPaths = @($PSCommandPath, $contractPath, $compilerPath, $llvmAsPath, $closureScript,
    (Join-Path $PSScriptRoot 'verification-process.ps1'), $contract.invalidFieldProbe)
foreach ($case in $cases) { $inputPaths += @($case.Source, $case.Expected) }
foreach ($path in $inputPaths) {
    if (-not (Test-Path -LiteralPath (Resolve-Input $path) -PathType Leaf)) {
        throw "C472 input is missing: $path"
    }
}
if (-not (Test-Path -LiteralPath $stdlibRoot -PathType Container)) {
    throw "C472 stdlib is missing: $stdlibRoot"
}
foreach ($case in $cases) {
    if ((Get-FileHash -LiteralPath (Resolve-Input $case.Source) -Algorithm SHA256).Hash -cne $case.SourceHash) {
        throw "C472 source hash differs from contract: $($case.Source)"
    }
    if ((Get-FileHash -LiteralPath (Resolve-Input $case.Expected) -Algorithm SHA256).Hash -cne $case.ExpectedHash) {
        throw "C472 expected hash differs from contract: $($case.Expected)"
    }
}
if ((Get-FileHash -LiteralPath (Resolve-Input $contract.invalidFieldProbe) -Algorithm SHA256).Hash -cne
    $contract.invalidFieldProbeSha256) {
    throw 'C472 invalid-field source hash differs from contract'
}

function Get-C472InputFingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPath -StdlibRoot $stdlibRoot -LlvmRoot $llvmRoot
    $settings = [ordered]@{ gate = 'C472-owned-struct-dictionary-literal'; commonFingerprint = $common; optimization = 'O1'; jobs = '1' }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings `
        -InputPath @($inputPaths | ForEach-Object { Resolve-Input $_ })
}

$inputStart = Get-C472InputFingerprint
$compilerSha = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($ValidateInputsOnly) {
    [pscustomobject]@{ status = 'preflight-passed'; compilerSha256 = $compilerSha; inputFingerprint = $inputStart; caseCount = $cases.Count } |
        ConvertTo-Json -Compress
    return
}
if (Test-Path -LiteralPath $outputPath) { throw "OutputDirectory must not already exist: $outputPath" }
[void][IO.Directory]::CreateDirectory($outputPath)
$resultPath = Join-Path $outputPath 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    defectId = $contract.defectId
    status = 'running'
    compilerSha256 = $compilerSha
    inputFingerprintStart = $inputStart
    inputFingerprintEnd = $null
    inputStable = $false
    structural = @()
    negative = $null
    cases = @()
    failure = $null
}
try {
    foreach ($case in @($cases | Where-Object { $_.Name -in @('entry', 'function', 'field-order') })) {
        $ir = Invoke-VerificationProcessCapture -FilePath $compilerPath `
            -ArgumentList @('typed-ir-nodes', (Resolve-Input $case.Source)) `
            -Description "C472 $($case.Name) typed IR" -WorkingDirectory $root -TimeoutMilliseconds 120000
        if ($ir.ExitCode -ne 0 -or $ir.Stderr.Length -ne 0) {
            throw "C472 $($case.Name) typed IR inspection failed: $($ir.Stderr)"
        }
        $struct = [regex]::Match($ir.Stdout, '(?m)^node (?<id>\d+) kind 12 parent (?<parent>\d+) .* type 26/1/[^\r\n]*$')
        if (-not $struct.Success) { throw "C472 $($case.Name) has no nominal struct value node" }
        $structId = $struct.Groups['id'].Value
        $parentId = $struct.Groups['parent'].Value
        if ($ir.Stdout -cnotmatch "(?m)^node ${parentId} kind 16\b" -or
            $ir.Stdout -cnotmatch "(?m)^node \d+ kind 14 parent ${structId} .* type 27/3/") {
            throw "C472 $($case.Name) lost dictionary to struct to array topology"
        }
        if ($case.Name -eq 'field-order') {
            $first = [regex]::Match($struct.Value, ' operands (?<id>\d+)/')
            if (-not $first.Success) { throw 'C472 field-order struct has no first field operand' }
            $firstId = $first.Groups['id'].Value
            $textField = [regex]::Match($ir.Stdout,
                "(?m)^node ${firstId} kind 2 parent ${structId} .* operands -1/-1/(?<next>\d+) ")
            if (-not $textField.Success) { throw 'C472 first declared field is not the Text owner' }
            $arrayId = $textField.Groups['next'].Value
            if ($ir.Stdout -cnotmatch "(?m)^node ${arrayId} kind 14 parent ${structId} .* type 27/3/") {
                throw 'C472 second declared field is not the owned array'
            }
        }
        $record.structural += [ordered]@{ name = $case.Name; structNode = [int]$structId; dictionaryNode = [int]$parentId; status = 'passed' }
    }

    $negativeOutput = Join-Path $outputPath 'invalid.exe'
    $negative = Invoke-VerificationProcessCapture -FilePath $compilerPath `
        -ArgumentList @('build', (Resolve-Input $contract.invalidFieldProbe), '-o', $negativeOutput,
            '--target', 'windows-x64', '--llvm', $llvmRoot, '--stdlib', $stdlibRoot,
            '--jobs', '1', '-O1', '--keep-temps') `
        -Description 'C472 invalid contextual field' -WorkingDirectory $root -TimeoutMilliseconds 300000
    $record.negative = [ordered]@{ exitCode = $negative.ExitCode; stdout = $negative.Stdout; stderr = $negative.Stderr }
    if ($negative.ExitCode -eq 0 -or $negative.Stdout -notmatch [regex]::Escape($contract.invalidFieldManagedDiagnostic) -or
        $negative.Stdout -match 'compiler error S028' -or (Test-Path -LiteralPath $negativeOutput)) {
        throw 'Invalid contextual field did not fail before LLVM with the required identifier diagnostic'
    }

    foreach ($case in $cases) {
        $exe = Join-Path $outputPath "$($case.Name).exe"
        $llvm = "$exe.ll"
        $bitcode = "$exe.bc"
        $build = Invoke-VerificationProcessCapture -FilePath $compilerPath `
            -ArgumentList @('build', (Resolve-Input $case.Source), '-o', $exe,
                '--target', 'windows-x64', '--llvm', $llvmRoot, '--stdlib', $stdlibRoot,
                '--jobs', '1', '-O1', '--keep-temps') `
            -Description "C472 $($case.Name) build" -WorkingDirectory $root -TimeoutMilliseconds 300000
        if ($build.ExitCode -ne 0 -or $build.Stderr.Length -ne 0 -or
            ($build.Stdout + $build.Stderr) -match '(?im)^(?:warning|note)\b' -or
            -not (Test-Path -LiteralPath $exe -PathType Leaf) -or
            -not (Test-Path -LiteralPath $llvm -PathType Leaf)) {
            throw "C472 $($case.Name) build failed or emitted diagnostics: $($build.Stdout) $($build.Stderr)"
        }
        $closureOutput = & $closureScript -LlvmPath $llvm 2>&1
        if (-not $?) { throw "C472 $($case.Name) LLVM direct-call closure failed: $closureOutput" }
        $assembly = Invoke-VerificationProcessCapture -FilePath $llvmAsPath `
            -ArgumentList @($llvm, '-o', $bitcode) -Description "C472 $($case.Name) llvm-as" -TimeoutMilliseconds 30000
        if ($assembly.ExitCode -ne 0 -or $assembly.Stderr.Length -ne 0) {
            throw "C472 $($case.Name) llvm-as failed: $($assembly.Stderr)"
        }
        $run = Invoke-VerificationProcessCapture -FilePath $exe `
            -Description "C472 $($case.Name) run" -TimeoutMilliseconds 10000
        $actual = [Text.Encoding]::UTF8.GetBytes($run.Stdout)
        $expected = [IO.File]::ReadAllBytes((Resolve-Input $case.Expected))
        if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0 -or
            [Convert]::ToHexString($actual) -cne [Convert]::ToHexString($expected)) {
            throw "C472 $($case.Name) native output differs from exact expected bytes"
        }
        $record.cases += [ordered]@{
            name = $case.Name
            sourceSha256 = $case.SourceHash
            expectedSha256 = $case.ExpectedHash
            llvmSha256 = (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash
            executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
            stdoutSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($actual))
            buildExitCode = $build.ExitCode
            llvmAsExitCode = $assembly.ExitCode
            runExitCode = $run.ExitCode
            warningOrNoteCount = 0
        }
    }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
} finally {
    $record.inputFingerprintEnd = Get-C472InputFingerprint
    $record.inputStable = $record.inputFingerprintEnd -ceq $inputStart
    if (-not $record.inputStable) {
        $record.status = 'failed'
        $record.failure = 'C472 inputs changed during focused verification'
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"))
}
if ($record.status -ne 'passed') { throw "C472 focused gate failed: $($record.failure); result=$resultPath" }
Write-Output "[C472] PASS $($cases.Count)/$($cases.Count) native exact cases, negative diagnostic, stable inputs: $resultPath"
