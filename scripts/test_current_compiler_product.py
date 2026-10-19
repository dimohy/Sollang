"""Compiler reuse rejects changed sources, binaries, LLVM, and diagnostics."""
import hashlib
import importlib.util
import json
import unittest
from pathlib import Path

import test_verification_source_proof as source_fixture

spec = importlib.util.spec_from_file_location('current_product', Path(__file__).with_name('verify-current-compiler-product.py'))
product = importlib.util.module_from_spec(spec)
spec.loader.exec_module(product)


class ProductTests(unittest.TestCase):
    def setUp(self):
        source_fixture.SourceProofTests.setUp(self)
        self.build = self.root / 'build'
        self.build.mkdir()
        self.compiler = self.build / 'compiler.exe'
        self.llvm = self.build / 'compiler.exe.ll'
        self.compiler.write_bytes(b'compiler')
        self.llvm.write_bytes(b'llvm')
        for name in ('build.stdout.txt', 'build.stderr.txt'):
            (self.build / name).write_text('')
        self.record.update(steps=dict.fromkeys(('semanticPreflight', 'build', 'llvmAs', 'v004'), 0),
                           compilerSha256=self.digest(self.compiler),
                           generatedArtifactHashes=[dict(path=str(self.llvm), sha256=self.digest(self.llvm))])
        self.save()

    @staticmethod
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest().upper()

    def save(self):
        (self.build / 'result.json').write_text(json.dumps(self.record))

    def test_current_product_is_reusable(self):
        self.assertEqual(product.validate(self.root, self.build)['compiler'], str(self.compiler))

    def test_stale_source_rejects_reuse(self):
        self.source.write_text('changed')
        with self.assertRaisesRegex(ValueError, 'SOURCE_INPUT_DRIFT'):
            product.validate(self.root, self.build)

    def test_changed_binary_rejects_reuse(self):
        self.compiler.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'BINARY_DRIFT'):
            product.validate(self.root, self.build)

    def test_changed_llvm_rejects_reuse(self):
        self.llvm.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'LLVM_DRIFT'):
            product.validate(self.root, self.build)

    def test_warning_rejects_reuse(self):
        (self.build / 'build.stdout.txt').write_text('warning S001 example\n')
        with self.assertRaisesRegex(ValueError, 'BUILD_DIAGNOSTICS'):
            product.validate(self.root, self.build)

    def test_missing_build_step_rejects_reuse(self):
        del self.record['steps']['llvmAs']
        self.save()
        with self.assertRaisesRegex(ValueError, 'BUILD_STEPS_INCOMPLETE'):
            product.validate(self.root, self.build)


if __name__ == '__main__':
    unittest.main()
