[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Label,
    [ValidateSet("windows", "linux")][string]$Platform = "windows",
    [string]$Distribution = "Ubuntu",
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$StdlibRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 64)][int]$Jobs = 4
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$compilerPath = [System.IO.Path]::GetFullPath($Compiler)
$stdlibPath = [System.IO.Path]::GetFullPath($StdlibRoot)
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
$fixture = "1156-interpolation-readonly-struct-reference"
$sourcePath = Join-Path $repoRoot "examples\regression\$fixture.slg"
$expectedRoot = Join-Path $repoRoot "examples\regression\expected"
$expectedPath = Join-Path $expectedRoot "$fixture.stdout.txt"
$regexCountsPath = Join-Path $expectedRoot "$fixture.selfhost.llvm.regex-counts.txt"
$orderedRegexPath = Join-Path $expectedRoot "$fixture.selfhost.llvm.ordered-regex.txt"
$llvmAsPath = Join-Path ([System.IO.Path]::GetFullPath($LlvmRoot)) "bin\llvm-as.exe"

foreach ($requiredPath in @(
    $compilerPath,
    $stdlibPath,
    $sourcePath,
    $expectedPath,
    $regexCountsPath,
    $orderedRegexPath,
    $llvmAsPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "$Label interpolation-reference verifier input is missing: $requiredPath"
    }
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

$artifactBase = Join-Path $outputRoot "$Label-check-$fixture"
$executablePath = if ($Platform -eq "windows") { "$artifactBase.exe" } else { $artifactBase }
$llvmPath = $executablePath + ".ll"
$bitcodePath = $executablePath + ".bc"
Remove-Item -LiteralPath $executablePath, $llvmPath, $bitcodePath -ErrorAction SilentlyContinue

if ($Platform -eq "windows") {
    $build = Invoke-VerificationProcessCapture `
        -FilePath $compilerPath `
        -ArgumentList @(
            "build", $sourcePath,
            "-o", $executablePath,
            "--target", "windows-x64",
            "--llvm", ([System.IO.Path]::GetFullPath($LlvmRoot)),
            "--stdlib", $stdlibPath,
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -Description "$Label interpolation-reference build"
} else {
    $build = Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList @(
            "-d", $Distribution, "--", (Convert-ToWslPath $compilerPath),
            "build", (Convert-ToWslPath $sourcePath),
            "-o", (Convert-ToWslPath $executablePath),
            "--target", "linux-x64",
            "--stdlib", (Convert-ToWslPath $stdlibPath),
            "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "-O1", "--keep-temps") `
        -Description "$Label interpolation-reference build"
}
if ($build.ExitCode -ne 0) {
    throw "$Label interpolation-reference build failed.`n$($build.Stdout)$($build.Stderr)"
}
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $llvmPath -PathType Leaf) -or
    (Get-Item -LiteralPath $llvmPath).Length -eq 0) {
    throw "$Label interpolation-reference build did not retain executable and LLVM artifacts"
}

$llvm = [System.IO.File]::ReadAllText($llvmPath)
foreach ($contract in ([System.IO.File]::ReadAllLines($regexCountsPath) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    $fields = $contract.Split("`t", 2)
    if ($fields.Length -ne 2) {
        throw "invalid interpolation-reference regex-count contract '$contract'"
    }
    $expectedCount = [int]$fields[0]
    $actualCount = ([regex]::Matches($llvm, $fields[1])).Count
    if ($actualCount -ne $expectedCount) {
        throw "$Label interpolation-reference LLVM regex '$($fields[1])' matched $actualCount times instead of $expectedCount"
    }
}

$cursor = 0
foreach ($pattern in ([System.IO.File]::ReadAllLines($orderedRegexPath) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
    $match = ([regex]::new($pattern)).Match($llvm, $cursor)
    if (-not $match.Success) {
        throw "$Label interpolation-reference LLVM did not match ordered regex '$pattern' after byte $cursor"
    }
    $cursor = $match.Index + $match.Length
}

& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
& $llvmAsPath $llvmPath -o $bitcodePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Platform -eq "windows") {
    $run = Invoke-VerificationProcessCapture `
        -FilePath $executablePath `
        -Description "$Label interpolation-reference executable"
} else {
    $run = Invoke-VerificationProcessCapture `
        -FilePath "wsl.exe" `
        -ArgumentList @("-d", $Distribution, "--", (Convert-ToWslPath $executablePath)) `
        -Description "$Label interpolation-reference executable"
}
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($run.ExitCode -ne 0 -or $actual -cne $expected) {
    throw "$Label interpolation-reference execution differed.`nExpected:`n$expected`nActual:`n$actual`n$($run.Stderr)"
}
Write-Host "[interpolation reference] PASS $Label $Platform entry alloca, store, pointer call, assembly, and exact execution."
