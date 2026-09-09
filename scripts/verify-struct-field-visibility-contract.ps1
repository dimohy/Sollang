[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateRange(1, 16)][int]$Jobs = 6,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$runnerProject = Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.exe"
$llvmRoot = Join-Path $repoRoot ".tools\llvm-22.1.8"
$stdlibRoot = Join-Path $repoRoot "stdlib"
$directCallVerifier = Join-Path $repoRoot "scripts\verify-llvm-direct-call-closure.ps1"
$grammarPath = Join-Path $repoRoot "syntax\sollang.grammar"
$transportPath = Join-Path $repoRoot "stdlib\std\net\quic\transport_parameters.slg"
$astPath = Join-Path $repoRoot "selfhost\syntax\ast.slg"
$diagnosticsPath = Join-Path $repoRoot "selfhost\llvm\emitter\diagnostics.slg"
$boundaryFixturePath = Join-Path $repoRoot "examples\regression\1391-opaque-struct-instance-boundary.slg"
$boundaryModulePath = Join-Path $repoRoot "examples\regression\diagnostics\sample\opaque_value.slg"
$boundaryPeerPath = Join-Path $repoRoot "examples\regression\diagnostics\sample\opaque_value_peer.slg"
$fixtureNames = @(
    "1391-opaque-struct-instance-boundary",
    "1392-selfhost-opaque-struct-ast",
    "1393-selfhost-opaque-struct-diagnostics",
    "diagnostic/opaque-struct-construction",
    "diagnostic/opaque-struct-field-read",
    "diagnostic/opaque-struct-field-write",
    "diagnostic/opaque-struct-modifier-rejected",
    "diagnostic/private-inferred-field-chain"
)

foreach ($requiredPath in @(
    $compilerProject,
    $runnerProject,
    $llvmRoot,
    $stdlibRoot,
    $directCallVerifier,
    $grammarPath,
    $transportPath,
    $astPath,
    $diagnosticsPath,
    $boundaryFixturePath,
    $boundaryModulePath,
    $boundaryPeerPath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "struct field visibility verification input is missing: $requiredPath"
    }
}

function Assert-ContainsOrdinal {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Description
    )

    if (-not $Text.Contains($Expected, [System.StringComparison]::Ordinal)) {
        throw "$Description is missing: $Expected"
    }
}

function Get-FunctionBody {
    param(
        [Parameter(Mandatory)][string]$Llvm,
        [Parameter(Mandatory)][string]$Symbol
    )

    $escaped = [regex]::Escape($Symbol)
    $matches = [regex]::Matches($Llvm, "(?ms)^define\s+[^\r\n]*@$escaped\([^\r\n]*\)\s*#[^{\r\n]*\{.*?^\}")
    if ($matches.Count -ne 1) {
        throw "expected exactly one LLVM definition for $Symbol; found $($matches.Count)"
    }
    $matches[0].Value
}

Write-Host "[struct field visibility 1/4] Verify syntax, semantic, self-host, and QUIC source contracts."
$grammarText = [System.IO.File]::ReadAllText($grammarPath)
$transportText = [System.IO.File]::ReadAllText($transportPath)
$astText = [System.IO.File]::ReadAllText($astPath)
$diagnosticsText = [System.IO.File]::ReadAllText($diagnosticsPath)
$boundaryFixtureText = [System.IO.File]::ReadAllText($boundaryFixturePath)
$boundaryModuleText = [System.IO.File]::ReadAllText($boundaryModulePath)
$boundaryPeerText = [System.IO.File]::ReadAllText($boundaryPeerPath)
Assert-ContainsOrdinal $grammarText 'StructFieldDeclaration = Identifier("public")?' 'public field grammar marker'
if ($grammarText.Contains('Identifier("opaque")', [System.StringComparison]::Ordinal)) {
    throw 'obsolete optional opaque struct marker remains in the grammar'
}
Assert-ContainsOrdinal $transportText 'public struct StreamCount' 'QUIC StreamCount boundary'
Assert-ContainsOrdinal $transportText '    raw: UInt64' 'QUIC private-by-default representation field'
Assert-ContainsOrdinal $astText 'kind == 26' 'self-host field visibility declaration path'
Assert-ContainsOrdinal $diagnosticsText 'privateFieldOperationDiagnosticCount' 'self-host private-field diagnostic classifier'
Assert-ContainsOrdinal $boundaryModuleText '    public x: UInt64' 'explicit public field boundary'
Assert-ContainsOrdinal $boundaryFixtureText 'opaque.Point { x: 9 }' 'external public-field construction'
Assert-ContainsOrdinal $boundaryFixtureText '10 => point!.x' 'external public-field write'
Assert-ContainsOrdinal $boundaryPeerText 'Token { raw: value }' 'same logical module private-field construction'
foreach ($diagnosticKind in @('construct', 'read', 'write')) {
    Assert-ContainsOrdinal $diagnosticsText $diagnosticKind "self-host private-field $diagnosticKind diagnostic"
}
Write-Host "[struct field visibility 1/4] PASS source contracts"

if (-not $SkipBuild) {
    Write-Host "[struct field visibility 2/4] Build the focused managed compiler and fixture runner with warnings as errors."
    & dotnet build $runnerProject -c Release --no-restore -warnaserror
    if ($LASTEXITCODE -ne 0) {
        throw "struct field visibility focused managed build failed"
    }
} else {
    Write-Host "[struct field visibility 2/4] SKIP managed build by explicit request"
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw "struct field visibility compiler executable is missing after build: $compiler"
}

