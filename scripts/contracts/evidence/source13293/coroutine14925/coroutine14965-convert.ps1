param([Parameter(Mandatory)][string]$Plan)
$ErrorActionPreference='Stop'
$root=(Get-Location).Path
$source=Join-Path $root 'scripts/verify-c437-current-source.ps1'
$tokens=$null; $parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'C437 audit converter source syntax invalid' }
$functions=@($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Convert-C437AuditLlvm' },$true))
if ($functions.Count -ne 1) { throw 'C437 audit converter must have one authoritative definition' }
. ([scriptblock]::Create($functions[0].Extent.Text))
$config=Get-Content -LiteralPath $Plan -Raw | ConvertFrom-Json
foreach ($case in $config.cases) {
    $text=[IO.File]::ReadAllText($case.llvm)
    if ($text.Contains('@c437_audit_malloc')) { throw 'Input is already instrumented' }
    $audit=Convert-C437AuditLlvm -LlvmText $text -CompilerKind native -CaseId $case.id
    $audit+="`ndeclare ptr @c437_audit_malloc(i64)`ndeclare void @c437_audit_free(ptr)`ndeclare ptr @c437_audit_realloc(ptr, i64)`n"
    [IO.File]::WriteAllText($case.auditLlvm,$audit,[Text.UTF8Encoding]::new($false))
}
Write-Output 'Converted exact current Native LLVM using the existing C437 converter'
