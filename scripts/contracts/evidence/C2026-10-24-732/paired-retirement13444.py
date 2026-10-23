"""Port retained paired journals into the existing retirement-only observation contract.

No test is rerun and no completed record is changed. Original execution identities,
exit codes, timestamps and stream bytes remain authoritative. Only copied journal
stream paths change to preserve the lifecycle's owned-output boundary.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import sys

root = Path.cwd()
sys.path.insert(0, str(root / 'scripts'))
from completed_artifact_plan import assert_artifact_path, assert_output_shutdown, terminal_consumer_process

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
source = assert_artifact_path(root, args.source.resolve())
output = assert_artifact_path(root, args.output.resolve())
assert source.name == 'result.json' and not output.exists()
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest().upper()
record = read(source)
assert record['status'] == 'passed' and record['completed'] == record['total'] > 0
assert record['inputsStable'] and record['processesStopped']
assert record['inputHashesStart'] == record['inputHashesEnd']
runs = record['runs']
fixtures = sorted({x['fixture'] for x in runs})
assert len(fixtures) == record['total'] and len(runs) == len(fixtures) * 2
for fixture in fixtures:
    pair = [x for x in runs if x['fixture'] == fixture]
    assert sorted(x['compiler'] for x in pair) == ['managed', 'selfhost']
    assert pair[0]['runtimeStdout'] == pair[1]['runtimeStdout']
    for run in pair:
        assert run['buildExit'] == run['llvmAsExit'] == run['directCallExit'] == run['nativeExit'] == 0
        assert run['actualCompilerStderr'] == run['expectedCompilerStderr'] and not run['runtimeStderr']
assert_output_shutdown(root, source.parent)
output.mkdir()
journals = output / 'journals'
journals.mkdir()
pins = {str(source): sha(source), str(Path(__file__).resolve()): sha(Path(__file__).resolve()),
        str(root / 'scripts/completed_artifact_plan.py'): sha(root / 'scripts/completed_artifact_plan.py')}
processes = []
for run in runs:
    for stage in ('build', 'as', 'closure', 'native'):
        original = source.parent / f"{run['fixture']}.{run['compiler']}.{stage}.execution.json"
        row = read(original)
        assert row['exit'] == 0 and terminal_consumer_process(root, source.parent, row), original
        pins[str(original)] = sha(original)
        target = journals / original.name
        relocated = dict(row)
        relocated['sourceJournal'] = {'path': str(original), 'sha256': sha(original)}
        for field in ('stdoutPath', 'stderrPath'):
            old_stream = assert_artifact_path(root, Path(row[field]))
            new_stream = journals / old_stream.name
            shutil.copyfile(old_stream, new_stream)
            assert sha(old_stream) == sha(new_stream)
            pins[str(old_stream)] = sha(old_stream)
            pins[str(new_stream)] = sha(new_stream)
            relocated[field] = str(new_stream)
        target.write_text(json.dumps(relocated, indent=2) + '\n', encoding='utf-8')
        assert terminal_consumer_process(root, output, relocated), target
        pins[str(target)] = sha(target)
        processes.append(relocated)
for run in runs:
    if run['compiler'] == 'selfhost':
        build = read(source.parent / f"{run['fixture']}.selfhost.build.execution.json")
        compiler = Path(build['command'][0])
        product = compiler.parent / 'result.json'
        assert sha(compiler) == run['compilerSha256']
        assert record['inputHashesStart'][str(compiler)].upper() == sha(compiler)
        pins[str(compiler)] = sha(compiler)
        pins[str(product)] = sha(product)
assert all(Path(p).is_file() and sha(Path(p)) == h for p, h in pins.items())
result = dict(schemaVersion=1, status='passed',
              inputHashes=pins, inputsStable=True, processesStopped=True,
              processes=processes,
              recordType='retained-paired-journal-retirement-observation',
              originalPairResult=str(source), originalPairResultSha256=sha(source),
              observedPairs=record['completed'], observedSideExecutions=len(runs),
              observedTerminalProcessJournals=len(processes),
              scope='Retirement-only observation of unchanged historical paired results. '
                    'Copied original journal/log bytes with explicit stream-path relocation. '
                    'No new execution, current-source acceptance or language test completion.',
              claimsCompilerTestsPassed=False, claimsGoalComplete=False)
(output / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(status='passed', historicalPairs=len(fixtures), verifiedTerminalJournals=len(processes),
                      newCompilerExecutions=0, originalRecordsChanged=False)))
