[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CompilerAssembly = '',
    [string]$ExpectedCompilerSha256 = '',
    [string]$OutputDirectory = '',
    [switch]$RunManaged
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $repo 'scripts/verification-process.ps1')

function Get-StdlibSourceSetHash {
    $stdlibRoot = Join-Path $repo 'stdlib'
    $entries = Get-ChildItem -LiteralPath $stdlibRoot -Recurse -File -Filter '*.slg' |
        ForEach-Object {
            $relative = [IO.Path]::GetRelativePath($repo, $_.FullName).Replace('\\', '/')
            "$relative=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
        } |
        Sort-Object
    $bytes = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

$contractPath = Join-Path $repo 'scripts/contracts/typed-block-mutable-borrow.json'
$schemaPath = Join-Path $repo 'scripts/contracts/typed-block-mutable-borrow.schema.json'
$formatterPath = Join-Path $repo 'scripts/format-authoritative-slg.ps1'
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $schemaPath)) { throw 'typed-block mutable-borrow contract schema failure' }
$contract = $contractText | ConvertFrom-Json
$staticResultSchemaPath = Join-Path $repo $contract.staticResultSchema
if (-not (Test-Path -LiteralPath $staticResultSchemaPath -PathType Leaf)) { throw 'missing typed-block mutable-borrow static result schema' }
$managedResultSchemaPath = Join-Path $repo $contract.managedResultSchema
if (-not (Test-Path -LiteralPath $managedResultSchemaPath -PathType Leaf)) { throw 'missing typed-block mutable-borrow managed result schema' }
$ids = @($contract.cases.id)
$expectedIds = @('P-PRIMARY-MUT', 'P-ADDITIONAL-MUT', 'N-ADDITIONAL-READONLY')
if ($ids.Count -ne 3 -or @($ids | Sort-Object -Unique).Count -ne 3 -or @(Compare-Object ($ids | Sort-Object) ($expectedIds | Sort-Object)).Count -ne 0) {
    throw 'typed-block mutable-borrow contract must retain exactly three cases'
}

$compilerSourcePath = Join-Path $repo $contract.compilerSource
$compilerSource = [IO.File]::ReadAllText($compilerSourcePath)
$helper = [regex]::Match($compilerSource, '(?ms)^\s*private HashSet<string> MutableBorrowBindingNames\(BoundFunction function\)\s*\{(?<body>.*?)^\s*private bool FunctionReadonlyBorrowsHeapInput')
if (-not $helper.Success -or
    [regex]::Matches($compilerSource, 'var mutableBindings = MutableBorrowBindingNames\(function\);').Count -ne 2 -or
    $helper.Groups['body'].Value -notmatch 'FunctionMutablyBorrowsInput\(function\)' -or
    $helper.Groups['body'].Value -notmatch 'function\.AdditionalParameters \?\? \[\]' -or
    $helper.Groups['body'].Value -notmatch 'parameter\.Ownership == BoundFunctionInputOwnership\.MutableBorrow' -or
    $helper.Groups['body'].Value -notmatch 'mutableBindings\.Add\(parameter\.Name\)') {
    throw 'ordinary and typed-block validation do not share the exact mutable-borrow binding helper'
}

