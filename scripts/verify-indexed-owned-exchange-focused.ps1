[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$OutputDirectory = '',
    [string]$ResumeResult = '',
    [string]$ExpectedCompilerSha256 = 'B64972E6D63F47E5E600B3978B3F9AA57521CF124CCFCEDAC34B2A9AC8098F40'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/verification-process.ps1')

$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/indexed-exchange-focused-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$contractPath = Join-Path $root 'scripts/contracts/indexed-owned-exchange.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/indexed-owned-exchange.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/indexed-owned-exchange-result.schema.json'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $root 'tests/native-interop/indexed_owned_exchange_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$resultPath = Join-Path $OutputDirectory 'result.json'

function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n").TrimEnd() }
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    return Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000
}

foreach ($path in @($contractPath, $contractSchemaPath, $resultSchemaPath, $closurePath, $auditShimPath, $llvmAs, $clang, $PSCommandPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "indexed exchange input is missing: $path" }
}
$compilerHash = Hash $Compiler
if ($compilerHash -cne $ExpectedCompilerSha256) {
    throw "indexed exchange compiler hash mismatch: expected $ExpectedCompilerSha256, actual $compilerHash"
}
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath)) { throw 'indexed exchange contract schema validation failed' }
$contract = $contractText | ConvertFrom-Json
$resume = $null
if (-not [string]::IsNullOrWhiteSpace($ResumeResult)) {
    $ResumeResult = (Resolve-Path -LiteralPath $ResumeResult).Path
    $resumeText = [IO.File]::ReadAllText($ResumeResult)
    if (-not ($resumeText | Test-Json -SchemaFile $resultSchemaPath)) { throw "resume result schema validation failed: $ResumeResult" }
    $resume = $resumeText | ConvertFrom-Json
    if ($resume.compilerSha256 -cne $compilerHash) { throw 'resume compiler hash does not match the requested compiler' }
}

$inputPaths = [ordered]@{
    compiler = $Compiler
    contract = $contractPath
    contractSchema = $contractSchemaPath
    resultSchema = $resultSchemaPath
    verifier = $PSCommandPath
    closureVerifier = $closurePath
    auditShim = $auditShimPath
    llvmAs = $llvmAs
    clang = $clang
}
foreach ($case in $contract.fixtures.cases) {
    $inputPaths["source:$($case.id)"] = Join-Path $root $case.source
    $inputPaths["expected:$($case.id)"] = Join-Path $root $case.expected
}
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) { throw "indexed exchange case input is missing: $($entry.Value)" }
    $inputHashes[$entry.Key] = Hash $entry.Value
}

function Inspect-ExchangeLlvm([string]$LlvmPath) {
    $llvm = [IO.File]::ReadAllText($LlvmPath)
    $regions = @([regex]::Matches($llvm, '(?ms)^  %exchange_left\d+ =.*?^bb_exchange_done\d+:\s*$'))
    if ($regions.Count -eq 0) { return [pscustomobject]@{ Bounds=$false; Same=$false; Clean=$false } }
    $bounds = $true
    $same = $true
    $clean = $true
    foreach ($match in $regions) {
        $region = $match.Value
        $markers = @('exchange_left_in_bounds', 'exchange_right_in_bounds', 'exchange_in_bounds', 'exchange_bounds_ok', 'exchange_same', 'exchange_swap', 'exchange_left_ptr', 'exchange_right_ptr', 'exchange_left_value', 'exchange_right_value', '  store ')
        $previous = -1
        foreach ($marker in $markers) {
            $next = $region.IndexOf($marker, [StringComparison]::Ordinal)
            if ($next -le $previous) { $bounds = $false; break }
            $previous = $next
        }
        if (-not [regex]::IsMatch($region, 'br i1 %exchange_same\d+, label %bb_exchange_done\d+, label %bb_exchange_swap\d+')) { $same = $false }
        if ($region -match '@sollang_(?:alloc|free|realloc)|memcpy|memmove|sollang_drop') { $clean = $false }
    }
    return [pscustomobject]@{ Bounds=$bounds; Same=$same; Clean=$clean }
}

