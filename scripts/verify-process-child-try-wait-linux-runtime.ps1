[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $root ('artifacts/scratch/1717-process-child-try-wait-linux-runtime-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/1717-process-child-try-wait-linux-runtime.c'
$authorities = [ordered]@{
    managed = 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'
    selfhost = 'selfhost/llvm/emitter/process_runtime.slg'
}
$declarations = @'
%sollang.process_poll_result = type { i32, i32 }
%sollang.process_result = type { i32, i32 }
declare i32 @waitpid(i32, ptr, i32)
declare i32 @kill(i32, i32)
declare ptr @__errno_location()
'@
$wrapper = @'
define i64 @sollang_probe_poll(i64 %token) {
entry:
  %result = call %sollang.process_poll_result @sollang_poll_process(i64 %token)
  %code = extractvalue %sollang.process_poll_result %result, 0
  %state = extractvalue %sollang.process_poll_result %result, 1
  %code64 = zext i32 %code to i64
  %state64 = zext i32 %state to i64
  %shifted = shl i64 %state64, 32
  %packed = or i64 %shifted, %code64
  ret i64 %packed
}

define i64 @sollang_probe_wait(i64 %token) {
entry:
  %result = call %sollang.process_result @sollang_wait_process(i64 %token)
  %code = extractvalue %sollang.process_result %result, 0
  %error = extractvalue %sollang.process_result %result, 1
  %code64 = zext i32 %code to i64
  %error64 = zext i32 %error to i64
  %shifted = shl i64 %error64, 32
  %packed = or i64 %shifted, %code64
  ret i64 %packed
}
'@

function Convert-ToWslPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $drive = $full.Substring(0, 1).ToLowerInvariant()
    $tail = $full.Substring(3).Replace('\', '/')
    return "/mnt/$drive/$tail"
}

$harnessWsl = Convert-ToWslPath $harness
$results = @()
foreach ($authority in $authorities.Keys) {
    $relativePath = $authorities[$authority]
    $path = Join-Path $root $relativePath
    $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $matches = [regex]::Matches($source, '(?ms)^\s*define internal %sollang\.process_poll_result @sollang_poll_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    $expected = if ($authority -eq 'selfhost') { 2 } else { 1 }
    if ($matches.Count -ne $expected) { throw "Expected $expected poll functions in $relativePath, found $($matches.Count)" }
    $linux = @($matches | Where-Object { $_.Value.Contains('@waitpid(') })
    if ($linux.Count -ne 1) { throw "Expected one Linux poll function in $relativePath" }
    $waitMatches = [regex]::Matches($source, '(?ms)^\s*define internal %sollang\.process_result @sollang_wait_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    $linuxWait = @($waitMatches | Where-Object { $_.Value.Contains('@waitpid(') })
    if ($linuxWait.Count -ne 1) { throw "Expected one Linux wait function in $relativePath" }
    $llvmPath = Join-Path $output "$authority.ll"
    $executablePath = Join-Path $output $authority
    $body = $linux[0].Value.Replace(' #0 {', ' {') + "`n" + $linuxWait[0].Value.Replace(' #0 {', ' {')
    [IO.File]::WriteAllText($llvmPath, "target triple = `"x86_64-pc-linux-gnu`"`n$declarations`n$body`n$wrapper`n", [Text.UTF8Encoding]::new($false))
    $llvmWsl = Convert-ToWslPath $llvmPath
    $executableWsl = Convert-ToWslPath $executablePath
    $build = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d', 'Ubuntu', '--', 'clang', '-Wall', '-Wextra', '-Werror', $harnessWsl, $llvmWsl, '-o', $executableWsl) -Description "$authority Linux poll build" -TimeoutMilliseconds 20000
    [IO.File]::WriteAllText((Join-Path $output "$authority.build.log"), $build.Stdout + $build.Stderr)
    if ($build.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($build.Stderr)) { throw "$authority Linux build failed: $($build.Stderr)" }
    $run = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @('-d', 'Ubuntu', '--', $executableWsl) -Description "$authority Linux poll run" -TimeoutMilliseconds 20000
    [IO.File]::WriteAllText((Join-Path $output "$authority.run.log"), $run.Stdout + $run.Stderr)
    if ($run.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($run.Stderr) -or $run.Stdout.Trim() -cne 'process tryWait linux runtime: 8/8') {
        throw "$authority Linux execution failed: $($run.Stdout)$($run.Stderr)"
    }
    $results += [ordered]@{
        authority = $authority
        source = $relativePath
        sourceSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        llvmSha256 = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
        executableSha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
        passed = 8
        total = 8
    }
}

[IO.File]::WriteAllText((Join-Path $output 'result.json'), ((([ordered]@{
    schemaVersion = 1
    status = 'passed'
    evidenceScope = 'extracted-production-functions-not-rebuilt-selfhost'
    harnessSha256 = (Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash
    authorities = $results
} | ConvertTo-Json -Depth 5) + "`n")))
Write-Host "[process tryWait Linux runtime] PASS 16/16; $output/result.json"
