"""Reject misleading phase completion from reordered or incomplete live traces."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('phase_reader', Path(__file__).parent / 'probes/read-c527-phase-observation.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
OWNER = 'sollang_fn_owner'
LABELS = [f'{kind}:{OWNER}->{callee}' for callee in ('repeat', 'other', 'repeat') for kind in ('before', 'after')]
PLAN = {'markers': [{'label': label} for label in LABELS]}


class PhaseObservationTests(unittest.TestCase):
    def test_repeated_classifier_identity_keeps_distinct_ordered_invocations(self):
        result = module.summarize(PLAN, '\n'.join(LABELS) + '\n', OWNER)
        self.assertEqual((result['completed'], result['total']), (3, 3))
        self.assertTrue(result['allObservedCallsReturned'])

    def test_pending_call_does_not_count_as_returned(self):
        result = module.summarize(PLAN, '\n'.join(LABELS[:3]) + '\n', OWNER)
        self.assertEqual(result['completed'], 1)
        self.assertEqual(result['currentCall'], 'other')

    def test_incomplete_last_write_and_unrelated_owner_do_not_promote(self):
        result = module.summarize(PLAN, 'before:other->repeat\n' + LABELS[0], OWNER)
        self.assertEqual(result['completed'], 0)
        self.assertIsNone(result['currentCall'])

    def test_reordered_duplicate_and_reentered_events_are_rejected(self):
        for labels in ([LABELS[1]], [LABELS[0], LABELS[0]], LABELS + LABELS):
            with self.subTest(labels=labels), self.assertRaises(ValueError):
                module.summarize(PLAN, '\n'.join(labels) + '\n', OWNER)


if __name__ == '__main__':
    unittest.main()
