[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $root ('artifacts/scratch/linux-ownership-storage-focused-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$logPath = Join-Path $output 'run.log'
$resultPath = Join-Path $output 'result.json'
$cases = @(
    [ordered]@{
        id = '1723-owned-match-payload-mutable-binding'
        source = 'examples/regression/1723-owned-match-payload-mutable-binding.slg'
        golden = 'examples/regression/expected/1723-owned-match-payload-mutable-binding.stdout.txt'
    },
    [ordered]@{
        id = '1725-materialized-text-storage-boundaries'
        source = 'examples/regression/1725-materialized-text-storage-boundaries.slg'
        golden = 'examples/regression/expected/1725-materialized-text-storage-boundaries.stdout.txt'
    }
)
$inputs = @('src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll')
$inputs += @($cases | ForEach-Object { $_.source; $_.golden })
$hashes = [ordered]@{}
foreach ($relativePath in $inputs) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Linux ownership/storage input is missing: $relativePath"
    }
    $hashes[$relativePath] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$record = [ordered]@{
    schemaVersion = 1
    scope = 'linux-x64-owned-match-and-materialized-text-storage-exact'
    status = 'running'
    completed = 0
    total = $cases.Count
    target = 'linux-x64'
    integration = 'managed host only; selfhost and Stage2/Stage3 not executed'
    inputHashes = $hashes
    goldenLineCounts = [ordered]@{
        ownedMatch = @(Get-Content -LiteralPath (Join-Path $root $cases[0].golden)).Count
        materializedTextStorage = @(Get-Content -LiteralPath (Join-Path $root $cases[1].golden)).Count
    }
    log = [IO.Path]::GetRelativePath($root, $logPath).Replace('\', '/')
}
try {
    $arguments = @(
        'run', '--project', (Join-Path $root 'tests/Sollang.ExampleTests'),
        '--no-build', '-c', 'Release', '--'
    )
    foreach ($case in $cases) {
        $arguments += @('--exact', $case.id)
    }
    $arguments += @('--target', 'linux-x64', '--skip-bootstrap', '--jobs', '1')
    $actual = (& dotnet @arguments 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText($logPath, $actual + "`n")
    $record.exitCode = $exitCode
    $record.output = $actual
    foreach ($case in $cases) {
        if ($actual -match "(?m)^\[[12]/2\] PASS $([regex]::Escape($case.id)) ") {
            $record.completed++
        }
    }
    if ($exitCode -ne 0 -or $record.completed -ne $record.total -or
        -not $actual.Contains('All 2 example tests passed.', [StringComparison]::Ordinal)) {
        throw "Linux ownership/storage exact fixtures failed: $($record.completed)/$($record.total), exit $exitCode"
    }
    foreach ($relativePath in $inputs) {
        $current = (Get-FileHash -LiteralPath (Join-Path $root $relativePath) -Algorithm SHA256).Hash
        if ($current -cne $hashes[$relativePath]) {
            throw "Linux ownership/storage input changed during execution: $relativePath"
        }
    }
    $record.inputsStable = $true
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"))
    Write-Host "[Linux ownership/storage focused] $($record.status) $($record.completed)/$($record.total); $resultPath"
}