Write-Host "[struct field visibility 3/4] Execute the public-field, same-module, self-host, and external-access fixtures."
$runnerArguments = @("run", "--project", $runnerProject, "-c", "Release", "--no-build", "--")
foreach ($fixtureName in $fixtureNames) {
    $runnerArguments += @("--exact", $fixtureName)
}
$runnerArguments += @("--skip-bootstrap", "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    & dotnet @runnerArguments
if ($LASTEXITCODE -ne 0) {
    throw "struct field visibility focused fixture execution failed"
}
    Write-Host "[struct field visibility 3/4] PASS 8/8 focused fixtures"

Write-Host "[struct field visibility 4/4] Prove the one-word, allocation-free LLVM representation in isolated API bodies."
$systemTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryRoot = Join-Path $systemTemp ("sollang-field-visibility-" + [guid]::NewGuid().ToString("N"))
[System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
try {
    $manifestPath = Join-Path $repoRoot "examples\regression\expected\1391-opaque-struct-instance-boundary.sources.txt"
    $sourcePaths = @(Get-Content -LiteralPath $manifestPath |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $repoRoot $_.Trim())).Path })
    $executablePath = Join-Path $temporaryRoot "field-visibility-managed-exact-1391.exe"
    $buildArguments = @("build") + $sourcePaths + @(
        "-o", $executablePath,
        "--target", "windows-x64",
        "--llvm", $llvmRoot,
        "-O0", "--keep-temps")
    $buildOutput = @(& $compiler @buildArguments 2>&1)
    $buildExitCode = $LASTEXITCODE
    $buildDiagnostics = $buildOutput -join [Environment]::NewLine
    if ($buildExitCode -ne 0) {
        throw "struct field visibility native build failed with exit code $buildExitCode.`n$buildDiagnostics"
    }
    if ($buildDiagnostics -match '(?m)^(?:warning S\d+|note N\d+)\b') {
        throw "struct field visibility native build emitted a compiler warning or note.`n$buildDiagnostics"
    }

    $llvmPath = [System.IO.Path]::ChangeExtension($executablePath, ".ll")
    if (-not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
        throw "struct field visibility LLVM evidence is missing: $llvmPath"
    }
    & $directCallVerifier -LlvmPath $llvmPath
    if ($LASTEXITCODE -ne 0) {
        throw "struct field visibility direct-call closure verification failed"
    }
    $llvmAs = Join-Path $llvmRoot "bin\llvm-as.exe"
    $bitcodePath = [System.IO.Path]::ChangeExtension($executablePath, ".bc")
    & $llvmAs $llvmPath -o $bitcodePath
    if ($LASTEXITCODE -ne 0) {
        throw "struct field visibility llvm-as verification failed"
    }
    $actualOutput = @(& $executablePath 2>&1)
    $executionExitCode = $LASTEXITCODE
    if ($executionExitCode -ne 0) {
        throw "struct field visibility native execution failed with exit code $executionExitCode"
    }
    $expectedOutputPath = Join-Path $repoRoot "examples\regression\expected\1391-opaque-struct-instance-boundary.stdout.txt"
    $expectedOutput = ([System.IO.File]::ReadAllText($expectedOutputPath)).Replace("`r`n", "`n").TrimEnd("`n")
    $normalizedOutput = (($actualOutput -join "`n").Replace("`r`n", "`n")).TrimEnd("`n")
    if ($normalizedOutput -cne $expectedOutput) {
        throw "struct field visibility native stdout mismatch. expected='$expectedOutput' actual='$normalizedOutput'"
    }
    $llvm = [System.IO.File]::ReadAllText($llvmPath)
    $factorySymbol = 'sollang_fn_sample_opaque_value_token'
    $projectorSymbol = 'sollang_fn_sample_opaque_value_Token_value'
    $factoryBody = Get-FunctionBody -Llvm $llvm -Symbol $factorySymbol
    $projectorBody = Get-FunctionBody -Llvm $llvm -Symbol $projectorSymbol

    $factoryHeader = [regex]::Match($factoryBody, '^define\s+internal\s+(?<type>%[-a-zA-Z$._0-9]+)\s+@', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $factoryHeader.Success) {
        throw "private-field factory does not return a direct LLVM aggregate"
    }
    $valueType = [regex]::Escape($factoryHeader.Groups['type'].Value)
    $layoutMatches = [regex]::Matches($llvm, "(?m)^$valueType\s*=\s*type\s*\{\s*i64\s*\}\s*$")
    if ($layoutMatches.Count -ne 1) {
        throw "private-field value must have exactly one direct i64 field; found $($layoutMatches.Count) matching layouts"
    }
    if (([regex]::Matches($factoryBody, '(?m)^\s*%[-a-zA-Z$._0-9]+\s*=\s*insertvalue\b')).Count -ne 1) {
        throw "private-field factory must contain exactly one insertvalue"
    }
    if (([regex]::Matches($projectorBody, '(?m)^\s*%[-a-zA-Z$._0-9]+\s*=\s*extractvalue\b')).Count -ne 1) {
        throw "private-field instance projector must contain exactly one extractvalue"
    }
    foreach ($body in @($factoryBody, $projectorBody)) {
        if ($body -match '(?im)\b(?:call|invoke|alloca)\b|malloc|calloc|realloc|free|sollang_runtime_') {
            throw "private-field factory/projector introduced a call, stack slot, heap operation, or runtime wrapper"
        }
    }
    Write-Host "[struct field visibility 4/4] PASS one i64 aggregate, one insertvalue, one extractvalue, zero wrapper calls/allocations"
} finally {
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    if ($resolvedTemporaryRoot.StartsWith($systemTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($resolvedTemporaryRoot).StartsWith('sollang-field-visibility-', [System.StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "[struct field visibility contract] PASS 4/4 gates, 8/8 fixtures, public-field, same-module, inferred-chain, obsolete-modifier, and direct one-word zero-allocation contracts"
