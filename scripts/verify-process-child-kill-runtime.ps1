[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$authorities = [ordered]@{
    managed = 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'
    selfhost = 'selfhost/llvm/emitter/process_runtime.slg'
}
$windowsHarness = Join-Path $PSScriptRoot 'contracts/fixtures/1737-process-child-kill-windows-runtime.c'
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name '1737-process-child-kill-windows-runtime' -Harness $windowsHarness
$windowsResults = @()
$wrapper = @'
define i1 @sollang_probe_kill(i64 %token) {
entry:
  %result = call i1 @sollang_kill_process(i64 %token)
  ret i1 %result
}
'@

foreach ($authority in $authorities.Keys) {
    $relativePath = $authorities[$authority]
    $path = Join-Path $root $relativePath
    $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $matches = [regex]::Matches($source, '(?ms)^\s*define internal i1 @sollang_kill_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    $expected = if ($authority -eq 'selfhost') { 2 } else { 1 }
    if ($matches.Count -ne $expected) { throw "Expected $expected kill functions in $relativePath, found $($matches.Count)" }
    $windows = @($matches | Where-Object { $_.Value.Contains('@TerminateProcess(') })
    if ($windows.Count -ne 1) { throw "Expected one Windows kill function in $relativePath" }
    $body = $windows[0].Value.Replace(' #0 {', ' {')
    $declarations = 'declare dllimport i32 @TerminateProcess(ptr, i32)'
    $result = Invoke-RuntimeLlvmProbe -Probe $probe -Authority $authority `
        -Llvm "$declarations`n$body`n$wrapper" -ExpectedOutput 'process kill windows runtime: 3/3'
    $windowsResults += [ordered]@{
        authority = $authority
        sourceSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        llvmSha256 = $result.LlvmHash
        executableSha256 = $result.ExecutableHash
        passed = 3
        total = 3
    }
}

function Convert-ToWslPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $drive = $full.Substring(0, 1).ToLowerInvariant()
    return "/mnt/$drive/" + $full.Substring(3).Replace('\', '/')
}

$linuxOutput = Join-Path $root ('artifacts/scratch/1737-process-child-kill-linux-runtime-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($linuxOutput)
$linuxHarness = Join-Path $PSScriptRoot 'contracts/fixtures/1737-process-child-kill-linux-runtime.c'
$linuxResults = @()
foreach ($authority in ([ordered]@{
    managed = 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'
    selfhost = 'selfhost/llvm/emitter/process_runtime.slg'
}).Keys) {
    $relativePath = if ($authority -eq 'managed') {
        'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.cs'
    } else {
        'selfhost/llvm/emitter/process_runtime.slg'
    }
    $path = Join-Path $root $relativePath
    $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $matches = [regex]::Matches($source, '(?ms)^\s*define internal i1 @sollang_kill_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    $linux = @($matches | Where-Object { $_.Value.Contains('@kill(i32 %pid, i32 9)') })
    if ($linux.Count -ne 1) { throw "Expected one Linux kill function in $relativePath" }
    $body = $linux[0].Value.Replace(' #0 {', ' {')
    $llvmPath = Join-Path $linuxOutput "$authority.ll"
    $executablePath = Join-Path $linuxOutput $authority
    $llvm = "target triple = `"x86_64-pc-linux-gnu`"`ndeclare i32 @kill(i32, i32)`n$body`n$wrapper`n"
    [IO.File]::WriteAllText($llvmPath, $llvm, [Text.UTF8Encoding]::new($false))
    $build = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @(
        '-d', 'Ubuntu', '--', 'clang', '-Wall', '-Wextra', '-Werror',
        (Convert-ToWslPath $linuxHarness), (Convert-ToWslPath $llvmPath),
        '-o', (Convert-ToWslPath $executablePath)
    ) -Description "$authority Linux kill build" -TimeoutMilliseconds 20000
    if ($build.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($build.Stderr)) {
        throw "$authority Linux kill build failed: $($build.Stderr)"
    }
    $run = Invoke-VerificationProcessCapture -FilePath 'wsl.exe' -ArgumentList @(
        '-d', 'Ubuntu', '--', (Convert-ToWslPath $executablePath)
    ) -Description "$authority Linux kill run" -TimeoutMilliseconds 20000
    $hasStandardError = -not [string]::IsNullOrWhiteSpace($run.Stderr)
    $hasUnexpectedOutput = $run.Stdout.Trim() -cne 'process kill linux runtime: 3/3'
    if ($run.ExitCode -ne 0 -or $hasStandardError -or $hasUnexpectedOutput) {
        throw "$authority Linux kill execution failed: $($run.Stdout)$($run.Stderr)"
    }
    $linuxResults += [ordered]@{
        authority = $authority
        sourceSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        llvmSha256 = (Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash
        executableSha256 = (Get-FileHash -LiteralPath $executablePath -Algorithm SHA256).Hash
        passed = 3
        total = 3
    }
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    evidenceScope = 'extracted-managed-and-selfhost-production-functions'
    windows = $windowsResults
    linux = $linuxResults
}
[IO.File]::WriteAllText((Join-Path $probe.Output 'result.json'), (($record | ConvertTo-Json -Depth 6) + "`n"))
Write-Host "[process Child.kill runtime] PASS 12/12; $($probe.Output)/result.json"
