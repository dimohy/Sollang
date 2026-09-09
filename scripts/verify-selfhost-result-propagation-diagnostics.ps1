[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
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
$sourcePath = (Resolve-Path -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/result-propagation-in-entry.slg")).Path
$filePath = $compilerPath
$arguments = @($Target, $sourcePath)

if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
    if ($Target -ne "linux") {
        throw "WSL diagnostic execution requires target linux"
    }
    function Convert-ToWslPath {
        param([Parameter(Mandatory)][string]$Path)

        $absolute = [System.IO.Path]::GetFullPath($Path)
        $drive = $absolute.Substring(0, 1).ToLowerInvariant()
        $tail = $absolute.Substring(3).Replace('\', '/')
        "/mnt/$drive/$tail"
    }
    $filePath = "wsl.exe"
    $arguments = @(
        "-d", $Distribution, "--", (Convert-ToWslPath $compilerPath),
        $Target, (Convert-ToWslPath $sourcePath)
    )
}

$result = Invoke-VerificationProcessCapture `
    -FilePath $filePath `
    -ArgumentList $arguments `
    -Description "$Label entry Result propagation diagnostic"
$text = $result.Stdout + $result.Stderr
$expected = "'?' can only be used inside a function returning Result<T, E>; in main, match the Result explicitly with '-> when' and handle Ok/Err"
if ($result.ExitCode -eq 0 -or
    -not $text.Contains($expected) -or
    [regex]::Matches($text, [regex]::Escape($expected)).Count -ne 1 -or
    $text.Contains("compiler verification failure V006") -or
    $text -match '(?m)^target (datalayout|triple)') {
    throw "entry Result propagation did not fail once with explicit-match guidance before LLVM under $Label ($compilerPath)"
}

Write-Host "[selfhost Result propagation] PASS $Label rejects '?' in main once with explicit Ok/Err match guidance."
