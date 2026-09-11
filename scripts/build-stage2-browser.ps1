[CmdletBinding()]
param(
    [string]$Stage2Compiler = "artifacts\example-tests\selfhost-stage2.exe",
    [switch]$ReuseCompilerArtifact,
    [string]$FocusedFixture = "",
    [switch]$AllowUnpromotedCandidate,
    [string]$CandidateOutputDirectory = "artifacts\scratch\browser-focused"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")
. (Join-Path $PSScriptRoot "browser-stage2-input-fingerprint.ps1")
. (Join-Path $PSScriptRoot "browser-output-scope.ps1")
$stage2Path = (Resolve-Path (Join-Path $repoRoot $Stage2Compiler)).Path
$manifestPath = Join-Path $repoRoot "selfhost\browser_driver.sources.txt"
$llvmRoot = Join-Path $repoRoot ".tools\llvm-22.1.8"
$llvmAs = Join-Path $llvmRoot "bin\llvm-as.exe"
$clang = Join-Path $llvmRoot "bin\clang.exe"
$wasmLd = Join-Path $llvmRoot "bin\wasm-ld.exe"
$nodePath = (Get-Command node -ErrorAction Stop).Source
$focusedMode = -not [string]::IsNullOrWhiteSpace($FocusedFixture)
if ($AllowUnpromotedCandidate -ne $focusedMode) {
    throw "AllowUnpromotedCandidate and FocusedFixture must be supplied together"
}
if ($AllowUnpromotedCandidate -and $ReuseCompilerArtifact) {
    throw "an unpromoted focused candidate cannot reuse a previously published browser artifact"
}
$compilerOutputCandidate = if ($AllowUnpromotedCandidate) {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $CandidateOutputDirectory))
} else {
    Join-Path $repoRoot "artifacts"
}
$artifactRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "artifacts"))
$compilerOutputRoot = Assert-BrowserCompilerOutputRoot `
    -CandidatePath $compilerOutputCandidate `
    -ArtifactRoot $artifactRoot
New-Item -ItemType Directory -Path $compilerOutputRoot -Force | Out-Null
$compilerLlvm = Join-Path $compilerOutputRoot "sollangc-browser-stage2.ll"
$compilerError = Join-Path $compilerOutputRoot "sollangc-browser-stage2.err"
$compilerBitcode = Join-Path $compilerOutputRoot "sollangc-browser-stage2.bc"
$compilerObject = Join-Path $compilerOutputRoot "sollangc-browser-stage2.o"
$compilerArtifact = Join-Path $compilerOutputRoot "sollangc-browser.wasm"
$compilerFingerprint = Join-Path $compilerOutputRoot "sollangc-browser.inputs.sha256"
$compilerReceipt = Join-Path $compilerOutputRoot "sollangc-browser.outputs.sha256"
$publicCompiler = Join-Path $repoRoot "public\sollangc-stage2-0.4.260817.wasm"

function Invoke-BrowserTool {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Description
    )

    $result = Invoke-VerificationProcess `
        -FilePath $FilePath `
        -ArgumentList $Arguments `
        -Description $Description
    if (-not [string]::IsNullOrWhiteSpace($result.Stdout)) {
        Write-Host -NoNewline $result.Stdout
    }
    if (-not [string]::IsNullOrWhiteSpace($result.Stderr)) {
        Write-Host -NoNewline $result.Stderr
    }
}

$browserSources = Get-Content -LiteralPath $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }

$candidateInputFingerprint = Get-BrowserStage2InputFingerprint `
    -RepositoryRoot $repoRoot `
    -Stage2Path $stage2Path `
    -ManifestPath $manifestPath `
    -BuildScriptPath $PSCommandPath `
    -LlvmAsPath $llvmAs `
    -ClangPath $clang `
    -WasmLdPath $wasmLd

