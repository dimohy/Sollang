[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [ValidateSet('selfhost', 'managed')][string]$CompilerInterface = 'selfhost',
    [string]$Label = 'selfhost',
    [ValidateSet('windows', 'linux')][string]$Target = 'windows',
    [string]$StandardLibrary = '',
    [string]$Distribution = '',
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ContractPath = 'scripts/contracts/trait-ownership-diagnostics.json',
    [string[]]$Fixture = @(),
    [string]$ResultPath = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$stdlibPath = ''
$stdlibSources = @()
if (-not [string]::IsNullOrWhiteSpace($StandardLibrary)) {
    if (-not (Test-Path -LiteralPath $StandardLibrary -PathType Container)) {
        throw 'DIAGNOSTIC_STDLIB_SOURCE_ROOT_INVALID'
    }
    $stdlibPath = (Resolve-Path -LiteralPath $StandardLibrary).Path
    if (-not (Test-Path -LiteralPath $stdlibPath -PathType Container)) {
        throw 'Diagnostic standard-library source root must contain SLG sources'
    }
    $stdlibSources = @(Get-ChildItem -LiteralPath $stdlibPath -Recurse -File -Filter '*.slg' | Sort-Object FullName | Select-Object -ExpandProperty FullName)
    if ($stdlibSources.Count -eq 0) { throw 'Diagnostic standard-library source root must contain SLG sources' }
}
if (-not [string]::IsNullOrWhiteSpace($Distribution) -and $Target -ne 'linux') {
    throw 'WSL trait/ownership diagnostics require target linux'
}
if ($CompilerInterface -ceq 'managed' -and -not [string]::IsNullOrWhiteSpace($Distribution)) {
    throw 'Managed trait/ownership diagnostics do not support WSL distribution mode'
}
function Convert-ToTraitDiagnosticWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}
$contractFile = [IO.Path]::GetFullPath($ContractPath, $repoRoot)
if (-not $contractFile.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath $contractFile -PathType Leaf)) { throw "Invalid diagnostic contract path: $ContractPath" }
$contract = Get-Content -LiteralPath $contractFile -Raw | ConvertFrom-Json
if ($contract.PSObject.Properties['sourceMode']) {
    $actualSourceMode = if ($stdlibPath) { 'standard-library' } else { 'raw' }
    if ($contract.sourceMode -cne $actualSourceMode) { throw 'DIAGNOSTIC_SOURCE_MODE_MISMATCH' }
}
if ($contract.schemaVersion -ne 1 -or $contract.cases.Count -eq 0) { throw 'Invalid trait/ownership diagnostic contract' }
$ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($case in $contract.cases) {
    if (-not $ids.Add($case.id) -or $case.expectedExit -ne 1 -or $case.outputContains.Count -eq 0) { throw "Invalid diagnostic case: $($case.id)" }
    if ($case.PSObject.Properties['timeoutMilliseconds'] -and $case.timeoutMilliseconds -le 0) { throw "Invalid diagnostic timeout: $($case.id)" }
    if ($case.PSObject.Properties['dependencySources']) {
        foreach ($dependency in $case.dependencySources) {
            $dependencyPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $dependency))
            if (-not $dependencyPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) { throw "Invalid diagnostic dependency: $dependency" }
        }
    }
    $source = [IO.Path]::GetFullPath((Join-Path $repoRoot $case.source))
    if (-not $source.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Invalid diagnostic source: $($case.source)" }
}
if ($Fixture.Count -gt 0) {
    $requested = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($id in $Fixture) {
        if (-not $requested.Add($id)) { throw "Duplicate diagnostic selection: $id" }
        if (-not $ids.Contains($id)) { throw "Unknown diagnostic selection: $id" }
    }
    $contract.cases = @($contract.cases | Where-Object { $requested.Contains($_.id) })
}
$receiptPath = ''
if (-not [string]::IsNullOrWhiteSpace($ResultPath)) {
    $receiptPath = [IO.Path]::GetFullPath($ResultPath, $repoRoot)
    if (Test-Path -LiteralPath $receiptPath) { throw "Diagnostic result already exists: $receiptPath" }
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $receiptPath) -PathType Container)) {
        throw "Diagnostic result parent is missing: $receiptPath"
    }
}
$inputs = [ordered]@{}
foreach ($path in @($compilerPath, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'),
    $contractFile) + $stdlibSources +
    @($contract.cases | ForEach-Object {
        Join-Path $repoRoot $_.source
        if ($_.PSObject.Properties['dependencySources']) {
            foreach ($dependency in $_.dependencySources) { Join-Path $repoRoot $dependency }
        }
    })) {
    $inputs[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerHash = (Get-FileHash -LiteralPath $compilerPath).Hash
$failures = [Collections.Generic.List[string]]::new()
$caseRows = [Collections.Generic.List[object]]::new()
$passed = 0
foreach ($case in $contract.cases) {
    $sourcePaths = [Collections.Generic.List[string]]::new()
    if ($case.PSObject.Properties['dependencySources']) {
        foreach ($dependency in $case.dependencySources) {
            $sourcePaths.Add((Join-Path $repoRoot $dependency))
        }
    }
    $sourcePaths.Add((Join-Path $repoRoot $case.source))
    $filePath = $compilerPath
    $arguments = if ($CompilerInterface -ceq 'managed') {
        @('build') + @($sourcePaths) + @('--target', "$Target-x64")
    } elseif ($stdlibPath) { @("$Target-stdlib", $stdlibPath) + @($sourcePaths) }
    else { @($Target) + @($sourcePaths) }
    if ($CompilerInterface -ceq 'managed' -and $stdlibPath) { $arguments += @('--stdlib', $stdlibPath) }
    if (-not [string]::IsNullOrWhiteSpace($Distribution)) {
        $filePath = 'wsl.exe'
        $modeArguments = if ($stdlibPath) { @("$Target-stdlib", (Convert-ToTraitDiagnosticWslPath $stdlibPath)) } else { @($Target) }
        $arguments = @('-d', $Distribution, '--', (Convert-ToTraitDiagnosticWslPath $compilerPath)) + $modeArguments +
            @($sourcePaths | ForEach-Object { Convert-ToTraitDiagnosticWslPath $_ })
    }
    $timeout = if ($case.PSObject.Properties['timeoutMilliseconds']) { $case.timeoutMilliseconds } else { 3600000 }
    $result = Invoke-VerificationProcessCapture -FilePath $filePath -ArgumentList $arguments -Description "$Label trait/ownership $($case.id)" -TimeoutMilliseconds $timeout
    $output = $result.Stdout + $result.Stderr
    $missing = @($case.outputContains | Where-Object { -not $output.Contains($_) })
    $llvmStarted = $output -match '(?m)^target (datalayout|triple)'
    $casePassed = $result.ExitCode -eq $case.expectedExit -and $missing.Count -eq 0 -and -not $llvmStarted
    $caseRows.Add([ordered]@{ id=$case.id; passed=$casePassed; exitCode=$result.ExitCode;
        missing=@($missing); llvmStarted=$llvmStarted })
    if (-not $casePassed) {
        $failures.Add("$($case.id): exit=$($result.ExitCode), missing=$($missing -join '; '), output=$output")
    } else { $passed++ }
}
$drift = @($inputs.GetEnumerator() | Where-Object {
    (Get-FileHash -LiteralPath $_.Key -Algorithm SHA256).Hash -cne $_.Value
} | ForEach-Object Key)
if ($receiptPath) {
    $record = [ordered]@{ schemaVersion=1; status=if ($failures.Count -eq 0 -and $drift.Count -eq 0) {'passed'} else {'failed'};
        compilerInterface=$CompilerInterface;
        standardLibraryPath=$stdlibPath;
        standardLibrarySourceCount=$stdlibSources.Count;
        compilerSha256=$compilerHash; completed=$passed; total=$contract.cases.Count;
        inputStable=($drift.Count -eq 0); inputHashes=$inputs; inputDrift=@($drift);
        cases=@($caseRows.ToArray()); failureIds=@($caseRows | Where-Object { -not $_.passed } | ForEach-Object id) }
    [IO.File]::WriteAllText($receiptPath, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}
if ($drift.Count -gt 0) { throw "Diagnostic inputs changed during verification: $($drift -join ', ')" }
if ($failures.Count -gt 0) { throw "Trait/ownership diagnostics $passed/$($contract.cases.Count) passed:`n$($failures -join "`n")" }
Write-Host "[trait/ownership diagnostics] PASS $Label $Target $passed/$($contract.cases.Count) actionable errors before LLVM."
