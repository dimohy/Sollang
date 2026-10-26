$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Get-Location).Path
. ./scripts/verification-artifact-identity.ps1
. ./scripts/verification-c527-historical-baseline.ps1
$contract = Get-Content -LiteralPath scripts/contracts/interpolation-semantic-parity.json -Raw | ConvertFrom-Json
$managedCodegen = Get-Content -LiteralPath src/Sollang.Compiler/CodeGen/LlvmEmitter.Expressions.Core.cs -Raw
$interpolationCodegen = Get-Content -LiteralPath selfhost/llvm/text/foundation.slg -Raw
$path = Join-Path $root 'scripts/verify-interpolation-semantic-parity.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'C527_PARENT_PARSE_FAILED' }
$start = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -ceq 'largeLiteral'
}, $true))
$end = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -ceq 'characterConversion'
}, $true))
if ($start.Count -ne 1 -or $end.Count -ne 1) { throw 'C527_PARENT_BLOCK_BOUNDARY_INVALID' }
$text = [IO.File]::ReadAllText($path)
$block = $text.Substring($start[0].Extent.StartOffset, $end[0].Extent.StartOffset - $start[0].Extent.StartOffset)
if (-not $block.Contains('$largeBaselineLlvm.Contains(''sitofp i32 4294967296 to double'', [StringComparison]::Ordinal)')) {
    throw 'C527_ORIGINAL_PREDICATE_CHANGED'
}
. ([ScriptBlock]::Create($block))
[ordered]@{ status='passed'; completed=1; total=1; scope='Actual C527 parent verifier block only'
    originalPredicateUnchanged=$true; claimsWholeParityComplete=$false } | ConvertTo-Json
