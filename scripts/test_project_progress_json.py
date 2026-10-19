"""Verify progress JSON preserves nested evidence and authoritative counts."""

import hashlib
import json
import shutil
import subprocess
import unittest
import tempfile
import copy
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


class ProjectProgressJsonTests(unittest.TestCase):
    def test_report_preserves_nested_evidence_and_counts(self):
        names = ("active-goal-progress", "compiler-defects",
                 "stdlib-evolution-progress", "stabilization-progress")
        paths = [ROOT / "scripts/contracts" / (name + ".json") for name in names]
        before = {path: path.read_bytes() for path in paths}
        result = subprocess.run(
            [shutil.which("pwsh") or "pwsh", "-NoProfile", "-File",
             str(ROOT / "scripts/show-project-progress.ps1"), "-AsJson"],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertEqual(result.stderr, "")
        report = json.loads(result.stdout)
        for path, data in before.items():
            self.assertEqual(hashlib.sha256(path.read_bytes()).digest(),
                             hashlib.sha256(data).digest(), "INPUT_CHANGED: " + str(path))
        goal, compiler, stdlib, _ = [json.loads(before[path].decode("utf-8-sig")) for path in paths]
        self.assertEqual(report["currentGoal"]["queuedUnits"], goal["queuedUnits"])
        self.assertEqual(report["currentGoal"]["completedUnits"], goal["completedUnits"])
        self.assertEqual(report["currentGoal"]["compiler"]["total"], len(compiler["defects"]))
        self.assertEqual(report["currentGoal"]["compiler"]["stabilized"],
                         sum(row["state"] == "closed" for row in compiler["defects"]))
        self.assertEqual(report["currentGoal"]["stdlib"]["total"], len(stdlib["contracts"]))
        self.assertEqual(report["currentGoal"]["stdlib"]["complete"],
                         sum(row["status"] == "complete" for row in stdlib["contracts"]))

    def test_previous_depth_rejects_deep_evidence_instead_of_silently_clipping(self):
        fixture = {"evidence": {"processes": [{"nested": {"a": {"b": {"c": {
            "d": {"e": {"f": {"values": [{"pid": 42, "status": "stopped"}]}}}}}}}}]}}
        result = subprocess.run(
            [shutil.which("pwsh") or "pwsh", "-NoProfile", "-Command",
             "$input | ConvertFrom-Json | ConvertTo-Json -Depth 8 -WarningAction Stop"],
            input=json.dumps(fixture), capture_output=True, text=True,
            encoding="utf-8", timeout=30)
        self.assertNotEqual(result.returncode, 0)

    def test_current_focus_preserves_completion_and_rejects_invalid_selection(self):
        command = r"""
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$request = $input | ConvertFrom-Json
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($request.reporter, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'REPORTER_PARSE_FAILED' }
$ast.FindAll({ param($a)
    $a -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -ceq 'Get-FocusedGateOutcome'
}, $true) | ForEach-Object { Invoke-Expression $_.Extent.Text }
$selection = @($ast.FindAll({ param($a)
    $a -is [System.Management.Automation.Language.IfStatementAst] -and
        $a.Extent.Text.StartsWith('if ($selectedFocusedGates.Count -ne 1', [StringComparison]::Ordinal)
}, $true))
if ($selection.Count -ne 1) { throw 'REPORTER_SELECTION_NOT_UNIQUE' }
foreach ($gate in $request.gates) { Get-FocusedGateOutcome $gate | Out-Null }
$selectedFocusedGates = @($request.gates | Where-Object name -ceq $request.selectedName)
Invoke-Expression $selection[0].Extent.Text
"""
        active = {"name": "current", "status": "active", "completed": 4, "total": 7}
        complete = {**active, "status": "complete", "completed": 7}
        scenarios = [
            ("active", [active], True), ("complete", [complete], True),
            ("false-completion", [{**complete, "completed": 6}], False),
            ("pending", [{**active, "status": "pending", "completed": 0}], False),
            ("failed", [{**active, "status": "failed"}], False),
            ("missing", [{**complete, "name": "other"}], False),
            ("duplicate", [complete, complete], False),
        ]
        for name, gates, allowed in scenarios:
            with self.subTest(name=name):
                result = subprocess.run(
                    [shutil.which("pwsh") or "pwsh", "-NoProfile", "-Command", command],
                    input=json.dumps({"reporter": str(ROOT / "scripts/show-project-progress.ps1"),
                                      "selectedName": "current", "gates": gates}),
                    capture_output=True, text=True, encoding="utf-8", timeout=30)
                self.assertEqual(result.returncode == 0, allowed, result.stderr or result.stdout)


class CompilerDefectCostSelectionTests(unittest.TestCase):
    """Synthetic consumer contracts exercise the actual verifier, not compiler proof."""

    def test_cost_selection_keeps_executed_proofs_and_rejects_bypasses(self):
        fingerprint = "A" * 64
        evaluator = ROOT.parent / "AgenticShaping/evals/unstructured-to-structured.mjs"
        trace = {
            "ruleId": "AS-US-001", "traceAuthority": "orchestrator",
            "signal": {"id": "C-test-999", "durable": True, "machineDecidable": True,
                       "sourceEvidence": ["synthetic consumer regression"]},
            "orchestratorEvidence": {"inputFingerprint": fingerprint},
            "decision": {"structured": False, "reason": "Existing checks suffice",
                         "costSelection": {"strategy": "model-direct", "newCodeBenefit": "unknown",
                                           "rationale": "No useful new code", "mandatoryChecksPreserved": True}},
            "currentTaskComplete": True, "forbiddenActions": []}
        scenarios = [
            ("open-direct", {}, True), ("open-reuse", {"strategy": "reuse-existing"}, True),
            ("open-missing-candidate", {}, False), ("structured", {}, True),
            ("direct", {}, True), ("reuse", {"strategy": "reuse-existing"}, True),
            ("new-code-unknown", {"strategy": "reusable-code", "newCodeBenefit": "unknown"}, False),
            ("new-code-negative", {"strategy": "reusable-code", "newCodeBenefit": "negative"}, False),
            ("mandatory-bypass", {"mandatoryChecksPreserved": False}, False),
            ("missing-candidate", {}, False), ("candidate-exit", {}, False),
            ("candidate-output-drift", {}, False), ("baseline-exit", {}, False),
            ("fingerprint-drift", {}, False), ("incomplete", {}, False),
            ("measured-without-proof", {}, False), ("forbidden", {}, False),
        ]
        # Parse and execute the production functions; do not execute the ledger
        # sweep or substitute mocked Assert-ShapingReceipt/Assert-ShapingEvidence.
        command = r"""
$ErrorActionPreference = 'Stop'; Set-StrictMode -Version Latest
$request = $input | ConvertFrom-Json
$RepositoryRoot = $request.repository
$agenticShapingEvidenceRequiredFromSequence = 1
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($request.verifier, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'VERIFIER_PARSE_FAILED' }
$ast.FindAll({ param($a) $a -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
    ForEach-Object { Invoke-Expression $_.Extent.Text }
Assert-ShapingEvidence -Defect $request.defect -Sequence 999
"""
        for name, selection_delta, allowed in scenarios:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                repository = base / "repo"
                repository.mkdir()
                copied_evaluator = base / "AgenticShaping/evals/unstructured-to-structured.mjs"
                copied_evaluator.parent.mkdir(parents=True)
                copied_evaluator.write_bytes(evaluator.read_bytes())
                current = copy.deepcopy(trace)
                current["decision"]["costSelection"].update(selection_delta)
                if name == "structured":
                    current["decision"] = {
                        "structured": True, "reason": "legacy structured contract",
                        "claimLevel": "structured-and-applied",
                        "asset": {"kind": "fixture", "authorityPath": "existing", "inputFingerprint": fingerprint,
                                  "validatorEvidence": ["synthetic validation"]},
                        "application": {"productionPathChanged": True, "consumerEvidence": ["synthetic consumer"]},
                        "measurementPlan": {"metric": "elapsedMs", "measurementCommand": "synthetic measurement",
                                            "baselineEvidence": ["baseline"], "candidateEvidence": ["candidate"],
                                            "measuredInputFingerprint": fingerprint}}
                    current["orchestratorEvidence"].update({
                        "runner": "agentic-shaping-orchestrator", "runId": "synthetic",
                        "targetRepository": "synthetic repo", "targetRevision": "a" * 40,
                        "executedCommands": [{"purpose": purpose, "command": "synthetic " + purpose,
                                              "exitCode": 0, "expectedExitCode": 0, "outputSha256": fingerprint}
                                             for purpose in ("validator", "consumer")]})
                if name == "fingerprint-drift":
                    current["orchestratorEvidence"]["inputFingerprint"] = "B" * 64
                if name == "incomplete": current["currentTaskComplete"] = False
                if name == "forbidden": current["forbiddenActions"] = ["skip-required-check"]
                if name == "measured-without-proof":
                    current["decision"]["claimLevel"] = "measured-improvement"
                (repository / "trace.json").write_text(json.dumps(current), encoding="utf-8")
                evidence = {"inputFingerprint": fingerprint, "baselineReceipt": "baseline.json",
                            "candidateReceipt": "candidate.json", "tracePath": "trace.json"}
                for phase, exit_code in (("baseline", 1), ("candidate", 0)):
                    output = repository / (phase + ".txt")
                    output.write_bytes(b"synthetic actual captured output\n")
                    record = {"schemaVersion": 1, "defectId": "C-test-999", "phase": phase,
                              "inputFingerprint": fingerprint, "command": "synthetic consumer check",
                              "exitCode": exit_code, "expectedExitCode": exit_code,
                              "outputPath": output.name,
                              "outputSha256": hashlib.sha256(output.read_bytes()).hexdigest().upper()}
                    if name == "candidate-exit" and phase == "candidate": record["exitCode"] = 1
                    if name == "baseline-exit" and phase == "baseline": record["exitCode"] = 0
                    (repository / (phase + ".json")).write_text(json.dumps(record), encoding="utf-8")
                if name == "candidate-output-drift":
                    (repository / "candidate.txt").write_bytes(b"tampered\n")
                if name in ("missing-candidate", "open-missing-candidate"): del evidence["candidateReceipt"]
                result = subprocess.run(
                    [shutil.which("pwsh") or "pwsh", "-NoProfile", "-Command", command],
                    input=json.dumps({"repository": str(repository),
                                      "verifier": str(ROOT / "scripts/verify-compiler-defects.ps1"),
                                      "defect": {"id": "C-test-999", "state": "open" if name.startswith("open-") else "candidate-fixed",
                                                 "shapingEvidence": evidence}}),
                    capture_output=True, text=True, encoding="utf-8", timeout=30)
                if allowed:
                    self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
                else:
                    self.assertNotEqual(result.returncode, 0, "FORBIDDEN_ACCEPTANCE: " + name)
                    expected_rejection = {
                        "new-code-unknown": "AS-US-001-NEW-CODE-BENEFIT-UNSUPPORTED",
                        "new-code-negative": "AS-US-001-NEW-CODE-BENEFIT-UNSUPPORTED",
                        "mandatory-bypass": "AS-US-001-MANDATORY-CHECKS-NOT-PRESERVED",
                        "missing-candidate": "missing candidateReceipt",
                        "open-missing-candidate": "missing candidateReceipt",
                        "candidate-exit": "candidate shaping command did not pass",
                        "candidate-output-drift": "candidate output hash does not match",
                        "baseline-exit": "baseline shaping command exit does not match",
                        "fingerprint-drift": "trace identity does not match",
                        "incomplete": "AS-US-001-CURRENT-TASK",
                        "measured-without-proof": "measured improvement is missing measurementReceipt",
                        "forbidden": "AS-US-001-FORBIDDEN-ACTION",
                    }[name]
                    self.assertIn(expected_rejection, result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
