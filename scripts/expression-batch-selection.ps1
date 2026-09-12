Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

function Get-ExpressionBatchFixtureSelection {
    param(
        [string[]]$Fixture = @(),
        [string]$ManifestPath = '',
        [string]$ManifestSha256 = '',
        [string[]]$DefaultFixture = @()
    )
    if ($Fixture.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($ManifestPath)) {
        throw 'Supply explicit fixtures or a fixture manifest, not both'
    }
    if ($ManifestSha256 -ne '' -and $ManifestPath -eq '') {
        throw 'A fixture manifest hash requires a fixture manifest'
    }
    $selected = @($Fixture)
    if ($ManifestPath -ne '') {
        $manifestText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ManifestPath).Path)
        if ($ManifestSha256 -ne '' -and
            (Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash -cne $ManifestSha256) {
            throw 'Fixture manifest changed after launch'
        }
        $schemaPath = Join-Path $PSScriptRoot 'contracts/expression-batch-selection.schema.json'
        if (-not ($manifestText | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
            throw 'Fixture manifest does not match its schema'
        }
        $selected = @(($manifestText | ConvertFrom-Json).fixtures)
    } elseif ($selected.Count -eq 0) {
        $selected = @($DefaultFixture)
    }
    if ($selected.Count -gt 0) {
        Assert-NativeExactFixturePlan -Fixture $selected
        foreach ($name in $selected) {
            if ($name -cnotmatch '^[0-9]{1,4}-[a-z0-9]+(?:-[a-z0-9]+)*$') {
                throw "Invalid expression batch fixture name: $name"
            }
        }
    }
    return $selected
}
