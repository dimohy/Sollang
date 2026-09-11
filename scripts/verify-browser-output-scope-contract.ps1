$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "browser-output-scope.ps1")

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("sollang-browser-output-scope-" + [guid]::NewGuid().ToString("N"))))
$artifactRoot = Join-Path $temporaryRoot "artifacts"
try {
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

    $rootResult = Assert-BrowserCompilerOutputRoot `
        -CandidatePath $artifactRoot `
        -ArtifactRoot $artifactRoot
    if ($rootResult -cne [System.IO.Path]::GetFullPath($artifactRoot)) {
        throw "browser output scope did not preserve the artifact root"
    }

    $child = Join-Path $artifactRoot "scratch\browser-focused"
    $childResult = Assert-BrowserCompilerOutputRoot `
        -CandidatePath $child `
        -ArtifactRoot $artifactRoot
    if ($childResult -cne [System.IO.Path]::GetFullPath($child)) {
        throw "browser output scope did not preserve an artifact descendant"
    }

    $normalizedChild = Join-Path $artifactRoot "scratch\..\browser-focused"
    $normalizedResult = Assert-BrowserCompilerOutputRoot `
        -CandidatePath $normalizedChild `
        -ArtifactRoot $artifactRoot
    if ($normalizedResult -cne [System.IO.Path]::GetFullPath((Join-Path $artifactRoot "browser-focused"))) {
        throw "browser output scope did not normalize an in-root descendant"
    }

    foreach ($outside in @(
        (Join-Path $temporaryRoot "outside"),
        ($artifactRoot + "-prefix-collision"),
        (Join-Path $artifactRoot "..\outside")
    )) {
        $rejected = $false
        try {
            Assert-BrowserCompilerOutputRoot `
                -CandidatePath $outside `
                -ArtifactRoot $artifactRoot | Out-Null
        } catch {
            $rejected = $_.Exception.Message -ceq `
                "browser compiler output must remain under $([System.IO.Path]::GetFullPath($artifactRoot))"
        }
        if (-not $rejected) {
            throw "browser output scope accepted an out-of-root path: $outside"
        }
    }

    Write-Host "[browser output scope contract] PASS root and normalized descendants accepted; sibling, prefix collision, and traversal escape rejected."
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
