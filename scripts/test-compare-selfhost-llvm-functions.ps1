[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$directory = Join-Path $root "artifacts/scratch/llvm-function-comparison-$([Guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($directory)
$baseline = Join-Path $directory 'baseline.ll'
$candidate = Join-Path $directory 'candidate.ll'
$tool = Join-Path $PSScriptRoot 'compare-selfhost-llvm-functions.ps1'
$encoding = [Text.UTF8Encoding]::new($false)
$text = @'
declare void @ignored()
define void @first() { ret void }
define void @second() { ret void } ; inline wrapper
define i32 @third() {
entry:
  ret i32 3
}
'@
[IO.File]::WriteAllText($baseline, $text, $encoding)
[IO.File]::WriteAllText($candidate, $text, $encoding)
function Compare-Inputs {
    (& $tool -Baseline $baseline -Candidate $candidate) -join "`n" | ConvertFrom-Json
}
$same = Compare-Inputs
if ($same.baseline.functionCount -ne 3 -or $same.candidate.functionCount -ne 3 -or
    @($same.changed).Count -ne 0) { throw 'MIXED_FUNCTION_DEFINITIONS_NOT_SEPARATED' }
[IO.File]::WriteAllText($candidate, $text.Replace('@second() { ret void }', '@second() { unreachable }'), $encoding)
$changed = Compare-Inputs
if (@($changed.changed).Count -ne 1 -or $changed.changed[0] -cne 'second' -or
    @($changed.added).Count -ne 0 -or @($changed.removed).Count -ne 0) {
    throw 'INLINE_CHANGE_LEAKED_TO_NEIGHBOR'
}
[IO.File]::WriteAllText($candidate, $text + "`ndefine void @fourth() { ret void }`n", $encoding)
$added = Compare-Inputs
if (@($added.added).Count -ne 1 -or $added.added[0] -cne 'fourth' -or
    @($added.changed).Count -ne 0) { throw 'INLINE_FUNCTION_ADDITION_NOT_REPORTED' }
function Assert-Rejected([string]$InputText, [string]$Expected) {
    [IO.File]::WriteAllText($candidate, $InputText, $encoding)
    try { $null = Compare-Inputs; throw 'EXPECTED_REJECTION' }
    catch { if (-not $_.Exception.Message.Contains($Expected)) { throw } }
}
Assert-Rejected "define void @duplicate() { ret void }`ndefine void @duplicate() { ret void }`n" 'duplicate LLVM function definition'
Assert-Rejected "define void @unfinished() {`nentry:`n  ret void`n" 'unterminated LLVM function definition'
Assert-Rejected "define void @unfinished() {`ndefine void @next() { ret void }`n" 'unterminated LLVM function definition'
[pscustomobject]@{ status = 'passed'; completed = 6; total = 6; outputDirectory = $directory } | ConvertTo-Json
