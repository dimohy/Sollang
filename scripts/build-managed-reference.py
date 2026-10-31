"""Build an isolated managed reference with pinned inputs and owned output."""
from pathlib import Path
import argparse
import hashlib
import json

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reusable-directory', type=Path, action='append', required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    sources = [p for p in (ROOT / 'src').rglob('*') if p.is_file()
               and p.suffix in {'.cs', '.csproj', '.props', '.targets'}
               and not {'bin', 'obj'}.intersection(p.relative_to(ROOT / 'src').parts)]
    paths = [Path(__file__), *sources, ROOT / 'syntax/sollang.grammar', ROOT / 'syntax/sollang.lexer',
             *sorted((ROOT / 'stdlib').rglob('*.slg')),
             *[p for p in ROOT.iterdir() if p.is_file()
               and (p.name.startswith('Directory.') or p.name in {'global.json', 'NuGet.Config'})]]
    inputs = {str(p.resolve()): sha(p) for p in paths}
    initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
    output.mkdir()
    with VerificationContractLease(list(map(Path, inputs))):
        result = dict(schemaVersion=1, status='running', completed=0, total=1, inputHashes=inputs,
                      scope='Managed reference build only; focused consumers pending.', claimsGoalComplete=False)
        execution = VerificationExecution(ROOT, output, result,
                                         lambda: all(sha(p) == h for p, h in inputs.items()), sha)
        error = None
        try:
            done = execution.run(['dotnet', 'build', 'src/Sollang.Compiler/Sollang.Compiler.csproj',
                                  '-c', 'Release', '--no-restore', '--nologo', '-v', 'minimal',
                                  '-o', str(output / 'compiler'), '/nodeReuse:false',
                                  '/p:UseSharedCompilation=false', '/warnaserror'], output / 'build', timeout=180)
            assert done.returncode == 0 and not done.stderr, done.stdout[-2000:] + done.stderr
            result.update(status='passed', completed=1)
        except BaseException as exc:
            error = exc
        finally:
            execution.finalize(error, cleanup=False)
        if error:
            raise error
    print(json.dumps({k: result.get(k) for k in ['status', 'completed', 'total', 'inputsStable', 'processesStopped']}))


if __name__ == '__main__':
    main()