$sources = @($contract.cases | ForEach-Object { Join-Path $repo $_.source })
foreach ($path in $sources) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing typed-block mutable-borrow fixture: $path" } }
$negative = $contract.cases | Where-Object id -ceq 'N-ADDITIONAL-READONLY'
$expectedPath = Join-Path $repo $negative.expected
if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) { throw 'missing typed-block readonly expected diagnostic' }
$verificationProcessPath = Join-Path $repo 'scripts/verification-process.ps1'
$inputPaths = [ordered]@{
    contract = $contractPath
    contractSchema = $schemaPath
    staticResultSchema = $staticResultSchemaPath
    managedResultSchema = $managedResultSchemaPath
    compilerSource = $compilerSourcePath
    verifier = $PSCommandPath
    verificationProcess = $verificationProcessPath
    formatter = $formatterPath
    expected = $expectedPath
}
foreach ($case in $contract.cases) { $inputPaths["source:$($case.id)"] = Join-Path $repo $case.source }
$inputHashesStart = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashesStart[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash }
$inputHashesStart['stdlibSourceSet'] = Get-StdlibSourceSetHash
& $formatterPath -Check -Source $sources
if ($LASTEXITCODE -ne 0) { throw 'typed-block mutable-borrow fixture format failure' }
if (-not $RunManaged) {
    $staticOutput = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Join-Path $repo 'artifacts/scratch/typed-block-mutable-borrow/static-current' } else { [IO.Path]::GetFullPath($OutputDirectory) }
    [IO.Directory]::CreateDirectory($staticOutput) | Out-Null
    $inputHashesEnd = [ordered]@{}
    foreach ($entry in $inputPaths.GetEnumerator()) { $inputHashesEnd[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash }
    $inputHashesEnd['stdlibSourceSet'] = Get-StdlibSourceSetHash
    $inputStable = -not [bool]@(Compare-Object ($inputHashesStart.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) ($inputHashesEnd.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }))
    $staticFailureIds = @()
    if (-not $inputStable) { $staticFailureIds = @('INPUT_DRIFT') }
    $staticRecord = [ordered]@{ schemaVersion=1; status=if($inputStable){'static-passed-managed-pending'}else{'failed'}; completed=if($inputStable){3}else{0}; total=3; managedCompleted=0; managedTotal=3; inputStable=$inputStable; inputHashes=$inputHashesStart; caseIds=$ids; failureIds=[object[]]$staticFailureIds }
    $staticJson = ($staticRecord | ConvertTo-Json -Depth 6) + "`n"
    $staticResultPath = Join-Path $staticOutput 'result.json'
    [IO.File]::WriteAllText($staticResultPath, $staticJson, [Text.UTF8Encoding]::new($false))
    if (-not ($staticJson | Test-Json -SchemaFile $staticResultSchemaPath)) { throw 'typed-block mutable-borrow static result schema failure' }
    if (-not $inputStable) { throw "typed-block mutable-borrow static input drift; result=$staticResultPath" }
    Write-Host "[typed-block mutable borrow] PASS production-source/static 3/3; integrated managed 0/3 not run; result=$staticResultPath"
    return
}

