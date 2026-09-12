[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/process-child-poll-boundaries.c'
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name 'process-child-poll-boundaries' -Harness $harness
$output = $probe.Output
$harnessHash = (Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash
$scriptHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$authorities = [ordered]@{
    'windows-managed' = 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'
    'windows-selfhost' = 'selfhost/llvm/emitter/process_runtime.slg'
    'linux-managed' = 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'
    'linux-selfhost' = 'selfhost/llvm/emitter/process_runtime.slg'
}
$sourceHashes = @{}
foreach ($path in $authorities.Values) {
    $sourceHashes[$path] = (Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash
}
$windowsDeclarations = @'
%sollang.process_poll_result = type { i32, i32 }
declare dllimport i32 @WaitForSingleObject(ptr, i32)
declare dllimport i32 @GetExitCodeProcess(ptr, ptr)
declare dllimport i32 @CloseHandle(ptr)
declare i32 @sollang_probe_wait(ptr, i32)
declare i32 @sollang_probe_read_exit(ptr, ptr)
declare i32 @sollang_probe_close(ptr)
'@
$linuxDeclarations = @'
%sollang.process_poll_result = type { i32, i32 }
declare i32 @waitpid(i32, ptr, i32)
declare ptr @__errno_location()
declare i32 @sollang_probe_waitpid(i32, ptr, i32)
'@
$wrapper = @'
define i64 @WRAPPER(i64 %token) {
entry:
  %result = call %sollang.process_poll_result @FUNCTION(i64 %token)
  %code = extractvalue %sollang.process_poll_result %result, 0
  %state = extractvalue %sollang.process_poll_result %result, 1
  %code64 = zext i32 %code to i64
  %state64 = zext i32 %state to i64
  %shifted = shl i64 %state64, 32
  %packed = or i64 %shifted, %code64
  ret i64 %packed
}
'@
$wrappers = $wrapper.Replace('@WRAPPER(', '@sollang_probe_poll(').Replace('@FUNCTION(', '@sollang_poll_process(') + "`n" +
    $wrapper.Replace('@WRAPPER(', '@sollang_probe_poll_injected(').Replace('@FUNCTION(', '@sollang_poll_process_injected(')
function Convert-ToWslPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^[A-Za-z]:\\') { throw "WSL probe requires an absolute drive path: $full" }
    return '/mnt/' + $full.Substring(0, 1).ToLowerInvariant() + '/' + $full.Substring(3).Replace('\', '/')
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    evidenceScope = 'extracted-production-poll-functions; real child barriers and separately labelled syscall fault injection; not public Child integration'
    harnessSha256 = $harnessHash
    verifierSha256 = $scriptHash
    completed = 0
    total = 40
    actualProcessChecks = 0
    injectedBoundaryChecks = 0
    results = @()
}
$recordPath = Join-Path $output 'result.json'
try {
    foreach ($authority in $authorities.Keys) {
        $relativePath = $authorities[$authority]
        $path = Join-Path $root $relativePath
        $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
        $matches = [regex]::Matches($source, '(?ms)^\s*define internal %sollang\.process_poll_result @sollang_poll_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
        $expected = if ($authority.EndsWith('-selfhost')) { 2 } else { 1 }
        if ($matches.Count -ne $expected) { throw "Expected $expected poll bodies in $relativePath; found $($matches.Count)" }
        $windows = $authority.StartsWith('windows-')
        $osCall = if ($windows) { '@WaitForSingleObject(' } else { '@waitpid(' }
        $selected = @($matches | Where-Object { $_.Value.Contains($osCall) })
        if ($selected.Count -ne 1) { throw "Expected one $authority poll body" }
        $body = $selected[0].Value.Replace(' #0 {', ' {')
        $injected = $body.Replace('@sollang_poll_process(', '@sollang_poll_process_injected(')
        # The fault path changes external symbol bindings only. Both copies retain
        # the production branches/status decoding; the direct copy calls the OS.
        if ($windows) {
            $injected = $injected.Replace('@WaitForSingleObject(', '@sollang_probe_wait(').
                Replace('@GetExitCodeProcess(', '@sollang_probe_read_exit(').
                Replace('@CloseHandle(', '@sollang_probe_close(')
            $declarations = $windowsDeclarations
            $actual = 3
        } else {
            $injected = $injected.Replace('@waitpid(', '@sollang_probe_waitpid(')
            $declarations = $linuxDeclarations
            $actual = 7
        }
        $expectedOutput = "actual=$actual injected=5 outstanding=0"
        $llvm = "$declarations`n$body`n$injected`n$wrappers"
        if ($windows) {
            $result = Invoke-RuntimeLlvmProbe -Probe $probe -Authority $authority -Llvm $llvm -ExpectedOutput $expectedOutput
            $llvmHash = $result.LlvmHash
            $executableHash = $result.ExecutableHash
        } else {
            $llvmPath = Join-Path $output "$authority.ll"
            $executablePath = Join-Path $output $authority
            [IO.File]::WriteAllText($llvmPath, "target triple = `"x86_64-pc-linux-gnu`"`n$llvm`n", [Text.UTF8Encoding]::new($false))
            $build = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d', 'Ubuntu', '--', 'clang',
                '-Wall', '-Wextra', '-Werror', (Convert-ToWslPath $harness), (Convert-ToWslPath $llvmPath), '-o', (Convert-ToWslPath $executablePath)) -Description "$authority boundary build" -TimeoutMilliseconds 20000
            [IO.File]::WriteAllText((Join-Path $output "$authority.build.log"), $build.Stdout + $build.Stderr)
            if ($build.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($build.Stderr)) { throw "$authority build failed: $($build.Stderr)" }
            $run = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d', 'Ubuntu', '--', (Convert-ToWslPath $executablePath)) -Description "$authority boundary execution" -TimeoutMilliseconds 20000
            [IO.File]::WriteAllText((Join-Path $output "$authority.run.log"), $run.Stdout + $run.Stderr)
            if ($run.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($run.Stderr) -or $run.Stdout.Trim() -cne $expectedOutput) {
                throw "$authority execution failed (exit $($run.ExitCode)): $($run.Stdout)$($run.Stderr)"
            }
            $llvmHash = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
            $executableHash = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
        }
        $record.results += [ordered]@{
            authority = $authority
            source = $relativePath
            sourceSha256 = $sourceHashes[$relativePath]
            llvmSha256 = $llvmHash
            executableSha256 = $executableHash
            actualProcessChecks = $actual
            injectedBoundaryChecks = 5
            outstandingOwnedChildren = 0
        }
        $record.completed += $actual + 5
        $record.actualProcessChecks += $actual
        $record.injectedBoundaryChecks += 5
    }
    foreach ($path in $sourceHashes.Keys) {
        if ((Get-FileHash -LiteralPath (Join-Path $root $path) -Algorithm SHA256).Hash -ne $sourceHashes[$path]) { throw "Source changed during probe: $path" }
    }
    if ((Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash -ne $harnessHash -or
        (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash -ne $scriptHash) { throw 'Probe harness or verifier changed during execution' }
    if ($record.completed -ne $record.total) { throw 'Boundary evidence count differs from contract' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    [IO.File]::WriteAllText($recordPath, (($record | ConvertTo-Json -Depth 6) + "`n"))
}
Write-Host "[process poll boundaries] PASS $($record.completed)/$($record.total); actual=$($record.actualProcessChecks) injected=$($record.injectedBoundaryChecks); $recordPath"
