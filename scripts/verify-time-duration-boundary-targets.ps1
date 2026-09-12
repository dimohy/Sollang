[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Compiler = "",
    [string]$OutputDirectory = "",
    [string]$WslDistribution = "Ubuntu",
    [switch]$Worker
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root "artifacts\scratch")).TrimEnd([IO.Path]::DirectorySeparatorChar)
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $scratchRoot ("time-duration-targets-" + [guid]::NewGuid().ToString("N"))
}
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $outputRoot.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "time Duration target output must be below artifacts/scratch: $outputRoot"
}
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $root "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
$compilerPath = [IO.Path]::GetFullPath($Compiler)
$scriptPath = [IO.Path]::GetFullPath($PSCommandPath)
$pwshPath = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
$logPath = Join-Path $outputRoot "run.stdout.log"
$errorLogPath = Join-Path $outputRoot "run.stderr.log"
$resultPath = Join-Path $outputRoot "result.json"
$launchPath = Join-Path $outputRoot "launch.json"

if (-not $Worker) {
    if (Test-Path -LiteralPath $outputRoot) {
        if (-not (Test-Path -LiteralPath $outputRoot -PathType Container) -or
            @(Get-ChildItem -LiteralPath $outputRoot -Force).Count -ne 0) {
            throw "time Duration target output must be new or empty: $outputRoot"
        }
    }
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $arguments = @(
        "-NoProfile", "-File", $scriptPath,
        "-RepositoryRoot", $root,
        "-Compiler", $compilerPath,
        "-OutputDirectory", $outputRoot,
        "-WslDistribution", $WslDistribution,
        "-Worker"
    )
    $supervisor = Start-Process -FilePath $pwshPath -ArgumentList $arguments `
        -WorkingDirectory $root -RedirectStandardOutput $logPath `
        -RedirectStandardError $errorLogPath -WindowStyle Hidden -PassThru
    $launch = [ordered]@{
        status = "running"
        executionMode = "detached-supervisor"
        supervisorPid = $supervisor.Id
        compilerPath = $compilerPath
        outputDirectory = $outputRoot
        logPath = $logPath
        errorLogPath = $errorLogPath
        resultPath = $resultPath
        startedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    }
    $temporaryLaunch = "$launchPath.tmp"
    [IO.File]::WriteAllText($temporaryLaunch, ($launch | ConvertTo-Json -Depth 4) + "`n", [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryLaunch -Destination $launchPath -Force
    Write-Host "[time Duration targets] detached supervisor PID $($supervisor.Id); result=$resultPath; log=$logPath"
    return
}

[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$contractPath = Join-Path $root "scripts\contracts\time-duration-boundary.json"
$contractSchemaPath = Join-Path $root "scripts\contracts\time-duration-boundary.schema.json"
$resultSchemaPath = Join-Path $root "scripts\contracts\time-duration-boundary-result.schema.json"
$staticVerifierPath = Join-Path $root "scripts\verify-time-duration-boundary.ps1"
$browserRunnerPath = Join-Path $root "scripts\verify-time-browser-program.mjs"
$verificationProcessPath = Join-Path $root "scripts\verification-process.ps1"
$llvmRoot = Join-Path $root ".tools\llvm-22.1.8"
$clangPath = Join-Path $llvmRoot "bin\clang.exe"
$wasmLdPath = Join-Path $llvmRoot "bin\wasm-ld.exe"
$dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop).Source
$nodePath = (Get-Command node -CommandType Application -ErrorAction Stop).Source
$wslPath = (Get-Command wsl.exe -CommandType Application -ErrorAction Stop).Source

foreach ($path in @(
    $compilerPath, $contractPath, $contractSchemaPath, $resultSchemaPath,
    $staticVerifierPath, $browserRunnerPath, $verificationProcessPath,
    $clangPath, $wasmLdPath, $dotnetPath, $pwshPath, $nodePath, $wslPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "time Duration target verifier input is missing: $path"
    }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256([AllowEmptyString()][string]$Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

function Normalize-Output([AllowEmptyString()][string]$Text) {
    $Text.Replace("`r`n", "`n")
}

function Convert-ToWslPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    "/mnt/$($full.Substring(0, 1).ToLowerInvariant())/$($full.Substring(3).Replace([char]92, [char]47))"
}

function Get-RepoRelative([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return [IO.Path]::GetRelativePath($root, $full).Replace([char]92, [char]47)
    }
    $full.Replace([char]92, [char]47)
}

function Get-LiveObservedProcessIds([hashtable]$Observed) {
    $live = [Collections.Generic.List[int]]::new()
    foreach ($entry in $Observed.GetEnumerator()) {
        $process = Get-Process -Id ([int]$entry.Key) -ErrorAction SilentlyContinue
        if ($null -eq $process) { continue }
        try {
            if ($process.StartTime.ToUniversalTime().Ticks -eq [long]$entry.Value) {
                $live.Add([int]$entry.Key)
            }
        } catch { }
        finally { $process.Dispose() }
    }
    @($live | Sort-Object -Unique)
}

function Observe-Descendants([int]$RootProcessId, [hashtable]$Observed) {
    $records = @(Get-CimInstance Win32_Process)
    $frontier = @($RootProcessId)
    while ($frontier.Count -gt 0) {
        $children = @($records | Where-Object { $frontier -contains [int]$_.ParentProcessId })
        $frontier = @()
        foreach ($child in $children) {
            $childId = [int]$child.ProcessId
            if (-not $Observed.ContainsKey($childId)) {
                $process = Get-Process -Id $childId -ErrorAction SilentlyContinue
                if ($null -ne $process) {
                    try { $Observed[$childId] = $process.StartTime.ToUniversalTime().Ticks } catch { }
                    finally { $process.Dispose() }
                }
            }
            $frontier += $childId
        }
    }
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Description,
        [int]$TimeoutMilliseconds = 60000
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $observed = @{}
    try {
        if (-not $process.Start()) { throw "$Description did not start" }
        $rootPid = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(100)) {
            Observe-Descendants -RootProcessId $rootPid -Observed $observed
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                $process.Kill($true)
                [void]$process.WaitForExit(10000)
                throw "$Description exceeded ${TimeoutMilliseconds}ms"
            }
        }
        Observe-Descendants -RootProcessId $rootPid -Observed $observed
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $orphanDeadline = [DateTimeOffset]::UtcNow.AddSeconds(3)
        do {
            $orphans = @(Get-LiveObservedProcessIds $observed)
            if ($orphans.Count -eq 0) { break }
            Start-Sleep -Milliseconds 100
        } while ([DateTimeOffset]::UtcNow -lt $orphanDeadline)
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
            OrphanProcessIds = @($orphans)
        }
    } finally {
        $process.Dispose()
    }
}

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $contractSchemaPath)) {
    throw "time Duration boundary contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
$inputPaths = [Collections.Generic.List[string]]::new()
foreach ($path in @($contractPath, $contractSchemaPath, $resultSchemaPath, $staticVerifierPath, $scriptPath, $browserRunnerPath, $verificationProcessPath)) {
    $inputPaths.Add([IO.Path]::GetFullPath($path))
}
foreach ($entry in $contract.trackedInputs) { $inputPaths.Add([IO.Path]::GetFullPath((Join-Path $root $entry.path))) }
$inputHashes = [ordered]@{}
foreach ($path in $inputPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "tracked input is missing: $path" }
    $key = Get-RepoRelative $path
    if ($inputHashes.Contains($key)) { throw "tracked input identity is duplicated: $key" }
    $inputHashes[$key] = Get-Sha256 $path
}
foreach ($entry in $contract.trackedInputs) {
    if ($inputHashes[$entry.path] -cne $entry.sha256.ToUpperInvariant()) {
        throw "tracked input hash drifted: $($entry.path)"
    }
}

