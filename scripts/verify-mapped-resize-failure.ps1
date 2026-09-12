[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('preserved', 'baseline-failure')]
    [string]$Expectation = 'preserved'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/1706-map-write-resize-failure.c'
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name '1706-mapped-resize' -Harness $harness
$output = $probe.Output
$runtimeSources = [ordered]@{
    selfhost = 'selfhost/llvm/runtime.slg'
    managed = 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.cs'
}
$declarations = @'
%sollang.mapped_bytes = type { ptr, i64, ptr, i64, i1 }
declare dllimport ptr @CreateFileA(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport i32 @CloseHandle(ptr)
declare dllimport i32 @GetFileSizeEx(ptr, ptr)
declare dllimport ptr @CreateFileMappingA(ptr, ptr, i32, i32, i32, ptr)
declare dllimport ptr @MapViewOfFile(ptr, i32, i32, i32, i64)
declare dllimport i32 @UnmapViewOfFile(ptr)
declare i32 @sollang_probe_seek(ptr, i64, ptr, i32)
declare i32 @sollang_probe_end(ptr)
'@
$wrapper = @'
define i32 @sollang_probe_map(ptr %path, i64 %length, i64 %size) {
entry:
  %value = call %sollang.mapped_bytes @sollang_map_file(ptr %path, i64 %length, i64 0, i64 0, i64 %size, i1 true)
  %data = extractvalue %sollang.mapped_bytes %value, 0
  %valid = icmp ne ptr %data, null
  br i1 %valid, label %mapped, label %failed
mapped:
  %base = extractvalue %sollang.mapped_bytes %value, 2
  %unmapped = call i32 @UnmapViewOfFile(ptr %base)
  %released = icmp ne i32 %unmapped, 0
  %result = zext i1 %released to i32
  ret i32 %result
failed:
  ret i32 0
}
'@
$results = @()
foreach ($authority in $runtimeSources.Keys) {
    $sourcePath = Join-Path $root $runtimeSources[$authority]
    $source = [IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n")
    $functions = [regex]::Matches($source, '(?ms)^\s*define internal %sollang\.mapped_bytes @sollang_map_file\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    $expectedCount = if ($authority -eq 'selfhost') { 2 } else { 1 }
    if ($functions.Count -ne $expectedCount) {
        throw "Unexpected map runtime extraction count for ${authority}: $($functions.Count)"
    }
    # Self-host declares Windows first and Linux second; identify the OS by
    # actual calls, rather than silently accepting a different runtime block.
    $windowsFunctions = @($functions | Where-Object { $_.Value.Contains('@CreateFileA(') })
    if ($windowsFunctions.Count -ne 1) { throw "Expected one Windows map function for $authority" }
    $body = $windowsFunctions[0].Value.Replace(' #0 {', ' {')
    $body = $body.Replace('@SetFilePointerEx(', '@sollang_probe_seek(').Replace('@SetEndOfFile(', '@sollang_probe_end(')
    if ($authority -eq 'managed') {
        $helperSource = [IO.File]::ReadAllText((Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.RuntimeHelpers.cs')).Replace("`r`n", "`n")
        $copyFunctions = [regex]::Matches($helperSource, '(?ms)^\s*define internal i32 @sollang_copy_text_to_c_path\([^\n]+\) #0 \{.*?^\s*\}')
        if ($copyFunctions.Count -ne 1) { throw 'Expected one managed C path copy runtime function.' }
        $body += "`n" + $copyFunctions[0].Value.Replace(' #0 {', ' {')
    }
    $result = Invoke-RuntimeLlvmProbe -Probe $probe -Authority $authority -Llvm "$declarations`n$body`n$wrapper" -Arguments @($Expectation) -ExpectedOutput "mapped resize ${Expectation}: 3/3"
    $results += [ordered]@{
        authority = $authority
        sourcePath = $runtimeSources[$authority]
        sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
        extractedLlvmHash = $result.LlvmHash
        executableHash = $result.ExecutableHash
        passed = 3
        total = 3
    }
    Write-Host "[mapped resize] PASS $authority $Expectation 3/3"
}
[IO.File]::WriteAllText((Join-Path $output 'result.json'), (([ordered]@{
    schemaVersion = 1
    expectation = $Expectation
    status = 'passed'
    harnessHash = (Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash
    authorities = $results
} | ConvertTo-Json -Depth 5) + "`n"))
Write-Host "[mapped resize] Evidence: $output"
