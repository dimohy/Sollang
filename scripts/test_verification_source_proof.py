"""Reject historical, changed, and incomplete native compiler source proofs."""

import hashlib
import tempfile
import unittest
from pathlib import Path

from verification_source_proof import current_build_inputs


class SourceProofTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "selfhost/compiler.slg"
        self.manifest = self.root / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
        self.stdlib = self.root / "stdlib/std/test.slg"
        for path, text in [(self.source, "source"), (self.stdlib, "library"), (self.manifest, "selfhost/compiler.slg\n")]:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        pins = {str(path): hashlib.sha256(path.read_bytes()).hexdigest().upper()
                for path in [self.source, self.stdlib, self.manifest]}
        self.record = {"status": "passed", "inputsStable": True, "inputHashesStart": pins,
                       "inputHashesEnd": dict(pins), "inputFingerprint": "same", "finalInputFingerprint": "same"}

    def test_current_canonical_sources_pass(self):
        self.assertIn(self.source, current_build_inputs(self.root, self.record))

    def test_changed_source_cannot_reuse_passed_build(self):
        self.source.write_text("changed", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "PAIRED_COMPILER_SOURCE_INPUT_DRIFT"):
            current_build_inputs(self.root, self.record)

    def test_new_stdlib_source_requires_rebuild(self):
        self.stdlib.with_name("new.slg").write_text("new", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "PAIRED_COMPILER_SOURCE_CLOSURE_INCOMPLETE"):
            current_build_inputs(self.root, self.record)

    def test_changed_build_inputs_do_not_count_as_stable(self):
        self.record["inputHashesEnd"] = {}
        with self.assertRaisesRegex(ValueError, "PAIRED_COMPILER_SOURCE_PROOF_INCOMPLETE"):
            current_build_inputs(self.root, self.record)

    def test_missing_canonical_manifest_is_rejected(self):
        del self.record["inputHashesStart"][str(self.manifest)]
        self.record["inputHashesEnd"] = dict(self.record["inputHashesStart"])
        with self.assertRaisesRegex(ValueError, "PAIRED_COMPILER_CANONICAL_MANIFEST_MISSING"):
            current_build_inputs(self.root, self.record)


if __name__ == "__main__":
    unittest.main()
