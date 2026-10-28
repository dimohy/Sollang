"""Guard the distinction between executable LLVM and checked source acceptance."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
import copy
import json
from contextlib import nullcontext
from types import SimpleNamespace
from unittest.mock import patch
import sys
import os
import shutil

from verification_fingerprints import input_file_identity, unique_input_files
from verification_contract_lease import VerificationContractLease

SCRIPT = Path(__file__).with_name("verify-checked-package-emitter.py")
spec = importlib.util.spec_from_file_location("checked_package_validator", SCRIPT)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class CheckedPackageEmitterTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name).resolve()
        (self.root / "stdlib").mkdir()
        (self.root / "stdlib/library.slg").write_text("namespace sample\n", encoding="utf-8")
        (self.root / "program.slg").write_text("main {}\n", encoding="utf-8")
        self.wrapper = self.root / "wrapper.slg"
        self.wrapper.write_text(
            'import sollang.compiler.llvm.text as compiler\n'
            'import sollang.compiler.syntax.source_decoding as sourceDecoding\n'
            'import sys.file as file\n\nmain {\n    [\n'
            '    "stdlib/library.slg",\n    "program.slg"\n'
            '    ] => declaredPaths\n    [Text; ~] => paths!\n'
            '    declaredPaths -> each sourcePath { paths! -> push(sourcePath) }\n'
            '    [file.SourceText; ~] => owners!\n'
            '    paths! -> each sourcePath {\n        sourcePath -> file.mapText => owner\n'
            '        owners! -> push(owner)\n    }\n    [Text; ~] => sources!\n'
            '    owners! -> each owner {\n        owner -> sourceDecoding.utf8Text => source\n'
            '        sources! -> push(source)\n    }\n'
            '    sources! -> compiler.emitCheckedWithPaths(paths!, 1) => diagnosticCount\n'
            '    diagnosticCount != 0 -> if { "selection-emission-rejected" -> println }\n}\n',
            encoding="utf-8")
        self.contract = {"observedSourceOrder": ["stdlib/library.slg", "program.slg"],
                         "cases": [{"source": "wrapper.slg", "emittedLlvm": True}]}

    def test_checked_original_program_and_complete_package_pass(self):
        self.assertEqual(validator.validate(self.contract, self.root), 1)

    def test_unchecked_emission_is_rejected(self):
        self.wrapper.write_text(self.wrapper.read_text().replace(
            "compiler.emitCheckedWithPaths(paths!, 1) => diagnosticCount", "compiler.emit"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "EMITTER_NOT_CANONICAL_CHECKED"):
            validator.validate(self.contract, self.root)

    def test_missing_stdlib_and_duplicate_order_are_rejected(self):
        (self.root / "stdlib/second.slg").write_text("namespace second\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "STDLIB_SCOPE_INVALID"):
            validator.validate(self.contract, self.root)
        self.contract["observedSourceOrder"].insert(0, "stdlib/library.slg")
        with self.assertRaisesRegex(ValueError, "SOURCE_ORDER_INVALID"):
            validator.validate(self.contract, self.root)

    def reusable_contract(self):
        (self.root / 'helper.slg').write_text('namespace helper\n', encoding='utf-8')
        (self.root / 'second.slg').write_text('main {}\n', encoding='utf-8')
        producer = {'id': 'checked-unit', 'source': 'wrapper.slg',
                    'additionalSources': ['helper.slg'], 'stdlibSourceOrder': ['stdlib/library.slg']}
        cases = [{'id': name, 'source': producer['source'],
                  'additionalSources': producer['additionalSources'][:], 'programSource': name,
                  'runArguments': [name], 'observedSourceOrder': ['stdlib/library.slg', name],
                  'exit': 0, 'emittedLlvm': index == 0}
                 for index, name in enumerate(['program.slg', 'second.slg'])]
        spec = importlib.util.spec_from_file_location('runtime_generator', validator.GENERATOR)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        self.wrapper.write_bytes(generator.render('', True, producer['stdlibSourceOrder'],
                                                  runtime_program_paths=['program.slg', 'second.slg']))
        return {'reusableCheckedProducer': producer, 'cases': cases}

    def test_reusable_checked_producer_preserves_both_case_shapes(self):
        contract = self.reusable_contract()
        self.assertEqual(validator.validate(contract, self.root), 1)
        self.assertEqual(validator.validate_reusable(contract, self.root), 1)
        self.wrapper.write_text(self.wrapper.read_text().replace('compiler.emitChecked', 'compiler.emit'))
        with self.assertRaisesRegex(ValueError, 'NOT_CANONICAL_CHECKED'):
            validator.validate_reusable(contract, self.root)

    def test_checked_files_mode_requires_exact_files_consumer(self):
        contract = self.reusable_contract()
        contract['reusableCheckedProducer']['inputMode'] = 'checked-files'
        # The text-source consumer cannot stand in for the CLI file-loading path.
        with self.assertRaisesRegex(ValueError, 'NOT_CANONICAL_CHECKED'):
            validator.validate_reusable(contract, self.root)
        spec = importlib.util.spec_from_file_location('files_generator', validator.GENERATOR)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        self.wrapper.write_bytes(generator.render('', True, ['stdlib/library.slg'],
            runtime_program_paths=['program.slg', 'second.slg'], checked_files=True))
        self.assertEqual(validator.validate_reusable(contract, self.root), 1)
        source = self.wrapper.read_text()
        self.assertIn('paths! -> compiler.emitCheckedFilesWithStandardLibrarySources(1)', source)
        self.assertNotIn('file.mapText', source)
        contract['reusableCheckedProducer']['inputMode'] = 'unchecked-files'
        with self.assertRaisesRegex(ValueError, 'INPUT_MODE_INVALID'):
            validator.validate_reusable(contract, self.root)

    def multi_file_contract(self):
        contract = self.reusable_contract()
        (self.root / 'peer.slg').write_text('namespace peer\n', encoding='utf-8')
        first = contract['cases'][0]
        first['programAdditionalSources'] = ['peer.slg']
        first['observedSourceOrder'].append('peer.slg')
        spec = importlib.util.spec_from_file_location('multi_file_generator', validator.GENERATOR)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        order, groups = generator.validated_runtime_program_groups(contract, self.root)
        self.wrapper.write_bytes(generator.render('', True, order,
            runtime_program_paths=list(groups), runtime_program_groups=groups))
        return contract

    def test_multi_file_groups_keep_exact_source_order_and_consumer(self):
        contract = self.multi_file_contract()
        self.assertEqual(validator.validate_reusable(contract, self.root), 1)
        rendered = self.wrapper.read_text()
        self.assertIn('paths! -> push("program.slg")\n            paths! -> push("peer.slg")', rendered)
        self.wrapper.write_text(rendered.replace('paths! -> push("peer.slg")', 'paths! -> push("second.slg")'))
        with self.assertRaisesRegex(ValueError, 'NOT_CANONICAL_CHECKED'):
            validator.validate_reusable(contract, self.root)

    def test_multi_file_groups_reject_undeclared_duplicate_and_unsafe_sources(self):
        contract = self.multi_file_contract()
        for sources in [None, ['missing.slg'], ['../escape.slg'], ['stdlib/library.slg'],
                        ['program.slg'], ['peer.slg', 'peer.slg']]:
            with self.subTest(sources=sources):
                invalid = copy.deepcopy(contract)
                invalid['cases'][0]['programAdditionalSources'] = sources
                with self.assertRaisesRegex(ValueError, 'PROGRAM_SOURCES_'):
                    validator.validate_reusable(invalid, self.root)
        invalid = copy.deepcopy(contract)
        invalid['cases'][0]['observedSourceOrder'] = ['stdlib/library.slg', 'peer.slg', 'program.slg']
        with self.assertRaisesRegex(ValueError, 'PROGRAM_ARGUMENT_MISMATCH'):
            validator.validate_reusable(invalid, self.root)

    def test_one_selector_cannot_choose_conflicting_source_groups(self):
        contract = self.multi_file_contract()
        conflicting = copy.deepcopy(contract['cases'][0])
        conflicting['programAdditionalSources'] = []
        conflicting['observedSourceOrder'] = ['stdlib/library.slg', 'program.slg']
        contract['cases'].append(conflicting)
        with self.assertRaisesRegex(ValueError, 'PROGRAM_SOURCES_AMBIGUOUS'):
            validator.validate_reusable(contract, self.root)

    def test_package_source_prefix_cannot_include_the_user_program(self):
        contract = self.reusable_contract()
        contract['reusableCheckedProducer']['stdlibSourceOrder'].append('program.slg')
        with self.assertRaisesRegex(ValueError, 'STDLIB_ORDER_INVALID'):
            validator.validate_reusable(contract, self.root)

    def test_previous_user_only_package_consumer_is_rejected(self):
        contract = self.reusable_contract()
        source = self.wrapper.read_text().replace(
            'compiler.emitCheckedWithPaths(paths!, 1)', 'compiler.emitChecked')
        self.wrapper.write_text(source)
        with self.assertRaisesRegex(ValueError, 'NOT_CANONICAL_CHECKED'):
            validator.validate_reusable(contract, self.root)

    def test_reusable_acceptance_rejects_different_input_and_producer_authority(self):
        contract = self.reusable_contract()
        acceptance = json.loads((SCRIPT.parent / 'contracts/checked-producer-reuse-acceptance.json').read_text())
        mutations = {
            'group-producer-source-mismatch': lambda c: c['cases'][0].update(source='second.slg'),
            'group-compile-closure-mismatch': lambda c: c['cases'][0].update(additionalSources=[]),
            'group-program-argument-mismatch': lambda c: c['cases'][0].update(runArguments=['./program.slg']),
            'group-stdlib-inventory-or-order-mismatch': lambda c: c['reusableCheckedProducer'].update(stdlibSourceOrder=[]),
            'group-program-last-mismatch': lambda c: c['cases'][0].update(observedSourceOrder=['program.slg', 'stdlib/library.slg']),
            'group-missing-or-outside-program': lambda c: c['cases'][0].update(programSource='../outside.slg'),
        }
        ids = {row['id'] for row in acceptance['cases'] if row['owner'] == 'validator'}
        self.assertEqual(ids, set(mutations))
        for identifier, mutate in mutations.items():
            candidate = copy.deepcopy(contract)
            mutate(candidate)
            with self.subTest(acceptance=identifier), self.assertRaises(ValueError):
                validator.validate_reusable(candidate, self.root)

    def test_reusable_rejects_missing_files_duplicate_inventory_and_baked_program(self):
        contract = self.reusable_contract()
        for mutate in [
                lambda c: c['reusableCheckedProducer'].update(stdlibSourceOrder=['stdlib/library.slg'] * 2),
                lambda c: c['cases'][0].update(programSource='missing.slg'),
                lambda c: c.update(observedSourceOrder=['stdlib/library.slg', 'program.slg']),
                lambda c: c['reusableCheckedProducer'].update(id='../outside')]:
            candidate = copy.deepcopy(contract)
            mutate(candidate)
            with self.assertRaises(ValueError):
                validator.validate_reusable(candidate, self.root)


class NumericCheckedProducerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(SCRIPT.parent))
        module_spec = importlib.util.spec_from_file_location('numeric_checked_test',
                                                          SCRIPT.with_name('verify-c385-preir-call-numeric.py'))
        cls.numeric = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(cls.numeric)
        cls.contract = json.loads((SCRIPT.parent.parent / 'artifacts/scratch/'
            'resume-rootfc1a-c385-named-borrowed-move-reusable-checked-contract-20261004-04.json').read_text())

    def test_explicit_harness_optimization_preserves_defaults_and_rejects_invalid(self):
        self.assertEqual(self.numeric.harness_build_options({}, 'managed'), [])
        self.assertEqual(self.numeric.harness_build_options({}, 'paired'), ['-O1'])
        self.assertEqual(self.numeric.harness_build_options({'harnessBuildOptimization': '-O0'}, 'managed'), ['-O0'])
        with self.assertRaisesRegex(ValueError, 'HARNESS_BUILD_OPTIMIZATION_INVALID'):
            self.numeric.harness_build_options({'harnessBuildOptimization': '-Ofast'}, 'managed')

    def test_legacy_and_undeclared_runtime_fields_are_separate(self):
        legacy = {'cases': [{'source': 'program.slg'}]}
        self.assertIsNone(self.numeric.reusable_producer(legacy))
        self.assertEqual(self.numeric.contract_observed_sources(legacy), [])
        for field in ('programSource', 'runArguments', 'observedSourceOrder'):
            invalid = copy.deepcopy(legacy)
            invalid['cases'][0][field] = ['program.slg']
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'RUNTIME_FIELDS_REQUIRE_GROUP'):
                self.numeric.contract_observed_sources(invalid)

    def test_all_original_programs_are_leased_without_changing_case_order(self):
        # This historical 143-module fixture is a unit-test inventory, not the
        # live stdlib inventory. Keep its source universe isolated from additions.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'scripts').mkdir()
            for tool in ('verify-checked-package-emitter.py', 'generate-selection-result-emitter.py'):
                shutil.copyfile(SCRIPT.parent / tool, root / 'scripts' / tool)
            group = self.contract['reusableCheckedProducer']
            programs = [case['programSource'] for case in self.contract['cases']]
            for name in [*group['stdlibSourceOrder'], *group['additionalSources'], *programs]:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('main {}\n', encoding='utf-8')
            spec = importlib.util.spec_from_file_location('lease_generator', validator.GENERATOR)
            generator = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(generator)
            wrapper = root / group['source']
            wrapper.parent.mkdir(parents=True, exist_ok=True)
            wrapper.write_bytes(generator.render('', True, group['stdlibSourceOrder'],
                                                 runtime_program_paths=list(dict.fromkeys(programs))))
            with patch.object(self.numeric, 'ROOT', root):
                self.assertEqual(self.numeric.reusable_producer(self.contract), group)
                before = copy.deepcopy(self.contract)
                paths = self.numeric.contract_observed_sources(self.contract)
                self.assertEqual(len(paths), 156)
                self.assertEqual(len(paths), len(set(paths)))
                self.assertEqual(self.contract, before)
                self.assertEqual(paths[:143], [(root / name).resolve()
                                             for name in group['stdlibSourceOrder']])

    def test_producer_cannot_be_an_expected_failed_build_or_write_build_diagnostics(self):
        for fields in ({'exit': 1}, {'stderr': 'unexpected build diagnostics'}):
            candidate = copy.deepcopy(self.contract)
            candidate['cases'][0].update(fields)
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                self.numeric.reusable_producer(candidate)
        candidate = copy.deepcopy(self.contract)
        candidate['reusableCheckedProducer']['id'] = '../outside'
        with self.assertRaisesRegex(ValueError, 'PRODUCER_ID_INVALID'):
            self.numeric.reusable_producer(candidate)

    def test_shared_binary_changed_or_missing_is_not_current(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'probe.exe'
            binary.write_bytes(b'original producer')
            pins = {binary: self.numeric.sha(binary)}
            self.assertTrue(self.numeric.binary_inputs_stable(pins))
            binary.write_bytes(b'changed producer')
            self.assertFalse(self.numeric.binary_inputs_stable(pins))
            binary.unlink()
            self.assertFalse(self.numeric.binary_inputs_stable(pins))

    def fake_dispatch(self, fault=None, runtime_names=None):
        """Exercise supervision wiring without compiling or running a program."""
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        root = Path(workspace.name).resolve()
        for name in (
                'driver.slg', 'helper.slg', 'program.slg', 'second.slg', 'stdlib/library.slg',
                'fixture.project', 'managed.exe', 'managed.dll',
                'src/Sollang.Compiler/Semantics/SemanticCompiler.cs',
                'scripts/verification_execution.py', 'scripts/verification_step_diagnostics.py',
                'scripts/verification_json_records.py', 'scripts/verification_async_workers.py',
                'scripts/verification_observed_sources.py', 'scripts/verification_contract_lease.py',
                'scripts/verify-checked-package-emitter.py', 'scripts/generate-selection-result-emitter.py',
                'scripts/contracts/checked-producer-reuse-acceptance.json',
                'scripts/completed_artifact_plan.py', 'scripts/ArtifactLifecycle.ps1',
                'scripts/Invoke-CompletedArtifactCleanup.ps1', 'scripts/contracts/artifact-lifecycle.json',
                '.tools/llvm-22.1.8/bin/clang.exe', '.tools/llvm-22.1.8/bin/llvm-as.exe',
                'tests/native-interop/owned_array_audit.c'):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture input\n', encoding='utf-8')
        group = {'id': 'checked-unit', 'source': 'driver.slg',
                 'additionalSources': ['helper.slg'], 'stdlibSourceOrder': ['stdlib/library.slg']}
        cases = []
        for index, program in enumerate(('program.slg', 'second.slg')):
            case = {'id': f'case{index}', 'source': group['source'],
                    'additionalSources': group['additionalSources'], 'programSource': program,
                    'runArguments': [program], 'observedSourceOrder': ['stdlib/library.slg', program],
                    'exit': 0, 'stderr': '', 'emittedLlvm': index == 0,
                    'stdout': 'value=7' if index == 0 else 'semantic-rejected\nselection-emission-rejected'}
            if index == 0:
                case['expectedAllocations'] = 0
            cases.append(case)
        runtime_names = ['fixture.project'] if runtime_names is None else runtime_names
        for name in runtime_names:
            (root / name).write_text(name, encoding='utf-8')
        contract = {'schemaVersion': 1, 'reusableCheckedProducer': group, 'cases': cases,
                    'runtimeInputFiles': runtime_names}
        contract_path = root / 'contract.json'
        contract_path.write_text(json.dumps(contract), encoding='utf-8')
        commands = []

        class FakeExecution:
            def __init__(self, _root, _output, result, stable, _sha):
                self.result, self.stable = result, stable

            def run(self, command, prefix, **_kwargs):
                if not self.stable():
                    raise ValueError('INPUT_DRIFT before command')
                commands.append((prefix.name, command))
                stdout = ''
                if prefix.name == 'build':
                    Path(command[command.index('-o') + 1]).write_bytes(b'one checked producer')
                elif prefix.name == 'run':
                    if fault == 'cancel' and command[1] == 'second.slg':
                        raise KeyboardInterrupt()
                    stdout = ('define i32 @main() { ret i32 0 }\n' if command[1] == 'program.slg'
                              else cases[1]['stdout'])
                elif prefix.name in ('assemble', 'native-link', 'audit-link'):
                    Path(command[command.index('-o') + 1]).write_bytes(b'generated artifact')
                elif prefix.name == 'native-run':
                    stdout = cases[0]['stdout']
                elif prefix.name == 'audit-run':
                    stdout = cases[0]['stdout'] + '\nallocations=0,releases=0'
                prefix.with_suffix('.stdout').write_text(stdout, encoding='utf-8')
                stderr = 'S003 build warning' if prefix.name == 'build' and fault == 'build-warning' else ''
                prefix.with_suffix('.stderr').write_text(stderr, encoding='utf-8')
                self.result['processes'].append({'exit': 0, 'shutdownConfirmed': True})
                if prefix.name == 'run' and command[1] == 'program.slg':
                    if fault == 'binary':
                        Path(command[0]).write_bytes(b'drifted producer')
                    elif fault == 'input':
                        (root / 'second.slg').write_text('changed original\n', encoding='utf-8')
                    elif fault == 'runtime-input':
                        (root / runtime_names[-1]).write_text('changed data\n', encoding='utf-8')
                return SimpleNamespace(returncode=0)

        args = SimpleNamespace(contract=contract_path, output=root / 'output', mode='managed',
                               managed_compiler=root / 'managed.exe',
                               format_compiler=None, diagnostics_configuration=None,
                               diagnostics_plan=None, artifact_cleanup='plan-only', reusable_compiler_directory=None)
        error = None
        with patch.object(self.numeric, 'ROOT', root), \
                patch.object(self.numeric, 'reusable_producer', return_value=group), \
                patch.object(self.numeric, 'emission_semantic_proof', return_value=[]), \
                patch.object(self.numeric, 'managed_runtime_inputs', return_value=[]), \
                patch.object(self.numeric, 'initialize_output'), \
                patch.object(self.numeric, 'cleanup_output') as cleanup, \
                patch.object(self.numeric, 'assert_output_shutdown'), \
                patch.object(self.numeric, 'VerificationExecution', FakeExecution), \
                patch('verification_contract_lease.VerificationContractLease', nullcontext):
            try:
                self.numeric.execute(args, None, 'deterministic-test',
                                     self.numeric.contract_observed_sources(contract))
            except (ValueError, KeyboardInterrupt) as caught:
                error = caught
            result = json.loads((args.output / 'result.json').read_text(encoding='utf-8'))
            cleanup_count = cleanup.call_count
        return result, commands, cleanup_count, error

    def test_shared_build_once_keeps_positive_negative_and_allocation_audit(self):
        result, commands, cleanup_count, error = self.fake_dispatch()
        self.assertIsNone(error)
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(result['completed'], 2)
        self.assertTrue(result['inputsStable'] and result['processesStopped'])
        self.assertEqual(sum(stage == 'build' for stage, _ in commands), 1)
        self.assertEqual(result['reusableCheckedProducer']['buildCount'], 1)
        self.assertEqual({row['producerSha256'] for row in result['cases']},
                         {result['reusableCheckedProducer']['executableSha256']})
        self.assertEqual([command[1:] for stage, command in commands if stage == 'run'],
                         [['program.slg'], ['second.slg']])
        self.assertEqual(result['cases'][0]['auditRunExit'], 0)
        self.assertEqual(result['cases'][1]['runStdout'], 'semantic-rejected\nselection-emission-rejected')
        self.assertNotIn('assemblyExit', result['cases'][1])
        self.assertEqual(cleanup_count, 1)

    def test_runtime_data_result_uses_existing_hash_and_stability_contract(self):
        result, _, cleanup_count, error = self.fake_dispatch()
        self.assertIsNone(error)
        self.assertEqual(len(result['runtimeInputFiles']), 1)
        self.assertIn(result['runtimeInputFiles'][0], result['inputHashes'])
        self.assertEqual(result['runtimeInputLease'], 'deterministic-test')
        self.assertTrue(result['inputsStable'])
        self.assertEqual(cleanup_count, 1)

    def test_runtime_data_paths_are_explicit_repo_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'fixture.project').write_text('data')
            with patch.object(self.numeric, 'ROOT', root):
                self.assertEqual(self.numeric.contract_runtime_inputs({}), [])
                self.assertEqual(self.numeric.contract_runtime_inputs(
                    {'runtimeInputFiles': ['fixture.project']}), [root / 'fixture.project'])
                for names in ([], 'fixture.project', [3], ['missing.project'],
                              ['../outside.project'], [str(root / 'fixture.project')],
                              ['.'], ['fixture.project', './fixture.project']):
                    with self.subTest(names=names), self.assertRaisesRegex(ValueError, 'RUNTIME_INPUT_'):
                        self.numeric.contract_runtime_inputs({'runtimeInputFiles': names})

    def test_distinct_deseret_runtime_files_keep_both_hashes_and_detect_second_drift(self):
        names = ['\U00010400.project', '\U00010428.project']
        for fault in (None, 'runtime-input'):
            with self.subTest(fault=fault):
                result, _, cleanup_count, error = self.fake_dispatch(fault, names)
                self.assertEqual(len(result['runtimeInputFiles']), 2)
                self.assertEqual(len({str(p) for p in result['runtimeInputFiles']}), 2)
                self.assertTrue(all(p in result['inputHashes'] for p in result['runtimeInputFiles']))
                self.assertEqual(result['runtimeInputLease'], 'deterministic-test')
                self.assertTrue(result['processesStopped'])
                self.assertEqual(result['inputsStable'], fault is None)
                self.assertEqual(cleanup_count, int(fault is None))
                self.assertEqual(error is None, fault is None)

    def test_physical_file_identity_preserves_distinct_files_and_deduplicates_aliases(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            names = ['normal.project', '\u03a3.project', '\u03c2.project',
                     '\U00010400.project', '\U00010428.project']
            files = [root / name for name in names]
            for index, path in enumerate(files):
                path.write_text(str(index), encoding='utf-8')
            self.assertFalse(os.path.samefile(files[-2], files[-1]))
            if os.name == 'nt':
                self.assertEqual(files[-2], files[-1])  # The original WindowsPath defect.
            self.assertEqual(len(unique_input_files(files)), 5)
            alias = root / 'alias.project'
            os.link(files[0], alias)
            self.assertTrue(os.path.samefile(files[0], alias))
            self.assertEqual(input_file_identity(files[0]), input_file_identity(alias))
            with VerificationContractLease([*files, alias]) as lease:
                self.assertEqual(len(lease.paths), 5)
                self.assertEqual(len(lease.handles), 5)
                if os.name == 'nt':
                    for path in files:
                        with self.subTest(path=str(path)), self.assertRaises(PermissionError):
                            with path.open('wb'):
                                pass
            self.assertEqual(lease.handles, [])
            with patch.object(self.numeric, 'ROOT', root):
                resolved = self.numeric.contract_runtime_inputs({'runtimeInputFiles': names})
                self.assertEqual([str(p) for p in resolved], [str(p) for p in files])
                with self.assertRaisesRegex(ValueError, 'RUNTIME_INPUT_PATH_DUPLICATE'):
                    self.numeric.contract_runtime_inputs({'runtimeInputFiles': ['normal.project', 'alias.project']})
            with self.assertRaises(FileNotFoundError):
                unique_input_files([root / 'missing.project'])
            with self.assertRaisesRegex(ValueError, 'VERIFICATION_INPUT_NOT_FILE'):
                unique_input_files([root])

    def test_physical_identity_unavailable_does_not_fall_back_to_path_equality(self):
        with patch.object(Path, 'stat', return_value=SimpleNamespace(st_mode=0o100644, st_ino=0, st_dev=1)):
            with self.assertRaisesRegex(ValueError, 'VERIFICATION_INPUT_IDENTITY_UNAVAILABLE'):
                input_file_identity(Path('unverified.project'))

    def test_shared_success_exit_with_build_warning_never_runs_binary(self):
        result, commands, cleanup_count, error = self.fake_dispatch('build-warning')
        self.assertIsInstance(error, ValueError)
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['reusableCheckedProducer']['status'], 'failed')
        self.assertEqual(result['reusableCheckedProducer']['buildExit'], 0)
        self.assertEqual(result['cases'][0]['buildStderr'], 'S003 build warning')
        self.assertIsNone(result['cases'][0]['producerSha256'])
        self.assertFalse(result['cases'][0]['passed'])
        self.assertNotIn('runExit', result['cases'][0])
        self.assertEqual(sum(stage == 'build' for stage, _ in commands), 1)
        self.assertEqual(sum(stage == 'run' for stage, _ in commands), 0)
        self.assertTrue(result['inputsStable'] and result['processesStopped'])
        self.assertEqual(cleanup_count, 0)

    def test_shared_drift_and_cancellation_preserve_failed_output(self):
        for fault in ('binary', 'input', 'cancel', 'runtime-input'):
            with self.subTest(fault=fault):
                result, commands, cleanup_count, error = self.fake_dispatch(fault)
                self.assertIsNotNone(error)
                self.assertEqual(result['status'], 'canceled' if fault == 'cancel' else 'failed')
                self.assertTrue(result['processesStopped'])
                self.assertEqual(cleanup_count, 0)
                self.assertEqual(sum(stage == 'build' for stage, _ in commands), 1)
                if fault != 'cancel':
                    self.assertFalse(result['inputsStable'])
                    self.assertEqual([command[1] for stage, command in commands if stage == 'run'],
                                     ['program.slg'])
class EmittedEntryPointTests(unittest.TestCase):
    def test_native_and_wasm_entry_identity_ignores_return_type(self):
        for target, entry in (("windows", "main"), ("wasm", "sollang_start")):
            for result in ("void", "i32"):
                with self.subTest(target=target, result=result):
                    llvm = f"define dso_local {result} @{entry}() {{\n}}\n"
                    self.assertEqual(validator.validate_emitted_entrypoint(llvm, target), entry)

    def test_previous_native_checked_as_wasm_failure_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "EMISSION_ENTRY_DEFINITION_COUNT"):
            validator.validate_emitted_entrypoint("define i32 @main() { ret i32 0 }", "wasm")

    def test_declaration_and_duplicate_definitions_are_rejected(self):
        for llvm in ("declare i32 @main()", "define i32 @main() {}\ndefine void @main() {}"):
            with self.subTest(llvm=llvm):
                with self.assertRaisesRegex(ValueError, "EMISSION_ENTRY_DEFINITION_COUNT"):
                    validator.validate_emitted_entrypoint(llvm, "windows")

    def test_another_function_body_or_comment_cannot_define_entry(self):
        for llvm in ("define i32 @other() { call i32 @main(); ret i32 0 }",
                     "define i32 @other() { ret i32 0 } ; @main()",
                     "; define i32 @main() { ret i32 0 }"):
            with self.subTest(llvm=llvm):
                with self.assertRaisesRegex(ValueError, "EMISSION_ENTRY_DEFINITION_COUNT"):
                    validator.validate_emitted_entrypoint(llvm, "windows")

    def test_unknown_target_cannot_choose_a_default_entry(self):
        with self.assertRaisesRegex(ValueError, "EMISSION_ENTRY_TARGET_UNSUPPORTED"):
            validator.validate_emitted_entrypoint("define i32 @main() {}", "unknown")


if __name__ == "__main__":
    unittest.main()
