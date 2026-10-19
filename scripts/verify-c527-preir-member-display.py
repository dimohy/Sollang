#!/usr/bin/env python3
"""Verify a direct member display decision before IR and paired compiler behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POSITIVE = ROOT / "scripts/probes/interpolation/c527-direct-member-display-positive.slg"
NEGATIVE = ROOT / "scripts/probes/interpolation/c527-direct-member-display-negative.slg"
PRIVATE = ROOT / "examples/regression/diagnostics/2060-interpolated-private-field.slg"
PRIVATE_DEPENDENCY = ROOT / "examples/regression/diagnostics/sample/opaque_value.slg"
SOURCE_ORDER = ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-01.json"
PREIR_SOURCE = ROOT / "artifacts/scratch/c527-preir-member-display-probe-20260929-01.slg"
EXPECTED_FLOAT = (
    "sollang: semantic error at 8:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(label: str, command: list[str], output: Path) -> dict:
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
    parser.add_argument("--managed", required=True, type=Path)
    parser.add_argument("--selfhost", required=True, type=Path)
    parser.add_argument("--build-result", required=True, type=Path)
    parser.add_argument("--probe", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    probe = args.probe.resolve(strict=True)
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    build_result = json.loads(args.build_result.read_text(encoding="utf-8"))
    source_order = json.loads(SOURCE_ORDER.read_text(encoding="utf-8"))
    if build_result["status"] != "passed" or not build_result["inputsStable"]:
        raise ValueError("selfhost compiler build did not pass with stable inputs")
    if build_result["compilerSha256"] != digest(selfhost):
        raise ValueError("selfhost compiler hash differs from build result")
    if source_order["status"] != "passed":
        raise ValueError("source order proof did not pass")
    for relative, expected in source_order["sourceSha256"].items():
        if digest(ROOT / relative) != expected:
            raise ValueError(f"source order proof drifted: {relative}")

    inputs = [managed, selfhost, probe, POSITIVE, NEGATIVE, PRIVATE, PRIVATE_DEPENDENCY,
              SOURCE_ORDER, PREIR_SOURCE, Path(__file__).resolve()]
    starting_hashes = {str(path): digest(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {"preIrProbe": run("preir-probe", [str(probe)], output)}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        results = {}
        for case, sources in (("positive", [POSITIVE]), ("negative", [NEGATIVE]),
                              ("private", [PRIVATE, PRIVATE_DEPENDENCY])):
            executable = output / f"{name}-{case}.exe"
            command = [str(compiler), "build", *(str(path) for path in sources),
                       "-o", str(executable), "--target", "windows-x64"]
            if name == "selfhost":
                command.extend(["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                                "-O1", "--stdlib", str(ROOT / "stdlib")])
            results[case] = run(f"{name}-{case}-build", command, output)
            results[case]["executableExists"] = executable.is_file()
            if case == "positive" and executable.is_file():
                results["positiveNative"] = run(f"{name}-positive-native", [str(executable)], output)
        runs[name] = results

    stable = starting_hashes == {str(path): digest(path) for path in inputs}
    passed = stable and runs["preIrProbe"] == {
        "exitCode": 0, "stdout": "kind=5 invalid=20\nkind=5 invalid=-1\n", "stderr": ""
    }
    for name in ("managed", "selfhost"):
        result = runs[name]
        passed = passed and (
            result["positive"]["exitCode"] == 0
            and result["positive"]["stderr"] == ""
            and result["positive"]["executableExists"]
            and result.get("positiveNative") == {"exitCode": 0, "stdout": "value=true\n", "stderr": ""}
            and result["negative"]["exitCode"] == 1
            and result["negative"]["stderr"] == EXPECTED_FLOAT
            and not result["negative"]["executableExists"]
            and result["private"]["exitCode"] == 1
            and "private" in result["private"]["stderr"].lower()
            and not result["private"]["executableExists"]
        )
    passed = passed and runs["managed"]["private"]["stderr"] == runs["selfhost"]["private"]["stderr"]
    record = {
        "schemaVersion": 1,
        "unit": "C527-direct-lexical-member-displayability-before-Typed-IR",
        "status": "passed" if passed else "failed",
        "completed": 1 if passed else 0,
        "total": 1,
        "inputStable": stable,
        "inputSha256": starting_hashes,
        "selfhostBuildResult": str(args.build_result.resolve()),
        "sourceOrderProof": str(SOURCE_ORDER),
        "runs": runs,
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": "0/7",
    }
    (output / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"focused C527 verification failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: pre-IR probe, paired positive/negative/private controls")


if __name__ == "__main__":
    main()
