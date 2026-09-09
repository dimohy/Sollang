[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$caseRoot = Join-Path $repoRoot "artifacts\parallel-callback-cache-stability"
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$llvm = Join-Path $repoRoot ".tools\llvm-22.1.8"
$firstSource = Join-Path $caseRoot "first.slg"
$secondSource = Join-Path $caseRoot "second.slg"
$mainSource = Join-Path $caseRoot "main.slg"
$incrementalOutput = Join-Path $caseRoot "incremental.exe"
$coldOutput = Join-Path $caseRoot "cold.exe"

if (Test-Path -LiteralPath $caseRoot) {
    Remove-Item -LiteralPath $caseRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $caseRoot | Out-Null

function Write-FirstSource {
    param([switch]$WithLeadingCallback)

    $leading = if ($WithLeadingCallback) {
@'
    values -> parallel value {
        value -> plusTwo
    } => prepared
    prepared -> parallel value {
'@
    } else {
@'
    values -> parallel value {
'@
    }
    @"
namespace cache.first

plusOne value: Int -> Int {
    value + 1
}

plusTwo value: Int -> Int {
    value + 2
}

public map values: move [Int; ~] -> [Int; ~] {
$leading
        value -> plusOne
    } => mapped
    mapped
}
"@ | Set-Content -LiteralPath $firstSource -Encoding utf8NoBOM
}

@'
namespace cache.second

plusTen value: Int -> Int {
    value + 10
}

public map values: move [Int; ~] -> [Int; ~] {
    values -> parallel value {
        value -> plusTen
    } => mapped
    mapped
}
'@ | Set-Content -LiteralPath $secondSource -Encoding utf8NoBOM

@'
import cache.first as first
import cache.second as second

main {
    [1; ~] -> first.map -> second.map => values
    "$(values[0])" -> println
}
'@ | Set-Content -LiteralPath $mainSource -Encoding utf8NoBOM

function Invoke-Build {
    param([string]$Output)

    $text = & dotnet $compiler build $mainSource $firstSource $secondSource `
        -o $Output --target windows-x64 --llvm $llvm --keep-temps 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "parallel callback cache build failed:`n$text"
    }
    $text
}

function Assert-Product {
    param([string]$Output, [string]$Expected)

    $actual = (& $Output | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $actual -ne $Expected) {
        throw "parallel callback cache product expected '$Expected', actual '$actual'"
    }
}

Write-Host "[parallel callback cache 1/4] Seed one callback in each module."
Write-FirstSource
$null = Invoke-Build $incrementalOutput
Assert-Product $incrementalOutput "12"

Write-Host "[parallel callback cache 2/4] Insert a callback before the unchanged module."
Write-FirstSource -WithLeadingCallback
$incrementalLog = Invoke-Build $incrementalOutput
$reuseMatch = [regex]::Match(
    $incrementalLog,
    '\[codegen-cache\] loaded; reused (?<reused>[1-9][0-9]*)/(?<total>[0-9]+) units;')
if (-not $reuseMatch.Success) {
    throw "callback insertion did not exercise partial codegen reuse:`n$incrementalLog"
}
Assert-Product $incrementalOutput "14"

Write-Host "[parallel callback cache 3/4] Build the edited graph cold."
$coldLog = Invoke-Build $coldOutput
if ($coldLog -notmatch '\[codegen-cache\] cold; reused 0/[0-9]+ units;') {
    throw "comparison build was not cold:`n$coldLog"
}
Assert-Product $coldOutput "14"

Write-Host "[parallel callback cache 4/4] Require byte-identical incremental and cold LLVM."
$incrementalLlvm = [System.IO.Path]::ChangeExtension($incrementalOutput, ".ll")
$coldLlvm = [System.IO.Path]::ChangeExtension($coldOutput, ".ll")
$incrementalHash = (Get-FileHash -LiteralPath $incrementalLlvm -Algorithm SHA256).Hash
$coldHash = (Get-FileHash -LiteralPath $coldLlvm -Algorithm SHA256).Hash
if ($incrementalHash -ne $coldHash) {
    throw "parallel callback insertion produced cache-dependent LLVM: incremental=$incrementalHash cold=$coldHash"
}
Write-Host "[parallel callback cache] PASS reused=$($reuseMatch.Groups['reused'].Value)/$($reuseMatch.Groups['total'].Value) LLVM=$incrementalHash"
