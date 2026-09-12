[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCompiler,
    [switch]$TypeDelimiters,
    [switch]$ReadonlyTextSlice,
    [switch]$ExecuteFixtures,
    [string[]]$FixtureId = @()
)

$ErrorActionPreference = 'Stop'
if ($PSBoundParameters.ContainsKey('FixtureId') -and (-not $ExecuteFixtures -or $FixtureId.Count -eq 0)) {
    throw 'an explicit FixtureId selection requires ExecuteFixtures and at least one fixture ID'
}
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$output = Join-Path $repo ('artifacts/scratch/generic-type-contexts/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output -Force | Out-Null
$compiler = Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$source = Get-Content -LiteralPath (Join-Path $repo 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs') -Raw
function Read-Methods([string]$Name, [int]$Count) {
    $pattern = '(?ms)^    private (?:static )?[^\r\n]+\b' + [regex]::Escape($Name) + '\(.*?^    \}'
    $matches = [regex]::Matches($source, $pattern)
    if ($matches.Count -ne $Count) { throw "expected $Count authoritative $Name declarations; found $($matches.Count)" }
    return ($matches | ForEach-Object Value) -join "`n`n"
}
$specialization = Read-Methods 'ParseSpecializedFunctionType' 2
$referencesParameter = Read-Methods 'TypeSyntaxReferencesParameter' 1
$delimiters = Read-Methods 'FindTopLevelTypeComma' 1
$delimiters += "`n" + (Read-Methods 'FindTopLevelTypeColon' 1)
$delimiters += "`n" + (Read-Methods 'SplitTopLevelProductFields' 1)
$delimiters += "`n" + (Read-Methods 'ParseProductType' 1)
$parseType = Read-Methods 'ParseType' 1
$contextStart = $parseType.IndexOf('        if (_activeGenericTypeArguments.TryGetValue')
$dynStart = $parseType.IndexOf('        if (typeName.StartsWith("dyn "')
$refStart = $parseType.IndexOf('        if (typeName.StartsWith("ref "')
if ($contextStart -lt 0 -or $dynStart -le $contextStart -or $refStart -le $dynStart) {
    throw 'selected current ParseType branch boundaries changed'
}
# Extract, do not reimplement, the production generic/product and borrowed/
# algebraic/container branches. Unrelated dyn/numeric collection dispatch is
# excluded; leaf lookup and every table operation still use the real DLL.
$selectedParser = "    private BoundType ParseCandidateType(string typeName, int line, int column)`n    {`n" +
    $parseType.Substring($contextStart, $dynStart - $contextStart) + $parseType.Substring($refStart)
$selectedParser = $selectedParser.Replace('ParseType(', 'ParseCandidateType(')
function Read-DefinitionArrayProbe([string]$Name, [string]$CountName) {
    $prefix = [regex]::Match($source, '(?ms)^        bool ' + $Name + '\(.*?^            var elementType = ResolveDefinitionType').Value
    $bodyStart = $prefix.IndexOf("        {`r`n")
    if ($bodyStart -lt 0) { $bodyStart = $prefix.IndexOf("        {`n") }
    $bodyEnd = $prefix.LastIndexOf('            var elementType = ResolveDefinitionType')
    if ($bodyStart -lt 0 -or $bodyEnd -le $bodyStart) { throw "missing $Name production guard" }
    $body = $prefix.Substring($bodyStart, $bodyEnd - $bodyStart).Replace('type = default;', '').Replace('return false;', 'return (false, "", 0);')
    return "    private static (bool Matched, string Element, int Count) Probe$Name(string typeName, int line, int column)`n$body            return (true, elementName, $CountName);`n        }"
}
$definitionProbes = (Read-DefinitionArrayProbe 'TryResolveDefinitionFixedStaticArray' 'length') + "`n" +
    (Read-DefinitionArrayProbe 'TryResolveDefinitionBoundedArray' 'capacity')
$boundSource = Get-Content -LiteralPath (Join-Path $repo 'src/Sollang.Compiler/Semantics/BoundProgram.cs') -Raw
$typeId = [regex]::Match($boundSource, '(?ms)^internal enum TypeId\r?\n\{.*?^\}').Value
if (!$typeId) { throw 'missing authoritative TypeId enum' }
$generated = "global using BoundType = Sollang.Compiler.Semantics.TypeId;`nnamespace Sollang.Compiler.Semantics;`n$typeId`ninternal sealed partial class SemanticCompiler {`n$specialization`n$referencesParameter`n$delimiters`n$selectedParser`n$definitionProbes`n}`n"
[IO.File]::WriteAllText((Join-Path $output 'ProductionMethods.cs'), $generated)
$wrapper = Join-Path $repo 'src/Sollang.Compiler/Semantics/SemanticCompiler.GenericTypeContexts.cs'
$harness = Join-Path $repo 'scripts/contracts/fixtures/generic-type-context-harness.cs'
$delimiterSource = Join-Path $repo 'src/Sollang.Compiler/Semantics/SemanticCompiler.TypeDelimiters.cs'
$sliceEmitterPath = Join-Path $repo 'src/Sollang.Compiler/CodeGen/LlvmEmitter.FunctionCalls.cs'
$sliceEmitterSource = Get-Content -LiteralPath $sliceEmitterPath -Raw
$sliceMethod = [regex]::Match($sliceEmitterSource, '(?ms)^    private RuntimeValue CreateRuntimeSlice\(.*?^    \}').Value
$arrayViewHelper = [regex]::Match($sliceEmitterSource, '(?ms)^    private static [^\r\n]+ TryGetRuntimeArrayView\(RuntimeValue value\) =>.*?^        \};').Value
$sliceArgument = [regex]::Match($sliceEmitterSource, '(?ms)^    private string BuildReadonlySliceArgument\(\r?\n        BoundType expectedType,.*?^    \}').Value
$sliceEnsure = [regex]::Match($sliceEmitterSource, '(?ms)^    private void EnsureFunctionArgumentRuntimeType\(.*?^    \}').Value
$runtimeEnsure = [regex]::Match($sliceEmitterSource, '(?ms)^    private void EnsureRuntimeType\(.*?^    \}').Value
$sliceSerialize = [regex]::Match($sliceEmitterSource, '(?ms)^    private string BuildIntSliceArgument\(string pointer, string length\).*?^    \}').Value
foreach ($consumer in @($sliceMethod, $sliceArgument, $sliceEnsure)) {
    if (-not $consumer -or [regex]::Matches($consumer, '\bTryGetRuntimeArrayView\(').Count -ne 1) {
        throw 'each of the three slice consumers must use the authoritative array-view classifier exactly once'
    }
}
$runtimeValuesPath = Join-Path $repo 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Utilities.cs'
$runtimeValues = Get-Content -LiteralPath $runtimeValuesPath -Raw
$sliceRecords = @()
foreach ($recordName in @('RuntimeValue', 'RuntimeReference', 'RuntimeIntSlice', 'RuntimeInlineSlice', 'RuntimeStaticIntArray', 'RuntimeStaticTextArray', 'RuntimeStaticInlineArray', 'RuntimeDynamicIntArray', 'RuntimeDynamicInlineArray')) {
    $record = [regex]::Match($runtimeValues, '(?ms)^    private (?:abstract|sealed) record ' + $recordName + '\(.*?;').Value
    if (-not $record) { throw "missing authoritative runtime value $recordName" }
    $sliceRecords += $record
}
$storageEnum = [regex]::Match($runtimeValues, '(?ms)^    private enum RuntimeContainerStorage\r?\n    \{.*?^    \}').Value
if (-not $sliceMethod -or -not $storageEnum -or -not $arrayViewHelper -or -not $runtimeEnsure -or -not $sliceSerialize) {
    throw 'readonly Text slice production extraction failed'
}
$sliceGenerated = "namespace Sollang.Compiler.CodeGen;`ninternal sealed partial class LlvmEmitter {`n" +
    ($sliceRecords -join "`n") + "`n$storageEnum`n$arrayViewHelper`n$sliceMethod`n$sliceArgument`n$sliceEnsure`n$runtimeEnsure`n$sliceSerialize`n}`n"
$sliceGeneratedPath = Join-Path $output 'ReadonlyTextSliceProduction.cs'
[IO.File]::WriteAllText($sliceGeneratedPath, $sliceGenerated)
$sliceHarness = Join-Path $repo 'scripts/contracts/fixtures/readonly-text-slice-harness.cs'
$project = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable>
    <LangVersion>preview</LangVersion><TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="$wrapper" />
    <Compile Include="$harness" />
    <Compile Include="$delimiterSource" />
    <Compile Include="$sliceHarness" />
  </ItemGroup>
</Project>
"@
$projectPath = Join-Path $output 'GenericTypeContexts.csproj'
[IO.File]::WriteAllText($projectPath, $project)
$fixture = Join-Path $repo 'scripts/contracts/fixtures/1719-generic-readonly-slice-context.slg'
$actual = (& dotnet run --project $projectPath --configuration Release -- $compiler $fixture 2>&1) -join "`n"
$exitCode = $LASTEXITCODE
[IO.File]::WriteAllText((Join-Path $output 'run.log'), $actual)
$passed = [regex]::Matches($actual, '(?m)^PASS [A-Za-z0-9-]+\r?$').Count
$status = if ($exitCode -eq 0 -and $passed -eq 21 -and $actual -match '(?m)^generic-type-contexts=21/21\r?$') { 'passed' } else { 'failed' }
$evidence = [ordered]@{
    schemaVersion = 1
    scope = 'current-extracted-generic-context-methods-with-existing-production-type-parser'
    status = $status
    exitCode = $exitCode
    completed = $passed
    total = 21
    compilerSha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
    wrapperSha256 = (Get-FileHash -LiteralPath $wrapper -Algorithm SHA256).Hash
    extractedMethodsSha256 = (Get-FileHash -LiteralPath (Join-Path $output 'ProductionMethods.cs') -Algorithm SHA256).Hash
    inferenceCallsiteCount = [regex]::Matches($source, 'if \(TryGetBorrowedGenericElement\(typeTemplate, actualType, line, column,').Count
    integration = 'pending-accumulated-compiler-verification-including-named-owner-and-temporary-reference-calls'
    namedOwnerExpectedStdout = @{ '1719' = "2`n2"; '1720' = "42`ntext" }
    temporaryReferenceExpectedDiagnostic = 'requires an addressable owner or reference'
}
if ($TypeDelimiters) {
    $matrix = Join-Path $repo 'scripts/probes/type-delimiters/cases.json'
    $delimiterOutput = (& dotnet run --no-build --project $projectPath --configuration Release -- $compiler $fixture --type-delimiters $matrix 2>&1) -join "`n"
    $delimiterExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'type-delimiters.log'), $delimiterOutput)
    $delimiterPassed = [regex]::Matches($delimiterOutput, '(?m)^PASS delimiter-').Count
    $matrixCases = Get-Content -LiteralPath $matrix -Raw | ConvertFrom-Json
    $delimiterTotal = $matrixCases.accepted.Count + $matrixCases.rejected.Count + $matrixCases.separators.Count + 3
    $evidence.typeDelimiters = @{
        completed = $delimiterPassed; total = $delimiterTotal; exitCode = $delimiterExit
        contractSha256 = (Get-FileHash -LiteralPath $matrix -Algorithm SHA256).Hash
        helperSha256 = (Get-FileHash -LiteralPath $delimiterSource -Algorithm SHA256).Hash
        referenceAccepted = [regex]::Matches($delimiterOutput, '(?m)^REFERENCE ACCEPT ').Count
        referenceRejected = [regex]::Matches($delimiterOutput, '(?m)^REFERENCE REJECT ').Count
        status = if ($delimiterExit -eq 0 -and $delimiterPassed -eq $delimiterTotal) { 'passed' } else { 'failed' }
    }
    if ($evidence.typeDelimiters.status -ne 'passed') { $status = 'failed'; $evidence.status = 'failed' }
}
if ($evidence.inferenceCallsiteCount -ne 2) { throw 'both production generic inference paths must consume the shared borrowed-type rule' }
if ($ReadonlyTextSlice) {
    $sliceContractPath = Join-Path $repo 'scripts/contracts/readonly-text-slice.json'
    $sliceContract = Get-Content -LiteralPath $sliceContractPath -Raw | ConvertFrom-Json
    if ($sliceContract.schemaVersion -ne 1 -or $sliceContract.checks.Count -ne 11 -or $sliceContract.consumers.Count -ne 3) { throw 'readonly Text slice probe contract drifted' }
    $sliceOutput = (& dotnet run --no-build --project $projectPath --configuration Release -- $compiler $fixture --readonly-text-slice 2>&1) -join "`n"
    $sliceExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'readonly-text-slice.log'), $sliceOutput + "`n")
    $slicePassed = [regex]::Matches($sliceOutput, '(?m)^PASS readonly-text-slice-').Count
    $evidence.readonlyTextSlice = @{
        scope = $sliceContract.scope; completed = $slicePassed; total = 11; exitCode = $sliceExit
        consumerCount = 3
        status = if ($sliceExit -eq 0 -and $slicePassed -eq 11 -and $sliceOutput -match '(?m)^readonly-text-slice=11/11\r?$') { 'passed' } else { 'failed' }
        contractSha256 = (Get-FileHash -LiteralPath $sliceContractPath -Algorithm SHA256).Hash
        extractedEmitterSha256 = (Get-FileHash -LiteralPath $sliceGeneratedPath -Algorithm SHA256).Hash
        emitterSourceSha256 = (Get-FileHash -LiteralPath $sliceEmitterPath -Algorithm SHA256).Hash
        runtimeValuesSha256 = (Get-FileHash -LiteralPath $runtimeValuesPath -Algorithm SHA256).Hash
        integration = 'fixture1719-passed-on-21906-direct-call-delta-and-final-Stage2-Stage3-pending'
    }
    if ($evidence.readonlyTextSlice.status -ne 'passed') { $status = 'failed'; $evidence.status = 'failed' }
}
if ($CandidateCompiler) {
    $candidate = [IO.Path]::GetFullPath($CandidateCompiler)
    $selfhostShapes = @()
    foreach ($case in @(@{ Id = 1719; Name = 'generic-readonly-slice-context'; Kind = 2 }, @{ Id = 1720; Name = 'generic-reference-context'; Kind = 8 })) {
        $path = Join-Path $repo ("scripts/contracts/fixtures/$($case.Id)-$($case.Name).slg")
        $records = (& $candidate semantic-type-records $path 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "selfhost semantic type records failed: $records" }
        [IO.File]::WriteAllText((Join-Path $output "$($case.Id)-selfhost-types.txt"), $records)
        $parameter = [regex]::Match($records, '(?m)^semantic type (\d+) kind 1 origin 3 .*status 0$')
        if (!$parameter.Success) { throw "selfhost fixture $($case.Id) has no canonical generic type parameter" }
        $shapePattern = '(?m)^semantic type (\d+) kind ' + $case.Kind + ' .* first ' + $parameter.Groups[1].Value + ' second -1 length -1 status 0$'
        if ($records -notmatch $shapePattern) { throw "selfhost fixture $($case.Id) lost the borrowed wrapper generic element" }
        $selfhostShapes += @{ fixture = $case.Id; wrapperKind = $case.Kind; genericTypeId = [int]$parameter.Groups[1].Value; status = 'passed' }
    }
    $evidence.selfhostTypeShapes = $selfhostShapes
    $evidence.selfhostCandidateSha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
}
[string]$managedFailure = ''
if ($ExecuteFixtures) {
    $executionContractPath = Join-Path $repo 'scripts/contracts/generic-type-context-execution.json'
    $execution = Get-Content -LiteralPath $executionContractPath -Raw | ConvertFrom-Json
    $selectedIds = @($FixtureId | Sort-Object -Unique)
    $allIds = @($execution.positive.id) + @($execution.negative.id)
    foreach ($id in $selectedIds) {
        if ($allIds -cnotcontains $id) { throw "unknown managed fixture selection: $id" }
    }
    $positiveCases = @($execution.positive | Where-Object { $selectedIds.Count -eq 0 -or $selectedIds -ccontains $_.id })
    $negativeCases = @($execution.negative | Where-Object { $selectedIds.Count -eq 0 -or $selectedIds -ccontains $_.id })
    $selectedManagedCases = @($positiveCases) + @($negativeCases)
    $selectedManagedIds = @(foreach ($selectedManagedCase in $selectedManagedCases) { $selectedManagedCase.id })
    $llvm = Join-Path $repo '.tools/llvm-22.1.8'
    $llvmAssembler = Join-Path $llvm 'bin/llvm-as.exe'
    $closureVerifier = Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1'
    $managed = [ordered]@{
        scope = $execution.scope; status = 'running'; completed = 0
        total = $selectedManagedCases.Count; contractTotal = $allIds.Count
        selectedIds = $selectedManagedIds
        cases = @(); compilerSha256 = $evidence.compilerSha256
        finalStageIntegration = 'pending-accumulated-Stage2-Stage3-and-required-targets'
    }
    $evidence.managedExecution = $managed
    $inputHashes = @{}
    try {
        if ($status -ne 'passed') { throw 'isolated generic/delimiter checks failed before managed source execution' }
        if ($execution.schemaVersion -ne 1 -or $execution.positive.Count -ne 7 -or $execution.negative.Count -ne 2) {
            throw 'managed generic execution contract dimensions drifted'
        }
        $cases = $selectedManagedCases
        foreach ($path in @($compiler, $executionContractPath, $llvmAssembler, $closureVerifier, $PSCommandPath) + @($cases | ForEach-Object { Join-Path $repo $_.source })) {
            $inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        }
        & (Join-Path $repo 'scripts/format-authoritative-slg.ps1') -Check -Compiler $compiler -Source @($cases | ForEach-Object { Join-Path $repo $_.source })
        foreach ($case in $positiveCases) {
            $path = Join-Path $repo $case.source
            $exe = Join-Path $output ($case.id + '.exe')
            $ll = [IO.Path]::ChangeExtension($exe, '.ll')
            $caseLog = Join-Path $output ($case.id + '.run.log')
            $caseResult = [ordered]@{ id = $case.id; source = $case.source; sourceSha256 = $inputHashes[$path]; status = 'running'; log = $caseLog }
            $managed.cases += $caseResult
            $runOutput = (& dotnet $compiler run $path --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
            $runExit = $LASTEXITCODE
            [IO.File]::WriteAllText($caseLog, $runOutput + "`n")
            $caseResult.exitCode = $runExit
            $caseResult.stdout = $runOutput.Replace("`r`n", "`n").TrimEnd()
            if ($runExit -ne 0 -or $caseResult.stdout -cne $case.stdout) {
                $caseResult.status = 'failed'
                $caseResult.failure = "managed $($case.id) did not execute with exact stdout"
                continue
            }
            $assemblyOutput = (& $llvmAssembler $ll -o ([IO.Path]::ChangeExtension($exe, '.bc')) 2>&1) -join "`n"
            $assemblyExit = $LASTEXITCODE
            [IO.File]::WriteAllText((Join-Path $output ($case.id + '.assemble.log')), $assemblyOutput + "`n")
            if ($assemblyExit -ne 0 -or -not [string]::IsNullOrWhiteSpace($assemblyOutput)) { throw "managed $($case.id) LLVM assembly failed or warned: $assemblyOutput" }
            $closureOutput = (& $closureVerifier -LlvmPath $ll 6>&1) -join "`n"
            [IO.File]::WriteAllText((Join-Path $output ($case.id + '.closure.log')), $closureOutput + "`n")
            $caseResult.llvmSha256 = (Get-FileHash -LiteralPath $ll -Algorithm SHA256).Hash
            $caseResult.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
            $caseResult.assembly = 'passed'; $caseResult.directCallClosure = 'passed'; $caseResult.status = 'passed'
            $managed.completed++
        }
        foreach ($case in $negativeCases) {
            if ([string]::IsNullOrWhiteSpace($case.diagnostic)) { throw "managed negative $($case.id) has an empty diagnostic contract" }
            $path = Join-Path $repo $case.source
            $exe = Join-Path $output ($case.id + '.exe')
            $ll = [IO.Path]::ChangeExtension($exe, '.ll')
            $temporaryLlvm = Join-Path $output ($case.id + '.slg-tmp/' + $case.id + '.ll')
            $caseLog = Join-Path $output ($case.id + '.build.log')
            $caseResult = [ordered]@{ id = $case.id; source = $case.source; sourceSha256 = $inputHashes[$path]; status = 'running'; log = $caseLog }
            $managed.cases += $caseResult
            $failureOutput = (& dotnet $compiler build $path --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
            $failureExit = $LASTEXITCODE
            [IO.File]::WriteAllText($caseLog, $failureOutput + "`n")
            $caseResult.exitCode = $failureExit
            $caseResult.diagnostic = $failureOutput
            if ($failureExit -eq 0 -or -not $failureOutput.Contains($case.diagnostic, [StringComparison]::Ordinal) -or
                $failureOutput -notmatch 'semantic error' -or
                (Test-Path -LiteralPath $exe) -or (Test-Path -LiteralPath $ll) -or (Test-Path -LiteralPath $temporaryLlvm)) {
                $caseResult.status = 'failed'
                $caseResult.failure = "managed negative $($case.id) did not fail before LLVM"
                continue
            }
            $caseResult.beforeLlvm = $true; $caseResult.status = 'passed'; $managed.completed++
        }
        foreach ($path in $inputHashes.Keys) {
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$path]) { throw "managed execution input changed: $path" }
        }
        if ($managed.completed -ne $managed.total) {
            $failedIds = @($managed.cases | Where-Object { $_.status -ne 'passed' } | ForEach-Object { $_.id })
            throw "managed execution failed for selected fixture IDs: $($failedIds -join ', ')"
        }
        $managed.inputHashes = $inputHashes; $managed.status = 'passed'
        $evidence.integration = 'managed-selected-source-execution-passed-final-accumulated-Stage2-Stage3-pending'
    } catch {
        $managedFailure = $_.Exception.Message
        foreach ($caseResult in $managed.cases) {
            if ($caseResult.status -eq 'running') { $caseResult.status = 'failed'; $caseResult.failure = $managedFailure }
        }
        $managed.inputHashes = $inputHashes
        $managed.status = 'failed'; $managed.failure = $managedFailure
        $status = 'failed'; $evidence.status = 'failed'
    }
}
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($evidence | ConvertTo-Json -Depth 4))
if ($status -ne 'passed') { throw "generic type context probe failed: $managedFailure; evidence: $(Join-Path $output 'result.json')" }
Write-Output 'Generic type contexts: extracted production methods + current DLL type parser and place validator PASS 21/21.'
if ($TypeDelimiters) {
    Write-Output "Type delimiters: selected production parser branches + existing real type table PASS $delimiterPassed/$delimiterTotal; whole compiler integration pending."
}
if ($ExecuteFixtures) { Write-Output "Managed focused source execution PASS $($managed.completed)/$($managed.total); final accumulated Stage2/Stage3 pending." }
if ($ReadonlyTextSlice) { Write-Output "Extracted shared array classifier + three readonly Text call consumers PASS $slicePassed/11; current ordinary-call and final Stage integration are recorded separately." }
Write-Output (Join-Path $output 'result.json')
