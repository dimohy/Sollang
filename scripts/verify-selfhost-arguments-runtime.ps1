[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = ''
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
$outputRoot = Join-Path $repoRoot "artifacts/arguments-runtime/$compilerHash"
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
function Invoke-ArgumentsProcess {
    param([string]$FilePath, [string[]]$Arguments, [string]$Description, [int]$Timeout = 120000)
    $result = Invoke-VerificationProcessCapture -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $repoRoot -Description $Description -TimeoutMilliseconds $Timeout
    if ($result.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($result.Stderr)) {
        throw "$Description exit=$($result.ExitCode): $($result.Stdout) $($result.Stderr)"
    }
    $result.Stdout
}
$llvmByFixture = @{}
$sourceHashes = @{}
$sourcePaths = @{}
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
foreach ($fixture in @($contract.cases.fixture | Select-Object -Unique)) {
    $source = $sourcePaths[$fixture]
    $sourceHashes[$fixture] = (Get-FileHash -LiteralPath $source).Hash
    $compiled = Join-Path $outputRoot "$fixture.native.exe"
    # The full stdlib is intentional: unused declarations must not enable argv setup.
    $buildOutput = Invoke-ArgumentsProcess $compilerPath @('build',$source,'--stdlib',(Join-Path $repoRoot 'stdlib'),'--target','windows-x64','--llvm',$LlvmRoot,'--keep-temps','-o',$compiled) "$fixture full stdlib build" 180000
    [IO.File]::WriteAllText("$compiled.build.log",$buildOutput,[Text.UTF8Encoding]::new($false))
    $null = Invoke-ArgumentsProcess $assembler @("$compiled.ll",'-o',"$compiled.bc") "$fixture assemble"
    $llvmByFixture[$fixture] = [IO.File]::ReadAllText("$compiled.ll")
}
$results = foreach ($case in $contract.cases) {
    $prefix = Join-Path $outputRoot $case.name
    $executable = "$prefix.exe"
    $item = [ordered]@{name=$case.name;fixture=$case.fixture;sourceSha256=$sourceHashes[$case.fixture];passed=$false;output='';error=$null}
    try {
        $llvm = $llvmByFixture[$case.fixture]
        $hasArguments = $llvm.Contains('call void @sollang_init_utf8_arguments()')
        if ($hasArguments -ne $case.requiresArguments) { throw 'Arguments capability reachability mismatch' }
        $audit = $llvm.Replace('@malloc(', '@audit_malloc(').Replace('@realloc(', '@audit_realloc(').Replace('@free(', '@audit_free(').Replace('@main()', '@slg_program_main()').Replace('@WideCharToMultiByte(', '@audit_WideCharToMultiByte(').Replace('declare dllimport i32 @audit_WideCharToMultiByte', 'declare i32 @audit_WideCharToMultiByte')
        [IO.File]::WriteAllText("$prefix.audit.ll",$audit,[Text.UTF8Encoding]::new($false))
        $options = @('-Wno-override-module',"-DEXPECTED_ALLOCATIONS=$($case.allocations)")
        if ($case.PSObject.Properties.Name -contains 'failureKind') { $options += "-DFAIL_$($case.failureKind)=$($case.failureOrdinal)" }
        $null = Invoke-ArgumentsProcess $clang ($options + @("$prefix.audit.ll",$shim,'-O1','-lshell32','-lbcrypt','-o',$executable)) "$($case.name) audit link"
        $item.output = (Invoke-ArgumentsProcess $executable @($case.arguments) "$($case.name) audit execute" 10000).Replace("`r`n","`n")
        $expected = $case.expected.Replace("`r`n","`n").Replace('{executable}',$executable)
        if ($expected.Length -gt 0 -and -not $expected.EndsWith("`n")) { $expected += "`n" }
        $expected += "allocations=$($case.allocations),releases=$($case.allocations)`n"
        if ($item.output -cne $expected) { throw "Exact stdout/allocation mismatch: $($item.output)" }
        $item.passed = $true
    } catch { $item.error = $_.Exception.Message }
    [pscustomobject]$item
}
if ((Get-FileHash -LiteralPath $compilerPath).Hash -cne $compilerHash) { throw 'Arguments compiler changed during verification' }
$report = [ordered]@{compilerSha256=$compilerHash;contractSha256=(Get-FileHash -LiteralPath $contractPath).Hash;shimSha256=(Get-FileHash -LiteralPath $shim).Hash;passed=@($results | Where-Object passed).Count;total=$contract.cases.Count;cases=@($results)}
$report | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $outputRoot 'results.json') -Encoding utf8
if ($report.passed -ne $report.total) { throw "Arguments runtime $($report.passed)/$($report.total): $($results | ConvertTo-Json -Depth 4 -Compress)" }
Write-Host "[arguments runtime] PASS $($report.passed)/$($report.total) reachability, exact argv, allocation/release and failure cleanup."
