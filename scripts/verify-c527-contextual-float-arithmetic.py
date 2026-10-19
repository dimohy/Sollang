#!/usr/bin/env python3
"""Check contextual floating arithmetic against the C# compiler."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
CASES = ("left", "right")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def execute(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("managed", "paired"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--build", type=Path)
    parser.add_argument("--managed-proof", type=Path)
    parser.add_argument("--source-comparison", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output exists: {output}")
    compiler = MANAGED
    inputs = [MANAGED, Path(__file__).resolve()]
    reference = None
    if args.mode == "paired":
        if not args.build or not args.managed_proof or not args.source_comparison:
            raise ValueError("paired mode requires build, C# proof, and source comparison")
        build = args.build.resolve()
        proof = args.managed_proof.resolve()
        comparison = args.source_comparison.resolve()
        build_record = json.loads((build / "result.json").read_text(encoding="utf-8"))
        reference = json.loads(proof.read_text(encoding="utf-8"))
        source_record = json.loads(comparison.read_text(encoding="utf-8"))
        if build_record["status"] != "passed" or not build_record["inputsStable"]:
            raise ValueError("self-host compiler build is not stable")
        if reference["status"] != "passed" or not reference["inputStable"]:
            raise ValueError("C# first proof is not stable")
        if source_record["status"] != "compared-before-slg-edit":
            raise ValueError("source decisions were not compared")
        compiler = build / "compiler.exe"
        if sha(compiler) != build_record["compilerSha256"]:
            raise ValueError("self-host binary changed")
        inputs.extend((compiler, build / "result.json", proof, comparison))
    elif args.build or args.managed_proof or args.source_comparison:
        raise ValueError("managed mode takes no paired inputs")
    inputs.extend(ROOT / f"scripts/probes/interpolation/c527-contextual-float-arithmetic-{side}.slg" for side in CASES)
    hashes = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for side in CASES:
        case_dir = output / side
        case_dir.mkdir()
        source = ROOT / f"scripts/probes/interpolation/c527-contextual-float-arithmetic-{side}.slg"
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", str(source), "-o", str(exe), "--target", "windows-x64"]
        if args.mode == "paired":
            command.extend(("--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"))
        build_exit = execute(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = read(case_dir / "build.stderr.txt")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = execute([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = read(case_dir / "run.stdout.txt")
        if args.mode == "managed":
            passed = build_exit == run_exit == 0 and stderr == "" and stdout == "value=3\n"
        else:
            expected = reference["cases"][side]
            passed = (build_exit == expected["buildExit"] and stderr == expected["buildStderr"]
                      and run_exit == expected["runExit"] and stdout == expected["runStdout"])
        cases[side] = {"status": "passed" if passed else "failed", "buildExit": build_exit,
                       "buildStderr": stderr, "runExit": run_exit, "runStdout": stdout}
        print(f"{side}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = hashes == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C527 contextual floating arithmetic",
              "mode": args.mode, "status": "passed" if stable and completed == len(CASES) else "failed",
              "completed": completed, "total": len(CASES), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": hashes, "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"contextual float arithmetic failed: {completed}/{len(CASES)}")


if __name__ == "__main__":
    main()
