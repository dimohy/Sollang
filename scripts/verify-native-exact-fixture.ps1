[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Fixture,
    [ValidateSet("windows", "linux")][string]$Platform = "windows",
    [string]$Distribution = "Ubuntu",
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$StdlibRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 64)][int]$Jobs = 1,
    [ValidateRange(1000, 180000)][int]$TimeoutMilliseconds = 180000,
    [ValidateRange(0, 2147483647)][long]$ExpectedStdoutLength = 0,
    [AllowEmptyString()][string]$CommonInputFingerprint = "",
    [ValidateSet("", "windows", "linux")][string]$CompilerHost = "",
    [ValidateSet("native-build", "raw-llvm")][string]$CompilationMode = "native-build",
    [string[]]$AdditionalSource = @(),
    [string]$CancellationRequestPath = "",
    [string]$CancellationRunId = "",
    [string]$CancellationAcknowledgementPath = "",
    [string]$PhaseExecutionContract = "",
    [ValidateSet("", "managed", "selfhost")][string]$CompilerSide = ""
)

$caseClock = [Diagnostics.Stopwatch]::StartNew()
function Get-NativeExactRemainingCaseMilliseconds {
    $remaining = $TimeoutMilliseconds - $caseClock.ElapsedMilliseconds
    if ($remaining -le 0) { throw 'NATIVE_EXACT_CASE_BUDGET_EXHAUSTED' }
    [int]$remaining
}

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "native-exact-fixture-receipt.ps1")
. (Join-Path $PSScriptRoot "native-exact-source-closure.ps1")
$cancellationValues = @($CancellationRequestPath, $CancellationRunId, $CancellationAcknowledgementPath)
if (@($cancellationValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -notin @(0, 3)) {
    throw 'CancellationRequestPath, CancellationRunId, and CancellationAcknowledgementPath must be supplied together'
}
if (-not [string]::IsNullOrWhiteSpace($CancellationRequestPath)) {
    Initialize-VerificationCancellation -RequestPath $CancellationRequestPath `
        -RunId $CancellationRunId -AcknowledgementPath $CancellationAcknowledgementPath
}
Assert-VerificationCancellationNotRequested

$repoRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$compilerIsManagedDll = [System.IO.Path]::GetExtension($compilerPath).Equals('.dll', [System.StringComparison]::OrdinalIgnoreCase)
$windowsCompilerPath = $compilerPath
[string[]]$windowsCompilerArgumentPrefix = @()
if ($compilerIsManagedDll) {
    $dotnetCommand = Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $windowsCompilerPath = $dotnetCommand.Source
    $windowsCompilerArgumentPrefix = @($compilerPath)
}
$llvmHome = (Resolve-Path -LiteralPath $LlvmRoot).Path
$stdlibPath = (Resolve-Path -LiteralPath $StdlibRoot).Path
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
$sourcePath = Join-Path $repoRoot "examples\regression\$Fixture.slg"
$expectedRoot = Join-Path $repoRoot "examples\regression\expected"
$expectedPath = Join-Path $expectedRoot "$Fixture.stdout.txt"
$sourceManifestPath = Join-Path $expectedRoot "$Fixture.sources.txt"
$argumentsPath = Join-Path $expectedRoot "$Fixture.args.txt"
$llvmAsPath = Join-Path $llvmHome "bin\llvm-as.exe"
$clangPath = Join-Path $llvmHome "bin\clang.exe"

$effectiveCompilerHost = if ([string]::IsNullOrWhiteSpace($CompilerHost)) { $Platform } else { $CompilerHost }
if ($CompilationMode -eq "native-build" -and $effectiveCompilerHost -ne $Platform) {
    throw "native-build requires CompilerHost to match Platform"
}
if ($CompilationMode -eq "raw-llvm" -and
    ($effectiveCompilerHost -ne "windows" -or $Platform -ne "linux")) {
    throw "raw-llvm currently requires CompilerHost windows and Platform linux"
}

$requiredPaths = @($compilerPath, $stdlibPath, $sourcePath, $llvmAsPath, $clangPath)
if ($ExpectedStdoutLength -eq 0) { $requiredPaths += $expectedPath }
foreach ($requiredPath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "$Label exact fixture input is missing: $requiredPath"
    }
}

$sourcePaths = @(if (Test-Path -LiteralPath $sourceManifestPath) {
    Get-Content -LiteralPath $sourceManifestPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $repoRoot $_.Trim())).Path }
} else {
    $sourcePath
})
if ($sourcePaths.Count -eq 0 -or
    -not $sourcePaths.Contains((Resolve-Path -LiteralPath $sourcePath).Path)) {
    throw "$Label exact fixture manifest must contain its executable root: $sourceManifestPath"
}
$additionalSourcePaths = @($AdditionalSource | ForEach-Object {
    (Resolve-Path -LiteralPath $_).Path
})
$sourcePaths += $additionalSourcePaths
Assert-NativeExactCompilerSourceClosure -RepositoryRoot $repoRoot -Fixture $Fixture -SourcePath $sourcePaths

$fixtureContractPaths = [System.Collections.Generic.List[string]]::new()
$compilerStderrExactPath = Join-Path $expectedRoot "$Fixture.compiler.stderr.exact.txt"
$hasExactCompilerStderr = Test-Path -LiteralPath $compilerStderrExactPath -PathType Leaf
if ($hasExactCompilerStderr) {
    if (Test-Path -LiteralPath (Join-Path $expectedRoot "$Fixture.compiler.stderr.contains.txt")) {
        throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_AMBIGUOUS'
    }
    $fixtureContractPaths.Add((Resolve-Path -LiteralPath $compilerStderrExactPath).Path)
    Assert-NativeExactCompilerDiagnostics -Stdout '' -Stderr ([IO.File]::ReadAllText($compilerStderrExactPath)) -ExpectedExactPath $compilerStderrExactPath
}
$hasArgumentsContract = Test-Path -LiteralPath $argumentsPath -PathType Leaf
[string[]]$runArguments = @()
if ($hasArgumentsContract) {
    $runArguments = [System.IO.File]::ReadAllLines($argumentsPath, [System.Text.Encoding]::UTF8)
    $fixtureContractPaths.Add((Resolve-Path -LiteralPath $argumentsPath).Path)
}
if (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf) {
    $fixtureContractPaths.Add((Resolve-Path -LiteralPath $sourceManifestPath).Path)
}
if ($ExpectedStdoutLength -eq 0) {
    $fixtureContractPaths.Add((Resolve-Path -LiteralPath $expectedPath).Path)
}
$llvmContracts = Get-NativeExactLlvmContracts -ExpectedRoot $expectedRoot -Fixture $Fixture `
    -CompilerIsManagedDll $compilerIsManagedDll -CompilerSide $CompilerSide `
    -PhaseContractProvided (-not [string]::IsNullOrWhiteSpace($PhaseExecutionContract))
foreach ($contractPath in $llvmContracts.InputPaths) {
    $fixtureContractPaths.Add((Resolve-Path -LiteralPath $contractPath).Path)
}
$fixtureInputPaths = @($sourcePaths) + @($fixtureContractPaths)
$phaseContext = $null; $phaseCase = $null; $phasePrefix = ''
if (-not [string]::IsNullOrWhiteSpace($PhaseExecutionContract)) {
    if ($Platform -cne 'windows' -or $CompilationMode -cne 'native-build' -or [string]::IsNullOrWhiteSpace($CompilerSide) -or $AdditionalSource.Count -gt 0) {
        throw 'PHASE_EXECUTION_REQUIRES_WINDOWS_NATIVE_BUILD_AND_SIDE'
    }
    $phaseContext = Get-NativeExactPhaseContext $repoRoot $PhaseExecutionContract $CompilerSide $compilerPath $PSCommandPath
    [void](Assert-NativeExactPhaseOutputPath $repoRoot $outputRoot)
    $phaseCases = @($phaseContext.Contract.cases | Where-Object { $_.fixture.path -ceq [IO.Path]::GetRelativePath($repoRoot, $sourcePath).Replace('\', '/') })
    if ($phaseCases.Count -gt 1) { throw 'PHASE_EXECUTION_DUPLICATE_FIXTURE' }
    if ($phaseCases.Count -eq 1) {
        $phaseCase = $phaseCases[0]
        if ((Get-NativeExactPhaseExpectedStage $phaseCase compile $CompilerSide).exitCode -ne 0) { throw 'PHASE_EXECUTION_NEGATIVE_REQUIRES_NEGATIVE_RUNNER' }
        $phasePrefix = Get-NativeExactPhaseOutcomePrefix $phaseContext $phaseCase
        if (Test-Path -LiteralPath "$phasePrefix.compile.json") { throw 'PHASE_EXECUTION_CACHED_OUTCOME_FORBIDDEN' }
    }
} elseif (-not [string]::IsNullOrWhiteSpace($CompilerSide)) { throw 'PHASE_EXECUTION_CONTRACT_REQUIRED' }


[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

function Convert-ToExactFixtureWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

$artifactBase = Join-Path $outputRoot "$Label-exact-$Fixture"
$executablePath = if ($Platform -eq "windows") { "$artifactBase.exe" } else { $artifactBase }
$llvmPath = $executablePath + ".ll"
$bitcodePath = $executablePath + ".bc"
$objectPath = $executablePath + ".o"
$emissionErrorPath = $executablePath + ".emit.err"
$inputReceiptPath = $executablePath + ".inputs.sha256"
$outputReceiptPath = $executablePath + ".outputs.sha256"
if ($null -ne $phaseCase) {
    foreach ($existing in @($executablePath, $llvmPath, $bitcodePath, $objectPath, $inputReceiptPath, $outputReceiptPath)) {
        if (Test-Path -LiteralPath $existing) { throw 'PHASE_EXECUTION_EXISTING_PRODUCTS_PROTECTED' }
    }
}
$phaseBuildRecord = ''; $phaseRunRecord = ''
$phaseBuildInputs = $null
if ($null -ne $phaseCase) {
    $phaseBuildRecord = "$artifactBase.compile.execution.json"
    $phaseRunRecord = "$artifactBase.run.execution.json"
    $phaseBuildInputs = Get-NativeExactPhaseCommandInputs $phaseContext ($fixtureInputPaths + @($llvmAsPath, $clangPath) + @(Get-ChildItem -LiteralPath $stdlibPath -Recurse -File -Filter '*.slg' | ForEach-Object FullName))
} elseif ($hasExactCompilerStderr) {
    $diagnosticRunId = [guid]::NewGuid().ToString('N')
    $phaseBuildRecord = "$artifactBase.$diagnosticRunId.compile.execution.json"
    $phaseRunRecord = "$artifactBase.$diagnosticRunId.run.execution.json"
}


function Get-CurrentWindowsExactInputFingerprint {
    if ((Test-Path -LiteralPath $compilerStderrExactPath -PathType Leaf) -ne $hasExactCompilerStderr) {
        throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_PRESENCE_CHANGED'
    }
    if ((Test-Path -LiteralPath $argumentsPath -PathType Leaf) -ne $hasArgumentsContract) {
        throw "$Label exact $Fixture argument contract presence changed during verification"
    }
    $freshCommonFingerprint = Get-NativeExactWindowsCommonInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CompilerPath $compilerPath `
        -StdlibRoot $stdlibPath `
        -LlvmRoot $llvmHome
    Get-NativeExactPerFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CommonFingerprint $freshCommonFingerprint `
        -Fixture $Fixture `
        -Label $Label `
        -Platform $Platform `
        -Distribution $Distribution `
        -Jobs $Jobs `
        -ExpectedStdoutLength $ExpectedStdoutLength `
        -InputPath $fixtureInputPaths
}

$inputFingerprint = ""
$reuseVerifiedArtifacts = $false
if ($Platform -eq "windows") {
    $commonFingerprint = if ([string]::IsNullOrWhiteSpace($CommonInputFingerprint)) {
        Get-NativeExactWindowsCommonInputFingerprint `
            -RepositoryRoot $repoRoot `
            -CompilerPath $compilerPath `
            -StdlibRoot $stdlibPath `
            -LlvmRoot $llvmHome
    } else {
        if ($CommonInputFingerprint -cnotmatch '^[0-9A-F]{64}$') {
            throw "$Label exact $Fixture common input fingerprint is not an uppercase SHA-256 value"
        }
        $CommonInputFingerprint
    }
    $inputFingerprint = Get-NativeExactPerFixtureInputFingerprint `
        -RepositoryRoot $repoRoot `
        -CommonFingerprint $commonFingerprint `
        -Fixture $Fixture `
        -Label $Label `
        -Platform $Platform `
        -Distribution $Distribution `
        -Jobs $Jobs `
        -ExpectedStdoutLength $ExpectedStdoutLength `
        -InputPath $fixtureInputPaths
    $reuseVerifiedArtifacts = Test-NativeExactFixtureReceipt `
        -InputFingerprint $inputFingerprint `
        -InputReceiptPath $inputReceiptPath `
        -LlvmPath $llvmPath `
        -BitcodePath $bitcodePath `
        -ExecutablePath $executablePath `
        -OutputReceiptPath $outputReceiptPath
}

if (-not $reuseVerifiedArtifacts) {
    Remove-Item -LiteralPath $executablePath, $llvmPath, $bitcodePath, $objectPath, $emissionErrorPath, $inputReceiptPath, $outputReceiptPath -ErrorAction SilentlyContinue
}

$jobText = $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture)
if (-not $reuseVerifiedArtifacts -and $Platform -eq "windows") {
    $arguments = @("build") + $sourcePaths + @(
        "-o", $executablePath,
        "--target", "windows-x64",
        "--llvm", $llvmHome)
    if (-not $compilerIsManagedDll) {
        $arguments += @("--stdlib", $stdlibPath)
    }
    $arguments += @("--jobs", $jobText)
    $arguments += @("-O1", "--keep-temps")
    $build = Invoke-VerificationProcessCapture `
        -FilePath $windowsCompilerPath `
        -ArgumentList ($windowsCompilerArgumentPrefix + $arguments) `
        -Description "$Label exact $Fixture build" `
        -ExecutionRecordPath $phaseBuildRecord `
        -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
} elseif (-not $reuseVerifiedArtifacts -and $CompilationMode -eq "raw-llvm") {
    $arguments = @("linux", "--jobs", $jobText) + $sourcePaths
    Invoke-VerificationProcessToFile `
        -FilePath $windowsCompilerPath `
        -ArgumentList ($windowsCompilerArgumentPrefix + $arguments) `
        -Description "$Label exact $Fixture Linux LLVM emission from Windows" `
        -OutputPath $llvmPath `
        -ErrorPath $emissionErrorPath `
        -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
    $emissionDiagnostics = [System.IO.File]::ReadAllText($emissionErrorPath)
    $build = [pscustomobject]@{ ExitCode = 0; Stdout = ""; Stderr = $emissionDiagnostics }
} elseif (-not $reuseVerifiedArtifacts) {
    $wslCompilerArguments = if ($compilerIsManagedDll) {
        @('dotnet', (Convert-ToExactFixtureWslPath $compilerPath))
    } else {
        @((Convert-ToExactFixtureWslPath $compilerPath))
    }
    $arguments = @("-d", $Distribution, "--") + $wslCompilerArguments + @("build")
    $arguments += $sourcePaths | ForEach-Object { Convert-ToExactFixtureWslPath $_ }
    $arguments += @(
        "-o", (Convert-ToExactFixtureWslPath $executablePath),
        "--target", "linux-x64")
    if (-not $compilerIsManagedDll) {
        $arguments += @("--stdlib", (Convert-ToExactFixtureWslPath $stdlibPath))
    }
    $arguments += @("--jobs", $jobText)
    $arguments += @("-O1", "--keep-temps")
    $build = Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList $arguments `
        -Description "$Label exact $Fixture build" `
        -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
}

if (-not $reuseVerifiedArtifacts) {
    $buildDiagnostics = $build.Stdout + $build.Stderr
    if ($build.ExitCode -ne 0) {
        throw "$Label exact $Fixture build failed with exit code $($build.ExitCode).`n$buildDiagnostics"
    }
    $diagnosticContract = if ($hasExactCompilerStderr) { $compilerStderrExactPath } else { '' }
    Assert-NativeExactCompilerDiagnostics -Stdout $build.Stdout -Stderr $build.Stderr -ExpectedExactPath $diagnosticContract
    if (-not (Test-Path -LiteralPath $llvmPath -PathType Leaf) -or
        (Get-Item -LiteralPath $llvmPath).Length -eq 0) {
        throw "$Label exact $Fixture build did not retain LLVM"
    }
    if ($CompilationMode -eq "native-build" -and
        -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        throw "$Label exact $Fixture native build did not retain its executable"
    }

    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
    if (-not $?) { throw "$Label exact $Fixture direct-call closure verification failed" }
    $assembly = Invoke-VerificationProcessCapture `
        -FilePath $llvmAsPath `
        -ArgumentList @($llvmPath, "-o", $bitcodePath) `
        -Description "$Label exact $Fixture llvm-as" `
        -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
    if ($assembly.ExitCode -ne 0) {
        throw "$Label exact $Fixture llvm-as failed with exit code $($assembly.ExitCode).`n$($assembly.Stdout)$($assembly.Stderr)"
    }

    if ($CompilationMode -eq "raw-llvm") {
        $objectBuild = Invoke-VerificationProcessCapture `
            -FilePath $clangPath `
            -ArgumentList @("--target=x86_64-unknown-linux-gnu", "-c", $llvmPath, "-O1", "-o", $objectPath) `
            -Description "$Label exact $Fixture Linux object build" `
            -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
        if ($objectBuild.ExitCode -ne 0) {
            throw "$Label exact $Fixture Linux object build failed with exit code $($objectBuild.ExitCode).`n$($objectBuild.Stdout)$($objectBuild.Stderr)"
        }
        $link = Invoke-VerificationProcessCapture `
            -FilePath "wsl.exe" `
            -ArgumentList @(
                "-d", $Distribution, "--", "gcc",
                (Convert-ToExactFixtureWslPath $objectPath),
                "-pthread", "-o", (Convert-ToExactFixtureWslPath $executablePath)) `
            -Description "$Label exact $Fixture Linux link" `
            -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
        if ($link.ExitCode -ne 0) {
            throw "$Label exact $Fixture Linux link failed with exit code $($link.ExitCode).`n$($link.Stdout)$($link.Stderr)"
        }
    }

    Assert-NativeExactLlvmContracts -LlvmPath $llvmPath -Contracts $llvmContracts
}

if ($null -ne $phaseCase) {
    [void](Write-NativeExactPhaseOutcome -Context $phaseContext -Case $phaseCase -Stage compile -ProcessRecordPath $phaseBuildRecord -OutputPath $phasePrefix -BinaryPath $executablePath -InputHashesStart $phaseBuildInputs)
    $phaseRunInputs = Get-NativeExactPhaseCommandInputs $phaseContext (@($phaseBuildInputs.Keys) + @($executablePath))
}
$run = if ($Platform -eq "windows") {
    Invoke-VerificationProcessCapture `
        -FilePath $executablePath `
        -ArgumentList $runArguments `
        -Description "$Label exact $Fixture execution" `
        -ExecutionRecordPath $phaseRunRecord `
        -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
} else {
    Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList (@("-d", $Distribution, "--", (Convert-ToExactFixtureWslPath $executablePath)) + $runArguments) `
        -Description "$Label exact $Fixture execution" `
        -TimeoutMilliseconds (Get-NativeExactRemainingCaseMilliseconds)
}
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
if ($ExpectedStdoutLength -gt 0) {
    if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0 -or $actual.Length -ne $ExpectedStdoutLength) {
        throw "$Label exact $Fixture execution length differed: expected=$ExpectedStdoutLength actual=$($actual.Length) exit=$($run.ExitCode) stderrLength=$($run.Stderr.Length)"
    }
} else {
    $expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    if ($run.ExitCode -ne 0 -or $run.Stderr.Length -ne 0 -or $actual -cne $expected) {
        throw "$Label exact $Fixture execution differed (exit=$($run.ExitCode), stderrLength=$($run.Stderr.Length)).`nExpected:`n$expected`nActual:`n$actual`n$($run.Stderr)"
    }
}

