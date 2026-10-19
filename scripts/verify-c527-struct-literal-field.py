#!/usr/bin/env python3
"""Pair C# and SLG direct nominal struct field interpolation behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-struct-literal-source-comparison-20260929-01.json"
MANAGED_FIRST = ROOT / "artifacts/scratch/c527-struct-literal-managed-first-20260929-01.json"
CASES = {
    "positive": (ROOT / "scripts/probes/interpolation/c527-struct-literal-field-positive.slg", ""),
    "float": (ROOT / "scripts/probes/interpolation/c527-struct-literal-field-float.slg",
              "sollang: semantic error at 6:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n"),
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
        raise ValueError("build or source comparison evidence is invalid")
    inputs = [managed, selfhost, build_path, COMPARISON, MANAGED_FIRST,
              ROOT / "selfhost/ir/interpolation.slg",
              ROOT / "selfhost/semantic/expression_type_ids.slg",
              ROOT / "selfhost/semantic/interpolation_inference.slg",
              ROOT / "selfhost/llvm/text/foundation.slg", Path(__file__).resolve()]
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
    record = {"schemaVersion": 1, "unit": "C527 direct nominal struct field receiver paired",
              "status": "passed" if passed else "failed", "completed": 1 if passed else 0,
              "total": 1, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"{record['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
