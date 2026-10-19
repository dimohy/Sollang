function Get-FocusedSelfhostInputHashes {
    param([Parameter(Mandatory)][string[]]$Paths, [switch]$AllowMissing)
    $hashes = [ordered]@{}
    foreach ($path in $Paths) {
        $absolute = [IO.Path]::GetFullPath($path)
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            if (-not $AllowMissing) { throw "FOCUSED_SELFHOST_INPUT_MISSING: $absolute" }
            $hashes[$absolute] = 'MISSING'
        } else {
            $hashes[$absolute] = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash
        }
    }
    return $hashes
}

function Get-FocusedSelfhostReusableSemanticPreflight {
    param([Parameter(Mandatory)][string]$RecordPath,
          [Parameter(Mandatory)][string]$Manifest,
          [Parameter(Mandatory)][string[]]$Sources,
          [Parameter(Mandatory)][string[]]$StdlibSources,
          [Parameter(Mandatory)][string]$ManagedDll)
    $path = (Resolve-Path -LiteralPath $RecordPath).Path
    $proof = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    if ($proof.status -cne 'passed' -or $proof.inputsStable -ne $true -or
        $proof.processesStopped -ne $true -or $proof.scope -cne 'focused-selfhost' -or
        $proof.completed -ne 4 -or $proof.total -ne 4 -or
        -not $proof.ContainsKey('codegenInvoked') -or $proof.codegenInvoked -ne $false -or
        $proof.codegenPathGuard -cne 'passed' -or
        $proof.productionApiPath -cne 'CompilerApp.LoadProgram -> SemanticCompiler.Compile(null)' -or
        @($proof.failureIds).Count -ne 0 -or $proof.formatPreflight.status -cne 'passed' -or
        $proof.formatPreflight.exit -ne 0 -or $proof.formatPreflight.sourceCount -ne $Sources.Count -or
        @($proof.cases).Count -ne 4 -or -not $proof.inputHashes -or
        $proof.managedDllSha256 -ine (Get-FileHash -LiteralPath $ManagedDll -Algorithm SHA256).Hash) {
        throw "FOCUSED_SELFHOST_SEMANTIC_REUSE_INVALID: $path"
    }
    $expected = [ordered]@{ positive = 0; 'deferred-text' = 1; 'rebound-owner' = 1; 'focused-selfhost' = 0 }
    foreach ($entry in $expected.GetEnumerator()) {
        $rows = @($proof.cases | Where-Object { $_.id -ceq $entry.Key })
        if ($rows.Count -ne 1 -or $rows[0].passed -ne $true -or $rows[0].exit -ne $entry.Value -or
            ($entry.Key -ceq 'focused-selfhost' -and $rows[0].sourceCount -ne $Sources.Count)) {
            throw "FOCUSED_SELFHOST_SEMANTIC_REUSE_CASE_INVALID: $($entry.Key)"
        }
    }
    foreach ($inputPath in (@($Manifest, $ManagedDll) + @($Sources) + @($StdlibSources))) {
        $absolute = [IO.Path]::GetFullPath($inputPath)
        if (-not $proof.inputHashes.ContainsKey($absolute)) {
            throw "FOCUSED_SELFHOST_SEMANTIC_REUSE_INPUT_MISSING: $absolute"
        }
    }
    foreach ($entry in $proof.inputHashes.GetEnumerator()) {
        if ($entry.Value -notmatch '^[0-9a-fA-F]{64}$' -or
            -not (Test-Path -LiteralPath $entry.Key -PathType Leaf) -or
            (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash -ine $entry.Value) {
            throw "FOCUSED_SELFHOST_SEMANTIC_REUSE_INPUT_DRIFT: $($entry.Key)"
        }
    }
    return $path
}

function Get-FocusedSelfhostInputFingerprint {
    param([Parameter(Mandatory)]$Hashes,
          [Parameter(Mandatory)][string]$Optimization,
          [Parameter(Mandatory)][int]$Jobs,
          [Parameter(Mandatory)][bool]$ManagedSeed)
    $lines = foreach ($entry in $Hashes.GetEnumerator()) {
        "$($entry.Key.Replace('\', '/')) $($entry.Value)"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes("optimization=$Optimization jobs=$Jobs managed=$ManagedSeed`n" + ($lines -join "`n") + "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-FocusedSelfhostProtectedCompilerDirectories {
    param([Parameter(Mandatory)][string[]]$Directories,
          [Parameter(Mandatory)][string[]]$InputPaths,
          [Parameter(Mandatory)][string]$ExternalOutputRoot,
          [Parameter(Mandatory)][int]$MaximumReusableCompilers)
    $externalRoot = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($ExternalOutputRoot)) + [IO.Path]::DirectorySeparatorChar
    $required = @($Directories)
    foreach ($path in $InputPaths) {
        $absolute = [IO.Path]::GetFullPath($path)
        if ([IO.Path]::GetFileName($absolute) -ieq 'compiler.exe' -and
            $absolute.StartsWith($externalRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $required += [IO.Path]::GetDirectoryName($absolute)
        }
    }
    $required = @($required | ForEach-Object {
        [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($_))
    } | Sort-Object -Unique)
    if ($required.Count -gt $MaximumReusableCompilers) {
        throw "FOCUSED_SELFHOST_REUSABLE_COMPILER_LIMIT: $($required.Count) required, $MaximumReusableCompilers allowed"
    }
    return $required
}
