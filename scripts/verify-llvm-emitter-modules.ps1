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
)

$facadeLines = [IO.File]::ReadAllLines($facadePath)
if ($facadeLines.Count -gt 17000) {
    throw "selfhost/llvm/text.slg grew to $($facadeLines.Count) lines; extract a cohesive emitter module before adding more."
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

$manifestPaths = Get-ChildItem (Join-Path $repoRoot "examples/expected") -Filter "*.sources.txt"
foreach ($manifestPath in $manifestPaths) {
    $lines = [IO.File]::ReadAllLines($manifestPath.FullName)
    if ($lines -notcontains "selfhost/llvm/text.slg") {
        continue
    }

    foreach ($relativePath in $modulePaths) {
        if ($lines -notcontains $relativePath) {
            throw "$($manifestPath.Name) omits imported emitter module $relativePath."
        }
    }
}

Write-Host "PASS LLVM emitter modules: facade=$($facadeLines.Count) lines, modules=$($modulePaths.Count), manifests=$($manifestPaths.Count)"
