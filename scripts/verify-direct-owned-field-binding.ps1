[CmdletBinding()]
param(
    [string]$Compiler = '',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/verification-process.ps1')
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
}
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$contractPath = Join-Path $root 'scripts/contracts/direct-owned-field-binding.json'
$schemaPath = Join-Path $root 'scripts/contracts/direct-owned-field-binding.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/direct-owned-field-binding-result.schema.json'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$shimPath = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$verifierPath = $PSCommandPath
foreach ($path in @($contractPath, $schemaPath, $resultSchemaPath, $closurePath, $shimPath, $llvmAs, $clang, $verifierPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C341 required input is missing: $path" }
}
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $schemaPath)) { throw 'C341 contract schema validation failed' }
$contract = $contractText | ConvertFrom-Json
$ids = @($contract.cases.id)
if (($ids | Select-Object -Unique).Count -ne $ids.Count) { throw 'C341 contract case IDs are not unique' }
if ($ids.Count -ne 20) { throw "C341 contract case count drifted: $($ids.Count)" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/c341-direct-binding-focused-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$resultPath = Join-Path $OutputDirectory 'result.json'

function Normalize([string]$Text) { return $Text.Replace("`r`n", "`n").TrimEnd() }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    return Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000
}

$inputPaths = [ordered]@{
    compiler = $Compiler
    contract = $contractPath
    contractSchema = $schemaPath
    resultSchema = $resultSchemaPath
    verifier = $verifierPath
    closureVerifier = $closurePath
    auditShim = $shimPath
}
foreach ($case in $contract.cases) {
    $inputPaths["source:$($case.id)"] = Join-Path $root $case.source
    if ($case.PSObject.Properties.Name -contains 'expected') {
        $inputPaths["expected:$($case.id)"] = Join-Path $root $case.expected
    }
}
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) { throw "C341 case input is missing: $($entry.Value)" }
    $inputHashes[$entry.Key] = Hash $entry.Value
}