$toolHashes = [ordered]@{
    dotnet = [ordered]@{ path = [IO.Path]::GetFullPath($dotnetPath); sha256 = Get-Sha256 $dotnetPath }
    pwsh = [ordered]@{ path = [IO.Path]::GetFullPath($pwshPath); sha256 = Get-Sha256 $pwshPath }
    node = [ordered]@{ path = [IO.Path]::GetFullPath($nodePath); sha256 = Get-Sha256 $nodePath }
    wsl = [ordered]@{ path = [IO.Path]::GetFullPath($wslPath); sha256 = Get-Sha256 $wslPath }
    clang = [ordered]@{ path = [IO.Path]::GetFullPath($clangPath); sha256 = Get-Sha256 $clangPath }
    wasmLd = [ordered]@{ path = [IO.Path]::GetFullPath($wasmLdPath); sha256 = Get-Sha256 $wasmLdPath }
    browserRunner = [ordered]@{ path = [IO.Path]::GetFullPath($browserRunnerPath); sha256 = Get-Sha256 $browserRunnerPath }
}
$compiler = [ordered]@{ path = $compilerPath; sha256 = Get-Sha256 $compilerPath }
$checks = [Collections.Generic.List[object]]::new()
$failureIds = [Collections.Generic.List[string]]::new()
$orphanProcessIds = [Collections.Generic.List[int]]::new()
$startedAt = [DateTimeOffset]::UtcNow

