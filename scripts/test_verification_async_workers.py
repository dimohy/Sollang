"""Suspend/resume contracts must hold for every generic copy, not only stdout."""
import unittest
from verification_async_workers import (validate_worker_contract, validate_workers,
    validate_runtime_selection_contract, validate_runtime_selection)


SPEC = dict(sourceSymbol=1, copies=2, resumeStates=[1, 2])


def worker(index, states=(1, 2)):
    dispatch = ' '.join(f'i32 {state}, label %async_resume{state}' for state in states)
    labels = ''.join(f'async_resume{state}:\n  call void @sollang_task_park_on(ptr %control, ptr null)\n'
                     for state in states)
    return (f'define i1 @sollang_m144_s1_g{index}_async_worker(ptr %control) {{\n'
            f'  switch i32 %async_resume_state, label %async_state_invalid [ i32 0, label %async_state_start {dispatch} ]\n'
            f'{labels}  ret i1 true\n}}\n')


class GenericWorkerContractTests(unittest.TestCase):
    def test_all_copies_suspend(self):
        self.assertEqual([row['resumeStates'] for row in validate_workers(worker(10) + worker(20), SPEC)], [[1, 2], [1, 2]])

    def test_first_copy_blocking_join_is_not_success(self):
        with self.assertRaisesRegex(ValueError, 'RESUME_STATES_MISMATCH'):
            validate_workers(worker(10, ()) + worker(20), SPEC)

    def test_missing_copy(self):
        with self.assertRaisesRegex(ValueError, 'COPY_COUNT_MISMATCH'):
            validate_workers(worker(20), SPEC)

    def test_missing_resume_label(self):
        with self.assertRaisesRegex(ValueError, 'RESUME_LABEL_MISSING'):
            validate_workers((worker(10) + worker(20)).replace('async_resume1:\n', '', 1), SPEC)

    def test_dispatch_without_actual_park(self):
        with self.assertRaisesRegex(ValueError, 'PARK_COUNT_MISMATCH'):
            validate_workers((worker(10) + worker(20)).replace('call void @sollang_task_park_on(', 'call void @other(', 1), SPEC)

    def test_noncanonical_state_contract(self):
        with self.assertRaisesRegex(ValueError, 'CONTRACT_INVALID'):
            validate_worker_contract(dict(sourceSymbol=1, copies=2, resumeStates=[2, 1]))

    def test_bool_is_not_a_numeric_contract(self):
        with self.assertRaisesRegex(ValueError, 'CONTRACT_INVALID'):
            validate_worker_contract(dict(sourceSymbol=True, copies=2, resumeStates=[1]))

    def test_crlf_has_same_contract(self):
        self.assertEqual(len(validate_workers((worker(10) + worker(20)).replace('\n', '\r\n'), SPEC)), 2)


class RuntimeSelectionTests(unittest.TestCase):
    @staticmethod
    def module(file_worker, io_completion):
        text = ''
        if file_worker:
            text += 'define internal void @sollang_file_worker_run(ptr %context) #0 {\n  ret void\n}\n'
            text += ''.join('@sollang_' + name + ' = internal global i64 0\n' for name in
                            ('file_request_head', 'file_worker_started', 'file_worker_stopping'))
        if io_completion:
            text += 'define internal void @sollang_io_push_completion(ptr %control) #0 {\n  ret void\n}\n'
            text += '@sollang_io_completion_head = internal global ptr null\n'
        return text

    def test_file_socket_and_scheduler_boundaries(self):
        for file_worker, io_completion in ((True, True), (False, True), (False, False)):
            with self.subTest(file=file_worker, io=io_completion):
                observed = validate_runtime_selection(self.module(file_worker, io_completion),
                    dict(fileWorker=file_worker, ioCompletion=io_completion))
                self.assertEqual(observed['sollang_file_worker_run'], int(file_worker))

    def test_dormant_file_worker_is_not_socket_only(self):
        with self.assertRaisesRegex(ValueError, 'SELECTION_MISMATCH:sollang_file_worker_run'):
            validate_runtime_selection(self.module(True, True), dict(fileWorker=False, ioCompletion=True))

    def test_references_do_not_supply_definitions(self):
        text = 'call void @sollang_io_push_completion(ptr null)\n'
        with self.assertRaisesRegex(ValueError, 'SELECTION_MISMATCH'):
            validate_runtime_selection(text, dict(fileWorker=False, ioCompletion=True))

    def test_duplicate_definitions_are_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SELECTION_MISMATCH'):
            validate_runtime_selection(self.module(False, True) * 2, dict(fileWorker=False, ioCompletion=True))

    def test_globals_are_part_of_selection(self):
        text = self.module(False, True) + '@sollang_file_worker_started = internal global i1 false\n'
        with self.assertRaisesRegex(ValueError, 'SELECTION_MISMATCH:sollang_file_worker_started'):
            validate_runtime_selection(text, dict(fileWorker=False, ioCompletion=True))

    def test_invalid_or_incomplete_contract_is_rejected(self):
        for spec in ({}, dict(fileWorker=1, ioCompletion=True), dict(fileWorker=True, ioCompletion=False)):
            with self.subTest(spec=spec), self.assertRaisesRegex(ValueError, 'CONTRACT_INVALID'):
                validate_runtime_selection_contract(spec)


if __name__ == '__main__':
    unittest.main()