$results = foreach ($case in $contract.cases) {
    $source = $inputPaths["source:$($case.id)"]
    $prefix = Join-Path $OutputDirectory $case.id
    $exe = "$prefix.exe"
    $ll = "$prefix.ll"
    $item = [ordered]@{
        id = $case.id
        passed = $false
        sourceSha256 = Hash $source
        compileExit = -1
        warningNoteFree = $false
        llvmProduced = $false
        llvmAsExit = $null
        closureExit = $null
        nativeExit = $null
        auditExit = $null
        diagnosticMatched = $null
        failure = $null
    }
    try {
        $compile = Run 'dotnet' @($Compiler, 'build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps') "$($case.id) managed compile"
        $item.compileExit = $compile.ExitCode
        $item.llvmProduced = Test-Path -LiteralPath $ll -PathType Leaf
        $compileDiagnostics = Normalize ($compile.Stdout + "`n" + $compile.Stderr)
        $item.warningNoteFree = -not [regex]::IsMatch(
            $compileDiagnostics,
            '(?im)^\s*(?:sollang:\s*)?(?:warning|note)(?:\[|\s|:)')
        if (-not $item.warningNoteFree) { throw "compile produced warning or note: $compileDiagnostics" }
        if ($case.kind -eq 'negative') {
            $diagnostic = $compileDiagnostics
            $item.diagnosticMatched = $diagnostic.Contains([string]$case.diagnostic, [StringComparison]::Ordinal)
            if ($compile.ExitCode -eq 0) { throw 'negative compiled successfully' }
            if ($item.llvmProduced) { throw 'negative produced LLVM' }
            if (-not $item.diagnosticMatched) { throw "negative diagnostic mismatch: $diagnostic" }
            $item.passed = $true
        } else {
            if ($compile.ExitCode -ne 0) { throw "positive compile failed: $($compile.Stdout) $($compile.Stderr)" }
            if (-not $item.llvmProduced) { throw 'positive omitted LLVM' }
            $expected = if ($case.PSObject.Properties.Name -contains 'expected') {
                Normalize ([IO.File]::ReadAllText($inputPaths["expected:$($case.id)"]))
            } else { Normalize ([string]$case.expectedText) }
            $native = Run $exe @() "$($case.id) native execute"
            $item.nativeExit = $native.ExitCode
            if ($native.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($native.Stderr)) { throw "native failed: $($native.Stdout) $($native.Stderr)" }
            if ((Normalize $native.Stdout) -cne $expected) { throw "native exact mismatch: $($native.Stdout)" }
            $assembled = Run $llvmAs @($ll, '-o', "$prefix.bc") "$($case.id) llvm-as"
            $item.llvmAsExit = $assembled.ExitCode
            if ($assembled.ExitCode -ne 0) { throw "llvm-as failed: $($assembled.Stdout) $($assembled.Stderr)" }
            $closure = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) "$($case.id) V004"
            $item.closureExit = $closure.ExitCode
            if ($closure.ExitCode -ne 0) { throw "V004 failed: $($closure.Stdout) $($closure.Stderr)" }
            if ($case.PSObject.Properties.Name -contains 'auditAllocations') {
                $auditLl = "$prefix.audit.ll"
                $llvmText = [IO.File]::ReadAllText($ll)
                $auditText = $llvmText.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('@sollang_start()', '@slg_program_main()')
                $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
                [IO.File]::WriteAllText($auditLl, $auditText, [Text.UTF8Encoding]::new($false))
                $auditExe = "$prefix.audit.exe"
                $auditLink = Run $clang @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$($case.auditAllocations)", $auditLl, $shimPath, '-O1', '-o', $auditExe) "$($case.id) allocation link"
                if ($auditLink.ExitCode -ne 0) { throw "allocation link failed: $($auditLink.Stdout) $($auditLink.Stderr)" }
                $audit = Run $auditExe @() "$($case.id) allocation execute"
                $item.auditExit = $audit.ExitCode
                $expectedAudit = "$expected`nallocations=$($case.auditAllocations),releases=$($case.auditAllocations)"
                if ($audit.ExitCode -ne 0 -or (Normalize $audit.Stdout) -cne $expectedAudit) { throw "allocation audit mismatch: $($audit.Stdout) $($audit.Stderr)" }
            }
            $item.passed = $true
        }
    } catch {
        $item.failure = $_.Exception.Message
    }
    [pscustomobject]$item
}

$drift = @()
foreach ($entry in $inputPaths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $inputHashes[$entry.Key]) { $drift += $entry.Key }
}
if ($drift.Count -gt 0) {
    $results += [pscustomobject]@{ id='C341_INPUT_DRIFT'; passed=$false; sourceSha256=('0' * 64); compileExit=-1; warningNoteFree=$false; llvmProduced=$false; llvmAsExit=$null; closureExit=$null; nativeExit=$null; auditExit=$null; diagnosticMatched=$null; failure="C341 input drift: $($drift -join ', ')" }
}
$passed = @($results | Where-Object passed).Count
$failureIds = @($results | Where-Object { -not $_.passed } | ForEach-Object id)
$record = [ordered]@{
    schemaVersion = 1
    defectId = 'C2026-09-06-341'
    runStatus = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completionStatus = if ($passed -eq 20 -and $results.Count -eq 20) { 'complete' } else { 'in-progress' }
    completed = $passed
    total = 20
    compilerSha256 = $inputHashes.compiler
    inputHashes = $inputHashes
    cases = @($results | Where-Object { $_.id -ne 'C341_INPUT_DRIFT' })
    failureIds = $failureIds
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath)) { throw "C341 result schema validation failed: $resultPath" }
if ($record.runStatus -ne 'passed' -or $record.completionStatus -ne 'complete') {
    throw "C341 focused failed $passed/20: $($failureIds -join ', '); result=$resultPath"
}
Write-Host "[C341 direct owned field binding] PASS 20/20 compiler=$($record.compilerSha256) result=$resultPath"
