[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$harness = Join-Path $root 'scripts/verify-selfhost-array-inherent-methods.ps1'
$typeIds = Join-Path $root 'selfhost/semantic/type_ids.slg'
$typeTerms = Join-Path $root 'selfhost/semantic/type_terms.slg'
$expressionTypes = Join-Path $root 'selfhost/semantic/expression_type_ids_resolution_phases.slg'
$ordinary = Join-Path $root 'selfhost/ir/typed/ordinary_function.slg'
$callResolution = Join-Path $root 'selfhost/semantic/call_resolution_sources.slg'
$callArguments = Join-Path $root 'selfhost/llvm/text/call_arguments.slg'
$fixture = Join-Path $root 'examples/regression/1759-array-inherent-selfhost.slg'
$module = Join-Path $root 'examples/regression/fixtures/1759-array-inherent-methods.slg'
$pathModule = Join-Path $root 'stdlib/sys/path.slg'
$externalPathCaller = Join-Path $root 'selfhost/cli_cpp_binding.slg'
foreach ($path in @($harness,$typeIds,$typeTerms,$expressionTypes,$ordinary,$callResolution,$callArguments,$fixture,$module,$pathModule,$externalPathCaller)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "array-inherent contract input is missing: $path" }
}

$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($harness, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw "array-inherent harness has PowerShell parse errors: $($errors.Message -join '; ')" }
$invalidWorkingDirectory = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst]
}, $true) | Where-Object {
    $_.GetCommandName() -ceq 'Invoke-VerificationProcessToFile' -and
    @($_.CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -ceq 'WorkingDirectory' }).Count -gt 0
})
if ($invalidWorkingDirectory.Count -ne 0) { throw 'ToFile calls must not pass its unsupported WorkingDirectory parameter' }

