[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SeedCompiler,
    [string]$OutputDirectory = "",
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 3600000,
    [switch]$PrepareOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "compiler-emission-fingerprint.ps1")

$seedPath = [IO.Path]::GetFullPath($SeedCompiler)
$seedReceipt = [IO.Path]::ChangeExtension($seedPath, ".sha256")
if (-not (Test-Path -LiteralPath $seedPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $seedReceipt -PathType Leaf)) {
    throw "C85 control requires a receipt-bound SLG seed compiler: $seedPath"
}
$seedHash = (Get-FileHash -LiteralPath $seedPath -Algorithm SHA256).Hash
if ([IO.File]::ReadAllText($seedReceipt).Trim() -cne $seedHash) {
    throw "C85 control seed does not match its receipt: $seedPath"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "artifacts/c85-per-source-control"
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$typedPath = Join-Path $repoRoot "selfhost/ir/typed.slg"
$typedText = [IO.File]::ReadAllText($typedPath)
$rangeMerge = '        results! -> appendAndReleaseFunctionResultRange(functionResults, frozenFunctionResultStartsBySource[sourceIndex], frozenFunctionResultCountsBySource[sourceIndex])'
$perSourceMerge = @'
        [FunctionLowerRequest; ~] => sourceFunctionRequests!
        0 => sourceFunctionSymbolIndex!
        sourceFunctionSymbolIndex! < sourceRange.symbolCount -> while {
            prepared.package.symbols[sourceRange.symbolStart + sourceFunctionSymbolIndex!] => sourceFunctionSymbol
            sourceFunctionSymbol.kind == 7 or sourceFunctionSymbol.kind == 31 or sourceFunctionSymbol.kind == 36
                -> if { sourceFunctionRequests! -> push(FunctionLowerRequest { sourceIndex: sourceIndex, symbolIndex: sourceFunctionSymbolIndex! }) }
            sourceFunctionSymbolIndex! + 1 => sourceFunctionSymbolIndex!
        }
        sourceFunctionRequests! -> lowerFunctionRequests(parallelFunctions) => sourceFunctionResults!
        results! -> appendAndReleaseFunctionResults(sourceFunctionResults!)
'@.TrimEnd("`r", "`n")
if ([regex]::Matches($typedText, [regex]::Escape($rangeMerge)).Count -ne 1) {
    throw "C85 control could not find exactly one global range merge anchor"
}
$overlayText = $typedText.Replace($rangeMerge, $perSourceMerge)

$globalPattern = '(?ms)^    \[FunctionLowerRequest; ~\] => globalFunctionRequests!\r?\n.*?^    globalFunctionRequests! -> lowerFunctionRequests\(parallelFunctions\) => globalFunctionResults!\r?\n'
$globalMatches = [regex]::Matches($overlayText, $globalPattern)
if ($globalMatches.Count -ne 1) {
    throw "C85 control could not find exactly one compiler-wide request collection"
}
$overlayText = [regex]::Replace(
    $overlayText,
    $globalPattern,
    "    prepared.package.sources -> len => sourceCount`r`n",
    1)
if ($overlayText.Contains('globalFunctionRequests! -> lowerFunctionRequests')) {
    throw "C85 control retained the compiler-wide dispatch"
}
$overlayText = $overlayText.Replace(
    '    lowerSource requestedSourceIndex: Int, functionResults: mut [SourceTypedIr; ~] -> SourceTypedIr {',
    '    lowerSource requestedSourceIndex: Int -> SourceTypedIr {')
$overlayText = $overlayText.Replace(
    '        sourceLowerIndex! -> lowerSource(globalFunctionResults!) => sourceResult',
    '        sourceLowerIndex! -> lowerSource => sourceResult')
if ($overlayText.Contains('lowerSource(globalFunctionResults!)')) {
    throw "C85 control retained the compiler-wide result owner"
}
if ([regex]::Matches(
        $overlayText,
        [regex]::Escape('sourceFunctionRequests! -> lowerFunctionRequests(parallelFunctions)')).Count -ne 1) {
    throw "C85 control did not materialize exactly one textual per-source dispatch"
}

$overlayPath = Join-Path $outputRoot "typed.per-source-control.slg"
[IO.File]::WriteAllText($overlayPath, $overlayText, [Text.UTF8Encoding]::new($false))

function Resolve-Manifest([string]$Path) {
    @(Get-Content -LiteralPath $Path |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path })
}

