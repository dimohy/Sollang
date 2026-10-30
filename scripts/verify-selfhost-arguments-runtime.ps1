[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '',
    [string]$OutputDirectory = '',
    [string]$PreparedLlvmManifest = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
if ([string]::IsNullOrWhiteSpace($LlvmRoot)) { $LlvmRoot = Join-Path $repoRoot '.tools/llvm-22.1.8' }
$clang = (Resolve-Path -LiteralPath (Join-Path $LlvmRoot 'bin/clang.exe')).Path
$assembler = (Resolve-Path -LiteralPath (Join-Path $LlvmRoot 'bin/llvm-as.exe')).Path
$shim = Join-Path $repoRoot 'tests/native-interop/arguments_runtime_audit.c'
$contractPath = Join-Path $repoRoot 'scripts/contracts/arguments-runtime.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.target -cne 'windows-x64' -or $contract.cases.Count -eq 0) { throw 'Invalid Windows arguments runtime contract' }
$compilerHash = (Get-FileHash -LiteralPath $compilerPath).Hash
$outputRoot = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory, $repoRoot) }
    else { Join-Path $repoRoot "artifacts/arguments-runtime/$compilerHash" }
if ($OutputDirectory -and (Test-Path -LiteralPath $outputRoot)) { throw 'ARGUMENTS_RUNTIME_FRESH_OUTPUT_REQUIRED' }
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
function Invoke-ArgumentsProcess {
    param([string]$FilePath, [string[]]$Arguments, [string]$Description, [int]$Timeout = 120000,
        [string]$ExpectedStderr = '', [string]$LogPrefix = '')
    $capture = @{ FilePath=$FilePath; ArgumentList=$Arguments; WorkingDirectory=$repoRoot;
        Description=$Description; TimeoutMilliseconds=$Timeout }
    if ($LogPrefix) { $capture.ExecutionRecordPath = "$LogPrefix.execution.json" }
    $result = Invoke-VerificationProcessCapture @capture
    if ($LogPrefix) {
        [IO.File]::WriteAllText("$LogPrefix.stdout", $result.Stdout, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText("$LogPrefix.stderr", $result.Stderr, [Text.UTF8Encoding]::new($false))
    }
    if ($result.ExitCode -ne 0 -or $result.Stderr.Replace("`r`n","`n") -cne $ExpectedStderr.Replace("`r`n","`n")) {
        throw "$Description exit=$($result.ExitCode): $($result.Stdout) $($result.Stderr)"
    }
    $result.Stdout
}
$llvmByFixture = @{}
$sourceHashes = @{}
$sourcePaths = @{}
$expectedBuildDiagnostics = @{}
$prepared = @{}
# Validate every source and runtime dependency before any full stdlib build.
$null = Resolve-Path -LiteralPath $shim
$null = Resolve-Path -LiteralPath (Join-Path $repoRoot 'tests/native-interop/owned_array_audit.c')
$null = Resolve-Path -LiteralPath (Join-Path $repoRoot 'stdlib')
foreach ($case in $contract.cases) {
    if ($case.name -notmatch '^[a-z0-9-]+$' -or $case.fixture -notmatch '^[a-z0-9-]+$' -or $case.allocations -lt 0) { throw 'Invalid arguments runtime case' }
    $relativeSource = if ($case.PSObject.Properties.Name -contains 'source') { $case.source } else { "examples/regression/$($case.fixture).slg" }
    $resolvedSource = (Resolve-Path -LiteralPath (Join-Path $repoRoot $relativeSource)).Path
    if (-not $resolvedSource.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Arguments fixture must stay inside the repository' }
    if ($sourcePaths.ContainsKey($case.fixture) -and $sourcePaths[$case.fixture] -cne $resolvedSource) { throw 'Conflicting argument fixture identity' }
    $sourcePaths[$case.fixture] = $resolvedSource
    $sourceHashes[$case.fixture] = (Get-FileHash -LiteralPath $resolvedSource).Hash
    if ($case.PSObject.Properties.Name -contains 'failureKind') {
        if ($case.failureKind -cnotin @('ALLOCATION','CONVERSION') -or $case.failureOrdinal -le 0) { throw 'Invalid failure injection contract' }
    }
}
if ($contract.PSObject.Properties['buildDiagnostics']) {
    foreach ($entry in $contract.buildDiagnostics.PSObject.Properties) {
        if (-not $sourcePaths.ContainsKey($entry.Name)) { throw 'ARGUMENTS_DIAGNOSTIC_FIXTURE_UNKNOWN' }
        $path = (Resolve-Path -LiteralPath (Join-Path $repoRoot $entry.Value)).Path
        if (-not $path.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'ARGUMENTS_DIAGNOSTIC_PATH_ESCAPE'
        }
        $expectedBuildDiagnostics[$entry.Name] = [IO.File]::ReadAllText($path)
    }
}
if ($PreparedLlvmManifest) {
    $preparedRecord = Get-Content -LiteralPath $PreparedLlvmManifest -Raw | ConvertFrom-Json
    if ($preparedRecord.schemaVersion -ne 1 -or $preparedRecord.compilerSha256 -cne $compilerHash) {
        throw 'ARGUMENTS_PREPARED_COMPILER_MISMATCH'
    }
    $requiredPreparedInputs = @($compilerPath, $clang, $assembler) + @($sourcePaths.Values) +
        @((Get-ChildItem -LiteralPath (Join-Path $repoRoot 'stdlib') -Recurse -File -Filter '*.slg').FullName)
    foreach ($requiredInput in $requiredPreparedInputs) {
        if (-not $preparedRecord.producerInputHashes.PSObject.Properties[$requiredInput]) {
            throw 'ARGUMENTS_PREPARED_INPUT_CLOSURE_INCOMPLETE'
        }
    }
    foreach ($entry in $preparedRecord.producerInputHashes.PSObject.Properties) {
        if (-not (Test-Path -LiteralPath $entry.Name -PathType Leaf) -or
            (Get-FileHash -LiteralPath $entry.Name).Hash -cne $entry.Value) { throw 'ARGUMENTS_PREPARED_INPUT_DRIFT' }
    }
    foreach ($entry in $preparedRecord.fixtures) {
        if (-not $sourcePaths.ContainsKey($entry.fixture) -or $prepared.ContainsKey($entry.fixture) -or
            $sourceHashes[$entry.fixture] -cne $entry.sourceSha256 -or
            -not (Test-Path -LiteralPath $entry.llvm -PathType Leaf) -or
            (Get-FileHash -LiteralPath $entry.llvm).Hash -cne $entry.llvmSha256) { throw 'ARGUMENTS_PREPARED_LLVM_DRIFT' }
        if ($entry.PSObject.Properties['assembly']) {
            if (-not (Test-Path -LiteralPath $entry.assembly -PathType Leaf) -or
                (Get-FileHash -LiteralPath $entry.assembly).Hash -cne $entry.assemblySha256) { throw 'ARGUMENTS_PREPARED_ASSEMBLY_DRIFT' }
        }
        $prepared[$entry.fixture] = $entry
    }
}
$executionInputs = @($compilerPath,$clang,$assembler,$shim,$contractPath,$PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'),
    (Join-Path $repoRoot 'tests/native-interop/owned_array_audit.c')) + @($sourcePaths.Values) +
    @((Get-ChildItem -LiteralPath (Join-Path $repoRoot 'stdlib') -Recurse -File -Filter '*.slg').FullName)
if ($PreparedLlvmManifest) {
    $executionInputs += (Resolve-Path -LiteralPath $PreparedLlvmManifest).Path
    $executionInputs += @($preparedRecord.producerInputHashes.PSObject.Properties.Name)
    $executionInputs += @($preparedRecord.fixtures | ForEach-Object { $_.llvm; if ($_.PSObject.Properties['assembly']) { $_.assembly } })
}
if ($contract.PSObject.Properties['buildDiagnostics']) {
    $executionInputs += @($contract.buildDiagnostics.PSObject.Properties | ForEach-Object { Join-Path $repoRoot $_.Value })
}
$inputHashesStart = [ordered]@{}
foreach ($path in ($executionInputs | Select-Object -Unique)) {
    $resolved = (Resolve-Path -LiteralPath $path).Path
    $inputHashesStart[$resolved] = (Get-FileHash -LiteralPath $resolved).Hash
}
foreach ($fixture in @($contract.cases.fixture | Select-Object -Unique)) {
    $source = $sourcePaths[$fixture]
    $sourceHashes[$fixture] = (Get-FileHash -LiteralPath $source).Hash
    $compiled = Join-Path $outputRoot "$fixture.native.exe"
    # The full stdlib is intentional: unused declarations must not enable argv setup.
    if ($prepared.ContainsKey($fixture)) {
        $llvmPath = $prepared[$fixture].llvm
        if (-not $prepared[$fixture].PSObject.Properties['assembly']) {
            $null = Invoke-ArgumentsProcess $assembler @($llvmPath,'-o',"$compiled.bc") "$fixture assemble" 120000 '' "$compiled.assemble"
        }
    } else {
        $expectedDiagnostics = if ($expectedBuildDiagnostics.ContainsKey($fixture)) { $expectedBuildDiagnostics[$fixture] } else { '' }
        $buildOutput = Invoke-ArgumentsProcess $compilerPath @('build',$source,'--stdlib',(Join-Path $repoRoot 'stdlib'),'--target','windows-x64','--llvm',$LlvmRoot,'--keep-temps','-o',$compiled) "$fixture full stdlib build" 180000 $expectedDiagnostics "$compiled.build"
        $llvmPath = "$compiled.ll"
        $null = Invoke-ArgumentsProcess $assembler @($llvmPath,'-o',"$compiled.bc") "$fixture assemble" 120000 '' "$compiled.assemble"
    }
    $llvmByFixture[$fixture] = [IO.File]::ReadAllText($llvmPath)
}
$results = foreach ($case in $contract.cases) {
    $prefix = Join-Path $outputRoot $case.name
    $executable = "$prefix.exe"
    $item = [ordered]@{name=$case.name;fixture=$case.fixture;sourceSha256=$sourceHashes[$case.fixture];passed=$false;output='';error=$null}
    try {
        $llvm = $llvmByFixture[$case.fixture]
        $hasArguments = $llvm.Contains('call i32 @sollang_init_arguments()')
        if ($hasArguments -ne $case.requiresArguments) { throw 'Arguments capability reachability mismatch' }
        $audit = $llvm.Replace('@malloc(', '@audit_malloc(').Replace('@realloc(', '@audit_realloc(').Replace('@free(', '@audit_free(').Replace('@main()', '@slg_program_main()').Replace('@WideCharToMultiByte(', '@audit_WideCharToMultiByte(').Replace('declare dllimport i32 @audit_WideCharToMultiByte', 'declare i32 @audit_WideCharToMultiByte')
        $audit = $audit.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(')
        if ($audit -notmatch '(?m)^declare ptr @audit_malloc\(') { $audit += "`ndeclare ptr @audit_malloc(i64)`n" }
        if ($audit -notmatch '(?m)^declare void @audit_free\(') { $audit += "`ndeclare void @audit_free(ptr)`n" }
        [IO.File]::WriteAllText("$prefix.audit.ll",$audit,[Text.UTF8Encoding]::new($false))
        $options = @('-Wno-override-module',"-DEXPECTED_ALLOCATIONS=$($case.allocations)")
        if ($case.PSObject.Properties.Name -contains 'failureKind') {
            $options += "-DFAIL_$($case.failureKind)=$($case.failureOrdinal)"
            $options += '-DEXPECTED_EXIT_CODE=1'
        }
        $null = Invoke-ArgumentsProcess $clang ($options + @("$prefix.audit.ll",$shim,'-O1','-lshell32','-lbcrypt','-o',$executable)) "$($case.name) audit link" 120000 '' "$prefix.link"
        $item.output = (Invoke-ArgumentsProcess $executable @($case.arguments) "$($case.name) audit execute" 10000 '' "$prefix.run").Replace("`r`n","`n")
        $expected = $case.expected.Replace("`r`n","`n").Replace('{executable}',$executable)
        if ($expected.Length -gt 0 -and -not $expected.EndsWith("`n")) { $expected += "`n" }
        $expected += "allocations=$($case.allocations),releases=$($case.allocations)`n"
        if ($item.output -cne $expected) { throw "Exact stdout/allocation mismatch: $($item.output)" }
        $item.passed = $true
    } catch { $item.error = $_.Exception.Message }
    [pscustomobject]$item
}
if ((Get-FileHash -LiteralPath $compilerPath).Hash -cne $compilerHash) { throw 'Arguments compiler changed during verification' }
$inputHashesEnd = [ordered]@{}
foreach ($path in $inputHashesStart.Keys) {
    $inputHashesEnd[$path] = (Get-FileHash -LiteralPath $path).Hash
    if ($inputHashesEnd[$path] -cne $inputHashesStart[$path]) { throw 'ARGUMENTS_RUNTIME_INPUT_DRIFT' }
}
$report = [ordered]@{compilerSha256=$compilerHash;contractSha256=(Get-FileHash -LiteralPath $contractPath).Hash;shimSha256=(Get-FileHash -LiteralPath $shim).Hash;passed=@($results | Where-Object passed).Count;total=$contract.cases.Count;cases=@($results);inputHashesStart=$inputHashesStart;inputHashesEnd=$inputHashesEnd;inputsStable=$true;reusedCompiledFixtures=@($prepared.Keys)}
$report | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $outputRoot 'results.json') -Encoding utf8
if ($report.passed -ne $report.total) { throw "Arguments runtime $($report.passed)/$($report.total): $($results | ConvertTo-Json -Depth 4 -Compress)" }
Write-Host "[arguments runtime] PASS $($report.passed)/$($report.total) reachability, exact argv, allocation/release and failure cleanup."
