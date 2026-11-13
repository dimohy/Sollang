import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import source_phase_context as module


class SourcePhaseContextTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.phase = "semantic-analysis"
        self.scopes = {"managed": ["src/Sollang.Compiler/Semantics"],
                       "selfhost": ["selfhost/semantic"]}
        self.files = ["src/Sollang.Compiler/Semantics/Core.cs", "selfhost/semantic/core.slg",
                      "src/Sollang.Compiler/Cli/Aux.cs", "selfhost/llvm/aux.slg"]
        standard_library = self.root / "stdlib/sys/text.slg"
        standard_library.parent.mkdir(parents=True)
        standard_library.write_text("namespace sys.text")
        for name in self.files:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name, encoding="utf-8")
        self.inventory = {"sourceScopes": self.scopes, "requiredDecisionIds": ["one"],
                          "decisions": [{"id": "one", "status": "complete",
                              "managedSources": [self.files[0]], "selfhostSources": [self.files[1]],
                              "supportingSources": self.files[2:],
                              **{key: "reviewed" for key in ("structure", "branches", "logic", "diagnostics")}}]}
        patcher = patch.dict(module.authority.PHASE_SCOPES, {self.phase: self.scopes})
        patcher.start()
        self.addCleanup(patcher.stop)

    def sources(self):
        return module.source_sets(self.root, self.phase, self.inventory)

    def build(self, side="selfhost"):
        binary = self.root / ("compiler.exe" if side == "selfhost" else "compiler.dll")
        binary.write_bytes(b"compiler")
        expected = self.sources()[1][side]
        birth_path = self.root / "birth.json"
        birth_path.write_text(json.dumps({"status": "passed", "inputsStable": True, "processesStopped": True,
            "inputHashes": {str(self.root / name): digest for name, digest in expected.items()},
            "generatedOutputHashes": {str(binary): module.authority.file_hash(binary)}}))
        birth = {"path": "birth.json", "sha256": module.authority.file_hash(birth_path)}
        return {"status": "passed", "phase": self.phase, "compilerSide": side,
                "inputStable": True, "exitCode": 0, "canceled": False,
                "failureIds": [], "orphanProcessIds": [], "completed": 1, "total": 1,
                "sourceHashesStart": expected, "sourceHashesEnd": expected,
                "actualBuildRecord": birth,
                "sourceProvenance": {name: {"method": "direct-build-input", "record": birth,
                    "inputKey": str(self.root / name)} for name in expected},
                "binary": {"path": binary.name, "sha256": module.authority.file_hash(binary)}}

    def test_primary_and_supporting_sources_are_both_pinned(self):
        primary, expanded = self.sources()
        for side in self.scopes:
            self.assertEqual(len(primary[side]), 1)
            self.assertEqual(len(expanded[side]), 2)
            module.validate_build(self.root, self.phase, side, self.build(side), expanded[side])

    def test_missing_support_rejected(self):
        (self.root / self.files[2]).unlink()
        with self.assertRaises(module.authority.PhaseClosureError):
            self.sources()

    def test_foreign_support_rejected(self):
        path = self.root / "docs/foreign.cs"
        path.parent.mkdir()
        path.write_text("foreign")
        self.inventory["decisions"][0]["supportingSources"].append("docs/foreign.cs")
        with self.assertRaises(module.authority.PhaseClosureError):
            self.sources()

    def test_primary_cannot_be_relabelled_support(self):
        self.inventory["decisions"][0]["supportingSources"].append(self.files[0])
        with self.assertRaises(module.authority.PhaseClosureError):
            self.sources()

    def test_unreviewed_primary_rejected(self):
        (self.root / "src/Sollang.Compiler/Semantics/New.cs").write_text("new")
        with self.assertRaises(module.authority.PhaseClosureError):
            self.sources()

    def test_narrowed_scope_rejected(self):
        self.inventory["sourceScopes"] = {"managed": [self.files[0]], "selfhost": [self.files[1]]}
        with self.assertRaises(module.authority.PhaseClosureError):
            self.sources()

    def test_duplicate_decision_rejected(self):
        self.inventory["decisions"] *= 2
        with self.assertRaises(module.authority.PhaseClosureError):
            self.sources()

    def test_primary_only_build_view_rejected(self):
        build = self.build()
        build["sourceHashesStart"] = self.sources()[0]["selfhost"]
        with self.assertRaises(module.authority.PhaseClosureError):
            module.validate_build(self.root, self.phase, "selfhost", build, self.sources()[1]["selfhost"])

    def test_changed_support_rejected(self):
        build = self.build()
        (self.root / self.files[3]).write_text("changed")
        with self.assertRaises(module.authority.PhaseClosureError):
            module.validate_build(self.root, self.phase, "selfhost", build, self.sources()[1]["selfhost"])

    def test_changed_binary_rejected(self):
        build = self.build()
        (self.root / "compiler.exe").write_bytes(b"different")
        with self.assertRaises(module.authority.PhaseClosureError):
            module.validate_build(self.root, self.phase, "selfhost", build, self.sources()[1]["selfhost"])

    def test_wrong_build_phase_or_side_rejected(self):
        for field, value in (("phase", "ownership"), ("compilerSide", "managed")):
            build = self.build()
            build[field] = value
            with self.assertRaises(module.authority.PhaseClosureError):
                module.validate_build(self.root, self.phase, "selfhost", build, self.sources()[1]["selfhost"])

    def test_enrich_preserves_native_empty_runtime_and_rejects_base_drift(self):
        primary, expanded = self.sources()
        build = self.build()
        inventory = dict(self.inventory, status="reviewed", phase=self.phase)
        catalog = self.root / "catalog.json"
        catalog.write_text("runtime catalog")
        inventory["runtimeInputs"] = [{"path": "catalog.json", "sha256": module.authority.file_hash(catalog)}]
        for name, value in (("inventory.json", inventory), ("build.json", build),
                            ("comparison.json", {"sourceHashes": expanded["managed"] | expanded["selfhost"]})):
            (self.root / name).write_text(json.dumps(value))
        def reference(name):
            return {"path": name, "sha256": module.authority.file_hash(self.root / name)}
        runner = self.root / "runner.ps1"
        runner.write_text("runner")
        context = {"Root": str(self.root), "CompilerSide": "selfhost",
                   "SourceHashes": primary["managed"] | primary["selfhost"],
                   "SideSourceHashes": primary["selfhost"], "InputHashes": {},
                   "CompilerBinary": build["binary"], "CompilerRuntimeHashes": {},
                   "SourceComparisonReference": reference("comparison.json"),
                   "Contract": {"phase": self.phase, "reviewedInventory": reference("inventory.json"),
                       "compilerBinaries": {"selfhost": dict(build["binary"], buildRecord="build.json",
                           buildRecordSha256=reference("build.json")["sha256"])}}}
        for name in ("source_phase_context.py", "verify-structural-parity-detail.py",
                     "context_suite_evidence.py", "verification_build_stdout.py",
                     "verification_source_proof.py", "completed_artifact_plan.py"):
            (self.root / name).write_text("test tool " + name)
        with patch.object(module, "__file__", str(self.root / "source_phase_context.py")), \
             patch.object(module.authority, "__file__", str(self.root / "verify-structural-parity-detail.py")):
            enriched = module.enrich(self.root, copy.deepcopy(context), runner)
        self.assertEqual(enriched["CompilerRuntimeHashes"], {})
        self.assertEqual(enriched["SideSourceHashes"], expanded["selfhost"])
        self.assertEqual(enriched["SourceHashes"], expanded["managed"] | expanded["selfhost"])
        self.assertIn("birth.json", enriched["InputHashes"])
        self.assertEqual(enriched["InputHashes"]["catalog.json"], module.authority.file_hash(catalog).upper())
        self.assertIn("stdlib/sys/text.slg", enriched["InputHashes"])
        context["SourceHashes"]["extra"] = "0" * 64
        with self.assertRaisesRegex(module.authority.PhaseClosureError, "legacy context source scope differs"):
            module.enrich(self.root, context, runner)
        self.assertEqual(context["CompilerRuntimeHashes"], {})

    def test_invented_build_provenance_rejected(self):
        build = self.build()
        del build["sourceProvenance"][self.files[3]]
        with self.assertRaises(module.authority.PhaseClosureError):
            module.validate_build(self.root, self.phase, "selfhost", build, self.sources()[1]["selfhost"])

    def test_runtime_fixture_is_pinned_and_changed_content_rejected(self):
        path = self.root / "catalog.json"
        path.write_text("original")
        inventory = {"runtimeInputs": [{"path": "catalog.json", "sha256": module.authority.file_hash(path)}]}
        self.assertEqual(module.runtime_inputs(self.root, inventory),
                         {"catalog.json": module.authority.file_hash(path).upper()})
        path.write_text("changed")
        with self.assertRaisesRegex(module.authority.PhaseClosureError, "runtime input drift"):
            module.runtime_inputs(self.root, inventory)

    def test_missing_runtime_fixture_rejected(self):
        with self.assertRaises((module.authority.PhaseClosureError, FileNotFoundError)):
            module.runtime_inputs(self.root, {"runtimeInputs": [{"path": "missing.json", "sha256": "0" * 64}]})

    def test_existing_outside_runtime_fixture_rejected(self):
        with tempfile.TemporaryDirectory() as other:
            path = Path(other).resolve() / "outside.json"
            path.write_text("outside")
            with self.assertRaises(module.authority.PhaseClosureError):
                module.runtime_inputs(self.root, {"runtimeInputs": [{"path": str(path),
                    "sha256": module.authority.file_hash(path)}]})

    def test_duplicate_runtime_fixture_rejected(self):
        path = self.root / "catalog.json"
        path.write_text("catalog")
        reference = {"path": "catalog.json", "sha256": module.authority.file_hash(path)}
        with self.assertRaisesRegex(module.authority.PhaseClosureError, "duplicate runtime input"):
            module.runtime_inputs(self.root, {"runtimeInputs": [reference, reference]})


if __name__ == "__main__":
    unittest.main()