$artifactBySource = @{}
function Get-Artifact([object]$Case) {
    $key = [string]$Case.source
    if ($artifactBySource.ContainsKey($key)) { return $artifactBySource[$key] }
    $source = Join-Path $root $key
    $prefix = Join-Path $OutputDirectory ([string]$Case.id)
    $exe = "$prefix.exe"
    $ll = "$prefix.ll"
    $compile = Run 'dotnet' @($Compiler, 'build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps') "$($Case.id) compile"
    $artifact = [ordered]@{
        Compile = $compile
        Exe = $exe
        Llvm = $ll
        LlvmProduced = Test-Path -LiteralPath $ll -PathType Leaf
        Native = $null
        Assemble = $null
        Closure = $null
        Structure = $null
        Audit = $null
    }
    if ($compile.ExitCode -eq 0 -and $artifact.LlvmProduced) {
        $artifact.Assemble = Run $llvmAs @($ll, '-o', "$prefix.bc") "$($Case.id) llvm-as"
        $artifact.Closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) "$($Case.id) V004"
        $artifact.Structure = Inspect-ExchangeLlvm $ll
        $artifact.Native = Run $exe @() "$($Case.id) native"
    }
    $artifactBySource[$key] = [pscustomobject]$artifact
    return $artifactBySource[$key]
}

