[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
function File([string]$Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $root $Relative))
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "GZIP selfhost contract input missing or outside repository: $Relative" }
    $path
}
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Satisfies([object]$Value, [string]$Schema) {
    $json = $Value | ConvertTo-Json -Depth 10
    try { [bool]($json | Test-Json -SchemaFile $Schema -ErrorAction Stop) } catch { $false }
}

$contractPath = File 'scripts/contracts/gzip-selfhost-focused.json'
$contractSchemaPath = File 'scripts/contracts/gzip-selfhost-focused.schema.json'
$resultSchemaPath = File 'scripts/contracts/gzip-selfhost-focused-result.schema.json'
$authorityPath = File 'scripts/contracts/gzip-stream-api.json'
$verifierPath = File 'scripts/verify-gzip-selfhost-focused.ps1'
$contractText = [IO.File]::ReadAllText($contractPath)
Require ($contractText | Test-Json -SchemaFile $contractSchemaPath -ErrorAction Stop) 'GZIP selfhost focused contract failed its schema'
$contract = $contractText | ConvertFrom-Json
$authority = [IO.File]::ReadAllText($authorityPath) | ConvertFrom-Json
Require ((@($contract.positiveCaseIds) -join "`n") -ceq (@($authority.positiveCases.id) -join "`n")) 'GZIP selfhost positives must reuse all ten authority cases in order'
Require ((@($contract.negativeCaseIds) -join "`n") -ceq (@($authority.negativeCases.id) -join "`n")) 'GZIP selfhost negatives must reuse all three authority cases in order'
foreach ($case in @($authority.negativeCases)) {
    $targetDiagnostic = $contract.selfhostDiagnosticsByCase.PSObject.Properties[$case.id].Value
    $derivedDiagnostic = '; sollang semantic error: ' + ($case.diagnostic -replace '^sollang: semantic error at \d+:\d+: \[module ''<main>''\] ', '')
    Require ($targetDiagnostic -ceq $derivedDiagnostic) "selfhost diagnostic mapping drifted from semantic authority: $($case.id)"
}
foreach ($required in @($contract.requiredFocusedCaseIds)) { Require (@($contract.positiveCaseIds) -ccontains $required) "required focused GZIP case missing: $required" }
Require ((@($contract.additionalSourcesByCase.'crc-parity') -join "`n") -ceq 'stdlib/std/hash/crc32.slg') 'GZIP crc-parity selfhost closure must include the public CRC32 module exactly once'

$tokens = [IO.File]::ReadAllText($verifierPath)
foreach ($token in @(
    "[switch]`$ValidateOnly",
    "ExpectedCompilerSha256",
    "OutputDirectory must be below artifacts/scratch",
    "`$moduleSourcePaths = @(`$authority.sources",
    "`$focused.additionalSourcesByCase.PSObject.Properties[`$case.id]",
    "@('windows', '--jobs', '1') + `$moduleSourcePaths",
    "verify-llvm-direct-call-closure.ps1",
    "llvm-as.exe",
    "clang.exe",
    "System.IO.Compression.GZipStream",
    "dynamic-writer-determinism",
    "GZIP_SELFHOST_INPUT_DRIFT",
    "inputHashesStart",
    "inputHashesEnd",
    "orphanProcessIds = `$null",
    "Test-Json -SchemaFile `$resultSchemaPath"
)) { Require ($tokens.Contains($token, [StringComparison]::Ordinal)) "GZIP selfhost verifier contract token missing: $token" }

$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($verifierPath, [ref]$null, [ref]$parseErrors)
Require (@($parseErrors).Count -eq 0) "GZIP selfhost verifier has PowerShell parse errors: $($parseErrors -join '; ')"

$hashes = [ordered]@{}
for ($index = 0; $index -lt 25; $index++) { $hashes["input$index"] = 'A' * 64 }
$cases = [Collections.Generic.List[object]]::new()
foreach ($caseId in @($contract.positiveCaseIds)) {
    foreach ($optimization in @($contract.optimizations)) {
        $cases.Add([ordered]@{ id = "$caseId-$($optimization.ToLowerInvariant())"; kind = 'positive'; optimization = $optimization; passed = $true; compileExit = 0; diagnosticFree = $true; llvmProduced = $true; llvmAsExit = 0; closureExit = 0; linkExit = 0; nativeExit = 0; exact = $true; stdoutSha256 = 'B' * 64; failure = $null })
    }
}
foreach ($caseId in @($contract.negativeCaseIds)) {
    $cases.Add([ordered]@{ id = $caseId; kind = 'negative'; optimization = $null; passed = $true; compileExit = 1; diagnosticFree = $false; llvmProduced = $false; llvmAsExit = $null; closureExit = $null; linkExit = $null; nativeExit = $null; exact = $true; stdoutSha256 = $null; failure = $null })
}
$canonical = [ordered]@{
    schemaVersion = 1; mode = 'selfhost-native-gzip-focused'; status = 'passed'; platform = 'windows-x64'; phase = 'execution'; attempted = 23; completed = 23; total = 23
    executionMode = 'detached-supervisor-worker'; processAuditAuthority = 'scripts/invoke-detached-selfhost-verification.ps1 completion record'; orphanProcessIds = $null
    positive = [ordered]@{ completed = 20; total = 20 }; negative = [ordered]@{ completed = 3; total = 3 }
    expectedCompilerSha256 = 'C' * 64; compilerSha256Start = 'C' * 64; compilerSha256End = 'C' * 64
    inputStable = $true; inputDrift = @(); inputHashesStart = $hashes; inputHashesEnd = $hashes
    toolHashes = [ordered]@{ compiler = 'C' * 64; llvmAs = 'D' * 64; clang = 'E' * 64; closureVerifier = 'F' * 64 }
    dynamic = [ordered]@{ caseId = 'dynamic-writer'; btype = 2; independentReader = 'System.IO.Compression.GZipStream'; decodedExact = $true; deterministicAcrossOptimizations = $true; stdoutSha256O0 = 'B' * 64; stdoutSha256O2 = 'B' * 64 }
    cases = @($cases); failureIds = @()
}
Require (Satisfies $canonical $resultSchemaPath) 'canonical passed 23/23 GZIP selfhost receipt was rejected'

$wrongCompleted = ($canonical | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$wrongCompleted.completed = 22
Require (-not (Satisfies $wrongCompleted $resultSchemaPath)) 'result schema accepted passed completed below 23'
$failureOnPass = ($canonical | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$failureOnPass.failureIds = @('UNEXPECTED')
Require (-not (Satisfies $failureOnPass $resultSchemaPath)) 'result schema accepted failureIds on passed receipt'
$driftOnPass = ($canonical | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$driftOnPass.inputStable = $false; $driftOnPass.inputDrift = @('compiler')
Require (-not (Satisfies $driftOnPass $resultSchemaPath)) 'result schema accepted input drift on passed receipt'
$shortCases = ($canonical | ConvertTo-Json -Depth 10) | ConvertFrom-Json
$shortCases.cases = @($shortCases.cases | Select-Object -First 22)
Require (-not (Satisfies $shortCases $resultSchemaPath)) 'result schema accepted a receipt without exactly 23 cases'

Write-Host '[GZIP selfhost focused contract] PASS authority 13/13, validate-only positive 1/1, negative controls 4/4.'
