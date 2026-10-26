[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$path = Join-Path $RepositoryRoot 'scripts/verify-llvm-emitter-split-abi.ps1'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Split ABI verifier parse failure.' }
$functions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Test-UnreferencedSplitHelper', 'Get-SplitContextStateParameters', 'Get-SplitContextMaterializations') }, $true))
if ($functions.Count -ne 3) { throw 'Expected three production ABI classifiers.' }
foreach ($function in $functions) { . ([scriptblock]::Create($function.Extent.Text)) }
$declaration = 'helper context: ref EmitContext, state: ref State -> Unit {}'
$cases = @(
    @{ Name = 'unused-declaration'; Source = $declaration; Llvm = ''; Expected = $true },
    @{ Name = 'referenced-helper-cannot-disappear'; Source = "$declaration`ncontext -> helper(state)"; Llvm = ''; Expected = $false },
    @{ Name = 'missing-declaration'; Source = ''; Llvm = ''; Expected = $false },
    @{ Name = 'duplicate-declaration'; Source = "$declaration`n$declaration"; Llvm = ''; Expected = $false },
    @{ Name = 'dangling-generated-call'; Source = $declaration; Llvm = 'call void @sollang_fn_sollang_compiler_llvm_text_helper(ptr %context, ptr %state)'; Expected = $false }
)
foreach ($case in $cases) {
    if ((Test-UnreferencedSplitHelper -Name helper -SourceText $case.Source -LlvmText $case.Llvm) -ne $case.Expected) { throw "Split ABI classifier failed: $($case.Name)" }
}
foreach ($case in @(
    @{ Parameters = @('i32 %input', 'ptr %context', 'ptr %state'); Following = 0 },
    @{ Parameters = @('ptr %context', 'ptr %state', 'i32 %builtin'); Following = 1 }
)) {
    $selected = @(Get-SplitContextStateParameters -Parameters $case.Parameters -FollowingParameters $case.Following)
    if ($selected.Count -ne 2 -or $selected[0] -cne 'ptr %context' -or $selected[1] -cne 'ptr %state') { throw 'Split ABI pointer positions changed.' }
}
$rejected = $false
try { Get-SplitContextStateParameters -Parameters @('ptr %context', 'i32 %builtin') -FollowingParameters 1 | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Missing pointer inventory accepted.' }
$llvm = @'
define void @unrelated() {
  %ref_arg0 = alloca %sollang.struct.1, align 8
  ret void
}
define void @entry() {
  %ref_arg0 = alloca %sollang.struct.2, align 8
  call void @sollang_fn_sollang_compiler_llvm_text_emitCore(ptr %ref_arg0, ptr %state)
  ret void
}
'@
$owners = @(Get-SplitContextMaterializations -LlvmText $llvm)
if ($owners.Count -ne 1 -or $owners[0].Groups['type'].Value -cne '%sollang.struct.2') { throw 'Entry context incorrectly captured an unrelated function owner.' }
$rejected = $false
try { Get-SplitContextMaterializations -LlvmText $llvm.Replace('  %ref_arg0 = alloca %sollang.struct.2, align 8', '') | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Cross-function owner fallback accepted.' }
Write-Host '[split ABI controls] PASS 10/10; pointer positions, unused declarations and function-scoped owners checked.'
