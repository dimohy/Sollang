#!/usr/bin/env python3
"""Compare contextual if value and branch diagnostics with C# evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from verification_fingerprints import managed_runtime_inputs


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
SEMANTIC_SOURCE = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
CASES = {
    "valid": (
        ROOT / "scripts/probes/diagnostics/c385-contextual-if-numeric-operand.slg",
        ROOT / "artifacts/scratch/c385-contextual-if-numeric-managed-first-20260929-01.json",
    ),
    "invalid": (
        ROOT / "scripts/probes/diagnostics/c385-contextual-if-invalid-branch.slg",
        ROOT / "artifacts/scratch/c385-contextual-if-invalid-managed-first-20260929-01.json",
    ),
}
COMPARISON = ROOT / "artifacts/scratch/c385-contextual-if-invalid-source-comparison-20260929-01.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    record = json.loads(read(build / "result.json"))
    if record["status"] != "passed" or not record["inputsStable"]:
        raise ValueError("self-host compiler build is not stable")
    compiler = build / "compiler.exe"
    if digest(compiler) != record["compilerSha256"]:
        raise ValueError("self-host compiler hash changed")
    comparison = json.loads(read(COMPARISON))
    if comparison["status"] != "compared-before-slg-diagnostic-edit":
        raise ValueError("source comparison was not completed before the SLG edit")
    inputs = [compiler, build / "result.json", *managed_runtime_inputs(MANAGED), SEMANTIC_SOURCE, COMPARISON, Path(__file__).resolve()]
    expected = {}
    for name, (source, proof_path) in CASES.items():
        proof = json.loads(read(proof_path))
        if proof["status"] != "passed" or proof["inputSha256"] != {
            source.relative_to(ROOT).as_posix(): digest(source),
            MANAGED.relative_to(ROOT).as_posix(): digest(MANAGED),
            SEMANTIC_SOURCE.relative_to(ROOT).as_posix(): digest(SEMANTIC_SOURCE),
        }:
            raise ValueError(f"managed proof inputs changed: {name}")
        expected[name] = proof
        inputs.extend((source, proof_path))
    hashes = {str(path): digest(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for name, (source, _) in CASES.items():
        case_dir = output / name
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", str(source), "-o", str(exe), "--target", "windows-x64",
                   "--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"]
        build_exit = run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        build_stderr = read(case_dir / "build.stderr.txt")
        run_exit = None
        run_stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            run_stdout = read(case_dir / "run.stdout.txt").strip()
        proof = expected[name]
        passed = build_exit == proof["buildExit"]
        if name == "valid":
            passed = passed and build_stderr == "" and run_exit == proof["runExit"]
            passed = passed and run_stdout == proof["runStdout"]
        else:
            passed = passed and build_stderr.strip() == proof["buildStderr"] and run_exit is None
        cases[name] = {"status": "passed" if passed else "failed", "buildExit": build_exit,
                       "buildStderr": build_stderr, "runExit": run_exit, "runStdout": run_stdout}
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = hashes == {str(path): digest(path) for path in inputs}
    complete = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C385 contextual if branch diagnostic parity",
              "status": "passed" if stable and complete == len(CASES) else "failed",
              "completed": complete, "total": len(CASES), "inputStable": stable,
              "compilerSha256": digest(compiler), "inputSha256": hashes, "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"contextual if parity failed: {complete}/{len(CASES)}")


if __name__ == "__main__":
    main()
