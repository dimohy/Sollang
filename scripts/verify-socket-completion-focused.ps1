[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Fa-f0-9]{64}$')] [string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = 'artifacts/scratch/socket-completion/focused'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$output = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
[IO.Directory]::CreateDirectory($output) | Out-Null
$compiler = if ([IO.Path]::IsPathRooted($Compiler)) { [IO.Path]::GetFullPath($Compiler) } else { [IO.Path]::GetFullPath((Join-Path $root $Compiler)) }
$compilerSha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
if ($compilerSha256 -cne $ExpectedCompilerSha256.ToUpperInvariant()) {
    throw "socket completion focused compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$compilerSha256"
}
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
$w04Source = Join-Path $root 'scripts/probes/socket-completion/w04-partial-send.slg'
$w04Expected = Join-Path $root 'scripts/probes/socket-completion/w04-partial-send.stdout.txt'
$w04Verifier = Join-Path $root 'scripts/verify-socket-completion-w04.ps1'
$w04ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-w04-result.schema.json'
$w05Source = Join-Path $root 'scripts/probes/socket-completion/w05-pending-reset.slg'
$w05Expected = Join-Path $root 'scripts/probes/socket-completion/w05-pending-reset.stdout.txt'
$w05Verifier = Join-Path $root 'scripts/verify-socket-completion-w05.ps1'
$w05ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-w05-result.schema.json'
$w06Source = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-completion-race.slg'
$w06CancelExpected = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-wins.stdout.txt'
$w06CompletionExpected = Join-Path $root 'scripts/probes/socket-completion/w06-completion-wins.stdout.txt'
$w06Verifier = Join-Path $root 'scripts/verify-socket-completion-w06.ps1'
$w06ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-w06-result.schema.json'
$w07Source = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.slg'
$w07Expected = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.stdout.txt'
$w07Verifier = Join-Path $root 'scripts/verify-socket-completion-w07.ps1'
$w07ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-w07-result.schema.json'
$l01Source = Join-Path $root 'scripts/probes/socket-completion/l01-direct-receive.slg'
$l01Expected = Join-Path $root 'scripts/probes/socket-completion/l01-direct-receive.stdout.txt'
$l01Verifier = Join-Path $root 'scripts/verify-socket-completion-l01.ps1'
$l01ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l01-result.schema.json'
$l02Source = Join-Path $root 'scripts/probes/socket-completion/l02-pending-receive.slg'
$l02Expected = Join-Path $root 'scripts/probes/socket-completion/l02-pending-receive.stdout.txt'
$l02Verifier = Join-Path $root 'scripts/verify-socket-completion-l02.ps1'
$l02ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l02-result.schema.json'
$l03Source = Join-Path $root 'scripts/probes/socket-completion/l03-partial-send.slg'
$l03Expected = Join-Path $root 'scripts/probes/socket-completion/l03-partial-send.stdout.txt'
$l03Verifier = Join-Path $root 'scripts/verify-socket-completion-l03.ps1'
$l03ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l03-result.schema.json'
$l04Source = Join-Path $root 'scripts/probes/socket-completion/l04-false-readiness-recv.c'
$l04Verifier = Join-Path $root 'scripts/verify-socket-completion-l04.ps1'
$l04ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l04-result.schema.json'
$l05Source = Join-Path $root 'scripts/probes/socket-completion/l05-pending-reset.slg'
$l05ShimSource = Join-Path $root 'scripts/probes/socket-completion/l05-pending-reset-recv.c'
$l05Expected = Join-Path $root 'scripts/probes/socket-completion/l05-pending-reset.stdout.txt'
$l05Verifier = Join-Path $root 'scripts/verify-socket-completion-l05.ps1'
$l05ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l05-result.schema.json'
$l06Source = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-completion-race.slg'
$l06CancelExpected = Join-Path $root 'scripts/probes/socket-completion/w06-cancel-wins.stdout.txt'
$l06CompletionExpected = Join-Path $root 'scripts/probes/socket-completion/w06-completion-wins.stdout.txt'
$l06Verifier = Join-Path $root 'scripts/verify-socket-completion-l06.ps1'
$l06ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l06-result.schema.json'
$l07Source = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.slg'
$l07Expected = Join-Path $root 'scripts/probes/socket-completion/w07-task-cancel.stdout.txt'
$l07Verifier = Join-Path $root 'scripts/verify-socket-completion-l07.ps1'
$l07ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l07-result.schema.json'
$l08Source = Join-Path $root 'scripts/probes/socket-completion/l08-bounded-fair-batch.slg'
$l08Expected = Join-Path $root 'scripts/probes/socket-completion/l08-bounded-fair-batch.stdout.txt'
$l08Verifier = Join-Path $root 'scripts/verify-socket-completion-l08.ps1'
$l08ResultSchema = Join-Path $root 'scripts/contracts/socket-completion-l08-result.schema.json'
$submissionVerifier = Join-Path $root 'scripts/verify-portable-socket-completion-submission.ps1'
$submissionContract = Join-Path $root 'scripts/contracts/portable-socket-completion-submission.json'
$submissionContractSchema = Join-Path $root 'scripts/contracts/portable-socket-completion-submission.schema.json'
$submissionResultSchema = Join-Path $root 'scripts/contracts/portable-socket-completion-submission-result.schema.json'
$submissionFixture = Join-Path $root 'scripts/probes/portable-memory-io/socket-completion-submission-windows.slg'
$submissionExpected = Join-Path $root 'scripts/probes/portable-memory-io/socket-completion-submission-windows.stdout.txt'
$pendingFixture = Join-Path $root 'scripts/probes/portable-memory-io/socket-completion-pending-wake-windows.slg'
$pendingExpected = Join-Path $root 'scripts/probes/portable-memory-io/socket-completion-pending-wake-windows.stdout.txt'
$expectedImplemented = @('W01', 'W02', 'W03', 'W04', 'W05', 'W06', 'W07', 'L01', 'L02', 'L03', 'L04', 'L05', 'L06', 'L07', 'L08', 'B01', 'B02', 'X01', 'X02', 'X03', 'X04', 'X05')

