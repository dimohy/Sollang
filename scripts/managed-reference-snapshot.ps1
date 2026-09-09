Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'input-fingerprint-stability.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')

function Invoke-ManagedReferenceProcess {
    param([Parameter(Mandatory)][string]$FilePath,
          [Parameter(Mandatory)][string[]]$ArgumentList,
          [Parameter(Mandatory)][string]$WorkingDirectory,
          [Parameter(Mandatory)][string]$OutputDirectory,
          [Parameter(Mandatory)][int]$TimeoutMilliseconds)
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$FilePath
    $info.WorkingDirectory=$WorkingDirectory
    $info.UseShellExecute=$false
    $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true
    $info.RedirectStandardError=$true
    foreach($argument in $ArgumentList){$info.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new()
    $process.StartInfo=$info
    $stdout=$null; $stderr=$null; $stdoutTask=$null; $stderrTask=$null; $started=$false
    try {
        # Buffer size 1 disables FileStream buffering: partial logs survive interruption.
        $stdout=[IO.FileStream]::new("$OutputDirectory/stdout.log",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,$true)
        $stderr=[IO.FileStream]::new("$OutputDirectory/stderr.log",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,1,$true)
        $started=$process.Start()
        if(-not $started){throw 'Managed reference process did not start'}
        [ordered]@{processId=$process.Id;filePath=$FilePath;arguments=$ArgumentList} |
            ConvertTo-Json -Depth 4 | Set-Content "$OutputDirectory/process.json"
        $stdoutTask=$process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrTask=$process.StandardError.BaseStream.CopyToAsync($stderr)
        Wait-VerificationProcess -Process $process -Description 'managed reference' -TimeoutMilliseconds $TimeoutMilliseconds
        $process.WaitForExit()
        [void]$stdoutTask.GetAwaiter().GetResult()
        [void]$stderrTask.GetAwaiter().GetResult()
        $stdout.Dispose(); $stdout=$null
        $stderr.Dispose(); $stderr=$null
        [pscustomobject]@{ExitCode=$process.ExitCode}
    } finally {
        if($started -and -not $process.HasExited){$process.Kill($true);$process.WaitForExit()}
        if($null -ne $stdoutTask){[void]$stdoutTask.GetAwaiter().GetResult()}
        if($null -ne $stderrTask){[void]$stderrTask.GetAwaiter().GetResult()}
        if($null -ne $stdout){$stdout.Dispose()}
        if($null -ne $stderr){$stderr.Dispose()}
        $process.Dispose()
    }
}

function Get-ManagedReferenceSnapshot {
    param([Parameter(Mandatory)][string[]]$DirectoryRoots,
          [Parameter(Mandatory)][string[]]$RequiredFiles,
          [Parameter(Mandatory)][string[]]$Command)
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($root in $DirectoryRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Missing input directory: $root" }
        foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName)
            if ($relative -match '(^|[\\/])(bin|obj|\.sollang-cache|\.git)([\\/]|$)') { continue }
            if ($relative -match '(^|[\\/])\.sollang[\\/]test([\\/]|$)') { continue }
            $null = $paths.Add($file.FullName)
        }
    }
    foreach ($file in $RequiredFiles) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing input file: $file" }
        $null = $paths.Add([IO.Path]::GetFullPath($file))
    }
    $files = @($paths | Sort-Object -CaseSensitive | ForEach-Object {
        $before = Get-Item -LiteralPath $_
        $length = $before.Length
        $modified = $before.LastWriteTimeUtc.Ticks
        $hash = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash
        $after = Get-Item -LiteralPath $_
        if ($length -ne $after.Length -or $modified -ne $after.LastWriteTimeUtc.Ticks) {
            throw "Input changed while taking snapshot: $_"
        }
        [ordered]@{path=$_;length=$length;sha256=$hash}
    })
    $identity = [ordered]@{command=@($Command);files=$files}
    $json = ConvertTo-Json -InputObject $identity -Depth 6 -Compress
    $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json)))
    [pscustomobject]@{schemaVersion=1;fingerprint=$fingerprint;command=@($Command);files=$files}
}

function Invoke-ManagedReferenceGuard {
    param([Parameter(Mandatory)][scriptblock]$GetSnapshot,
          [Parameter(Mandatory)][scriptblock]$Run,
          [Parameter(Mandatory)][string]$OutputDirectory)
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count) {
        throw "Verification output directory must be empty: $output"
    }
    $null = New-Item -ItemType Directory -Path $output -Force
    try {
        $before = & $GetSnapshot
        $before | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$output/inputs-before.json"
        $runFailure = $null
        try { $result = & $Run $output } catch { $runFailure = $_ }
        # Always audit the post-run identity, including failed executions.
        $after = & $GetSnapshot
        $after | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$output/inputs-after.json"
        Assert-InputFingerprintStable -ExpectedFingerprint $before.fingerprint -CurrentFingerprint $after.fingerprint -Phase 'managed reference'
        if ($null -ne $runFailure) { throw $runFailure }
        if ($result.ExitCode -ne 0) { throw "Managed reference runner exited $($result.ExitCode)" }
        $stdout=[IO.File]::ReadAllText("$output/stdout.log")
        $stderr=[IO.File]::ReadAllText("$output/stderr.log")
        $lines = @(($stdout -split '\r?\n') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -eq 0 -or $lines[-1] -cnotmatch '^All ([1-9][0-9]*) example tests passed\.$') {
            throw 'Managed reference runner has no terminal success summary'
        }
        $total = [int]$Matches[1]
        if ($stdout -match '(?m)^\[\d+/\d+\] FAIL ' -or -not [string]::IsNullOrWhiteSpace($stderr)) {
            throw 'Managed reference log contains a failure or stderr output'
        }
        $receipt = [ordered]@{schemaVersion=1;state='passed';inputFingerprint=$before.fingerprint;
            exitCode=$result.ExitCode;passed=$total;total=$total;
            stdoutSha256=(Get-FileHash "$output/stdout.log").Hash;
            stderrSha256=(Get-FileHash "$output/stderr.log").Hash}
        $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$output/success.json"
        [pscustomobject]$receipt
    } catch {
        [ordered]@{schemaVersion=1;state='failed';error=$_.Exception.Message} |
            ConvertTo-Json | Set-Content -LiteralPath "$output/failure.json"
        throw
    }
}
