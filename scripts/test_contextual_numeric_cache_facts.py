"""Contract of the bounded semantic facts prefix, independent of later payloads."""
import hashlib
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "contextual_numeric_cache", Path(__file__).with_name("verify-contextual-numeric-cache.py"))
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def prefix(schema):
    def word(value):
        return struct.pack("<Q", value)

    def text(value):
        encoded = value.encode("utf-8")
        return word(len(encoded)) + encoded

    # The producer writes numeric facts before the optional main scope and the
    # version-dependent function records. The latter are outside this reader.
    header = [6002245291165495635, schema, 101, 202, 303, 0, 0, 0, 0, 0, 1, 0, 0]
    facts = {"provider.value:0": "UInt8", "plain:1": "UInt16", "plus:2": "Int"}
    bindings = {"first": "UInt8", "second": "UInt16"}
    data = struct.pack("<13Q", *header) + bytes(32)
    data += word(len(facts)) + b"".join(text(k) + text(v) for k, v in facts.items())
    data += text("consumer.한글")
    data += word(len(bindings)) + b"".join(text(k) + text(v) for k, v in bindings.items())
    return data + hashlib.sha256(data).digest(), (facts, "consumer.한글", bindings)


class ManagedSemanticFacts(unittest.TestCase):
    def read(self, raw):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "facts.semantic"
            path.write_bytes(raw)
            return verifier.semantic_facts(path)

    def test_current_schema11_keeps_exact_types_and_main_identity(self):
        raw, expected = prefix(11)
        self.assertEqual(self.read(raw), expected)

    def test_previous_prefix_versions_remain_readable(self):
        for version in (9, 10):
            with self.subTest(version=version):
                raw, expected = prefix(version)
                self.assertEqual(self.read(raw), expected)

    def test_unknown_schema_rejected_with_valid_checksum(self):
        raw, _ = prefix(12)
        with self.assertRaisesRegex(ValueError, "CONTEXTUAL_NUMERIC_CACHE_SCHEMA_CHANGED"):
            self.read(raw)

    def test_changed_payload_rejected_before_reading_facts(self):
        raw, _ = prefix(11)
        changed = bytearray(raw)
        changed[140] ^= 1
        with self.assertRaisesRegex(ValueError, "CONTEXTUAL_NUMERIC_CACHE_CHECKSUM_CHANGED"):
            self.read(changed)


if __name__ == "__main__":
    unittest.main()
