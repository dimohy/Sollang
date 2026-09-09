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
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 3600000,
    [ValidateRange(0, 2147483647)][long]$ExpectedStdoutLength = 0,
    [AllowEmptyString()][string]$CommonInputFingerprint = "",
    [ValidateSet("", "windows", "linux")][string]$CompilerHost = "",
    [ValidateSet("native-build", "raw-llvm")][string]$CompilationMode = "native-build",
    [string[]]$AdditionalSource = @()
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "native-exact-fixture-receipt.ps1")
. (Join-Path $PSScriptRoot "native-exact-source-closure.ps1")

$repoRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
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
foreach ($suffix in @(
    "selfhost.llvm.not-contains.txt",
    "llvm.not-contains.txt",
    "selfhost.llvm.regex-counts.txt",
    "selfhost.llvm.ordered-regex.txt")) {
    $contractPath = Join-Path $expectedRoot "$Fixture.$suffix"
    if (Test-Path -LiteralPath $contractPath -PathType Leaf) {
        $fixtureContractPaths.Add((Resolve-Path -LiteralPath $contractPath).Path)
    }
}
$fixtureInputPaths = @($sourcePaths) + @($fixtureContractPaths)

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

function Get-CurrentWindowsExactInputFingerprint {
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
        "--llvm", $llvmHome,
        "--stdlib", $stdlibPath,
        "--jobs", $jobText,
        "-O1", "--keep-temps")
    $build = Invoke-VerificationProcessCapture `
        -FilePath $compilerPath `
        -ArgumentList $arguments `
        -Description "$Label exact $Fixture build" `
        -TimeoutMilliseconds $TimeoutMilliseconds
} elseif (-not $reuseVerifiedArtifacts -and $CompilationMode -eq "raw-llvm") {
    $arguments = @("linux", "--jobs", $jobText) + $sourcePaths
    Invoke-VerificationProcessToFile `
        -FilePath $compilerPath `
        -ArgumentList $arguments `
        -Description "$Label exact $Fixture Linux LLVM emission from Windows" `
        -OutputPath $llvmPath `
        -ErrorPath $emissionErrorPath `
        -TimeoutMilliseconds $TimeoutMilliseconds
    $emissionDiagnostics = [System.IO.File]::ReadAllText($emissionErrorPath)
    if ($emissionDiagnostics -match '(?m)^(?:warning S\d+|note N\d+)\b') {
        throw "$Label exact $Fixture emitted a compiler warning or note.`n$emissionDiagnostics"
    }
    $build = [pscustomobject]@{ ExitCode = 0; Stdout = ""; Stderr = $emissionDiagnostics }
} elseif (-not $reuseVerifiedArtifacts) {
    $arguments = @(
        "-d", $Distribution, "--", (Convert-ToExactFixtureWslPath $compilerPath),
        "build")
    $arguments += $sourcePaths | ForEach-Object { Convert-ToExactFixtureWslPath $_ }
    $arguments += @(
        "-o", (Convert-ToExactFixtureWslPath $executablePath),
        "--target", "linux-x64",
        "--stdlib", (Convert-ToExactFixtureWslPath $stdlibPath),
        "--jobs", $jobText,
        "-O1", "--keep-temps")
    $build = Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList $arguments `
        -Description "$Label exact $Fixture build" `
        -TimeoutMilliseconds $TimeoutMilliseconds
}

if (-not $reuseVerifiedArtifacts) {
    $buildDiagnostics = $build.Stdout + $build.Stderr
    if ($build.ExitCode -ne 0) {
        throw "$Label exact $Fixture build failed with exit code $($build.ExitCode).`n$buildDiagnostics"
    }
    if ($buildDiagnostics -match '(?m)^(?:warning S\d+|note N\d+)\b') {
        throw "$Label exact $Fixture build emitted a compiler warning or note.`n$buildDiagnostics"
    }
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
        -TimeoutMilliseconds $TimeoutMilliseconds
    if ($assembly.ExitCode -ne 0) {
        throw "$Label exact $Fixture llvm-as failed with exit code $($assembly.ExitCode).`n$($assembly.Stdout)$($assembly.Stderr)"
    }

    if ($CompilationMode -eq "raw-llvm") {
        $objectBuild = Invoke-VerificationProcessCapture `
            -FilePath $clangPath `
            -ArgumentList @("--target=x86_64-unknown-linux-gnu", "-c", $llvmPath, "-O1", "-o", $objectPath) `
            -Description "$Label exact $Fixture Linux object build" `
            -TimeoutMilliseconds $TimeoutMilliseconds
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
            -TimeoutMilliseconds $TimeoutMilliseconds
        if ($link.ExitCode -ne 0) {
            throw "$Label exact $Fixture Linux link failed with exit code $($link.ExitCode).`n$($link.Stdout)$($link.Stderr)"
        }
    }

    foreach ($suffix in @("selfhost.llvm.not-contains.txt", "llvm.not-contains.txt")) {
        $contractPath = Join-Path $expectedRoot "$Fixture.$suffix"
        if (Test-Path -LiteralPath $contractPath) {
            foreach ($forbidden in ([System.IO.File]::ReadAllLines($contractPath) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
                if ([System.IO.File]::ReadAllText($llvmPath).Contains($forbidden.Trim(), [System.StringComparison]::Ordinal)) {
                    throw "$Label exact $Fixture LLVM retained forbidden text '$($forbidden.Trim())'"
                }
            }
        }
    }

    $llvmText = [System.IO.File]::ReadAllText($llvmPath)
    $regexCountsPath = Join-Path $expectedRoot "$Fixture.selfhost.llvm.regex-counts.txt"
    if (Test-Path -LiteralPath $regexCountsPath) {
        foreach ($contract in ([System.IO.File]::ReadAllLines($regexCountsPath) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $fields = $contract.Split("`t", 2)
            if ($fields.Length -ne 2) { throw "invalid exact regex-count contract '$contract'" }
            $actualCount = ([regex]::Matches($llvmText, $fields[1])).Count
            if ($actualCount -ne [int]$fields[0]) {
                throw "$Label exact $Fixture LLVM regex '$($fields[1])' matched $actualCount times instead of $($fields[0])"
            }
        }
    }

    $orderedRegexPath = Join-Path $expectedRoot "$Fixture.selfhost.llvm.ordered-regex.txt"
    if (Test-Path -LiteralPath $orderedRegexPath) {
        $cursor = 0
        foreach ($pattern in ([System.IO.File]::ReadAllLines($orderedRegexPath) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $match = ([regex]::new($pattern)).Match($llvmText, $cursor)
            if (-not $match.Success) {
                throw "$Label exact $Fixture LLVM did not match ordered regex '$pattern' after byte $cursor"
            }
            $cursor = $match.Index + $match.Length
        }
    }
}

$run = if ($Platform -eq "windows") {
    Invoke-VerificationProcessCapture `
        -FilePath $executablePath `
        -ArgumentList $runArguments `
        -Description "$Label exact $Fixture execution" `
        -TimeoutMilliseconds $TimeoutMilliseconds
} else {
    Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList (@("-d", $Distribution, "--", (Convert-ToExactFixtureWslPath $executablePath)) + $runArguments) `
        -Description "$Label exact $Fixture execution" `
        -TimeoutMilliseconds $TimeoutMilliseconds
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

Write-Host "[native exact] PASS $Label $Platform $Fixture direct closure, LLVM contracts, assembly, and execution."
