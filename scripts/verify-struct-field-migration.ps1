[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$sourceRoots = @("stdlib", "selfhost", "examples", "tests") |
    ForEach-Object { Join-Path $root $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container }

function Get-PublicFieldInsertions {
    param([Parameter(Mandatory)][string]$Text)

    $insertions = [System.Collections.Generic.SortedSet[int]]::new()
    $headers = [regex]::Matches(
        $Text,
        '(?m)\bpublic\s+(?:opaque\s+)?struct\s+[A-Za-z_][A-Za-z0-9_.]*\s*\{')
    foreach ($header in $headers) {
        $openBrace = $Text.IndexOf('{', $header.Index)
        if ($openBrace -lt 0) { continue }

        $depth = 1
        $index = $openBrace + 1
        $lineComment = $false
        while ($index -lt $Text.Length -and $depth -gt 0) {
            $character = $Text[$index]
            if ($lineComment) {
                if ($character -eq "`n") { $lineComment = $false }
                $index++
                continue
            }
            if ($character -eq '#') {
                $lineComment = $true
                $index++
                continue
            }
            if ($character -eq '{') {
                $depth++
                $index++
                continue
            }
            if ($character -eq '}') {
                $depth--
                $index++
                continue
            }
            if ($depth -ne 1 -or
                -not ([char]::IsLetter($character) -or $character -eq '_')) {
                $index++
                continue
            }

            $identifierStart = $index
            $index++
            while ($index -lt $Text.Length -and
                ([char]::IsLetterOrDigit($Text[$index]) -or $Text[$index] -eq '_')) {
                $index++
            }
            $afterIdentifier = $index
            while ($afterIdentifier -lt $Text.Length -and
                [char]::IsWhiteSpace($Text[$afterIdentifier])) {
                $afterIdentifier++
            }
            if ($afterIdentifier -ge $Text.Length -or $Text[$afterIdentifier] -ne ':') {
                continue
            }

            $beforeIdentifier = $identifierStart - 1
            while ($beforeIdentifier -ge 0 -and [char]::IsWhiteSpace($Text[$beforeIdentifier])) {
                $beforeIdentifier--
            }
            $previousEnd = $beforeIdentifier + 1
            while ($beforeIdentifier -ge 0 -and
                ([char]::IsLetterOrDigit($Text[$beforeIdentifier]) -or $Text[$beforeIdentifier] -eq '_')) {
                $beforeIdentifier--
            }
            $previous = if ($previousEnd -gt $beforeIdentifier + 1) {
                $Text.Substring($beforeIdentifier + 1, $previousEnd - $beforeIdentifier - 1)
            } else { "" }
            if ($previous -cne 'public') {
                [void]$insertions.Add($identifierStart)
            }
        }
    }
    @($insertions)
}

$expectedPrivateFields = [ordered]@{
    # Only the checked plan compiler/evaluator may mutate instruction topology or slots.
    'selfhost/semantic/constant_expressions.slg' = 2
    'stdlib/std/net/quic/transport_parameters.slg' = 1
    # HMAC owns both hash states; callers use update/finish without replacing them.
    'stdlib/std/crypto/hmac_sha256.slg' = 2
    # Replay storage, scratch, cursor, and ceilings remain adapter-owned.
    'stdlib/std/io.slg' = 5
    # File adapters encapsulate their affine handles and explicit positions.
    'stdlib/std/io/file.slg' = 4
    # Completion slots expose observations and consuming buffer recovery only;
    # the socket runtime exclusively owns native identity and state transitions.
    'stdlib/std/net/socket.slg' = 9
    # Cross-module method-owner fixtures construct and inspect state through methods.
    'examples/regression/fixtures/1501-method-owner-leaf.slg' = 1
    'examples/regression/fixtures/1501-method-owner-wrapper.slg' = 2
    'examples/regression/diagnostics/sample/opaque_value.slg' = 2
    'examples/regression/1392-selfhost-opaque-struct-ast.slg' = 1
    'examples/regression/1393-selfhost-opaque-struct-diagnostics.slg' = 1
    'examples/regression/diagnostics/opaque-struct-modifier-rejected.slg' = 1
}
$actualPrivateFields = [ordered]@{}
foreach ($file in Get-ChildItem -LiteralPath $sourceRoots -Recurse -File -Filter "*.slg") {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $insertions = @(Get-PublicFieldInsertions -Text $text)
    if ($insertions.Count -eq 0) { continue }
    $relativePath = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
    $actualPrivateFields[$relativePath] = $insertions.Count
}

foreach ($expected in $expectedPrivateFields.GetEnumerator()) {
    if (-not $actualPrivateFields.Contains($expected.Key) -or
        $actualPrivateFields[$expected.Key] -ne $expected.Value) {
        throw "expected $($expected.Value) reviewed private field(s) in '$($expected.Key)'"
    }
}
foreach ($actual in $actualPrivateFields.GetEnumerator()) {
    if (-not $expectedPrivateFields.Contains($actual.Key)) {
        throw "unreviewed private-by-default field found in public struct: $($actual.Key) ($($actual.Value))"
    }
}

$privateFieldCount = ($actualPrivateFields.Values | Measure-Object -Sum).Sum
Write-Host "[struct field migration] PASS $privateFieldCount reviewed private field(s), $($actualPrivateFields.Count) files, zero unreviewed compatibility changes."