$inputPaths = [ordered]@{
    compiler = $compiler; contract = $contractPath; resultSchema = $resultSchema
    b01Source = $b01Source; b01Expected = $b01ExpectedPath
    x01Source = $x01Source; x01Expected = $x01ExpectedPath; x02Source = $x02Source
    x01ReactorSource = $x01ReactorSource; x01ReactorExpected = $x01ReactorExpectedPath
    x01StreamSource = $x01StreamSource; x01StreamExpected = $x01StreamExpectedPath
    w01Source = $w01Source; w01Verifier = $w01Verifier; w01ResultSchema = $w01ResultSchema
    w04Source = $w04Source; w04Expected = $w04Expected; w04Verifier = $w04Verifier; w04ResultSchema = $w04ResultSchema
    w05Source = $w05Source; w05Expected = $w05Expected; w05Verifier = $w05Verifier; w05ResultSchema = $w05ResultSchema
    w06Source = $w06Source; w06CancelExpected = $w06CancelExpected; w06CompletionExpected = $w06CompletionExpected
    w06Verifier = $w06Verifier; w06ResultSchema = $w06ResultSchema
    w07Source = $w07Source; w07Expected = $w07Expected; w07Verifier = $w07Verifier; w07ResultSchema = $w07ResultSchema
    l01Source = $l01Source; l01Expected = $l01Expected; l01Verifier = $l01Verifier; l01ResultSchema = $l01ResultSchema
    l02Source = $l02Source; l02Expected = $l02Expected; l02Verifier = $l02Verifier; l02ResultSchema = $l02ResultSchema
    l03Source = $l03Source; l03Expected = $l03Expected; l03Verifier = $l03Verifier; l03ResultSchema = $l03ResultSchema
    l04Source = $l04Source; l04Verifier = $l04Verifier; l04ResultSchema = $l04ResultSchema
    l05Source = $l05Source; l05ShimSource = $l05ShimSource; l05Expected = $l05Expected; l05Verifier = $l05Verifier; l05ResultSchema = $l05ResultSchema
    l06Source = $l06Source; l06CancelExpected = $l06CancelExpected; l06CompletionExpected = $l06CompletionExpected
    l06Verifier = $l06Verifier; l06ResultSchema = $l06ResultSchema
    l07Source = $l07Source; l07Expected = $l07Expected; l07Verifier = $l07Verifier; l07ResultSchema = $l07ResultSchema
    l08Source = $l08Source; l08Expected = $l08Expected; l08Verifier = $l08Verifier; l08ResultSchema = $l08ResultSchema
    submissionVerifier = $submissionVerifier; submissionContract = $submissionContract
    submissionContractSchema = $submissionContractSchema; submissionResultSchema = $submissionResultSchema
    submissionFixture = $submissionFixture; submissionExpected = $submissionExpected
    pendingFixture = $pendingFixture; pendingExpected = $pendingExpected
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
function Get-InternalFunctionBody([string]$Ir, [string]$Name) {
    $escaped = [regex]::Escape($Name)
    $match = [regex]::Match($Ir, "(?m)^define internal [^\r\n]+ @$escaped\([^\r\n]*\) #0 \{(?<body>.*?)\r?\n\}", [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($match.Success) { return $match.Groups['body'].Value }
    return ''
}
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

$l02Output = Join-Path $output 'l02'
& $l02Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l02Output 6>&1 | Out-Null
$l02Exit = if ($?) { 0 } else { 1 }
$l02ResultPath = Join-Path $l02Output 'result.json'
$l02ResultText = if (Test-Path -LiteralPath $l02ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l02ResultPath) } else { $null }
$l02Result = if ($null -ne $l02ResultText) { $l02ResultText | ConvertFrom-Json } else { $null }
$l02SchemaOk = $null -ne $l02ResultText -and (Test-Json -Json $l02ResultText -SchemaFile $l02ResultSchema)
$l02Ok = $l02Exit -eq 0 -and $l02SchemaOk -and $null -ne $l02Result -and
    $l02Result.status -ceq 'passed' -and $l02Result.compilerSha256 -ceq $compilerSha256 -and
    $l02Result.inputStable -eq $true -and @($l02Result.inputDrift).Count -eq 0 -and
    @($l02Result.orphanProcessIds).Count -eq 0
if (-not $l02Ok) { Add-Failure 'L02' }
$l02Llvm = Join-Path $l02Output 'l02.ll'
$l02Exe = Join-Path $l02Output 'l02'
$l02Stdout = if ($null -eq $l02Result) { , [string[]]@() } else { , [string[]]@($l02Result.stdout) }
$probeResults.Add([ordered]@{
    caseId = 'L02'; source = 'scripts/probes/socket-completion/l02-pending-receive.slg'; sourceSha256 = (Get-FileHash $l02Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l02Result) { -1 } else { $l02Result.compileExitCode }
    nativeExitCode = if ($null -eq $l02Result) { $null } else { $l02Result.nativeExitCode }
    stdout = $l02Stdout
    llvmAsExitCode = if ($null -eq $l02Result) { $null } else { $l02Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $l02Result) { $null } else { $l02Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l02Llvm -PathType Leaf) { (Get-FileHash $l02Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $l02Exe -PathType Leaf) { (Get-FileHash $l02Exe -Algorithm SHA256).Hash } else { $null }
})

$l03Output = Join-Path $output 'l03'
& $l03Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l03Output 6>&1 | Out-Null
$l03Exit = if ($?) { 0 } else { 1 }
$l03ResultPath = Join-Path $l03Output 'result.json'
$l03ResultText = if (Test-Path -LiteralPath $l03ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l03ResultPath) } else { $null }
$l03Result = if ($null -ne $l03ResultText) { $l03ResultText | ConvertFrom-Json } else { $null }
$l03SchemaOk = $null -ne $l03ResultText -and (Test-Json -Json $l03ResultText -SchemaFile $l03ResultSchema)
$l03Ok = $l03Exit -eq 0 -and $l03SchemaOk -and $null -ne $l03Result -and $l03Result.status -ceq 'passed' -and
    $l03Result.compilerSha256 -ceq $compilerSha256 -and $l03Result.inputStable -eq $true -and
    @($l03Result.inputDrift).Count -eq 0 -and @($l03Result.orphanProcessIds).Count -eq 0
if (-not $l03Ok) { Add-Failure 'L03' }
$l03Llvm = Join-Path $l03Output 'l03.ll'; $l03Exe = Join-Path $l03Output 'l03'
$probeResults.Add([ordered]@{
    caseId = 'L03'; source = 'scripts/probes/socket-completion/l03-partial-send.slg'; sourceSha256 = (Get-FileHash $l03Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l03Result) { -1 } else { $l03Result.compileExitCode }; nativeExitCode = if ($null -eq $l03Result) { $null } else { $l03Result.nativeExitCode }
    stdout = if ($null -eq $l03Result) { @() } else { @($l03Result.stdout) }; llvmAsExitCode = if ($null -eq $l03Result) { $null } else { $l03Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $l03Result) { $null } else { $l03Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l03Llvm -PathType Leaf) { (Get-FileHash $l03Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $l03Exe -PathType Leaf) { (Get-FileHash $l03Exe -Algorithm SHA256).Hash } else { $null }
})

$l04Output = Join-Path $output 'l04'
& $l04Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l04Output 6>&1 | Out-Null
$l04Exit = if ($?) { 0 } else { 1 }
$l04ResultPath = Join-Path $l04Output 'result.json'
$l04ResultText = if (Test-Path -LiteralPath $l04ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l04ResultPath) } else { $null }
$l04Result = if ($null -ne $l04ResultText) { $l04ResultText | ConvertFrom-Json } else { $null }
$l04SchemaOk = $null -ne $l04ResultText -and (Test-Json -Json $l04ResultText -SchemaFile $l04ResultSchema)
$l04Ok = $l04Exit -eq 0 -and $l04SchemaOk -and $null -ne $l04Result -and $l04Result.status -ceq 'passed' -and
    $l04Result.compilerSha256 -ceq $compilerSha256 -and $l04Result.inputStable -eq $true -and
    @($l04Result.inputDrift).Count -eq 0 -and @($l04Result.orphanProcessIds).Count -eq 0 -and
    (@($l04Result.trace) -join "`n") -ceq 'forced-recv-call=2'
if (-not $l04Ok) { Add-Failure 'L04' }
$l04Llvm = Join-Path $l04Output 'l04.ll'
$l04Exe = Join-Path $l04Output 'l04'
$probeResults.Add([ordered]@{
    caseId = 'L04'; source = 'scripts/probes/socket-completion/l04-false-readiness-recv.c'; sourceSha256 = (Get-FileHash $l04Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l04Result) { -1 } else { $l04Result.compileExitCode }
    nativeExitCode = if ($null -eq $l04Result) { $null } else { $l04Result.nativeExitCode }
    stdout = if ($null -eq $l04Result) { @() } else { @($l04Result.stdout) }
    llvmAsExitCode = if ($null -eq $l04Result) { $null } else { $l04Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $l04Result) { $null } else { $l04Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l04Llvm -PathType Leaf) { (Get-FileHash $l04Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $l04Exe -PathType Leaf) { (Get-FileHash $l04Exe -Algorithm SHA256).Hash } else { $null }
})

$l05Output = Join-Path $output 'l05'
& $l05Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l05Output 6>&1 | Out-Null
$l05Exit = if ($?) { 0 } else { 1 }; $l05ResultPath = Join-Path $l05Output 'result.json'
$l05ResultText = if (Test-Path -LiteralPath $l05ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l05ResultPath) } else { $null }
$l05Result = if ($null -ne $l05ResultText) { $l05ResultText | ConvertFrom-Json } else { $null }
$l05SchemaOk = $null -ne $l05ResultText -and (Test-Json -Json $l05ResultText -SchemaFile $l05ResultSchema)
$l05Ok = $l05Exit -eq 0 -and $l05SchemaOk -and $null -ne $l05Result -and $l05Result.status -ceq 'passed' -and $l05Result.compilerSha256 -ceq $compilerSha256 -and $l05Result.inputStable -eq $true -and @($l05Result.inputDrift).Count -eq 0 -and @($l05Result.orphanProcessIds).Count -eq 0
if (-not $l05Ok) { Add-Failure 'L05' }
$l05Llvm = Join-Path $l05Output 'l05.ll'; $l05Exe = Join-Path $l05Output 'l05'
$probeResults.Add([ordered]@{
    caseId = 'L05'; source = 'scripts/probes/socket-completion/l05-pending-reset.slg'; sourceSha256 = (Get-FileHash $l05Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l05Result) { -1 } else { $l05Result.compileExitCode }; nativeExitCode = if ($null -eq $l05Result) { $null } else { $l05Result.nativeExitCode }; stdout = if ($null -eq $l05Result) { @() } else { @($l05Result.stdout) }
    llvmAsExitCode = if ($null -eq $l05Result) { $null } else { $l05Result.llvmAsExitCode }; closureExitCode = if ($null -eq $l05Result) { $null } else { $l05Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l05Llvm -PathType Leaf) { (Get-FileHash $l05Llvm -Algorithm SHA256).Hash } else { $null }; outputSha256 = if (Test-Path -LiteralPath $l05Exe -PathType Leaf) { (Get-FileHash $l05Exe -Algorithm SHA256).Hash } else { $null }
})

$l06Output = Join-Path $output 'l06'
& $l06Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l06Output 6>&1 | Out-Null
$l06Exit = if ($?) { 0 } else { 1 }; $l06ResultPath = Join-Path $l06Output 'result.json'
$l06ResultText = if (Test-Path -LiteralPath $l06ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l06ResultPath) } else { $null }
$l06Result = if ($null -ne $l06ResultText) { $l06ResultText | ConvertFrom-Json } else { $null }
$l06SchemaOk = $null -ne $l06ResultText -and (Test-Json -Json $l06ResultText -SchemaFile $l06ResultSchema)
$l06Ok = $l06Exit -eq 0 -and $l06SchemaOk -and $null -ne $l06Result -and
    $l06Result.status -ceq 'passed' -and $l06Result.compilerSha256 -ceq $compilerSha256 -and
    $l06Result.inputStable -eq $true -and @($l06Result.inputDrift).Count -eq 0 -and
    @($l06Result.orphanProcessIds).Count -eq 0 -and @($l06Result.runs).Count -eq 2
if (-not $l06Ok) { Add-Failure 'L06' }
$l06Llvm = Join-Path $l06Output 'l06.ll'; $l06Exe = Join-Path $l06Output 'l06'
$l06Stdout = [string[]]@()
if ($null -ne $l06Result) {
    $l06Stdout = [string[]]@($l06Result.runs | ForEach-Object { $variant = $_.variant; @($_.stdout) | ForEach-Object { "$variant`:$_" } })
}
$l06NativeExit = if ($null -eq $l06Result -or @($l06Result.runs | Where-Object exitCode -ne 0).Count -ne 0) { $null } else { 0 }
$probeResults.Add([ordered]@{
    caseId = 'L06'; source = 'scripts/probes/socket-completion/w06-cancel-completion-race.slg'; sourceSha256 = (Get-FileHash $l06Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l06Result) { -1 } else { $l06Result.compileExitCode }; nativeExitCode = $l06NativeExit; stdout = $l06Stdout
    llvmAsExitCode = if ($null -eq $l06Result) { $null } else { $l06Result.llvmAsExitCode }; closureExitCode = if ($null -eq $l06Result) { $null } else { $l06Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l06Llvm -PathType Leaf) { (Get-FileHash $l06Llvm -Algorithm SHA256).Hash } else { $null }; outputSha256 = if (Test-Path -LiteralPath $l06Exe -PathType Leaf) { (Get-FileHash $l06Exe -Algorithm SHA256).Hash } else { $null }
})

$l07Output = Join-Path $output 'l07'
& $l07Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l07Output 6>&1 | Out-Null
$l07Exit = if ($?) { 0 } else { 1 }; $l07ResultPath = Join-Path $l07Output 'result.json'
$l07ResultText = if (Test-Path -LiteralPath $l07ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l07ResultPath) } else { $null }
$l07Result = if ($null -ne $l07ResultText) { $l07ResultText | ConvertFrom-Json } else { $null }
$l07SchemaOk = $null -ne $l07ResultText -and (Test-Json -Json $l07ResultText -SchemaFile $l07ResultSchema)
$l07Ok = $l07Exit -eq 0 -and $l07SchemaOk -and $null -ne $l07Result -and
    $l07Result.status -ceq 'passed' -and $l07Result.compilerSha256 -ceq $compilerSha256 -and
    $l07Result.inputStable -eq $true -and @($l07Result.inputDrift).Count -eq 0 -and
    @($l07Result.orphanProcessIds).Count -eq 0 -and $l07Result.run.peerObservedEof -eq $true