if (-not (Test-Path -LiteralPath $CompilerAssembly -PathType Leaf) -or $ExpectedCompilerSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'managed run requires an exact compiler path and SHA-256'
}
$compilerPath = [IO.Path]::GetFullPath($CompilerAssembly)
$compilerHash = (Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash
if ($compilerHash -cne $ExpectedCompilerSha256.ToUpperInvariant()) { throw 'typed-block mutable-borrow compiler hash mismatch' }
$output = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Join-Path $repo ('artifacts/scratch/typed-block-mutable-borrow/' + [guid]::NewGuid().ToString('N')) } else { [IO.Path]::GetFullPath($OutputDirectory) }
[IO.Directory]::CreateDirectory($output) | Out-Null
$llvmRoot = Join-Path $repo '.tools/llvm-22.1.8'
$managedInputPaths = [ordered]@{ compiler=$compilerPath }
foreach ($entry in $inputPaths.GetEnumerator()) { $managedInputPaths[$entry.Key] = $entry.Value }
$inputHashes = [ordered]@{}
foreach ($entry in $managedInputPaths.GetEnumerator()) { $inputHashes[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash }
$inputHashes['stdlibSourceSet'] = Get-StdlibSourceSetHash
$results = foreach ($case in $contract.cases) {
    $source = Join-Path $repo $case.source
    $exe = Join-Path $output "$($case.id).exe"
    $ll = Join-Path $output "$($case.id).ll"
    $diagnosticsPath = Join-Path $output "$($case.id).diagnostics.txt"
    if ((Test-Path -LiteralPath $exe) -or (Test-Path -LiteralPath $ll) -or (Test-Path -LiteralPath $diagnosticsPath)) { throw "typed-block mutable-borrow output must be fresh: $($case.id)" }
    $run = Invoke-VerificationProcessCapture -FilePath 'dotnet' -ArgumentList @($compilerPath, 'build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O0', '--keep-temps') -WorkingDirectory $repo -Description "$($case.id) compile" -TimeoutMilliseconds 120000
    $diagnostics = ($run.Stdout + "`n" + $run.Stderr).Replace("`r`n", "`n").TrimEnd()
    [IO.File]::WriteAllText($diagnosticsPath, $diagnostics, [Text.UTF8Encoding]::new($false))
    $warningNoteFree = -not [regex]::IsMatch($diagnostics, '(?im)^\s*(?:sollang:\s*)?(?:warning|note)(?:\[|\s|:)')
    $llvmProduced = Test-Path -LiteralPath $ll -PathType Leaf
    $executableProduced = Test-Path -LiteralPath $exe -PathType Leaf
    $diagnosticCount = [regex]::Matches($diagnostics, '(?im)^\s*sollang:\s*(?:semantic\s+)?error\b').Count
    if ($case.kind -ceq 'compile-success') {
        $diagnosticMatched = $null
        $passed = $run.ExitCode -eq 0 -and $warningNoteFree -and $llvmProduced -and $executableProduced -and $diagnosticCount -eq 0
    } else {
        $expected = [IO.File]::ReadAllText($expectedPath).Trim()
        $diagnosticMatched = $diagnostics.Contains($expected, [StringComparison]::Ordinal)
        $passed = $run.ExitCode -ne 0 -and $warningNoteFree -and -not $llvmProduced -and -not $executableProduced -and $diagnosticCount -eq 1 -and $diagnosticMatched
    }
    $diagnosticsHash = (Get-FileHash -LiteralPath $diagnosticsPath -Algorithm SHA256).Hash
    $llvmHash = if ($llvmProduced) { (Get-FileHash -LiteralPath $ll -Algorithm SHA256).Hash } else { $null }
    $executableHash = if ($executableProduced) { (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash } else { $null }
    [ordered]@{ id=$case.id; kind=$case.kind; passed=$passed; compileExit=$run.ExitCode; warningNoteFree=$warningNoteFree; llvmProduced=$llvmProduced; executableProduced=$executableProduced; diagnosticCount=$diagnosticCount; diagnosticMatched=$diagnosticMatched; diagnosticsSha256=$diagnosticsHash; llvmSha256=$llvmHash; executableSha256=$executableHash; failure=if($passed){$null}else{'EXPECTATION_MISMATCH'} }
}
$completed = @($results | Where-Object passed).Count
$inputHashesEnd = [ordered]@{}
foreach ($entry in $managedInputPaths.GetEnumerator()) { $inputHashesEnd[$entry.Key] = (Get-FileHash -LiteralPath $entry.Value -Algorithm SHA256).Hash }
$inputHashesEnd['stdlibSourceSet'] = Get-StdlibSourceSetHash
$inputStable = -not [bool]@(Compare-Object ($inputHashes.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) ($inputHashesEnd.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }))
$failureIds = @($results | Where-Object { -not $_.passed } | ForEach-Object { $_.id })
if (-not $inputStable) { $failureIds += 'INPUT_DRIFT' }
$record = [ordered]@{ schemaVersion=1; status=if($completed -eq 3 -and $inputStable){'passed'}else{'failed'}; completed=$completed; total=3; compilerSha256=$compilerHash; inputStable=$inputStable; inputHashes=$inputHashes; cases=@($results); failureIds=@($failureIds) }
$resultPath = Join-Path $output 'result.json'
$resultJson = ($record | ConvertTo-Json -Depth 6) + "`n"
[IO.File]::WriteAllText($resultPath, $resultJson, [Text.UTF8Encoding]::new($false))
if (-not ($resultJson | Test-Json -SchemaFile $managedResultSchemaPath)) { throw 'typed-block mutable-borrow managed result schema failure' }
if ($completed -ne 3 -or -not $inputStable) { throw "typed-block mutable-borrow managed failed $completed/3 inputStable=$inputStable; result=$resultPath" }
Write-Host "[typed-block mutable borrow] PASS managed 3/3 result=$resultPath"
