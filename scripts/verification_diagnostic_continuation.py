"""Project adapter: construct history from durable records, not an Agent's run count."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'scripts/contracts/c527-diagnostic-continuation.json'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def ref(path):
    return dict(path=str(Path(path).resolve()), sha256=sha(path))


def whole_input_history():
    rows = []
    for path in sorted((ROOT / 'artifacts/scratch').glob('resume-rootfc1a-c527-*/result.json')):
        record = json.loads(path.read_text(encoding='utf-8-sig'))
        if (record.get('status') in ('timed-out', 'cancelled', 'observed')
                and record.get('originalFixtureSources') == 111
                and record.get('optimization') == 'O1'):
            if record.get('inputsStable') is not True or record.get('processesStopped') is not True:
                raise ValueError('AS-DC-001-HISTORY-NOT-TERMINAL-STABLE')
            rows.append(dict(mode='whole-input', record=ref(path)))
    return rows


def check_c527_plan(plan_path, command, timeout_ms, output):
    config = json.loads(CONFIG.read_text())
    plan = json.loads(Path(plan_path).read_text(encoding='utf-8-sig'))
    if (plan.get('ruleId') != config['ruleId'] or plan.get('purpose') != 'diagnostic'
            or plan.get('mode') != 'whole-input' or plan.get('completionMode') != 'diagnostic-only'
            or plan.get('command', {}).get('args') != command[1:]
            or plan['command'].get('executable') != command[0]
            or plan['command'].get('timeoutMs') != timeout_ms
            or plan.get('acceptance', {}).get('timeoutMs') != config['acceptanceTimeoutMs']):
        raise ValueError('AS-DC-001-PROJECT-COMMAND-MISMATCH')
    history = whole_input_history()
    plan['priorRuns'] = history
    plan['maximumWholeInputRuns'] = len(history) + config['additionalWholeInputRuns']
    plan['evidence'].append(ref(CONFIG))
    output = Path(output)
    bound_plan = output.with_suffix('.plan.json')
    if bound_plan.exists() or output.exists():
        raise ValueError('AS-DC-001-RESULT-EXISTS')
    bound_plan.write_text(json.dumps(plan, indent=2), encoding='utf-8')
    completed = subprocess.run(['node', config['launchAdapter'], str(bound_plan), str(output), '--check'],
                               capture_output=True, text=True, check=False)
    if completed.returncode not in (0, 2):
        raise RuntimeError(f'AS-DC-001-CHECK-FAILED: {completed.stderr.strip()}')
    decision = json.loads(output.read_text())
    if not decision['allowed']:
        raise ValueError(decision['code'])
    return dict(plan=str(bound_plan), result=str(output), historyCount=len(history))
