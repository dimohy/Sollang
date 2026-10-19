# Current files are hashed from bytes. Explicit historical native-build callers
# may instead inspect the identity recorded by a successful, input-stable build.
# A recorded identity does not claim that deleted binary bytes were reread.
function Get-CompilerEvidenceHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$LiteralPath,
        [ValidateSet('SHA256')][string]$Algorithm = 'SHA256',
        [switch]$ArchivedNativeBuild
    )
    $path = [IO.Path]::GetFullPath($LiteralPath, $RepositoryRoot)
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return [pscustomobject]@{ Hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            IdentitySource = 'live-bytes'; Evidence = $path }
    }
    if (-not $ArchivedNativeBuild -or
        [IO.Path]::GetFileName($path) -cne 'compiler.exe') {
        throw "ARTIFACT_LIVE_IDENTITY_REQUIRED: $path"
    }
    # Use the lifecycle's single path authority for both workspace artifacts
    # and its explicitly configured LOCALAPPDATA/Sollang output root.
    $pathValidation = & python -X utf8 -c 'import sys; from pathlib import Path; sys.path.insert(0, sys.argv[1]); from completed_artifact_plan import assert_artifact_path; assert_artifact_path(Path(sys.argv[2]), Path(sys.argv[3]))' `
        $PSScriptRoot $RepositoryRoot $path
    if ($LASTEXITCODE -ne 0) { throw "ARTIFACT_LIVE_IDENTITY_REQUIRED: $path" }
    $recordPath = Join-Path ([IO.Path]::GetDirectoryName($path)) 'result.json'
    if (-not (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
        throw "ARTIFACT_RECORDED_BUILD_MISSING: $recordPath"
    }
    $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    if ($record.schemaVersion -ne 1 -or $record.status -cne 'passed' -or $record.inputsStable -ne $true -or
        $record.compilerSha256 -cnotmatch '^[A-Fa-f0-9]{64}$' -or
        $record.inputFingerprint -cnotmatch '^[A-Fa-f0-9]{64}$' -or
        $record.inputFingerprint -cne $record.finalInputFingerprint -or
        -not ($record.compilerSourceCount -is [int] -or $record.compilerSourceCount -is [long]) -or
        -not ($record.stdlibSourceCount -is [int] -or $record.stdlibSourceCount -is [long]) -or
        $record.compilerSourceCount -le 0 -or $record.stdlibSourceCount -le 0) {
        throw "ARTIFACT_RECORDED_BUILD_UNVERIFIED: $recordPath"
    }
    [pscustomobject]@{ Hash = $record.compilerSha256.ToUpperInvariant()
        IdentitySource = 'recorded-native-build'; Evidence = $recordPath }
}
