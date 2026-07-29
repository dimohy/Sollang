[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$facadePath = Join-Path $repoRoot "selfhost/llvm/text.slg"
$modulePaths = @(
    "selfhost/llvm/emitter/number_format.slg"
    "selfhost/llvm/emitter/compute_runtime.slg"
    "selfhost/llvm/emitter/text_output_runtime.slg"
    "selfhost/llvm/emitter/process_runtime.slg"
    "selfhost/llvm/emitter/mouse_event_runtime.slg"
    "selfhost/llvm/emitter/com_runtime.slg"
    "selfhost/llvm/emitter/ownership.slg"
    "selfhost/llvm/emitter/context.slg"
    "selfhost/llvm/emitter/type_queries.slg"
    "selfhost/llvm/emitter/diagnostics.slg"
)
$fragmentPaths = @(
    "selfhost/llvm/text/foundation.slg"
    "selfhost/llvm/text/text_literals.slg"
    "selfhost/llvm/text/native_handles.slg"
    "selfhost/llvm/text/entrypoints.slg"
    "selfhost/llvm/text/core_calls.slg"
    "selfhost/llvm/text/ownership.slg"
    "selfhost/llvm/text/platform_io.slg"
    "selfhost/llvm/text/containers.slg"
    "selfhost/llvm/text/control.slg"
    "selfhost/llvm/text/functions.slg"
)

$facadeLines = [IO.File]::ReadAllLines($facadePath)
if ($facadeLines.Count -gt 4500) {
    throw "selfhost/llvm/text.slg grew to $($facadeLines.Count) lines; keep the core orchestration below 4,500 lines."
}

$facadeText = [IO.File]::ReadAllText($facadePath)
foreach ($relativePath in $modulePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing LLVM emitter module: $relativePath"
    }

    $moduleName = [IO.Path]::GetFileNameWithoutExtension($relativePath)
    $expectedNamespace = "namespace sollang.compiler.llvm.emitter.$moduleName"
    $firstLine = [IO.File]::ReadLines($absolutePath) | Select-Object -First 1
    if ($firstLine -ne $expectedNamespace) {
        throw "$relativePath must declare '$expectedNamespace'."
    }

    if ($facadeText -notmatch [regex]::Escape("sollang.compiler.llvm.emitter.$moduleName")) {
        throw "selfhost/llvm/text.slg does not import $relativePath."
    }
}

$logicalNamespace = "namespace sollang.compiler.llvm.text"
foreach ($relativePath in $fragmentPaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
        throw "Missing LLVM text fragment: $relativePath"
    }

    $firstLine = [IO.File]::ReadLines($absolutePath) | Select-Object -First 1
    if ($firstLine -ne $logicalNamespace) {
        throw "$relativePath must contribute to '$logicalNamespace'."
    }

    $fragmentLines = [IO.File]::ReadAllLines($absolutePath)
    if ($fragmentLines.Count -gt 3000) {
        throw "$relativePath grew to $($fragmentLines.Count) lines; split the responsibility before it exceeds 3,000 lines."
    }
}

$statefulFragments = $fragmentPaths | Where-Object {
    $_ -match "/(core_calls|ownership|platform_io|containers|control|functions)\.slg$"
}
foreach ($relativePath in $statefulFragments) {
    $text = [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
    if (-not $text.Contains("context: ref emitterContext.EmitContext", [System.StringComparison]::Ordinal) `
        -or -not $text.Contains("state: ref CoreEmitterState", [System.StringComparison]::Ordinal)) {
        throw "$relativePath must pass emitter context and frozen state by readonly reference."
    }
    if ($text.Contains("context: emitterContext.EmitContext", [System.StringComparison]::Ordinal) `
        -or $text.Contains("state: CoreEmitterState", [System.StringComparison]::Ordinal)) {
        throw "$relativePath contains a by-value emitter context/state boundary."
    }
}

$manifestPaths = @(
    Get-ChildItem (Join-Path $repoRoot "examples/regression/expected") -Filter "*.sources.txt"
    Get-Item (Join-Path $repoRoot "selfhost/browser_driver.sources.txt")
    Get-Item (Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt")
    Get-Item (Join-Path $repoRoot "tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-driver.sources.txt")
)
foreach ($manifestPath in $manifestPaths) {
    $lines = [IO.File]::ReadAllLines($manifestPath.FullName)
    if ($lines -notcontains "selfhost/llvm/text.slg") {
        continue
    }

    foreach ($relativePath in @($modulePaths) + @($fragmentPaths)) {
        if ($lines -notcontains $relativePath) {
            throw "$($manifestPath.Name) omits imported emitter module $relativePath."
        }
    }
}

Write-Host "PASS LLVM emitter modules: facade=$($facadeLines.Count) lines, modules=$($modulePaths.Count), fragments=$($fragmentPaths.Count), manifests=$($manifestPaths.Count)"
