[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $root ('artifacts/scratch/1708-map-layout-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$typePath = Join-Path $root 'selfhost/semantic/type_ids.slg'
$layoutPath = Join-Path $root 'selfhost/llvm/text/foundation.slg'
$testPath = Join-Path $PSScriptRoot 'contracts/fixtures/1708-map-layout-traits.slg'
$typeSource = [IO.File]::ReadAllText($typePath)
$layoutSource = [IO.File]::ReadAllText($layoutPath)

function Select-Declaration([string]$Source, [string]$Name) {
    # Canonical SLG puts each declaration's closing brace in column zero.
    # Select the real body; no algorithm is duplicated in the probe.
    $matches = [regex]::Matches($Source, '(?ms)^public (?:struct )?' + [regex]::Escape($Name) + '\b.*?^}')
    if ($matches.Count -ne 1) { throw "Expected one production declaration: $Name" }
    return $matches[0].Value.Replace('typeIds.SemanticType', 'SemanticType').Replace('typeIds.NominalField', 'NominalField')
}
$declarations = @(
    Select-Declaration $typeSource 'SemanticType'
    Select-Declaration $typeSource 'NominalField'
    Select-Declaration $typeSource 'PayloadEdge'
    Select-Declaration $layoutSource 'TypeLayoutRequest'
    Select-Declaration $layoutSource 'TypeLayouts'
    Select-Declaration $typeSource 'classifyWithResources'
    Select-Declaration $layoutSource 'layoutsFor'
)
$source = Join-Path $output 'probe.slg'
$executable = Join-Path $output 'probe.exe'
[IO.File]::WriteAllText($source, ($declarations -join "`n`n") + "`n`n" + [IO.File]::ReadAllText($testPath))
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$build = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compiler, 'build', $source, '-o', $executable, '--keep-temps') -Description 'isolated mapped layout and traits' -TimeoutMilliseconds 30000
[IO.File]::WriteAllText((Join-Path $output 'build.log'), $build.Stdout + $build.Stderr)
if ($build.ExitCode -ne 0 -or $build.Stderr -match '\S') { throw "Map layout probe compilation failed: $($build.Stdout)$($build.Stderr)" }
$run = Invoke-VerificationProcessCapture -FilePath $executable -ArgumentList @() -Description 'mapped layout and trait assertions' -TimeoutMilliseconds 10000
$expected = "traits=5,5,0,5,0`nread=40/8/0`nwrite=40/8/0`nfixed=80/8/0`nempty=0/0"
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
[IO.File]::WriteAllText((Join-Path $output 'actual.txt'), $run.Stdout)
$passed = $run.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($run.Stderr) -and $actual -ceq $expected
$record = [ordered]@{
    status = $(if ($passed) { 'passed' } else { 'failed' })
    exitCode = $run.ExitCode
    checks = 5
    authority = @($typePath, $layoutPath)
    extractedSourceSha256 = (Get-FileHash $source -Algorithm SHA256).Hash
    fixtureSha256 = (Get-FileHash $testPath -Algorithm SHA256).Hash
    outputSha256 = (Get-FileHash (Join-Path $output 'actual.txt') -Algorithm SHA256).Hash
    evidenceScope = 'extracted-production-functions-not-rebuilt-selfhost'
}
$record | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $output 'result.json') -Encoding utf8
if (-not $passed) { throw "Map layout/trait mismatch: $actual; $($run.Stderr); evidence $output" }
Write-Host "[mapped layout traits] PASS 5/5 isolated production assertions; $output/result.json"
