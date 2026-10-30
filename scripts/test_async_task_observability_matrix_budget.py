"""Check the production matrix deadline before any compiler is launched."""
import json
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parent.parent
MATRIX = ROOT / "scripts/verify-managed-async-task-observability-matrix.ps1"
SCHEMA = ROOT / "scripts/contracts/async-task-observability-managed-matrix-result.schema.json"
HISTORICAL = ROOT / "scripts/contracts/evidence/source13293/coroutine14925/managed13-14935.json"


def ps(script):
    result = subprocess.run(["pwsh", "-NoProfile", "-NonInteractive", "-Command", script],
                            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", check=True)
    return json.loads(result.stdout)


class MatrixCaseBudgetTests(unittest.TestCase):
    def test_production_run_rejects_expired_case_before_process_start(self):
        # Load the actual two functions without executing the matrix entry point.
        actual = ps(f"""
            $ErrorActionPreference = 'Stop'
            $ast = [Management.Automation.Language.Parser]::ParseFile('{MATRIX.as_posix()}', [ref]$null, [ref]$null)
            foreach ($name in @('Get-RemainingCaseSeconds', 'Run')) {{
                $function = $ast.Find({{ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }}, $true)
                Invoke-Expression $function.Extent.Text
            }}
            $script:started = 0
            function Unexpected-Process {{ $script:started++; throw 'UNEXPECTED_PROCESS_STARTED' }}
            $processPython = 'Unexpected-Process'
            $failures = @()
            foreach ($elapsed in @(180000, 180001)) {{
                $script:caseStopwatch = [pscustomobject]@{{ Elapsed = [TimeSpan]::FromMilliseconds($elapsed) }}
                try {{ Run 'compiler' @() 'expired'; throw 'EXPIRED_CASE_ACCEPTED' }}
                catch {{ $failures += $_.Exception.Message }}
            }}
            $script:caseStopwatch = $null
            try {{ Run 'compiler' @() 'missing'; throw 'MISSING_CONTEXT_ACCEPTED' }}
            catch {{ $failures += $_.Exception.Message }}
            @{{ ordinary = (Get-RemainingCaseSeconds 0); nearDeadline = (Get-RemainingCaseSeconds 179000);
                started = $script:started; failures = $failures }} | ConvertTo-Json -Compress
        """)
        self.assertEqual(120, actual["ordinary"])
        self.assertEqual(1, actual["nearDeadline"])
        self.assertEqual(0, actual["started"])
        self.assertEqual(["ASYNC_TASK_OBSERVABILITY_CASE_BUDGET_EXHAUSTED"] * 2
                         + ["ASYNC_TASK_OBSERVABILITY_CASE_CONTEXT_REQUIRED"], actual["failures"])

    def test_result_schema_preserves_history_and_rejects_missing_or_over_budget_time(self):
        actual = ps(f"""
            $ErrorActionPreference = 'Stop'
            $record = Get-Content -LiteralPath '{HISTORICAL.as_posix()}' -Raw | ConvertFrom-Json -AsHashtable
            function Accepted {{ ($record | ConvertTo-Json -Depth 32) | Test-Json -SchemaFile '{SCHEMA.as_posix()}' -ErrorAction SilentlyContinue }}
            $historical = Accepted
            $record.maximumCaseMilliseconds = 180000
            foreach ($case in $record.cases) {{ $case.wholeCaseElapsedMilliseconds = 1500 }}
            $normal = Accepted
            $record.cases[0].wholeCaseElapsedMilliseconds = 180001
            $over = Accepted
            $record.cases[0].Remove('wholeCaseElapsedMilliseconds') | Out-Null
            $missing = Accepted
            $record.status = 'running'; $record.completed = 0; $record.cases = @()
            $running = Accepted
            @{{ historical=$historical; normal=$normal; over=$over; missing=$missing; running=$running }} | ConvertTo-Json -Compress
        """)
        self.assertEqual(dict(historical=True, normal=True, over=False, missing=False, running=True), actual)


if __name__ == "__main__":
    unittest.main()