function Publish-Result([string]$Status, [Nullable[int]]$ExitCode) {
    $result = [ordered]@{
        schemaVersion = 1
        contract = "time-duration-boundary"
        status = $Status
        startedAtUtc = $startedAt.ToString("O")
        finishedAtUtc = if ($Status -eq "running") { $null } else { [DateTimeOffset]::UtcNow.ToString("O") }
        supervisorPid = $PID
        exitCode = if ($null -eq $ExitCode) { $null } else { [int]$ExitCode }
        completed = $checks.Count
        total = 30
        failureIds = @($failureIds)
        orphanProcessIds = @($orphanProcessIds | Sort-Object -Unique)
        compiler = $compiler
        toolHashes = $toolHashes
        inputHashes = $inputHashes
        checks = @($checks)
        unsupported = @($contract.platformContract.unsupported)
        blockers = @($contract.platformContract.blockers)
    }
    $json = ($result | ConvertTo-Json -Depth 10) + "`n"
    if (-not (Test-Json -Json $json -SchemaFile $resultSchemaPath)) {
        throw "time Duration result does not satisfy its schema in '$Status' state"
    }
    $temporary = "$resultPath.tmp"
    [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $resultPath -Force
}

function Add-Orphans([object]$ProcessResult) {
    foreach ($processId in @($ProcessResult.OrphanProcessIds)) {
        if (-not $orphanProcessIds.Contains([int]$processId)) { $orphanProcessIds.Add([int]$processId) }
    }
    if (@($ProcessResult.OrphanProcessIds).Count -gt 0) {
        throw "observed child processes remained after exact process exit: $(@($ProcessResult.OrphanProcessIds) -join ',')"
    }
}

function Assert-CleanCompilation([object]$Result, [string]$ArtifactPath, [string]$Id) {
    Add-Orphans $Result
    if ($Result.ExitCode -ne 0 -or -not [string]::IsNullOrEmpty($Result.Stderr) -or
        -not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) {
        throw "$Id compilation failed or produced stderr`n$($Result.Stderr)$($Result.Stdout)"
    }
    if ($Result.Stdout -match '(?im)^\s*(warning|note)\b') {
        throw "$Id compilation produced a warning or note`n$($Result.Stdout)"
    }
}

function Add-Check([string]$Id, [string]$Kind, [string]$Target, [string]$Optimization,
    [int]$ExitCode, [string]$Stdout, [string]$Stderr, [AllowNull()][string]$ArtifactPath,
    [AllowNull()][string]$ExactOutput = $null, [AllowNull()][string]$Diagnostic = $null,
    [string[]]$Capabilities = @()) {
    $observedCompilerSha256 = Get-Sha256 $compilerPath
    if ($observedCompilerSha256 -cne $compiler.sha256) {
        $script:currentFailureId = "compiler.input-drift"
        throw "compiler SHA-256 changed during verification: started $($compiler.sha256), now $observedCompilerSha256"
    }
    $artifact = if ($null -eq $ArtifactPath) { $null } else {
        [ordered]@{ path = [IO.Path]::GetFullPath($ArtifactPath); sha256 = Get-Sha256 $ArtifactPath }
    }
    $checks.Add([ordered]@{
        id = $Id
        kind = $Kind
        target = $Target
        optimization = $Optimization
        status = "passed"
        exitCode = $ExitCode
        stdoutSha256 = Get-TextSha256 $Stdout
        stderrSha256 = Get-TextSha256 $Stderr
        artifact = $artifact
        observation = [ordered]@{
            exactOutput = $ExactOutput
            diagnostic = $Diagnostic
            capabilities = @($Capabilities)
        }
    })
    Write-Host "[time Duration targets $($checks.Count)/30] PASS $Id"
    Publish-Result -Status "running" -ExitCode $null
}

Publish-Result -Status "running" -ExitCode $null
$currentFailureId = "preflight"
try {
    if ($contract.compilerHashPolicy -cne "snapshot-start-equals-every-case-and-end") {
        $currentFailureId = "compiler.hash-policy"
        throw "compiler hash policy drifted"
    }
    $plannedWindows = 1
    $plannedLinux = 1
    foreach ($case in $contract.platformContract.positiveCases) {
        if (@($case.targets) -contains "windows-x64") { $plannedWindows += @($contract.platformContract.optimizations).Count }
        if (@($case.targets) -contains "linux-x64") { $plannedLinux += @($contract.platformContract.optimizations).Count }
    }
    $plannedBrowser = @($contract.platformContract.browserUnavailableCases).Count + 1 +
        (@($contract.platformContract.browserExecutionCases).Count * @($contract.platformContract.optimizations).Count)
    if ($plannedWindows -ne 13 -or $plannedLinux -ne 11 -or $plannedBrowser -ne 6 -or
        ($plannedWindows + $plannedLinux + $plannedBrowser) -ne 30) {
        $currentFailureId = "authority.case-matrix"
        throw "time Duration planned matrix drifted: Windows=$plannedWindows Linux=$plannedLinux browser=$plannedBrowser"
    }

    $static = Invoke-CapturedProcess -FilePath $pwshPath -Arguments @(
        "-NoProfile", "-File", $staticVerifierPath,
        "-RepositoryRoot", $root, "-Compiler", $compilerPath, "-Llvm", $llvmRoot
    ) -Description "time Duration static and managed boundary verifier" -TimeoutMilliseconds 60000
    Add-Orphans $static
    if ($static.ExitCode -ne 0 -or -not [string]::IsNullOrEmpty($static.Stderr) -or
        $static.Stdout -cnotmatch '(?m)^\[time Duration boundary\] PASS ') {
        $currentFailureId = "static-boundary"
        throw "time Duration static boundary failed`n$($static.Stderr)$($static.Stdout)"
    }
    if ((Get-Sha256 $compilerPath) -cne $compiler.sha256) {
        $currentFailureId = "compiler.input-drift"
        throw "compiler changed during static boundary verification"
    }

    foreach ($case in $contract.platformContract.positiveCases) {
        foreach ($target in $case.targets) {
            foreach ($optimization in $contract.platformContract.optimizations) {
                $id = "$target.$($case.id).$($optimization.ToLowerInvariant())"
                $currentFailureId = "$id.compile"
                $caseDirectory = Join-Path $outputRoot $id
                [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
                $artifactPath = if ($target -ceq "windows-x64") { Join-Path $caseDirectory "probe.exe" } else { Join-Path $caseDirectory "probe" }
                $compile = Invoke-CapturedProcess -FilePath $dotnetPath -Arguments @(
                    $compilerPath, "build", (Join-Path $root $case.source), "-o", $artifactPath,
                    "--target", $target, "-$optimization", "--llvm", $llvmRoot
                ) -Description "$id compilation"
                Assert-CleanCompilation $compile $artifactPath $id
                $currentFailureId = "$id.execute"
                $execution = if ($target -ceq "windows-x64") {
                    Invoke-CapturedProcess -FilePath $artifactPath -Arguments @() -Description "$id execution"
                } else {
                    Invoke-CapturedProcess -FilePath $wslPath -Arguments @(
                        "-d", $WslDistribution, "--", (Convert-ToWslPath $artifactPath)
                    ) -Description "$id execution"
                }
                Add-Orphans $execution
                $actual = Normalize-Output $execution.Stdout
                $expected = Normalize-Output ([IO.File]::ReadAllText((Join-Path $root $case.expected)))
                if ($execution.ExitCode -ne 0 -or -not [string]::IsNullOrEmpty($execution.Stderr) -or $actual -cne $expected) {
                    throw "$id exact output drifted`nexpected:`n$expected`nactual:`n$actual`nstderr:`n$($execution.Stderr)"
                }
                Add-Check $id "exact-execution" $target $optimization $execution.ExitCode $actual $execution.Stderr $artifactPath -ExactOutput $actual
            }
        }
    }

    foreach ($target in @("windows-x64", "linux-x64", "wasm32-browser")) {
        $case = $contract.platformContract.privateConstructionCase
        $id = "$target.$($case.id).diagnostic"
        $currentFailureId = $id
        $caseDirectory = Join-Path $outputRoot $id
        [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
        $extension = if ($target -ceq "windows-x64") { ".exe" } elseif ($target -ceq "wasm32-browser") { ".wasm" } else { "" }
        $artifactPath = Join-Path $caseDirectory ("forgery" + $extension)
        $diagnostic = Invoke-CapturedProcess -FilePath $dotnetPath -Arguments @(
            $compilerPath, "build", (Join-Path $root $case.source), "-o", $artifactPath,
            "--target", $target, "-O0", "--llvm", $llvmRoot
        ) -Description "$id compilation"
        Add-Orphans $diagnostic
        $stderr = Normalize-Output $diagnostic.Stderr
        $expectedDiagnostic = $case.diagnostic + "`n"
        if ($diagnostic.ExitCode -ne 1 -or -not [string]::IsNullOrEmpty($diagnostic.Stdout) -or
            $stderr -cne $expectedDiagnostic -or (Test-Path -LiteralPath $artifactPath)) {
            throw "$id did not fail exactly before artifact creation`nstdout:`n$($diagnostic.Stdout)`nstderr:`n$stderr"
        }
        Add-Check $id "exact-diagnostic" $target "diagnostic" $diagnostic.ExitCode $diagnostic.Stdout $stderr $null -Diagnostic $stderr.TrimEnd("`n")
    }

    foreach ($case in $contract.platformContract.browserUnavailableCases) {
        $id = "wasm32-browser.$($case.id).unavailable"
        $currentFailureId = $id
        $caseDirectory = Join-Path $outputRoot $id
        [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
        $artifactPath = Join-Path $caseDirectory "probe.wasm"
        $diagnostic = Invoke-CapturedProcess -FilePath $dotnetPath -Arguments @(
            $compilerPath, "build", (Join-Path $root $case.source), "-o", $artifactPath,
            "--target", "wasm32-browser", "-O0", "--llvm", $llvmRoot
        ) -Description "$id compilation"
        Add-Orphans $diagnostic
        $stderr = Normalize-Output $diagnostic.Stderr
        $expectedDiagnostic = "sollang: $($contract.platformContract.browserUnavailableDiagnostic)`n"
        if ($diagnostic.ExitCode -ne 1 -or -not [string]::IsNullOrEmpty($diagnostic.Stdout) -or
            $stderr -cne $expectedDiagnostic -or (Test-Path -LiteralPath $artifactPath)) {
            throw "$id did not preserve the exact child-process capability diagnostic`nstdout:`n$($diagnostic.Stdout)`nstderr:`n$stderr"
        }
        Add-Check $id "unavailable-diagnostic" "wasm32-browser" "diagnostic" $diagnostic.ExitCode $diagnostic.Stdout $stderr $null -Diagnostic $stderr.TrimEnd("`n") -Capabilities @("child-process-unavailable")
    }

    foreach ($case in $contract.platformContract.browserExecutionCases) {
        foreach ($optimization in $contract.platformContract.optimizations) {
            $id = "wasm32-browser.$($case.id).$($optimization.ToLowerInvariant())"
            $currentFailureId = "$id.compile"
            $caseDirectory = Join-Path $outputRoot $id
            [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
            $artifactPath = Join-Path $caseDirectory "probe.wasm"
            $compile = Invoke-CapturedProcess -FilePath $dotnetPath -Arguments @(
                $compilerPath, "build", (Join-Path $root $case.source), "-o", $artifactPath,
                "--target", "wasm32-browser", "-$optimization", "--llvm", $llvmRoot
            ) -Description "$id compilation"
            Assert-CleanCompilation $compile $artifactPath $id
            $currentFailureId = "$id.execute"
            $execution = Invoke-CapturedProcess -FilePath $nodePath -Arguments @(
                $browserRunnerPath, $artifactPath, (Join-Path $root $case.expected)
            ) -Description "$id browser execution"
            Add-Orphans $execution
            if ($execution.ExitCode -ne 0 -or -not [string]::IsNullOrEmpty($execution.Stderr)) {
                throw "$id browser execution failed`n$($execution.Stderr)$($execution.Stdout)"
            }
            try { $browserResult = $execution.Stdout | ConvertFrom-Json } catch { throw "$id browser result was not JSON" }
            if ($browserResult.status -cne "passed" -or $browserResult.exitCode -ne 0 -or
                $browserResult.exactOutput -cne "browser-time-domains=ok" -or
                @($browserResult.imports) -notcontains "env:sollang_browser_now_millis" -or
                @($browserResult.imports) -notcontains "env:sollang_browser_utc_now_millis") {
                throw "$id browser result did not prove both actual clock capabilities"
            }
            Add-Check $id "exact-execution" "wasm32-browser" $optimization 0 ($browserResult.exactOutput + "`n") "" $artifactPath `
                -ExactOutput ($browserResult.exactOutput + "`n") `
                -Capabilities @("monotonic:performance.now", "wall:Date.now")
        }
    }

    if ($checks.Count -ne $contract.platformContract.authoritativeTotal) {
        $currentFailureId = "authority.total"
        throw "time Duration target count drifted: expected 30, actual $($checks.Count)"
    }
    $endingCompilerSha256 = Get-Sha256 $compilerPath
    if ($endingCompilerSha256 -cne $compiler.sha256) {
        $currentFailureId = "compiler.input-drift"
        throw "compiler changed during verification: started $($compiler.sha256), ended $endingCompilerSha256"
    }
    foreach ($toolName in $toolHashes.Keys) {
        $endingToolSha256 = Get-Sha256 $toolHashes[$toolName].path
        if ($endingToolSha256 -cne $toolHashes[$toolName].sha256) {
            $currentFailureId = "tool.input-drift.$($toolName.ToLowerInvariant())"
            throw "verification tool changed during execution: $toolName"
        }
    }
    $endingHashes = [ordered]@{}
    foreach ($path in $inputPaths) { $endingHashes[(Get-RepoRelative $path)] = Get-Sha256 $path }
    foreach ($key in $inputHashes.Keys) {
        if ($endingHashes[$key] -cne $inputHashes[$key]) {
            $currentFailureId = "input-drift.$($key.Replace('/', '.').ToLowerInvariant())"
            throw "time Duration input changed during verification: $key"
        }
    }
    Publish-Result -Status "passed" -ExitCode 0
    Write-Host "[time Duration targets] PASS 30/30; result=$resultPath"
} catch {
    if ((Test-Path -LiteralPath $compilerPath -PathType Leaf) -and
        (Get-Sha256 $compilerPath) -cne $compiler.sha256) {
        $currentFailureId = "compiler.input-drift"
    }
    if (-not $failureIds.Contains($currentFailureId)) { $failureIds.Add($currentFailureId) }
    try { Publish-Result -Status "failed" -ExitCode 1 } catch { Write-Error $_ }
    Write-Error $_
    exit 1
}
