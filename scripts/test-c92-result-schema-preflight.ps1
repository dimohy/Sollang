param(
    [Parameter(Mandatory)][string]$PrototypeRecord,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$ExecutionRecord = ''
)
$ErrorActionPreference = 'Stop'
$producer = Join-Path $PSScriptRoot 'verify-additional-move-ownership.ps1'
$schemaPath = Join-Path $PSScriptRoot 'contracts/additional-move-ownership-result.schema.json'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($producer, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'C92_PRODUCER_PARSE_FAILED' }
foreach ($name in @('New-C92CaseRecord', 'New-C92ResultRecord')) {
    $definitions = @($ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true))
    if ($definitions.Count -ne 1) { throw "C92_FACTORY_NOT_UNIQUE: $name" }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
}
$prototype = Get-Content -LiteralPath $PrototypeRecord -Raw | ConvertFrom-Json -AsHashtable
$rows = @(foreach ($row in $prototype.cases) {
    $metadata = [ordered]@{ id = $row.id; kind = if ($row.expectedCompileExit -eq 1) { 'negative' } else { 'positive' } }
    if ($null -ne $row.expectedAllocationCount) { $metadata.auditAllocations = $row.expectedAllocationCount }
    [pscustomobject](New-C92CaseRecord -Case $metadata -AuditContract @{auditRuns = $row.auditRunCount} -SeedSha256 $prototype.deterministicSeedSha256)
})
$record = New-C92ResultRecord -Results $rows -Failures @('C92_RESULT_SCHEMA_PREFLIGHT') -Drift @() -Hashes $prototype.inputHashes -GeneratedHashes ([ordered]@{}) -ExpectedCompilerSha256 $prototype.expectedCompilerSha256 -SeedSha256 $prototype.deterministicSeedSha256
$schema = Get-Content -LiteralPath $schemaPath -Raw
$legacySchema = $schema | ConvertFrom-Json -AsHashtable
[void]$legacySchema.'$defs'.base.properties.Remove('status')
$unknownProperty = $record | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
$unknownProperty.cases[0].forbiddenUnknownProperty = $true
$invalidTerminalState = $record | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
$invalidTerminalState.cases[0].status = 'running'
$controls = @(
    @{ id = 'actual-factories-current-schema'; value = $record; schema = $schema; expected = $true },
    @{ id = 'previous-missing-status-schema'; value = $record; schema = ($legacySchema | ConvertTo-Json -Depth 50); expected = $false },
    @{ id = 'unknown-property-rejected'; value = $unknownProperty; schema = $schema; expected = $false },
    @{ id = 'unfinished-case-rejected'; value = $invalidTerminalState; schema = $schema; expected = $false }
)
if (-not [string]::IsNullOrWhiteSpace($ExecutionRecord)) {
    $processRecord = Get-Content -LiteralPath $ExecutionRecord -Raw | ConvertFrom-Json -AsHashtable
    $processSchema = ($schema | ConvertFrom-Json -AsHashtable).properties.processes.items | ConvertTo-Json -Depth 20
    $missingExit = $processRecord | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    [void]$missingExit.Remove('exit')
    $missingProcesses = $prototype | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    [void]$missingProcesses.Remove('processes')
    $controls += @(
        @{ id = 'actual-execution-record-schema'; value = $processRecord; schema = $processSchema; expected = $true },
        @{ id = 'missing-exit-rejected'; value = $missingExit; schema = $processSchema; expected = $false },
        @{ id = 'previous-success-without-process-records-rejected'; value = $missingProcesses; schema = $schema; expected = $false }
    )
}
$results = @(foreach ($control in $controls) {
    $actual = $false
    try { $actual = [bool](($control.value | ConvertTo-Json -Depth 20) | Test-Json -Schema $control.schema -ErrorAction Stop) } catch { $actual = $false }
    [ordered]@{ id = $control.id; expectedValid = $control.expected; actualValid = $actual; passed = $actual -eq $control.expected }
})
$completed = @($results | Where-Object passed).Count
[void][IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory))
$result = [ordered]@{
    schemaVersion = 1; status = if ($completed -eq $controls.Count) { 'passed' } else { 'failed' }
    completed = $completed; total = $controls.Count; scope = 'actual-producer-factories-and-result-schema-before-native-cost'
    producerSha256 = (Get-FileHash -LiteralPath $producer -Algorithm SHA256).Hash
    schemaSha256 = (Get-FileHash -LiteralPath $schemaPath -Algorithm SHA256).Hash
    prototypeSha256 = (Get-FileHash -LiteralPath $PrototypeRecord -Algorithm SHA256).Hash
    cases = $results
}
[IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) 'result.json'), ($result | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($result.status -ne 'passed') { throw 'C92_SCHEMA_PREFLIGHT_CONTROLS_FAILED' }
Write-Output "C92 schema preflight controls: $completed/$($controls.Count) passed"
