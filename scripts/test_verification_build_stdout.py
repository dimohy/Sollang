"""Protocol controls, including outputs that must never become empty stdout."""
import tempfile
import unittest
from pathlib import Path

from verification_build_stdout import POLICY, validate_build_stdout, validate_policy


class BuildStdoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.binary = Path(self.temp.name) / "example.exe"
        self.binary.write_bytes(b"compiled fixture")
        self.prefix = self.binary.parent / ".sollang-cache" / "example.windows-x64"
        self.lines = ["[native 1/1] optimized partition",
            f"[frontend-cache] cold; rebuilt and published 3 sources; {self.prefix}.sources",
            f"[codegen-cache] cold; reused 0/3 units; {self.prefix}.cgu",
            f"[semantic-cache] cold; reused 0/4 functions; main rebuilt; mapped 0/4 functions, 0/5 call sites; {self.prefix}.semantic",
            f"[product-cache] rebuilt; linked and published; {self.prefix}.product",
            f"Wrote {self.binary} ({self.binary.stat().st_size:,} bytes)"]

    def validate(self, lines=None, side="managed"):
        return validate_build_stdout(("\r\n".join(self.lines if lines is None else lines)+"\r\n").encode(), self.binary, side)

    def test_cold_managed(self):
        self.assertEqual("", self.validate()["semanticStdout"])

    def test_exact_managed(self):
        self.validate([f"[frontend-cache] exact hit; skipped parsing and semantic analysis for 3 sources; {self.prefix}.sources",
            f"[codegen-cache] exact; reused 3/3 units; {self.prefix}.cgu",
            f"[semantic-cache] exact via frontend; skipped semantic loading; {self.prefix}.semantic",
            f"[product-cache] exact hit; skipped linking; {self.prefix}.product", self.lines[-1]])

    def test_native(self):
        self.validate([f"[semantic-cache] load-status 50; reused 0/145 sources; rejected 0; uncached 23; {self.prefix}.semantic",
            f"Kept {self.binary}.ll", f"Wrote {self.binary}"], "selfhost")

    def test_partition_progress_for_both_linkers(self):
        for side in ("managed", "selfhost"):
            suffix = self.lines[1:] if side == "managed" else [
                f"[semantic-cache] load-status 50; reused 0/155 sources; rejected 0; uncached 24; {self.prefix}.semantic",
                f"[codegen-cache] reused 0/12 units; {self.prefix}.cgu",
                f"Kept {self.binary}.ll", f"Wrote {self.binary}"]
            for count in (1, 3):
                with self.subTest(side=side, count=count):
                    self.validate([f"[native {i}/{count}] optimized partition"
                        for i in range(1, count + 1)] + suffix, side)

    def test_partition_progress_rejects_incomplete_reordered_and_late_lines(self):
        for side in ("managed", "selfhost"):
            suffix = self.lines[1:] if side == "managed" else [
                f"[semantic-cache] load-status 50; reused 0/155 sources; rejected 0; uncached 24; {self.prefix}.semantic",
                f"Wrote {self.binary}"]
            for progress in (["1/2"], ["1/2", "1/2"], ["2/2", "1/2"],
                             ["1/2", "2/3"], ["0/1"], ["2/1"]):
                with self.subTest(side=side, progress=progress), self.assertRaises(ValueError):
                    self.validate([f"[native {part}] optimized partition" for part in progress] + suffix, side)
            with self.subTest(side=side, late=True), self.assertRaises(ValueError):
                self.validate(suffix[:1] + ["[native 1/1] optimized partition"] + suffix[1:], side)

    def test_native_codegen_cache_counts(self):
        for reused, total in ((0, 12), (7, 12), (12, 12), (0, 0)):
            with self.subTest(reused=reused, total=total):
                self.validate([
                    f"[semantic-cache] load-status 50; reused 0/155 sources; rejected 0; uncached 24; {self.prefix}.semantic",
                    f"[codegen-cache] reused {reused}/{total} units; {self.prefix}.cgu",
                    f"Kept {self.binary}.ll", f"Wrote {self.binary}"], "selfhost")

    def test_native_codegen_cache_rejects_bad_counts_paths_and_duplicates(self):
        line = f"[codegen-cache] reused 0/12 units; {self.prefix}.cgu"
        semantic = f"[semantic-cache] load-status 50; reused 0/155 sources; rejected 0; uncached 24; {self.prefix}.semantic"
        for middle in ([line, line], [line.replace("0/12", "13/12")],
                       [line.replace("0/12", "-1/12")],
                       [line.replace(str(self.prefix), str(self.prefix.parent / 'other.windows-x64'))],
                       [line.replace(".cgu", ".semantic")], [line, "42"]):
            with self.subTest(middle=middle), self.assertRaises(ValueError):
                self.validate([semantic, *middle, f"Wrote {self.binary}"], "selfhost")

    def test_undeclared_output_and_warnings_are_errors(self):
        for extra in ("42", "warning: lowered ownership", "[new-cache] ok", " "):
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                self.validate(self.lines[:-1]+[extra,self.lines[-1]])

    def test_wrong_size_or_product_or_cache_path(self):
        for old,new in ((self.lines[-1],f"Wrote {self.binary} (999 bytes)"),
                        (self.lines[-1],f"Wrote {self.binary}.other (16 bytes)"),
                        (str(self.prefix),str(self.prefix.parent/'other.windows-x64'))):
            with self.subTest(new=new), self.assertRaises(ValueError):
                self.validate([line.replace(old,new) for line in self.lines])

    def test_missing_or_duplicate_or_partial_progress(self):
        for lines in ([], self.lines[1:-1], self.lines+[self.lines[-1]],
                      [self.lines[0].replace("1/1","1/2")]+self.lines[1:],
                      self.lines[:2]+[self.lines[1]]+self.lines[2:]):
            with self.subTest(lines=lines), self.assertRaises(ValueError):
                self.validate(lines)

    def test_rejected_cache_cannot_be_silenced(self):
        with self.assertRaises(ValueError):
            self.validate([line.replace("cold;", "rejected: corrupt;",1) for line in self.lines])

    def test_policy_scope(self):
        oracle={"exitCode":0,"stdout":"","stderr":"","stdoutPolicy":POLICY}
        validate_policy(oracle,"compile")
        for stage,change in (("run",{}),("grammar",{}),("compile",{"exitCode":1}),
                             ("compile",{"stdout":"result"}),("compile",{"stderr":"warning"}),
                             ("compile",{"stdoutPolicy":"ignore-all"})):
            with self.subTest(stage=stage,change=change), self.assertRaises(ValueError):
                validate_policy({**oracle,**change},stage)


if __name__ == "__main__":
    unittest.main()
