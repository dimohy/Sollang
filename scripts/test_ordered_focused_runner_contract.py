"""Reject discarded execution settings before prerequisite work or spawning."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).with_name('run-ordered-focused-verification.py')
spec = importlib.util.spec_from_file_location('ordered_runner_contract', PATH)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerContractTests(unittest.TestCase):
    def test_supported_normal_routes(self):
        for plan in [dict(runner='numeric'), dict(runner='context-suite'),
                     dict(runner='native-fixtures',fixture='2489-preir-propagated-display-invariant',
                          expectedSources=111,timeoutMilliseconds=1200000)]:
            runner.validate_runner_contract(plan)

    def test_native_contract_cannot_be_discarded_by_another_route(self):
        for kind in ['numeric','context-suite']:
            for field,value in [('fixture','2489-preir-propagated-display-invariant'),
                                ('expectedSources',111),('timeoutMilliseconds',1200000)]:
                with self.assertRaisesRegex(ValueError,'RUNNER_CONTRACT_MISMATCH'):
                    runner.validate_runner_contract(dict(runner=kind,**{field:value}))

    def test_timeout_and_input_scope_remain_frozen(self):
        valid = dict(runner='native-fixtures',fixture='2489-preir-propagated-display-invariant',
                     expectedSources=111,timeoutMilliseconds=1200000)
        for field,value in [('timeoutMilliseconds',180000),('timeoutMilliseconds',1200001),
                            ('timeoutMilliseconds',True),('expectedSources',110),('expectedSources',True)]:
            with self.assertRaisesRegex(ValueError,'CONTRACT_INVALID'):
                runner.validate_runner_contract({**valid,field:value})

    def test_bad_route_is_rejected_before_child_or_prerequisite_work(self):
        with tempfile.TemporaryDirectory(dir=runner.ROOT/'artifacts/scratch') as folder:
            plan_path = Path(folder)/'plan.json'
            plan_path.write_text(json.dumps(dict(runner='numeric',timeoutMilliseconds=1200000)),encoding='utf-8')
            with patch.object(sys,'argv',['runner','--plan',str(plan_path),'--record',str(Path(folder)/'result.json')]), \
                 patch.object(runner.subprocess,'run') as child:
                with self.assertRaisesRegex(ValueError,'RUNNER_CONTRACT_MISMATCH'):
                    runner.main()
                child.assert_not_called()


if __name__=='__main__':
    unittest.main()