& (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
    -Manifest $manifestPath `
    -RepositoryRoot $repoRoot
Invoke-BrowserTool $stage2Path (@("format", "--check") + $browserSources) "browser compiler source format"
if ($AllowUnpromotedCandidate) {
    Write-Host "[browser candidate] Focused fixture $FocusedFixture uses an explicit unpromoted compiler and scratch-only outputs."
} else {
    $stage2FileName = [System.IO.Path]::GetFileNameWithoutExtension($stage2Path)
    if (-not $stage2FileName.Contains("stage2", [System.StringComparison]::Ordinal)) {
        throw "browser compiler input must be a receipt-bound Stage2 artifact with a Stage3 sibling: $stage2Path"
    }
    $stage3FileName = $stage2FileName.Replace("stage2", "stage3", [System.StringComparison]::Ordinal)
    $stage3Path = Join-Path `
        ([System.IO.Path]::GetDirectoryName($stage2Path)) `
        ($stage3FileName + [System.IO.Path]::GetExtension($stage2Path))
    & (Join-Path $PSScriptRoot "verify-selfhost-stage3-artifacts.ps1") `
        -Platform windows `
        -Stage3Path $stage3Path `
        -RepositoryRoot $repoRoot
}

if ($ReuseCompilerArtifact) {
    $receiptCurrent = Test-Stage2ArtifactReceipt `
        -LlvmPath $compilerLlvm `
        -BitcodePath $compilerBitcode `
        -ExecutablePath $compilerArtifact `
        -ReceiptPath $compilerReceipt `
        -AdditionalArtifacts @{ object = $compilerObject }
    $fingerprintCurrent = (Test-Path -LiteralPath $compilerFingerprint) -and
        [System.IO.File]::ReadAllText($compilerFingerprint).Trim() -ceq $candidateInputFingerprint
    if (-not $receiptCurrent -or -not $fingerprintCurrent) {
        throw "browser compiler artifact is missing, mutated, or stale; rerun without -ReuseCompilerArtifact"
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
        -WindowStyle Hidden
    Wait-VerificationProcess $process "browser Stage2 compiler emission"
    $compilerDiagnostics = [System.IO.File]::ReadAllText($compilerError)
    if ($process.ExitCode -ne 0) {
        throw "Stage2 browser emission failed.`n$compilerDiagnostics"
    }
    if (-not [string]::IsNullOrWhiteSpace($compilerDiagnostics)) {
        throw "Stage2 browser emission produced warnings or notes; compiler builds require empty stderr.`n$compilerDiagnostics"
    }
    $compilerLlvmText = [System.IO.File]::ReadAllText($compilerLlvm)
    $sourceTextPushPattern = '(?s)%push(?<sourceTextPush>\d+)_append_bytes = mul i64 %push\k<sourceTextPush>_append_capacity, 32.*?%push\k<sourceTextPush>_slot = getelementptr %sollang\.source_text'
    if (-not [System.Text.RegularExpressions.Regex]::IsMatch($compilerLlvmText, $sourceTextPushPattern)) {
        throw "Stage2 browser compiler did not allocate 32 bytes per SourceText array element"
    }

    Write-Host "[browser 2/4] Verify and link the Stage2-emitted LLVM."
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $compilerLlvm
    Invoke-BrowserTool $llvmAs @($compilerLlvm, "-o", $compilerBitcode) "browser compiler llvm-as"
    Invoke-BrowserTool $clang @(
        "-target", "wasm32-unknown-unknown-wasm",
        "-O2",
        "-g",
        "-fno-addrsig",
        "-c", $compilerLlvm,
        "-o", $compilerObject
    ) "browser compiler clang"
    Invoke-BrowserTool $wasmLd @(
        "--no-entry",
        "--export=sollang_start",
        "--export=sollang_alloc",
        "--export-memory",
        "--allow-undefined",
        "--gc-sections",
        $compilerObject,
        "-o", $compilerArtifact
    ) "browser compiler wasm-ld"

}

