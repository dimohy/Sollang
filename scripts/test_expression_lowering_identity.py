"""Reject equal-count expression inventories with incorrect AST identities."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/verify-expression-lowering-parity.ps1'


class IdentityTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        declarations = SCRIPT.read_text().split('foreach ($path in', 1)[0]
        paths = re.findall(r'\$\w+Path = Join-Path \$root [\"\x27]([^\"\x27]+)[\"\x27]', declarations)
        for name in paths:
            relative = Path(name.replace('\\', '/'))
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)

    def run_gate(self, root):
        return subprocess.run(['pwsh', '-NoProfile', '-File', str(SCRIPT), '-RepositoryRoot', str(root)],
                              capture_output=True, text=True, encoding='utf-8')

    def mapping(self, expression, kind):
        path = self.root / 'scripts/contracts/expression-lowering-parity.json'
        record = json.loads(path.read_text())
        next(row for row in record['mappings'] if row['managedExpression'] == expression)['selfhostAstKinds'] = [kind]
        path.write_text(json.dumps(record))

    def test_current_42_expression_inventory_passes(self):
        result = self.run_gate(ROOT)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('mapping 42/42', result.stdout)

    def test_old_compile_time_each_identity_rejected(self):
        self.mapping('CompileTimeEachExpression', 83)
        result = self.run_gate(self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('canonical AST identity: CompileTimeEachExpression', result.stderr)

    def test_boolean_cannot_use_compile_time_each_identity(self):
        self.mapping('BoolExpression', 84)
        result = self.run_gate(self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('canonical AST identity: BoolExpression', result.stderr)

    def test_equal_canonical_kinds_rejected(self):
        path = self.root / 'scripts/contracts/ast-expression-kinds.json'
        record = json.loads(path.read_text())
        next(row for row in record['kinds'] if row['identity'] == 'compile-time-each')['kind'] = 83
        path.write_text(json.dumps(record))
        self.mapping('CompileTimeEachExpression', 83)
        result = self.run_gate(self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('AST expression identities collide', result.stderr)


if __name__ == '__main__':
    unittest.main()
