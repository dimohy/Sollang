[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$path = Join-Path $RepositoryRoot 'scripts/verify-interpolation-semantic-parity.ps1'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Interpolation verifier parse failure.' }
$functions = @($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Invoke-InterpolationVerificationSource'}, $true))
if ($functions.Count -ne 1) { throw 'Expected one production verification-source invocation.' }
. ([scriptblock]::Create($functions[0].Extent.Text))
$relative = 'scripts/verify-utf8-each-runtime.ps1'
$expected = (Get-FileHash -LiteralPath (Join-Path $RepositoryRoot $relative) -Algorithm SHA256).Hash
$actual = Invoke-InterpolationVerificationSource -Root $RepositoryRoot -RelativePath $relative
if ($actual -cne $expected) { throw 'Current UTF8 verifier did not execute with stable identity.' }
$output = Join-Path $RepositoryRoot ('artifacts/scratch/interpolation-verification-source-controls-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $output 'scripts') | Out-Null
$fixture = Join-Path $output $relative
$cases = @(
    @{ Name = 'unknown-script'; Relative = 'scripts/unknown.ps1'; Source = "throw 'must not run'"; Error = 'Unsupported interpolation verification script' },
    @{ Name = 'failed-script'; Relative = $relative; Source = "param([string]`$RepositoryRoot)`nthrow 'EXPECTED_VERIFICATION_SOURCE_FAILURE'"; Error = 'EXPECTED_VERIFICATION_SOURCE_FAILURE' },
    @{ Name = 'changed-script'; Relative = $relative; Source = "param([string]`$RepositoryRoot)`n[IO.File]::WriteAllText(`$PSCommandPath, 'changed')"; Error = 'changed during execution' }
)
foreach ($case in $cases) {
    [IO.File]::WriteAllText($fixture, $case.Source)
    $failure = $null
    try { Invoke-InterpolationVerificationSource -Root $output -RelativePath $case.Relative | Out-Null } catch { $failure = $_.Exception.Message }
    if (-not $failure -or -not $failure.Contains($case.Error, [StringComparison]::Ordinal)) { throw "Verification-source negative control failed: $($case.Name): $failure" }
}
Write-Host '[interpolation verification sources] PASS 4/4: current execution, unknown script, failed execution and changing identity.'
