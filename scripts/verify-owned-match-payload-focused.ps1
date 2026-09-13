[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$contractPath = Join-Path $root 'scripts/contracts/owned-match-payload-focused.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/owned-match-payload-focused.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/owned-match-payload-focused-result.schema.json'
$runnerPath = Join-Path $root 'tests/Sollang.ExampleTests/bin/Release/net11.0/Sollang.ExampleTests.dll'
$runnerSourcePath = Join-Path $root 'tests/Sollang.ExampleTests/Program.cs'
$dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop).Source

function Resolve-InputFile([string]$Path, [string]$Description, [bool]$RequireRepository = $true) {
    $fullPath = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "$Description is missing: $fullPath"
    }
    if ($RequireRepository -and
        -not $fullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description is outside the repository: $fullPath"
    }
    return $fullPath
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-TextSha256([string]$Text) {
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text)))
}

function Invoke-RunnerCapture([string[]]$Arguments) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $dotnetPath
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'C399 ExampleTests runner did not start' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $result = [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdoutTask.GetAwaiter().GetResult()
        Stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Save-Result([object]$Value, [string]$Path) {
    $json = ($Value | ConvertTo-Json -Depth 8) + "`n"
    if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) {
        throw 'C399 focused result does not match its schema'
    }
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

$Compiler = Resolve-InputFile $Compiler 'C399 compiler' $false
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory, $root)
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($OutputDirectory + [IO.Path]::DirectorySeparatorChar).StartsWith($artifactRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "C399 output directory must be under artifacts: $OutputDirectory"
}
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'

foreach ($path in @($contractPath, $contractSchemaPath, $resultSchemaPath, $runnerPath, $runnerSourcePath, $PSCommandPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C399 verifier input is missing: $path" }
}
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath)) { throw 'C399 focused contract does not match its schema' }
$contract = $contractText | ConvertFrom-Json

$casePaths = [ordered]@{}
foreach ($case in $contract.cases) {
    $casePaths["source:$($case.id)"] = Resolve-InputFile ([string]$case.source) "C399 source $($case.id)"
    $casePaths["expected:$($case.id)"] = Resolve-InputFile ([string]$case.expected) "C399 expectation $($case.id)"
}

$inputPaths = [ordered]@{
    compiler = $Compiler
    runner = $runnerPath
    runnerSource = $runnerSourcePath
    dotnet = $dotnetPath
    verifier = $PSCommandPath
    contract = $contractPath
    contractSchema = $contractSchemaPath
    resultSchema = $resultSchemaPath
}
foreach ($entry in $casePaths.GetEnumerator()) { $inputPaths[$entry.Key] = $entry.Value }
$inputHashesStart = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashesStart[$entry.Key] = Get-Sha256 $entry.Value }

$compilerSha256 = $inputHashesStart.compiler
if ($compilerSha256 -cne $ExpectedCompilerSha256) {
    throw "C399 compiler hash mismatch: expected $ExpectedCompilerSha256, actual $compilerSha256"
}

$cases = @($contract.cases | ForEach-Object {
    [ordered]@{
        id = [string]$_.id
        runnerId = [string]$_.runnerId
        kind = [string]$_.kind
        source = [string]$_.source
        sourceSha256 = $inputHashesStart["source:$($_.id)"]
        expected = [string]$_.expected
        expectedSha256 = $inputHashesStart["expected:$($_.id)"]
        status = 'not-run'
        passed = $false
        failureId = $null
    }
})

