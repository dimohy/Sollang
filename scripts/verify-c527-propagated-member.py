#!/usr/bin/env python3
"""Verify propagated Result member behavior and retained diagnostics."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-propagated-member-source-comparison-20260929-01.json"
MANAGED_FIRST = ROOT / "artifacts/scratch/c527-propagated-result-member-managed-first-20260929-01.json"
INFERENCE = ROOT / "selfhost/semantic/interpolation_inference.slg"
PREPARATION = ROOT / "selfhost/llvm/text/context_prepare.slg"
CASES = {
    "positive": (ROOT / "scripts/probes/interpolation/c527-propagated-result-member-positive.slg", ""),
    "float": (ROOT / "scripts/probes/interpolation/c527-propagated-result-member-float.slg",
              "sollang: semantic error at 8:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
    "mismatch": (ROOT / "scripts/probes/interpolation/c527-propagated-result-member-error-mismatch.slg",
                 "sollang: semantic error at 1:13: [module '<main>'] '?' error type Text does not match function error type Int\n"),
    "simpleMismatch": (ROOT / "examples/regression/diagnostics/2083-interpolated-result-propagation-error-mismatch.slg",
                       "sollang: semantic error at 1:12: [module '<main>'] '?' error type Text does not match function error type Int\n"),
    "invalidIndex": (ROOT / "scripts/probes/interpolation/c527-kind10-indexed-invalid-bool.slg",
                     "sollang: semantic error at 1:24: [module '<main>'] index must be Int\n"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(result.stdout)
    (output / f"{label}.stderr.txt").write_bytes(result.stderr)
    return {"exitCode": result.returncode,
            "stdout": result.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
            "stderr": result.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")}


def main() -> None:
    parser = argparse.ArgumentParser()
    for name in ("managed", "selfhost", "build-result", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    build_path = args.build_result.resolve(strict=True)
    build = json.loads(build_path.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    first = json.loads(MANAGED_FIRST.read_text(encoding="utf-8"))
    if (build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(selfhost)
            or comparison["status"] != "passed" or first["status"] != "passed"
            or comparison["inputSha256"][str(MANAGED_FIRST)] != sha(MANAGED_FIRST)):
        raise ValueError("build or source-comparison evidence is invalid")
    contents = INFERENCE.read_text(encoding="utf-8")
    preparation = PREPARATION.read_text(encoding="utf-8")
    if ("propagationDecisions: ref [ResultPropagationDecision; ~]" not in contents
            or "rootHasPriorError!" not in contents
            or preparation.index("interpolationInference.resultPropagationDecisionByNode(")
            > preparation.index("interpolationInference.invalidDisplayTypeByNode(")):
        raise ValueError("Result propagation and display source order changed")
    inputs = [managed, selfhost, build_path, COMPARISON, MANAGED_FIRST,
              INFERENCE, PREPARATION, Path(__file__).resolve()]
    inputs += [source for source, _ in CASES.values()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[name] = {}
        for case, (source, _) in CASES.items():
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
    passed = stable
    for name in ("managed", "selfhost"):
        current = runs[name]
        for case, (_, expected) in CASES.items():
            actual = current[case]
            passed = passed and actual["stderr"] == expected
            passed = passed and (actual["exitCode"] == 0 if case == "positive" else actual["exitCode"] != 0)
            passed = passed and (actual["executableExists"] if case == "positive" else not actual["executableExists"])
        passed = passed and current["native"] == {"exitCode": 0, "stdout": "value=5\n", "stderr": ""}
    record = {"schemaVersion": 1, "unit": "C527 propagated Result payload member paired",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