$regressionCases = @(
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-implicit-main-multiplication-table.slg", "browser-stage2-implicit-main-multiplication-table.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-implicit-main-multiplication-table.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-each.slg", "browser-stage2-range-each.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-each.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-fold.slg", "browser-stage2-range-fold.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-range-fold.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-when.slg", "browser-stage2-when.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-when.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-raw-strings.slg", "browser-stage2-raw-strings.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-raw-strings.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-containers.slg", "browser-stage2-containers.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-containers.stdout.txt"),
    @("examples\regression\854-set-key-only.slg", "browser-stage2-set.ll", "examples\regression\expected\854-set-key-only.stdout.txt"),
    @("examples\regression\1134-wasm-struct-array-i64-fragment-identity.slg", "browser-stage2-fragment-identity.ll", "examples\regression\expected\1134-wasm-struct-array-i64-fragment-identity.stdout.txt"),
    @("examples\regression\1135-wasm-uintsize-interpolation-width.slg", "browser-stage2-uintsize-interpolation.ll", "examples\regression\expected\1135-wasm-uintsize-interpolation-width.stdout.txt"),
    @("examples\regression\1136-wasm-trailing-value-if-effect.slg", "browser-stage2-trailing-value-if.ll", "examples\regression\expected\1136-wasm-trailing-value-if-effect.stdout.txt"),
    @("examples\regression\1137-browser-open-import-second-fragment.slg", "browser-stage2-open-import-second-fragment.ll", "examples\regression\expected\1137-browser-open-import-second-fragment.stdout.txt", "", "examples\regression\expected\1137-browser-open-import-second-fragment.sources.txt"),
    @("examples\regression\1017-quic-friendly-ipv4-endpoints.slg", "browser-stage2-quic-endpoint-values.ll", "examples\regression\expected\1017-quic-friendly-ipv4-endpoints.stdout.txt"),
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
    @("examples\regression\845-browser-unit-block-yield.slg", "browser-stage2-unit-block-yield.ll", "examples\regression\expected\845-browser-unit-block-yield.stdout.txt"),
    @("tests\Sollang.ExampleTests\Fixtures\browser-stage2-result-propagation-control.slg", "browser-stage2-result-propagation-control.ll", "tests\Sollang.ExampleTests\Fixtures\browser-stage2-result-propagation-control.stdout.txt"),
    @("examples\regression\1390-browser-time-domain-separation.slg", "browser-stage2-time-domain-separation.ll", "examples\regression\expected\1390-browser-time-domain-separation.stdout.txt"),
    @("examples\regression\1391-opaque-struct-instance-boundary.slg", "browser-stage2-opaque-struct-instance-boundary.ll", "examples\regression\expected\1391-opaque-struct-instance-boundary.stdout.txt", "", "examples\regression\expected\1391-opaque-struct-instance-boundary.sources.txt"),
    @("examples\regression\1321-parallel-additional-borrow-result.slg", "browser-stage2-parallel-additional-borrow-result.ll", "examples\regression\expected\1321-parallel-additional-borrow-result.stdout.txt"),
    @("examples\regression\1681-function-boolean-when-result.slg", "browser-stage2-function-boolean-when-result.ll", "examples\regression\expected\1681-function-boolean-when-result.stdout.txt"),
    @("examples\regression\1688-io-file-protocol-adapters.slg", "browser-stage2-file-protocol-adapters.ll", "examples\regression\expected\1688-io-file-protocol-adapters.browser.stdout.txt"),
    @("examples\regression\575-multiplication-table.slg", "browser-stage2-println-call-order.ll", "examples\regression\expected\575-multiplication-table.stdout.txt"),
    @(
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-read-int.slg",
        "browser-stage2-read-int.ll",
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-read-int.stdout.txt",
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-read-int.stdin.txt"
    )
)
if ($focusedMode) {
    $regressionCases = @($regressionCases | Where-Object {
        [System.IO.Path]::GetFileNameWithoutExtension($_[0]) -ceq $FocusedFixture
    })
    if ($regressionCases.Count -ne 1) {
        throw "focused browser fixture is not registered exactly once: $FocusedFixture"
    }
}
Write-Host "[browser 3/4] Execute $($regressionCases.Count) browser compiler regression(s)."
foreach ($case in $regressionCases) {
    $programLlvm = Join-Path $compilerOutputRoot $case[1]
    $programBitcode = [System.IO.Path]::ChangeExtension($programLlvm, ".bc")
    $programObject = [System.IO.Path]::ChangeExtension($programLlvm, ".o")
    $programWasm = [System.IO.Path]::ChangeExtension($programLlvm, ".wasm")
    $compilerArguments = @(
        (Join-Path $PSScriptRoot "verify-browser-stage2.mjs"),
        $compilerArtifact,
        (Join-Path $repoRoot $case[0]),
        $programLlvm
    )
    if ($case.Count -gt 4) {
        $compilerArguments += "--source-manifest"
        $compilerArguments += (Join-Path $repoRoot $case[4])
    }
    Invoke-BrowserTool $nodePath $compilerArguments "browser compiler regression $($case[0])"
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $programLlvm
    Invoke-BrowserTool $llvmAs @($programLlvm, "-o", $programBitcode) "browser program llvm-as $($case[0])"
    Invoke-BrowserTool $clang @(
        "-target", "wasm32-unknown-unknown-wasm",
        "-O2",
        "-fno-addrsig",
        "-c", $programLlvm,
        "-o", $programObject
    ) "browser program clang $($case[0])"
    Invoke-BrowserTool $wasmLd @(
        "--no-entry",
        "--export=sollang_start",
        "--export-memory",
        "--allow-undefined",
        "--gc-sections",
        $programObject,
        "-o", $programWasm
    ) "browser program wasm-ld $($case[0])"
    $verifyArguments = @(
        (Join-Path $PSScriptRoot "verify-browser-program.mjs"),
        $programWasm,
        (Join-Path $repoRoot $case[2])
    )
    if ($case.Count -gt 3 -and -not [string]::IsNullOrWhiteSpace($case[3])) {
        $verifyArguments += (Join-Path $repoRoot $case[3])
    }
    Invoke-BrowserTool $nodePath $verifyArguments "browser program execution $($case[0])"
}