if ($null -ne $phaseCase) {
    [void](Write-NativeExactPhaseOutcome -Context $phaseContext -Case $phaseCase -Stage run -ProcessRecordPath $phaseRunRecord -OutputPath $phasePrefix -BinaryPath $executablePath -InputHashesStart $phaseRunInputs)
}
if ($Platform -eq "windows") {
    $freshInputFingerprint = Get-CurrentWindowsExactInputFingerprint
    if ($freshInputFingerprint -cne $inputFingerprint) {
        throw "$Label exact $Fixture inputs changed during verification; refusing to publish or reuse stale artifacts"
    }
    if ($reuseVerifiedArtifacts) {
        if (-not (Test-NativeExactFixtureReceipt `
                -InputFingerprint $inputFingerprint `
                -InputReceiptPath $inputReceiptPath `
                -LlvmPath $llvmPath `
                -BitcodePath $bitcodePath `
                -ExecutablePath $executablePath `
                -OutputReceiptPath $outputReceiptPath)) {
            throw "$Label exact $Fixture cached artifacts changed during execution"
        }
        [void](Get-NativeExactRemainingCaseMilliseconds)
        Write-Host "[native exact] PASS $Label $Platform $Fixture cached artifacts authenticated and exact execution revalidated."
        return
    }
    Publish-NativeExactFixtureReceipt `
        -InputFingerprint $inputFingerprint `
        -InputReceiptPath $inputReceiptPath `
        -LlvmPath $llvmPath `
        -BitcodePath $bitcodePath `
        -ExecutablePath $executablePath `
        -OutputReceiptPath $outputReceiptPath
}

[void](Get-NativeExactRemainingCaseMilliseconds)
Write-Host "[native exact] PASS $Label $Platform $Fixture direct closure, LLVM contracts, assembly, and execution."
