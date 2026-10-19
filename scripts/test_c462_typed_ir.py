"""C462 result checks preserve terminal selection and later literal ownership."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('c462_ir', Path(__file__).with_name('verify-c462-typed-ir.py'))
ir = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ir)


def row(index, kind, parent, operand=-1, next_operand=-1, type_id=ir.UINT64):
    return f'node {index} kind {kind} parent {parent} source 0 ast 0 symbol 0 target -1 type {type_id} payload -1 opcode -1 operands {operand}/-1/{next_operand} flags 0'


class ResultTests(unittest.TestCase):
    def setUp(self):
        self.rows = [row(0, 1, -1, 1), row(1, 9, 0), row(2, 5, 1, next_operand=3),
                     row(3, 34, 1, 2), row(4, 1, -1, 5), row(5, 3, 4)]

    def verify(self):
        return ir.verify('\n'.join(self.rows))

    def test_transparent_flow_returns_selection(self):
        self.assertEqual(self.verify()['terminalResult'], 3)

    def test_direct_selection_preserves_same_contract(self):
        self.rows[0] = row(0, 1, -1, 3)
        self.assertEqual(self.verify()['terminalResult'], 3)

    def test_source_cannot_replace_terminal_selection(self):
        self.rows[0] = row(0, 1, -1, 2)
        with self.assertRaisesRegex(ValueError, 'OWNERSHIP_MISMATCH'):
            self.verify()

    def test_nonterminal_control_cannot_replace_later_literal(self):
        self.rows[4] = row(4, 1, -1, 3)
        with self.assertRaisesRegex(ValueError, 'OWNERSHIP_MISMATCH'):
            self.verify()

    def test_wrong_subject_type_rejected(self):
        self.rows[2] = row(2, 5, 1, next_operand=3, type_id='3/1/1/-1/3/0')
        with self.assertRaisesRegex(ValueError, 'SUBJECT_IDENTITY_MISMATCH'):
            self.verify()

    def test_cyclic_wrapper_rejected(self):
        self.rows[1] = row(1, 9, 0, 1)
        with self.assertRaisesRegex(ValueError, 'RESULT_EDGE_INVALID'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