if (-not $focusedMode) {
foreach ($diagnosticCase in @(
    @(
        "examples\regression\diagnostics\browser-interpolation-boundary.slg",
        "artifacts\browser-stage2-interpolation-diagnostic.txt",
        "unknown interpolation binding 'dimohy는'"
    ),
    @(
        "tests\Sollang.ExampleTests\Fixtures\browser-stage2-unknown-flow-target.slg",
        "artifacts\browser-stage2-unknown-flow-target-diagnostic.txt",
        "unresolved call target 'println2'"
    ),
    @(
        "examples\regression\diagnostics\848-bare-println-expression.slg",
        "artifacts\browser-stage2-bare-println-diagnostic.txt",
        "function 'println' expects an argument and must use call or flow syntax"
    ),
    @(
        "examples\regression\diagnostics\849-unterminated-flow-println.slg",
        "artifacts\browser-stage2-unterminated-string-diagnostic.txt",
        "unterminated string literal"
    ),
    @(
        "examples\regression\diagnostics\return-outside-function.slg",
        "artifacts\browser-stage2-return-outside-function-diagnostic.txt",
        "'return' is only valid inside a value or Unit function"
    ),
    @(
        "examples\regression\588-mouse-event-stream.slg",
        "artifacts\browser-stage2-mouse-event-diagnostic.txt",
        "mouse event streams are unavailable on wasm32-browser; browser events require host-driven callback lowering"
    ),
    @(
        "examples\regression\802-readonly-parallel-branch.slg",
        "artifacts\browser-stage2-parallel-branch-diagnostic.txt",
        "parallel execution is unavailable on wasm32-browser because the target does not provide a compute worker pool"
    ),
    @(
        "examples\regression\1024-socket-ipv6-udp-roundtrip.slg",
        "artifacts\browser-stage2-network-capability-diagnostic.txt",
        "network sockets are unavailable on wasm32-browser; use a host-provided networking adapter"
    ),
    @(
        "examples\regression\diagnostics\opaque-struct-construction.slg",
        "artifacts\browser-stage2-opaque-struct-construction-diagnostic.txt",
        "cannot construct struct 'sample.opaque_value.Token' outside module 'sample.opaque_value' because field 'raw' is private; use its public factory or public instance methods",
        "examples\regression\diagnostics\opaque-struct-construction.sources.txt"
    ),
    @(
        "examples\regression\diagnostics\opaque-struct-field-read.slg",
        "artifacts\browser-stage2-opaque-struct-field-read-diagnostic.txt",
        "cannot read private field 'raw' of struct 'sample.opaque_value.Token' outside module 'sample.opaque_value'; use its public factory or public instance methods",
        "examples\regression\diagnostics\opaque-struct-field-read.sources.txt"
    ),
    @(
        "examples\regression\diagnostics\opaque-struct-field-write.slg",
        "artifacts\browser-stage2-opaque-struct-field-write-diagnostic.txt",
        "cannot write private field 'raw' of struct 'sample.opaque_value.Token' outside module 'sample.opaque_value'; use its public factory or public instance methods",
        "examples\regression\diagnostics\opaque-struct-field-write.sources.txt"
    ),
    @(
        "examples\regression\diagnostics\opaque-struct-modifier-rejected.slg",
        "artifacts\browser-stage2-obsolete-opaque-modifier-diagnostic.txt",
        "parse error at 1:8: expected end of statement"
    ),
    @(
        "examples\regression\diagnostics\private-inferred-field-chain.slg",
        "artifacts\browser-stage2-private-inferred-field-chain-diagnostic.txt",
        "cannot read private field 'secret' of struct 'sample.opaque_value.Inner' outside module 'sample.opaque_value'; use its public factory or public instance methods",
        "examples\regression\diagnostics\private-inferred-field-chain.sources.txt"
    )
)) {
    $expectedDiagnosticBase64 = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($diagnosticCase[2]))
    $diagnosticArguments = @(
        (Join-Path $PSScriptRoot "verify-browser-stage2.mjs"),
        $compilerArtifact,
        (Join-Path $repoRoot $diagnosticCase[0]),
        (Join-Path $repoRoot $diagnosticCase[1]),
        "--expect-diagnostic-base64",
        $expectedDiagnosticBase64
    )
    if ($diagnosticCase.Count -gt 3) {
        $diagnosticArguments += "--source-manifest"
        $diagnosticArguments += (Join-Path $repoRoot $diagnosticCase[3])
    }
    Invoke-BrowserTool $nodePath $diagnosticArguments "browser diagnostic $($diagnosticCase[0])"
}
}

