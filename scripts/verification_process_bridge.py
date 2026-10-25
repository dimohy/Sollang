"""Expose the existing owned-process supervisor to non-Python verification tools.

A stopped command is an observation, including nonzero compiler exits. The
calling verifier owns its oracle; this bridge never marks a test as passed.
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

from completed_artifact_plan import assert_artifact_path
from focused_verification_output import sha
from verification_execution import VerificationExecution


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--timeout-seconds', type=float, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or args.timeout_seconds <= 0:
        parser.error('a command and a positive timeout are required')
    executable = shutil.which(command[0])
    if executable is None:
        raise FileNotFoundError('VERIFICATION_BRIDGE_EXECUTABLE_MISSING: ' + command[0])
    command[0] = str(Path(executable).resolve())
    repo = args.repo.resolve()
    output = assert_artifact_path(repo, args.output)
    inputs = [Path(command[0]), Path(__file__), Path(__file__).with_name('verification_execution.py')]
    pins = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True, exist_ok=False)
    result = dict(schemaVersion=1, status='running', inputHashes=pins,
                  claimsTestPassed=False, claimsGoalComplete=False)
    execution = VerificationExecution(repo, output, result,
        lambda: all(Path(path).is_file() and sha(path) == digest for path, digest in pins.items()), sha)
    error = None
    try:
        observed = execution.run(command, output / 'command', timeout=args.timeout_seconds)
        result.update(status='observed-not-qualified', programExit=observed.returncode)
    except BaseException as failure:
        error = failure
    finally:
        execution.finalize(error, cleanup=False)
    accepted = (error is None and result.get('inputsStable') is True
                and result.get('processesStopped') is True)
    print(json.dumps(dict(record=str(output / 'result.json'), executionObserved=accepted)))
    return 0 if accepted else 1


if __name__ == '__main__':
    sys.exit(main())
