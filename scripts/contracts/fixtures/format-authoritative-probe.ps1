$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($env:SOLLANG_FOCUSED_FORMAT_PROBE)) {
    throw 'formatter probe requires its explicit output path'
}
[IO.File]::AppendAllText($env:SOLLANG_FOCUSED_FORMAT_PROBE,
    ((@($args) | ConvertTo-Json -Compress) + "`n"))
exit 0
