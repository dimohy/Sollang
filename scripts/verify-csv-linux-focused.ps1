[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $root ('artifacts/scratch/csv-linux-focused-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$logPath = Join-Path $output 'run.log'
$resultPath = Join-Path $output 'result.json'
$inputs = @(
    'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll',
    'stdlib/std/text/csv.slg',
    'examples/regression/1721-csv-bounded-reader.slg',
    'examples/regression/expected/1721-csv-bounded-reader.stdout.txt',
    'examples/regression/1724-csv-bounded-writer.slg',
    'examples/regression/expected/1724-csv-bounded-writer.stdout.txt'
)
$hashes = [ordered]@{}
foreach ($relativePath in $inputs) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "CSV Linux focused input is missing: $relativePath"
    }
    $hashes[$relativePath] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$record = [ordered]@{
    schemaVersion = 1
    scope = 'linux-x64-csv-reader-writer-exact'
    status = 'running'
    completed = 0
    total = 2
    target = 'linux-x64'
    integration = 'managed host only; selfhost and Stage2/Stage3 not executed'
    inputHashes = $hashes
    goldenLineCounts = [ordered]@{
        reader = @(Get-Content -LiteralPath (Join-Path $root $inputs[3])).Count
        writer = @(Get-Content -LiteralPath (Join-Path $root $inputs[5])).Count
    }
    log = [IO.Path]::GetRelativePath($root, $logPath).Replace('\', '/')
}
try {
    $actual = (& dotnet run --project (Join-Path $root 'tests/Sollang.ExampleTests') `
        --no-build -c Release -- `
        --exact 1721-csv-bounded-reader `
        --exact 1724-csv-bounded-writer `
        --target linux-x64 `
        --skip-bootstrap `
        --jobs 1 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText($logPath, $actual + "`n")
    $record.exitCode = $exitCode
    $record.output = $actual
    foreach ($id in @('1721-csv-bounded-reader', '1724-csv-bounded-writer')) {
        if ($actual -match "(?m)^\[[12]/2\] PASS $([regex]::Escape($id)) ") {
            $record.completed++
        }
    }
    if ($exitCode -ne 0 -or $record.completed -ne $record.total -or
        -not $actual.Contains('All 2 example tests passed.', [StringComparison]::Ordinal)) {
        throw "Linux CSV exact fixtures failed: $($record.completed)/$($record.total), exit $exitCode"
    }
    foreach ($relativePath in $inputs) {
        $current = (Get-FileHash -LiteralPath (Join-Path $root $relativePath) -Algorithm SHA256).Hash
        if ($current -cne $hashes[$relativePath]) {
            throw "CSV Linux focused input changed during execution: $relativePath"
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
    Write-Host "[CSV Linux focused] $($record.status) $($record.completed)/$($record.total); $resultPath"
}
