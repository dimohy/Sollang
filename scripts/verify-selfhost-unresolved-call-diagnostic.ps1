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
    "examples/regression/diagnostics/unknown-value-flow-target.slg")).Path
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
    -Description "$Label unknown value-flow target diagnostic"
$text = $result.Stdout + $result.Stderr
$expected = "unresolved call target 'println2'"
if ($result.ExitCode -eq 0 -or
    -not $text.Contains($expected) -or
    [regex]::Matches($text, [regex]::Escape($expected)).Count -ne 1 -or
    $text -match '(?m)^target (datalayout|triple)') {
    throw "unknown value-flow target did not fail once before LLVM under $Label ($compilerPath)"
}
Write-Host "[selfhost unresolved call] PASS $Label rejects println2 once before LLVM emission."

$propagatingSourcePath = (Resolve-Path -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/unknown-propagating-instance-target.slg")).Path
$propagatingArguments = @($Target, $propagatingSourcePath)
if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
    $propagatingArguments = @(
        "-d", $Distribution, "--", (Convert-ToWslPath $compilerPath),
        $Target, (Convert-ToWslPath $propagatingSourcePath)
    )
}
$propagatingResult = Invoke-VerificationProcessCapture `
    -FilePath $filePath `
    -ArgumentList $propagatingArguments `
    -Description "$Label unknown propagating instance target diagnostic"
$propagatingText = $propagatingResult.Stdout + $propagatingResult.Stderr
$propagatingExpected = "unresolved instance call target 'chunkWindow'; the identifier after '->' is the method name, while the identifier after '=>' is the result binding"
if ($propagatingResult.ExitCode -eq 0 -or
    -not $propagatingText.Contains($propagatingExpected) -or
    [regex]::Matches($propagatingText, "unresolved instance call target 'chunkWindow'").Count -ne 1 -or
    $propagatingText.Contains("compiler verification failure V006") -or
    $propagatingText -match '(?m)^target (datalayout|triple)') {
    throw "unknown propagating instance target did not fail once with binding guidance before LLVM under $Label ($compilerPath)"
}
Write-Host "[selfhost unresolved call] PASS $Label distinguishes the instance method name from the result binding before LLVM emission."

$ambiguityRoot = (Resolve-Path -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/open-import-ambiguous.slg")).Path
$ambiguityAlpha = (Resolve-Path -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/collision/alpha.slg")).Path
$ambiguityBeta = (Resolve-Path -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/collision/beta.slg")).Path
$ambiguityArguments = @($Target, $ambiguityRoot, $ambiguityAlpha, $ambiguityBeta)
if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
    $ambiguityArguments = @(
        "-d", $Distribution, "--", (Convert-ToWslPath $compilerPath), $Target,
        (Convert-ToWslPath $ambiguityRoot),
        (Convert-ToWslPath $ambiguityAlpha),
        (Convert-ToWslPath $ambiguityBeta)
    )
}
$ambiguityResult = Invoke-VerificationProcessCapture `
    -FilePath $filePath `
    -ArgumentList $ambiguityArguments `
    -Description "$Label open-import ambiguity diagnostic"
$ambiguityText = $ambiguityResult.Stdout + $ambiguityResult.Stderr
$ambiguityExpected = (Get-Content -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/open-import-ambiguous.stderr.contains.txt") -Raw).Trim()
if ($ambiguityResult.ExitCode -ne 1 -or
    -not $ambiguityText.Contains($ambiguityExpected) -or
    [regex]::Matches($ambiguityText, [regex]::Escape($ambiguityExpected)).Count -ne 1 -or
    $ambiguityText -match '(?m)^target (datalayout|triple)') {
    throw "open-import ambiguity did not fail once with candidate guidance before LLVM under $Label ($compilerPath)`n$ambiguityText"
}
Write-Host "[selfhost unresolved call] PASS $Label reports exact open-import candidates and qualification guidance before LLVM emission."
