[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$CancellationRequestPath = '',
    [string]$CancellationRunId = '',
    [string]$CancellationAcknowledgementPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$compiler = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }))
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
$scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "output must be under artifacts/scratch: $output"
}
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) {
        throw "output must be new or empty: $output"
    }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

. (Join-Path $root 'scripts/verification-process.ps1')
$contractPath = Join-Path $root 'scripts/contracts/portable-async-socket-adapter.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/portable-async-socket-adapter.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/portable-async-socket-current-result.schema.json'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$resultPath = Join-Path $output 'result.json'
$expectedHash = $ExpectedCompilerSha256.ToUpperInvariant()
$compilerIsManagedDll = [IO.Path]::GetExtension($compiler).Equals('.dll', [StringComparison]::OrdinalIgnoreCase)
$compilerCommand = $compiler
[string[]]$compilerArgumentPrefix = @()
if ($compilerIsManagedDll) {
    $compilerCommand = (Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $compilerArgumentPrefix = @($compiler)
}

function Exit-IfCancellationRequested {
    if ([string]::IsNullOrWhiteSpace($CancellationRequestPath) -or
        -not (Test-Path -LiteralPath $CancellationRequestPath -PathType Leaf)) { return }
    if ([string]::IsNullOrWhiteSpace($CancellationRunId) -or [string]::IsNullOrWhiteSpace($CancellationAcknowledgementPath)) {
        throw 'cancellation request requires run ID and acknowledgement path'
    }
    $request = Get-Content -LiteralPath $CancellationRequestPath -Raw | ConvertFrom-Json
    if ($request.schemaVersion -ne 1 -or $request.runId -cne $CancellationRunId -or [string]::IsNullOrWhiteSpace([string]$request.requestedAtUtc)) {
        throw 'cancellation request does not match the portable async socket run'
    }
    $acknowledgement = [ordered]@{
        schemaVersion = 1
        runId = $CancellationRunId
        targetProcessId = $PID
        observedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
    }
    $acknowledgementDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($CancellationAcknowledgementPath))
    [IO.Directory]::CreateDirectory($acknowledgementDirectory) | Out-Null
    $temporaryAcknowledgement = [IO.Path]::Combine($acknowledgementDirectory, ([IO.Path]::GetFileName($CancellationAcknowledgementPath) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'))
    [IO.File]::WriteAllText($temporaryAcknowledgement, (($acknowledgement | ConvertTo-Json -Depth 3) + "`n"), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryAcknowledgement -Destination $CancellationAcknowledgementPath
    exit 130
}

$contractRaw = [IO.File]::ReadAllText($contractPath)
if (-not ($contractRaw | Test-Json -SchemaFile $contractSchemaPath)) { throw 'portable async socket contract violates its schema' }
$contract = $contractRaw | ConvertFrom-Json
$cases = @($contract.probes)
if ($cases.Count -ne 3) { throw "portable async socket case count drifted: $($cases.Count)" }
$expectedCaseIds = @('direct-owner-return', 'pending-await-owner-return', 'cooperative-cancellation-owner-return')
if ((@($cases.id | Sort-Object) -join '|') -cne (@($expectedCaseIds | Sort-Object) -join '|')) {
    throw "portable async socket case identities drifted: $($cases.id -join ',')"
}
$managedWindowsPassed = @($contract.matrix.cases | Where-Object {
    $_.platform -ceq 'managed-windows-x64' -and $_.status -ceq 'passed'
} | ForEach-Object id | Sort-Object)
if (($managedWindowsPassed -join '|') -cne 'W01|W02|W03') {
    throw "portable async socket managed Windows passed identities drifted: $($managedWindowsPassed -join ',')"
}

$inputPaths = @($PSCommandPath, $contractPath, $contractSchemaPath, $resultSchemaPath, $formatVerifier, $closureVerifier,
    (Join-Path $root 'stdlib/std/io/socket.slg'), (Join-Path $root 'stdlib/std/net/socket.slg'),
    (Join-Path $root 'stdlib/sys/runtime/socket.slg'), $compiler)
$inputPaths += @($cases | ForEach-Object { Join-Path $root $_.source })
foreach ($path in @($inputPaths) + @($llvmAs)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "required input is missing: $path" }
}
$inputHashes = [ordered]@{}
foreach ($path in $inputPaths) {
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    $inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$compilerHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
if ($compilerHash -cne $expectedHash) { throw "compiler hash mismatch: expected=$expectedHash actual=$compilerHash" }

foreach ($source in @($cases | ForEach-Object { Join-Path $root $_.source }) + @((Join-Path $root 'stdlib/std/io/socket.slg'))) {
    $format = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $formatVerifier, '-Check', '-Source', $source) -WorkingDirectory $root -Description "portable async socket format $source" -TimeoutMilliseconds 120000
    if ($format.ExitCode -ne 0) { throw "authoritative format failed for $source`:`n$($format.Stderr)$($format.Stdout)" }
}

$records = [Collections.Generic.List[object]]::new()
$failureIds = [Collections.Generic.List[string]]::new()
foreach ($case in $cases) {
    Exit-IfCancellationRequested
    $source = Join-Path $root $case.source
    $exe = Join-Path $output ($case.id + '.exe')
    $llvm = [IO.Path]::ChangeExtension($exe, '.ll')
    $bitcode = [IO.Path]::ChangeExtension($exe, '.bc')
    $expected = [string]$case.expected[0]
    $compileArguments = @('build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot)
    if (-not $compilerIsManagedDll) { $compileArguments += @('--stdlib', (Join-Path $root 'stdlib'), '--jobs', '4') }
    $compileArguments += @('-O0', '--keep-temps')
    $compile = Invoke-VerificationProcessCapture -FilePath $compilerCommand -ArgumentList ($compilerArgumentPrefix + $compileArguments) -WorkingDirectory $root -Description "portable async socket compile $($case.id)" -TimeoutMilliseconds 120000
    $diagnostics = $compile.Stderr + $compile.Stdout
    $warningCount = ([regex]::Matches($diagnostics, '(?im)^.*\bwarning\b.*$')).Count
    $noteCount = ([regex]::Matches($diagnostics, '(?im)^.*\bnote\b.*$')).Count
    $llvmAsExit = $null
    $closureExit = $null
    $nativeExit = $null
    $stdout = ''
    if ($compile.ExitCode -eq 0 -and $warningCount -eq 0 -and $noteCount -eq 0) {
        $assembly = Invoke-VerificationProcessCapture -FilePath $llvmAs -ArgumentList @($llvm, '-o', $bitcode) -WorkingDirectory $root -Description "portable async socket llvm-as $($case.id)" -TimeoutMilliseconds 120000
        $llvmAsExit = $assembly.ExitCode
        $closure = Invoke-VerificationProcessCapture -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -WorkingDirectory $root -Description "portable async socket closure $($case.id)" -TimeoutMilliseconds 120000
        $closureExit = $closure.ExitCode
        if ($llvmAsExit -eq 0 -and $closureExit -eq 0) {
            $native = Invoke-VerificationProcessCapture -FilePath $exe -ArgumentList @() -WorkingDirectory $root -Description "portable async socket native $($case.id)" -TimeoutMilliseconds 15000
            $nativeExit = $native.ExitCode
            $stdout = $native.Stdout.TrimEnd("`r", "`n")
        }
    }
    $passed = $compile.ExitCode -eq 0 -and $warningCount -eq 0 -and $noteCount -eq 0 -and $llvmAsExit -eq 0 -and $closureExit -eq 0 -and $nativeExit -eq 0 -and $stdout -ceq $expected
    if (-not $passed) { $failureIds.Add(('CASE_' + $case.id.ToUpperInvariant().Replace('-', '_'))) }
    $records.Add([ordered]@{
        id = $case.id; source = $case.source; expected = $expected; compileExitCode = $compile.ExitCode
        compileStdout = $compile.Stdout; compileStderr = $compile.Stderr
        warningCount = $warningCount; noteCount = $noteCount; llvmAsExitCode = $llvmAsExit
        directCallClosureExitCode = $closureExit; nativeExitCode = $nativeExit; stdout = $stdout; passed = $passed
        llvmSha256 = if (Test-Path -LiteralPath $llvm) { (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash } else { $null }
        executableSha256 = if (Test-Path -LiteralPath $exe) { (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash } else { $null }
    })
    Exit-IfCancellationRequested
}

$inputDrift = [Collections.Generic.List[string]]::new()
foreach ($path in $inputPaths) {
    $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$relative]) { $inputDrift.Add($relative) }
}
if ($inputDrift.Count -gt 0) { $failureIds.Add('INPUT_DRIFT') }
$completed = @($records | Where-Object passed).Count
$result = [ordered]@{
    schemaVersion = 1; status = if ($completed -eq 3 -and $failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completed = $completed; total = 3; compilerSha256 = $compilerHash; inputStable = $inputDrift.Count -eq 0
    inputDrift = @($inputDrift); failureIds = @($failureIds); cases = @($records); inputHashes = $inputHashes
}
$json = ($result | ConvertTo-Json -Depth 10) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw 'portable async socket result violates its schema' }
Write-Host "[portable async socket current] $($result.status) $completed/3; result=$resultPath"
if ($result.status -cne 'passed') { exit 1 }