if (-not $l07Ok) { Add-Failure 'L07' }
$l07Llvm = Join-Path $l07Output 'l07.ll'; $l07Exe = Join-Path $l07Output 'l07'
$probeResults.Add([ordered]@{
    caseId = 'L07'; source = 'scripts/probes/socket-completion/w07-task-cancel.slg'; sourceSha256 = (Get-FileHash $l07Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l07Result) { -1 } else { $l07Result.compileExitCode }; nativeExitCode = if ($null -eq $l07Result) { $null } else { $l07Result.run.exitCode }; stdout = if ($null -eq $l07Result) { @() } else { @($l07Result.run.stdout) }
    llvmAsExitCode = if ($null -eq $l07Result) { $null } else { $l07Result.llvmAsExitCode }; closureExitCode = if ($null -eq $l07Result) { $null } else { $l07Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l07Llvm -PathType Leaf) { (Get-FileHash $l07Llvm -Algorithm SHA256).Hash } else { $null }; outputSha256 = if (Test-Path -LiteralPath $l07Exe -PathType Leaf) { (Get-FileHash $l07Exe -Algorithm SHA256).Hash } else { $null }
})

$l08Output = Join-Path $output 'l08'
& $l08Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l08Output 6>&1 | Out-Null
$l08Exit = if ($?) { 0 } else { 1 }; $l08ResultPath = Join-Path $l08Output 'result.json'
$l08ResultText = if (Test-Path -LiteralPath $l08ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l08ResultPath) } else { $null }
$l08Result = if ($null -ne $l08ResultText) { $l08ResultText | ConvertFrom-Json } else { $null }
$l08SchemaOk = $null -ne $l08ResultText -and (Test-Json -Json $l08ResultText -SchemaFile $l08ResultSchema)
$l08Ok = $l08Exit -eq 0 -and $l08SchemaOk -and $null -ne $l08Result -and
    $l08Result.status -ceq 'passed' -and $l08Result.compilerSha256 -ceq $compilerSha256 -and
    $l08Result.inputStable -eq $true -and @($l08Result.inputDrift).Count -eq 0 -and
    @($l08Result.orphanProcessIds).Count -eq 0 -and @($l08Result.run.peerSent).Count -eq 2
