"""Native persisted numeric facts must be exact-source, bounded and checksummed."""
import importlib.util
import struct
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "numeric_cache_verifier", Path(__file__).with_name("verify-contextual-numeric-cache.py"))
VERIFIER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFIER)
SOURCE = b"main { UInt8(4) => first; UInt16(4) => second }"


def envelope(words):
    words[2] = len(words) + 32
    digest = VERIFIER.hashlib.sha256(struct.pack(f"<{len(words)}Q", *words)).digest()
    return words + list(digest)


def fixture(*, facts=(1, 0, 2, 1), source=SOURCE, call_schema=2,
            frame_schema=1, array_plan=None):
    # Public recipe rows: unsigned builtin symbols 8 and 9, signedWord encoded.
    recipes = [6002245308444529748, 1, 0, 0, 27, 2, 0,
               1, 2, 0, 16, 0, 0, 0, 0, 0, 0,
               1, 2, 0, 18, 0, 0, 0, 0, 0, 0]
    owner = [6002245308478540870, 1, 0, len(source), len(recipes), 0, len(facts) // 2,
             *source, *recipes, *facts]
    owner[2] = len(owner)
    calls = [6002245308495514451, call_schema, 6 + len(owner), len(owner), 0, 0, *owner]
    generation = envelope([6002245308512486734, 1, 0, 123, 1, 0, len(calls), 0,
                           *([0] * 32), *calls])
    if array_plan is None:
        array_plan = ([5931875489630604371, 1, 0, 0, 0, 0, 0] + [0] * 32
                      if frame_schema == 2 else [])
    return envelope([6002245308512486735, frame_schema, 0, 1, 0, 1, 1, 0, len(array_plan),
                     *array_plan,
                     0, len(generation), *generation])


class NativeNumericCacheTests(unittest.TestCase):
    def inspect(self, words, source=SOURCE):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            cache = output / ".sollang-cache"
            cache.mkdir()
            (cache / "test.semantic").write_bytes(struct.pack(f"<{len(words)}Q", *words))
            return VERIFIER.native_semantic_facts(output, source)

    def test_reads_persisted_widths(self):
        expressions, owner, bindings = self.inspect(fixture())
        self.assertEqual({value[3] for value in expressions.values()}, {16, 18})
        self.assertEqual(owner, "exact-source-main")
        self.assertEqual(bindings, {})

    def test_schema2_reads_widths_after_array_plan(self):
        self.assertEqual(self.inspect(fixture(frame_schema=2)), self.inspect(fixture()))

    def test_unknown_frame_schema_rejected(self):
        with self.assertRaisesRegex(ValueError, "CACHE_HEADER"):
            self.inspect(fixture(frame_schema=3))

    def test_legacy_frame_with_array_prefix_rejected(self):
        with self.assertRaisesRegex(ValueError, "CACHE_HEADER"):
            self.inspect(fixture(array_plan=[0] * 39))

    def test_schema2_short_array_prefix_rejected(self):
        with self.assertRaisesRegex(ValueError, "CACHE_HEADER"):
            self.inspect(fixture(frame_schema=2, array_plan=[0] * 38))

    def test_schema2_array_prefix_overflow_rejected(self):
        words = fixture(frame_schema=2)[:-32]
        words[8] = len(words)
        with self.assertRaisesRegex(ValueError, "CACHE_HEADER"):
            self.inspect(envelope(words))

    def test_schema2_array_header_rejected(self):
        for field, value in [(0, 0), (1, 2), (5, 1000001), (6, 1), (7, 256)]:
            with self.subTest(field=field):
                words = fixture(frame_schema=2)[:-32]
                words[9 + field] = value
                with self.assertRaisesRegex(ValueError, "STATIC_ARRAYS_HEADER"):
                    self.inspect(envelope(words))

    def test_schema2_row_count_overflow_rejected(self):
        words = fixture(frame_schema=2)[:-32]
        words[3] = len(words)
        with self.assertRaisesRegex(ValueError, "CACHE_HEADER"):
            self.inspect(envelope(words))

    def test_legacy_call_schema_rejected(self):
        with self.assertRaisesRegex(ValueError, "OWNER_CALLS_HEADER"):
            self.inspect(fixture(call_schema=1))

    def test_corruption_rejected(self):
        words = fixture()
        words[20] ^= 1
        with self.assertRaisesRegex(ValueError, "CHECKSUM"):
            self.inspect(words)

    def test_truncation_rejected(self):
        with self.assertRaisesRegex(ValueError, "HEADER"):
            self.inspect(fixture()[:-1])

    def test_different_source_rejected(self):
        with self.assertRaisesRegex(ValueError, "MAIN_OWNER_NOT_UNIQUE"):
            self.inspect(fixture(), SOURCE + b"\n")

    def test_duplicate_expression_rejected(self):
        with self.assertRaisesRegex(ValueError, "DUPLICATE_OR_TYPE"):
            self.inspect(fixture(facts=(1, 0, 1, 1)))

    def test_unknown_recipe_rejected(self):
        with self.assertRaisesRegex(ValueError, "DUPLICATE_OR_TYPE"):
            self.inspect(fixture(facts=(1, 0, 2, 99)))


if __name__ == "__main__":
    unittest.main()
