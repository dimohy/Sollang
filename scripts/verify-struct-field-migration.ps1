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
    # GZIP codec, encoder, framed decoder, and raw DEFLATE decoder fields are
    # validated streaming state; callers use checked factories and write/finish.
    'stdlib/std/compress/gzip.slg' = 51
    # ZIP codec limits plus affine stored/DEFLATE decoder and writer header,
    # payload, checksum, directory, phase, and failure state are mutated only by
    # checked instance construction, write, entry-finalization, and consuming finish.
    'stdlib/std/archive/zip.slg' = 41
    # Binary reader/writer order, cursor, ceiling, and produced count advance
    # only through checked factories and instance operations.
    'stdlib/std/encoding/binary.slg' = 5
    # Hash configuration, accumulators, byte counts, and buffered tails stay
    # hasher-owned behind write/checksum/reset operations.
    'stdlib/std/hash/crc32.slg' = 2
    'stdlib/std/hash/xxhash64.slg' = 9
    # Replay storage, scratch, cursor, and ceilings remain adapter-owned.
    'stdlib/std/io.slg' = 5
    # BufferQueue owns storage, cursor, watermarks, and pause state so its
    # bounded backpressure invariant cannot be fabricated by callers.
    'stdlib/std/io/async.slg' = 5
    # DiagnosticSession is an affine compiler-owned capability. Callers use
    # track, snapshot, and close rather than fabricating its opaque token.
    'stdlib/std/async/diagnostics.slg' = 1
    # File adapters encapsulate their affine handles and explicit positions.
    'stdlib/std/io/file.slg' = 4
    # AsyncStream is the sole affine owner of its completion reactor and next
    # operation identity; callers advance both only through consuming methods.
    'stdlib/std/io/socket.slg' = 2
    # The completion reactor token and completion-slot state stay private;
    # the socket runtime exclusively owns native identity and transitions.
    'stdlib/std/net/socket.slg' = 10
    # Clock identity, affine timer state, tick ownership, and fixed offsets
    # cannot be fabricated outside the validated clock constructors.
    'stdlib/std/time.slg' = 16
    # Logger filtering remains controlled by its constructor and instance API.
    'stdlib/std/log.slg' = 1
    # Original authority spelling is retained only by the validated URI parser.
    'stdlib/std/uri.slg' = 1
    # Path iteration retains its borrowed source, cursor, bounds, style, limits,
    # and parsed header; callers observe components only through instance APIs.
    'stdlib/std/path.slg' = 7
    # sys.path.Path retains validated UTF-8 bytes and style behind factories
    # and inherent observation/normalization methods.
    'stdlib/sys/path.slg' = 2
    # CSV reader/writer cursors, budgets, and format state are advanced only by
    # their checked instance APIs; callers receive public Field/Error values.
    'stdlib/std/text/csv.slg' = 13
    # Compiled text matchers retain borrowed source and validated work limits;
    # their representation is not a public construction or mutation surface.
    'stdlib/std/text/glob.slg' = 4
    'stdlib/std/text/regex.slg' = 9
    # Child owns the affine OS token and cached terminal observation. Callers
    # use processId/tryWait/wait rather than fabricating lifecycle state.
    'stdlib/sys/process.slg' = 4
    # Cross-module method-owner fixtures construct and inspect state through methods.
    'examples/regression/fixtures/1501-method-owner-leaf.slg' = 1
    'examples/regression/fixtures/1501-method-owner-wrapper.slg' = 2
    'examples/regression/diagnostics/sample/opaque_value.slg' = 2
    'examples/regression/1392-selfhost-opaque-struct-ast.slg' = 1
    'examples/regression/1393-selfhost-opaque-struct-diagnostics.slg' = 1
    'examples/regression/diagnostics/opaque-struct-modifier-rejected.slg' = 1
    # The qualified-call fixture deliberately exposes its embedded Path only
    # through fromText, normalizeConfined, and byteCount.
    'examples/regression/656-selfhost-qualified-move-when-ir.slg' = 2
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
$unreviewedPrivateFields = @($actualPrivateFields.GetEnumerator() |
    Where-Object { -not $expectedPrivateFields.Contains($_.Key) } |
    ForEach-Object { "$($_.Key) ($($_.Value))" })
if ($unreviewedPrivateFields.Count -ne 0) {
    throw "unreviewed private-by-default fields found in public structs: $($unreviewedPrivateFields -join ', ')"
}

$privateFieldCount = ($actualPrivateFields.Values | Measure-Object -Sum).Sum
Write-Host "[struct field migration] PASS $privateFieldCount reviewed private field(s), $($actualPrivateFields.Count) files, zero unreviewed compatibility changes."
