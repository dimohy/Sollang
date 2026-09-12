[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$source = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Drop.cs'
$dispatchSource = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs'
$fixture = Join-Path $root 'scripts/contracts/fixtures/source-text-borrowed-drop.cs'
$output = Join-Path $root ('artifacts/scratch/source-text-borrowed-drop-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{schemaVersion=2;status='running';completed=0;total=20;scope='actual-managed-cleanup-helper-and-dispatch-prefix-extraction';checks=@();modes=@()}
function Save-Record { [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n")) }
try {
    $hashes = @{}
    foreach ($path in @($source, $dispatchSource, $fixture, $PSCommandPath)) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    $record.inputHashes = $hashes
    Save-Record
    $candidate = [IO.File]::ReadAllText($source)
    $baseline = (& git -C $root show 'baf9f8cb:src/Sollang.Compiler/CodeGen/LlvmEmitter.Drop.cs') -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Frozen cleanup baseline could not be read' }
    $candidateDispatch = [IO.File]::ReadAllText($dispatchSource)
    $baselineDispatch = (& git -C $root show 'baf9f8cb:src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs') -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Frozen dispatch baseline could not be read' }
    $record.baselineCommit = (& git -C $root rev-parse 'baf9f8cb^{commit}') -join ''
    if ($LASTEXITCODE -ne 0) { throw 'Frozen baseline commit could not be resolved' }
    $record.extraction = [ordered]@{
        production = @('EmitSourceTextUnmap complete method', 'IsCustomOwnedType complete method', 'DropOwnedRuntimeValue exact prefix before switch', 'RuntimeSourceText exact switch case', 'RuntimeSourceText complete record')
        stubs = @('explicit type-table facts', 'materialize/drop call observation', 'non-SourceText runtime shapes', 'synthetic default records other switch dispatch only')
        excluded = @('other drop switch bodies', 'actual aggregate materialization', 'owned-drop helper execution', 'complete compiler/native execution')
    }
    $pattern = '(?ms)^    private void EmitSourceTextUnmap\(string basePointer, string mappedLength\)\r?\n    \{.*?^    \}'
    $classifierPattern = '(?ms)^    private bool IsCustomOwnedType\(BoundType type\)\r?\n    \{.*?^    \}'
    $dispatchPattern = '(?ms)(?<prefix>^    private void DropOwnedRuntimeValue\(RuntimeValue value\)\r?\n    \{.*?)(?=^        switch \(value\))'
    $sourceCasePattern = '(?ms)^            case RuntimeSourceText source:\r?\n.*?^                break;'
    $sourceRecordPattern = '(?ms)^    private sealed record RuntimeSourceText\(.*?^        : RuntimeValue\(BoundType.SourceText\);'
    $logs = @{}
    foreach ($mode in @('baseline', 'candidate')) {
        $body = if ($mode -eq 'baseline') { $baseline } else { $candidate }
        $dispatchBody = if ($mode -eq 'baseline') { $baselineDispatch } else { $candidateDispatch }
        $matches = [regex]::Matches($body, $pattern)
        if ($matches.Count -ne 1) { throw "Expected exactly one actual cleanup declaration: $mode" }
        $classifiers = [regex]::Matches($body, $classifierPattern)
        $dispatches = [regex]::Matches($dispatchBody, $dispatchPattern)
        $sourceCases = [regex]::Matches($dispatchBody, $sourceCasePattern)
        $sourceRecords = [regex]::Matches($dispatchBody, $sourceRecordPattern)
        foreach ($extracted in @(@{name='classifier';count=$classifiers.Count}, @{name='dispatch';count=$dispatches.Count}, @{name='SourceText case';count=$sourceCases.Count}, @{name='SourceText record';count=$sourceRecords.Count})) {
            if ($extracted.count -ne 1) { throw "Expected exactly one actual $($extracted.name): $mode" }
        }
        $folder = Join-Path $output $mode
        [void][IO.Directory]::CreateDirectory($folder)
        $production = "public sealed partial class DropProbe {`n$($matches[0].Value)`n$($classifiers[0].Value)`n$($sourceRecords[0].Value)`n$($dispatches[0].Groups['prefix'].Value)        switch (value)`n        {`n$($sourceCases[0].Value)`n            default: otherSwitchBranches++; break; // Observation only; other actual switch bodies are out of scope.`n        }`n    }`n}`n"
        $productionPath = Join-Path $folder 'Production.cs'
        [IO.File]::WriteAllText($productionPath, $production)
        [IO.File]::WriteAllText((Join-Path $folder 'Probe.csproj'), "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework><Nullable>enable</Nullable><EnableDefaultCompileItems>false</EnableDefaultCompileItems><TreatWarningsAsErrors>true</TreatWarningsAsErrors><UseSharedCompilation>false</UseSharedCompilation></PropertyGroup><ItemGroup><Compile Include=`"$fixture`"/><Compile Include=`"Production.cs`"/></ItemGroup></Project>")
        $actual = (& dotnet run --project (Join-Path $folder 'Probe.csproj') -c Release -- $mode 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $folder 'run.log'), $actual + "`n")
        if ($exitCode -ne 0 -or $actual -notmatch '(?m)^HELPER PASS 7/7$' -or $actual -notmatch '(?m)^DISPATCH PASS 13/13$' -or $actual -notmatch '(?m)^PASS 20/20$') { throw "$mode cleanup/dispatch probe failed: $actual" }
        $logs[$mode] = $actual
        $record.modes += [ordered]@{mode=$mode;completed=20;total=20;helperChecks=7;dispatchChecks=13;exitCode=$exitCode;productionSha256=(Get-FileHash -LiteralPath $productionPath -Algorithm SHA256).Hash;runLog=(Join-Path $folder 'run.log')}
        Save-Record
    }
    $baselineDynamic = @($logs.baseline -split "`n" | Where-Object { $_ -like 'dynamic/*' })
    $candidateDynamic = @($logs.candidate -split "`n" | Where-Object { $_ -like 'dynamic/*' })
    if (($baselineDynamic -join "`n") -cne ($candidateDynamic -join "`n")) { throw 'Dynamic cleanup instruction traces changed' }
    $baselineControls = @($logs.baseline -split "`n" | Where-Object { $_ -like 'dispatch/control/*' })
    $candidateControls = @($logs.candidate -split "`n" | Where-Object { $_ -like 'dispatch/control/*' })
    if ($baselineControls.Count -ne 7 -or ($baselineControls -join "`n") -cne ($candidateControls -join "`n")) { throw 'Non-SourceText dispatch controls changed' }
    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { throw "Cleanup probe input changed: $path" }
    }
    $record.completed = 20
    $record.checks = @('null/zero', 'null/heap-marker', 'null/dynamic-length', 'dynamic/zero', 'dynamic/heap-marker', 'dynamic/dynamic-length', 'nonconstant-name')
    $record.checks += @('dispatch/null/zero', 'dispatch/null/heap-marker', 'dispatch/null/dynamic-length', 'dispatch/dynamic/zero', 'dispatch/dynamic/heap-marker', 'dispatch/dynamic/dynamic-length', 'dispatch/custom-struct', 'dispatch/custom-enum', 'dispatch/custom-box', 'dispatch/static-int', 'dispatch/static-text', 'dispatch/static-inline', 'dispatch/non-owned-scalar')
    if ($record.checks.Count -ne $record.total) { throw 'Cleanup/dispatch check denominator drifted' }
    $record.dynamicInstructionTracesUnchanged = $true
    $record.otherDispatchTracesUnchanged = $true
    $record.inputsStable = $true
    $record.status = 'passed'
} catch { $record.status = 'failed'; $record.failure = $_.Exception.Message; throw }
finally { Save-Record }
Write-Host "[SourceText borrowed drop] PASS 20/20 (helper 7 + dispatch 13; baseline and candidate); $resultPath"
