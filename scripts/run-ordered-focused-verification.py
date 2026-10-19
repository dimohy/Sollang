"""Require exact paired prerequisite coverage before starting a focused check."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PROJECTION = Path(__file__).with_name("verify-focused-case-projection.py")
SPEC = importlib.util.spec_from_file_location("focused_projection", PROJECTION)
projection = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(projection)


def validate_runner_contract(plan):
    runner = plan.get('runner')
    if runner not in ('numeric', 'context-suite', 'native-fixtures'):
        raise ValueError('ORDERED_FOCUSED_RUNNER_UNKNOWN')
    # These fields are consumed only by the native fixture runner. Accepting
    # them on another runner would silently replace the declared source and
    # timeout contract with that tool's defaults.
    native_fields = {'fixture', 'expectedSources', 'timeoutMilliseconds'}
    if runner != 'native-fixtures' and native_fields.intersection(plan):
        raise ValueError('ORDERED_FOCUSED_RUNNER_CONTRACT_MISMATCH')
    if runner == 'native-fixtures' and (
            type(plan.get('timeoutMilliseconds')) is not int
            or plan['timeoutMilliseconds'] != 1200000
            or type(plan.get('expectedSources')) is not int
            or plan['expectedSources'] != 111
            or not isinstance(plan.get('fixture'), str) or not plan['fixture']):
        raise ValueError('ORDERED_NATIVE_FIXTURE_CONTRACT_INVALID')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    plan_path, record_path = args.plan.resolve(), args.record.resolve()
    if record_path.exists() or not record_path.is_relative_to(ROOT / "artifacts"):
        raise ValueError("ORDERED_FOCUSED_FRESH_RECORD_REQUIRED")
    plan = json.loads(plan_path.read_text(encoding="utf-8-sig"))
    validate_runner_contract(plan)
    prerequisites = plan.get("prerequisites", [])
    if not prerequisites or len({row["id"] for row in prerequisites}) != len(prerequisites):
        raise ValueError("ORDERED_FOCUSED_PREREQUISITES_EMPTY_OR_DUPLICATED")
    checked = []
    inputs = [plan_path, Path(__file__).resolve(), PROJECTION]
    for row in prerequisites:
        paths = [(ROOT / row[key]).resolve() for key in ("contract", "paired", "managed")]
        result = projection.verify(*paths)
        if result["completed"] != row["expectedCases"]:
            raise ValueError("ORDERED_FOCUSED_PREREQUISITE_SCOPE_MISMATCH: " + row["id"])
        checked.append({"id": row["id"], "completed": result["completed"], "total": result["total"]})
        inputs.extend(paths)
    for check in plan.get("sourceChecks", []):
        script = (ROOT / check["script"]).resolve()
        if not script.is_relative_to(ROOT / "scripts"):
            raise ValueError("ORDERED_FOCUSED_SOURCE_CHECK_BOUNDARY_INVALID")
        subprocess.run([sys.executable, str(script), *check["arguments"]], cwd=ROOT, check=True)
        inputs.append(script)
    output = (ROOT / plan["output"]).resolve()
    if output.exists() or not output.is_relative_to(ROOT / "artifacts"):
        raise ValueError("ORDERED_FOCUSED_FRESH_OUTPUT_REQUIRED")
    runner = plan["runner"]
    if runner == "numeric":
        command = [sys.executable, str(ROOT / "scripts/verify-c385-preir-call-numeric.py"), "--mode", "paired"]
        for key, option in (("contract", "--contract"), ("build", "--build"),
                            ("managedProof", "--managed-proof"), ("sourceComparison", "--source-comparison"),
                            ("formatter", "--format-compiler")):
            command.extend([option, str((ROOT / plan[key]).resolve())])
        command.extend(["--output", str(output), "--artifact-cleanup", "execute"])
    elif runner == "context-suite":
        context_runner = ROOT / "scripts/run-context-fixture-pairs.ps1"
        context_plan = (ROOT / plan["contextPlan"]).resolve()
        inputs.extend([context_runner, context_plan])
        command = ["pwsh", "-NoProfile", "-File", str(context_runner),
                   "-PlanPath", context_plan.relative_to(ROOT).as_posix(), "-OutputDirectory", str(output)]
        subprocess.run([*command, "-Check"], cwd=ROOT, check=True)
    elif runner == "native-fixtures":
        from verification_source_proof import current_build_inputs
        fixture = plan['fixture']
        manifest = ROOT / f'examples/regression/expected/{fixture}.sources.txt'
        expected = ROOT / f'examples/regression/expected/{fixture}.stdout.txt'
        managed_proof = (ROOT / plan['managedProof']).resolve()
        build = (ROOT / plan['build']).resolve()
        build_record = build / 'result.json'
        proof = json.loads(managed_proof.read_text(encoding='utf-8-sig'))
        compiler_record = json.loads(build_record.read_text(encoding='utf-8-sig'))
        current_build_inputs(ROOT, compiler_record)
        if (plan['timeoutMilliseconds'] != 1200000 or plan['expectedSources'] != 111
                or len(manifest.read_text().splitlines()) != plan['expectedSources']
                or proof.get('status') != 'passed' or proof.get('mode') != 'managed'
                or proof.get('completed') != 1 or proof.get('total') != 1
                or not proof.get('inputsStable') or not proof.get('processesStopped')
                or len(proof.get('cases', [])) != 1 or proof['cases'][0].get('id') != fixture
                or proof['cases'][0].get('runStdout') != expected.read_text().strip()):
            raise ValueError('ORDERED_NATIVE_FIXTURE_CONTRACT_INVALID')
        for name, digest in proof['inputHashes'].items():
            if hashlib.sha256(Path(name).read_bytes()).hexdigest().upper() != digest:
                raise ValueError('ORDERED_NATIVE_FIXTURE_MANAGED_INPUT_DRIFT: ' + name)
        native_runner = ROOT / 'scripts/verify-compiler-paired-native-fixtures.ps1'
        managed = ROOT / 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
        inputs.extend([native_runner, managed_proof, build_record, manifest, expected])
        command = ['pwsh', '-NoProfile', '-File', str(native_runner), '-ManagedCompiler', str(managed),
                   '-SelfhostCompiler', str(build / 'compiler.exe'), '-Fixture', fixture,
                   '-OutputDirectory', str(output), '-TimeoutMilliseconds', str(plan['timeoutMilliseconds']),
                   '-AdditionalInput', str(plan_path)]
    else:
        raise ValueError("ORDERED_FOCUSED_UNKNOWN_RUNNER")
    record = {"schemaVersion": 1, "status": "prerequisites-passed", "prerequisites": checked,
              "phase": plan["id"], "phaseStatus": "running", "command": command,
              "inputHashes": {str(path): hashlib.sha256(path.read_bytes()).hexdigest().upper() for path in inputs},
              "fullUnitClosure": False}
    record_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    code = subprocess.call(command, cwd=ROOT)
    record.update(phaseStatus="passed" if code == 0 else "failed", phaseExit=code,
                  executionResult=str(output / "result.json"))
    record_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
