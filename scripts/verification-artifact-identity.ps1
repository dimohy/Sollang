# Resolve the recorded workspace identity independently of file existence.
# The historical P workspace was moved to the current repository; it is not
# a second location to probe and must never require a compatibility alias.
function Resolve-CompilerEvidencePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$LiteralPath
    )
    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $historicalPrefix = 'P:\MyWorks\Sollang\'
    $recorded = $LiteralPath.Replace('/', '\')
    if ($recorded.StartsWith($historicalPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $relative = $recorded.Substring($historicalPrefix.Length)
        if ([string]::IsNullOrWhiteSpace($relative) -or
            @($relative.Split('\') | Where-Object { $_ -in @('.', '..', '') }).Count -ne 0 -or
            [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':')) {
            throw "ARTIFACT_HISTORICAL_PATH_INVALID: $LiteralPath"
        }
        $path = [IO.Path]::GetFullPath($relative, $root)
        if (-not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "ARTIFACT_HISTORICAL_PATH_INVALID: $LiteralPath"
        }
        return $path
    }
    [IO.Path]::GetFullPath($LiteralPath, $root)
}

function Get-CompilerEvidencePinnedHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][psobject]$InputHashes,
        [Parameter(Mandatory)][string]$LiteralPath
    )
    $path = Resolve-CompilerEvidencePath -RepositoryRoot $RepositoryRoot -LiteralPath $LiteralPath
    $pinEntries = @($InputHashes.PSObject.Properties | Where-Object {
        (Resolve-CompilerEvidencePath -RepositoryRoot $RepositoryRoot -LiteralPath $_.Name).Equals(
            $path, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($pinEntries.Count -ne 1 -or $pinEntries[0].Value -cnotmatch '^[A-Fa-f0-9]{64}$') {
        throw "ARTIFACT_PINNED_PATH_IDENTITY_INVALID: $path"
    }
    $pinEntries[0].Value.ToUpperInvariant()
}

# Current files are hashed from bytes. Explicit historical native-build callers
# may instead inspect the identity recorded by a successful, input-stable build.
# A recorded identity does not claim that deleted binary bytes were reread.
function Get-CompilerEvidenceHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$LiteralPath,
        [ValidateSet('SHA256')][string]$Algorithm = 'SHA256',
        [switch]$ArchivedNativeBuild,
        [string]$ArchivedManagedExecutionRecord = ''
    )
    $path = Resolve-CompilerEvidencePath -RepositoryRoot $RepositoryRoot -LiteralPath $LiteralPath
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return [pscustomobject]@{ Hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
            IdentitySource = 'live-bytes'; Evidence = $path }
    }
    if ($ArchivedManagedExecutionRecord) {
        $recordPath = Resolve-CompilerEvidencePath -RepositoryRoot $RepositoryRoot -LiteralPath $ArchivedManagedExecutionRecord
        $artifactRoot = [IO.Path]::GetFullPath('artifacts', $RepositoryRoot) + '\'
        if ([IO.Path]::GetFileName($path) -cne 'Sollang.Compiler.dll' -or
            -not $recordPath.StartsWith($artifactRoot, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($recordPath) -cne 'result.json' -or
            -not (Test-Path -LiteralPath $recordPath -PathType Leaf)) {
            throw "ARTIFACT_RECORDED_MANAGED_EXECUTION_INVALID: $recordPath"
        }
        $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
        foreach ($field in @('schemaVersion', 'gate', 'state', 'inputsStable', 'inputFingerprintStart',
                'inputFingerprintEnd', 'orphanProcessIds', 'managedCompilerPath', 'managedCompilerSha256',
                'managed', 'selfhost', 'failureId')) {
            if (-not $record.PSObject.Properties[$field]) {
                throw "ARTIFACT_RECORDED_MANAGED_EXECUTION_INVALID: $recordPath"
            }
        }
        $recordedCompiler = Resolve-CompilerEvidencePath -RepositoryRoot $RepositoryRoot -LiteralPath $record.managedCompilerPath
        if ($record.schemaVersion -ne 1 -or $record.gate -cne 'compiler-parity-negative-fixture' -or
            $record.state -cne 'passed' -or $record.inputsStable -ne $true -or
            $record.inputFingerprintStart -cnotmatch '^[A-Fa-f0-9]{64}$' -or
            $record.inputFingerprintStart -cne $record.inputFingerprintEnd -or
            @($record.orphanProcessIds).Count -ne 0 -or $record.failureId -or
            $recordedCompiler -cne $path -or $record.managedCompilerSha256 -cnotmatch '^[A-Fa-f0-9]{64}$') {
            throw "ARTIFACT_RECORDED_MANAGED_EXECUTION_INVALID: $recordPath"
        }
        foreach ($side in @($record.managed, $record.selfhost)) {
            if ($null -eq $side) {
                throw "ARTIFACT_RECORDED_MANAGED_EXECUTION_INVALID: $recordPath"
            }
            foreach ($field in @('exitCode', 'nonzeroExit', 'expectedInStderr', 'noEmittedProducts', 'generatedProducts')) {
                if (-not $side.PSObject.Properties[$field]) {
                    throw "ARTIFACT_RECORDED_MANAGED_EXECUTION_INVALID: $recordPath"
                }
            }
            if ($side.exitCode -ne 1 -or $side.nonzeroExit -ne $true -or
                $side.expectedInStderr -ne $true -or $side.noEmittedProducts -ne $true -or
                @($side.generatedProducts).Count -ne 0) {
                throw "ARTIFACT_RECORDED_MANAGED_EXECUTION_INVALID: $recordPath"
            }
        }
        # This is the identity in the preserved paired execution. It does not
        # authenticate deleted DLL bytes or qualify a current compiler run.
        return [pscustomobject]@{ Hash = $record.managedCompilerSha256.ToUpperInvariant()
            IdentitySource = 'recorded-managed-execution'; Evidence = $recordPath }
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
