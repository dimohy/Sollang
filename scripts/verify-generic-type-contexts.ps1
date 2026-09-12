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
$semanticSourcePath = Join-Path $repo 'src/Sollang.Compiler/Semantics/SemanticCompiler.cs'
$source = Get-Content -LiteralPath $semanticSourcePath -Raw
function Read-Methods([string]$Name, [int]$Count) {
    $pattern = '(?ms)^    private (?:static )?[^\r\n]+\b' + [regex]::Escape($Name) + '(?:<[^>]+>)?\(.*?^    \}'
    $matches = [regex]::Matches($source, $pattern)
    if ($matches.Count -ne $Count) { throw "expected $Count authoritative $Name declarations; found $($matches.Count)" }
    return ($matches | ForEach-Object Value) -join "`n`n"
}
$specialization = Read-Methods 'ParseSpecializedFunctionType' 2
$referencesParameter = Read-Methods 'TypeSyntaxReferencesParameter' 1
$delimiters = Read-Methods 'FindTopLevelTypeComma' 1
$delimiters += "`n" + (Read-Methods 'FindTopLevelTypeColon' 1)
$delimiters += "`n" + (Read-Methods 'SplitTopLevelProductFields' 1)
$delimiters += "`n" + (Read-Methods 'ParseProductTypeFields' 1)
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
$boundSourcePath = Join-Path $repo 'src/Sollang.Compiler/Semantics/BoundProgram.cs'
$boundSource = Get-Content -LiteralPath $boundSourcePath -Raw
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
    temporaryReferenceSource = 'scripts/probes/type-delimiters/temporary-reference-negative.slg'
}
[string]$focusedFailure = ''
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

    $layoutCases = @($matrixCases.declarationLayouts)
    $requiredLayoutCoverage = @(
        'function-input',
        'function-return',
        'struct-field',
        'enum-payload',
        'fixed-product',
        'bounded-product',
        'growable-product',
        'readonly-product',
        'reference-product',
        'nested-product',
        'native-layout-consumption'
    )
    if ($layoutCases.Count -ne 2) { throw 'type delimiter declaration/layout contract must retain two focused consumers' }
    $coveredLayoutRequirements = @($layoutCases.coverage | ForEach-Object { $_ } | Sort-Object -Unique)
    if (@(Compare-Object $requiredLayoutCoverage $coveredLayoutRequirements).Count -ne 0) {
        throw 'type delimiter declaration/layout contract does not cover the required consumers and storage shapes'
    }
    $functionLayoutSource = Get-Content -LiteralPath (Join-Path $repo $layoutCases[0].source) -Raw
    $declarationLayoutSource = Get-Content -LiteralPath (Join-Path $repo $layoutCases[1].source) -Raw
    foreach ($requiredFunctionShape in @(
        'makePair: -> (left: Int, right: [Int; 2])',
        'makeFixed: -> [(left: Int, right: Int); 2]',
        'makeBounded: -> [(left: Int, right: Int); <=3]',
        'makeGrowable: -> [(left: Int, right: Int); ~]',
        'readView values: [(left: Int, right: Int)]',
        'readReference value: ref (left: Int, right: [Int; 2])'
    )) {
        if (-not $functionLayoutSource.Contains($requiredFunctionShape, [StringComparison]::Ordinal)) {
            throw "function declaration/layout probe lost required shape: $requiredFunctionShape"
        }
    }
    foreach ($requiredDeclarationShape in @(
        'product: (left: Int, right: [Int; 2])',
        'fixed: [(left: Int, right: Int); 2]',
        'bounded: [(left: Int, right: Int); <=3]',
        'growable: [(left: Int, right: Int); ~]',
        'Product((left: Int, right: [Int; 2]))',
        'Fixed([(left: Int, right: Int); 2])',
        'Bounded([(left: Int, right: Int); <=3])',
        'Growable([(left: Int, right: Int); ~])',
        'Reference(ref (left: Int, right: Int))',
        'layout.fixed[1].right',
        'Product(value) { value.left + value.right[1] -> println }'
    )) {
        if (-not $declarationLayoutSource.Contains($requiredDeclarationShape, [StringComparison]::Ordinal)) {
            throw "struct/enum declaration layout probe lost required shape: $requiredDeclarationShape"
        }
    }

    $layoutSources = @($layoutCases | ForEach-Object { Join-Path $repo $_.source })
    & (Join-Path $repo 'scripts/format-authoritative-slg.ps1') -Check -Compiler $compiler -Source $layoutSources
    $layoutLlvm = Join-Path $repo '.tools/llvm-22.1.8'
    $layoutAssembler = Join-Path $layoutLlvm 'bin/llvm-as.exe'
    $layoutClosureVerifier = Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1'
    $layoutProductionHashes = [ordered]@{
        semanticCompiler = (Get-FileHash -LiteralPath $semanticSourcePath -Algorithm SHA256).Hash
        typeDefinitionTable = (Get-FileHash -LiteralPath $boundSourcePath -Algorithm SHA256).Hash
    }
    $layoutResults = @()
    $layoutCompleted = 0
    foreach ($layoutCase in $layoutCases) {
        $layoutPath = Join-Path $repo $layoutCase.source
        $layoutExe = Join-Path $output ($layoutCase.id + '.exe')
        $layoutLl = [IO.Path]::ChangeExtension($layoutExe, '.ll')
        $layoutLog = Join-Path $output ($layoutCase.id + '.run.log')
        $layoutResult = [ordered]@{
            id = $layoutCase.id
            source = $layoutCase.source
            sourceSha256 = (Get-FileHash -LiteralPath $layoutPath -Algorithm SHA256).Hash
            coverage = @($layoutCase.coverage)
            status = 'running'
            log = $layoutLog
        }
        $layoutResults += $layoutResult
        $layoutOutput = (& dotnet $compiler run $layoutPath --llvm $layoutLlvm -o $layoutExe --keep-temps 2>&1) -join "`n"
        $layoutExit = $LASTEXITCODE
        [IO.File]::WriteAllText($layoutLog, $layoutOutput + "`n")
        $layoutResult.exitCode = $layoutExit
        $layoutResult.stdout = $layoutOutput.Replace("`r`n", "`n").TrimEnd()
        if ($layoutExit -ne 0 -or $layoutResult.stdout -cne $layoutCase.stdout) {
            $layoutResult.status = 'failed'
            $layoutResult.failure = 'focused managed source did not compile and execute with exact output'
            continue
        }
        $layoutAssemblyOutput = (& $layoutAssembler $layoutLl -o ([IO.Path]::ChangeExtension($layoutExe, '.bc')) 2>&1) -join "`n"
        $layoutAssemblyExit = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output ($layoutCase.id + '.assemble.log')), $layoutAssemblyOutput + "`n")
        if ($layoutAssemblyExit -ne 0 -or -not [string]::IsNullOrWhiteSpace($layoutAssemblyOutput)) {
            $layoutResult.status = 'failed'
            $layoutResult.failure = 'focused declaration/layout LLVM did not assemble without diagnostics'
            continue
        }
        $layoutClosureOutput = (& $layoutClosureVerifier -LlvmPath $layoutLl 6>&1) -join "`n"
        $layoutClosureExit = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output ($layoutCase.id + '.closure.log')), $layoutClosureOutput + "`n")
        if ($layoutClosureExit -ne 0) {
            $layoutResult.status = 'failed'
            $layoutResult.failure = 'focused declaration/layout LLVM direct-call closure failed'
            continue
        }
        if ((Get-FileHash -LiteralPath $layoutPath -Algorithm SHA256).Hash -cne $layoutResult.sourceSha256) {
            throw "focused declaration/layout input changed: $layoutPath"
        }
        $layoutResult.llvmSha256 = (Get-FileHash -LiteralPath $layoutLl -Algorithm SHA256).Hash
        $layoutResult.executableSha256 = (Get-FileHash -LiteralPath $layoutExe -Algorithm SHA256).Hash
        $layoutResult.assembly = 'passed'
        $layoutResult.directCallClosure = 'passed'
        $layoutResult.status = 'passed'
        $layoutCompleted++
    }
    $semanticSourceChanged = (Get-FileHash -LiteralPath $semanticSourcePath -Algorithm SHA256).Hash -cne $layoutProductionHashes.semanticCompiler
    $typeTableSourceChanged = (Get-FileHash -LiteralPath $boundSourcePath -Algorithm SHA256).Hash -cne $layoutProductionHashes.typeDefinitionTable
    if ($semanticSourceChanged -or $typeTableSourceChanged) {
        throw 'focused declaration/layout production source changed during verification'
    }
    $layoutStatus = if ($layoutCompleted -eq $layoutCases.Count) { 'passed' } else { 'failed' }
    $evidence.declarationLayouts = @{
        scope = 'current-production-parser-type-table-and-native-layout-consumers'
        completed = $layoutCompleted
        total = $layoutCases.Count
        status = $layoutStatus
        cases = $layoutResults
        requiredCoverage = $requiredLayoutCoverage
        compilerSha256 = $evidence.compilerSha256
        productionSourceHashes = $layoutProductionHashes
        finalStageIntegration = 'pending-accumulated-Stage2-Stage3-and-required-targets'
    }
    if ($layoutStatus -ne 'passed') {
        $failedLayoutIds = @($layoutResults | Where-Object { $_.status -ne 'passed' } | ForEach-Object { $_.id })
        $focusedFailure = "declaration/layout consumers failed: $($failedLayoutIds -join ', ')"
        $status = 'failed'
        $evidence.status = 'failed'
    }

    $declarationCases = @($matrixCases.declarationRecursionAndDiagnostics)
    $requiredDeclarationCoverage = @(
        'self-recursive-nominal-reference',
        'direct-value-recursion',
        'duplicate-product-label',
        'empty-product-label'
    )
    if ($declarationCases.Count -ne 4 -or
        @($declarationCases | Where-Object kind -eq 'positive').Count -ne 1 -or
        @($declarationCases | Where-Object kind -eq 'negative').Count -ne 3) {
        throw 'declaration recursion/diagnostic contract must retain one positive and three negative cases'
    }
    if (@(Compare-Object $requiredDeclarationCoverage @($declarationCases.coverage | Sort-Object -Unique)).Count -ne 0) {
        throw 'declaration recursion/diagnostic contract does not cover all required boundaries'
    }
    foreach ($negativeCase in @($declarationCases | Where-Object kind -eq 'negative')) {
        if ([string]::IsNullOrWhiteSpace($negativeCase.diagnosticKind) -or
            [string]::IsNullOrWhiteSpace($negativeCase.diagnostic)) {
            throw "declaration negative '$($negativeCase.id)' requires exact diagnostic kind and text"
        }
    }
    $requiredDeclarationShapes = [ordered]@{
        'self-recursive-reference' = 'next: ref RecursiveNode'
        'direct-value-recursion' = 'next: RecursiveValue'
        'duplicate-product-label' = 'value: (item: Int, item: Text)'
        'empty-product-label' = 'value: (: Int, item: Text)'
    }
    foreach ($declarationCase in $declarationCases) {
        $declarationSource = Get-Content -LiteralPath (Join-Path $repo $declarationCase.source) -Raw
        if (-not $requiredDeclarationShapes.Contains($declarationCase.id) -or
            -not $declarationSource.Contains($requiredDeclarationShapes[$declarationCase.id], [StringComparison]::Ordinal)) {
            throw "declaration recursion/diagnostic probe lost required shape: $($declarationCase.id)"
        }
    }

    $positiveDeclarationSources = @($declarationCases |
        Where-Object kind -eq 'positive' |
        ForEach-Object { Join-Path $repo $_.source })
    & (Join-Path $repo 'scripts/format-authoritative-slg.ps1') -Check -Compiler $compiler -Source $positiveDeclarationSources
    $declarationResults = @()
    $declarationCompleted = 0
    foreach ($declarationCase in $declarationCases) {
        $declarationPath = Join-Path $repo $declarationCase.source
        $declarationExe = Join-Path $output ($declarationCase.id + '.exe')
        $declarationLl = [IO.Path]::ChangeExtension($declarationExe, '.ll')
        $declarationTemporaryLl = Join-Path $output ($declarationCase.id + '.slg-tmp/' + $declarationCase.id + '.ll')
        $declarationLog = Join-Path $output ($declarationCase.id + '.log')
        $declarationResult = [ordered]@{
            id = $declarationCase.id
            source = $declarationCase.source
            kind = $declarationCase.kind
            coverage = $declarationCase.coverage
            sourceSha256 = (Get-FileHash -LiteralPath $declarationPath -Algorithm SHA256).Hash
            status = 'running'
            log = $declarationLog
        }
        $declarationResults += $declarationResult
        if ($declarationCase.kind -eq 'positive') {
            $declarationOutput = (& dotnet $compiler run $declarationPath --llvm $layoutLlvm -o $declarationExe --keep-temps 2>&1) -join "`n"
            $declarationExit = $LASTEXITCODE
            [IO.File]::WriteAllText($declarationLog, $declarationOutput + "`n")
            $declarationResult.exitCode = $declarationExit
            $declarationResult.stdout = $declarationOutput.Replace("`r`n", "`n").TrimEnd()
            if ($declarationExit -ne 0 -or $declarationResult.stdout -cne $declarationCase.stdout) {
                $declarationResult.status = 'failed'
                $declarationResult.failure = 'self-recursive nominal reference did not compile and execute with exact output'
                continue
            }
            $declarationAssemblyOutput = (& $layoutAssembler $declarationLl -o ([IO.Path]::ChangeExtension($declarationExe, '.bc')) 2>&1) -join "`n"
            $declarationAssemblyExit = $LASTEXITCODE
            if ($declarationAssemblyExit -ne 0 -or -not [string]::IsNullOrWhiteSpace($declarationAssemblyOutput)) {
                $declarationResult.status = 'failed'
                $declarationResult.failure = 'self-recursive nominal reference LLVM did not assemble without diagnostics'
                continue
            }
            $declarationClosureOutput = (& $layoutClosureVerifier -LlvmPath $declarationLl 6>&1) -join "`n"
            if ($LASTEXITCODE -ne 0) {
                $declarationResult.status = 'failed'
                $declarationResult.failure = "self-recursive nominal reference direct-call closure failed: $declarationClosureOutput"
                continue
            }
            $declarationResult.assembly = 'passed'
            $declarationResult.directCallClosure = 'passed'
            $declarationResult.llvmSha256 = (Get-FileHash -LiteralPath $declarationLl -Algorithm SHA256).Hash
            $declarationResult.executableSha256 = (Get-FileHash -LiteralPath $declarationExe -Algorithm SHA256).Hash
        } else {
            $declarationOutput = (& dotnet $compiler build $declarationPath --llvm $layoutLlvm -o $declarationExe --keep-temps 2>&1) -join "`n"
            $declarationExit = $LASTEXITCODE
            [IO.File]::WriteAllText($declarationLog, $declarationOutput + "`n")
            $declarationResult.exitCode = $declarationExit
            $declarationResult.diagnosticKind = $declarationCase.diagnosticKind
            $declarationResult.diagnostic = $declarationCase.diagnostic
            $declarationResult.actualDiagnostic = $declarationOutput
            if ($declarationExit -eq 0 -or
                -not $declarationOutput.Contains($declarationCase.diagnosticKind, [StringComparison]::Ordinal) -or
                -not $declarationOutput.Contains($declarationCase.diagnostic, [StringComparison]::Ordinal) -or
                (Test-Path -LiteralPath $declarationExe) -or
                (Test-Path -LiteralPath $declarationLl) -or
                (Test-Path -LiteralPath $declarationTemporaryLl)) {
                $declarationResult.status = 'failed'
                $declarationResult.failure = 'declaration negative did not fail with the exact diagnostic before LLVM emission'
                continue
            }
            $declarationResult.beforeLlvm = $true
        }
        if ((Get-FileHash -LiteralPath $declarationPath -Algorithm SHA256).Hash -cne $declarationResult.sourceSha256) {
            throw "declaration recursion/diagnostic input changed: $declarationPath"
        }
        $declarationResult.status = 'passed'
        $declarationCompleted++
    }
    $declarationStatus = if ($declarationCompleted -eq $declarationCases.Count) { 'passed' } else { 'failed' }
    $negativeBeforeLlvm = @($declarationResults | Where-Object {
        $_.Contains('beforeLlvm') -and $_['beforeLlvm'] -eq $true
    }).Count
    $expectedNegativeCount = @($declarationCases | Where-Object kind -eq 'negative').Count
    if ($negativeBeforeLlvm -ne $expectedNegativeCount) {
        throw "declaration negative pre-LLVM evidence differs: $negativeBeforeLlvm/$expectedNegativeCount"
    }
    $evidence.declarationRecursionAndDiagnostics = @{
        scope = 'current-managed-declaration-recursion-and-product-label-diagnostics'
        completed = $declarationCompleted
        total = $declarationCases.Count
        status = $declarationStatus
        cases = $declarationResults
        requiredCoverage = $requiredDeclarationCoverage
        compilerSha256 = $evidence.compilerSha256
        negativeBeforeLlvm = $negativeBeforeLlvm
        finalStageIntegration = 'pending-accumulated-Stage2-Stage3-and-required-targets'
    }
    if ($declarationStatus -ne 'passed') {
        $failedDeclarationIds = @($declarationResults | Where-Object status -ne 'passed' | ForEach-Object id)
        $declarationFailure = "declaration recursion/diagnostics failed: $($failedDeclarationIds -join ', ')"
        $focusedFailure = (@($focusedFailure, $declarationFailure) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '; '
        $status = 'failed'
        $evidence.status = 'failed'
    }
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
    $candidateInputSha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
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
    $evidence.selfhostCandidateSha256 = $candidateInputSha256

    if ($TypeDelimiters) {
        if ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -cne $candidateInputSha256) {
            throw 'selfhost candidate changed before the C396 Windows gate started'
        }
        $candidateExecutionContractPath = Join-Path $repo 'scripts/contracts/generic-type-context-execution.json'
        $candidateExecutionContract = Get-Content -LiteralPath $candidateExecutionContractPath -Raw | ConvertFrom-Json
        # This authority is deliberately independent from both JSON contracts.  A coordinated JSON edit
        # must not be able to weaken the candidate promotion gate without changing this verifier too.
        $candidateC396Cases = @(
            [pscustomobject]@{ id = 'result-product-payload'; kind = 'positive'; source = 'scripts/probes/type-delimiters/result-product-payload.slg'; expected = '0'; diagnosticKind = ''; candidateDiagnosticPattern = ''; coverage = 'result-product-payload' },
            [pscustomobject]@{ id = 'readonly-product-array'; kind = 'positive'; source = 'scripts/probes/type-delimiters/readonly-product-array.slg'; expected = '0'; diagnosticKind = ''; candidateDiagnosticPattern = ''; coverage = 'readonly-product-array' },
            [pscustomobject]@{ id = 'nested-labeled-product'; kind = 'positive'; source = 'scripts/probes/type-delimiters/nested-labeled-product.slg'; expected = '0'; diagnosticKind = ''; candidateDiagnosticPattern = ''; coverage = 'nested-labeled-product' },
            [pscustomobject]@{ id = 'function-layout-consumers'; kind = 'positive'; source = 'scripts/probes/type-delimiters/function-layout-consumers.slg'; expected = "23`n5`n13`n21"; diagnosticKind = ''; candidateDiagnosticPattern = ''; coverage = 'function-layout-consumers' },
            [pscustomobject]@{ id = 'declaration-layout-consumers'; kind = 'positive'; source = 'scripts/probes/type-delimiters/declaration-layout-consumers.slg'; expected = "30`n26"; diagnosticKind = ''; candidateDiagnosticPattern = ''; coverage = 'declaration-layout-consumers' },
            [pscustomobject]@{ id = 'self-recursive-reference'; kind = 'positive'; source = 'scripts/probes/type-delimiters/self-recursive-reference.slg'; expected = '1'; diagnosticKind = ''; candidateDiagnosticPattern = ''; coverage = 'self-recursive-nominal-reference' },
            [pscustomobject]@{ id = 'direct-nested-container'; kind = 'negative'; source = 'scripts/probes/type-delimiters/direct-nested-container-negative.slg'; expected = 'readonly array views require inline scalar or user-value elements'; diagnosticKind = 'semantic error'; candidateDiagnosticStream = 'stdout'; candidateDiagnosticPattern = '^; sollang semantic error: readonly array views require inline scalar or user-value elements$'; coverage = 'direct-nested-container' },
            [pscustomobject]@{ id = 'direct-value-recursion'; kind = 'negative'; source = 'scripts/probes/type-delimiters/direct-value-recursion.slg'; expected = 'recursively contains itself; recursive values require an explicit heap reference type'; diagnosticKind = 'semantic error'; candidateDiagnosticStream = 'stdout'; candidateDiagnosticPattern = '^; sollang compiler error S058: type has a recursive by-value layout \(source 0, byte [0-9]+, length [0-9]+\); use explicit box or heap-backed storage to break the value cycle$'; coverage = 'direct-value-recursion' },
            [pscustomobject]@{ id = 'duplicate-product-label'; kind = 'negative'; source = 'scripts/probes/type-delimiters/duplicate-product-label.slg'; expected = "duplicate product field label 'item'"; diagnosticKind = 'parse error'; candidateDiagnosticStream = 'stdout'; candidateDiagnosticPattern = "^; sollang syntax error: duplicate product field label 'item' \(source 0, byte [0-9]+, length [0-9]+\)$"; coverage = 'duplicate-product-label' },
            [pscustomobject]@{ id = 'empty-product-label'; kind = 'negative'; source = 'scripts/probes/type-delimiters/empty-product-label.slg'; expected = 'expected Identifier'; diagnosticKind = 'parse error'; candidateDiagnosticStream = 'stdout'; candidateDiagnosticPattern = '^; sollang syntax error: expected Identifier \(source 0, byte [0-9]+, length [0-9]+\)$'; coverage = 'empty-product-label' }
        )
        $candidateC396Ids = @($candidateC396Cases | ForEach-Object id)
        if ($candidateC396Cases.Count -ne 10 -or
            @($candidateC396Cases | Where-Object kind -eq 'positive').Count -ne 6 -or
            @($candidateC396Cases | Where-Object kind -eq 'negative').Count -ne 4 -or
            @($candidateC396Ids | Sort-Object -Unique).Count -ne 10) {
            throw 'C396 candidate contract must retain six unique positive and four unique negative cases'
        }

        $candidateJsonCases = @(
            $candidateExecutionContract.positive | ForEach-Object {
                [pscustomobject]@{ id = $_.id; kind = 'positive'; source = $_.source; expected = $_.stdout; diagnosticKind = '' }
            }
            $candidateExecutionContract.negative | ForEach-Object {
                [pscustomobject]@{ id = $_.id; kind = 'negative'; source = $_.source; expected = $_.diagnostic; diagnosticKind = 'semantic error' }
            }
            $layoutCases | ForEach-Object {
                [pscustomobject]@{ id = $_.id; kind = 'positive'; source = $_.source; expected = $_.stdout; diagnosticKind = '' }
            }
            $declarationCases | ForEach-Object {
                [pscustomobject]@{ id = $_.id; kind = $_.kind; source = $_.source; expected = if ($_.kind -eq 'positive') { $_.stdout } else { $_.diagnostic }; diagnosticKind = if ($_.kind -eq 'negative') { $_.diagnosticKind } else { '' } }
            }
        )
        foreach ($authorityCase in $candidateC396Cases) {
            $jsonMatches = @($candidateJsonCases | Where-Object id -CEQ $authorityCase.id)
            if ($jsonMatches.Count -ne 1) { throw "C396 JSON contract must contain exactly one '$($authorityCase.id)' tuple" }
            $jsonCase = $jsonMatches[0]
            if ($jsonCase.kind -cne $authorityCase.kind -or
                $jsonCase.source -cne $authorityCase.source -or
                $jsonCase.expected -cne $authorityCase.expected -or
                $jsonCase.diagnosticKind -cne $authorityCase.diagnosticKind) {
                throw "C396 JSON contract tuple drifted from verifier authority: $($authorityCase.id)"
            }
        }

        function Invoke-C396CapturedProcess([string]$FilePath, [string[]]$Arguments) {
            $startInfo = [Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = $FilePath
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
            $process = [Diagnostics.Process]::new()
            $process.StartInfo = $startInfo
            if (-not $process.Start()) { throw "failed to start C396 verifier process: $FilePath" }
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit()
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            $exitCode = $process.ExitCode
            $process.Dispose()
            return [pscustomobject]@{ exitCode = $exitCode; stdout = $stdout; stderr = $stderr }
        }
        function ConvertTo-C396ExactText([string]$Text) {
            return $Text.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n")
        }
        function Get-C396ContainedExistingPath([string]$Path, [string]$Root, [string]$Description) {
            $resolvedRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            $resolvedPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
            if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "$Description escaped its resolved root: $resolvedPath"
            }
            return $resolvedPath
        }
        function Get-C396ContainedArtifactPath([string]$Path, [string]$Root, [string]$Description) {
            $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            $resolvedPath = [IO.Path]::GetFullPath($Path)
            if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "$Description escaped its scratch root: $resolvedPath"
            }
            return $resolvedPath
        }
        function Test-C396ContainsLlvm([string]$Text) {
            return $Text -match '(?im)^\s*(?:source_filename\s*=|target\s+(?:triple|datalayout)\s*=|define\b|declare\b|attributes\b|module asm\b|![A-Za-z0-9_.-]+\s*=|@[-A-Za-z0-9_.$]+\s*=|%[-A-Za-z0-9_.$]+\s*=\s*type\b|[-A-Za-z0-9_.$]+:\s*(?:;.*)?$|[{}]\s*$|(?:[%@][-A-Za-z0-9_.$]+\s*=\s*)?(?:ret|br|switch|indirectbr|invoke|call|callbr|resume|unreachable|alloca|load|store|fence|cmpxchg|atomicrmw|getelementptr|extractvalue|insertvalue|phi|select|icmp|fcmp|add|sub|mul|udiv|sdiv|fdiv|urem|srem|frem|shl|lshr|ashr|and|or|xor|trunc|zext|sext|fptrunc|fpext|fptoui|fptosi|uitofp|sitofp|ptrtoint|inttoptr|bitcast|addrspacecast|va_arg|landingpad|catchpad|cleanuppad)\b|;(?!\s*sollang (?:(?:syntax|semantic) error:|compiler error(?: [A-Z][0-9]+)?:)))'
        }
        function Write-C396StreamLogs([string]$Prefix, [pscustomobject]$Result) {
            [IO.File]::WriteAllText($Prefix + '.stdout.log', $Result.stdout)
            [IO.File]::WriteAllText($Prefix + '.stderr.log', $Result.stderr)
        }

        $candidateClang = Join-Path $layoutLlvm 'bin/clang.exe'
        $candidatePowerShell = (Get-Command pwsh -CommandType Application -ErrorAction Stop).Source
        $candidateSourceRoot = Join-Path $repo 'scripts/probes/type-delimiters'
        $candidateScratchRoot = Get-C396ContainedArtifactPath $output (Join-Path $repo 'artifacts/scratch/generic-type-contexts') 'candidate output directory'
        $candidateResults = @()
        $candidateCompleted = 0
        $candidateNegativeBeforeLlvm = 0
        $candidateInputHashes = [ordered]@{}
        foreach ($candidateInputPath in @($candidate, $candidateExecutionContractPath, $matrix, $PSCommandPath, $layoutAssembler, $candidateClang, $layoutClosureVerifier)) {
            $candidateResolvedInputPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $candidateInputPath).Path)
            $candidateInputHashes[$candidateResolvedInputPath] = (Get-FileHash -LiteralPath $candidateResolvedInputPath -Algorithm SHA256).Hash
        }
        foreach ($candidateCase in $candidateC396Cases) {
            if ($candidateCase.id -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw "unsafe C396 case id: $($candidateCase.id)" }
            if ([IO.Path]::IsPathRooted($candidateCase.source)) { throw "C396 source must be repository-relative: $($candidateCase.id)" }
            $candidateSource = Get-C396ContainedExistingPath (Join-Path $repo $candidateCase.source) $candidateSourceRoot "C396 source '$($candidateCase.id)'"
            $candidateInputHashes[$candidateSource] = (Get-FileHash -LiteralPath $candidateSource -Algorithm SHA256).Hash
        }

        foreach ($candidateCase in $candidateC396Cases) {
            $candidateSource = Get-C396ContainedExistingPath (Join-Path $repo $candidateCase.source) $candidateSourceRoot "C396 source '$($candidateCase.id)'"
            $candidateCaseRoot = Get-C396ContainedArtifactPath (Join-Path $candidateScratchRoot ('candidate-' + $candidateCase.id)) $candidateScratchRoot "C396 artifact directory '$($candidateCase.id)'"
            New-Item -ItemType Directory -Path $candidateCaseRoot | Out-Null
            $candidateCaseRoot = Get-C396ContainedExistingPath $candidateCaseRoot $candidateScratchRoot "C396 artifact directory '$($candidateCase.id)'"
            $candidateLl = Get-C396ContainedArtifactPath (Join-Path $candidateCaseRoot 'output.ll') $candidateScratchRoot "C396 LLVM '$($candidateCase.id)'"
            $candidateBc = Get-C396ContainedArtifactPath (Join-Path $candidateCaseRoot 'output.bc') $candidateScratchRoot "C396 bitcode '$($candidateCase.id)'"
            $candidateExe = Get-C396ContainedArtifactPath (Join-Path $candidateCaseRoot 'output.exe') $candidateScratchRoot "C396 executable '$($candidateCase.id)'"
            $candidateCaseResult = [ordered]@{
                id = $candidateCase.id
                source = $candidateCase.source
                kind = $candidateCase.kind
                coverage = $candidateCase.coverage
                sourceSha256 = $candidateInputHashes[$candidateSource]
                status = 'running'
            }
            $candidateResults += $candidateCaseResult
            if ($candidateCase.kind -eq 'positive') {
                $candidateEmit = Invoke-C396CapturedProcess $candidate @('windows', $candidateSource)
                Write-C396StreamLogs (Join-Path $candidateCaseRoot 'emit') $candidateEmit
                $candidateCaseResult.exitCode = $candidateEmit.exitCode
                if ($candidateEmit.exitCode -ne 0 -or
                    [string]::IsNullOrWhiteSpace($candidateEmit.stdout) -or
                    -not [string]::IsNullOrWhiteSpace($candidateEmit.stderr)) {
                    $candidateCaseResult.status = 'failed'
                    $candidateCaseResult.failure = 'candidate did not emit diagnostic-free Windows LLVM'
                    continue
                }
                [IO.File]::WriteAllText($candidateLl, $candidateEmit.stdout)
                $candidateLl = Get-C396ContainedExistingPath $candidateLl $candidateScratchRoot "C396 LLVM '$($candidateCase.id)'"
                $candidateAssembly = Invoke-C396CapturedProcess $layoutAssembler @($candidateLl, '-o', $candidateBc)
                Write-C396StreamLogs (Join-Path $candidateCaseRoot 'assemble') $candidateAssembly
                if ($candidateAssembly.exitCode -ne 0 -or
                    -not [string]::IsNullOrWhiteSpace($candidateAssembly.stdout) -or
                    -not [string]::IsNullOrWhiteSpace($candidateAssembly.stderr) -or
                    -not (Test-Path -LiteralPath $candidateBc -PathType Leaf)) {
                    $candidateCaseResult.status = 'failed'
                    $candidateCaseResult.failure = 'candidate Windows LLVM did not assemble without diagnostics'
                    continue
                }
                $candidateBc = Get-C396ContainedExistingPath $candidateBc $candidateScratchRoot "C396 bitcode '$($candidateCase.id)'"
                $candidateClosure = Invoke-C396CapturedProcess $candidatePowerShell @('-NoProfile', '-File', $layoutClosureVerifier, '-LlvmPath', $candidateLl)
                Write-C396StreamLogs (Join-Path $candidateCaseRoot 'closure') $candidateClosure
                if ($candidateClosure.exitCode -ne 0) {
                    $candidateCaseResult.status = 'failed'
                    $candidateCaseResult.failure = 'candidate Windows LLVM direct-call closure failed'
                    continue
                }
                $candidateLink = Invoke-C396CapturedProcess $candidateClang @('-Wno-override-module', $candidateLl, '-O1', '-o', $candidateExe, '-lws2_32', '-lshell32', '-lbcrypt')
                Write-C396StreamLogs (Join-Path $candidateCaseRoot 'link') $candidateLink
                if ($candidateLink.exitCode -ne 0 -or
                    -not [string]::IsNullOrWhiteSpace($candidateLink.stdout) -or
                    -not [string]::IsNullOrWhiteSpace($candidateLink.stderr) -or
                    -not (Test-Path -LiteralPath $candidateExe -PathType Leaf)) {
                    $candidateCaseResult.status = 'failed'
                    $candidateCaseResult.failure = 'candidate Windows LLVM did not link with empty output'
                    continue
                }
                $candidateExe = Get-C396ContainedExistingPath $candidateExe $candidateScratchRoot "C396 executable '$($candidateCase.id)'"
                $candidateRun = Invoke-C396CapturedProcess $candidateExe @()
                Write-C396StreamLogs (Join-Path $candidateCaseRoot 'run') $candidateRun
                $candidateCaseResult.stdout = ConvertTo-C396ExactText $candidateRun.stdout
                $candidateCaseResult.stderr = ConvertTo-C396ExactText $candidateRun.stderr
                $candidateCaseResult.runExitCode = $candidateRun.exitCode
                if ($candidateRun.exitCode -ne 0 -or
                    $candidateCaseResult.stdout -cne $candidateCase.expected -or
                    -not [string]::IsNullOrWhiteSpace($candidateRun.stderr)) {
                    $candidateCaseResult.status = 'failed'
                    $candidateCaseResult.failure = 'candidate Windows executable did not produce exact stdout with empty stderr'
                    continue
                }
                $candidateCaseResult.llvmSha256 = (Get-FileHash -LiteralPath $candidateLl -Algorithm SHA256).Hash
                $candidateCaseResult.bitcodeSha256 = (Get-FileHash -LiteralPath $candidateBc -Algorithm SHA256).Hash
                $candidateCaseResult.executableSha256 = (Get-FileHash -LiteralPath $candidateExe -Algorithm SHA256).Hash
                $candidateCaseResult.assembly = 'passed'
                $candidateCaseResult.directCallClosure = 'passed'
                $candidateCaseResult.exactExecution = 'passed'
            } else {
                $negativeMarker = Get-C396ContainedArtifactPath (Join-Path $candidateCaseRoot 'pre-llvm.marker') $candidateScratchRoot "C396 pre-LLVM marker '$($candidateCase.id)'"
                [IO.File]::WriteAllText($negativeMarker, 'candidate verifier reached pre-LLVM boundary')
                $negativeMarkerSha256 = (Get-FileHash -LiteralPath $negativeMarker -Algorithm SHA256).Hash
                $candidateDiagnostic = Invoke-C396CapturedProcess $candidate @('windows', $candidateSource)
                Write-C396StreamLogs (Join-Path $candidateCaseRoot 'diagnostic') $candidateDiagnostic
                $candidateDiagnosticStdout = ConvertTo-C396ExactText $candidateDiagnostic.stdout
                $candidateDiagnosticStderr = ConvertTo-C396ExactText $candidateDiagnostic.stderr
                $candidateDiagnosticLines = @(@($candidateDiagnosticStdout, $candidateDiagnosticStderr) |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    ForEach-Object { $_ -split "`n" } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                $candidateDiagnosticLine = if ($candidateDiagnosticLines.Count -eq 1) { $candidateDiagnosticLines[0] } else { '' }
                $candidateDiagnosticStream = if (-not [string]::IsNullOrWhiteSpace($candidateDiagnosticStdout) -and [string]::IsNullOrWhiteSpace($candidateDiagnosticStderr)) { 'stdout' } elseif ([string]::IsNullOrWhiteSpace($candidateDiagnosticStdout) -and -not [string]::IsNullOrWhiteSpace($candidateDiagnosticStderr)) { 'stderr' } else { 'invalid' }
                $candidateUnexpectedRuntimeText = ($candidateDiagnostic.stdout + "`n" + $candidateDiagnostic.stderr) -match '(?im)\bwarning\b|^\s*at\s+\S|^\s*--- End of stack trace|System\.[A-Za-z][A-Za-z0-9.]*Exception|Unhandled exception|Stack trace'
                $candidateEmittedLlvm = Test-C396ContainsLlvm ($candidateDiagnostic.stdout + "`n" + $candidateDiagnostic.stderr)
                $candidateCaseResult.exitCode = $candidateDiagnostic.exitCode
                $candidateCaseResult.diagnosticKind = $candidateCase.diagnosticKind
                $candidateCaseResult.diagnosticPattern = $candidateCase.candidateDiagnosticPattern
                $candidateCaseResult.actualDiagnostic = $candidateDiagnosticLine
                $candidateCaseResult.diagnosticStream = $candidateDiagnosticStream
                $candidateCaseResult.compilerOutputPathMode = 'stdout-only; verifier-reserved LLVM/bitcode/executable paths must remain absent'
                $candidateCaseResult.preLlvmMarkerSha256 = $negativeMarkerSha256
                if ($candidateDiagnostic.exitCode -eq 0 -or
                    $candidateDiagnosticLines.Count -ne 1 -or
                    $candidateDiagnosticLine -cnotmatch $candidateCase.candidateDiagnosticPattern -or
                    $candidateDiagnosticStream -cne $candidateCase.candidateDiagnosticStream -or
                    $candidateUnexpectedRuntimeText -or
                    $candidateEmittedLlvm -or
                    -not (Test-Path -LiteralPath $negativeMarker -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $negativeMarker -Algorithm SHA256).Hash -cne $negativeMarkerSha256 -or
                    (Test-Path -LiteralPath $candidateLl) -or
                    (Test-Path -LiteralPath $candidateBc) -or
                    (Test-Path -LiteralPath $candidateExe)) {
                    $candidateCaseResult.status = 'failed'
                    $candidateCaseResult.failure = 'candidate negative did not fail with the exact diagnostic before LLVM emission'
                    continue
                }
                $candidateCaseResult.beforeLlvm = $true
                $candidateNegativeBeforeLlvm++
            }
            $candidateCaseResult.status = 'passed'
            $candidateCompleted++
        }
        foreach ($candidateInputPath in $candidateInputHashes.Keys) {
            if ((Get-FileHash -LiteralPath $candidateInputPath -Algorithm SHA256).Hash -cne $candidateInputHashes[$candidateInputPath]) {
                throw "C396 candidate input changed during verification: $candidateInputPath"
            }
        }
        $candidateStatus = if ($candidateCompleted -eq $candidateC396Cases.Count -and $candidateNegativeBeforeLlvm -eq 4) { 'passed' } else { 'failed' }
        $evidence.c396CandidateWindows = @{
            scope = 'scratch-only-current-selfhost-candidate-windows-exact'
            completed = $candidateCompleted
            total = $candidateC396Cases.Count
            positiveCompleted = @($candidateResults | Where-Object { $_.kind -eq 'positive' -and $_.status -eq 'passed' }).Count
            positiveTotal = 6
            negativeBeforeLlvm = $candidateNegativeBeforeLlvm
            negativeTotal = 4
            status = $candidateStatus
            compilerSha256 = $candidateInputSha256
            inputHashes = $candidateInputHashes
            toolHashes = [ordered]@{
                verifier = $candidateInputHashes[[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PSCommandPath).Path)]
                llvmAs = $candidateInputHashes[[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $layoutAssembler).Path)]
                clang = $candidateInputHashes[[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $candidateClang).Path)]
                closureVerifier = $candidateInputHashes[[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $layoutClosureVerifier).Path)]
            }
            cases = $candidateResults
            outputDirectory = $output
            compilerOutputPathMode = 'candidate emits LLVM only on stdout; verifier materializes positive LLVM in the contained scratch case directory'
            finalStageIntegration = 'pending-accumulated-Stage2-Stage3-and-required-targets'
        }
        if ($candidateStatus -ne 'passed') {
            $failedCandidateIds = @($candidateResults | Where-Object status -ne 'passed' | ForEach-Object id)
            $candidateFailure = "C396 candidate Windows failed: $($failedCandidateIds -join ', ')"
            $focusedFailure = (@($focusedFailure, $candidateFailure) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '; '
            $status = 'failed'
            $evidence.status = 'failed'
        }
    }
}
[string]$managedFailure = ''
if ($ExecuteFixtures) {
    $executionContractPath = Join-Path $repo 'scripts/contracts/generic-type-context-execution.json'
    $execution = Get-Content -LiteralPath $executionContractPath -Raw | ConvertFrom-Json
    $managedAuthorityCases = @(
        [pscustomobject]@{ id = '1719'; kind = 'positive'; source = 'scripts/contracts/fixtures/1719-generic-readonly-slice-context.slg'; expected = "2`n2" },
        [pscustomobject]@{ id = '1720'; kind = 'positive'; source = 'scripts/contracts/fixtures/1720-generic-reference-context.slg'; expected = "42`ntext" },
        [pscustomobject]@{ id = 'result-product-payload'; kind = 'positive'; source = 'scripts/probes/type-delimiters/result-product-payload.slg'; expected = '0' },
        [pscustomobject]@{ id = 'readonly-product-array'; kind = 'positive'; source = 'scripts/probes/type-delimiters/readonly-product-array.slg'; expected = '0' },
        [pscustomobject]@{ id = 'nested-labeled-product'; kind = 'positive'; source = 'scripts/probes/type-delimiters/nested-labeled-product.slg'; expected = '0' },
        [pscustomobject]@{ id = 'text-slice-direct-first'; kind = 'positive'; source = 'scripts/probes/readonly-text-slice/direct-first.slg'; expected = '2' },
        [pscustomobject]@{ id = 'text-slice-direct-additional'; kind = 'positive'; source = 'scripts/probes/readonly-text-slice/direct-additional.slg'; expected = '5' },
        [pscustomobject]@{ id = 'temporary-reference'; kind = 'negative'; source = 'scripts/probes/type-delimiters/temporary-reference-negative.slg'; expected = 'requires an addressable owner or reference' },
        [pscustomobject]@{ id = 'direct-nested-container'; kind = 'negative'; source = 'scripts/probes/type-delimiters/direct-nested-container-negative.slg'; expected = 'readonly array views require inline scalar or user-value elements' }
    )
    $managedContractCases = @(
        $execution.positive | ForEach-Object { [pscustomobject]@{ id = $_.id; kind = 'positive'; source = $_.source; expected = $_.stdout } }
        $execution.negative | ForEach-Object { [pscustomobject]@{ id = $_.id; kind = 'negative'; source = $_.source; expected = $_.diagnostic } }
    )
    if ($execution.schemaVersion -ne 1 -or
        $execution.scope -cne 'managed-current-dll-generic-and-delimiter-source-execution' -or
        $execution.acceptance -cne 'Every positive must run with exact stdout, pass llvm-as and direct-call closure; every negative must fail semantically before final or temporary LLVM exists. Final accumulated Stage2/Stage3 remains separate.' -or
        $managedContractCases.Count -ne $managedAuthorityCases.Count) {
        throw 'managed generic execution contract authority drifted'
    }
    foreach ($authorityCase in $managedAuthorityCases) {
        $matches = @($managedContractCases | Where-Object id -CEQ $authorityCase.id)
        if ($matches.Count -ne 1 -or $matches[0].kind -cne $authorityCase.kind -or
            $matches[0].source -cne $authorityCase.source -or $matches[0].expected -cne $authorityCase.expected) {
            throw "managed generic execution tuple drifted: $($authorityCase.id)"
        }
    }
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
[IO.File]::WriteAllText((Join-Path $output 'result.json'), ($evidence | ConvertTo-Json -Depth 8))
if ($status -ne 'passed') {
    $failureSummary = @($focusedFailure, $managedFailure) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    throw "generic type context probe failed: $($failureSummary -join '; '); evidence: $(Join-Path $output 'result.json')"
}
Write-Output 'Generic type contexts: extracted production methods + current DLL type parser and place validator PASS 21/21.'
if ($TypeDelimiters) {
    Write-Output "Type delimiters: selected production parser branches + existing real type table PASS $delimiterPassed/$delimiterTotal; whole compiler integration pending."
    Write-Output "Declaration/layout consumers: current production parser + type table + native LLVM execution $layoutCompleted/$($layoutCases.Count); final accumulated Stage2/Stage3 pending."
    Write-Output "Declaration recursion/diagnostics: current managed compiler PASS $declarationCompleted/$($declarationCases.Count); negative pre-LLVM $($evidence.declarationRecursionAndDiagnostics.negativeBeforeLlvm)/3; final accumulated Stage2/Stage3 pending."
}
if ($ExecuteFixtures) { Write-Output "Managed focused source execution PASS $($managed.completed)/$($managed.total); final accumulated Stage2/Stage3 pending." }
if ($ReadonlyTextSlice) { Write-Output "Extracted shared array classifier + three readonly Text call consumers PASS $slicePassed/11; current ordinary-call and final Stage integration are recorded separately." }
if ($CandidateCompiler -and $TypeDelimiters) {
    Write-Output "C396 candidate Windows: scratch-only selfhost compiler PASS $candidateCompleted/$($candidateC396Cases.Count); positive exact $($evidence.c396CandidateWindows.positiveCompleted)/6; negative pre-LLVM $candidateNegativeBeforeLlvm/4; final accumulated Stage2/Stage3 and other targets pending."
}
Write-Output (Join-Path $output 'result.json')
