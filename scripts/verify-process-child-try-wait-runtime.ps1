[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/1716-process-child-try-wait-runtime.c'
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name '1716-process-child-try-wait-runtime' -Harness $harness
$authorities = [ordered]@{
    managed = 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'
    selfhost = 'selfhost/llvm/emitter/process_runtime.slg'
}
$declarations = @'
%sollang.process_poll_result = type { i32, i32 }
declare dllimport i32 @WaitForSingleObject(ptr, i32)
declare dllimport i32 @GetExitCodeProcess(ptr, ptr)
declare dllimport i32 @CloseHandle(ptr)
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
'@

$results = @()
foreach ($authority in $authorities.Keys) {
    $relativePath = $authorities[$authority]
    $path = Join-Path $root $relativePath
    $source = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $matches = [regex]::Matches($source, '(?ms)^\s*define internal %sollang\.process_poll_result @sollang_poll_process\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    $expected = if ($authority -eq 'selfhost') { 2 } else { 1 }
    if ($matches.Count -ne $expected) { throw "Expected $expected poll functions in $relativePath, found $($matches.Count)" }
    $windows = @($matches | Where-Object { $_.Value.Contains('@WaitForSingleObject(') })
    if ($windows.Count -ne 1) { throw "Expected one Windows poll function in $relativePath" }
    $body = $windows[0].Value.Replace(' #0 {', ' {')
    $result = Invoke-RuntimeLlvmProbe -Probe $probe -Authority $authority -Llvm "$declarations`n$body`n$wrapper" -ExpectedOutput 'process tryWait runtime: 5/5'
    $results += [ordered]@{
        authority = $authority
        source = $relativePath
        sourceSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        llvmSha256 = $result.LlvmHash
        executableSha256 = $result.ExecutableHash
        passed = 5
        total = 5
    }
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    evidenceScope = 'extracted-production-functions-not-rebuilt-selfhost'
    harnessSha256 = (Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash
    authorities = $results
}
[IO.File]::WriteAllText((Join-Path $probe.Output 'result.json'), (($record | ConvertTo-Json -Depth 5) + "`n"))
Write-Host "[process tryWait runtime] PASS 10/10; $($probe.Output)/result.json"
