[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/focused'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
[IO.Directory]::CreateDirectory($output) | Out-Null
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$contractPath = Join-Path $root 'scripts/contracts/socket-completion-reactor.json'
$resultSchema = Join-Path $root 'scripts/contracts/socket-completion-focused-result.schema.json'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$b01Source = Join-Path $root 'scripts/probes/socket-completion/b01-browser-unavailable.slg'
$b01ExpectedPath = Join-Path $root 'scripts/probes/socket-completion/b01-browser-unavailable.stderr.contains.txt'
$x01Source = Join-Path $root 'scripts/probes/socket-completion/x01-moved-slot-reuse.slg'
$x01ExpectedPath = Join-Path $root 'scripts/probes/socket-completion/x01-moved-slot-reuse.stderr.contains.txt'
$x01ReactorSource = Join-Path $root 'scripts/probes/socket-completion/x01-register-reactor-reuse.slg'
$x01ReactorExpectedPath = Join-Path $root 'scripts/probes/socket-completion/x01-register-reactor-reuse.stderr.contains.txt'
$x01StreamSource = Join-Path $root 'scripts/probes/socket-completion/x01-register-stream-reuse.slg'
$x01StreamExpectedPath = Join-Path $root 'scripts/probes/socket-completion/x01-register-stream-reuse.stderr.contains.txt'
$x02Source = Join-Path $root 'scripts/probes/socket-completion/x02-vacant-recycle-rejected.slg'
$w01Source = Join-Path $root 'scripts/probes/socket-completion/w01-create-capacity.slg'
$w01Verifier = Join-Path $root 'scripts/verify-socket-completion-w01.ps1'
$w01ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-w01-result.schema.json'
$expectedImplemented = @('W01', 'B01', 'B02', 'X01', 'X02')

$inputPaths = [ordered]@{
    compiler = $compiler; contract = $contractPath; resultSchema = $resultSchema
    b01Source = $b01Source; b01Expected = $b01ExpectedPath
    x01Source = $x01Source; x01Expected = $x01ExpectedPath; x02Source = $x02Source
    x01ReactorSource = $x01ReactorSource; x01ReactorExpected = $x01ReactorExpectedPath
    x01StreamSource = $x01StreamSource; x01StreamExpected = $x01StreamExpectedPath
    w01Source = $w01Source; w01Verifier = $w01Verifier; w01ResultSchema = $w01ResultSchema
}
foreach ($path in @($inputPaths.Values) + @($llvmAs, $closure)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "socket completion focused input missing: $path" }
}
& (Join-Path $root 'scripts/verify-socket-reactor-contract.ps1') -RepositoryRoot $root
if (-not $?) { throw 'socket completion authority verifier failed' }

$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
$declaredPassed = @($contract.verificationMatrix | Where-Object status -CEQ 'passed' | ForEach-Object id | Sort-Object)
$sortedExpected = @($expectedImplemented | Sort-Object)
if (($declaredPassed -join ',') -cne ($sortedExpected -join ',')) {
    throw "contract passed IDs must equal executable focused IDs: declared=$($declaredPassed -join ',') executable=$($sortedExpected -join ',')"
}

