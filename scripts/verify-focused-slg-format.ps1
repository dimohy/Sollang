[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $root ('artifacts/scratch/focused-slg-format-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$trace = Join-Path $output 'invocations.jsonl'
$resultPath = Join-Path $output 'result.json'
$formatter = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$probe = Join-Path $root 'scripts/contracts/fixtures/format-authoritative-probe.ps1'
$priorTrace = $env:SOLLANG_FOCUSED_FORMAT_PROBE
$result = [ordered]@{ schemaVersion = 1; scope = 'formatter-dispatch-contract-not-source-formatting'; status = 'running'; completed = 0; total = 8; checks = @() }
function Assert-Check([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "focused formatter assertion failed: $Name" }
    $result.completed++
    $result.checks += $Name
}
function Assert-Rejected([string]$Name, [string[]]$Source, [string]$Expected) {
    $before = (Get-Content -LiteralPath $trace).Count
    $rejected = $false
    try { & $formatter -Check -Compiler $probe -Source $Source }
    catch {
        if (-not $_.Exception.Message.Contains($Expected, [StringComparison]::Ordinal)) { throw }
        $rejected = $true
    }
    Assert-Check $Name ($rejected -and (Get-Content -LiteralPath $trace).Count -eq $before)
}
try {
    $env:SOLLANG_FOCUSED_FORMAT_PROBE = $trace
    $source = 'stdlib/std/time.slg'
    $fixture = 'examples/regression/1711-time-rfc3339-calendar-format.slg'
    & $formatter -Check -Compiler $probe -Source @($source, $fixture, $source)
    $calls = @(Get-Content -LiteralPath $trace | ForEach-Object { ,($_ | ConvertFrom-Json) })
    $expected = @((Join-Path $root $source), (Join-Path $root $fixture)) | Sort-Object
    Assert-Check 'focused-deduplicated-selection' ($calls.Count -eq 1 -and $calls[0].Count -eq 4 -and ($calls[0][2..3] -join '|') -ceq ($expected -join '|'))
    Assert-Check 'check-flag-preserved' ($calls[0][0] -ceq 'format' -and $calls[0][1] -ceq '--check')
    & $formatter -Compiler $probe -Source @($source)
    $writeCall = Get-Content -LiteralPath $trace | Select-Object -Last 1 | ConvertFrom-Json
    Assert-Check 'write-mode-preserved' ($writeCall.Count -eq 2 -and $writeCall[0] -ceq 'format' -and $writeCall[1] -ceq (Join-Path $root $source))
    Assert-Rejected 'outside-source-scope-before-invocation' @('artifacts/scratch/not-authoritative.slg') 'outside the permitted SLG roots'
    Assert-Rejected 'wrong-extension-before-invocation' @('stdlib/std/time.txt') 'outside the permitted SLG roots'
    Assert-Rejected 'missing-source-before-invocation' @('stdlib/std/does-not-exist-focused-format.slg') 'focused format source is missing'
    Assert-Rejected 'empty-selection-before-invocation' @() 'focused format requires at least one explicit source'
    $before = @(Get-Content -LiteralPath $trace).Count
    & $formatter -Check -Compiler $probe
    $defaultCalls = @(Get-Content -LiteralPath $trace | Select-Object -Skip $before | ForEach-Object { ,($_ | ConvertFrom-Json) })
    $actualInventory = @($defaultCalls | ForEach-Object { $_ | Select-Object -Skip 2 })
    $defaultInventory = @('selfhost', 'stdlib', 'syntax/generated' | ForEach-Object {
        Get-ChildItem -LiteralPath (Join-Path $root $_) -Recurse -File -Filter '*.slg'
    } | Sort-Object -Property FullName -Unique | ForEach-Object FullName)
    Assert-Check 'default-inventory-preserved' (($actualInventory -join '|') -ceq ($defaultInventory -join '|'))
    $result.defaultSourceCount = $defaultInventory.Count
    $result.formatterSha256 = (Get-FileHash -LiteralPath $formatter -Algorithm SHA256).Hash
    $result.status = 'passed'
} catch {
    $result.status = 'failed'
    $result.failure = $_.Exception.Message
    throw
} finally {
    $env:SOLLANG_FOCUSED_FORMAT_PROBE = $priorTrace
    [IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 4) + "`n"))
}
Write-Host "[focused formatter dispatch] PASS $($result.completed)/$($result.total); $resultPath"
