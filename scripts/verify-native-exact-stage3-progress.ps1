[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$reader = Join-Path $PSScriptRoot 'read-native-exact-stage3-progress.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("sollang-native-stage3-progress-" + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
try {
    $pending = (& $reader -OutputDirectory $scratch -ExpectedPerGeneration 2 | ConvertFrom-Json)
    if ($pending.completed -ne 0 -or $pending.total -ne 4 -or $pending.percent -ne 0) { throw 'pending progress is incorrect' }

    $stage2 = [ordered]@{ schemaVersion=1; label='stage2'; platform='windows'; state='running'; completed=1; passed=1; failed=0; missing=1; total=2; results=@([ordered]@{Fixture='a';Success=$true;Error=''}) }
    [IO.File]::WriteAllText((Join-Path $scratch 'stage2-batch-results.json'), ($stage2|ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
    $running = (& $reader -OutputDirectory $scratch -ExpectedPerGeneration 2 | ConvertFrom-Json)
    if ($running.completed -ne 1 -or $running.total -ne 4 -or $running.percent -ne 25) { throw 'running progress is incorrect' }

    $stage2.completed = 2; $stage2.passed = 2; $stage2.missing = 0; $stage2.state = 'passed'; $stage2.results = @([ordered]@{Fixture='a';Success=$true;Error=''},[ordered]@{Fixture='b';Success=$true;Error=''})
    $stage3 = ($stage2 | ConvertTo-Json -Depth 4 | ConvertFrom-Json); $stage3.label = 'stage3'
    [IO.File]::WriteAllText((Join-Path $scratch 'stage2-batch-results.json'), ($stage2|ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $scratch 'stage3-batch-results.json'), ($stage3|ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
    $complete = (& $reader -OutputDirectory $scratch -ExpectedPerGeneration 2 | ConvertFrom-Json)
    if ($complete.completed -ne 4 -or $complete.percent -ne 100 -or $complete.failed -ne 0) { throw 'complete progress is incorrect' }
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host '[native exact Stage3 progress contract] PASS pending, running, and complete states.'
