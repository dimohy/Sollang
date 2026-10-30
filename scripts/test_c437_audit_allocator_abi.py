from pathlib import Path
import json
import subprocess
import unittest


class AuditAllocationAbiTests(unittest.TestCase):
    def test_actual_converter_handles_both_allocation_abis_and_rejects_bypasses(self):
        source = Path(__file__).with_name('verify-c437-current-source.ps1').resolve()
        script = r'''
$ErrorActionPreference='Stop'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($args[0],[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw 'Invalid production source' }
$function=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Convert-C437AuditLlvm'},$true))
if ($function.Count -ne 1) { throw 'Missing single production converter' }
. ([scriptblock]::Create($function[0].Extent.Text))
$passed=0
foreach ($kind in @('managed','native')) {
    foreach ($family in @('legacy','current')) {
        $entry=if($kind -ceq 'native'){'define i32 @main() {'}else{'define i32 @sollang_start() {'}
        $allocate=if($family -ceq 'legacy'){'malloc'}else{'sollang_alloc'}
        $release=if($family -ceq 'legacy'){'free'}else{'sollang_free'}
        $resize=if($family -ceq 'legacy'){'realloc'}else{'sollang_realloc'}
        $inputText="declare ptr @$allocate(i64)`ndeclare void @$release(ptr)`ndeclare ptr @$resize(ptr,i64)`ndefine internal ptr @sollang_alloc(i64 %bytes) {`n ret ptr null`n}`n"+$entry+"`n %p = call ptr @$allocate(i64 8)`n call void @$release(ptr %p)`n %q = call ptr @$resize(ptr %p, i64 16)`n store ptr @$release, ptr %callback`n ret i32 0`n}"
        $actual=Convert-C437AuditLlvm -LlvmText $inputText -CompilerKind $kind -CaseId "$kind-$family"
        foreach($required in @('call ptr @c437_audit_malloc(','call void @c437_audit_free(','call ptr @c437_audit_realloc(','ptr @c437_audit_free','@slg_program_main()')) {
            if(-not $actual.Contains($required)){throw "Missing instrumentation $required"}
        }
        $passed++
    }
}
$rejected=0
foreach($bad in @('define i32 @main() { call ptr @c437_audit_malloc(i64 8) }','define i32 @wrong_main() { }',('define i32 @main() {'+"`n call ptr @sollang_alloc (i64 8)`n}"))) {
    try { Convert-C437AuditLlvm -LlvmText $bad -CompilerKind native -CaseId negative | Out-Null }
    catch { $rejected++;continue }
    throw "Forbidden audit bypass accepted: $bad"
}
@{normal=$passed;negativeRejected=$rejected}|ConvertTo-Json -Compress
'''
        script = script.replace('$args[0]', "'" + str(source).replace("'", "''") + "'")
        result = subprocess.run(['pwsh', '-NoProfile', '-Command', script],
                                capture_output=True, text=True, encoding='utf-8', timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {'normal': 4, 'negativeRejected': 3})


if __name__ == '__main__':
    unittest.main()
