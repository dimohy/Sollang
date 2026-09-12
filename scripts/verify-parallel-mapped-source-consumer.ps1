[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1')
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$fixture = Join-Path $root 'examples/regression/1727-try-parallel-mapped-source-cleanup.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1727-try-parallel-mapped-source-cleanup.stdout.txt'
$harness = Join-Path $PSScriptRoot 'contracts/fixtures/1727-parallel-mapped-source-consumer.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$hashes = [ordered]@{}
foreach ($path in @($compiler, $fixture, $expectedPath, $harness, $PSCommandPath,
    (Join-Path $PSScriptRoot 'runtime-llvm-probe.ps1'), (Join-Path $PSScriptRoot 'verification-process.ps1'),
    (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'), (Join-Path $PSScriptRoot 'stage2-artifact-receipt.ps1'))) {
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$stdlibRoot = Join-Path $root 'stdlib'
$stdlibSources = Get-NativeExactOrderedSourceClosure -Root $stdlibRoot
$stdlibFingerprintSettings = [ordered]@{ platform = 'windows'; scope = '1727-managed-consumer-stdlib' }
$stdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath $stdlibSources
$probe = New-RuntimeLlvmProbe -RepositoryRoot $root -Name 'parallel-mapped-source-consumer' -Harness $harness
$output = $probe.Output
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1; status = 'running'; completed = 0; total = 4; checks = @()
    scope = 'managed-windows-real-mapped-SourceText-tryParallel-success-and-unselected-failure-payload'
    inputHashes = $hashes; compilerSha256 = $hashes[$compiler]
    stdlibSourceCount = $stdlibSources.Count; stdlibSourceFingerprint = $stdlibFingerprint
    schedulerContract = 'index0 Ok cannot be cancelled by sole error index1; join precedes initialized-unselected cleanup'
    integration = 'selfhost C402 consumer integration and Stage2/Stage3 remain pending'
}
function Save-Result { [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n")) }
function Complete-Check([string]$Name) { $record.completed++; $record.checks += $Name; Save-Result }
function Invoke-ConsumerStep {
    param([string]$Name, [string]$Tool, [string[]]$Arguments)
    $actual = Invoke-VerificationProcessCapture -FilePath $Tool -ArgumentList $Arguments -Description "1727 $Name" -WorkingDirectory $root -TimeoutMilliseconds 20000
    [IO.File]::WriteAllText((Join-Path $output "$Name.stdout.txt"), $actual.Stdout)
    [IO.File]::WriteAllText((Join-Path $output "$Name.stderr.txt"), $actual.Stderr)
    if ($actual.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($actual.Stderr)) {
        throw "1727 $Name failed, exit $($actual.ExitCode): $($actual.Stderr) $($actual.Stdout)"
    }
    return $actual.Stdout
}
try {
    Save-Result
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source @($fixture)
    Complete-Check 'authoritative-format'
    $exe = Join-Path $output '1727.exe'
    $buildOutput = Invoke-ConsumerStep -Name 'build' -Tool 'dotnet' -Arguments @($compiler, 'build', $fixture, '--llvm', $llvmRoot, '-o', $exe, '--keep-temps')
    if ($buildOutput -match '(?i)warning|\b[NS]00[12]\b') { throw "1727 build emitted a warning: $buildOutput" }
    $ir = [IO.Path]::ChangeExtension($exe, '.ll')
    if (-not (Test-Path -LiteralPath $ir)) { throw '1727 retained generated LLVM is missing.' }
    $expected = [IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
    if ([string]::IsNullOrWhiteSpace($expected)) { throw '1727 expected output is empty.' }
    $actual = Invoke-ConsumerStep -Name 'native' -Tool $exe -Arguments @()
    if ($actual.Replace("`r`n", "`n").TrimEnd("`n") -cne $expected) { throw "1727 exact stdout differs: $actual" }
    $record.nativeExecutableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    $record.generatedLlvmSha256 = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
    Complete-Check 'original-generated-native-success-and-failure-exact-output'
    $assemblyOutput = Invoke-ConsumerStep -Name 'assemble' -Tool $probe.LlvmAs -Arguments @($ir, '-o', (Join-Path $output '1727.bc'))
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $ir
    Complete-Check 'original-llvm-assembly-and-direct-call-closure'

    $body = [IO.File]::ReadAllText($ir)
    # Observe only the two actual OS call targets. Do not rewrite scheduler,
    # callback results, ownership, cleanup branches, or SourceText metadata.
    foreach ($symbol in @('MapViewOfFile', 'UnmapViewOfFile')) {
        $pattern = "(?m)^(?<prefix>[^\r\n]*\bcall\s+[^\r\n@]+)@$symbol\("
        $calls = [regex]::Matches($body, $pattern)
        if ($calls.Count -ne 1) { throw "Expected one generated OS callsite for $symbol; found $($calls.Count)." }
        $body = [regex]::Replace($body, $pattern, '${prefix}@sollang_probe_' + $symbol + '(')
    }
    if ([regex]::Matches($body, '(?m)^define\b[^\r\n]*@sollang_start\(\)').Count -ne 1) {
        throw '1727 generated native entry ABI changed.'
    }
    $body += "`ndeclare ptr @sollang_probe_MapViewOfFile(ptr, i32, i32, i32, i64)`ndeclare i32 @sollang_probe_UnmapViewOfFile(ptr)`n"
    $body = [regex]::Replace($body, '(?m)^target triple = "[^"]+"\r?\n', '')
    Push-Location $root
    try {
        $observed = Invoke-RuntimeLlvmProbe -Probe $probe -Authority 'real-os-observed' -Llvm $body -ExpectedOutput ($expected + "`nreal-os:map=2,unmap=2,failures=0")
    } finally { Pop-Location }
    $record.observedLlvmSha256 = $observed.LlvmHash
    $record.observedExecutableSha256 = $observed.ExecutableHash
    $record.realOs = [ordered]@{ successfulMaps = 2; successfulUnmaps = 2; failedMaps = 0; failedUnmaps = 0; shim = 'delegates to real Windows APIs' }
    Complete-Check 'real-os-two-maps-and-two-successful-unmaps'
    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { throw "1727 input drift: $path" }
    }
    $endingStdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath (Get-NativeExactOrderedSourceClosure -Root $stdlibRoot)
    if ($endingStdlibFingerprint -cne $stdlibFingerprint) { throw '1727 stdlib source closure changed during verification.' }
    $record.inputsStable = $true
    $record.status = 'passed'
} catch { $record.status = 'failed'; $record.failure = $_.Exception.Message; throw }
finally { Save-Result }
Write-Host "[parallel mapped SourceText consumer] PASS 4/4; $resultPath"
