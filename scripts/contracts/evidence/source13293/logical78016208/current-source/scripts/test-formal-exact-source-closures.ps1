[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) ('sollang-formal-closure-' + [guid]::NewGuid().ToString('N')))
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Formal closure control output already exists' }
$null = New-Item -ItemType Directory -Path $OutputDirectory
$fixtureRoot = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) 'repository'
function Write-ControlSource([string]$Relative, [string]$Text) {
    $destination = Join-Path $fixtureRoot $Relative
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination)
    [IO.File]::WriteAllText($destination, $Text, [Text.UTF8Encoding]::new($false))
}
$stageText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'verify-selfhost-stage2.ps1')) + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'verify-selfhost-stage3.ps1'))
$names = @([regex]::Matches($stageText, '--exact\s+(?<name>[a-zA-Z0-9_/-]+)') | ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
if ($names.Count -eq 0) { throw 'Formal Stage fixture inventory is empty' }
foreach ($name in $names) {
    $relative = if ($name.StartsWith('diagnostic/')) { 'examples/regression/diagnostics/' + $name.Substring(11) + '.slg' } else { 'examples/regression/' + $name + '.slg' }
    Write-ControlSource $relative "main {} `n"
}
$selected = @($names | Where-Object { -not $_.StartsWith('diagnostic/') })[0]
$main = "examples/regression/$selected.slg"
$manifest = "examples/regression/expected/$selected.sources.txt"
$provider = 'selfhost/test_provider.slg'
$leaf = 'selfhost/test_leaf.slg'
$prefix = "$main`n$provider`n"
Write-ControlSource $main "import sollang.compiler.test_provider`nmain {} `n"
Write-ControlSource $provider "namespace sollang.compiler.test_provider`nimport std.algorithm`n"
Write-ControlSource $leaf "namespace sollang.compiler.test_leaf`n"
Write-ControlSource 'stdlib/std/algorithm.slg' "namespace std.algorithm`n"
Write-ControlSource $manifest $prefix
Write-ControlSource 'tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt' "$provider`n$leaf`n"
$verifier = Join-Path $PSScriptRoot 'verify-formal-exact-source-closures.ps1'
$failures = [Collections.Generic.List[string]]::new()
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $message = ''
    try { & $Action *> $null } catch { $message = $_.Exception.Message }
    if ($message -notmatch $Pattern) { throw "Expected formal closure rejection '$Pattern', observed '$message'" }
    $failures.Add($message)
}
# Full stdlib injection resolves a dependency absent from bootstrap projections.
& $verifier -RepositoryRoot $fixtureRoot
if (-not $?) { throw 'Full standard library positive control failed' }
$completed = 1
Write-ControlSource 'stdlib/std/algorithm.slg' "namespace std.absent`n"
Expect-Failure { & $verifier -RepositoryRoot $fixtureRoot } 'std\.algorithm'
Write-ControlSource 'stdlib/std/algorithm.slg' "namespace std.algorithm`n"
$completed++
# Refresh appends only compiler dependencies and preserves the existing prefix.
Write-ControlSource $provider "namespace sollang.compiler.test_provider`nimport std.algorithm`nimport sollang.compiler.test_leaf`n"
& $verifier -RepositoryRoot $fixtureRoot -RefreshManifestClosure
if (-not $?) { throw 'Compiler dependency refresh positive control failed' }
$actual = [IO.File]::ReadAllText((Join-Path $fixtureRoot $manifest))
if (-not $actual.StartsWith($prefix, [StringComparison]::Ordinal) -or $actual -cne ($prefix + "$leaf`n")) { throw 'Refresh changed the prefix or appended an implicit stdlib source' }
& $verifier -RepositoryRoot $fixtureRoot
if (-not $?) { throw 'Refreshed closure failed readonly verification' }
$completed++
Write-ControlSource $manifest "$provider`n$main`n$leaf`n"
Expect-Failure { & $verifier -RepositoryRoot $fixtureRoot } 'must start with'
$completed++
$result = @{ schemaVersion = 1; status = 'passed'; completed = $completed; total = 4; fixtureRoot = $fixtureRoot; expectedRejections = @($failures) }
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'result.json') -Encoding utf8NoBOM
$result | ConvertTo-Json -Depth 4