if (-not $l08Ok) { Add-Failure 'L08' }
$l08Llvm = Join-Path $l08Output 'l08.ll'; $l08Exe = Join-Path $l08Output 'l08'
$probeResults.Add([ordered]@{
    caseId = 'L08'; source = 'scripts/probes/socket-completion/l08-bounded-fair-batch.slg'; sourceSha256 = (Get-FileHash $l08Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l08Result) { -1 } else { $l08Result.compileExitCode }; nativeExitCode = if ($null -eq $l08Result) { $null } else { $l08Result.run.exitCode }; stdout = if ($null -eq $l08Result) { @() } else { @($l08Result.run.stdout) }
    llvmAsExitCode = if ($null -eq $l08Result) { $null } else { $l08Result.llvmAsExitCode }; closureExitCode = if ($null -eq $l08Result) { $null } else { $l08Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l08Llvm -PathType Leaf) { (Get-FileHash $l08Llvm -Algorithm SHA256).Hash } else { $null }; outputSha256 = if (Test-Path -LiteralPath $l08Exe -PathType Leaf) { (Get-FileHash $l08Exe -Algorithm SHA256).Hash } else { $null }
})

$w07Output = Join-Path $output 'w07'
& $w07Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $w07Output 6>&1 | Out-Null
$w07Exit = if ($?) { 0 } else { 1 }
$w07ResultPath = Join-Path $w07Output 'result.json'
$w07ResultText = if (Test-Path -LiteralPath $w07ResultPath -PathType Leaf) { [IO.File]::ReadAllText($w07ResultPath) } else { $null }
$w07Result = if ($null -ne $w07ResultText) { $w07ResultText | ConvertFrom-Json } else { $null }
$w07SchemaOk = $null -ne $w07ResultText -and (Test-Json -Json $w07ResultText -SchemaFile $w07ResultSchema)
$w07Ok = $w07Exit -eq 0 -and $w07SchemaOk -and $null -ne $w07Result -and
    $w07Result.status -ceq 'passed' -and $w07Result.compilerSha256 -ceq $compilerSha256 -and
    $w07Result.inputStable -eq $true -and @($w07Result.inputDrift).Count -eq 0 -and
    @($w07Result.orphanProcessIds).Count -eq 0 -and $w07Result.run.peerObservedEof -eq $true
