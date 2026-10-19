[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedInterpolationLlvm,
    [Parameter(Mandatory)][string]$SelfhostInterpolationLlvm,
    [Parameter(Mandatory)][string]$ManagedDirectLlvm,
    [Parameter(Mandatory)][string]$SelfhostDirectLlvm,
    [Parameter(Mandatory)][string]$FullWordSelfhostLlvm,
    [Parameter(Mandatory)][string]$Tail63SelfhostLlvm,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output = [IO.Path]::GetFullPath($OutputPath, $root)
if (Test-Path -LiteralPath $output) { throw "BitSet mask result already exists: $output" }

$cases = @(
    [pscustomobject]@{ Name = 'interpolation'; Managed = $ManagedInterpolationLlvm; Selfhost = $SelfhostInterpolationLlvm },
    [pscustomobject]@{ Name = 'direct'; Managed = $ManagedDirectLlvm; Selfhost = $SelfhostDirectLlvm }
)
$inputs = @($cases | ForEach-Object { $_.Managed; $_.Selfhost } | ForEach-Object { [IO.Path]::GetFullPath($_, $root) }) +
    @([IO.Path]::GetFullPath($FullWordSelfhostLlvm, $root), [IO.Path]::GetFullPath($Tail63SelfhostLlvm, $root))
foreach ($inputPath in $inputs) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { throw "BitSet mask LLVM input missing: $inputPath" }
}
function Get-Hashes {
    $result = [ordered]@{}
    foreach ($inputPath in $inputs) { $result[$inputPath] = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash }
    return $result
}

$startHashes = Get-Hashes
$rows = @(
    foreach ($case in $cases) {
        $managed = [IO.File]::ReadAllText([IO.Path]::GetFullPath($case.Managed, $root))
        $selfhost = [IO.File]::ReadAllText([IO.Path]::GetFullPath($case.Selfhost, $root))
        $managedMask = [regex]::IsMatch($managed, '(?m)^\s*%[A-Za-z0-9_]+ = and i64 %[A-Za-z0-9_]+, 3\s*$')
        $selfhostMask = [regex]::IsMatch($selfhost, '(?m)^\s*%[A-Za-z0-9_]+_tail2 = and i64 %[A-Za-z0-9_]+_word2, 3\s*$')
        $selfhostPopMasked = [regex]::IsMatch($selfhost, '(?m)^\s*%[A-Za-z0-9_]+_pop2 = call i64 @llvm\.ctpop\.i64\(i64 %[A-Za-z0-9_]+_tail2\)\s*$')
        [ordered]@{
            name = $case.Name
            managedMask = $managedMask
            selfhostMask = $selfhostMask
            selfhostPopMasked = $selfhostPopMasked
            passed = $managedMask -and $selfhostMask -and $selfhostPopMasked
        }
    }
)
$fullWord = [IO.File]::ReadAllText([IO.Path]::GetFullPath($FullWordSelfhostLlvm, $root))
$fullWordPopCount = [regex]::Matches($fullWord, 'call i64 @llvm\.ctpop\.i64\(i64 ').Count
$fullWordNoTail = -not [regex]::IsMatch($fullWord, '_tail[0-9]+ = and i64')
$rows += [ordered]@{
    name = 'full-word'
    selfhostPopCount = $fullWordPopCount
    selfhostNoTailMask = $fullWordNoTail
    passed = $fullWordPopCount -eq 2 -and $fullWordNoTail
}
$tail63 = [IO.File]::ReadAllText([IO.Path]::GetFullPath($Tail63SelfhostLlvm, $root))
$tail63MaskCount = [regex]::Matches($tail63, '(?m)^\s*%[A-Za-z0-9_]+_tail0 = and i64 %[A-Za-z0-9_]+_word0, 9223372036854775807\s*$').Count
$rows += [ordered]@{
    name = 'tail-63'
    selfhostMaskCount = $tail63MaskCount
    passed = $tail63MaskCount -eq 2
}
$endHashes = Get-Hashes
$stable = ($startHashes | ConvertTo-Json -Compress) -ceq ($endHashes | ConvertTo-Json -Compress)
$passed = $stable -and @($rows | Where-Object { -not $_.passed }).Count -eq 0
$record = [ordered]@{
    schemaVersion = 1
    gate = 'bitset-count-tail-mask'
    status = if ($passed) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count
    total = $rows.Count
    inputHashesStart = $startHashes
    inputHashesEnd = $endHashes
    inputsStable = $stable
    cases = $rows
}
[IO.File]::WriteAllText($output, ($record | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
if (-not $passed) { throw "BitSet tail mask differs from C#; result=$output" }
Write-Output "[BitSet tail mask] PASS $($record.completed)/$($record.total); result=$output"
