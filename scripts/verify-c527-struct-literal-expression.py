#!/usr/bin/env python3
"""Pair computed nominal field values and mismatch diagnostics."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-expression-managed-first-20260929-01.json"
COMPARISON = ROOT / "artifacts/scratch/c527-struct-literal-expression-source-comparison-20260929-01.json"
CASES = {
    "positive": (ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field.slg", ""),
    "fieldType": (ROOT / "scripts/probes/interpolation/c527-struct-literal-expression-field-type.slg",
                  "sollang: semantic error at 1:15: [module '<main>'] field 'x' expects Bool, got Int\n"),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], output: Path, label: str) -> dict:
    process = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=180, check=False)
    (output / f"{label}.stdout.txt").write_bytes(process.stdout)
    (output / f"{label}.stderr.txt").write_bytes(process.stderr)
    return {"exitCode": process.returncode,
            "stdout": process.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
            "stderr": process.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n")}


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
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    if (build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(selfhost)
            or first["status"] != "passed" or comparison["status"] != "passed"):
        raise ValueError("build or C# first comparison evidence is invalid")
    inputs = [managed, selfhost, build_path, FIRST, COMPARISON,
              ROOT / "selfhost/semantic/expression_type_ids.slg",
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "selfhost/llvm/text/context_prepare.slg", Path(__file__).resolve()]
    inputs += [source for source, _ in CASES.values()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[name] = {}
        for case, (source, _) in CASES.items():
            executable = output / f"{name}-{case}.exe"
            command = [str(compiler), "build", str(source), "-o", str(executable), "--target", "windows-x64"]
            if name == "selfhost":
                command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                            "--stdlib", str(ROOT / "stdlib"), "-O1"]
            runs[name][case] = run(command, output, f"{name}-{case}-build")
            runs[name][case]["executableExists"] = executable.exists()
            if case == "positive" and executable.exists():
                runs[name]["native"] = run([str(executable)], output, f"{name}-native")
    stable = start == {str(path): sha(path) for path in inputs}
    passed = stable
    for name in ("managed", "selfhost"):
        for case, (_, expected) in CASES.items():
            actual = runs[name][case]
            passed = passed and actual["stderr"] == expected
            passed = passed and (actual["exitCode"] == 0 if case == "positive" else actual["exitCode"] != 0)
            passed = passed and (actual["executableExists"] if case == "positive" else not actual["executableExists"])
        passed = passed and runs[name]["native"] == {"exitCode": 0, "stdout": "value=5\n", "stderr": ""}
    record = {"schemaVersion": 1, "unit": "C527 computed nominal field paired",
              "status": "passed" if passed else "failed", "completed": 2 if passed else 0,
              "total": 2, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
