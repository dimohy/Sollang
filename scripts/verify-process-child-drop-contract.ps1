param()

$ErrorActionPreference = "Stop"

$verifier = Join-Path $PSScriptRoot "verify-process-child-drop-once.ps1"
$temporaryPaths = [System.Collections.Generic.List[string]]::new()

function New-ProcessDropFixture {
    param(
        [string]$Body
    )

    $path = [System.IO.Path]::GetTempFileName()
    $temporaryPaths.Add($path)
    [System.IO.File]::WriteAllText($path, $Body.Replace("`r`n", "`n"))
    $path
}

function Assert-ProcessDropRejected {
    param(
        [string]$Path,
        [string]$ExpectedFragment
    )

    $rejected = $false
    try {
        & $verifier -LlvmPath $Path | Out-Null
    } catch {
        if (-not $_.Exception.Message.Contains($ExpectedFragment, [System.StringComparison]::Ordinal)) {
            throw "process Child drop verifier rejected with the wrong diagnostic: $($_.Exception.Message)"
        }
        $rejected = $true
    }
    if (-not $rejected) {
        throw "process Child drop verifier accepted unsafe fixture '$Path'"
    }
}

$dropGlue = @'
define internal void @sollang_drop_t1(%child %value) {
entry:
  %handle = extractvalue %child %value, 0
  call void @sollang_drop_process_child(i64 %handle)
  ret void
}
define internal void @sollang_drop_t2(%result %value) {
entry:
  %child = extractvalue %result %value, 1
  call void @sollang_drop_t1(%child %child)
  ret void
}
'@

try {
    $selfhostSafe = New-ProcessDropFixture ($dropGlue + @'
define void @main() {
entry:
  ret void
}
'@)
    & $verifier -LlvmPath $selfhostSafe | Out-Null

    $managedSafe = New-ProcessDropFixture ($dropGlue + @'
define void @main(%result %value) {
entry:
  call void @sollang_drop_t2(%result %value)
  ret void
}
'@)
    & $verifier -LlvmPath $managedSafe | Out-Null

    $doubleOuter = New-ProcessDropFixture ($dropGlue + @'
define void @main(%result %value) {
entry:
  call void @sollang_drop_t2(%result %value)
  call void @sollang_drop_t2(%result %value)
  ret void
}
'@)
    Assert-ProcessDropRejected $doubleOuter "cleaned up a second time"

    $directNested = New-ProcessDropFixture ($dropGlue + @'
define void @main(%child %value) {
entry:
  call void @sollang_drop_t1(%child %value)
  ret void
}
'@)
    Assert-ProcessDropRejected $directNested "direct nested cleanup"
} finally {
    foreach ($path in $temporaryPaths) {
        Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
    }
}

Write-Host "[process Child drop contract] PASS managed/selfhost safe shapes and double/nested cleanup negative controls."
