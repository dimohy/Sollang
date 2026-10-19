#!/usr/bin/env python3
"""Verify C# and SLG nominal initializer diagnostics and retained receiver cases."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPARISON = ROOT / "artifacts/scratch/c527-struct-literal-initializer-source-comparison-20260929-01.json"
FIRST = ROOT / "artifacts/scratch/c527-struct-literal-initializer-managed-first-20260929-01.json"
EXPECTED = {
    "unknown-field": "sollang: semantic error at 1:10: [module '<main>'] struct 'Point' has no field 'y'\n",
    "duplicate-field": "sollang: semantic error at 1:16: [module '<main>'] field 'x' is initialized more than once in 'Point'\n",
    "missing-field": "sollang: semantic error at 1:2: [module '<main>'] struct 'Point' requires field 'x' to be initialized\n",
    "field-type": "sollang: semantic error at 1:13: [module '<main>'] field 'x' expects Bool, got Int\n",
    "float": "sollang: semantic error at 6:5: [module '<main>'] string interpolation expects Text, Int, or Bool but received Float\n",
    "positive": "",
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
    comparison = json.loads(COMPARISON.read_text(encoding="utf-8"))
    first = json.loads(FIRST.read_text(encoding="utf-8"))
    if (build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(selfhost)
            or comparison["status"] != "passed" or first["status"] != "passed"):
        raise ValueError("build or C# source comparison proof is invalid")
    sources = {name: ROOT / f"scripts/probes/interpolation/c527-struct-literal-{'field-' if name in ('float', 'positive') else ''}{name}.slg"
               for name in EXPECTED}
    inputs = [managed, selfhost, build_path, COMPARISON, FIRST,
              ROOT / "selfhost/semantic/expression_type_ids.slg",
              ROOT / "selfhost/llvm/emitter/diagnostics.slg", Path(__file__).resolve(), *sources.values()]
    start = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    runs = {}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        runs[name] = {}
        for case, source in sources.items():
            executable = output / f"{name}-{case}.exe"
            command = [str(compiler), "build", str(source), "-o", str(executable), "--target", "windows-x64"]
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
        for case, expected in EXPECTED.items():
            actual = runs[name][case]
            passed = passed and actual["stderr"] == expected
            passed = passed and (actual["exitCode"] == 0 if case == "positive" else actual["exitCode"] != 0)
            passed = passed and (actual["executableExists"] if case == "positive" else not actual["executableExists"])
        passed = passed and runs[name]["native"] == {"exitCode": 0, "stdout": "value=5\n", "stderr": ""}
    result = {"schemaVersion": 1, "unit": "C527 nominal initializer paired diagnostics",
              "status": "passed" if passed else "failed", "completed": 6 if passed else 0,
              "total": 6, "inputsStable": stable, "inputSha256": start, "runs": runs}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"{result['status'].upper()} {output / 'result.json'}")
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
