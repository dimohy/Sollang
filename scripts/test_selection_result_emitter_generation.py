"""Reject source drift and invalid embedding before compiler execution."""

import importlib.util
import textwrap
import unittest
import json
from unittest.mock import patch
from pathlib import Path

MODULE = Path(__file__).with_name("generate-selection-result-emitter.py")
SPEC = importlib.util.spec_from_file_location("selection_emitter", MODULE)
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


class SelectionEmitterGenerationTests(unittest.TestCase):
    def test_retained_program_is_the_exact_embedded_input(self):
        program = GENERATOR.PROGRAM.read_text(encoding="utf-8-sig").strip()
        actual = GENERATOR.EMITTER.read_bytes()
        self.assertEqual(actual, GENERATOR.render(program))
        embedded = actual.decode("utf-8").split('"""')[1]
        self.assertEqual(textwrap.dedent(embedded).strip(), program)

    def test_line_endings_and_interpolation_survive_generation(self):
        output = GENERATOR.render('main {\r\n    "$value" -> println\r\n}\r\n')
        self.assertNotIn(b"\r", output)
        self.assertIn(b'"$value" -> println', output)

    def test_empty_source_fails_before_compilation(self):
        with self.assertRaisesRegex(ValueError, "PROGRAM_EMPTY"):
            GENERATOR.render(" \n")

    def test_nested_raw_delimiter_fails_before_compilation(self):
        with self.assertRaisesRegex(ValueError, "RAW_DELIMITER_CONFLICT"):
            GENERATOR.render('main { """nested""" -> println }')

    def test_package_order_and_original_program_survive_embedding(self):
        paths = ['stdlib/sys/file.slg', 'stdlib/std/text/json.slg']
        program = 'main { "hello" -> println }'
        output = GENERATOR.render(program, True, paths).decode('utf-8')
        self.assertLess(output.index(paths[0]), output.index(paths[1]))
        self.assertEqual(textwrap.dedent(output.split('"""')[1]).strip(), program)
        self.assertIn('sources! -> push(input)', output)
        self.assertIn('sources! -> compiler.emitChecked', output)

    def test_package_contract_requires_complete_unique_stdlib_and_exact_program(self):
        program = GENERATOR.PROGRAM
        paths = sorted(path.relative_to(GENERATOR.ROOT).as_posix()
                       for path in (GENERATOR.ROOT / 'stdlib').rglob('*.slg'))
        valid = paths + [program.relative_to(GENERATOR.ROOT).as_posix()]
        self.assertEqual(GENERATOR.validated_package_paths(valid, program), paths)
        invalid = [None, [], valid[1:], [paths[0]] + valid,
                   paths + ['different.slg'], [{}] + valid[1:]]
        for order in invalid:
            with self.subTest(order=order):
                with self.assertRaisesRegex(ValueError, 'PACKAGE_SOURCE_ORDER_INVALID'):
                    GENERATOR.validated_package_paths(order, program)

    def test_program_file_loading_preserves_raw_source_without_embedding(self):
        output = GENERATOR.render('main { """raw""" -> println }', True,
                                  ['stdlib/sys/file.slg'], 'original.slg').decode()
        self.assertLess(output.index('stdlib/sys/file.slg'), output.index('original.slg'))
        self.assertNotIn('"""', output)
        self.assertNotIn('sources! -> push(input)', output)
        self.assertIn('sources! -> compiler.emitChecked', output)
        with self.assertRaisesRegex(ValueError, 'PROGRAM_FILE_REQUIRES_PACKAGE'):
            GENERATOR.render('main { }', program_path='original.slg')

    def test_runtime_checked_mode_uses_declared_argv_after_fail_fast_guards(self):
        acceptance = json.loads((MODULE.parent / 'contracts/checked-producer-reuse-acceptance.json').read_text())
        self.assertEqual({row['id'] for row in acceptance['cases'] if row['owner'] == 'generator'}, {
            'legacy-fixed-path-preserved', 'runtime-driver-mode-explicit',
            'runtime-mode-missing-prerequisite', 'runtime-argc-program-allowlist'})
        text = GENERATOR.render('', True, ['stdlib/a.slg', 'stdlib/b.slg'],
                                runtime_program_paths=['original.slg', 'second.slg']).decode()
        self.assertLess(text.index('(arguments -> len) != 2'), text.index('arguments[1]'))
        self.assertLess(text.index('SELECTION_RUNTIME_PROGRAM_PATH_NOT_DECLARED'), text.index('file.mapText'))
        self.assertLess(text.index('stdlib/a.slg'), text.index('stdlib/b.slg'))
        self.assertIn('    "stdlib/b.slg",\n    programPath\n    ] => declaredPaths\n', text)
        self.assertIn('paths! -> each sourcePath', text)
        self.assertIn('[Text; ~] => paths!', text)
        self.assertIn('(programPath -> text.compareOrdinal(candidate)) == 0\n'
                      '            -> if { true => allowed! }', text)
        self.assertIn('sources! -> compiler.emitCheckedWithPaths(paths!, 2) => diagnosticCount', text)
        self.assertIn('diagnosticCount != 0 -> if { "selection-emission-rejected" -> println }', text)
        self.assertNotIn('"""', text)
        self.assertEqual(text.count('process.exit(1)'), 2)

    def test_runtime_mode_cannot_mix_fixed_program_or_unchecked_emission(self):
        for kwargs in [dict(checked=False, package_paths=['library.slg']),
                       dict(checked=True),
                       dict(checked=True, package_paths=['library.slg'], program_path='baked.slg')]:
            with self.subTest(kwargs=kwargs), self.assertRaisesRegex(ValueError, 'RUNTIME_MODE_INVALID'):
                GENERATOR.render('', runtime_program_paths=['original.slg'], **kwargs)

    def test_runtime_cli_missing_each_prerequisite_is_rejected_without_output(self):
        required = ['--checked', '--load-program-from-file', '--package-contract', 'missing.json']
        for omitted in ['--checked', '--load-program-from-file', '--package-contract']:
            flags = required[:]
            position = flags.index(omitted)
            del flags[position:position + (2 if omitted == '--package-contract' else 1)]
            with self.subTest(omitted=omitted), patch('sys.argv', ['generator', '--runtime-program-argument', *flags]):
                with self.assertRaises(ValueError):
                    GENERATOR.main()


if __name__ == "__main__":
    unittest.main()