$compilerManifest = Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
$runtimeManifest = Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt"
$compilerSources = Resolve-Manifest $compilerManifest
$runtimeSources = Resolve-Manifest $runtimeManifest
$currentSourceFingerprint = Get-CompilerEmissionInputFingerprint `
    -RepositoryRoot $repoRoot -Path @($compilerSources + $runtimeSources)
$typedResolved = (Resolve-Path -LiteralPath $typedPath).Path
$overlayCompilerSources = @($compilerSources | ForEach-Object {
    if ([string]::Equals($_, $typedResolved, [StringComparison]::OrdinalIgnoreCase)) {
        $overlayPath
    } else {
        $_
    }
})
if (@($overlayCompilerSources | Where-Object { $_ -ceq $overlayPath }).Count -ne 1) {
    throw "C85 control source manifest did not replace exactly one typed.slg"
}
if ($PrepareOnly) {
    Write-Host "[C85 performance control] PREPARED $overlayPath"
    return
}

$llvmRoot = Join-Path $repoRoot ".tools/llvm-22.1.8"
$llvmAs = Join-Path $llvmRoot "bin/llvm-as.exe"
$clang = Join-Path $llvmRoot "bin/clang.exe"
$llvmPath = Join-Path $outputRoot "selfhost-c85-per-source-control.ll"
$errorPath = Join-Path $outputRoot "selfhost-c85-per-source-control.err"
$bitcodePath = Join-Path $outputRoot "selfhost-c85-per-source-control.bc"
$compilerPath = Join-Path $outputRoot "selfhost-c85-per-source-control.exe"

Invoke-VerificationProcessToFile `
    -FilePath $seedPath `
    -ArgumentList (@("windows") + $overlayCompilerSources + $runtimeSources) `
    -Description "C85 per-source SLG compiler control emission" `
    -OutputPath $llvmPath `
    -ErrorPath $errorPath `
    -TimeoutMilliseconds $TimeoutMilliseconds
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $llvmPath
& (Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1") `
    -LlvmPath $llvmPath -MinimumCallbackCount 4 -RequireNominalTransfer
& $llvmAs $llvmPath -o $bitcodePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clang -Wno-override-module $llvmPath -O1 -o $compilerPath -lws2_32 -lshell32 -lbcrypt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$receipt = [ordered]@{
    schemaVersion = 1
    mode = "c85-per-source-performance-control"
    seedCompilerFingerprint = $seedHash
    currentSourceFingerprint = $currentSourceFingerprint
    overlaySourceFingerprint = Get-CompilerEmissionInputFingerprint `
        -RepositoryRoot $repoRoot -Path @($overlayCompilerSources + $runtimeSources)
    overlayPath = [IO.Path]::GetRelativePath($repoRoot, $overlayPath).Replace('\', '/')
    compilerPath = [IO.Path]::GetRelativePath($repoRoot, $compilerPath).Replace('\', '/')
    compilerFingerprint = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
    llvmPath = [IO.Path]::GetRelativePath($repoRoot, $llvmPath).Replace('\', '/')
    llvmFingerprint = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
    dispatch = "per-source"
}
$verifiedCurrentSourceFingerprint = Get-CompilerEmissionInputFingerprint `
    -RepositoryRoot $repoRoot -Path @($compilerSources + $runtimeSources)
if ($verifiedCurrentSourceFingerprint -cne $currentSourceFingerprint) {
    throw "C85 current compiler sources changed during control generation; discard the candidate and rerun"
}
$receiptJson = ($receipt | ConvertTo-Json -Depth 4) + "`n"
$schemaPath = Join-Path $repoRoot "scripts/contracts/c85-per-source-performance-control.schema.json"
if (-not ($receiptJson | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "C85 control receipt does not match $schemaPath"
}
$receiptPath = Join-Path $outputRoot "receipt.json"
[IO.File]::WriteAllText($receiptPath, $receiptJson, [Text.UTF8Encoding]::new($false))
Write-Host "[C85 performance control] PASS $receiptPath"
