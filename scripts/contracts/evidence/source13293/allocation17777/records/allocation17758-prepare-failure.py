from pathlib import Path
import json
b=Path('artifacts/scratch/resume-20261006-owner-continuation22')
source=b/'allocation17737-failure.py';text=source.read_text(encoding='utf-8')
text=text.replace("p.add_argument('--expected-exit',type=int);a=p.parse_args()", "p.add_argument('--contract',type=Path,required=True);a=p.parse_args();contract=json.loads(a.contract.read_text(encoding='utf-8'));case=contract['cases'][0]")
text=text.replace("inputs=[source,clang,", "inputs=[a.contract.resolve(),source,clang,")
text=text.replace("assert a.expected_exit is None or run.returncode==a.expected_exit", "assert code==(case['expectedRuntimeExit'] & 0xffffffff)")
text=text.replace("assert run.stderr.strip()=='main:bb_alloc_fail3'", "assert run.stderr.strip()==case['stderr'], 'ALLOCATION_FAILURE_DIAGNOSTIC_MISMATCH: '+repr(run.stderr)")
text=text.replace("id='original42-null-allocation-traps',status='passed',passed=True,runExit=run.returncode", "id=case['id'],status='passed',passed=True,buildExit=0,runExit=run.returncode")
assert '--expected-exit' not in text and 'a.expected_exit' not in text
(b/'allocation17758-failure.py').write_text(text,encoding='utf-8')
contract=dict(schemaVersion=1,scope='Original42 managed-reference allocation failure: exact trap status and exact diagnostic. Does not replace original source or normal-output/LLVM expectations.',allocationBytes=4800,expectedSource='examples/regression/42-fixed-array-placement.slg',referenceObservation=(b/'allocation17740-managed-failure/result.json').as_posix(),cases=[dict(id='original42-null-allocation-traps',exit=0,expectedRuntimeExit=-1073741795,stderr='main:bb_alloc_fail3')],budget=dict(caseSeconds=180,retryCount=0))
(b/'allocation17758-failure-contract.json').write_text(json.dumps(contract,indent=2)+'\n',encoding='utf-8')
print('reused existing injection controller with a pinned runtime exit/diagnostic contract')
