"""Explicitly build the shared linker tool and retain its pinned consumer proof."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from contextlib import ExitStack

from completed_artifact_plan import initialize_output
from verification_contract_lease import VerificationContractLease
from verification_execution import VerificationExecution
from verification_fingerprints import unique_input_files

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reusable-directory', type=Path, action='append')
    args = parser.parse_args()
    output = args.output.resolve()
    project = ROOT / 'scripts/tools/CompilerLinkBridge/CompilerLinkBridge.csproj'
    dotnet = shutil.which('dotnet')
    if dotnet is None:
        raise ValueError('COMPILER_LINK_BRIDGE_DOTNET_MISSING')
    paths = unique_input_files([project, project.with_name('Program.cs'), ROOT / 'global.json',
        Path(__file__), ROOT / 'scripts/verification_execution.py',
        ROOT / 'scripts/verification_contract_lease.py', ROOT / 'scripts/verification_fingerprints.py',
        Path(dotnet), *[ROOT / name for name in ('Directory.Build.props', 'Directory.Build.targets')
                      if (ROOT / name).is_file()]])
    sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    with ExitStack() as leases:
        leases.enter_context(VerificationContractLease(paths))
        initialize_output(ROOT, output, reusable_directories=args.reusable_directory)
        output.mkdir(parents=True, exist_ok=False)
        # Preserve old project-local obj/bin products. Build a byte-identical,
        # exclusive source projection so SDK globbing cannot admit their .cs files.
        projection = output / 'project'
        projection.mkdir()
        copies = []
        for source in (project, project.with_name('Program.cs')):
            copy = projection / source.name
            copy.write_bytes(source.read_bytes())
            copies.append(copy)
        leases.enter_context(VerificationContractLease(copies))
        paths += copies
        pins = {str(path): sha(path) for path in paths}
        stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in paths)
        product = output / 'bin/CompilerLinkBridge.dll'
        result = dict(schemaVersion=1, status='running', completed=0, total=1, inputHashes=pins,
                      scope='Explicit pinned compiler link bridge build', bridgeProduct=str(product),
                      claimsGoalComplete=False, retainedFor='explicit-link-tool-consumers')
        execution = VerificationExecution(ROOT, output, result, stable, sha)
        execution.save()
        error = None
        try:
            build = execution.run([dotnet, 'build', str(projection / project.name), '-c', 'Release', '-o', str(product.parent),
                '-p:BaseIntermediateOutputPath=' + str(output / 'obj') + '/',
                '-p:MSBuildProjectExtensionsPath=' + str(output / 'obj') + '/'], output / 'build', timeout=180)
            if build.returncode != 0 or not product.is_file():
                raise ValueError('COMPILER_LINK_BRIDGE_BUILD_FAILED: ' + build.stderr)
            result.update(status='passed', completed=1, bridgeSha256=sha(product))
        except (Exception, KeyboardInterrupt) as caught:
            error = caught
            raise
        finally:
            # The executable is an input of pending policy/link checks.
            execution.finalize(error, cleanup=False)
        if result['status'] != 'passed':
            raise ValueError(result['failure'])
    print(json.dumps(dict(status=result['status'], completed=1, total=1,
                          proof=str(output / 'result.json'), bridgeProduct=str(product))))


if __name__ == '__main__':
    main()