if (-not $ReuseCompilerArtifact) {
    $currentInputFingerprint = Get-BrowserStage2InputFingerprint `
        -RepositoryRoot $repoRoot `
        -Stage2Path $stage2Path `
        -ManifestPath $manifestPath `
        -BuildScriptPath $PSCommandPath `
        -LlvmAsPath $llvmAs `
        -ClangPath $clang `
        -WasmLdPath $wasmLd
    if ($currentInputFingerprint -cne $candidateInputFingerprint) {
        throw "browser compiler inputs changed during generation or regression verification; rerun the build"
    }
    Write-Stage2ArtifactReceipt `
        -LlvmPath $compilerLlvm `
        -BitcodePath $compilerBitcode `
        -ExecutablePath $compilerArtifact `
        -ReceiptPath $compilerReceipt `
        -AdditionalArtifacts @{ object = $compilerObject }
    $candidateFingerprintPath = Get-CandidateArtifactPath $compilerFingerprint
    [System.IO.File]::WriteAllText($candidateFingerprintPath, $candidateInputFingerprint)
    Move-Item -LiteralPath $candidateFingerprintPath -Destination $compilerFingerprint -Force
}

$artifactHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $compilerArtifact).Hash
if ($AllowUnpromotedCandidate) {
    Write-Host "[browser 4/4] Retain the verified focused candidate under artifacts without publication."
    Write-Host "[browser focused candidate] PASS $artifactHash"
} else {
    Write-Host "[browser 4/4] Publish only the verified compiler artifact."
    Copy-Item -LiteralPath $compilerArtifact -Destination $publicCompiler -Force
    $publicHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $publicCompiler).Hash
    if ($artifactHash -ne $publicHash) {
        throw "published browser compiler hash differs from the verified artifact"
    }

    Write-Host "[browser stage2] PASS $publicHash"
}
