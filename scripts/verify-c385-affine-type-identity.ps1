[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Resolve-Input([string]$Path) {
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }
    return (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$compiler = Resolve-Input $CompilerPath
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'AFFINE_TYPE_OUTPUT_PATH_INVALID' }
if (Test-Path -LiteralPath $output) { throw "AFFINE_TYPE_OUTPUT_EXISTS: $output" }
$cases = @(
    [pscustomobject]@{ id = 'stream-consume-twice'; source = 'examples/regression/diagnostics/stream-consume-twice.slg'; name = 'values'; symbol = 3; reads = 2 },
    [pscustomobject]@{ id = 'event-stream-consume-twice'; source = 'examples/regression/diagnostics/event-stream-consume-twice.slg'; name = 'events'; symbol = 4; reads = 2 },
    [pscustomobject]@{ id = 'event-stream-named-receiver-control'; source = 'examples/regression/588-mouse-event-stream.slg'; name = 'rawEvents'; symbol = 4; reads = 1 }
)
$sources = @($cases | ForEach-Object { Resolve-Input $_.source })
function Get-StdlibFiles {
    return @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -Filter '*.slg' -File | Sort-Object FullName | ForEach-Object FullName)
}
$stdlib = @(Get-StdlibFiles)
if ($stdlib.Count -eq 0) { throw 'AFFINE_TYPE_STDLIB_EMPTY' }
function Get-StdlibFingerprint {
    $lines = foreach ($path in (Get-StdlibFiles)) { "$($path.Replace('\', '/')) $(Get-Sha $path)" }
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")))
}
$start = [ordered]@{ compiler = Get-Sha $compiler; runner = Get-Sha $PSCommandPath; stdlib = Get-StdlibFingerprint }
for ($i = 0; $i -lt $cases.Count; $i++) { $start[$cases[$i].id] = Get-Sha $sources[$i] }
New-Item -ItemType Directory -Path $output -ErrorAction Stop | Out-Null

$results = [ordered]@{}
$passed = 0
for ($i = 0; $i -lt $cases.Count; $i++) {
    $case = $cases[$i]
    $source = $sources[$i]
    $stdout = Join-Path $output "$($case.id).stdout.txt"
    $stderr = Join-Path $output "$($case.id).stderr.txt"
    $process = Start-Process -FilePath $compiler -ArgumentList (@('expression-type-records', $source) + $stdlib) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $sourceText = [IO.File]::ReadAllText($source)
    $records = @()
    foreach ($line in [IO.File]::ReadAllLines($stdout)) {
        if ($line -notmatch '^expression \d+ source 0 ast \d+ kind 15 parent \d+ start (?<start>\d+) type \d+/(?<kind>-?\d+)/(?<origin>-?\d+)/-?\d+/(?<symbol>-?\d+)/') { continue }
        $position = [int]$Matches.start
        if ($position + $case.name.Length -gt $sourceText.Length -or $sourceText.Substring($position, $case.name.Length) -cne $case.name) { continue }
        $records += [ordered]@{ start = $position; kind = [int]$Matches.kind; origin = [int]$Matches.origin; symbol = [int]$Matches.symbol }
    }
    $casePassed = $process.ExitCode -eq 0 -and $records.Count -eq $case.reads
    foreach ($record in $records) { if ($record.kind -ne 7 -or $record.origin -ne 4 -or $record.symbol -ne $case.symbol) { $casePassed = $false } }
    if ($casePassed) { $passed++ }
    $results[$case.id] = [ordered]@{ passed = $casePassed; exitCode = $process.ExitCode; expected = "kind 7 origin 4 symbol $($case.symbol)"; records = $records; stdoutSha256 = Get-Sha $stdout; stderrSha256 = Get-Sha $stderr }
}
$end = [ordered]@{ compiler = Get-Sha $compiler; runner = Get-Sha $PSCommandPath; stdlib = Get-StdlibFingerprint }
for ($i = 0; $i -lt $cases.Count; $i++) { $end[$cases[$i].id] = Get-Sha $sources[$i] }
$stable = (ConvertTo-Json -InputObject $start -Compress) -ceq (ConvertTo-Json -InputObject $end -Compress)
$result = [ordered]@{
    schemaVersion = 1; gate = 'c385-affine-semantic-type-identity'; state = if ($passed -eq $cases.Count -and $stable) { 'passed' } else { 'failed' }
    scope = 'Fixture plus complete current stdlib source closure; each affine producer name read must retain its semantic Stream or EventStream wrapper before Typed IR lowering.'
    compilerSha256 = $start.compiler; inputHashesStart = $start; inputHashesEnd = $end; inputsStable = $stable
    passed = $passed; total = $cases.Count; cases = $results
}
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host "[C385 affine semantic type identity] $passed/$($cases.Count); stable=$stable; $output"
if ($result.state -cne 'passed') { exit 1 }