$runnerSource = [IO.File]::ReadAllText($runnerSourcePath)
$requiredOption = [string]$contract.runnerCapability.option
$sourceOptionDeclared = $runnerSource -match '(?m)^\s*case\s+"--compiler"\s*:'
$missingValueProbe = Invoke-RunnerCapture @($runnerPath, $requiredOption)
$missingValueDiagnostic = "$requiredOption requires a compiler assembly path."
$missingValueMatched = $missingValueProbe.ExitCode -eq 2 -and $missingValueProbe.Stderr.Contains($missingValueDiagnostic, [StringComparison]::Ordinal)
$missingCompilerPath = Join-Path $OutputDirectory ("missing-c399-compiler-$([guid]::NewGuid().ToString('N')).dll")
$missingFileProbe = Invoke-RunnerCapture @($runnerPath, $requiredOption, $missingCompilerPath)
$missingFileDiagnostic = "Compiler path does not exist: $missingCompilerPath"
$missingFileMatched = $missingFileProbe.ExitCode -eq 2 -and $missingFileProbe.Stderr.Contains($missingFileDiagnostic, [StringComparison]::Ordinal)
$runnerSupportsCompilerInjection = $sourceOptionDeclared -and $missingValueMatched -and $missingFileMatched
$record = [ordered]@{
    schemaVersion = 1
    mode = 'owned-match-payload-focused'
    defectId = [string]$contract.defectId
    status = 'failed'
    completed = 0
    total = 6
    compilerSha256 = $compilerSha256
    expectedCompilerSha256 = $ExpectedCompilerSha256
    runnerSupportsCompilerInjection = $runnerSupportsCompilerInjection
    requiredRunnerOption = $requiredOption
    runnerCapabilityChecks = [ordered]@{
        sourceOptionDeclared = $sourceOptionDeclared
        missingValue = [ordered]@{
            exitCode = $missingValueProbe.ExitCode
            stdoutSha256 = Get-TextSha256 $missingValueProbe.Stdout
            stderrSha256 = Get-TextSha256 $missingValueProbe.Stderr
            diagnosticMatched = $missingValueMatched
        }
        missingFile = [ordered]@{
            exitCode = $missingFileProbe.ExitCode
            stdoutSha256 = Get-TextSha256 $missingFileProbe.Stdout
            stderrSha256 = Get-TextSha256 $missingFileProbe.Stderr
            diagnosticMatched = $missingFileMatched
        }
    }
    runnerExitCode = $null
    runnerStdoutSha256 = $null
    runnerStderrSha256 = $null
    inputStable = $false
    inputDrift = @()
    inputHashesStart = $inputHashesStart
    inputHashesEnd = [ordered]@{}
    toolHashes = [ordered]@{ dotnet = $inputHashesStart.dotnet; runner = $inputHashesStart.runner; verifier = $inputHashesStart.verifier }
    sourceHashes = [ordered]@{ runnerSource = $inputHashesStart.runnerSource; contract = $inputHashesStart.contract }
    cases = $cases
    failureIds = @()
}
$failure = $null

try {
    if (-not $runnerSupportsCompilerInjection) {
        $failureId = [string]$contract.runnerCapability.missingCapabilityFailureId
        $record.status = 'blocked'
        $record.failureIds = @($failureId)
        foreach ($case in $record.cases) { $case.failureId = $failureId }
        throw "ExampleTests runner cannot execute C399 under the requested compiler because it has no '$requiredOption <path>' option"
    }

    $arguments = @($runnerPath, '--suite', 'reference', '--target', 'windows-x64', '--skip-bootstrap', '--jobs', '6', $requiredOption, $Compiler)
    foreach ($case in $contract.cases) { $arguments += @('--exact', [string]$case.runnerId) }
    $run = Invoke-RunnerCapture $arguments
    $stdout = $run.Stdout
    $stderr = $run.Stderr
    $record.runnerExitCode = $run.ExitCode
    $record.runnerStdoutSha256 = Get-TextSha256 $stdout
    $record.runnerStderrSha256 = Get-TextSha256 $stderr
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'runner.stdout.log'), $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'runner.stderr.log'), $stderr, [Text.UTF8Encoding]::new($false))

    foreach ($case in $record.cases) {
        $matched = $stdout -match ('(?m)^\[\d+/6\]\s+PASS\s+' + [regex]::Escape($case.runnerId) + '\s+\(')
        $case.passed = $matched
        $case.status = if ($matched) { 'passed' } else { 'failed' }
        if ($matched) { $record.completed++ } else { $case.failureId = $case.id; $record.failureIds += $case.id }
    }
    if ($record.runnerExitCode -ne 0 -and $record.failureIds.Count -eq 0) { $record.failureIds += 'RUNNER_EXIT_NONZERO' }
} catch {
    if ($record.status -ne 'blocked' -and $record.failureIds.Count -eq 0) { $record.failureIds = @('VERIFIER_EXCEPTION') }
    $failure = $_
} finally {
    foreach ($entry in $inputPaths.GetEnumerator()) {
        $record.inputHashesEnd[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) { Get-Sha256 $entry.Value } else { $null }
        if ($record.inputHashesEnd[$entry.Key] -cne $inputHashesStart[$entry.Key]) { $record.inputDrift += $entry.Key }
    }
    $record.inputDrift = @($record.inputDrift | Sort-Object -Unique)
    $record.inputStable = $record.inputDrift.Count -eq 0
    if (-not $record.inputStable) {
        $record.status = 'failed'
        if ($record.failureIds -notcontains 'INPUT_DRIFT') { $record.failureIds += 'INPUT_DRIFT' }
    } elseif ($record.status -ne 'blocked') {
        $record.status = if ($record.completed -eq 6 -and $record.runnerExitCode -eq 0 -and $record.failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    }
    Save-Result $record $resultPath
    Write-Host "[C399 focused] $($record.status) $($record.completed)/$($record.total); result=$resultPath"
}

if ($record.status -ne 'passed') {
    if ($null -ne $failure) { throw $failure }
    throw "C399 focused failed $($record.completed)/$($record.total): $($record.failureIds -join ', ')"
}
