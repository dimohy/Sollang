#!/usr/bin/env python3
"""Compare direct numeric conversion interpolation with the prior C# proof."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
PROOF = ROOT / "artifacts/scratch/c527-preir-conversion-managed-first-20260929-01/result.json"
SOURCES = (
    ROOT / "selfhost/semantic/interpolation_inference.slg",
    ROOT / "selfhost/llvm/text/context_prepare.slg",
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def execute(command: list[str], out: Path, err: Path) -> int:
    with out.open("wb") as stdout, err.open("wb") as stderr:
        return subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, check=False).returncode


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build_dir = args.build.resolve()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    compiler = build_dir / "compiler.exe"
    build = read(build_dir / "result.json")
    proof = read(PROOF)
    if (build["status"] != "passed" or not build["inputsStable"]
            or build["compilerSha256"] != sha(compiler)):
        raise ValueError("focused SLG compiler build is not a stable pass")
    if (proof["status"] != "passed" or proof["compilerSha256"] != sha(MANAGED)
            or proof["managedSourceSha256"] != sha(ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs")):
        raise ValueError("C# first proof does not match current managed compiler")
    inputs = [compiler, build_dir / "result.json", PROOF, Path(__file__).resolve(), *SOURCES]
    inputs.extend(ROOT / case["source"] for case in proof["cases"].values())
    start_hashes = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for name, reference in proof["cases"].items():
        case_dir = output / name
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        code = execute([str(compiler), "build", str(ROOT / reference["source"]), "-o", str(exe),
                        "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                        "--stdlib", str(ROOT / "stdlib"), "-O1"],
                       case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = normalized(case_dir / "build.stderr.txt")
        run_code = None
        run_stdout = None
        if code == 0:
            run_code = execute([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            run_stdout = normalized(case_dir / "run.stdout.txt")
        passed = ((code != 0) == (reference["buildExit"] != 0)
                  and stderr == reference["buildStderr"]
                  and (code != 0 or (run_code == 0 and run_stdout == reference["runStdout"])))
        cases[name] = {"status": "passed" if passed else "failed", "buildExit": code,
                       "buildStderr": stderr, "runExit": run_code, "runStdout": run_stdout}
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = start_hashes == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C527 numeric conversion pre-IR display",
              "status": "passed" if stable and completed == len(cases) else "failed",
              "completed": completed, "total": len(cases), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": start_hashes, "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"conversion pair failed: {completed}/{len(cases)}")


if __name__ == "__main__":
    main()
