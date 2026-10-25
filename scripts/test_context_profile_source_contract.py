"""Reject old owning profile loaders before compiler or runtime work."""
import unittest
from pathlib import Path
from context_profile_source_contract import render_loader, validate_loader


class ProfileSourceContractTests(unittest.TestCase):
    def test_generated_loader_retains_outer_mappings(self):
        validate_loader("namespace example\n" + render_loader(144), 144)
        self.assertTrue(render_loader(144).endswith("\n"))

    def test_old_prepare_files_loader_is_rejected(self):
        old = "\npublic profileResolvedFiles paths: [Text; ~] -> Int {\n    paths -> semanticContext.prepareFiles => prepared!\n}"
        with self.assertRaisesRegex(ValueError, "PROFILE_OUTER_SOURCE_OWNERS_REQUIRED"):
            validate_loader(old, 144)

    def test_moving_owners_into_preparation_is_rejected(self):
        profile = render_loader(144).replace("sources! -> analysis.analyzeCheckedTextSources", "owners! -> analysis.analyzeSources")
        with self.assertRaisesRegex(ValueError, "PROFILE_OUTER_SOURCE_OWNERS_REQUIRED"):
            validate_loader(profile, 144)

    def test_owner_lifetime_marker_removal_is_rejected(self):
        profile = render_loader(144).replace("    owners! -> len => ownerCount\n", "")
        with self.assertRaisesRegex(ValueError, "PROFILE_OUTER_SOURCE_OWNERS_REQUIRED"):
            validate_loader(profile, 144)

    def test_changed_standard_library_prefix_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "PROFILE_OUTER_SOURCE_OWNERS_REQUIRED"):
            validate_loader(render_loader(143), 144)

    def test_duplicate_loader_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "PROFILE_OUTER_SOURCE_OWNERS_REQUIRED"):
            validate_loader(render_loader(144) * 2, 144)

    def test_invalid_prefix_is_rejected(self):
        for value in (None, True, 0, -1, "144"):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "PROFILE_STDLIB_COUNT_INVALID"):
                render_loader(value)

    def test_verifier_uses_contract_before_output_initialization(self):
        verifier = (Path(__file__).parent / "verify-context-phase-profile.py").read_text()
        self.assertLess(verifier.index("validate_loader(profile,"), verifier.index("initialize_output(ROOT,"))


if __name__ == "__main__":
    unittest.main()