$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashes[$entry.Key] = (Get-FileHash $entry.Value -Algorithm SHA256).Hash }
$probeResults = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure([string]$Id) { if ($Id -notin $failures) { $failures.Add($Id) } }
function Invoke-PositiveProbe([string]$CaseId, [string]$Source, [string]$ExpectedStdout) {
    $nativePath = Join-Path $output ($CaseId.ToLowerInvariant() + '.exe')
    @(& dotnet $compiler build $Source -o $nativePath --target windows-x64 --llvm $llvmRoot --keep-temps -O0 2>&1 | ForEach-Object ToString) | Set-Variable compileLines
    $compileExit = $LASTEXITCODE
    $nativeExit = $null; $stdout = @(); $llvmExit = $null; $closureExit = $null; $llvmHash = $null; $outputHash = $null
    if ($compileExit -eq 0) {
        $llvmPath = [IO.Path]::ChangeExtension($nativePath, '.ll')
        $bitcodePath = [IO.Path]::ChangeExtension($nativePath, '.bc')
        & $llvmAs $llvmPath -o $bitcodePath 2>&1 | Out-Null
        $llvmExit = $LASTEXITCODE
        & $closure -LlvmPath $llvmPath 6>&1 | Out-Null
        $closureExit = if ($?) { 0 } else { 1 }
        $stdout = @(& $nativePath 2>&1 | ForEach-Object ToString)
        $nativeExit = $LASTEXITCODE
        $llvmHash = (Get-FileHash $llvmPath -Algorithm SHA256).Hash
        $outputHash = (Get-FileHash $nativePath -Algorithm SHA256).Hash
    }
    if ($compileExit -ne 0 -or $nativeExit -ne 0 -or $llvmExit -ne 0 -or $closureExit -ne 0 -or ($stdout -join "`n") -cne $ExpectedStdout) { Add-Failure $CaseId }
    $probeResults.Add([ordered]@{
        caseId = $CaseId; source = [IO.Path]::GetRelativePath($root, $Source).Replace('\', '/'); sourceSha256 = (Get-FileHash $Source -Algorithm SHA256).Hash
        compileExitCode = $compileExit; nativeExitCode = $nativeExit; stdout = $stdout
        llvmAsExitCode = $llvmExit; closureExitCode = $closureExit; llvmSha256 = $llvmHash; outputSha256 = $outputHash
    })
}

$browserOutput = Join-Path $output 'b01.wasm'
$browserLog = @(& dotnet $compiler build $b01Source -o $browserOutput --target wasm32-browser --llvm $llvmRoot --keep-temps -O0 2>&1 | ForEach-Object ToString)
$browserExit = $LASTEXITCODE
$browserText = $browserLog -join "`n"
$browserExpected = [IO.File]::ReadAllText($b01ExpectedPath).Trim()
$browserDiagnosticOk = $browserExit -ne 0 -and $browserText.Contains($browserExpected, [StringComparison]::Ordinal)
$browserArtifacts = @($browserOutput, [IO.Path]::ChangeExtension($browserOutput, '.ll'), [IO.Path]::ChangeExtension($browserOutput, '.bc'))
$browserFallbackOk = @($browserArtifacts | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 0 -and
    -not $browserText.Contains('fallback', [StringComparison]::OrdinalIgnoreCase) -and -not $browserText.Contains('poll(', [StringComparison]::Ordinal)
if (-not $browserDiagnosticOk) { Add-Failure 'B01' }
if (-not $browserFallbackOk) { Add-Failure 'B02' }
foreach ($caseId in @('B01', 'B02')) {
    $probeResults.Add([ordered]@{
        caseId = $caseId; source = 'scripts/probes/socket-completion/b01-browser-unavailable.slg'; sourceSha256 = (Get-FileHash $b01Source -Algorithm SHA256).Hash
        compileExitCode = $browserExit; nativeExitCode = $null; stdout = $browserLog
        llvmAsExitCode = $null; closureExitCode = $null; llvmSha256 = $null; outputSha256 = $null
    })
}

function Invoke-NegativeProbe([string]$CaseId, [string]$Label, [string]$Source, [string]$ExpectedPath) {
    $nativePath = Join-Path $output ($Label + '.exe')
    $llvmPath = [IO.Path]::ChangeExtension($nativePath, '.ll')
    Remove-Item -LiteralPath $nativePath, $llvmPath -ErrorAction SilentlyContinue
    $log = @(& dotnet $compiler build $Source -o $nativePath --target windows-x64 --llvm $llvmRoot --keep-temps -O0 2>&1 | ForEach-Object ToString)
    $exit = $LASTEXITCODE
    $expected = [IO.File]::ReadAllText($ExpectedPath).Trim()
    if ($exit -eq 0 -or (Test-Path -LiteralPath $llvmPath -PathType Leaf) -or
        -not (($log -join "`n").Contains($expected, [StringComparison]::Ordinal))) { Add-Failure $CaseId }
    $probeResults.Add([ordered]@{
        caseId = $CaseId; source = [IO.Path]::GetRelativePath($root, $Source).Replace('\', '/'); sourceSha256 = (Get-FileHash $Source -Algorithm SHA256).Hash
        compileExitCode = $exit; nativeExitCode = $null; stdout = $log
        llvmAsExitCode = $null; closureExitCode = $null; llvmSha256 = $null; outputSha256 = $null
    })
}

Invoke-NegativeProbe 'X01' 'x01-slot' $x01Source $x01ExpectedPath
Invoke-NegativeProbe 'X01' 'x01-reactor' $x01ReactorSource $x01ReactorExpectedPath
Invoke-NegativeProbe 'X01' 'x01-stream' $x01StreamSource $x01StreamExpectedPath

Invoke-PositiveProbe 'X02' $x02Source 'invalid=true,code=0,len=2,first=7'

$w01Output = Join-Path $output 'w01'
& $w01Verifier -Compiler $compiler -OutputDirectory $w01Output 6>&1 | Out-Null
$w01Exit = if ($?) { 0 } else { 1 }
$w01ResultPath = Join-Path $w01Output 'result.json'
$w01Result = if (Test-Path -LiteralPath $w01ResultPath -PathType Leaf) {
    [IO.File]::ReadAllText($w01ResultPath) | ConvertFrom-Json
} else { $null }
if ($w01Exit -ne 0 -or $null -eq $w01Result -or $w01Result.status -cne 'passed') { Add-Failure 'W01' }
$w01Llvm = Join-Path $w01Output 'w01.ll'
$w01Exe = Join-Path $w01Output 'w01.exe'
$probeResults.Add([ordered]@{
    caseId = 'W01'; source = 'scripts/probes/socket-completion/w01-create-capacity.slg'; sourceSha256 = (Get-FileHash $w01Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $w01Result) { -1 } else { $w01Result.compileExit }
    nativeExitCode = if ($null -eq $w01Result) { $null } else { $w01Result.nativeExit }
    stdout = if ($null -eq $w01Result) { @() } else { @($w01Result.stdout -split "`n") }
    llvmAsExitCode = if ($null -eq $w01Result) { $null } else { $w01Result.llvmAsExit }
    closureExitCode = if ($null -eq $w01Result) { $null } else { $w01Result.closureExit }
    llvmSha256 = if (Test-Path -LiteralPath $w01Llvm -PathType Leaf) { (Get-FileHash $w01Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $w01Exe -PathType Leaf) { (Get-FileHash $w01Exe -Algorithm SHA256).Hash } else { $null }
})

$passed = @($expectedImplemented | Where-Object { $_ -notin $failures })
foreach ($entry in $inputPaths.GetEnumerator()) {
    if ((Get-FileHash $entry.Value -Algorithm SHA256).Hash -cne $inputHashes[$entry.Key]) { Add-Failure 'SOCKET_COMPLETION_INPUT_DRIFT' }
}
$result = [ordered]@{
    runStatus = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completionStatus = if ($passed.Count -eq 22 -and $failures.Count -eq 0) { 'complete' } else { 'in-progress' }
    completed = $passed.Count; total = 22; passedCaseIds = $passed; failureIds = @($failures); inputHashes = $inputHashes; probes = @($probeResults)
}
$resultPath = Join-Path $output 'result.json'
$json = $result | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($resultPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
if (-not (Test-Json -Json $json -SchemaFile $resultSchema)) { throw 'socket completion focused result violates schema' }
if ($result.probes.Count -ne 7 -or $result.passedCaseIds.Count -ne $result.completed -or
    @($result.passedCaseIds | Where-Object { $_ -notin $expectedImplemented }).Count -ne 0 -or
    ($result.completionStatus -ceq 'complete' -and $result.completed -ne $result.total)) { throw 'socket completion focused result count and ID consistency failed' }
$json
if ($failures.Count -ne 0) { exit 1 }
