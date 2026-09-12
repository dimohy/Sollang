[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/80-utf8-each-runtime.c'
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name '80-utf8-each-runtime' -Harness $harness
$foundationPath = Join-Path $root 'selfhost/llvm/text/foundation.slg'
$foundation = [IO.File]::ReadAllText($foundationPath).Replace("`r`n", "`n")
$fragment = [regex]::Match($foundation, '(?ms)^\s*eachText -> if \{\n(?<body>\s*"  %each\$\(eachIndex\)_utf8 = call i64 @sollang_utf8_decode.*?)(?=^\s*\} else \{)')
if (-not $fragment.Success) { throw 'Self-host Text each decode materializer is missing.' }
$bodyLines = @([regex]::Matches($fragment.Groups['body'].Value, '(?m)^\s*"(?<text>[^"\n]*)" -> println\s*$') | ForEach-Object { $_.Groups['text'].Value.Replace('$(eachIndex)', '0') })
if ($bodyLines.Count -ne 9) { throw "Text each decode materializer inventory changed: $($bodyLines.Count)" }
$nextLine = [regex]::Matches($foundation, '(?m)^\s*"(?<text>  %each\$\(eachIndex\)_next = add i64 %each\$\(eachIndex\)_index, %each\$\(eachIndex\)_width)" -> println\s*$')
if ($nextLine.Count -ne 1) { throw 'Text each must advance by the decoded byte width.' }
$next = $nextLine[0].Groups['text'].Value.Replace('$(eachIndex)', '0')
$body = $bodyLines -join "`n"
# The decoder body and Text-loop decode/advance instructions below are extracted
# from the actual authorities. The wrapper supplies only loop/output plumbing;
# this is runtime-fragment evidence, not a fresh whole-compiler result.
$wrapper = @'
declare void @llvm.trap()
define i64 @sollang_probe_decode(ptr %data, i64 %length, i64 %index) {
entry:
  %packed = call i64 @sollang_utf8_decode(ptr %data, i64 %length, i64 %index)
  ret i64 %packed
}
define i64 @sollang_probe_each(ptr %data, i64 %length, ptr %output) {
entry:
  %each0_data = freeze ptr %data
  %each0_length = freeze i64 %length
  %each0_index_slot = alloca i64, align 8
  %count_slot = alloca i64, align 8
  store i64 0, ptr %each0_index_slot, align 8
  store i64 0, ptr %count_slot, align 8
  br label %each0_header
each0_header:
  %each0_index = load i64, ptr %each0_index_slot, align 8
  %done = icmp uge i64 %each0_index, %each0_length
  br i1 %done, label %each0_exit, label %each0_body
each0_body:
__DECODE_BODY__
  %count = load i64, ptr %count_slot, align 8
  %slot = getelementptr i32, ptr %output, i64 %count
  store i32 %each0_item, ptr %slot, align 4
  %next_count = add i64 %count, 1
  store i64 %next_count, ptr %count_slot, align 8
  br label %each0_continue
each0_continue:
__ADVANCE__
  store i64 %each0_next, ptr %each0_index_slot, align 8
  br label %each0_header
each0_exit:
  %total = load i64, ptr %count_slot, align 8
  ret i64 %total
}
'@
$wrapper = $wrapper.Replace('__DECODE_BODY__', $body).Replace('__ADVANCE__', $next)
$sources = [ordered]@{ selfhost = 'selfhost/llvm/runtime.slg'; managed = 'src/Sollang.Compiler/CodeGen/LlvmEmitter.RuntimeHelpers.cs' }
$results = @()
$normalizedReference = $null
foreach ($authority in $sources.Keys) {
    $sourcePath = Join-Path $root $sources[$authority]
    $source = [IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n")
    $functions = [regex]::Matches($source, '(?ms)^\s*define internal i64 @sollang_utf8_decode\([^\n]+\) (?:#0 )?\{.*?^\s*\}')
    if ($functions.Count -ne 1) { throw "Expected one UTF-8 decoder in $authority" }
    $decoder = $functions[0].Value.Replace(' #0 {', ' {')
    $normalized = ($decoder -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join "`n"
    if ($null -eq $normalizedReference) { $normalizedReference = $normalized }
    elseif ($normalized -cne $normalizedReference) { throw 'Managed/self-host UTF-8 decoder implementations drifted.' }
    $result = Invoke-RuntimeLlvmProbe -Probe $probe -Authority $authority -Llvm "$decoder`n$wrapper" -ExpectedOutput 'utf8 decoder 28/28; each fragments 2/2'
    $results += [ordered]@{ authority = $authority; sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash; extractedLlvmHash = $result.LlvmHash; executableHash = $result.ExecutableHash; decoderPassed = 28; decoderTotal = 28; eachPassed = 2; eachTotal = 2 }
    Write-Host "[UTF-8 runtime] PASS $authority decoder 28/28; extracted each fragments 2/2"
}
[IO.File]::WriteAllText((Join-Path $probe.Output 'result.json'), (([ordered]@{
    schemaVersion = 1
    status = 'passed'
    scope = 'extracted-runtime-and-each-fragments'
    compilerIntegration = 'pending'
    harnessHash = (Get-FileHash -LiteralPath $harness -Algorithm SHA256).Hash
    foundationHash = (Get-FileHash -LiteralPath $foundationPath -Algorithm SHA256).Hash
    authorities = $results
} | ConvertTo-Json -Depth 5) + "`n"))
Write-Host "[UTF-8 runtime] Evidence: $($probe.Output)"
