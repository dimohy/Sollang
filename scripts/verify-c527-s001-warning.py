#!/usr/bin/env python3
"""Check managed-first S001 decisions and exact self-host warning parity."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
CASES = {
    "leftConversion": ("left-conversion", "warning S001 in module '' at 1:1:", "value=true\n"),
    "rightConversion": ("right-conversion", "warning S001 in module '' at 1:9:", "value=true\n"),
    "contextualLiteral": ("contextual-literal", "", "value=true\n"),
    "contextualRight": ("contextual-right", "", "value=true\n"),
    "invalidComparison": ("invalid-comparison", "numeric conversion 'Float' expects a numeric value, got Bool", None),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def normalized(path: Path) -> str:
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
    if args.mode == "managed":
        if args.build or args.managed_proof or args.source_comparison:
            raise ValueError("managed mode takes no paired inputs")
        compiler = MANAGED
        reference = None
        inputs = [MANAGED, ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs", Path(__file__).resolve()]
    else:
        if not args.build or not args.managed_proof or not args.source_comparison:
            raise ValueError("paired mode requires build and source proofs")
        build = args.build.resolve()
        reference_path = args.managed_proof.resolve()
        comparison_path = args.source_comparison.resolve()
        build_record = json.loads((build / "result.json").read_text(encoding="utf-8"))
        comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
        reference = json.loads(reference_path.read_text(encoding="utf-8"))
        if build_record["status"] != "passed" or not build_record["inputsStable"]:
            raise ValueError("compiler build is not verified")
        if reference["status"] != "passed" or not reference["inputStable"]:
            raise ValueError("managed proof is not verified")
        if comparison["status"] != "compared-before-slg-edit":
            raise ValueError("source decisions were not compared before the SLG edit")
        if comparison["managedDecision"]["sha256"] != sha(ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"):
            raise ValueError("C# semantic source changed since comparison")
        compiler = build / "compiler.exe"
        if sha(compiler) != build_record["compilerSha256"]:
            raise ValueError("compiler binary changed since build")
        inputs = [compiler, build / "result.json", MANAGED, reference_path, comparison_path, Path(__file__).resolve()]
    inputs.extend(ROOT / f"scripts/probes/interpolation/c527-s001-{suffix}.slg" for suffix, _, _ in CASES.values())
    start_hashes = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for name, (suffix, expected_stderr, expected_stdout) in CASES.items():
        case_dir = output / name
        case_dir.mkdir()
        source = ROOT / f"scripts/probes/interpolation/c527-s001-{suffix}.slg"
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", str(source), "-o", str(exe), "--target", "windows-x64"]
        if args.mode == "paired":
            command.extend(("--llvm", str(ROOT / ".tools/llvm-22.1.8"), "--stdlib", str(ROOT / "stdlib"), "-O1"))
        build_exit = run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = normalized(case_dir / "build.stderr.txt")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = normalized(case_dir / "run.stdout.txt")
        if args.mode == "managed":
            valid_stderr = (expected_stderr in stderr and stderr.count("warning S001") == 1
                            if expected_stderr.startswith("warning") else
                            expected_stderr in stderr and "warning S001" not in stderr
                            if expected_stderr else stderr == "")
            valid = (build_exit != 0 and expected_stdout is None or
                     build_exit == 0 and run_exit == 0 and stdout == expected_stdout)
            valid = valid and valid_stderr
        else:
            old = reference["cases"][name]
            valid = (build_exit == old["buildExit"] and stderr == old["buildStderr"]
                     and run_exit == old["runExit"] and stdout == old["runStdout"])
        cases[name] = {"status": "passed" if valid else "failed", "source": str(source.relative_to(ROOT)),
                       "buildExit": build_exit, "buildStderr": stderr, "runExit": run_exit, "runStdout": stdout}
        print(f"{name}: {'PASS' if valid else 'FAIL'}", flush=True)
    stable = start_hashes == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C527 interpolation S001 warning decisions",
              "mode": args.mode, "status": "passed" if stable and completed == len(cases) else "failed",
              "completed": completed, "total": len(cases), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": start_hashes, "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"S001 warning proof failed: {completed}/{len(cases)}")


if __name__ == "__main__":
    main()
