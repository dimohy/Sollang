[CmdletBinding()]
param(
    [string]$Stage2Compiler = "artifacts\example-tests\selfhost-stage2.exe",
    [switch]$ReuseCompilerArtifact
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$stage2Path = (Resolve-Path (Join-Path $repoRoot $Stage2Compiler)).Path
$manifestPath = Join-Path $repoRoot "selfhost\browser_driver.sources.txt"
$llvmRoot = Join-Path $repoRoot ".tools\llvm-22.1.8"
$llvmAs = Join-Path $llvmRoot "bin\llvm-as.exe"
$clang = Join-Path $llvmRoot "bin\clang.exe"
$wasmLd = Join-Path $llvmRoot "bin\wasm-ld.exe"
$compilerLlvm = Join-Path $repoRoot "artifacts\sollangc-browser-stage2.ll"
$compilerError = Join-Path $repoRoot "artifacts\sollangc-browser-stage2.err"
$compilerBitcode = Join-Path $repoRoot "artifacts\sollangc-browser-stage2.bc"
$compilerObject = Join-Path $repoRoot "artifacts\sollangc-browser-stage2.o"
$compilerArtifact = Join-Path $repoRoot "artifacts\sollangc-browser.wasm"
$publicCompiler = Join-Path $repoRoot "public\sollangc-stage2-0.3.260727.wasm"

$browserSources = Get-Content -LiteralPath $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }

