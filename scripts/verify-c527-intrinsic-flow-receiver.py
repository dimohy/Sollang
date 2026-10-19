#!/usr/bin/env python3
"""Pair C# and SLG results for a Text slice feeding len in interpolation."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-intrinsic-flow-receiver-source-comparison-20260929-01.json"
POSITIVE = ROOT / "scripts/probes/interpolation/c527-intrinsic-flow-result-receiver-positive.slg"
ARITY = ROOT / "scripts/probes/interpolation/c527-intrinsic-flow-result-receiver-arity.slg"
MANAGED_OUTPUT = Path(r"C:\Users\dimohy\AppData\Local\Sollang\c527-intrinsic-flow-receiver-managed-first-20260929-01")
EXPECTED_ARITY = "sollang: semantic error at 1:46: [module '<main>'] len does not accept arguments\n"


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
    build_result_path = args.build_result.resolve(strict=True)
    build = json.loads(build_result_path.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    if (build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(selfhost)
            or comparison["status"] != "passed"
            or comparison["inputSha256"][str(POSITIVE)] != sha(POSITIVE)
            or comparison["inputSha256"][str(ARITY)] != sha(ARITY)):
        raise ValueError("compiler build or C# source comparison is invalid")
    inputs = [managed, selfhost, build_result_path, COMPARISON, POSITIVE, ARITY,
              ROOT / "selfhost/ir/interpolation.slg",
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "selfhost/llvm/text/context_prepare.slg", Path(__file__).resolve()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs: dict[str, dict] = {}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[name] = {}
        for case, source in (("positive", POSITIVE), ("arity", ARITY)):
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
        passed = passed and (current["positive"]["exitCode"] == 0
                             and current["positive"]["executableExists"]
                             and current["native"] == {"exitCode": 0, "stdout": "length=2\n", "stderr": ""}
                             and current["arity"]["exitCode"] != 0
                             and not current["arity"]["executableExists"]
                             and current["arity"]["stderr"] == EXPECTED_ARITY)
    record = {"schemaVersion": 1, "unit": "C527 intrinsic-flow result receiver paired",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
