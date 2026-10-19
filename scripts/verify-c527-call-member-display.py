#!/usr/bin/env python3
"""Check call-result field pre-IR type and C# versus SLG focused behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-call-member-source-comparison-20260929-01.json"
FACTS = ROOT / "selfhost/semantic/expression_type_ids.slg"
PROBE_SOURCE = ROOT / "artifacts/scratch/c527-call-member-preir-probe-20260929-01.slg"
CASES = {
    "callInt": [ROOT / "scripts/probes/interpolation/c527-call-result-member-display-positive.slg"],
    "callFloat": [ROOT / "scripts/probes/interpolation/c527-call-result-member-display-negative.slg"],
    "indexedFloat": [ROOT / "scripts/probes/interpolation/c527-indexed-member-display-negative.slg"],
    "nestedFloat": [ROOT / "scripts/probes/interpolation/c527-nested-member-display-negative.slg"],
    "private": [ROOT / "scripts/probes/interpolation/c527-nested-private-intermediate.slg",
                ROOT / "scripts/probes/interpolation/sample/nested_private.slg"],
}
NEGATIVE = {
    "callFloat": "sollang: semantic error at 8:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "indexedFloat": "sollang: semantic error at 7:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "nestedFloat": "sollang: semantic error at 12:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "private": "sollang: semantic error at 1:1: [module '<main>'] cannot read private field 'hidden' of struct 'sample.nested_private.Wrapper' outside module 'sample.nested_private'; use its public factory or public instance methods\n",
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
    if build_result["status"] != "passed" or not build_result["inputsStable"]:
        raise ValueError("selfhost compiler build did not pass with stable inputs")
    if build_result["compilerSha256"] != sha(selfhost):
        raise ValueError("selfhost compiler hash differs from build result")
    managed_source = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
    if comparison["status"] != "passed" or comparison["inputSha256"][str(managed_source)] != sha(managed_source):
        raise ValueError("C# source comparison is invalid or stale")
    source = FACTS.read_text(encoding="utf-8")
    if source.count("public preIrInterpolationReceiverTypeId prepared:") != 1:
        raise ValueError("shared receiver type resolver changed")
    if source.count("preIrInterpolationReceiverTypeId(references!") != 3:
        raise ValueError("member and index receivers no longer share type resolution")
    inputs = [managed, selfhost, probe, FACTS, PROBE_SOURCE, COMPARISON,
              args.build_result.resolve(), Path(__file__).resolve()]
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
            if case == "callInt" and executable.is_file():
                runs[compiler_name]["callIntNative"] = run(
                    [str(executable)], output, f"{compiler_name}-callInt-native")
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable and runs["preIrProbe"] == {
        "exitCode": 0,
        "stdout": "node=0 kind=5 parent=-1 member=20 invalid=20\nnode=1 kind=8 parent=0 member=-1 invalid=-1\n",
        "stderr": "",
    }
    for compiler_name in ("managed", "selfhost"):
        cases = runs[compiler_name]
        positive = cases["callInt"]
        passed = passed and (positive["exitCode"] == 0 and positive["stderr"] == ""
                             and positive["executableExists"] and "Wrote " in positive["stdout"]
                             and cases.get("callIntNative") == {"exitCode": 0, "stdout": "value=5\n", "stderr": ""})
        for case, expected in NEGATIVE.items():
            passed = passed and cases[case] == {
                "exitCode": 1, "stdout": "", "stderr": expected, "executableExists": False}
    result = {
        "schemaVersion": 1,
        "unit": "C527 call-result member pre-IR type and displayability",
        "status": "passed" if passed else "failed",
        "completed": int(passed),
        "total": 1,
        "inputStable": stable,
        "inputSha256": start,
        "sourceComparison": str(COMPARISON),
        "selfhostBuildResult": str(args.build_result.resolve()),
        "runs": runs,
        "structuralPhasesClosed": "0/7",
        "fullPreIrExpressionClosure": False,
    }
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"focused verification failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: pre-IR call result and five paired cases")


if __name__ == "__main__":
    main()
