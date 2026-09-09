[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$Label = "selfhost",
    [ValidateSet("windows", "linux")]
    [string]$Target = "windows",
    [string]$Distribution = "",
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$cases = @(
    "opaque-struct-construction"
    "opaque-struct-field-read"
    "opaque-struct-field-write"
)

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

if (-not [string]::IsNullOrWhiteSpace($Distribution) -and $Target -ne "linux") {
    throw "WSL private-field diagnostic execution requires target linux"
}

$completed = 0
foreach ($case in $cases) {
    $manifestPath = Join-Path $repoRoot "examples/regression/diagnostics/$case.sources.txt"
    $expectedPath = Join-Path $repoRoot "examples/regression/diagnostics/$case.stderr.contains.txt"
    $sourcePaths = @(Get-Content -LiteralPath $manifestPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $repoRoot $_.Trim())).Path })
    $expectedLines = @(Get-Content -LiteralPath $expectedPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($sourcePaths.Count -lt 2) {
        throw "$case must retain its external consumer and declaring-module source manifest"
    }
    if ($expectedLines.Count -ne 1) {
        throw "$case must retain exactly one authoritative diagnostic expectation"
    }

    $filePath = $compilerPath
    $arguments = @($Target) + $sourcePaths
    if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
        $filePath = "wsl.exe"
        $arguments = @("-d", $Distribution, "--", (Convert-ToWslPath $compilerPath), $Target) +
            @($sourcePaths | ForEach-Object { Convert-ToWslPath $_ })
    }

    $result = Invoke-VerificationProcessCapture `
        -FilePath $filePath `
        -ArgumentList $arguments `
        -Description "$Label private-field diagnostic $case"
    $text = $result.Stdout + $result.Stderr
    $expected = $expectedLines[0]
    if ($result.ExitCode -ne 1 -or
        [regex]::Matches($text, [regex]::Escape($expected)).Count -ne 1 -or
        $text.Contains("compiler verification failure V006") -or
        $text -match '(?m)^target (datalayout|triple)') {
        throw "$case did not fail exactly once with its actionable diagnostic before LLVM under $Label ($compilerPath).`n$text"
    }
    $completed += 1
    Write-Host "[selfhost private fields $completed/$($cases.Count)] PASS $Label $case"
}

Write-Host "[selfhost private fields] PASS $Label rejects external construction, read, and write before LLVM emission."
