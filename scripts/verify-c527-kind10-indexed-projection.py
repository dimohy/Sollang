#!/usr/bin/env python3
"""Check method-result field indexing against the C# compiler."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-kind10-indexed-source-comparison-20260929-01.json"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
PROBE_SOURCE = ROOT / "artifacts/scratch/c527-kind10-indexed-shape-probe-20260929-01.slg"
POSITIVE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-positive.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-kind10-indexed-negative.slg"
EXPECTED_ERROR = (
    "sollang: semantic error at 15:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)
EXPECTED_PROBE = (
    "node=0 kind=7 parent=-1 operand0=1 indexed=-1 member=-1 callMember=20 target=-1 invalid=20\n"
    "node=1 kind=5 parent=0 operand0=2 indexed=-1 member=-1 callMember=28 target=-1 invalid=-1\n"
    "node=2 kind=10 parent=1 operand0=3 indexed=-1 member=-1 callMember=-1 target=0 invalid=-1\n"
    "node=3 kind=1 parent=2 operand0=-1 indexed=-1 member=-1 callMember=-1 target=-1 invalid=-1\n"
    "node=4 kind=0 parent=0 operand0=-1 indexed=-1 member=-1 callMember=-1 target=-1 invalid=-1\n"
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    completed = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(completed.stdout)
    (output / f"{label}.stderr.txt").write_bytes(completed.stderr)
    return {
        "exitCode": completed.returncode,
        "stdout": completed.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
        "stderr": completed.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "probe", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    probe = args.probe.resolve(strict=True)
    build_result_path = args.build_result.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    build_result = json.loads(build_result_path.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    managed_source = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
    if (build_result["status"] != "passed" or not build_result["inputsStable"]
            or build_result["compilerSha256"] != sha(selfhost)
            or comparison["status"] != "passed"
            or comparison["inputSha256"][str(managed_source)] != sha(managed_source)):
        raise ValueError("compiler or source-comparison evidence is invalid")
    facts = FACTS.read_text(encoding="utf-8")
    inference = INFERENCE.read_text(encoding="utf-8")
    preparation = PREPARATION.read_text(encoding="utf-8")
    if ("public preIrIndexedResultTypeId prepared:" not in facts
            or "expressionTypeIds.preIrIndexedResultTypeId(" not in inference
            or "member.kind == 7 and member.operand0 >= 0" not in inference
            or "node.kind == 7 and nodeIndex! < (memberTypes -> len)" not in inference):
        raise ValueError("indexed pre-IR route changed")
    phases = [
        "prepared -> expressionTypeIds.resolveContext => recursiveTypes!",
        "prepared -> interpolationInference.preIrFlowCallTargets(recursiveTypes!)",
        "prepared -> interpolationInference.preIrInvalidDirectDisplayTypeByNode(recursiveTypes!, semanticInterpolationCallTargets)",
        "prepared -> lowerPreparedIr(recursiveTypes!, supportsComputePool)",
    ]
    positions = [preparation.find(part) for part in phases]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        raise ValueError("pre-IR source order changed")
    inputs = [managed, selfhost, probe, build_result_path, COMPARISON, managed_source,
              FACTS, INFERENCE, PREPARATION, PROBE_SOURCE, POSITIVE, NEGATIVE,
              Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {"preIrProbe": run([str(probe)], output, "preir-probe")}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[name] = {}
        for case, source in (("positive", POSITIVE), ("negative", NEGATIVE)):
            executable = output / f"{name}-{case}.exe"
            command = [str(compiler), "build", str(source), "-o", str(executable),
                       "--target", "windows-x64"]
            if name == "selfhost":
                command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                            "--stdlib", str(ROOT / "stdlib"), "-O1"]
            runs[name][case] = run(command, output, f"{name}-{case}-build")
            runs[name][case]["executableExists"] = executable.is_file()
            if case == "positive" and executable.is_file():
                runs[name]["native"] = run([str(executable)], output, f"{name}-native")
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and runs["preIrProbe"] == {
        "exitCode": 0, "stdout": EXPECTED_PROBE, "stderr": ""}
    for name in ("managed", "selfhost"):
        passed = passed and (
            runs[name]["positive"]["exitCode"] == 0
            and runs[name]["positive"]["executableExists"]
            and runs[name]["native"] == {"exitCode": 0, "stdout": "value=5\n", "stderr": ""}
            and runs[name]["negative"]["exitCode"] != 0
            and not runs[name]["negative"]["executableExists"]
            and runs[name]["negative"]["stderr"] == EXPECTED_ERROR)
    record = {"schemaVersion": 1, "unit": "C527 method-result indexed projection",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
