[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleContractPath = Join-Path $repoRoot "scripts/contracts/llvm-emitter-modules.json"
$moduleContract = Get-Content -LiteralPath $moduleContractPath -Raw | ConvertFrom-Json
if ($moduleContract.schemaVersion -ne 1) {
    throw "Unsupported LLVM emitter module contract schema '$($moduleContract.schemaVersion)'."
}
$facadePath = Join-Path $repoRoot ([string]$moduleContract.facade)
$modulePaths = @($moduleContract.modules | ForEach-Object { [string]$_ })
if ($modulePaths.Count -eq 0 -or @($modulePaths | Select-Object -Unique).Count -ne $modulePaths.Count) {
    throw "LLVM emitter module contract must contain a non-empty unique module inventory."
}
$fragmentPaths = @(
    "selfhost/llvm/text/entry_expressions.slg"
    "selfhost/llvm/text/core_prepare.slg"
    "selfhost/llvm/text/foundation.slg"
    "selfhost/llvm/text/text_literals.slg"
    "selfhost/llvm/text/native_handles.slg"
    "selfhost/llvm/text/entrypoints.slg"
    "selfhost/llvm/text/runtime_resolution.slg"
    "selfhost/llvm/text/context_prepare.slg"
    "selfhost/llvm/text/invariants.slg"
    "selfhost/llvm/text/invariant_diagnostics.slg"
    "selfhost/llvm/text/core_calls.slg"
    "selfhost/llvm/text/call_arguments.slg"
    "selfhost/llvm/text/runtime_preamble.slg"
    "selfhost/llvm/text/stream_junctions.slg"
    "selfhost/llvm/text/ownership.slg"
    "selfhost/llvm/text/platform_io.slg"
    "selfhost/llvm/text/containers.slg"
    "selfhost/llvm/text/container_control.slg"
    "selfhost/llvm/text/control.slg"
    "selfhost/llvm/text/control_regions.slg"
    "selfhost/llvm/text/control_region_expressions.slg"
    "selfhost/llvm/text/functions.slg"
    "selfhost/llvm/text/function_expressions.slg"
    "selfhost/llvm/text/function_calls.slg"
    "selfhost/llvm/text/function_returns.slg"
    "selfhost/llvm/text/function_scheduling.slg"
)

function Assert-ManifestEntryExactlyOnce {
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$ManifestName
    )

    $count = @($Lines | Where-Object { $_ -ceq $RelativePath }).Count
    if ($count -ne 1) {
        throw "$ManifestName contains '$RelativePath' $count times; expected exactly once."
    }
}

Assert-ManifestEntryExactlyOnce `
    -Lines @("first.slg", "second.slg") `
    -RelativePath "first.slg" `
    -ManifestName "manifest exact-count positive control"
$duplicateManifestRejected = $false
try {
    Assert-ManifestEntryExactlyOnce `
        -Lines @("duplicate.slg", "duplicate.slg") `
        -RelativePath "duplicate.slg" `
        -ManifestName "manifest duplicate negative control"
} catch {
    if ($_.Exception.Message -notlike "manifest duplicate negative control contains 'duplicate.slg' 2 times*") {
        throw
    }
    $duplicateManifestRejected = $true
}
if (-not $duplicateManifestRejected) {
    throw "manifest duplicate negative control was accepted"
}

$facadeLines = [IO.File]::ReadAllLines($facadePath)

$facadeText = [IO.File]::ReadAllText($facadePath)
$logicalText = $facadeText + "`n" + (($fragmentPaths | ForEach-Object {
    [IO.File]::ReadAllText((Join-Path $repoRoot $_))
}) -join "`n")
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

    if ($logicalText -notmatch [regex]::Escape("sollang.compiler.llvm.emitter.$moduleName")) {
        throw "The sollang.compiler.llvm.text module does not import $relativePath."
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

}
$statefulFragments = $fragmentPaths | Where-Object {
    $_ -match "/(core_calls|runtime_preamble|stream_junctions|ownership|platform_io|containers|control|functions|function_scheduling)\.slg$"
}
foreach ($relativePath in $statefulFragments) {
    $text = [IO.File]::ReadAllText((Join-Path $repoRoot $relativePath))
    if ($text.IndexOf("context: ref emitterContext.EmitContext", [System.StringComparison]::Ordinal) -lt 0 `
        -or $text.IndexOf("state: ref CoreEmitterState", [System.StringComparison]::Ordinal) -lt 0) {
        throw "$relativePath must pass emitter context and frozen state by readonly reference."
    }
    if ($text.IndexOf("context: emitterContext.EmitContext", [System.StringComparison]::Ordinal) -ge 0 `
        -or $text.IndexOf("state: CoreEmitterState", [System.StringComparison]::Ordinal) -ge 0) {
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

    Assert-ManifestEntryExactlyOnce `
        -Lines $lines `
        -RelativePath "selfhost/llvm/text.slg" `
        -ManifestName $manifestPath.Name
    foreach ($relativePath in @($modulePaths) + @($fragmentPaths)) {
        Assert-ManifestEntryExactlyOnce `
            -Lines $lines `
            -RelativePath $relativePath `
            -ManifestName $manifestPath.Name
    }

    if ($lines -contains "selfhost/llvm/text/entrypoints.slg") {
        foreach ($dependency in @(
            "selfhost/source_style.slg"
            "selfhost/syntax/diagnostics.slg"
        )) {
            if ($lines -notcontains $dependency) {
                throw "$($manifestPath.Name) omits entrypoint dependency $dependency."
            }
        }
    }
}

Write-Host "PASS LLVM emitter modules: facade-inventory=$($facadeLines.Count) lines, fixed-line-limits=0, modules=$($modulePaths.Count), fragments=$($fragmentPaths.Count), manifests=$($manifestPaths.Count)"