if ($ReuseCompilerArtifact) {
    if (-not (Test-Path -LiteralPath $compilerArtifact)) {
        throw "verified browser compiler artifact is missing: $compilerArtifact"
    }
    Write-Host "[browser 1/4] Reuse the explicitly selected browser compiler artifact."
    Write-Host "[browser 2/4] Reused artifact: $compilerArtifact"
} else {
    Write-Host "[browser 1/4] Emit the browser compiler with the verified Stage2 compiler."
    $process = Start-Process `
        -FilePath $stage2Path `
        -ArgumentList (@("wasm") + $browserSources) `
        -RedirectStandardOutput $compilerLlvm `
        -RedirectStandardError $compilerError `
        -PassThru `
        -WindowStyle Hidden `
        -Wait
    if ($process.ExitCode -ne 0) {
        throw "Stage2 browser emission failed.`n$([System.IO.File]::ReadAllText($compilerError))"
    }

    Write-Host "[browser 2/4] Verify and link the Stage2-emitted LLVM."
    & $llvmAs $compilerLlvm -o $compilerBitcode
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $clang `
        -target wasm32-unknown-unknown-wasm `
        -O2 `
        -g `
        -fno-addrsig `
        -c $compilerLlvm `
        -o $compilerObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wasmLd `
        --no-entry `
        --export=sollang_start `
        --export=sollang_alloc `
        --export-memory `
        --allow-undefined `
        --gc-sections `
        $compilerObject `
        -o $compilerArtifact
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "[browser 3/4] Execute browser compiler regressions."
foreach ($case in @(
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-each.slg", "browser-stage2-range-each.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-each.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-fold.slg", "browser-stage2-range-fold.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-fold.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-when.slg", "browser-stage2-when.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-when.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-raw-strings.slg", "browser-stage2-raw-strings.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-raw-strings.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-containers.slg", "browser-stage2-containers.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-containers.stdout.txt"),
    @("examples\regression\576-linq-multiplication-table.slg", "browser-stage2-table.ll", "examples\regression\expected\576-linq-multiplication-table.stdout.txt"),
    @("examples\regression\580-deferred-text-evaluation.slg", "browser-stage2-deferred-text.ll", "examples\regression\expected\580-deferred-text-evaluation.stdout.txt"),
    @("examples\regression\582-billion-sensor-alerts.slg", "browser-stage2-sensor.ll", "examples\regression\expected\582-billion-sensor-alerts.stdout.txt"),
    @("examples\regression\583-stream-state-take-skip.slg", "browser-stage2-state.ll", "examples\regression\expected\583-stream-state-take-skip.stdout.txt"),
    @("examples\regression\585-stream-transaction-risk-scan.slg", "browser-stage2-risk.ll", "examples\regression\expected\585-stream-transaction-risk-scan.stdout.txt"),
    @("examples\regression\790-sequential-named-branch.slg", "browser-stage2-flow-branch.ll", "examples\regression\expected\790-sequential-named-branch.stdout.txt"),
    @("examples\regression\792-branch-source-order-and-multistage.slg", "browser-stage2-flow-branch-order.ll", "examples\regression\expected\792-branch-source-order-and-multistage.stdout.txt"),
    @("examples\regression\793-tap-block-flow.slg", "browser-stage2-flow-tap.ll", "examples\regression\expected\793-tap-block-flow.stdout.txt"),
    @("examples\regression\795-labeled-product-user-counterpart.slg", "browser-stage2-flow-labeled-product.ll", "examples\regression\expected\795-labeled-product-user-counterpart.stdout.txt"),
    @("examples\regression\796-ordinary-product-user-counterpart.slg", "browser-stage2-flow-product.ll", "examples\regression\expected\796-ordinary-product-user-counterpart.stdout.txt"),
    @("examples\regression\797-partition-first-match-direct-dispatch.slg", "browser-stage2-flow-partition.ll", "examples\regression\expected\797-partition-first-match-direct-dispatch.stdout.txt"),
    @("examples\regression\798-zip-shortest-stream.slg", "browser-stage2-flow-zip.ll", "examples\regression\expected\798-zip-shortest-stream.stdout.txt"),
    @("examples\regression\800-merge-cold-stream-availability.slg", "browser-stage2-flow-merge.ll", "examples\regression\expected\800-merge-cold-stream-availability.stdout.txt"),
    @("examples\regression\801-concat-and-latest-policies.slg", "browser-stage2-flow-latest.ll", "examples\regression\expected\801-concat-and-latest-policies.stdout.txt"),
    @(
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-read-int.slg",
        "browser-stage2-read-int.ll",
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-read-int.stdout.txt",
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-read-int.stdin.txt"
    )
)) {
    $programLlvm = Join-Path $repoRoot "artifacts\$($case[1])"
    $programBitcode = [System.IO.Path]::ChangeExtension($programLlvm, ".bc")
    $programObject = [System.IO.Path]::ChangeExtension($programLlvm, ".o")
    $programWasm = [System.IO.Path]::ChangeExtension($programLlvm, ".wasm")
    & node (Join-Path $PSScriptRoot "verify-browser-stage2.mjs") `
        $compilerArtifact `
        (Join-Path $repoRoot $case[0]) `
        $programLlvm
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $llvmAs $programLlvm -o $programBitcode
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $clang -target wasm32-unknown-unknown-wasm -O2 -fno-addrsig -c $programLlvm -o $programObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $wasmLd `
        --no-entry `
        --export=sollang_start `
        --export-memory `
        --allow-undefined `
        --gc-sections `
        $programObject `
        -o $programWasm
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $verifyArguments = @(
        (Join-Path $PSScriptRoot "verify-browser-program.mjs"),
        $programWasm,
        (Join-Path $repoRoot $case[2])
    )
    if ($case.Count -gt 3) {
        $verifyArguments += (Join-Path $repoRoot $case[3])
    }
    & node $verifyArguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& node (Join-Path $PSScriptRoot "verify-browser-stage2.mjs") `
    $compilerArtifact `
    (Join-Path $repoRoot "examples\regression\diagnostics\browser-interpolation-boundary.slg") `
    (Join-Path $repoRoot "artifacts\browser-stage2-interpolation-diagnostic.txt") `
    "unknown interpolation binding 'dimohy는'"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& node (Join-Path $PSScriptRoot "verify-browser-stage2.mjs") `
    $compilerArtifact `
    (Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\browser-stage2-unknown-flow-target.slg") `
    (Join-Path $repoRoot "artifacts\browser-stage2-unknown-flow-target-diagnostic.txt") `
    "unresolved call target 'println2'"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& node (Join-Path $PSScriptRoot "verify-browser-stage2.mjs") `
    $compilerArtifact `
    (Join-Path $repoRoot "examples\regression\588-mouse-event-stream.slg") `
    (Join-Path $repoRoot "artifacts\browser-stage2-mouse-event-diagnostic.txt") `
    "mouse event streams are unavailable on wasm32-browser; browser events require host-driven callback lowering"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& node (Join-Path $PSScriptRoot "verify-browser-stage2.mjs") `
    $compilerArtifact `
    (Join-Path $repoRoot "examples\regression\802-readonly-parallel-branch.slg") `
    (Join-Path $repoRoot "artifacts\browser-stage2-parallel-branch-diagnostic.txt") `
    "parallel execution is unavailable on wasm32-browser because the target does not provide a compute worker pool"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[browser 4/4] Publish only the verified compiler artifact."
Copy-Item -LiteralPath $compilerArtifact -Destination $publicCompiler -Force
$artifactHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $compilerArtifact).Hash
$publicHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $publicCompiler).Hash
if ($artifactHash -ne $publicHash) {
    throw "published browser compiler hash differs from the verified artifact"
}

Write-Host "[browser stage2] PASS $publicHash"