if (-not $w07Ok) { Add-Failure 'W07' }
$w07Llvm = Join-Path $w07Output 'w07.ll'
$w07Exe = Join-Path $w07Output 'w07.exe'
$probeResults.Add([ordered]@{
    caseId = 'W07'; source = 'scripts/probes/socket-completion/w07-task-cancel.slg'; sourceSha256 = (Get-FileHash $w07Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $w07Result) { -1 } else { $w07Result.compileExitCode }
    nativeExitCode = if ($null -eq $w07Result) { $null } else { $w07Result.run.exitCode }
    stdout = if ($null -eq $w07Result) { @() } else { @($w07Result.run.stdout) }
    llvmAsExitCode = if ($null -eq $w07Result) { $null } else { $w07Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $w07Result) { $null } else { $w07Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $w07Llvm -PathType Leaf) { (Get-FileHash $w07Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $w07Exe -PathType Leaf) { (Get-FileHash $w07Exe -Algorithm SHA256).Hash } else { $null }
})

$l01Output = Join-Path $output 'l01'
& $l01Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $l01Output 6>&1 | Out-Null
$l01Exit = if ($?) { 0 } else { 1 }
$l01ResultPath = Join-Path $l01Output 'result.json'
$l01ResultText = if (Test-Path -LiteralPath $l01ResultPath -PathType Leaf) { [IO.File]::ReadAllText($l01ResultPath) } else { $null }
$l01Result = if ($null -ne $l01ResultText) { $l01ResultText | ConvertFrom-Json } else { $null }
$l01SchemaOk = $null -ne $l01ResultText -and (Test-Json -Json $l01ResultText -SchemaFile $l01ResultSchema)
$l01Ok = $l01Exit -eq 0 -and $l01SchemaOk -and $null -ne $l01Result -and
    $l01Result.status -ceq 'passed' -and $l01Result.compilerSha256 -ceq $compilerSha256 -and
    $l01Result.inputStable -eq $true -and @($l01Result.inputDrift).Count -eq 0 -and
    @($l01Result.orphanProcessIds).Count -eq 0
if (-not $l01Ok) { Add-Failure 'L01' }
$l01Llvm = Join-Path $l01Output 'l01.ll'
$l01Exe = Join-Path $l01Output 'l01'
$l01Stdout = if ($null -eq $l01Result) { , [string[]]@() } else { , [string[]]@($l01Result.stdout) }
$probeResults.Add([ordered]@{
    caseId = 'L01'; source = 'scripts/probes/socket-completion/l01-direct-receive.slg'; sourceSha256 = (Get-FileHash $l01Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $l01Result) { -1 } else { $l01Result.compileExitCode }
    nativeExitCode = if ($null -eq $l01Result) { $null } else { $l01Result.nativeExitCode }
    stdout = $l01Stdout
    llvmAsExitCode = if ($null -eq $l01Result) { $null } else { $l01Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $l01Result) { $null } else { $l01Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $l01Llvm -PathType Leaf) { (Get-FileHash $l01Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $l01Exe -PathType Leaf) { (Get-FileHash $l01Exe -Algorithm SHA256).Hash } else { $null }
})

$w04Output = Join-Path $output 'w04'
& $w04Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $w04Output 6>&1 | Out-Null
$w04Exit = if ($?) { 0 } else { 1 }
$w04ResultPath = Join-Path $w04Output 'result.json'
$w04ResultText = if (Test-Path -LiteralPath $w04ResultPath -PathType Leaf) { [IO.File]::ReadAllText($w04ResultPath) } else { $null }
$w04Result = if ($null -ne $w04ResultText) { $w04ResultText | ConvertFrom-Json } else { $null }
$w04SchemaOk = $null -ne $w04ResultText -and (Test-Json -Json $w04ResultText -SchemaFile $w04ResultSchema)
$w04Ok = $w04Exit -eq 0 -and $w04SchemaOk -and $null -ne $w04Result -and
    $w04Result.status -ceq 'passed' -and $w04Result.compilerSha256 -ceq $compilerSha256 -and
    $w04Result.inputStable -eq $true -and @($w04Result.inputDrift).Count -eq 0 -and
    @($w04Result.orphanProcessIds).Count -eq 0
if (-not $w04Ok) { Add-Failure 'W04' }
$w04Llvm = Join-Path $w04Output 'w04.ll'
$w04Exe = Join-Path $w04Output 'w04.exe'
$w04Stdout = if ($null -eq $w04Result) { , [string[]]@() } else { , [string[]]@($w04Result.stdout) }
$probeResults.Add([ordered]@{
    caseId = 'W04'; source = 'scripts/probes/socket-completion/w04-partial-send.slg'; sourceSha256 = (Get-FileHash $w04Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $w04Result) { -1 } else { $w04Result.compileExitCode }
    nativeExitCode = if ($null -eq $w04Result) { $null } else { $w04Result.nativeExitCode }
    stdout = $w04Stdout
    llvmAsExitCode = if ($null -eq $w04Result) { $null } else { $w04Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $w04Result) { $null } else { $w04Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $w04Llvm -PathType Leaf) { (Get-FileHash $w04Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $w04Exe -PathType Leaf) { (Get-FileHash $w04Exe -Algorithm SHA256).Hash } else { $null }
})

$w05Output = Join-Path $output 'w05'
& $w05Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $w05Output 6>&1 | Out-Null
$w05Exit = if ($?) { 0 } else { 1 }
$w05ResultPath = Join-Path $w05Output 'result.json'
$w05ResultText = if (Test-Path -LiteralPath $w05ResultPath -PathType Leaf) { [IO.File]::ReadAllText($w05ResultPath) } else { $null }
$w05Result = if ($null -ne $w05ResultText) { $w05ResultText | ConvertFrom-Json } else { $null }
$w05SchemaOk = $null -ne $w05ResultText -and (Test-Json -Json $w05ResultText -SchemaFile $w05ResultSchema)
$w05Ok = $w05Exit -eq 0 -and $w05SchemaOk -and $null -ne $w05Result -and
    $w05Result.status -ceq 'passed' -and $w05Result.compilerSha256 -ceq $compilerSha256 -and
    $w05Result.inputStable -eq $true -and @($w05Result.inputDrift).Count -eq 0 -and
    @($w05Result.orphanProcessIds).Count -eq 0
if (-not $w05Ok) { Add-Failure 'W05' }
$w05Llvm = Join-Path $w05Output 'w05.ll'
$w05Exe = Join-Path $w05Output 'w05.exe'
$probeResults.Add([ordered]@{
    caseId = 'W05'; source = 'scripts/probes/socket-completion/w05-pending-reset.slg'; sourceSha256 = (Get-FileHash $w05Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $w05Result) { -1 } else { $w05Result.compileExitCode }
    nativeExitCode = if ($null -eq $w05Result) { $null } else { $w05Result.nativeExitCode }
    stdout = if ($null -eq $w05Result) { @() } else { @($w05Result.stdout) }
    llvmAsExitCode = if ($null -eq $w05Result) { $null } else { $w05Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $w05Result) { $null } else { $w05Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $w05Llvm -PathType Leaf) { (Get-FileHash $w05Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $w05Exe -PathType Leaf) { (Get-FileHash $w05Exe -Algorithm SHA256).Hash } else { $null }
})

$w06Output = Join-Path $output 'w06'
& $w06Verifier -Compiler $compiler -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $w06Output 6>&1 | Out-Null
$w06Exit = if ($?) { 0 } else { 1 }
$w06ResultPath = Join-Path $w06Output 'result.json'
$w06ResultText = if (Test-Path -LiteralPath $w06ResultPath -PathType Leaf) { [IO.File]::ReadAllText($w06ResultPath) } else { $null }
$w06Result = if ($null -ne $w06ResultText) { $w06ResultText | ConvertFrom-Json } else { $null }
$w06SchemaOk = $null -ne $w06ResultText -and (Test-Json -Json $w06ResultText -SchemaFile $w06ResultSchema)
$w06Ok = $w06Exit -eq 0 -and $w06SchemaOk -and $null -ne $w06Result -and
    $w06Result.status -ceq 'passed' -and $w06Result.compilerSha256 -ceq $compilerSha256 -and
    $w06Result.inputStable -eq $true -and @($w06Result.inputDrift).Count -eq 0 -and
    @($w06Result.orphanProcessIds).Count -eq 0 -and @($w06Result.runs).Count -eq 2
if (-not $w06Ok) { Add-Failure 'W06' }
$w06Llvm = Join-Path $w06Output 'w06.ll'
$w06Exe = Join-Path $w06Output 'w06.exe'
$w06Stdout = [string[]]@()
if ($null -ne $w06Result) {
    $w06Stdout = [string[]]@($w06Result.runs | ForEach-Object { $variant = $_.variant; @($_.stdout) | ForEach-Object { "$variant`:$_" } })
}
$w06NativeExit = if ($null -eq $w06Result -or @($w06Result.runs | Where-Object exitCode -ne 0).Count -ne 0) { $null } else { 0 }
$probeResults.Add([ordered]@{
    caseId = 'W06'; source = 'scripts/probes/socket-completion/w06-cancel-completion-race.slg'; sourceSha256 = (Get-FileHash $w06Source -Algorithm SHA256).Hash
    compileExitCode = if ($null -eq $w06Result) { -1 } else { $w06Result.compileExitCode }
    nativeExitCode = $w06NativeExit; stdout = $w06Stdout
    llvmAsExitCode = if ($null -eq $w06Result) { $null } else { $w06Result.llvmAsExitCode }
    closureExitCode = if ($null -eq $w06Result) { $null } else { $w06Result.closureExitCode }
    llvmSha256 = if (Test-Path -LiteralPath $w06Llvm -PathType Leaf) { (Get-FileHash $w06Llvm -Algorithm SHA256).Hash } else { $null }
    outputSha256 = if (Test-Path -LiteralPath $w06Exe -PathType Leaf) { (Get-FileHash $w06Exe -Algorithm SHA256).Hash } else { $null }
})

$submissionOutput = Join-Path $output 'w02-w03'
$submissionCompilerArgument = [IO.Path]::GetRelativePath($root, $compiler)
$submissionOutputArgument = [IO.Path]::GetRelativePath($root, $submissionOutput)
& $submissionVerifier -Compiler $submissionCompilerArgument -ExpectedCompilerSha256 $compilerSha256 -OutputDirectory $submissionOutputArgument 6>&1 | Out-Null
$submissionExit = if ($?) { 0 } else { 1 }
$submissionResultPath = Join-Path $submissionOutput 'result.json'
$submissionResultText = if (Test-Path -LiteralPath $submissionResultPath -PathType Leaf) { [IO.File]::ReadAllText($submissionResultPath) } else { $null }
$submissionResult = if ($null -ne $submissionResultText) { $submissionResultText | ConvertFrom-Json } else { $null }
$submissionSchemaOk = $null -ne $submissionResultText -and (Test-Json -Json $submissionResultText -SchemaFile $submissionResultSchema)
$submissionCommonOk = $submissionExit -eq 0 -and $submissionSchemaOk -and
    $null -ne $submissionResult -and $submissionResult.status -ceq 'passed' -and
    $submissionResult.completed -eq 1 -and $submissionResult.total -eq 1 -and
    $submissionResult.compilerSha256 -ceq $compilerSha256 -and $submissionResult.inputStable -eq $true -and
    @($submissionResult.inputDrift).Count -eq 0 -and @($submissionResult.orphanProcessIds).Count -eq 0 -and
    $submissionResult.payloadCopyFree -eq $true -and $submissionResult.dequeueOwnerTransferVerified -eq $true -and
    $submissionResult.waiterJoinedBeforeExit -eq $true
$w02Ok = $submissionCommonOk -and $submissionResult.compileExitCode -eq 0 -and
    $submissionResult.nativeExitCode -eq 0 -and $submissionResult.llvmAsExitCode -eq 0 -and
    $submissionResult.directCallClosureExitCode -eq 0 -and
    (@($submissionResult.stdout) -join "`n") -ceq (@(Get-Content $submissionExpected) -join "`n")
$w03Ok = $submissionCommonOk -and $submissionResult.pendingCompileExitCode -eq 0 -and
    $submissionResult.pendingNativeExitCode -eq 0 -and $submissionResult.pendingLlvmAsExitCode -eq 0 -and
    $submissionResult.pendingDirectCallClosureExitCode -eq 0 -and $submissionResult.waiterThreadDelta -eq 1 -and
    $submissionResult.waiterThreadCallSites -eq 1 -and
    (@($submissionResult.pendingStdout) -join "`n") -ceq (@(Get-Content $pendingExpected) -join "`n")
if (-not $w02Ok) { Add-Failure 'W02' }
if (-not $w03Ok) { Add-Failure 'W03' }
foreach ($submissionCase in @(
    [ordered]@{ id = 'W02'; source = $submissionFixture; stdout = if ($null -eq $submissionResult) { @() } else { @($submissionResult.stdout) }; compile = if ($null -eq $submissionResult) { -1 } else { $submissionResult.compileExitCode }; native = if ($null -eq $submissionResult) { $null } else { $submissionResult.nativeExitCode }; llvmAs = if ($null -eq $submissionResult) { $null } else { $submissionResult.llvmAsExitCode }; closure = if ($null -eq $submissionResult) { $null } else { $submissionResult.directCallClosureExitCode }; llvm = 'socket-completion-submission.ll'; exe = 'socket-completion-submission.exe' },
    [ordered]@{ id = 'W03'; source = $pendingFixture; stdout = if ($null -eq $submissionResult) { @() } else { @($submissionResult.pendingStdout) }; compile = if ($null -eq $submissionResult) { -1 } else { $submissionResult.pendingCompileExitCode }; native = if ($null -eq $submissionResult) { $null } else { $submissionResult.pendingNativeExitCode }; llvmAs = if ($null -eq $submissionResult) { $null } else { $submissionResult.pendingLlvmAsExitCode }; closure = if ($null -eq $submissionResult) { $null } else { $submissionResult.pendingDirectCallClosureExitCode }; llvm = 'socket-completion-pending-wake.ll'; exe = 'socket-completion-pending-wake.exe' }
)) {
    $submissionLlvm = Join-Path $submissionOutput $submissionCase.llvm
    $submissionExe = Join-Path $submissionOutput $submissionCase.exe
    $probeResults.Add([ordered]@{
        caseId = $submissionCase.id; source = [IO.Path]::GetRelativePath($root, $submissionCase.source).Replace('\', '/'); sourceSha256 = (Get-FileHash $submissionCase.source -Algorithm SHA256).Hash
        compileExitCode = $submissionCase.compile; nativeExitCode = $submissionCase.native; stdout = @($submissionCase.stdout)
        llvmAsExitCode = $submissionCase.llvmAs; closureExitCode = $submissionCase.closure
        llvmSha256 = if (Test-Path -LiteralPath $submissionLlvm -PathType Leaf) { (Get-FileHash $submissionLlvm -Algorithm SHA256).Hash } else { $null }
        outputSha256 = if (Test-Path -LiteralPath $submissionExe -PathType Leaf) { (Get-FileHash $submissionExe -Algorithm SHA256).Hash } else { $null }
    })
}

$positiveNativeCaseIds = @('W01', 'W02', 'W03', 'W04', 'W05', 'W06', 'W07', 'L01', 'L02', 'L03', 'L04', 'L05', 'L06', 'L07', 'L08')
$positiveNativeProbes = @($probeResults | Where-Object { $_.caseId -in $positiveNativeCaseIds })
$x03Ok = $positiveNativeProbes.Count -eq $positiveNativeCaseIds.Count -and
    @($positiveNativeProbes.caseId | Sort-Object -Unique).Count -eq $positiveNativeCaseIds.Count -and
    @($positiveNativeProbes | Where-Object { $_.compileExitCode -ne 0 -or $_.nativeExitCode -ne 0 -or $_.llvmAsExitCode -ne 0 -or $_.closureExitCode -ne 0 }).Count -eq 0
if (-not $x03Ok) { Add-Failure 'X03' }
$probeResults.Add([ordered]@{
    caseId = 'X03'; source = 'scripts/contracts/socket-completion-reactor.json'; sourceSha256 = (Get-FileHash $contractPath -Algorithm SHA256).Hash
    compileExitCode = if ($x03Ok) { 0 } else { 1 }; nativeExitCode = if ($x03Ok) { 0 } else { 1 }
    stdout = @("positive-native=$($positiveNativeProbes.Count)/$($positiveNativeCaseIds.Count),llvm-as=$($x03Ok.ToString().ToLowerInvariant()),v004=$($x03Ok.ToString().ToLowerInvariant())")
    llvmAsExitCode = if ($x03Ok) { 0 } else { 1 }; closureExitCode = if ($x03Ok) { 0 } else { 1 }; llvmSha256 = $null; outputSha256 = $null
})

$x04Functions = @('sollang_platform_socket_completion_submit', 'sollang_platform_socket_completion_cancel', 'sollang_platform_socket_completion_dequeue', 'sollang_platform_socket_completion_request_cancel_all', 'sollang_socket_completion_waiter')
$x04Bodies = [Collections.Generic.List[string]]::new()
foreach ($llvmPath in @($w06Llvm, $l08Llvm)) {
    $platformIr = if (Test-Path -LiteralPath $llvmPath -PathType Leaf) { [IO.File]::ReadAllText($llvmPath) } else { '' }
    foreach ($functionName in $x04Functions) {
        $body = Get-InternalFunctionBody $platformIr $functionName
        if ($body.Length -ne 0) { $x04Bodies.Add($body) }
    }
}
$x04AllocCalls = @($x04Bodies | ForEach-Object { [regex]::Matches($_, 'call (?:ptr|i64) @(?:sollang_alloc|malloc|realloc)\(').Count } | Measure-Object -Sum).Sum
$x04CopyCalls = @($x04Bodies | ForEach-Object { [regex]::Matches($_, '@llvm\.(?:memcpy|memmove)').Count } | Measure-Object -Sum).Sum
$x04Ok = $x04Bodies.Count -eq 10 -and $x04AllocCalls -eq 0 -and $x04CopyCalls -eq 0
if (-not $x04Ok) { Add-Failure 'X04' }
$probeResults.Add([ordered]@{
    caseId = 'X04'; source = 'scripts/contracts/socket-completion-reactor.json'; sourceSha256 = (Get-FileHash $contractPath -Algorithm SHA256).Hash
    compileExitCode = if ($x04Ok) { 0 } else { 1 }; nativeExitCode = if ($x04Ok) { 0 } else { 1 }
    stdout = @("platform-functions=$($x04Bodies.Count)/10,steady-alloc=$x04AllocCalls,payload-copy=$x04CopyCalls")
    llvmAsExitCode = if ($x04Ok) { 0 } else { 1 }; closureExitCode = if ($x04Ok) { 0 } else { 1 }; llvmSha256 = $null; outputSha256 = $null
})

$x05WindowsOk = $null -ne $w07Result -and $w07Result.status -ceq 'passed' -and $w07Result.run.peerObservedEof -eq $true -and
    $w07Result.irAssertions.taskCancelRequestsWithoutFree -eq $true -and $w07Result.irAssertions.cancelCallbackTwoPhase -eq $true -and
    $w07Result.irAssertions.closeJoinsBeforeOwnerCleanup -eq $true -and $w07Result.irAssertions.payloadCopyFree -eq $true -and
    @($w07Result.failureIds).Count -eq 0 -and @($w07Result.orphanProcessIds).Count -eq 0
$x05LinuxOk = $null -ne $l07Result -and $l07Result.status -ceq 'passed' -and $l07Result.run.peerObservedEof -eq $true -and
    $l07Result.irAssertions.taskCancelRequestsWithoutFree -eq $true -and $l07Result.irAssertions.cancelCallbackTwoPhase -eq $true -and
    $l07Result.irAssertions.closeJoinsBeforeOwnerCleanup -eq $true -and $l07Result.irAssertions.epollRegistrationRemovedByClose -eq $true -and
    $l07Result.irAssertions.payloadCopyFree -eq $true -and @($l07Result.failureIds).Count -eq 0 -and @($l07Result.orphanProcessIds).Count -eq 0
$x05Ok = $x05WindowsOk -and $x05LinuxOk
if (-not $x05Ok) { Add-Failure 'X05' }
$probeResults.Add([ordered]@{
    caseId = 'X05'; source = 'scripts/contracts/socket-completion-reactor.json'; sourceSha256 = (Get-FileHash $contractPath -Algorithm SHA256).Hash
    compileExitCode = if ($x05Ok) { 0 } else { 1 }; nativeExitCode = if ($x05Ok) { 0 } else { 1 }
    stdout = @("windows-cancel-drain-close=$($x05WindowsOk.ToString().ToLowerInvariant()),linux-cancel-drain-close=$($x05LinuxOk.ToString().ToLowerInvariant())")
    llvmAsExitCode = if ($x05Ok) { 0 } else { 1 }; closureExitCode = if ($x05Ok) { 0 } else { 1 }; llvmSha256 = $null; outputSha256 = $null
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
$scalarStdoutCaseIds = @($result.probes | Where-Object { $_.stdout -isnot [Array] } | ForEach-Object caseId)
if ($scalarStdoutCaseIds.Count -ne 0) {
    throw "socket completion focused probe stdout must remain arrays: $($scalarStdoutCaseIds -join ', ')"
}
$resultPath = Join-Path $output 'result.json'
$json = $result | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($resultPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
if (-not (Test-Json -Json $json -SchemaFile $resultSchema)) { throw 'socket completion focused result violates schema' }
if ($result.probes.Count -ne 24 -or $result.passedCaseIds.Count -ne $result.completed -or
    @($result.passedCaseIds | Where-Object { $_ -notin $expectedImplemented }).Count -ne 0 -or
    ($result.completionStatus -ceq 'complete' -and $result.completed -ne $result.total)) { throw 'socket completion focused result count and ID consistency failed' }
$json
if ($failures.Count -ne 0) { exit 1 }