$typeText = [IO.File]::ReadAllText($typeIds)
$typeTermText = [IO.File]::ReadAllText($typeTerms)
$expressionText = [IO.File]::ReadAllText($expressionTypes)
$ordinaryText = [IO.File]::ReadAllText($ordinary)
$callResolutionText = [IO.File]::ReadAllText($callResolution)
$callArgumentText = [IO.File]::ReadAllText($callArguments)
$fixtureText = [IO.File]::ReadAllText($fixture)
$moduleText = [IO.File]::ReadAllText($module)
$pathText = [IO.File]::ReadAllText($pathModule)
$externalPathText = [IO.File]::ReadAllText($externalPathCaller)
$harnessText = [IO.File]::ReadAllText($harness)
foreach ($required in @('public implOwnerTypeAst','public implOwnerTypeId','candidate.kind == 12 or candidate.kind == 16')) {
    if (-not $typeText.Contains($required, [StringComparison]::Ordinal)) { throw "canonical impl-owner invariant is missing: $required" }
}
foreach ($required in @(
    'nodes[nodes[node.parent].parent].kind == 6',
    '(source -> byte(node.start - 1)) == 91',
    'tokens[ownerOpenToken!].kind != grammar.tokenIdLeftBracket()',
    'ownerBracketDepth! == 0 -> if { ownerBracketToken! => typeTokenEnd! }'
)) {
    if (-not $typeTermText.Contains($required, [StringComparison]::Ordinal)) {
        throw "structural impl-owner type-term normalization is missing: $required"
    }
}
if (-not $callArgumentText.Contains('and (context.types[valueTypeId].kind == 3', [StringComparison]::Ordinal) -or
    -not $callArgumentText.Contains('or context.types[valueTypeId].kind == 12)', [StringComparison]::Ordinal) -or
    $callArgumentText.Contains("context.types[valueTypeId].kind == 3`n            or context.types[valueTypeId].kind == 4", [StringComparison]::Ordinal)) {
    throw 'fixed-array expression values must retain their existing borrowed slice ABI'
}
if (-not $expressionText.Contains('typeIds.implOwnerTypeId(', [StringComparison]::Ordinal) -or
    -not $ordinaryText.Contains('typeIds.implOwnerTypeId(', [StringComparison]::Ordinal)) {
    throw 'semantic and Typed IR must share canonical implOwnerTypeId'
}
if (-not $ordinaryText.Contains('parameterSymbol! >= 0 and function.kind == 31 and function.parent >= 0', [StringComparison]::Ordinal) -or
    $ordinaryText.Contains('parameterSymbol! >= 0 and parameterOrigin! < 0 and function.kind == 31', [StringComparison]::Ordinal)) {
    throw 'synthetic self parameters must always use the canonical impl-owner type'
}
if ($expressionText.Contains('lastPathChildByAst', [StringComparison]::Ordinal) -or
    $ordinaryText.Contains('receiverOwnerPath', [StringComparison]::Ordinal)) {
    throw 'legacy Path-only impl-owner resolution returned'
}
foreach ($required in @(
    'declaredReceiverValueTypeId! => receiverTypeId!',
    'structuralReceiverOwnerReference.typeId == receiverTypeId!',
    'structuralReceiverMethodIdentity.pathHash == identities[sourceIndex].pathHash'
)) {
    if (-not $callResolutionText.Contains($required, [StringComparison]::Ordinal)) {
        throw "structural receiver canonical type-id lookup is missing: $required"
    }
}
if (-not $harnessText.Contains("@(`$managed,'build') + `$compilerSources", [StringComparison]::Ordinal) -or
    $harnessText.Contains("+ `$runtimeSources +", [StringComparison]::Ordinal)) {
    throw 'managed bootstrap must rely on ambient stdlib and must not duplicate runtime manifest sources'
}
if (-not $harnessText.Contains("^ast source (?<source>\d+) node (?<node>\d+) kind (?<kind>\d+) parent (?<parent>-?\d+)", [StringComparison]::Ordinal) -or
    -not $harnessText.Contains('nominalOwners.Count -ne 1 -or $arrayOwners.Count -ne 1', [StringComparison]::Ordinal)) {
    throw 'selfhost AST topology assertion must retain the actual ast source prefix'
}
foreach ($required in @(
    "IndexOf('bytes -> arrayMethods.firstPlus'",
    "IndexOf('bytes -> arrayMethods.localFirstPlus'",
    "IndexOf('source -> firstPlus'",
    '$firstPlusResolution[0].TargetSymbol -ne $internalFirstPlusResolution[0].TargetSymbol'
)) {
    if (-not $harnessText.Contains($required, [StringComparison]::Ordinal)) {
        throw "targeted array-call resolution assertion is missing: $required"
    }
}
if ($harnessText.Contains("`$calls.Stdout -match '(?m)^resolution .* status [^0]", [StringComparison]::Ordinal)) {
    throw 'array gate must not reject unrelated intrinsic resolution records'
}
foreach ($required in @('bytes -> arrayMethods.firstPlus','bytes -> arrayMethods.localFirstPlus','bytes[0] == UInt8(7)')) {
    if (-not $fixtureText.Contains($required, [StringComparison]::Ordinal)) { throw "1759 fixture invariant is missing: $required" }
}
if (-not $moduleText.Contains('impl Marker', [StringComparison]::Ordinal) -or
    -not $moduleText.Contains('impl [UInt8]', [StringComparison]::Ordinal) -or
    -not $moduleText.Contains('source -> firstPlus(amount)', [StringComparison]::Ordinal)) {
    throw '1759 array owner or current-module call invariant is missing'
}
if (-not $pathText.Contains('public joinDiscovered: self, child: ref Path -> Path', [StringComparison]::Ordinal) -or
    -not $externalPathText.Contains('currentPath -> joinDiscovered(relative)', [StringComparison]::Ordinal)) {
    throw 'external Path.joinDiscovered visibility contract is missing'
}
$fixtureIdFiles = @(Get-ChildItem (Join-Path $root 'examples/regression') -File -Filter '1759-*.slg')
if ($fixtureIdFiles.Count -ne 1 -or $fixtureIdFiles[0].FullName -ne $fixture) {
    throw '1759 must identify exactly one top-level regression fixture'
}
Write-Host '[selfhost array inherent contract] PASS 11/11 (runner parameter, canonical owner, structural receiver lookup, legacy mutation, parser/call/borrow, fixture identity and external visibility controls)'
