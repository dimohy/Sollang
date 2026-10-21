[CmdletBinding()]
param(
    [ValidateSet('preserved', 'baseline-failure')][string]$Expectation = 'preserved',
    [ValidateSet('send-flags', 'readiness', 'multipending', 'publication')][string]$ProbeSet = 'send-flags',
    [ValidateSet('managed', 'selfhost', 'emitted')][string]$Authority = 'managed',
    [string]$EmittedLlvmPath = '',
    [string]$ProducerProof = '',
    [string]$ExpectedCompilerSha256 = '',
    [string]$RuntimeSourceSnapshot = '',
    [string]$ExpectedRuntimeSourceSha256 = '',
    [string]$Distribution = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'verification-compiler-build.ps1')
$root = Split-Path -Parent $PSScriptRoot
if ($ProbeSet -ne 'send-flags' -and $Expectation -ne 'preserved') { throw 'Readiness and multiple-operation cases require preserved completion semantics' }
$emittedRuntime = $null
if ($Authority -eq 'emitted') {
    if ($RuntimeSourceSnapshot -or $ExpectedRuntimeSourceSha256) { throw 'LINUX_RUNTIME_SOURCE_AUTHORITIES_CONFLICT' }
    $emittedRuntime = Resolve-VerificationEmittedRuntime -LlvmPath $EmittedLlvmPath -ProducerProof $ProducerProof -ExpectedCompilerSha256 $ExpectedCompilerSha256 -Target 'linux-x64' -RepositoryRoot $root
} elseif ($EmittedLlvmPath -or $ProducerProof -or $ExpectedCompilerSha256) { throw 'LINUX_EMITTED_AUTHORITY_REQUIRED' }
$sourcePath = if ($emittedRuntime) { $emittedRuntime.Path } elseif ($Authority -eq 'managed') {
    Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'
} else { Join-Path $root 'selfhost/llvm/emitter/socket_runtime.slg' }
$sourceVersion = if ($emittedRuntime) { 'native-emitted' } else { 'current' }
if (-not [string]::IsNullOrWhiteSpace($RuntimeSourceSnapshot)) {
    $snapshot = (Resolve-Path -LiteralPath $RuntimeSourceSnapshot).Path
    $rootPrefix = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
    $extension = if ($Authority -eq 'managed') { '.cs' } else { '.slg' }
    $snapshotInRoot = $snapshot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
    $snapshotExtensionMatches = [IO.Path]::GetExtension($snapshot) -ceq $extension
    $snapshotHashWellFormed = $ExpectedRuntimeSourceSha256 -match '^[A-Fa-f0-9]{64}$'
    if (-not $snapshotInRoot -or -not $snapshotExtensionMatches -or -not $snapshotHashWellFormed) {
        throw 'Runtime source snapshot path or anchored SHA256 is invalid'
    }
    if ((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -cne $ExpectedRuntimeSourceSha256.ToUpperInvariant()) { throw 'Runtime source snapshot SHA256 differs from the original baseline' }
    $sourcePath = $snapshot
    $sourceVersion = 'snapshot'
} elseif (-not [string]::IsNullOrWhiteSpace($ExpectedRuntimeSourceSha256)) {
    throw 'An expected snapshot hash requires an explicit runtime source snapshot'
}
$commonHarness = Join-Path $PSScriptRoot 'contracts/fixtures/linux-completion-sigpipe.c'
$harness = if ($ProbeSet -eq 'multipending') {
    Join-Path $PSScriptRoot 'contracts/fixtures/linux-completion-multipending.c'
} elseif ($ProbeSet -eq 'publication') {
    Join-Path $PSScriptRoot 'contracts/fixtures/linux-completion-publication.c'
} else { $commonHarness }
$output = Join-Path $root ('artifacts/scratch/linux-completion-sigpipe-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$inputs = @($sourcePath, $harness, $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1'))
if ($ProbeSet -eq 'multipending') { $inputs += $commonHarness }
if ($emittedRuntime) { $inputs += $emittedRuntime.InputPaths }
$inputs += @((Join-Path $PSScriptRoot 'verification-compiler-build.ps1'), (Join-Path $PSScriptRoot 'contracts/verification-compiler-build.json'))
$hashes = [ordered]@{}
foreach ($path in $inputs) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function WslPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -notmatch '^[A-Za-z]:\\') { throw 'Probe requires an absolute Windows drive path' }
    return '/mnt/' + $full.Substring(0,1).ToLowerInvariant() + '/' + $full.Substring(3).Replace('\','/')
}
function Run([string]$Step, [string[]]$Arguments) {
    $r = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList (@('-d',$Distribution,'--') + $Arguments) -WorkingDirectory $root -Description "Linux completion SIGPIPE $Step" -TimeoutMilliseconds 20000 -ExecutionRecordPath (Join-Path $output "$Step.execution.json")
    [IO.File]::WriteAllText((Join-Path $output "$Step.stdout.txt"), $r.Stdout)
    [IO.File]::WriteAllText((Join-Path $output "$Step.stderr.txt"), $r.Stderr)
    return $r
}
$record = [ordered]@{
    schemaVersion=1; status='running'; expectation=$Expectation; probeSet=$ProbeSet; authority=$Authority; runtimeSourceVersion=$sourceVersion; completed=0; total=$(switch ($ProbeSet) {'readiness' {4} 'multipending' {7} 'publication' {4} default {3}})
    evidenceScope='Extracted production Linux LLVM; real closed AF_UNIX stream send; synthetic waiter readiness; default SIGPIPE in isolated child processes; not public TCP API or full compiler acceptance'
    inputHashes=$hashes; inputsStable=$false; processesStopped=$false
}
try {
    $source = [IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n")
    if ($Authority -eq 'selfhost') {
        $regions = @()
        foreach ($name in @('emitLinuxRuntime','emitLinuxCompletionRuntime')) {
            $region = [regex]::Matches($source, "(?ms)^public ${name}:.*?(?=^public |\z)")
            if ($region.Count -ne 1) { throw "Expected exactly one Linux emitter region: $name" }
            $regions += $region[0].Value
        }
        $source = $regions -join "`n"
    }
    # Extract the transitive production helper closure, preserving the six roots.
    # Old anchored source snapshots and the current split implementation share this path.
    $functions = @{}
    foreach ($match in [regex]::Matches($source, '(?ms)^\s*define internal [^\n]+ @([A-Za-z0-9_]+)\([^\n]*\) #0 \{.*?^\s*\}')) {
        $name = $match.Groups[1].Value
        if ($functions.ContainsKey($name)) { throw "Duplicate production function: $name" }
        $functions[$name] = $match.Value
    }
    $queue = [Collections.Generic.Queue[string]]::new()
    $roots = @('sollang_socket_result','sollang_socket_errno','sollang_socket_error_kind','sollang_platform_socket_send','sollang_platform_socket_completion_submit','sollang_socket_completion_waiter')
    if ($ProbeSet -eq 'publication') { $roots += @('sollang_platform_socket_completion_create','sollang_platform_socket_completion_cancel','sollang_platform_socket_completion_dequeue') }
    foreach ($name in $roots) {
        if (-not $functions.ContainsKey($name)) { throw "Missing production function: $name" }
        $queue.Enqueue($name)
    }
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $bodies = @()
    while ($queue.Count -gt 0) {
        $name = $queue.Dequeue()
        if (-not $visited.Add($name)) { continue }
        $body = $functions[$name]
        $bodies += $body.Replace(' #0 {',' {')
        foreach ($reference in [regex]::Matches($body, '@([A-Za-z0-9_]+)')) {
            $callee = $reference.Groups[1].Value
            if ($functions.ContainsKey($callee) -and -not $visited.Contains($callee)) { $queue.Enqueue($callee) }
        }
    }
    $record.extractedProductionFunctions = @($visited | Sort-Object)
    $version = Run 'clang-version' @('/usr/bin/clang','--version')
    if ($version.ExitCode -ne 0 -or $version.Stdout -notmatch 'clang version 18\.1\.3') { throw 'Pinned Ubuntu clang18.1.3 unavailable' }
    $record.clangVersion = $version.Stdout.Trim()
    $toolHash = Run 'clang-hash' @('/usr/bin/sha256sum','/usr/lib/llvm-18/bin/clang')
    if ($toolHash.ExitCode -ne 0 -or $toolHash.Stdout -notmatch '^([a-f0-9]{64})\s') { throw 'Linux clang hash probe failed' }
    $record.clangSha256 = $Matches[1].ToUpperInvariant()
    $llvm = @'
target triple = "x86_64-pc-linux-gnu"
%sollang.socket_result = type { i64, i32, i32 }
declare ptr @__errno_location()
declare i64 @send(i32, ptr, i64, i32)
declare i64 @recv(i32, ptr, i64, i32)
declare i64 @read(i32, ptr, i64)
declare i32 @fcntl(i32, i32, ...)
declare i32 @epoll_ctl(i32, i32, i32, ptr)
declare i32 @socket_probe_epoll_wait(i32, ptr, i32, i32)
declare i32 @pthread_create(ptr, ptr, ptr, ptr)
declare i32 @pthread_mutex_init(ptr, ptr)
declare i32 @pthread_mutex_destroy(ptr)
declare i32 @pthread_mutex_lock(ptr)
declare i32 @pthread_mutex_unlock(ptr)
declare i1 @sollang_platform_io_ensure_signal()
declare void @sollang_io_push_completion(ptr)
declare void @sollang_platform_io_signal_completion()
declare void @llvm.trap()
'@
    $llvm += "`n" + (($bodies -join "`n").Replace('@epoll_wait(', '@socket_probe_epoll_wait('))
    if ($ProbeSet -eq 'publication') {
        $record.evidenceScope = 'Extracted production LLVM with test-local external binding hooks for epoll scheduling, rearm failure, allocator tracking and mutex-init failure; real kernel recv/send and pthread synchronization; not full native compiler acceptance'
        # Production state transitions and syscall arguments remain unmodified.
        $llvm = $llvm.Replace('@epoll_ctl(', '@socket_probe_epoll_ctl(').Replace('@pthread_mutex_init(', '@socket_probe_mutex_init(')
        $llvm = $llvm.Replace('@sollang_alloc(', '@socket_probe_alloc(').Replace('@malloc(', '@socket_probe_alloc(')
        $llvm = $llvm.Replace('@sollang_free(', '@socket_probe_free(').Replace('@free(', '@socket_probe_free(')
        $llvm += @'

declare i64 @write(i32, ptr, i64)
declare i32 @close(i32)
declare i32 @eventfd(i32, i32)
declare i32 @epoll_create1(i32)
declare ptr @socket_probe_alloc(i64)
declare void @socket_probe_free(ptr)
declare void @llvm.memset.p0.i64(ptr, i8, i64, i1)

define i32 @socket_probe_receive(ptr %state, ptr %buffer, ptr %code) {
  %identity = ptrtoint ptr %state to i64
  %r = call %sollang.socket_result @sollang_platform_socket_completion_submit(i64 %identity, i64 17, i64 31, i32 0, ptr %buffer, i64 1, i64 1, i64 0, i64 1, i32 0)
  %kind = extractvalue %sollang.socket_result %r, 1
  %error = extractvalue %sollang.socket_result %r, 2
  store i32 %error, ptr %code
  ret i32 %kind
}
define i32 @socket_probe_cancel(ptr %state) {
  %identity = ptrtoint ptr %state to i64
  %r = call %sollang.socket_result @sollang_platform_socket_completion_cancel(i64 %identity, i64 31)
  %kind = extractvalue %sollang.socket_result %r, 1
  ret i32 %kind
}
define i32 @socket_probe_dequeue(ptr %state, ptr %descriptor) {
  %identity = ptrtoint ptr %state to i64
  %r = call %sollang.socket_result @sollang_platform_socket_completion_dequeue(i64 %identity, i1 false, ptr %descriptor)
  %kind = extractvalue %sollang.socket_result %r, 1
  ret i32 %kind
}
define i32 @socket_probe_create(ptr %identity, ptr %code) {
  %r = call %sollang.socket_result @sollang_platform_socket_completion_create(i64 1, i64 1, i64 1)
  %value = extractvalue %sollang.socket_result %r, 0
  %kind = extractvalue %sollang.socket_result %r, 1
  %error = extractvalue %sollang.socket_result %r, 2
  store i64 %value, ptr %identity
  store i32 %error, ptr %code
  ret i32 %kind
}
'@
    }
    # The real waiter is a test entry point; only its linkage is exported.
    $llvm = $llvm.Replace('define internal ptr @sollang_socket_completion_waiter(', 'define ptr @sollang_socket_completion_waiter(')
    $llvm += @'

define i32 @socket_probe_send(i64 %fd, ptr %code) {
  %buffer = alloca i8
  %r = call %sollang.socket_result @sollang_platform_socket_send(i64 %fd, ptr %buffer, i64 1)
  %kind = extractvalue %sollang.socket_result %r, 1
  %error = extractvalue %sollang.socket_result %r, 2
  store i32 %error, ptr %code
  ret i32 %kind
}
define i32 @socket_probe_submit(ptr %state, ptr %code) {
  %identity = ptrtoint ptr %state to i64
  %buffer = alloca i8
  %r = call %sollang.socket_result @sollang_platform_socket_completion_submit(i64 %identity, i64 17, i64 31, i32 1, ptr %buffer, i64 1, i64 1, i64 0, i64 1, i32 0)
  %kind = extractvalue %sollang.socket_result %r, 1
  %error = extractvalue %sollang.socket_result %r, 2
  store i32 %error, ptr %code
  ret i32 %kind
}
'@
    $ll = Join-Path $output 'managed.ll'
    [IO.File]::WriteAllText($ll, $llvm, [Text.UTF8Encoding]::new($false))
    $record.llvmSha256 = (Get-FileHash -LiteralPath $ll -Algorithm SHA256).Hash
    $exe = Join-Path $output 'managed'
    $build = Run 'build' @('/usr/bin/clang','-Wall','-Wextra','-Werror','-O0',(WslPath $harness),(WslPath $ll),'-pthread','-o',(WslPath $exe))
    if ($build.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($build.Stderr)) { throw "Native probe build failed: $($build.Stderr)" }
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    $run = Run 'run' @((WslPath $exe),$Expectation,$ProbeSet)
    $record.nativeExit = $run.ExitCode
    $cases = @()
    foreach ($line in ($run.Stdout -split '\r?\n' | Where-Object { $_ })) {
        if ($line -notmatch '^([a-z-]+): exit=(-?\d+) signal=(\d+)$') { throw "Unexpected native case output: $line" }
        $name = $Matches[1]; $childExit = [int]$Matches[2]; $childSignal = [int]$Matches[3]
        $expectSignal = $Expectation -eq 'baseline-failure' -and $name -ne 'ordinary'
        $passed = if ($expectSignal) { $childExit -eq -1 -and $childSignal -eq 13 } else { $childExit -eq 0 -and $childSignal -eq 0 }
        $cases += [ordered]@{id=$name; exit=$childExit; signal=$childSignal; passed=$passed}
    }
    $record.cases = $cases
    $record.completed = @($cases | Where-Object passed).Count
    if ($run.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($run.Stderr)) { throw "Native assertions failed (exit $($run.ExitCode)): $($run.Stdout)$($run.Stderr)" }
    if ($cases.Count -ne $record.total -or $record.completed -ne $record.total) { throw 'Native case count differs from the fixed probe set' }
    $record.status = 'passed'
} catch { $record.status='failed'; $record.failure=$_.Exception.Message }
finally {
    $record.inputsStable = $true
    foreach ($path in $inputs) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { $record.inputsStable=$false; $record.status='failed' }
    }
    $record.processesStopped = $true
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), ($record | ConvertTo-Json -Depth 6))
}
Write-Host "$($record.status): $output"
if ($record.status -ne 'passed') { throw $record.failure }
