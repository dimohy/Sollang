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
