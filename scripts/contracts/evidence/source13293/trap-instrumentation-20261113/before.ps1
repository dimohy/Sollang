[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$output = [System.IO.Path]::GetFullPath($OutputPath)
if ($resolvedInput -ceq $output) {
    throw "instrumented LLVM output must differ from the input"
}

$lines = [System.IO.File]::ReadAllLines($resolvedInput)
$instrumented = [System.Collections.Generic.List[string]]::new($lines.Length + 1)
$declaredExitProcess = $false
$trapOrdinal = 0
foreach ($line in $lines) {
    if (-not $declaredExitProcess -and $line.StartsWith("define ", [StringComparison]::Ordinal)) {
        $instrumented.Add("declare dllimport void @ExitProcess(i32)")
        $declaredExitProcess = $true
    }
    if ($line.Trim() -ceq "call void @llvm.trap()") {
        $trapOrdinal++
        $indentLength = $line.Length - $line.TrimStart().Length
        $indent = $line.Substring(0, $indentLength)
        $instrumented.Add("${indent}call void @ExitProcess(i32 $trapOrdinal)")
    } else {
        $instrumented.Add($line)
    }
}
if ($trapOrdinal -eq 0) {
    throw "LLVM input contains no trap calls: $resolvedInput"
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($output)
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
[System.IO.File]::WriteAllLines(
    $output,
    $instrumented,
    [System.Text.UTF8Encoding]::new($false))
Write-Host "[LLVM trap instrumentation] PASS traps=$trapOrdinal output=$output"
