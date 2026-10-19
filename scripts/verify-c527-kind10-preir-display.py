#!/usr/bin/env python3
"""Verify method-result field display decisions before Typed IR and paired output."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-kind10-receiver-source-comparison-20260929-01.json"
BOUNDARY = ROOT / "artifacts/scratch/c527-kind10-preir-boundary-20260929-01.json"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
PROBE_SOURCE = ROOT / "artifacts/scratch/c527-kind10-preir-display-probe-20260929-01.slg"
CASES = {
    "methodInt": [ROOT / "artifacts/scratch/c527-kind10-call-receiver-positive-20260929-01.slg"],
    "methodFloat": [ROOT / "artifacts/scratch/c527-kind10-call-receiver-candidate-20260929-01.slg"],
    "methodArity": [ROOT / "scripts/probes/interpolation/c527-kind10-method-arity-negative.slg"],
    "nestedFloat": [ROOT / "scripts/probes/interpolation/c527-nested-member-display-negative.slg"],
    "privateField": [ROOT / "scripts/probes/interpolation/c527-nested-private-intermediate.slg",
                     ROOT / "scripts/probes/interpolation/sample/nested_private.slg"],
}
EXPECTED_ERRORS = {
    "methodFloat": "sollang: semantic error at 15:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "methodArity": "sollang: semantic error at 10:5: [module '<main>'] function 'make' expects 1 additional argument(s)\n",
    "nestedFloat": "sollang: semantic error at 12:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "privateField": "sollang: semantic error at 1:1: [module '<main>'] cannot read private field 'hidden' of struct 'sample.nested_private.Wrapper' outside module 'sample.nested_private'; use its public factory or public instance methods\n",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(result.stdout)
    (output / f"{label}.stderr.txt").write_bytes(result.stderr)
    return {
        "exitCode": result.returncode,
        "stdout": result.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
        "stderr": result.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "probe", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    probe = args.probe.resolve(strict=True)
    build_result = json.loads(args.build_result.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    boundary = json.loads(BOUNDARY.read_text(encoding="utf-8"))
    managed_source = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
    if (build_result["status"] != "passed" or not build_result["inputsStable"]
            or build_result["compilerSha256"] != sha(selfhost)):
        raise ValueError("selfhost compiler build is invalid or unstable")
    if (comparison["status"] != "passed" or boundary["status"] != "passed"
            or comparison["inputSha256"][str(managed_source)] != sha(managed_source)):
        raise ValueError("C# first and source comparison evidence is invalid")
    inference = INFERENCE.read_text(encoding="utf-8")
    preparation = PREPARATION.read_text(encoding="utf-8")
    facts = FACTS.read_text(encoding="utf-8")
    if ("public preIrCallMemberTypeByNode prepared:" not in inference
            or "target.status == 0" not in inference
            or "method.kind == 31 -> if { method.typeNode => returnTypeNode! }" not in inference
            or "method.kind == 7 -> if { method.secondaryTypeNode => returnTypeNode! }" not in inference
            or "expressionTypeIds.accessibleMemberFieldType" not in inference
            or "public accessibleMemberFieldType prepared:" not in facts):
        raise ValueError("pre-IR method and field decisions changed")
    order = [
        "prepared -> expressionTypeIds.resolveContext => recursiveTypes!",
        "prepared -> interpolationInference.preIrFlowCallTargets(recursiveTypes!)",
        "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode(recursiveTypes!, semanticInterpolationCallTargets)",
        "prepared -> lowerPreparedIr(recursiveTypes!, supportsComputePool)",
    ]
    positions = [preparation.find(part) for part in order]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        raise ValueError("pre-IR method-to-member decision order changed")
    inputs = [managed, selfhost, probe, args.build_result.resolve(), COMPARISON,
              BOUNDARY, FACTS, INFERENCE, PREPARATION, PROBE_SOURCE,
              Path(__file__).resolve()]
    for sources in CASES.values():
        inputs.extend(sources)
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {"preIrProbe": run([str(probe)], output, "preir-probe")}
    for compiler_name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[compiler_name] = {}
        for case, sources in CASES.items():
            executable = output / f"{compiler_name}-{case}.exe"
            command = [str(compiler), "build", *(str(path) for path in sources),
                       "-o", str(executable), "--target", "windows-x64"]
            if compiler_name == "selfhost":
                command.extend(["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                                "--stdlib", str(ROOT / "stdlib"), "-O1"])
            runs[compiler_name][case] = run(command, output, f"{compiler_name}-{case}-build")
            runs[compiler_name][case]["executableExists"] = executable.is_file()
            if case == "methodInt" and executable.is_file():
                runs[compiler_name]["methodIntNative"] = run(
                    [str(executable)], output, f"{compiler_name}-methodInt-native")
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and runs["preIrProbe"] == {
        "exitCode": 0,
        "stdout": "node=0 member=-1 callMember=20 invalid=20\ntarget=0 kind=31 secondary=-1 typeNode=12\n",
        "stderr": ""}
    for compiler_name in ("managed", "selfhost"):
        cases = runs[compiler_name]
        positive = cases["methodInt"]
        passed = passed and (positive["exitCode"] == 0 and positive["stderr"] == ""
                             and positive["executableExists"] and "Wrote " in positive["stdout"]
                             and cases.get("methodIntNative") == {
                                 "exitCode": 0, "stdout": "value=5\n", "stderr": ""})
        for case, expected in EXPECTED_ERRORS.items():
            passed = passed and cases[case] == {
                "exitCode": 1, "stdout": "", "stderr": expected, "executableExists": False}
    record = {
        "schemaVersion": 1,
        "unit": "C527 kind-10 instance-method result pre-IR type",
        "status": "passed" if passed else "failed",
        "completed": int(passed),
        "total": 1,
        "inputStable": stable,
        "inputSha256": start,
        "sourceComparison": str(COMPARISON),
        "methodBoundary": str(BOUNDARY),
        "selfhostBuildResult": str(args.build_result.resolve()),
        "runs": runs,
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": "0/7",
    }
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"focused verification failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: method pre-IR type and five paired cases")


if __name__ == "__main__":
    main()