function Invoke-AllocationAudit([object]$Artifact, [string]$Expected) {
    $auditLl = Join-Path $OutputDirectory 'positive.audit.ll'
    $auditExe = Join-Path $OutputDirectory 'positive.audit.exe'
    $llvm = [IO.File]::ReadAllText($Artifact.Llvm)
    $llvm = $llvm.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(')
    $llvm = $llvm.Replace('call void @sollang_free(', 'call void @audit_free(')
    $llvm = $llvm.Replace('@sollang_start()', '@slg_program_main()')
    $llvm += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
    [IO.File]::WriteAllText($auditLl, $llvm, [Text.UTF8Encoding]::new($false))
    $link = Run $clang @('-Wno-override-module', $auditLl, $auditShimPath, '-O1', '-o', $auditExe) 'P-NESTED-CLEANUP audit link'
    if ($link.ExitCode -ne 0) { return [pscustomobject]@{ Passed=$false; Exit=$link.ExitCode; Failure="audit link failed: $($link.Stdout) $($link.Stderr)" } }
    $run = Run $auditExe @() 'P-NESTED-CLEANUP audit execute'
    $actual = Normalize $run.Stdout
    $lines = @($actual -split "`n")
    $countLine = $lines[-1]
    $counts = [regex]::Match($countLine, '^allocations=(?<alloc>\d+),releases=(?<release>\d+),invalid=(?<invalid>\d+)$')
    $programOutput = Normalize (($lines | Select-Object -SkipLast 1) -join "`n")
    $passed = $run.ExitCode -eq 0 -and $counts.Success -and $programOutput -ceq $Expected -and [int]$counts.Groups['alloc'].Value -eq [int]$counts.Groups['release'].Value -and [int]$counts.Groups['invalid'].Value -eq 0
    return [pscustomobject]@{ Passed=$passed; Exit=$run.ExitCode; Counts=$counts; Failure=if($passed){$null}else{"allocation audit mismatch: $actual $($run.Stderr)"} }
}

$results = foreach ($case in $contract.fixtures.cases) {
    $currentSourceHash = Hash (Join-Path $root $case.source)
    $prior = if ($null -eq $resume) { $null } else { @($resume.cases | Where-Object { $_.id -ceq $case.id }) }
    if ($null -ne $prior -and $prior.Count -eq 1 -and $prior[0].passed -and $prior[0].sourceSha256 -ceq $currentSourceHash) {
        $prior[0]
        continue
    }
    $artifact = Get-Artifact $case
    $expected = Normalize ([IO.File]::ReadAllText((Join-Path $root $case.expected)))
    $item = [ordered]@{
        id = [string]$case.id
        passed = $false
        reusedImmutableArtifact = $false
        sourceSha256 = $currentSourceHash
        compileExit = $artifact.Compile.ExitCode
        diagnosticMatched = $null
        llvmProduced = $artifact.LlvmProduced
        llvmAsExit = if ($null -eq $artifact.Assemble) { $null } else { $artifact.Assemble.ExitCode }
        closureExit = if ($null -eq $artifact.Closure) { $null } else { $artifact.Closure.ExitCode }
        nativeExit = if ($null -eq $artifact.Native) { $null } else { $artifact.Native.ExitCode }
        stdoutMatched = $null
        observedStdout = if ($null -eq $artifact.Native) { $null } else { Normalize $artifact.Native.Stdout }
        artifactHashes = [ordered]@{
            llvm = if ($artifact.LlvmProduced) { Hash $artifact.Llvm } else { $null }
            native = if (Test-Path -LiteralPath $artifact.Exe -PathType Leaf) { Hash $artifact.Exe } else { $null }
        }
        boundsBeforeMutation = if ($null -eq $artifact.Structure) { $null } else { $artifact.Structure.Bounds }
        sameIndexNoMemory = if ($null -eq $artifact.Structure) { $null } else { $artifact.Structure.Same }
        exchangeBodyNoForbidden = if ($null -eq $artifact.Structure) { $null } else { $artifact.Structure.Clean }
        allocationBalanced = $null
        invalidAllocationCount = $null
        failure = $null
    }
    try {
        if ($case.kind -ceq 'compile-failure') {
            $diagnostic = Normalize ($artifact.Compile.Stdout + "`n" + $artifact.Compile.Stderr)
            $item.diagnosticMatched = $diagnostic.Contains($expected, [StringComparison]::Ordinal)
            if ($artifact.Compile.ExitCode -eq 0) { throw 'negative compiled successfully' }
            if ($artifact.LlvmProduced) { throw 'negative produced LLVM' }
            if (-not $item.diagnosticMatched) { throw "negative diagnostic mismatch: $diagnostic" }
        } else {
            if ($artifact.Compile.ExitCode -ne 0 -or -not $artifact.LlvmProduced) { throw "compile failed: $($artifact.Compile.Stdout) $($artifact.Compile.Stderr)" }
            if ($artifact.Assemble.ExitCode -ne 0) { throw "llvm-as failed: $($artifact.Assemble.Stdout) $($artifact.Assemble.Stderr)" }
            if ($artifact.Closure.ExitCode -ne 0) { throw "V004 failed: $($artifact.Closure.Stdout) $($artifact.Closure.Stderr)" }
            if (-not $artifact.Structure.Bounds -or -not $artifact.Structure.Same -or -not $artifact.Structure.Clean) { throw 'generated exchange LLVM structural contract failed' }
            $item.stdoutMatched = (Normalize $artifact.Native.Stdout) -ceq $expected
            if (-not $item.stdoutMatched) { throw "native stdout mismatch: $($artifact.Native.Stdout)" }
            if ($case.kind -ceq 'native-success' -and $artifact.Native.ExitCode -ne 0) { throw "native success exited $($artifact.Native.ExitCode)" }
            if ($case.kind -ceq 'native-trap' -and $artifact.Native.ExitCode -eq 0) { throw 'bounds negative did not trap' }
            if ($case.id -ceq 'P-NESTED-CLEANUP') {
                $audit = Invoke-AllocationAudit $artifact $expected
                $item.allocationBalanced = $audit.Passed
                $item.invalidAllocationCount = if ($audit.Counts.Success) { [int]$audit.Counts.Groups['invalid'].Value } else { $null }
                if (-not $audit.Passed) { throw $audit.Failure }
            }
        }
        $item.passed = $true
    } catch {
        $item.failure = $_.Exception.Message
    }
    [pscustomobject]$item
}

$drift = @()
foreach ($entry in $inputPaths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $drift += $entry.Key }
}
$failureIds = @($results | Where-Object { -not $_.passed } | ForEach-Object id)
if ($drift.Count -gt 0) { $failureIds += 'INDEXED_EXCHANGE_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1
    status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    evidenceMode = 'fresh'
    priorResultSha256 = $null
    compilerSha256 = $compilerHash
    inputHashes = $inputHashes
    completed = @($results | Where-Object passed).Count
    total = 9
    cases = @($results)
    failureIds = @($failureIds)
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw "indexed exchange result schema failure: $resultPath" }
if ($record.status -ne 'passed') { throw "indexed exchange focused gate failed: $($failureIds -join ', '); result=$resultPath" }
Write-Host "[indexed-owned-exchange focused] PASS 9/9 result=$resultPath"
