[CmdletBinding()]
param(
    [ValidateSet('preserved', 'baseline-failure')][string]$Expectation = 'preserved',
    [string]$Distribution = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/linux-completion-sigpipe.c'
$output = Join-Path $root ('artifacts/scratch/linux-completion-sigpipe-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$inputs = @($sourcePath, $harness, $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1'))
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
    schemaVersion=1; status='running'; expectation=$Expectation; completed=0; total=3
    evidenceScope='Extracted CSharp production Linux LLVM; real closed AF_UNIX stream send; synthetic waiter readiness; default SIGPIPE in isolated child processes; not public TCP API or full compiler acceptance'
    inputHashes=$hashes; inputsStable=$false; processesStopped=$false
}
try {
    $source = [IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n")
    $bodies = @()
    foreach ($name in @('sollang_socket_result','sollang_socket_errno','sollang_socket_error_kind','sollang_platform_socket_send','sollang_platform_socket_completion_submit','sollang_socket_completion_waiter')) {
        $matches = [regex]::Matches($source, "(?ms)^\s*define internal [^`n]+ @$name\([^`n]*\) #0 \{.*?^\s*\}")
        if ($matches.Count -ne 1) { throw "Expected exactly one production function: $name" }
        $bodies += $matches[0].Value.Replace(' #0 {',' {')
    }
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
declare i1 @sollang_platform_io_ensure_signal()
declare void @sollang_io_push_completion(ptr)
declare void @sollang_platform_io_signal_completion()
declare void @llvm.trap()
'@
    $llvm += "`n" + (($bodies -join "`n").Replace('@epoll_wait(', '@socket_probe_epoll_wait('))
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
    $run = Run 'run' @((WslPath $exe),$Expectation)
    $record.nativeExit = $run.ExitCode
    if ($run.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($run.Stderr)) { throw "Native assertions failed (exit $($run.ExitCode)): $($run.Stdout)$($run.Stderr)" }
    $record.completed = 3
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
