param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateRange(1, 16)]
    [int]$Jobs = 3
)

$ErrorActionPreference = "Stop"
$contractPath = Join-Path $RepositoryRoot "scripts\contracts\quic-stream-api.json"
$runnerProject = Join-Path $RepositoryRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -Depth 20
$fixtures = @($contract.frameExhaustiveConsumerFixtures)
if ($fixtures.Count -eq 0) {
    throw "QUIC frame exhaustive-consumer fixture contract is empty"
}

$arguments = @(
    "run",
    "--project", $runnerProject,
    "-c", "Release",
    "--no-build",
    "--",
    "--skip-bootstrap"
)
foreach ($fixture in $fixtures) {
    $fixturePath = Join-Path $RepositoryRoot "examples\regression\$fixture.slg"
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
        throw "QUIC frame exhaustive-consumer fixture is missing: $fixturePath"
    }
    $arguments += @("--exact", $fixture)
}
$arguments += @("--jobs", [string][Math]::Min($Jobs, $fixtures.Count))

& dotnet @arguments
if ($LASTEXITCODE -ne 0) {
    throw "QUIC frame exhaustive-consumer preflight failed"
}
Write-Host "[QUIC frame consumers] PASS $($fixtures.Count) exhaustive frame.Value consumers before compiler emission."
